## Design 55 A3 + Design 56 9.5d-latent -- animal_latent(1 + x | id) Gaussian.
##
## animal_latent(1 + x | id, d = K, pedigree = ped) routes through the
## same block-diagonal reduced-rank latent-slope engine as
## phylo_latent(1 + x | species, d = K) (Design 56 sec. 9.5a).
## The structural matrix A comes from a pedigree via
## pedigree_to_Ainv_sparse(), not from a phylogenetic tree.
##
## Per-column Sigma_k = Lambda_k Lambda_k^T (rank d), with K latent
## factor-score columns g_phy_slope[, f, k] ~ N(0, A). No
## intercept-slope cross-column correlation (block-diagonal).
##
## Coverage:
##   - Recovery (unbiased over replicates): mean Sigma_k within 0.30
##     for the intercept block, 0.15 for the slope block; conv = 0.
##   - Wide == long byte-identity (tolerance <= 1e-6 logLik).
##   - d > n_traits aborts loud (negative test).

skip_if_not_animal_latent_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not(exists("pedigree_to_A", envir = asNamespace("gllvmTMB")))
  testthat::skip_if_not_installed("tidyr")
}

## ---------------------------------------------------------------------------
## DGP: pedigree + block-diagonal latent-slope fixture.
## Mirrors make_platent_slope_fixture() from test-phylo-latent-slope-gaussian.R
## but uses a half-sib pedigree instead of a random tree.
## ---------------------------------------------------------------------------
.make_animal_latent_ped <- function(n_id = 80L) {
  data.frame(
    id   = paste0("i", seq_len(n_id)),
    sire = c(rep(NA, 8L), rep(paste0("i", rep(1:4, length.out = n_id - 8L)), 1L)),
    dam  = c(rep(NA, 8L), rep(paste0("i", rep(5:8, length.out = n_id - 8L)), 1L)),
    stringsAsFactors = FALSE
  )
}

make_animal_latent_slope_fixture <- function(
  seed,
  n_id   = 80L,
  n_traits = 3L,
  K      = 1L,
  reps   = 14L,
  Lam0   = matrix(c(1.1, -0.6, 0.4), 3L, 1L),
  Lam1   = matrix(c(0.3,  0.9, -0.5), 3L, 1L),
  resid_sd = 0.35
) {
  set.seed(seed)
  ped <- .make_animal_latent_ped(n_id)
  A <- gllvmTMB::pedigree_to_A(ped)
  id_labels <- rownames(A)
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
  rows$species <- factor(paste0("i", rows$sp), levels = id_labels)
  rows$trait   <- factor(paste0("t", rows$trait))

  list(
    df = rows, ped = ped, n_traits = n_traits,
    Sig0_true = Lam0 %*% t(Lam0),
    Sig1_true = Lam1 %*% t(Lam1),
    resid_sd  = resid_sd
  )
}

fit_animal_latent_slope <- function(df, ped, long = FALSE) {
  form <- if (long) {
    value ~ 0 + trait +
      animal_latent(0 + trait + (0 + trait):x | species, d = 1, pedigree = ped)
  } else {
    value ~ 0 + trait + animal_latent(1 + x | species, d = 1, pedigree = ped)
  }
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form, data = df, unit = "species", cluster = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
}

## ======================================================================
## 1. Recovery (unbiased over replicates)
## ======================================================================
test_that("animal_latent(1+x|id,d=1) recovers per-column Sigma on Gaussian (unbiased over replicates)", {
  skip_if_not_heavy()
  skip_if_not_animal_latent_slope_deps()

  nrep <- 8L
  n_traits <- 3L
  S0s <- array(0, c(n_traits, n_traits, nrep))
  S1s <- array(0, c(n_traits, n_traits, nrep))
  fx1 <- NULL
  for (r in seq_len(nrep)) {
    fx <- make_animal_latent_slope_fixture(seed = 2000L + r)
    if (r == 1L) fx1 <- fx
    fit <- fit_animal_latent_slope(fx$df, fx$ped)
    testthat::expect_equal(fit$opt$convergence, 0L)
    S0s[, , r] <- fit$report$Sigma_phy_slope_intercept
    S1s[, , r] <- fit$report$Sigma_phy_slope_slope
  }
  S0bar <- apply(S0s, c(1, 2), mean)
  S1bar <- apply(S1s, c(1, 2), mean)

  ## Mean recovery (rotation-invariant Sigma matrices).
  ## Intercept block: generous 0.30 band (Monte-Carlo scale noise).
  ## Slope block: tighter 0.15 band (well identified by covariate contrasts).
  testthat::expect_lt(max(abs(S0bar - fx1$Sig0_true)), 0.30)
  testthat::expect_lt(max(abs(S1bar - fx1$Sig1_true)), 0.15)
})

## ======================================================================
## 2. Wide == long byte-identity
## ======================================================================
test_that("animal_latent wide == long byte-identical (Design 55 sec. 3)", {
  skip_if_not_heavy()
  skip_if_not_animal_latent_slope_deps()

  fx <- make_animal_latent_slope_fixture(seed = 4242L, n_id = 40L, reps = 10L)
  fw <- fit_animal_latent_slope(fx$df, fx$ped, long = FALSE)
  fl <- fit_animal_latent_slope(fx$df, fx$ped, long = TRUE)

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
test_that("animal_latent aborts when d > n_traits", {
  skip_if_not_animal_latent_slope_deps()

  fx <- make_animal_latent_slope_fixture(seed = 7L, n_id = 20L, reps = 3L)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        animal_latent(1 + x | species, d = 5, pedigree = fx$ped),
      data = fx$df, unit = "species",
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ))),
    regexp = "d.*traits|rank.*exceed|cannot exceed|d_phy_slope"
  )
})
