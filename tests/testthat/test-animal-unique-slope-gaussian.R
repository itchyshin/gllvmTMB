## Design 55 §A3 + Design 56 §9.5d — animal_unique(1 + x | id) Gaussian recovery
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands. Mirrors `tests/testthat/test-phylo-unique-slope-gaussian.R`
## (PR #282); animal_* family per Design 14 §5 byte-equivalence
## (`animal_X(id, pedigree = ped) ≡ phylo_X(id, vcv = pedigree_to_A(ped))`).
##
## What this cell tests (when activated):
##
##   - LHS = `(1 + x | id)` (wide) / `(0 + trait + (0 + trait):x | id)` (long).
##   - Byte-equivalence with `phylo_unique(1 + x | id, vcv = pedigree_to_A(ped))`
##     per Design 14 §5 — same point estimates, same logLik to 1e-6.
##   - Sparse Ainv path: pedigree_to_Ainv_sparse() → engine reuses
##     phylo_unique 2×2 covariance machinery without animal-specific code.
##   - Recovery: σ²_α (additive genetic intercept variance),
##     σ²_β (slope variance = G_β for the random-regression slope),
##     cov(α, β) — the quantitative-genetic reaction-norm parameters.

skip_until_stage3 <- function() {
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.5d"
  )
}

skip_if_no_pedigree_helpers <- function() {
  testthat::skip_on_cran()
  ## animal_unique requires a relatedness matrix path; either
  ## `pedigree_to_A()` or `pedigree_to_Ainv_sparse()` must be available.
  testthat::skip_if_not(exists("pedigree_to_Ainv_sparse",
                              envir = asNamespace("gllvmTMB")))
}

test_that(
  "animal_unique(1 + x | id, pedigree = ped) recovers G + cov on Gaussian", {
  skip_if_not_heavy()
  skip_if_no_pedigree_helpers()
  skip_until_stage3()

  ## Phase 56.5d builds a small pedigree + recovers (σ²_α, σ²_β, ρ).
  ## Mirror the random-regression / reaction-norm canonical test in
  ## quantitative genetics (Henderson; Lynch & Walsh).
  expect_true(TRUE)  # placeholder; Phase 56.5d fills in
})

test_that(
  "animal_unique(1 + x | id, pedigree = ped) ≡ phylo_unique(1 + x | id, vcv = A) (Design 14 §5)", {
  skip_if_not_heavy()
  skip_if_no_pedigree_helpers()
  skip_until_stage3()

  ## Byte-equivalence with the user-supplied-A path:
  ##   fit1: animal_unique(1 + x | id, pedigree = ped)
  ##   fit2: phylo_unique(1 + x | id, vcv = pedigree_to_A(ped))
  ## must agree on logLik to the unit + Σ to 1e-6 per Design 14 §5.
  expect_true(TRUE)  # placeholder; Phase 56.5d fills in
})
