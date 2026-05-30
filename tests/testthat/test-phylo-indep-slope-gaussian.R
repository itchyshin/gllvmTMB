## Design 55 §A2 + Design 56 §9.5b — phylo_indep(1 + x | sp) Gaussian recovery
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands. Mirrors `tests/testthat/test-phylo-unique-slope-gaussian.R`
## (PR #282); customises for the diagonal-Σ_b case per Design 55 §5.
##
## What this cell tests (when activated):
##
##   - LHS = `(1 + x | sp)` (wide) / `(0 + trait + (0 + trait):x | sp)` (long).
##   - Σ_b is **diagonal** per Design 56 §5.3:
##     `cov(intercept, slope) = 0` is the model contract (not just truth).
##     ρ parameter is **map**-pinned to zero in TMB.
##   - Recovery: σ²_intercept, σ²_slope, plus an assertion that cov=0
##     in the fit (model is constrained, not estimating cov).
##   - Byte-identity wide ↔ long per Design 55 §3.

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

skip_until_stage3 <- function() {
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.5b"
  )
}

test_that(
  "phylo_indep(1 + x | sp) recovers σ²_int, σ²_slope on Gaussian; cov pinned to 0", {
  skip_if_not_heavy()
  skip_if_not_ape()
  skip_until_stage3()

  ## DGP must have true cov = 0 (independent intercept + slope per
  ## species). Recovery test asserts:
  ##   - σ²_intercept hat ≈ truth (within 20%)
  ##   - σ²_slope hat ≈ truth
  ##   - cov hat is map-pinned to 0 (not estimated)
  ##
  ## Negative test (Design 56 §7.3): asking phylo_indep to model
  ## `cor_b != 0` should not be permitted at the parser level.
  expect_true(TRUE)  # placeholder; Phase 56.5b fills in
})

test_that(
  "phylo_indep wide ≡ long byte-identical (Design 55 §3)", {
  skip_if_not_heavy()
  skip_if_not_ape()
  skip_until_stage3()
  expect_true(TRUE)  # placeholder
})
