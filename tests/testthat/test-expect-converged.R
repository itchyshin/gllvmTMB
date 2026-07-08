## Tests of the test helper `expect_converged()` (tests/testthat/setup.R).
##
## The helper exists because `fit$opt$convergence` is nlminb's PORT stopping code,
## not a verdict on the optimum, and which code it returns can flip with the
## collation locale (see the long note in setup.R). It must therefore accept PORT's
## benign "false convergence (8)" -- but ONLY when the gradient is genuinely small.
##
## A guard that cannot fail proves nothing, so these are the power tests. No model
## fits here: `expect_converged()` only touches `$opt` and `$tmb_obj$gr`.

fake_fit <- function(convergence, message = "", grad = 1e-6) {
  list(
    opt = list(convergence = convergence, message = message, par = c(a = 0)),
    tmb_obj = list(gr = function(par) grad)
  )
}

test_that("expect_converged() accepts a clean convergence", {
  expect_success(expect_converged(fake_fit(0L, "relative convergence (4)", 1e-6)))
  ## convergence 0 is accepted regardless of gradient -- the optimiser said so.
  expect_success(expect_converged(fake_fit(0L, "relative convergence (4)", 1e3)))
})

test_that("expect_converged() accepts PORT 'false convergence' ONLY with a small gradient", {
  ## The real case: nlminb stops on a flat surface but the gradient is small.
  expect_success(
    expect_converged(fake_fit(1L, "false convergence (8)", 1.95e-2))
  )
  ## Same status code, but a large gradient -- this is a genuinely bad stop.
  expect_failure(
    expect_converged(fake_fit(1L, "false convergence (8)", 5.0))
  )
})

test_that("expect_converged() rejects real non-convergence", {
  ## convergence 1 with a different PORT message is not the benign flat-surface case.
  expect_failure(
    expect_converged(fake_fit(1L, "iteration limit reached without convergence (10)", 1e-6))
  )
  ## Any other non-zero status is rejected outright.
  expect_failure(expect_converged(fake_fit(2L, "singular convergence (7)", 1e-6)))
  expect_failure(expect_converged(fake_fit(51L, "", 1e-6)))
})

test_that("expect_converged() rejects a fit whose gradient cannot be evaluated", {
  bad <- fake_fit(1L, "false convergence (8)")
  bad$tmb_obj$gr <- function(par) stop("boom")
  ## gmax becomes NA -> isTRUE(NA < tol) is FALSE -> fails, rather than passing silently.
  expect_failure(expect_converged(bad))
})

test_that("expect_converged() honours grad_tol", {
  expect_failure(expect_converged(fake_fit(1L, "false convergence (8)", 0.5), grad_tol = 0.1))
  expect_success(expect_converged(fake_fit(1L, "false convergence (8)", 0.5), grad_tol = 1.0))
})
