# Phase 56.5 per-cell scoping notes — sample size + identifiability

**Maintained by:** Curie (simulation fidelity + sample-size choice),
Fisher (identifiability + SE behaviour), Noether (Σ_b shape vs
estimable parameter count), Shannon (cross-team coordination).
**Lead author:** Claude/Shannon on Ada's authorisation 2026-05-26
to produce docs/audit-only parallel work while Codex/Ada implements
Phase 56.1.
**Status:** Audit-only reference for Phase 56.5 recovery-test
activation. No engine code change; no test code change; no register
edit. Read by Codex when 56.5 activates the skeleton tests landed
in PRs #282 / #283 / #284.

## 1. Purpose

When Phase 56.1-56.3 engine work lands and Phase 56.4 activates the
`phylo_unique(1 + x | sp)` recovery test, Phase 56.5 walks the
remaining 15 of 16 APPLICABLE cells in Design 55 §5. Each cell needs
a sample-size choice + recovery-tolerance choice + identifiability
red-flag list. This memo lays those choices out per cell so the
56.5 PR author doesn't re-derive them.

The choices follow these constraints:

1. **Test runtime budget**: each recovery test runs under `skip_on_cran()`,
   but should complete in **< 90 s on a CI runner** (TMB compile +
   fit + extract); per-cell test should match `test-phylo-slope.R`
   timing budget (~2-5 min for the heavy fixture).
2. **Recovery tolerance**: σ² estimates within ±20 % of truth at
   `n_sp ≥ 50`; ρ estimates within ±0.30 of truth at `n_sp ≥ 60`.
   (Fisher: SE of `atanh(ρ)` scales as `1 / sqrt(n_sp)`; ρ tolerance
   widens as `n_sp` shrinks.)
3. **Identifiability minimum**: each cell needs enough groups that
   the 2×2 Σ_b is empirically identified (Fisher: 20 groups per
   LHS column is the lower bound for stable correlation estimates).

## 2. Per-cell sample-size + tolerance recommendations

For each APPLICABLE cell, recommended fixture size + tolerance + red
flags. **n_sp / n_id / n_coords**: group count. **T**: trait count.
**n_rep**: replicates per (group, trait) cell. Total rows = product.

### 2.1 `phylo_*` family (4 cells)

| Cell | n_sp | T | n_rep | Total rows | σ² tol | ρ tol | Red flags |
|---|---:|---:|---:|---:|---:|---:|---|
| `phylo_unique(1+x\|sp)` | 60 | 3 | 4 | 720 | ±20 % | ±0.30 | (the A1 canonical case, already in #282) |
| `phylo_latent(1+x\|sp, d=2)` | 80 | 4 | 4 | 1280 | ±25 % | n/a (block-diag) | per-column Lambda recovery up to rotation — verify against truth modulo varimax + sign-anchor; n_sp ≥ 80 because d=2 doubles the load-on-Lambda count |
| `phylo_indep(1+x\|sp)` | 50 | 3 | 4 | 600 | ±15 % | **fixed at 0** (map-pinned) | diagonal Σ_b is easier to estimate than full 2×2 — smaller n_sp acceptable; negative test: assert `cor_b` is mapped to NA in the fit |
| `phylo_dep(1+x\|sp)` | 80 | 3 | 4 | 720 | ±25 % | ±0.40 | full 2T × 2T unstructured Cholesky has T(T+1) - T = T² off-diagonal entries; ρ tolerance widens because per-pair correlation estimates have higher MCSE |

### 2.2 `animal_*` family (4 cells; byte-equiv with phylo per Design 14 §5)

| Cell | n_id | T | n_rep | Total rows | σ² tol | ρ tol | Red flags |
|---|---:|---:|---:|---:|---:|---:|---|
| `animal_unique(1+x\|id)` | 60 (≥ 3 generations) | 3 | 4 | 720 | ±20 % | ±0.30 | small pedigree at d=1 may give ρ near ±1; use 4-generation Henderson-style pedigree fixture |
| `animal_latent(1+x\|id, d=2)` | 80 (≥ 4 generations) | 4 | 4 | 1280 | ±25 % | n/a | factor-analytic decomposition needs more pedigree depth than `phylo_*` because pedigree A-matrix has more sparse structure than tree VCV |
| `animal_indep(1+x\|id)` | 50 | 3 | 4 | 600 | ±15 % | fixed at 0 | smallest fixture; the diagonal constraint helps small-pedigree identification |
| `animal_dep(1+x\|id)` | 80 (≥ 4 generations) | 3 | 4 | 720 | ±25 % | ±0.40 | full unstructured + sparse A combination may surface Cholesky-conditioning issues — verify pdHess + SE before declaring recovery |

Plus byte-equivalence test per cell: `animal_X(id, pedigree=ped) ≡
phylo_X(id, vcv=pedigree_to_A(ped))` per Design 14 §5.

### 2.3 `spatial_*` family (4 cells; SPDE precision)

| Cell | n_coords (mesh) | T | n_rep | Total rows | σ² tol | ρ tol | Red flags |
|---|---:|---:|---:|---:|---:|---:|---|
| `spatial_unique(1+x\|coords)` | 100 sites + mesh n=200 | 3 | 4 | 1200 | ±25 % | ±0.35 | Matérn range + marginal σ are estimated *jointly* with Σ_b; tolerance widens because of the extra degrees of freedom; verify mesh-density invariance to ≤ 5 % across two mesh densities |
| `spatial_latent(1+x\|coords, d=2)` | 100 sites + mesh n=200 | 4 | 4 | 1600 | ±30 % | n/a | factor-analytic + SPDE is the hardest fit; may need n_sites ≥ 120 for stable Lambda recovery |
| `spatial_indep(1+x\|coords)` | 80 sites + mesh n=150 | 3 | 4 | 960 | ±20 % | fixed at 0 | diagonal Σ_b makes spatial mesh-sensitivity less severe |
| `spatial_dep(1+x\|coords)` | 100 sites + mesh n=200 | 3 | 4 | 1200 | ±30 % | ±0.45 | hardest spatial case — full unstructured Cholesky + Matérn jointly; may surface PD-Hessian issues at small mesh |

### 2.4 `relmat` (user-supplied A) family (4 cells)

| Cell | n_id | T | n_rep | Total rows | σ² tol | ρ tol | Red flags |
|---|---:|---:|---:|---:|---:|---:|---|
| `phylo_unique(1+x\|id, vcv=A_user)` | 60 (random PD A) | 3 | 4 | 720 | ±20 % | ±0.30 | tolerance same as phylo_unique; verify dense + sparse A paths both fire and agree to 1e-6 |
| `phylo_latent(1+x\|id, vcv=A_user, d=2)` | 80 | 4 | 4 | 1280 | ±25 % | n/a | factor-analytic + user-A; A condition number matters — generate well-conditioned A |
| `phylo_indep(1+x\|id, vcv=A_user)` | 50 | 3 | 4 | 600 | ±15 % | fixed at 0 | smallest fixture; user-A doesn't add identification cost beyond what phylo_indep already has |
| `phylo_dep(1+x\|id, vcv=A_user)` | 80 | 3 | 4 | 720 | ±25 % | ±0.40 | full unstructured + arbitrary A; condition the A matrix carefully |

## 3. Cross-cell identifiability red flags

Some failure modes are not cell-specific — they cut across the matrix:

1. **ρ near ±1**: when the true correlation is close to ±1 OR the data
   has < ~20 groups per LHS column, the fit may report ρ near ±1 with
   finite SE. The recovery test should:
   - Accept ρ̂ within ±0.30 of truth at `n_sp ≥ 60`.
   - **Fail** the test if the fit reports ρ̂ = ±0.99 *and* the truth
     is not at the boundary — that's a misidentification, not noise.
2. **σ² near zero**: variance components can drift to the boundary
   when truth is small. Fixtures should set true σ² ∈ [0.2, 0.6] —
   well-separated from zero, well-separated from huge.
3. **Non-PD Hessian**: surface as a test failure (don't paper over
   with `tryCatch`). PD Hessian is part of the recovery contract.
4. **`pdHess` + finite SE**: every recovery test should check both
   per Design 56 §7.3 (the Sokal silent-collapse invariant
   prevention).

## 4. Suggested fixture-reuse pattern

`make_phylo_unique_slope_fixture()` in `tests/testthat/test-phylo-unique-slope-gaussian.R`
(PR #282) is the canonical fixture builder. Each Phase 56.5 sub-PR
should extend it via a small per-cell adapter rather than re-creating
the fixture:

```r
make_phylo_latent_slope_fixture <- function(seed = 2027, n_sp = 80, T = 4, ...) {
  base <- make_phylo_unique_slope_fixture(seed = seed, n_sp = n_sp, T = T, ...)
  # Add per-column Lambda truth + draws here; reuse base$tree, base$df_long.
  ...
}
```

This keeps the fixture choices comparable across cells and minimises
per-cell skew.

## 5. Per-cell test runtime budget

The 16 APPLICABLE cells × ~2-5 min per cell ≈ 30-80 min of test
suite work, gated under `skip_on_cran()`. Local-only execution. On
CI matrix: tests run under `R CMD check` only if explicitly
selected; default CRAN check skips all 16. This matches the
existing `test-phylo-slope.R` budget pattern.

## 6. Cross-references

- [Design 55 §5](../../design/55-structural-slope-grammar.md) — the
  4 × 4 APPLICABLE cell matrix (16 cells).
- [Design 56 §5.3](../../design/56-augmented-lhs-engine-stage3.md) —
  per-keyword Σ_b shape table (drives per-cell tolerance choice).
- [Design 56 §7](../../design/56-augmented-lhs-engine-stage3.md) —
  fail-loud invariant; recovery test should include the negative test.
- `tests/testthat/test-phylo-unique-slope-gaussian.R` (PR #282) —
  canonical fixture pattern.
- `tests/testthat/test-{phylo,animal,spatial,relmat}-{latent,unique,indep,dep}-slope-gaussian.R`
  (PRs #283 + #284) — 15 cells with `skip_until_stage3()` gates.
- [Design 14 §5](../../design/14-known-relatedness-keywords.md) —
  `animal_*` byte-equivalence contract.

## 7. What this memo does NOT decide

- **Exact CI matrix integration**: how `skip_on_cran()` interacts
  with `skip_on_ci()` is decided in the test-file-by-test-file PR,
  not here.
- **Order of sub-phase landing**: Phase 56.5a-f sequencing is
  decided when Codex starts the cells; this memo provides per-cell
  parameter recommendations, not the order.
- **Validation-debt register updates**: per Design 55 §A6, register
  edits happen in Phase 56.6 after recovery tests pass.

— Curie + Fisher + Noether (lenses), Shannon (drafting), Claude
(composer). Audit-only; reviewers welcome before Phase 56.5 starts.
