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

  ## A fit that never reported eta cannot be failed on eta -- but the result
  ## must SAY so, so a caller can tell "eta agreed" from "eta was never checked".
  res <- .vgh_compare_optima(fit_cold, fit_warm_no_eta)
  expect_false(res$eta_checked)
  expect_true(is.na(res$eta_max_absdiff))
  expect_true(res$identical_optimum)
})

test_that("g_eigen vectors are returned in descending order", {
  base <- .vgh_verify_fixture()
  fit_cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  fit_warm <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)

  res <- .vgh_compare_optima(fit_cold, fit_warm)
  expect_equal(res$g_eigen_cold, sort(res$g_eigen_cold, decreasing = TRUE))
  expect_equal(res$g_eigen_warm, sort(res$g_eigen_warm, decreasing = TRUE))
})

## ---------------------------------------------------------------------------
## Regression tests for six defects found by adversarial review, 2026-07-29.
## Each uses the exact input that the earlier implementation certified wrongly,
## so each of these fails against that version. The harness passed its own
## 8-block suite while carrying all six -- which is why these are written from
## the refutation, not from the implementation.
## ---------------------------------------------------------------------------

test_that("DEFECT 1: two fits that BOTH failed to converge are not the same optimum", {
  base <- .vgh_verify_fixture()
  ## Identical in every respect except that neither converged.
  bad <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 100,
                              convergence = 1L, pdHess = FALSE)
  res <- .vgh_compare_optima(bad, bad)
  ## Old code tested identical(cold, warm) -- equality of flags, not truth.
  expect_false(res$identical_optimum)
  expect_match(res$verdict, "not both converged")

  ## And a fit carrying NO convergence evidence at all must not pass either:
  ## absent must not collapse to FALSE and then compare equal.
  silent <- list(opt = list(objective = 100),
                 report = list(Lambda_B = base$Lambda, eta = base$eta))
  expect_true(is.na(.vgh_read_converged(silent)))
  expect_false(.vgh_compare_optima(silent, silent)$identical_optimum)
})

test_that("DEFECT 2: a disagreeing second loading tier is not invisible", {
  base <- .vgh_verify_fixture()
  LW <- matrix(stats::rnorm(8), 4L, 2L)

  cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  warm <- cold
  cold$report$Lambda_W <- LW
  warm$report$Lambda_W <- LW * 100      # W-tier g_rel_frob ~ 9999

  res <- .vgh_compare_optima(cold, warm)
  expect_false(res$identical_optimum)
  expect_true("Lambda_W" %in% res$tiers)
  expect_gt(res$g_rel_frob_by_tier[["Lambda_W"]], 100)

  ## A tier present in one fit but not the other is a comparison error, not a pass.
  warm2 <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  expect_error(.vgh_compare_optima(cold, warm2), "loading tiers")
})

test_that("DEFECT 3: eta is load-bearing, not computed and discarded", {
  base <- .vgh_verify_fixture()
  Z2 <- matrix(stats::rnorm(length(base$Z)), nrow(base$Z), ncol(base$Z))

  cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 100)
  ## Same Lambda, same objective, but an independent eta: at equal parameters
  ## the conditional modes are determined, so this is a different point.
  warm <- .vgh_verify_make_fit(base$Lambda, tcrossprod(Z2, base$Lambda),
                               objective = 100)

  res <- .vgh_compare_optima(cold, warm)
  expect_true(res$eta_checked)
  expect_gt(res$eta_max_absdiff, 1e-3)
  expect_false(res$identical_optimum)
  expect_match(res$verdict, "eta differs")
})

test_that("DEFECT 4: a non-finite eta errors rather than returning NA silently", {
  base <- .vgh_verify_fixture()
  cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  warm <- cold
  warm$report$eta[1L, 1L] <- NA_real_
  expect_error(.vgh_compare_optima(cold, warm), "Non-finite")
})

test_that("DEFECT 5: identified parameters outside Lambda are compared", {
  base <- .vgh_verify_fixture()
  cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = 1)
  warm <- cold
  ## A 100-fold difference in the diagonal/Psi tier, everything else equal.
  cold$opt$par <- c(b_fix = 1, theta_diag_B = 1, theta_rr_B = 0.3)
  warm$opt$par <- c(b_fix = 1, theta_diag_B = 100, theta_rr_B = 0.3)
  res <- .vgh_compare_optima(cold, warm)
  expect_false(res$identical_optimum)
  expect_match(res$verdict, "identified parameters differ")

  ## theta_rr_* is EXCLUDED on purpose: a loading-column sign flip is the
  ## rotation/sign ambiguity, is invisible in eta and G, and must not be
  ## reported as a different optimum.
  warm2 <- cold
  warm2$opt$par <- c(b_fix = 1, theta_diag_B = 1, theta_rr_B = -0.3)
  expect_true(.vgh_compare_optima(cold, warm2)$identical_optimum)
})

test_that("DEFECT 6: the loglik tolerance is relative, not scale-blind", {
  base <- .vgh_verify_fixture()
  ## A realistic objective with a 1e-9 RELATIVE gap -- inside optimiser noise.
  ## Absolute |diff| here is 1.2e-4, which an absolute 1e-6 tolerance rejects.
  obj <- -1.234e5
  cold <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = obj)
  warm <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = obj * (1 + 1e-9))

  res <- .vgh_compare_optima(cold, warm)
  expect_gt(res$loglik_absdiff, 1e-5)     # absolute gap is large...
  expect_lt(res$loglik_reldiff, 1e-8)     # ...but relative gap is tiny
  expect_true(res$identical_optimum)

  ## A genuinely different optimum at the same scale is still caught.
  far <- .vgh_verify_make_fit(base$Lambda, base$eta, objective = obj * (1 + 1e-3))
  expect_false(.vgh_compare_optima(cold, far)$identical_optimum)
})
