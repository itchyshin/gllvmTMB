## Coverage (cursor-cloud-1125x7g): R/mspl-curvature-pin.R, R/vgh-verify.R, R/rotate-loadings.R.

.make_fit_stub <- function(par = c(b = 1, theta_diag_a = 0.2),
                           class = "gllvmTMB_multi") {
  structure(
    list(
      opt = list(objective = -10, convergence = 0L, par = par),
      sd_report = list(pdHess = TRUE),
      report = list(Lambda_B = matrix(c(0.2, 0.1), nrow = 2))
    ),
    class = class
  )
}

test_that(".gllvmTMB_mspl_numerical_hessian_status rejects bad objective", {
  out <- gllvmTMB:::.gllvmTMB_mspl_numerical_hessian_status(NULL, 1)
  expect_equal(out$status, "error")
  out2 <- gllvmTMB:::.gllvmTMB_mspl_numerical_hessian_status(list(fn = NULL), 1)
  expect_equal(out2$status, "error")
})

test_that(".gllvmTMB_mspl_numerical_hessian_status rejects non-finite par", {
  obj <- list(fn = function(x) 0, gr = function(x) 0)
  out <- gllvmTMB:::.gllvmTMB_mspl_numerical_hessian_status(obj, c(NA, 1))
  expect_equal(out$status, "nonfinite")
})

test_that(".gllvmTMB_mspl_pin_family_link reads family from list", {
  fit <- list(
    family = stats::poisson(),
    mspl = list(family = "poisson")
  )
  pin <- gllvmTMB:::.gllvmTMB_mspl_pin_family_link(fit)
  expect_equal(pin$family, "poisson")
  expect_equal(pin$link, "log")
})

test_that(".vgh_read_loglik returns negative objective", {
  fit <- .make_fit_stub()
  expect_equal(gllvmTMB:::.vgh_read_loglik(fit, "fit"), 10)
})

test_that(".vgh_read_loglik errors on bad objective", {
  fit <- list(opt = list(objective = c(1, 2)))
  expect_error(gllvmTMB:::.vgh_read_loglik(fit, "fit"), "opt\\$objective")
})

test_that(".vgh_read_converged respects optimizer and pdHess", {
  fit <- .make_fit_stub()
  expect_true(gllvmTMB:::.vgh_read_converged(fit))
  fit2 <- list(opt = list(convergence = 1L), sd_report = list(pdHess = TRUE))
  expect_true(gllvmTMB:::.vgh_read_converged(fit2))
  fit3 <- list(opt = list(), sd_report = list())
  expect_true(is.na(gllvmTMB:::.vgh_read_converged(fit3)))
})

test_that(".vgh_compare_params ignores rotation-ambiguous blocks", {
  cold <- .make_fit_stub(c(b = 1, theta_rr_1 = 0.5, theta_diag_a = 0.2))
  warm <- .make_fit_stub(c(b = 1.0001, theta_rr_1 = -0.5, theta_diag_a = 0.2001))
  cmp <- gllvmTMB:::.vgh_compare_params(cold, warm)
  expect_gt(cmp$param_compared, 0L)
  expect_lt(cmp$param_rel_maxdiff, 0.01)
})

test_that(".vgh_find_lambdas collects Lambda_B", {
  fit <- .make_fit_stub()
  mats <- gllvmTMB:::.vgh_find_lambdas(fit, "fit")
  expect_true("Lambda_B" %in% names(mats))
  expect_equal(nrow(mats$Lambda_B), 2L)
})

test_that("compare_loadings rotates aligned matrices to zero distance", {
  L <- matrix(c(1, 0.2, 0.1, 0.9), 2, 2)
  R <- matrix(c(0.6, -0.8, 0.8, 0.6), 2, 2)
  B <- L %*% R
  out <- compare_loadings(L, B)
  expect_lt(out$frobenius, 1e-10)
  expect_length(out$cor_per_factor, 2L)
})

test_that("compare_loadings validates dimensions", {
  expect_error(compare_loadings(matrix(1), 1), "matrices")
  expect_error(compare_loadings(matrix(1, 2, 1), matrix(1, 3, 1)), "dimensions")
})