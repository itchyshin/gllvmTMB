## Design 55 §A5 + Design 56 §9.5f — phylo_unique(1 + x | id, vcv = A_user) Gaussian
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands. Mirrors `tests/testthat/test-phylo-unique-slope-gaussian.R`
## (PR #282); customises for the user-supplied-A path ("relmat") per Design 55
## §A5. This is the most general path — phylo_*(vcv = A) accepts any
## positive-definite relatedness matrix.
##
## What this cell tests (when activated):
##
##   - LHS = `(1 + x | id)` (wide) / `(0 + trait + (0 + trait):x | id)` (long).
##   - `A_user` is supplied directly via `phylo_unique(id, vcv = A_user)`;
##     no tree, no pedigree — pure matrix path.
##   - Recovery: same (σ²_α, σ²_β, ρ) as the tree-derived path per
##     Design 14 §5 byte-equivalence (the matrix is the matrix; the
##     engine doesn't care where it came from).
##   - Edge case: when `A_user` is sparse (dgCMatrix), the engine takes
##     the sparse Ainv path; when dense, the dense Ainv path. Recovery
##     should be identical to TMB tolerance.

skip_if_no_matrix_helpers <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("Matrix")
}

skip_until_stage3 <- function() {
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.5f"
  )
}

test_that(
  "phylo_unique(1 + x | id, vcv = A_user) recovers Σ_b on Gaussian (dense path)", {
  skip_if_no_matrix_helpers()
  skip_until_stage3()

  ## Phase 56.5f: build a small random positive-definite A_user,
  ## simulate from the (intercept, slope) bivariate prior with that A,
  ## recover the 2×2 Σ_b. Mirror #282's fixture.
  expect_true(TRUE)  # placeholder; Phase 56.5f fills in
})

test_that(
  "phylo_unique(1 + x | id, vcv = A_user_sparse) recovers Σ_b on Gaussian (sparse path)", {
  skip_if_no_matrix_helpers()
  skip_until_stage3()

  ## Same as above but A_user is a sparse dgCMatrix (e.g. block-diagonal
  ## relatedness). Sparse Ainv engine path must agree with dense path
  ## to TMB tolerance.
  expect_true(TRUE)  # placeholder; Phase 56.5f fills in
})

test_that(
  "phylo_unique wide ≡ long byte-identical with user-supplied A (Design 55 §3)", {
  skip_if_no_matrix_helpers()
  skip_until_stage3()
  expect_true(TRUE)  # placeholder; Phase 56.5f fills in
})
