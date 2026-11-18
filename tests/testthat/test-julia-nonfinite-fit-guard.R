# Follow-up to #1562: engine = "julia" must not return a non-converged bridge
# fit with a non-finite log-likelihood. Runs without Julia.

test_that("a non-converged, non-finite bridge result is never returned (#1562)", {
  expect_error(
    .gllvm_julia_check_fit_finite(list(loglik = -Inf, converged = FALSE)),
    class = "gllvmTMB_julia_nonfinite_fit"
  )
  expect_false(
    .gllvm_julia_check_fit_finite(list(loglik = -10, converged = FALSE))
  )
  expect_false(
    .gllvm_julia_check_fit_finite(list(loglik = -10, converged = TRUE))
  )
})
