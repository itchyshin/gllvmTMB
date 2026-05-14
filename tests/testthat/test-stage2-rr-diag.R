# Stage 2: rr() and diag() covariance structures.
# Strategy: cross-validate against glmmTMB on the SAME formula and data.
# A matching log-likelihood (to TMB tolerance) is the gold-standard test of
# correct covstruct semantics, regardless of identifiability rotation/sign
# in the loading matrix Lambda.

skip_if_not_glmmTMB <- function() {
  testthat::skip_if_not_installed("glmmTMB")
}

simulate_rr_diag <- function(n_sites = 60, n_species = 12, n_traits = 4,
                             mean_species_per_site = 6, n_predictors = 2,
                             Lambda_B = NULL, psi_B = NULL, seed = 2025) {
  simulate_site_trait(
    n_sites               = n_sites,
    n_species             = n_species,
    n_traits              = n_traits,
    mean_species_per_site = mean_species_per_site,
    n_predictors          = n_predictors,
    Lambda_B              = Lambda_B,
    psi_B                   = psi_B,
    sigma2_eps            = 0.5,
    seed                  = seed
  )
}

test_that("Stage 2: rr() alone matches glmmTMB log-likelihood exactly", {
  skip_if_not_glmmTMB()
  Lambda_B <- matrix(c(1.0, 0.7, -0.3, 0.5,
                       0.3, -0.5, 0.8, 0.2), nrow = 4, ncol = 2)
  sim <- simulate_rr_diag(Lambda_B = Lambda_B, psi_B = NULL, seed = 2025)
  df <- sim$data

  fit_g <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
                    data = df)
  expect_s3_class(fit_g, "gllvmTMB_multi")
  expect_equal(fit_g$opt$convergence, 0L)

  ll_g <- -fit_g$opt$objective
  ## NOTE: glmmTMB uses its own keyword names `rr()` / `diag()`; we
  ## intentionally keep those here (NOT gllvmTMB's canonical
  ## latent()/unique()) because this is a cross-package log-likelihood
  ## agreement test, not a gllvmTMB-side fit.
  fit_t <- glmmTMB::glmmTMB(
    value ~ 0 + trait + rr(0 + trait | site, d = 2),
    data = df, REML = FALSE
  )
  ll_t <- as.numeric(stats::logLik(fit_t))
  expect_equal(ll_g, ll_t, tolerance = 1e-4)
})

test_that("Stage 2: diag() alone matches glmmTMB log-likelihood exactly", {
  skip_if_not_glmmTMB()
  sim <- simulate_rr_diag(Lambda_B = NULL,
                          psi_B = c(0.5, 0.5, 0.5, 0.5),
                          seed = 2025)
  df <- sim$data

  fit_g <- gllvmTMB(value ~ 0 + trait + unique(0 + trait | site),
                    data = df)
  expect_equal(fit_g$opt$convergence, 0L)

  ll_g <- -fit_g$opt$objective
  ## See note in previous test: glmmTMB uses `rr()` / `diag()`, not the
  ## gllvmTMB canonical names.
  fit_t <- glmmTMB::glmmTMB(
    value ~ 0 + trait + diag(0 + trait | site),
    data = df, REML = FALSE
  )
  ll_t <- as.numeric(stats::logLik(fit_t))
  expect_equal(ll_g, ll_t, tolerance = 1e-4)
})

test_that("Stage 2: rr() + diag() on the same grouping matches glmmTMB", {
  skip_if_not_glmmTMB()
  Lambda_B <- matrix(c(0.8, 0.5, -0.2, 0.3,
                       0.2, -0.4, 0.6, 0.1), nrow = 4, ncol = 2)
  sim <- simulate_rr_diag(n_sites = 80,
                          Lambda_B = Lambda_B,
                          psi_B = c(0.4, 0.4, 0.4, 0.4),
                          seed = 7)
  df <- sim$data

  fit_g <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site),
    data = df
  )
  expect_equal(fit_g$opt$convergence, 0L)
  expect_true(fit_g$use$rr_B && fit_g$use$diag_B)
  expect_equal(dim(fit_g$report$Lambda_B), c(4, 2))

  ll_g <- -fit_g$opt$objective
  ## glmmTMB-side keywords (NOT gllvmTMB's canonical names).
  fit_t <- suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait +
            rr(0 + trait | site, d = 2) +
            diag(0 + trait | site),
    data = df, REML = FALSE
  ))
  ll_t <- as.numeric(stats::logLik(fit_t))
  ## glmmTMB's combined-rr-and-diag fits sometimes hit non-PD Hessians on
  ## small samples; in that case we have nothing to compare against, so skip
  ## the logLik comparison rather than fail the test.
  testthat::skip_if(is.na(ll_t),
                    "glmmTMB hit non-PD Hessian on this dataset")
  expect_equal(ll_g, ll_t, tolerance = 1e-4)
})

test_that("Stage 2: residual sigma is recovered well", {
  Lambda_B <- matrix(c(0.8, 0.5, -0.2, 0.3,
                       0.2, -0.4, 0.6, 0.1), nrow = 4, ncol = 2)
  sim <- simulate_rr_diag(n_sites = 100,
                          Lambda_B = Lambda_B,
                          psi_B = c(0.3, 0.3, 0.3, 0.3),
                          seed = 11)
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = sim$data
  )
  expect_equal(fit$opt$convergence, 0L)
  ## true residual SD
  true_sigma <- sqrt(sim$truth$sigma2_eps)  # 0.5^.5
  expect_equal(fit$report$sigma_eps, true_sigma, tolerance = 0.1)
})

test_that("Stage 2: rejects spatial_unique() without mesh (Stage 4)", {
  sim <- simulate_rr_diag(n_sites = 30, n_species = 8, n_traits = 3,
                          mean_species_per_site = 4, seed = 1)
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + spatial_unique(0 + trait | coords, mesh = NULL),
      data = sim$data
    ),
    "spatial"
  )
})
