## Design 55 A5 + Design 56 9.5f-latent -- relmat_latent(1 + x | id) Gaussian.
##
## SCOPE NOTE (Design 14 sec. 2). "relmat" denotes the CAPABILITY "phylo
## latent random regression on a user-supplied relatedness matrix", expressed
## through `phylo_latent(species, vcv = A, d = K)` (no separate `relmat_*()`
## keyword exists). See test-relmat-dep-slope-gaussian.R for the dep analogue.
##
## Block-diagonal reduced-rank path: per-column Lambda_k (n_traits x d),
## Sigma_k = Lambda_k Lambda_k^T, g_phy_slope[, f, k] ~ N(0, A). No
## intercept-slope cross-column correlation.
##
## Coverage:
##   - Recovery (unbiased over replicates): mean Sigma_k within 0.30
##     for intercept block, 0.15 for slope block; conv = 0.
##   - Wide == long byte-identity (tolerance <= 1e-6 logLik).
##   - d > n_traits aborts loud (negative test).

skip_if_not_relmat_latent_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("Matrix")
  testthat::skip_if_not_installed("tidyr")
}

## ---------------------------------------------------------------------------
## DGP: user-A (AR(1)) + block-diagonal latent-slope fixture.
## Mirrors make_platent_slope_fixture() from test-phylo-latent-slope-gaussian.R
## but uses a generic AR(1) relatedness matrix instead of a random tree.
## ---------------------------------------------------------------------------
make_relmat_latent_slope_fixture <- function(
  seed,
  n_id   = 80L,
  n_traits = 3L,
  K      = 1L,
  reps   = 14L,
  ar1_rho = 0.5,
  Lam0   = matrix(c(1.1, -0.6, 0.4), 3L, 1L),
  Lam1   = matrix(c(0.3,  0.9, -0.5), 3L, 1L),
  resid_sd = 0.35
) {
  set.seed(seed)
  id_labels <- paste0("g", seq_len(n_id))
  A <- ar1_rho^abs(outer(seq_len(n_id), seq_len(n_id), "-"))
  dimnames(A) <- list(id_labels, id_labels)
  Lc <- t(chol(A))

  g0 <- Lc %*% matrix(stats::rnorm(n_id * K), n_id, K)
  g1 <- Lc %*% matrix(stats::rnorm(n_id * K), n_id, K)
  u_int <- g0 %*% t(Lam0)
  u_slp <- g1 %*% t(Lam1)

  rows <- expand.grid(
    rep   = seq_len(reps),
    trait = seq_len(n_traits),
    sp    = seq_len(n_id)
  )
  rows$x <- stats::rnorm(nrow(rows))
  beta <- c(0.5, -0.3, 0.1)[seq_len(n_traits)]
  mu <- beta[rows$trait] +
    u_int[cbind(rows$sp, rows$trait)] +
    u_slp[cbind(rows$sp, rows$trait)] * rows$x
  rows$value   <- mu + stats::rnorm(nrow(rows), 0, resid_sd)
  rows$species <- factor(paste0("g", rows$sp), levels = id_labels)
  rows$trait   <- factor(paste0("t", rows$trait))

  list(
    df = rows, A = A, n_traits = n_traits,
    Sig0_true = Lam0 %*% t(Lam0),
    Sig1_true = Lam1 %*% t(Lam1),
    resid_sd  = resid_sd
  )
}

fit_relmat_latent_slope <- function(df, A, long = FALSE) {
  form <- if (long) {
    value ~ 0 + trait +
      phylo_latent(0 + trait + (0 + trait):x | species, d = 1, vcv = A)
  } else {
    value ~ 0 + trait + phylo_latent(1 + x | species, d = 1, vcv = A)
  }
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form, data = df, unit = "species", cluster = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
}

## ======================================================================
## 1. Recovery (unbiased over replicates)
## ======================================================================
test_that("relmat_latent (phylo_latent, vcv=A, d=1) recovers per-column Sigma on Gaussian (unbiased over replicates)", {
  skip_if_not_heavy()
  skip_if_not_relmat_latent_slope_deps()

  nrep <- 8L
  n_traits <- 3L
  S0s <- array(0, c(n_traits, n_traits, nrep))
  S1s <- array(0, c(n_traits, n_traits, nrep))
  fx1 <- NULL
  for (r in seq_len(nrep)) {
    fx <- make_relmat_latent_slope_fixture(seed = 3000L + r)
    if (r == 1L) fx1 <- fx
    fit <- fit_relmat_latent_slope(fx$df, fx$A)
    testthat::expect_equal(fit$opt$convergence, 0L)
    S0s[, , r] <- fit$report$Sigma_phy_slope_intercept
    S1s[, , r] <- fit$report$Sigma_phy_slope_slope
  }
  S0bar <- apply(S0s, c(1, 2), mean)
  S1bar <- apply(S1s, c(1, 2), mean)

  ## Mean recovery (rotation-invariant Sigma matrices).
  testthat::expect_lt(max(abs(S0bar - fx1$Sig0_true)), 0.30)
  testthat::expect_lt(max(abs(S1bar - fx1$Sig1_true)), 0.15)
})

## ======================================================================
## 2. Wide == long byte-identity
## ======================================================================
test_that("relmat_latent wide == long byte-identical (Design 55 sec. 3)", {
  skip_if_not_heavy()
  skip_if_not_relmat_latent_slope_deps()

  fx <- make_relmat_latent_slope_fixture(seed = 5050L, n_id = 40L, reps = 10L)
  fw <- fit_relmat_latent_slope(fx$df, fx$A, long = FALSE)
  fl <- fit_relmat_latent_slope(fx$df, fx$A, long = TRUE)

  testthat::expect_equal(
    as.numeric(logLik(fw)),
    as.numeric(logLik(fl)),
    tolerance = 1e-6
  )
  testthat::expect_equal(
    fw$report$Sigma_phy_slope_intercept,
    fl$report$Sigma_phy_slope_intercept,
    tolerance = 1e-5
  )
  testthat::expect_equal(
    fw$report$Sigma_phy_slope_slope,
    fl$report$Sigma_phy_slope_slope,
    tolerance = 1e-5
  )
})

## ======================================================================
## 3. Negative test: d > n_traits aborts loud
## ======================================================================
test_that("relmat_latent (phylo_latent, vcv=A) aborts when d > n_traits", {
  skip_if_not_relmat_latent_slope_deps()

  fx <- make_relmat_latent_slope_fixture(seed = 7L, n_id = 20L, reps = 3L)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_latent(1 + x | species, d = 5, vcv = fx$A),
      data = fx$df, unit = "species",
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ))),
    regexp = "d.*traits|rank.*exceed|cannot exceed|d_phy_slope"
  )
})
