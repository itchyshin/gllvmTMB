## Instrumentation contract for the constrained-refit driver (issue #813).
##
## `.fix_and_refit_nll()` used to compute the ACHIEVED constraint value and the
## refit's convergence status and then throw both away, collapsing every failure
## mode to a bare NA -- which is why the stated reason the public nonlinear
## profile routes were withdrawn ("could accept loose constraints and
## unconverged refits") could not be checked from any output.
##
## Two things need pinning, and both are cheap, so they live in the LIGHT tier
## where CI can actually see them -- every curve test in
## test-profile-derived-curves.R is `skip_if_not_heavy()`.

test_that("the default return contract is still a bare numeric", {
  ## Every pre-#813 caller passes no `.details` and must still get a scalar.
  ## `.profile_curve_grid(.details = FALSE)` vapply()s over `numeric(1)`, so a
  ## list return would error there rather than degrade quietly.
  fm <- formals(gllvmTMB:::.fix_and_refit_nll)
  expect_true(".details" %in% names(fm))
  expect_false(eval(fm$.details))
})

test_that("the accepted constraint tolerance is named, not inlined", {
  ## The withdrawal reason is a claim about THIS number. It is 5% of the whole
  ## parameter range for a target on [0, 1] such as communality, so it must be
  ## greppable and reportable rather than buried in a comparison.
  expect_true(is.numeric(gllvmTMB:::.fix_and_refit_constraint_tol))
  expect_length(gllvmTMB:::.fix_and_refit_constraint_tol, 1L)
})

test_that(".profile_curve_grid(.details = TRUE) returns the documented frame", {
  ## Shape contract only -- mocked, so no fit and no TMB, and therefore visible
  ## to CI. The columns are what a calibration harness needs in order to discard
  ## refits that missed their constraint; dropping one silently would put us
  ## back where #813 started.
  fake <- function(fit, target_fn, q_0, lambda = 1e6, ...) {
    dots <- list(...)
    if (!isTRUE(dots$.details)) {
      return(q_0 * 2)
    }
    list(
      nll = q_0 * 2,
      achieved = q_0 + 1e-6,
      constraint_error = 1e-6,
      converged = TRUE,
      status = "ok",
      par = c(1, 2)
    )
  }
  testthat::local_mocked_bindings(.fix_and_refit_nll = fake, .package = "gllvmTMB")

  grid <- c(0.1, 0.2, 0.3)

  plain <- gllvmTMB:::.profile_curve_grid(NULL, identity, grid)
  expect_type(plain, "double")
  expect_length(plain, 3L)

  det <- gllvmTMB:::.profile_curve_grid(NULL, identity, grid, .details = TRUE)
  expect_s3_class(det, "data.frame")
  expect_equal(nrow(det), 3L)
  expect_true(all(
    c("objective", "achieved_value", "constraint_error",
      "refit_converged", "refit_status") %in% names(det)
  ))
  expect_type(det$refit_converged, "logical")
  expect_type(det$refit_status, "character")
  ## achieved_value must be the ACHIEVED value, never an echo of the request.
  expect_false(isTRUE(all.equal(det$achieved_value, grid)))
})
