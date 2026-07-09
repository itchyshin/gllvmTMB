## Tests of the test helpers `.fit_converged()` (predicate) and `expect_converged()`
## (assertion) in tests/testthat/setup.R.
##
## They exist because `fit$opt$convergence` and `pd_hessian` are second-order flags
## that lie (brain LESSONS 0c); the helpers delegate to the package's scale-free
## verdict `fit$fit_health$converged`. A guard that cannot fail proves nothing, so
## these are the power tests -- they must REJECT as well as ACCEPT. No model fits
## here: the helpers only read `$fit_health` (or fall back to `$opt` + `$tmb_obj$gr`).

fake_fit <- function(converged = NULL, scaled_gradient = NA_real_,
                     convergence = NA_integer_, pd_hessian = NA,
                     objective = NULL, grad = NULL) {
  fh <- list(converged = converged, scaled_gradient = scaled_gradient,
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

test_that(".fit_converged reads the package verdict", {
  expect_true(.fit_converged(fake_fit(converged = TRUE)))
  expect_false(.fit_converged(fake_fit(converged = FALSE)))
  ## The verdict is authoritative even when the raw flags disagree with it:
  ## converged despite a non-zero raw code and a non-PD Hessian (the benign ridge).
  expect_true(.fit_converged(fake_fit(converged = TRUE, convergence = 1L, pd_hessian = FALSE)))
  ## and NOT converged despite a clean raw code + PD (a fit that stopped short).
  expect_false(.fit_converged(fake_fit(converged = FALSE, convergence = 0L, pd_hessian = TRUE)))
})

test_that(".fit_converged is NA-safe: a missing/NA verdict is never a silent pass", {
  expect_false(.fit_converged(fake_fit(converged = NA)))
  ## No fit_health$converged at all, and no fallback material -> FALSE, not TRUE.
  expect_false(.fit_converged(list(fit_health = list())))
})

test_that(".fit_converged falls back to the scaled gradient when the verdict is absent", {
  ## fit_health$converged NULL -> recompute max|grad| / (1 + |objective|) < 1e-3.
  small <- fake_fit(converged = NULL, objective = 3.7e4, grad = 1.9e-2)  # scaled 5e-7
  big   <- fake_fit(converged = NULL, objective = 1e2,   grad = 5.0)     # scaled 5e-2
  expect_true(.fit_converged(small))
  expect_false(.fit_converged(big))
})

test_that("expect_converged passes on a good fit and fails on a bad one", {
  expect_success(expect_converged(fake_fit(converged = TRUE, scaled_gradient = 5e-7)))
  expect_failure(expect_converged(fake_fit(converged = FALSE, scaled_gradient = 5e-2)))
  ## benign ridge: converged TRUE though pd_hessian FALSE -> passes (the whole point).
  expect_success(expect_converged(
    fake_fit(converged = TRUE, scaled_gradient = 9e-7, convergence = 0L, pd_hessian = FALSE)))
})
