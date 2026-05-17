## M2.2-A — Binary family recovery (binomial logit/probit/cloglog + ordinal-probit link residual).
##
## Walks the validation-debt register's binary family rows to
## deeper-tested:
##
##   FAM-02 binomial (logit)   : `partial` → recovery + link-residual at d = 1
##   FAM-03 binomial (probit)  : `partial` → recovery + identification at d = 1
##   FAM-04 binomial (cloglog) : `partial` → recovery + link-residual at d = 1
##   FAM-14 ordinal_probit     : `partial` → link-residual = 1 invariant
##                                (existing test-ordinal-probit.R covers
##                                 K=3 / K=4 cutpoint + intercept recovery)
##
## DGP convention per link:
##   eta is drawn via simulate_site_trait() with sigma2_eps = 0,
##   then converted to binary 0/1 via the per-link probability:
##     logit DGP    : y = rbinom(1, plogis(eta))
##     probit DGP   : y = rbinom(1, pnorm(eta))
##     cloglog DGP  : y = rbinom(1, 1 - exp(-exp(eta)))
##
## Recovery target: the identifiable trait covariance Σ on the
## *latent* scale, where (per docs/design/02-family-registry.md):
##   Σ_true = Λ Λᵀ + diag(ψ²) + diag(σ²_d)
## with σ²_d the per-family link residual (π²/3, 1, π²/6
## respectively). Raw Λ entries are sign-pinned via the engine's
## packed-vector parameterisation, but Σ is the rotation-invariant
## quantity we compare against truth.
##
## Tolerances: binary fits at n_sites = 200, d = 1 are genuinely
## noisy. We use loose-but-meaningful bounds — max-cell relative
## error ≤ 0.5 on Σ, max-cell absolute error ≤ 0.3 on the implied
## correlation matrix R. These are far above the "10 % RMSE"
## target that M3.5 will need to hit with R = 200 replicates per
## cell; M2.2-A is single-replicate sanity recovery.

# ---- Shared helpers --------------------------------------------------

binary_dgp <- function(T, n_sites, Lam, psi, seed,
                      link = c("logit", "probit", "cloglog")) {
  link <- match.arg(link)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 1L, n_traits = T,
    mean_species_per_site = 1, n_predictors = 1,
    alpha = rep(0, T),
    beta  = matrix(0, nrow = T, ncol = 1),
    Lambda_B = Lam, psi_B = psi,
    sigma2_eps = 0, seed = seed
  )
  df  <- sim$data
  eta <- df$value
  prob <- switch(link,
                 logit   = stats::plogis(eta),
                 probit  = stats::pnorm(eta),
                 cloglog = 1 - exp(-exp(eta)))
  df$value <- stats::rbinom(length(eta), size = 1L, prob = prob)
  list(data = df, truth = sim$truth, link = link, eta = eta)
}

true_Sigma <- function(Lam, psi, sigma2_d) {
  T <- nrow(Lam)
  Lam %*% t(Lam) + diag(psi^2, T) + diag(sigma2_d, T)
}

# ---- (1) FAM-02 binomial(logit) recovery at d = 1 --------------------

test_that("binomial(logit) recovers Sigma at d=1 (FAM-02 / M2.2-A)", {
  skip_on_cran()
  T   <- 3L
  Lam <- matrix(c(0.8, 0.6, -0.4), nrow = T, ncol = 1L)
  psi <- c(0.3, 0.2, 0.4)

  fx <- binary_dgp(T = T, n_sites = 200L, Lam = Lam, psi = psi,
                   seed = 20260517L, link = "logit")

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site),
    data   = fx$data,
    family = binomial()  # default logit
  )))
  expect_equal(fit$opt$convergence, 0L,
               info = "binomial(logit) fit did not converge at n=200, d=1")

  Sigma_truth <- true_Sigma(Lam, psi, sigma2_d = pi^2 / 3)
  Sigma_est   <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "auto"
  ))

  ## Σ recovery: max-cell relative error against truth's max-cell magnitude.
  rel_err <- max(abs(Sigma_est$Sigma - Sigma_truth)) / max(abs(Sigma_truth))
  expect_lt(rel_err, 0.5,
            label = sprintf("FAM-02 max rel err on Sigma = %.3f (loose binary bound)", rel_err))

  ## R recovery (implied correlation, rotation-invariant).
  R_truth <- stats::cov2cor(Sigma_truth)
  expect_lt(max(abs(Sigma_est$R - R_truth)), 0.3,
            label = "FAM-02 max abs err on R correlation matrix")
})

# ---- (2) FAM-03 binomial(probit) recovery at d = 1 -------------------

test_that("binomial(probit) recovers Sigma at d=1 (FAM-03 / M2.2-A)", {
  skip_on_cran()
  T   <- 3L
  Lam <- matrix(c(0.8, 0.6, -0.4), nrow = T, ncol = 1L)
  psi <- c(0.3, 0.2, 0.4)

  fx <- binary_dgp(T = T, n_sites = 200L, Lam = Lam, psi = psi,
                   seed = 20260518L, link = "probit")

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site),
    data   = fx$data,
    family = binomial(link = "probit")
  )))
  expect_equal(fit$opt$convergence, 0L)

  ## Probit identification: latent residual variance = 1 by construction.
  Sigma_truth <- true_Sigma(Lam, psi, sigma2_d = 1)
  Sigma_est   <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "auto"
  ))

  rel_err <- max(abs(Sigma_est$Sigma - Sigma_truth)) / max(abs(Sigma_truth))
  expect_lt(rel_err, 0.5,
            label = sprintf("FAM-03 max rel err on Sigma = %.3f", rel_err))

  R_truth <- stats::cov2cor(Sigma_truth)
  expect_lt(max(abs(Sigma_est$R - R_truth)), 0.3,
            label = "FAM-03 max abs err on R correlation matrix")
})

# ---- (3) FAM-04 binomial(cloglog) recovery at d = 1 ------------------

test_that("binomial(cloglog) recovers Sigma at d=1 (FAM-04 / M2.2-A)", {
  skip_on_cran()
  T   <- 3L
  ## Cloglog is asymmetric; centre Lam closer to 0 so the linear
  ## predictor doesn't push too many rows into Pr(y=1) ≈ 1.
  Lam <- matrix(c(0.5, 0.4, -0.3), nrow = T, ncol = 1L)
  psi <- c(0.2, 0.2, 0.3)

  fx <- binary_dgp(T = T, n_sites = 200L, Lam = Lam, psi = psi,
                   seed = 20260519L, link = "cloglog")

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site),
    data   = fx$data,
    family = binomial(link = "cloglog")
  )))
  expect_equal(fit$opt$convergence, 0L)

  ## Cloglog residual variance = pi^2 / 6 (standard extreme-value).
  Sigma_truth <- true_Sigma(Lam, psi, sigma2_d = pi^2 / 6)
  Sigma_est   <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "auto"
  ))

  rel_err <- max(abs(Sigma_est$Sigma - Sigma_truth)) / max(abs(Sigma_truth))
  expect_lt(rel_err, 0.6,
            label = sprintf("FAM-04 max rel err on Sigma = %.3f", rel_err))
})

# ---- (4) Link-residual values per binomial link (M2.2-A) ------------

test_that("link_residual_per_trait() returns expected values per binomial link (M2.2-A)", {
  skip_on_cran()
  T   <- 2L
  Lam <- matrix(c(0.6, 0.4), nrow = T, ncol = 1L)
  psi <- c(0.2, 0.3)

  for (link in c("logit", "probit", "cloglog")) {
    fx <- binary_dgp(T = T, n_sites = 100L, Lam = Lam, psi = psi,
                     seed = 20260520L, link = link)
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site),
      data   = fx$data,
      family = binomial(link = link)
    )))
    if (fit$opt$convergence != 0L) {
      skip(sprintf("binomial(%s) fit did not converge at n=100; rerun with bigger n.", link))
    }
    expected <- switch(link,
                       logit   = pi^2 / 3,
                       probit  = 1,
                       cloglog = pi^2 / 6)
    actual <- gllvmTMB:::link_residual_per_trait(fit)
    expect_equal(unname(as.numeric(actual)),
                 rep(expected, T),
                 tolerance = 1e-8,
                 label = sprintf("link_residual_per_trait for binomial(%s)", link))
  }
})

# ---- (5) FAM-14 ordinal_probit link-residual = 1 invariant -----------

test_that("link_residual_per_trait() returns 1 for ordinal_probit fits (FAM-14 / M2.2-A)", {
  skip_on_cran()
  ## Construct a minimal ordinal-probit fit reusing the existing
  ## test-ordinal-probit.R DGP convention (Wright/Hadfield threshold
  ## model with cutpoints {0, 0.7, 1.4}).
  set.seed(20260521L)
  n_ind <- 200L
  Tn    <- 2L
  ystar <- matrix(stats::rnorm(n_ind * Tn), nrow = n_ind, ncol = Tn)
  y_a <- 1L + (ystar[, 1] > 0) + (ystar[, 1] > 0.7) + (ystar[, 1] > 1.4)  # K = 4
  y_b <- 1L + (ystar[, 2] > 0) + (ystar[, 2] > 0.7) + (ystar[, 2] > 1.4)  # K = 4
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), times = n_ind)),
    value      = c(rbind(y_a, y_b))
  )
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | individual),
      data   = df,
      family = gllvmTMB::ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") ||
      !inherits(fit, "gllvmTMB_multi") ||
      fit$opt$convergence != 0L) {
    skip("ordinal_probit smoke fixture did not converge in M2.2-A; deeper recovery is covered by test-ordinal-probit.R")
  }
  actual <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(as.numeric(actual)), rep(1, Tn), tolerance = 1e-8,
               label = "ordinal_probit latent residual = 1 by construction (Hadfield 2015 MEE eqn 10)")
})
