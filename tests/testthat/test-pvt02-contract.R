source(testthat::test_path("..", "..", "dev", "pvt02", "pvt02-contract.R"))

test_that("PVT-02 target is the total unit-tier diagonal", {
  spec <- pvt02_target_spec(
    theta_lambda = c(1, 2, 3, 4, 5),
    theta_psi = log(c(2, 3, 4)), n_traits = 3, d = 2, trait = 2
  )
  expect_equal(spec$lambda, rbind(c(1, 0), c(2, 3), c(4, 5)))
  expect_equal(spec$psi_sq, c(4, 9, 16))
  expect_equal(spec$V, 2^2 + 3^2 + 3^2)
  expect_equal(spec$log_V, log(22))
})

test_that("analytic log-V gradient matches central finite differences", {
  theta_lambda <- c(0.7, -0.3, 0.4, 0.2, -0.1)
  theta_psi <- c(-0.2, 0.1, 0.3)
  par <- c(theta_lambda, theta_psi)
  fn <- function(x) {
    pvt02_target_spec(x[seq_along(theta_lambda)], x[-seq_along(theta_lambda)], 3, 2, 2)$log_V
  }
  analytic <- pvt02_target_spec(theta_lambda, theta_psi, 3, 2, 2)$gradient
  expect_equal(analytic, pvt02_fd_gradient(fn, par), tolerance = 1e-6)
})

test_that("one-df LR roots require a real bracket and invert symmetrically", {
  crit <- stats::qchisq(0.95, df = 1)
  score <- function(q) q^2 - crit
  expect_equal(pvt02_profile_root(score, -4, 0)$root, -sqrt(crit), tolerance = 1e-7)
  expect_equal(pvt02_profile_root(score, 0, 4)$root, sqrt(crit), tolerance = 1e-7)
  expect_error(pvt02_profile_root(score, 2, 4), "does not bracket")
})

test_that("new PVT-02 window is disjoint from every prior certificate index", {
  old <- pvt02_seed_window(1, 40000)
  new <- pvt02_seed_window(50001, 5000)
  expect_true(pvt02_windows_disjoint(old, new))
  expect_false(pvt02_windows_disjoint(old, pvt02_seed_window(40000, 2)))
  expect_length(unique(pvt02_m3_seed(new)), 5000)
})

test_that("all requested rows are retained and failed endpoints are coverage misses", {
  rows <- do.call(rbind, list(
    pvt02_attempt_row(1, pvt02_m3_seed(1), 2, 2, 1, 3),
    pvt02_attempt_row(2, pvt02_m3_seed(2), 2, 2, NA, NA),
    pvt02_attempt_row(3, pvt02_m3_seed(3), 2, NA, fit_converged = FALSE)
  ))
  expect_silent(pvt02_validate_attempt_rows(rows, 1:3))
  out <- pvt02_summarise(rows, 1:3)
  expect_equal(out$n_attempted, 3)
  expect_equal(out$n_converged, 2)
  expect_equal(out$n_ci_failed, 1)
  expect_equal(out$coverage, 0.5)
  expect_equal(out$all_attempt_failure_fraction, 2 / 3)
  expect_error(pvt02_validate_attempt_rows(rows[-3, ], 1:3), "retain exactly")
  bad_seed <- rows
  bad_seed$seed <- 1L
  expect_error(pvt02_validate_attempt_rows(bad_seed, 1:3), "retained seeds")
})

test_that("promotion fails closed on wrong cell, insufficient attempts, and weak lower band", {
  cell <- list(
    family = "gaussian", tier = "unit", mode = "latent", unique = TRUE,
    d = 2L, n_units = 400L, target_scale = "log_V", level = 0.95
  )
  good <- list(n_attempted = 5000L, coverage = 0.947, lower_band = 0.941)
  expect_true(pvt02_promotion_verdict(cell, good, TRUE)$promote)
  expect_false(pvt02_promotion_verdict(cell, modifyList(good, list(n_attempted = 4999L)), TRUE)$promote)
  expect_false(pvt02_promotion_verdict(cell, modifyList(good, list(lower_band = 0.939)), TRUE)$promote)
  expect_false(pvt02_promotion_verdict(modifyList(cell, list(n_units = 150L)), good, TRUE)$promote)
  expect_false(pvt02_promotion_verdict(modifyList(cell, list(unique = FALSE)), good, TRUE)$promote)
  expect_false(pvt02_promotion_verdict(cell, good, FALSE)$promote)
})
