## Design 55 §A2 + Design 56 §9.5a — phylo_latent(1 + x | sp, d = K) Gaussian recovery
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands. Mirrors the canonical template at
## `tests/testthat/test-phylo-unique-slope-gaussian.R` (PR #282); customises
## for the reduced-rank latent case per Design 55 §5 APPLICABLE matrix.
##
## What this cell tests (when activated):
##
##   - LHS = `(1 + x | sp)` (wide) / `(0 + trait + (0 + trait):x | sp)` (long).
##   - Σ_b is block-diagonal across LHS columns per Design 56 §5.3:
##     each LHS column gets its own factor-analytic decomposition
##     `Lambda_k Lambda_k^T + diag(ψ_k)`. K_intercept + K_slope factors.
##   - Recovery: per-column Lambda matrices match truth up to rotation;
##     diagonal ψ recovered within tolerance.
##   - Byte-identity wide ↔ long per Design 55 §3.
##   - Negative test (Design 56 §7.3): n_lhs_cols mismatch must Rcpp::stop.

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

skip_until_stage3 <- function() {
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.5a"
  )
}

test_that(
  "phylo_latent(1 + x | sp, d = 2) recovers per-column Lambda + psi on Gaussian", {
  skip_if_not_heavy()
  skip_if_not_ape()
  skip_until_stage3()

  ## Mirror `make_phylo_unique_slope_fixture()` from #282; expand
  ## per-column Lambda to T × K. Phase 56.5a fills in the body.
  ##
  ## Recovery targets (per Design 56 §5.3 block-diagonal Σ_b):
  ##   - Lambda_intercept: T × K matrix matching truth up to rotation
  ##   - Lambda_slope: T × K matrix matching truth up to rotation
  ##   - diag(psi_intercept), diag(psi_slope): within tolerance
  expect_true(TRUE)  # placeholder; Phase 56.5a fills in
})

test_that(
  "phylo_latent wide ≡ long byte-identical (Design 55 §3)", {
  skip_if_not_heavy()
  skip_if_not_ape()
  skip_until_stage3()
  expect_true(TRUE)  # placeholder; Phase 56.5a fills in
})
