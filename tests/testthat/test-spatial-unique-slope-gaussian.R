## Design 55 §A4 + Design 56 §9.5e — spatial_unique(1 + x | coords) Gaussian recovery
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands. Mirrors `tests/testthat/test-phylo-unique-slope-gaussian.R`
## (PR #282); customises for the SPDE/GMRF spatial case per Design 55 §A4.
##
## What this cell tests (when activated):
##
##   - LHS = `(1 + x | coords)` (wide) / `(0 + trait + (0 + trait):x | coords)`
##     (long).
##   - Spatial structural matrix is the SPDE **precision** (sparse Q),
##     not a covariance — Kronecker decomposition Σ_b ⊗ A still applies
##     where A is the GMRF covariance implied by the precision.
##   - Per Design 56 §3.2 analogous-promotion table: spde block gets the
##     same 3D-array shape promotion as phylo block; no new structural
##     concept needed.
##   - Recovery: σ²_intercept, σ²_slope, cov(intercept, slope) at the
##     site-pair level; Matérn range/marginal-σ parameters from the
##     SPDE itself.
##   - Mesh sensitivity check: refit on a slightly denser mesh; verify
##     point estimates stable.

skip_if_not_spatial <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
}

skip_until_stage3 <- function() {
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.5e"
  )
}

test_that(
  "spatial_unique(1 + x | coords) recovers σ² + cov on Gaussian + SPDE precision", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  skip_until_stage3()

  ## Mirror `tests/testthat/test-spatial-latent-recovery.R` for the
  ## SPDE/mesh boilerplate, then add the intercept+slope LHS.
  ## Recovery: (σ²_α, σ²_β, ρ) + Matérn parameters (range, marginal σ).
  expect_true(TRUE)  # placeholder; Phase 56.5e fills in
})

test_that(
  "spatial_unique wide ≡ long byte-identical (Design 55 §3)", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  skip_until_stage3()
  expect_true(TRUE)  # placeholder; Phase 56.5e fills in
})

test_that(
  "spatial_unique slope LHS composes with SPDE precision (mesh-density invariance check)", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  skip_until_stage3()

  ## Refit on two mesh densities; point estimates of (σ²_α, σ²_β, ρ)
  ## should be stable to ≤ 5% across mesh densities. This is the
  ## spatial-specific identification check beyond what other cells need.
  expect_true(TRUE)  # placeholder; Phase 56.5e fills in
})
