## Design 55 §A2 + Design 56 §9.5c — phylo_dep(1 + x | sp) Gaussian recovery
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands. Mirrors `tests/testthat/test-phylo-unique-slope-gaussian.R`
## (PR #282); customises for the full-unstructured Σ_b case per Design 55 §5.
##
## What this cell tests (when activated):
##
##   - LHS = `(1 + x | sp)` (wide) / `(0 + trait + (0 + trait):x | sp)` (long).
##   - Σ_b is full unstructured 2T × 2T per Design 56 §5.3:
##     UNSTRUCTURED_CORR machinery + Cholesky-decomposed parameterisation.
##   - Recovery: T × T cross-trait covariance for intercepts, T × T for
##     slopes, T × T for intercept-slope cross-covariances.
##   - Byte-identity wide ↔ long per Design 55 §3.

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

skip_until_stage3 <- function() {
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.5c"
  )
}

test_that(
  "phylo_dep(1 + x | sp) recovers 2T × 2T unstructured Σ_b on Gaussian", {
  skip_if_not_ape()
  skip_until_stage3()

  ## phylo_dep at full rank is the saturated case — Phase 56.5c
  ## needs special care because UNSTRUCTURED_CORR over 2T params
  ## may surface identification issues at small n_sp.
  ##
  ## Recovery: Cholesky factor of the full 2T × 2T covariance
  ## within tolerance. At small T this is exact; at T ≥ 4 we may
  ## need to increase n_sp or relax tolerance.
  expect_true(TRUE)  # placeholder; Phase 56.5c fills in
})

test_that(
  "phylo_dep wide ≡ long byte-identical (Design 55 §3)", {
  skip_if_not_ape()
  skip_until_stage3()
  expect_true(TRUE)  # placeholder
})
