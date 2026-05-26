## Design 55 §A3 + Design 56 §9.5d-latent — animal_latent(1 + x | id) Gaussian recovery
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands. Mirrors `tests/testthat/test-phylo-unique-slope-gaussian.R`
## (PR #282); customises for the (animal × latent) cell per Design 55 §5.
##
## Σ_b shape per Design 56 §5.3: block-diagonal per LHS column (per-column Lambda factor-analytic).

skip_helper <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not(exists("pedigree_to_Ainv_sparse",
                              envir = asNamespace("gllvmTMB")))
}

skip_until_stage3 <- function() {
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.5d-latent"
  )
}

test_that(
  "animal_latent(1 + x | id) recovery: Σ_b per Design 56 §5.3 — block-diagonal per LHS column (per-column Lambda factor-analytic)", {
  skip_helper()
  skip_until_stage3()

  ## Mirror `make_phylo_unique_slope_fixture()` from #282; adapt the
  ## structural matrix (animal) and the keyword (latent) accordingly.
  ## Phase 56.5d-latent fills in the body.
  expect_true(TRUE)  # placeholder; Phase 56.5d-latent
})

test_that(
  "animal_latent wide ≡ long byte-identical (Design 55 §3)", {
  skip_helper()
  skip_until_stage3()
  expect_true(TRUE)  # placeholder; Phase 56.5d-latent
})
