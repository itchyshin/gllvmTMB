## Design 55 §A5 + Design 56 §9.5f-latent — relmat_latent(1 + x | id) Gaussian recovery
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands. Mirrors `tests/testthat/test-phylo-unique-slope-gaussian.R`
## (PR #282); customises for the (relmat × latent) cell per Design 55 §5.
##
## Σ_b shape per Design 56 §5.3: block-diagonal per LHS column with user-supplied A.

skip_helper <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("Matrix")
}

skip_until_stage3 <- function() {
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.5f-latent"
  )
}

test_that(
  "relmat_latent(1 + x | id) recovery: Σ_b per Design 56 §5.3 — block-diagonal per LHS column with user-supplied A", {
  skip_if_not_heavy()
  skip_helper()
  skip_until_stage3()

  ## Mirror `make_phylo_unique_slope_fixture()` from #282; adapt the
  ## structural matrix (relmat) and the keyword (latent) accordingly.
  ## Phase 56.5f-latent fills in the body.
  expect_true(TRUE)  # placeholder; Phase 56.5f-latent
})

test_that(
  "relmat_latent wide ≡ long byte-identical (Design 55 §3)", {
  skip_if_not_heavy()
  skip_helper()
  skip_until_stage3()
  expect_true(TRUE)  # placeholder; Phase 56.5f-latent
})
