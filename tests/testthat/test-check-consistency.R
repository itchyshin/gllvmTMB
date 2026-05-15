## Phase 1b validation milestone 2026-05-15 item 2:
## gllvmTMB_check_consistency(fit, n_sim) -- thin wrapper around
## TMB::checkConsistency() that tests whether the approximate
## marginal score is centred.
##
## Tests use small n_sim (5-20) and `skip_on_cran()` since the
## simulate-evaluate path is non-trivial. The fixture is the same
## rank-1 Gaussian fit used by test-confint-inspect.R and
## test-profile-targets.R.

make_tiny_fit_for_cc <- function(seed = 1L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 40, n_species = 6, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.4, -0.3), 3, 1),
    psi_B    = c(0.3, 0.3, 0.3),
    seed     = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = sim$data
  )))
}

## ---- input validation ---------------------------------------------------

test_that("gllvmTMB_check_consistency() errors on non-gllvmTMB_multi", {
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(list(foo = 1)),
    "gllvmTMB_multi"
  )
})

test_that("gllvmTMB_check_consistency() rejects n_sim < 2", {
  fit <- structure(list(tmb_obj = NULL), class = "gllvmTMB_multi")
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = 1L),
    "n_sim"
  )
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = NA_integer_),
    "n_sim"
  )
})

## ---- returns the documented structure -----------------------------------

test_that("gllvmTMB_check_consistency() returns the documented structure", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  res <- suppressWarnings(suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = 10L, seed = 1)
  ))
  expect_s3_class(res, "gllvmTMB_check_consistency")
  expect_named(res, c("marginal_p_value", "marginal_bias",
                      "joint_p_value", "flagged_parameters",
                      "n_sim", "threshold", "diagnostics",
                      "raw", "warnings", "call"))
  ## diagnostics is character of length >= 1.
  expect_true(is.character(res$diagnostics))
  expect_gte(length(res$diagnostics), 1L)
  ## n_sim matches the requested value.
  expect_equal(res$n_sim, 10L)
  ## threshold is the documented default.
  expect_equal(res$threshold, 0.5)
})

## ---- diagnostics vocabulary ---------------------------------------------

test_that("diagnostics flags are drawn from the documented set", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  res <- suppressWarnings(suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = 10L, seed = 1)
  ))
  documented <- c("centred", "marginal_score_non_centred",
                  "joint_score_non_centred",
                  "information_matrix_singular",
                  "marginal_p_value_unavailable")
  expect_true(all(res$diagnostics %in% documented))
})

## ---- tiny fixtures flag information_matrix_singular --------------------

test_that("tiny fixtures correctly flag the singular-information case", {
  skip_on_cran()
  ## A genuinely small fixture (n_sites = 15) is likely to trigger
  ## TMB's information-matrix-inversion failure.
  set.seed(1)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 15, n_species = 3, n_traits = 3,
    mean_species_per_site = 2,
    Lambda_B = matrix(c(0.8, 0.4, -0.3), 3, 1),
    psi_B    = c(0.3, 0.3, 0.3),
    seed     = 1
  )
  fit_small <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = sim$data
  )))
  res <- suppressWarnings(suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit_small, n_sim = 5L,
                                         seed = 1)
  ))
  ## On a tiny fixture, the marginal p-value is NA and the
  ## information_matrix_singular flag (or the fallback
  ## marginal_p_value_unavailable flag) fires.
  expect_true(any(res$diagnostics %in%
                   c("information_matrix_singular",
                     "marginal_p_value_unavailable")))
})

## ---- print method runs --------------------------------------------------

test_that("print.gllvmTMB_check_consistency runs without error", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  res <- suppressWarnings(suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = 10L, seed = 1)
  ))
  expect_message(print(res), "Laplace-consistency check")
})
