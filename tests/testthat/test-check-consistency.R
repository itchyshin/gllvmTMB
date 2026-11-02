## Phase 1b validation milestone 2026-05-15 item 2:
## gllvmTMB_check_consistency(fit, n_sim) -- thin wrapper around
## TMB::checkConsistency() that tests whether the approximate
## marginal score is centred.
##
## The TMB template has no SIMULATE block (#1582), so a real
## TMB::checkConsistency() run re-scores the observed data and the wrapper
## stops with a "simulation not available" error. The tests that exercise
## the result structure, the diagnostics vocabulary and the print method
## therefore mock the simulation step (`.gllvmTMB_cc_simulation_available()`
## and `.gllvmTMB_cc_raw()`) with synthetic replicates. The fixture is the
## same rank-1 Gaussian fit used by test-confint-inspect.R and
## test-profile-targets.R.

make_tiny_fit_for_cc <- function(seed = 1L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 40,
    n_species = 6,
    n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.4, -0.3), 3, 1),
    psi_B = c(0.3, 0.3, 0.3),
    seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data = sim$data
  )))
}

## Synthetic TMB::checkConsistency() output: `n` replicates of a gradient
## vector with one entry per fixed parameter. `vary = FALSE` reproduces what a
## template without a SIMULATE block returns (identical gradients).
fake_cc_raw <- function(fit, n, vary = TRUE) {
  p <- length(fit$tmb_obj$par)
  par <- stats::setNames(rep(0, p), names(fit$tmb_obj$par))
  set.seed(42)
  reps <- lapply(seq_len(n), function(i) {
    list(gradient = if (vary) stats::rnorm(p) else rep(0.1, p))
  })
  structure(reps, par = par, class = "checkConsistency")
}

## Pretend the template can simulate and return synthetic replicates.
mock_cc_simulation <- function(fit, n_rep = NULL, vary = TRUE,
                               .env = parent.frame()) {
  testthat::local_mocked_bindings(
    .gllvmTMB_cc_simulation_available = function(fit) TRUE,
    .gllvmTMB_cc_raw = function(obj, n, estimate) {
      fake_cc_raw(fit, if (is.null(n_rep)) n else n_rep, vary = vary)
    },
    .env = .env
  )
}

## ---- input validation ---------------------------------------------------

test_that("gllvmTMB_check_consistency() errors on non-fit input", {
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(list(foo = 1)),
    "fit returned by `gllvmTMB\\(\\)`"
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
  mock_cc_simulation(fit)
  n_sim <- length(fit$tmb_obj$par) + 10L
  res <- suppressWarnings(suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = n_sim, seed = 1)
  ))
  expect_s3_class(res, "gllvmTMB_check_consistency")
  expect_named(
    res,
    c(
      "marginal_p_value",
      "marginal_bias",
      "joint_p_value",
      "flagged_parameters",
      "n_sim",
      "threshold",
      "diagnostics",
      "raw",
      "warnings",
      "call"
    )
  )
  ## diagnostics is character of length >= 1.
  expect_true(is.character(res$diagnostics))
  expect_gte(length(res$diagnostics), 1L)
  ## n_sim matches the requested value.
  expect_equal(res$n_sim, n_sim)
  ## threshold is the documented default.
  expect_equal(res$threshold, 0.5)
})

## ---- diagnostics vocabulary ---------------------------------------------

test_that("diagnostics flags are drawn from the documented set", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  mock_cc_simulation(fit)
  n_sim <- length(fit$tmb_obj$par) + 10L
  res <- suppressWarnings(suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = n_sim, seed = 1)
  ))
  documented <- c(
    "no_centring_warning",
    "marginal_score_non_centred",
    "joint_score_non_centred",
    "information_matrix_singular",
    "marginal_p_value_unavailable"
  )
  expect_true(all(res$diagnostics %in% documented))
})

## ---- n_sim guard and the no-SIMULATE guard (#1582) ----------------------

test_that("n_sim not larger than the parameter count errors and names the count", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  npar <- length(fit$tmb_obj$par)
  ## Too few replicates used to be swallowed and reported as a singular matrix.
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = 5L, seed = 1),
    class = "gllvmTMB_check_consistency_n_sim_too_small"
  )
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = 5L, seed = 1),
    sprintf("%d fixed parameters", npar)
  )
  ## A covariance from n replicates has rank at most n - 1, so n_sim equal to
  ## the parameter count is also too small.
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = npar, seed = 1),
    class = "gllvmTMB_check_consistency_n_sim_too_small"
  )
})

test_that("a template with no SIMULATE block errors instead of reporting a singular matrix", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  npar <- length(fit$tmb_obj$par)
  ## The real template cannot simulate: its "simulated" y is the observed y.
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = npar + 20L, seed = 1),
    class = "gllvmTMB_check_consistency_simulation_unavailable"
  )
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = npar + 20L, seed = 1),
    "simulation not available"
  )
})

test_that("identical replicate gradients (zero score SD) error even if the up-front probe passes", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  mock_cc_simulation(fit, vary = FALSE)
  n_sim <- length(fit$tmb_obj$par) + 10L
  expect_error(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = n_sim, seed = 1),
    class = "gllvmTMB_check_consistency_simulation_unavailable"
  )
})

test_that("a summary() error is passed to $warnings, not labelled singular", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  ## Fewer replicates come back than n_sim asked for, so TMB's summary()
  ## stops with "Too few simulations".
  mock_cc_simulation(fit, n_rep = 3L)
  n_sim <- length(fit$tmb_obj$par) + 10L
  res <- suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = n_sim, seed = 1)
  )
  expect_true(any(grepl("Too few simulations", res$warnings)))
  expect_false("information_matrix_singular" %in% res$diagnostics)
  expect_true(is.na(res$marginal_p_value))
})

test_that("synthetic replicates give a finite marginal p-value and bias", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  mock_cc_simulation(fit)
  n_sim <- length(fit$tmb_obj$par) + 40L
  res <- suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = n_sim, seed = 1)
  )
  expect_true(is.finite(res$marginal_p_value))
  expect_true(all(is.finite(res$marginal_bias)))
  expect_length(res$marginal_bias, length(fit$tmb_obj$par))
})

## ---- print method runs --------------------------------------------------

test_that("print.gllvmTMB_check_consistency runs without error", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cc()
  mock_cc_simulation(fit)
  n_sim <- length(fit$tmb_obj$par) + 10L
  res <- suppressWarnings(suppressMessages(
    gllvmTMB::gllvmTMB_check_consistency(fit, n_sim = n_sim, seed = 1)
  ))
  expect_message(print(res), "Laplace-consistency check")
})
