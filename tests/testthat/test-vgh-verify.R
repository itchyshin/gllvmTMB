## Rotation-invariant verification harness for the VGH -> Laplace warm-start
## (Phase 2). Fixtures are generated INLINE, matching test-vgh-oracle.R's own
## note: nothing here may read from docs/, which .Rbuildignore excludes.
##
## The negative control is the whole point: a "fit_cold" / "fit_warm" pair
## whose Lambda differ ONLY by an orthogonal rotation Q must be reported as
## the SAME optimum (rotation is not evidence of a different optimum), while a
## pair at genuinely different loglik/G must be reported as DIFFERENT. A
## harness built on raw elementwise Lambda comparison would fail the first
## case (Lambda_cold != Lambda_warm elementwise, by construction) and this
## test asserts that gap explicitly before checking the real harness closes it.

.vgh_verify_fixture <- function(n_traits = 4L, rank = 2L, n_units = 6L,
                                 seed = 20260730L) {
  set.seed(seed)
  Lambda <- matrix(stats::rnorm(n_traits * rank), n_traits, rank)
  Z <- matrix(stats::rnorm(n_units * rank), n_units, rank)
  list(Lambda = Lambda, Z = Z, eta = tcrossprod(Z, Lambda))
}

## A proper orthogonal (rotation, not reflection) 2x2 matrix.
.vgh_verify_rotation2 <- function(theta) {
  matrix(c(cos(theta), sin(theta), -sin(theta), cos(theta)), nrow = 2L)
}

.vgh_verify_make_fit <- function(Lambda, eta, objective, convergence = 0L,
                                  pdHess = TRUE) {
  list(
    opt = list(objective = objective, convergence = convergence),
    sd_report = list(pdHess = pdHess),
    report = list(Lambda_B = Lambda, eta = eta)
  )
}

test_that("same optimum, Lambda differing only by rotation: identical_optimum is TRUE", {
  base <- .vgh_verify_fixture()
  Q <- .vgh_verify_rotation2(pi / 7)

  Lambda_warm <- base$Lambda %*% Q
  Z_warm <- base$Z %*% Q
  eta_warm <- tcrossprod(Z_warm, Lambda_warm)

  ## Sanity check on the fixture itself: the rotation must actually move
  ## Lambda elementwise (else this would not be a negative control at all --
  ## an elementwise-Lambda harness needs something to fail on).
  expect_gt(max(abs(base$Lambda - Lambda_warm)), 0.1)
  ## ... but must leave G = Lambda Lambda' and eta untouched (up to fp noise).
  expect_equal(tcrossprod(Lambda_warm), tcrossprod(base$Lambda), tolerance = 1e-10)
  expect_equal(eta_warm, base$eta, tolerance = 1e-10)

  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 123.456)
  fit_warm <- .vgh_verify_make_fit(Lambda_warm, eta_warm, objective = 123.456)

  res <- .vgh_compare_optima(fit_cold, fit_warm)

  expect_true(res$identical_optimum)
  expect_equal(res$loglik_absdiff, 0, tolerance = 1e-12)
  expect_lt(res$g_rel_frob, 1e-8)
  expect_lt(res$g_eigen_max_absdiff, 1e-8)
  expect_lt(res$eta_max_absdiff, 1e-8)
  expect_true(res$converged_cold)
  expect_true(res$converged_warm)
  expect_type(res$verdict, "character")
})

test_that("genuinely different optima: identical_optimum is FALSE", {
  base <- .vgh_verify_fixture()

  ## A different loading matrix (not a rotation of base$Lambda: G differs)
  ## paired with a different objective and a non-matching eta.
  Lambda_diff <- base$Lambda + 5
  Z_diff <- base$Z
  eta_diff <- tcrossprod(Z_diff, Lambda_diff)

  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 123.456)
  fit_diff <- .vgh_verify_make_fit(Lambda_diff, eta_diff, objective = 210.0,
                                     convergence = 0L, pdHess = TRUE)

  res <- .vgh_compare_optima(fit_cold, fit_diff)

  expect_false(res$identical_optimum)
  expect_gt(res$loglik_absdiff, 1e-6)
  expect_gt(res$g_rel_frob, 1e-6)
  expect_type(res$verdict, "character")
})

test_that("convergence disagreement alone forces identical_optimum FALSE", {
  base <- .vgh_verify_fixture()
  Q <- .vgh_verify_rotation2(pi / 5)
  Lambda_warm <- base$Lambda %*% Q
  eta_warm <- tcrossprod(base$Z %*% Q, Lambda_warm)

  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 50,
                                     convergence = 0L, pdHess = TRUE)
  fit_warm <- .vgh_verify_make_fit(Lambda_warm, eta_warm, objective = 50,
                                     convergence = 1L, pdHess = FALSE)

  res <- .vgh_compare_optima(fit_cold, fit_warm)

  expect_false(res$converged_warm)
  expect_false(res$identical_optimum)
})

test_that("shape mismatch in Lambda fails loudly, not with NA", {
  base <- .vgh_verify_fixture()
  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  Lambda_bad <- matrix(stats::rnorm(4L * 3L), 4L, 3L)
  fit_bad <- .vgh_verify_make_fit(Lambda_bad, NULL, objective = 1)

  expect_error(.vgh_compare_optima(fit_cold, fit_bad), "different shapes")
})

test_that("mismatched tiers (Lambda_B vs Lambda_W) fail loudly", {
  base <- .vgh_verify_fixture()
  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  fit_w_tier <- list(
    opt = list(objective = 1, convergence = 0L),
    sd_report = list(pdHess = TRUE),
    report = list(Lambda_W = base$Lambda, eta = base$eta)
  )

  expect_error(.vgh_compare_optima(fit_cold, fit_w_tier), "tier")
})

test_that("missing loglik fails loudly rather than returning NA", {
  base <- .vgh_verify_fixture()
  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  fit_no_obj <- list(
    opt = list(objective = NULL, convergence = 0L),
    sd_report = list(pdHess = TRUE),
    report = list(Lambda_B = base$Lambda, eta = base$eta)
  )

  expect_error(.vgh_compare_optima(fit_cold, fit_no_obj), "opt\\$objective")
})

test_that("eta comparison is included when both fits expose it, omitted when not", {
  base <- .vgh_verify_fixture()
  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  fit_warm_no_eta <- list(
    opt = list(objective = 1, convergence = 0L),
    sd_report = list(pdHess = TRUE),
    report = list(Lambda_B = base$Lambda)  # no eta
  )

  res <- .vgh_compare_optima(fit_cold, fit_warm_no_eta)
  expect_null(res$eta_max_absdiff)
  expect_true(res$identical_optimum)  # eta is not load-bearing
})

test_that("g_eigen vectors are returned in descending order", {
  base <- .vgh_verify_fixture()
  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  fit_warm <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)

  res <- .vgh_compare_optima(fit_cold, fit_warm)
  expect_equal(res$g_eigen_cold, sort(res$g_eigen_cold, decreasing = TRUE))
  expect_equal(res$g_eigen_warm, sort(res$g_eigen_warm, decreasing = TRUE))
})
