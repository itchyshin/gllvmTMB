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

test_that("Julia bridge fits carry a convergence_status (SHINICHI-1434-1119)", {
  st <- .gllvm_julia_convergence_status
  expect_identical(st(list(loglik = -10, converged = TRUE)), "converged")
  expect_identical(st(list(loglik = -10, converged = FALSE)), "not_converged")
  expect_identical(st(list(loglik = -Inf, converged = TRUE)), "not_converged")
  expect_identical(
    st(list(loglik = -10, converged = TRUE, convergence_status = "boundary")),
    "boundary"
  )
  fit <- structure(
    list(loglik = -10, converged = TRUE, convergence_status = "converged"),
    class = c("gllvmTMB_julia", "list")
  )
  expect_identical(summary(fit)$header$convergence_status, "converged")
})

test_that("a restored warm-restart checkpoint never leaves an NA status", {
  fit <- list(fit_health = NULL)
  obj <- list(env = new.env())
  cp <- list(fit_health = list(convergence_status = "boundary"))
  out <- .gllvmTMB_restore_warm_restart_checkpoint(fit, obj, cp)
  expect_identical(out$fit_health$convergence_status, "boundary")
})
