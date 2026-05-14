## Mixed-response Sigma: per-trait link-residual handling on the latent
## scale. Verifies that extract_Sigma() / extract_Omega() recover the
## known per-trait latent variance and cross-family correlations when
## the fit mixes Gaussian + binomial(logit) + Poisson(log) traits.
##
## Reference: Nakagawa & Schielzeth (2010, Biological Reviews 85:935-956,
## doi:10.1111/j.1469-185X.2010.00141.x); Nakagawa, Johnson & Schielzeth
## (2017, J Roy Soc Interface 14(134):20170213, doi:10.1098/rsif.2017.0213).

simulate_mixed_BW <- function(seed = 7) {
  set.seed(seed)
  n_sites <- 200L
  reps    <- 8L            # multiple replicates per site to anchor binomial info
  Tn      <- 3L
  ## Lambda_B encodes a 2-axis latent shared structure across traits.
  ## Larger magnitudes -> stronger between-site contrasts that survive
  ## the binomial / poisson noise.
  Lambda_B <- matrix(c( 1.4,  1.1, -0.7,
                        0.4, -1.0,  1.0),
                     nrow = Tn, ncol = 2)
  psi_B <- c(0.20, 0.20, 0.20)
  ## Generate the per-site latent contribution on the same scale for all
  ## three traits.
  Z_B   <- matrix(stats::rnorm(n_sites * 2L), nrow = n_sites, ncol = 2L)
  u_mat <- Z_B %*% t(Lambda_B)
  for (t in seq_len(Tn))
    u_mat[, t] <- u_mat[, t] + stats::rnorm(n_sites, sd = sqrt(psi_B[t]))
  alpha <- c(0, 0, log(2))   # poisson trait gets a mean ~2
  rows <- list()
  for (s in seq_len(n_sites)) {
    eta_s <- alpha + u_mat[s, ]
    for (rep in seq_len(reps)) {
      ## trait_1 = gaussian (identity)
      y_g   <- stats::rnorm(1, mean = eta_s[1], sd = 0.3)
      ## trait_2 = binomial(logit)
      p     <- plogis(eta_s[2])
      y_b   <- as.integer(stats::rbinom(1, 1, p))
      ## trait_3 = poisson(log)
      y_p   <- as.integer(stats::rpois(1, exp(eta_s[3])))
      rows[[length(rows) + 1L]] <- data.frame(
        site         = s,
        species      = rep,
        site_species = paste(s, rep, sep = "_"),
        trait        = c("trait_1", "trait_2", "trait_3"),
        family       = c("g", "b", "p"),
        value        = c(y_g, y_b, y_p),
        stringsAsFactors = FALSE
      )
    }
  }
  dat <- do.call(rbind, rows)
  dat$site         <- factor(dat$site, levels = seq_len(n_sites))
  dat$species      <- factor(dat$species, levels = seq_len(reps))
  dat$site_species <- factor(dat$site_species)
  dat$trait        <- factor(dat$trait, levels = paste0("trait_", 1:Tn))
  dat$family       <- factor(dat$family, levels = c("g", "b", "p"))
  ## True latent-scale Sigma_B = Lambda Lambda^T + diag(psi_B): traits on
  ## the same (latent) scale, cross-family correlations are well-defined.
  Sigma_true <- Lambda_B %*% t(Lambda_B) + diag(psi_B)
  R_true     <- cov2cor(Sigma_true)
  list(data = dat, Sigma_true = Sigma_true, R_true = R_true,
       Lambda_B = Lambda_B, psi_B = psi_B)
}

test_that("link_residual_per_trait() returns the expected per-family vector", {
  skip_on_cran()
  sim <- simulate_mixed_BW(seed = 7)
  fam_list <- list(gaussian(), binomial(), poisson())
  attr(fam_list, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = sim$data, family = fam_list
  )))
  expect_equal(fit$opt$convergence, 0L)
  v <- gllvmTMB:::link_residual_per_trait(fit)
  expect_length(v, 3L)
  ## Gaussian: 0
  expect_equal(unname(v[1]), 0)
  ## Binomial logit: pi^2 / 3
  expect_equal(unname(v[2]), pi^2 / 3, tolerance = 1e-12)
  ## Poisson log: log(1 + 1 / mu_t), with mu_t = mean(exp(eta)) over
  ## the trait's rows. Should be > 0 and < log(2) for our intercept (~2).
  expect_gt(unname(v[3]), 0)
  expect_lt(unname(v[3]), 1)
})

test_that("extract_Sigma() with mixed families uses per-trait link residuals", {
  skip_on_cran()
  sim <- simulate_mixed_BW(seed = 7)
  fam_list <- list(gaussian(), binomial(), poisson())
  attr(fam_list, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = sim$data, family = fam_list
  )))
  expect_equal(fit$opt$convergence, 0L)

  out_none <- suppressMessages(extract_Sigma(
    fit, level = "B", part = "total", link_residual = "none"))
  out_auto <- suppressMessages(extract_Sigma(
    fit, level = "B", part = "total", link_residual = "auto"))
  v <- gllvmTMB:::link_residual_per_trait(fit)

  ## Diagonals differ per-trait by exactly v
  expect_equal(unname(diag(out_auto$Sigma) - diag(out_none$Sigma)),
               unname(v), tolerance = 1e-10)
  ## Off-diagonals unchanged
  Md <- out_auto$Sigma - out_none$Sigma
  diag(Md) <- 0
  expect_true(all(abs(Md) < 1e-10))

  ## Per-trait diagonal recovery (latent scale): true diagonals are
  ## diag(Lambda Lambda^T) + psi_B; auto diagonal should be that plus v
  ## (which equals what the engine reports + link residual).
  Sigma_true_total <- sim$Sigma_true
  diag_true_lat    <- diag(Sigma_true_total) + v
  diag_est_lat     <- diag(out_auto$Sigma)
  expect_lt(max(abs(diag_est_lat - diag_true_lat)), 1.0)

  ## Cross-family correlations (latent scale) recovered
  R_est  <- out_auto$R
  R_true <- sim$R_true
  ## Add link residuals to each diagonal of the truth to match the
  ## marginal latent-scale interpretation
  Sigma_true_lat <- Sigma_true_total + diag(unname(v))
  R_true_lat     <- cov2cor(Sigma_true_lat)
  off <- function(M) M[lower.tri(M)]
  expect_gt(stats::cor(off(R_est), off(R_true_lat)), 0.7)
})

test_that("extract_Omega() and extract_proportions() use per-trait residuals", {
  skip_on_cran()
  sim <- simulate_mixed_BW(seed = 7)
  fam_list <- list(gaussian(), binomial(), poisson())
  attr(fam_list, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = sim$data, family = fam_list
  )))
  v <- gllvmTMB:::link_residual_per_trait(fit)

  om_none <- suppressMessages(extract_Omega(fit, link_residual = "none"))
  om_auto <- suppressMessages(extract_Omega(fit, link_residual = "auto"))
  ## Auto adds v entry-by-entry to diag(Omega), once (not per tier).
  expect_equal(unname(diag(om_auto$Omega) - diag(om_none$Omega)),
               unname(v), tolerance = 1e-10)

  pr <- suppressMessages(extract_proportions(fit, link_residual = "auto",
                                              format = "wide"))
  expect_true("link_residual" %in% colnames(pr))
  ## The Gaussian trait has 0 link residual; the binomial trait has pi^2/3;
  ## the Poisson trait has log(1 + 1/mu).
  expect_equal(unname(pr$link_residual), unname(v), tolerance = 1e-10)
})

test_that("single-family (binomial logit) fits give identical Sigma to before", {
  skip_on_cran()
  set.seed(2025)
  n <- 150; Tn <- 3
  Lambda <- matrix(c(0.8, 0.5, -0.3, 0.0, 0.6, 0.4), Tn, 2)
  u <- matrix(rnorm(n * 2), n, 2)
  eta <- u %*% t(Lambda)
  p <- plogis(eta)
  y_bin <- matrix(rbinom(n * Tn, 1, p), n, Tn)
  df <- data.frame(
    individual = factor(rep(seq_len(n), each = Tn)),
    trait      = factor(rep(c("a","b","c"), n), levels = c("a","b","c")),
    value      = as.integer(t(y_bin))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2),
    data = df, site = "individual", family = binomial()
  )))
  out_none <- suppressMessages(extract_Sigma(fit, level = "B", part = "total",
                                              link_residual = "none"))
  out_auto <- suppressMessages(extract_Sigma(fit, level = "B", part = "total",
                                              link_residual = "auto"))
  ## Single binomial-logit fit: every trait gets pi^2/3 added.
  expect_equal(unname(diag(out_auto$Sigma) - diag(out_none$Sigma)),
               rep(pi^2 / 3, Tn), tolerance = 1e-10)
})
