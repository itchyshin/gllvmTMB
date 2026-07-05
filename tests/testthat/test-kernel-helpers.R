## Pure-R input-validation guards for make_cross_kernel() and its
## .cross_kernel_* helpers (R/kernel-helpers.R). These exercise the
## documented abort branches that are reachable without a fit or Julia.
## The abs(|rho|) > 1 and unit-diagonal branches are already covered in
## test-coevolution-prototype.R; the branches below are distinct.

## A valid 2x2 correlation matrix reused as a clean A_H / A_P argument.
.cor2 <- function(r = 0.25) matrix(c(1, r, r, 1), 2, 2)

## ---- make_cross_kernel() top-level guards ------------------------

test_that("make_cross_kernel() rejects non-finite / non-scalar rho", {
  ## T3
  expect_error(
    make_cross_kernel(.cor2(), .cor2(), matrix(1, 2, 2), rho = NA_real_),
    "must be one finite number", fixed = TRUE
  )
  expect_error(
    make_cross_kernel(.cor2(), .cor2(), matrix(1, 2, 2), rho = c(0.1, 0.2)),
    "must be one finite number", fixed = TRUE
  )
})

test_that("make_cross_kernel() rejects invalid eps", {
  ## T6
  expect_error(
    make_cross_kernel(.cor2(), .cor2(), matrix(1, 2, 2), rho = 0.4, eps = -1),
    "must be one positive finite number", fixed = TRUE
  )
})

test_that("make_cross_kernel() rejects W with incompatible dimensions", {
  ## T4: A_H and A_P are 2x2, so W must be 2x2; a 3x2 W is rejected.
  expect_error(
    make_cross_kernel(.cor2(), .cor2(), matrix(1, 3, 2), rho = 0.4),
    "has incompatible dimensions", fixed = TRUE
  )
})

test_that("make_cross_kernel() rejects non-unique host/partner names", {
  ## T7: a shared label across the two lineages collides after
  ## concatenation. Both matrices stay valid correlation matrices so the
  ## name-uniqueness guard is what fires.
  A_H <- .cor2()
  dimnames(A_H) <- list(c("x", "y"), c("x", "y"))
  A_P <- .cor2()
  dimnames(A_P) <- list(c("y", "z"), c("y", "z"))
  expect_error(
    make_cross_kernel(A_H, A_P, matrix(1, 2, 2), rho = 0.4),
    "unique after concatenation", fixed = TRUE
  )
})

## ---- .cross_kernel_as_matrix() guards ----------------------------

test_that(".cross_kernel_as_matrix() rejects a non-numeric-matrix input", {
  ## T8: a character scalar for A_H fails the matrix/numeric check.
  expect_error(
    make_cross_kernel("x", .cor2(), matrix(1, 2, 2)),
    "must be a numeric matrix", fixed = TRUE
  )
})

test_that(".cross_kernel_as_matrix() rejects non-finite entries", {
  ## T9
  A_bad <- matrix(c(1, Inf, Inf, 1), 2, 2)
  expect_error(
    make_cross_kernel(A_bad, .cor2(), matrix(1, 2, 2)),
    "finite, non-missing", fixed = TRUE
  )
})

test_that(".cross_kernel_as_matrix() rejects a non-square matrix", {
  ## T10
  expect_error(
    make_cross_kernel(matrix(1, 2, 3), .cor2(), matrix(1, 2, 2)),
    "must be square", fixed = TRUE
  )
})

## ---- .cross_kernel_check_correlation() guard ---------------------

test_that(".cross_kernel_check_correlation() rejects a non-symmetric matrix", {
  ## T11: a square, finite, unit-diagonal but asymmetric A_H.
  A_asym <- matrix(c(1, 0.3, 0.1, 1), 2, 2)
  expect_error(
    make_cross_kernel(A_asym, .cor2(), matrix(1, 2, 2)),
    "must be symmetric", fixed = TRUE
  )
})
