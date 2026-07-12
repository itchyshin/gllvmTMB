## Tests of the test helpers `.fit_stationary_for_recovery_test()` (predicate) and `expect_stationary_for_recovery_test()`
## (assertion) in tests/testthat/setup.R.
##
## They are deliberately narrow recovery-fixture guards over the objective-scaled
## stationarity diagnostic. They do not replace the public convergence and
## inference-health checks.

fake_fit <- function(converged = NULL, scaled_gradient = NA_real_,
                     convergence = NA_integer_, pd_hessian = NA,
                     objective = NULL, grad = NULL) {
  fh <- list(converged = converged,
             stationary_by_scaled_gradient = converged,
             scaled_gradient = scaled_gradient,
             convergence = convergence, pd_hessian = pd_hessian)
  out <- list(fit_health = fh)
  ## Optional raw pieces for exercising the fallback path (no fit_health$converged).
  if (!is.null(objective) || !is.null(grad)) {
    out$opt <- list(objective = objective %||% NA_real_, par = c(a = 0))
    out$tmb_obj <- list(gr = function(par) grad %||% NA_real_)
  }
  out
}
`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("the recovery helper reads the scaled-stationarity field", {
  expect_true(.fit_stationary_for_recovery_test(fake_fit(converged = TRUE)))
  expect_false(.fit_stationary_for_recovery_test(fake_fit(converged = FALSE)))
  ## The narrow recovery guard is independent of raw optimiser and Hessian flags.
  expect_true(.fit_stationary_for_recovery_test(fake_fit(converged = TRUE, convergence = 1L, pd_hessian = FALSE)))
  ## and NOT converged despite a clean raw code + PD (a fit that stopped short).
  expect_false(.fit_stationary_for_recovery_test(fake_fit(converged = FALSE, convergence = 0L, pd_hessian = TRUE)))
})

test_that("the recovery helper is NA-safe", {
  expect_false(.fit_stationary_for_recovery_test(fake_fit(converged = NA)))
  ## No fit_health$converged at all, and no fallback material -> FALSE, not TRUE.
  expect_false(.fit_stationary_for_recovery_test(list(fit_health = list())))
})

test_that("the recovery helper falls back to the scaled gradient", {
  ## Missing field -> recompute the objective-scaled stationarity diagnostic.
  small <- fake_fit(converged = NULL, objective = 3.7e4, grad = 1.9e-2)  # scaled 5e-7
  big   <- fake_fit(converged = NULL, objective = 1e2,   grad = 5.0)     # scaled 5e-2
  expect_true(.fit_stationary_for_recovery_test(small))
  expect_false(.fit_stationary_for_recovery_test(big))
})

test_that("the recovery assertion passes and fails on its narrow signal", {
  expect_success(expect_stationary_for_recovery_test(fake_fit(converged = TRUE, scaled_gradient = 5e-7)))
  expect_failure(expect_stationary_for_recovery_test(fake_fit(converged = FALSE, scaled_gradient = 5e-2)))
  ## benign ridge: converged TRUE though pd_hessian FALSE -> passes (the whole point).
  expect_success(expect_stationary_for_recovery_test(
    fake_fit(converged = TRUE, scaled_gradient = 9e-7, convergence = 0L, pd_hessian = FALSE)))
})
