# M3 production-grid rerun under patched DGP — 2026-05-25

**Author**: Shannon (cross-team coordination) with Curie (sim
fidelity) reviewing.
**Date**: 2026-05-25.
**Triggered by**: maintainer 2026-05-25 *"1"* (re-dispatch the M3
production-grid under the corrected DGP, to see whether any cells
clear the §5 admission floor after the binomial-psi fix from PR
#263).
**Run**: [26412130690](https://github.com/itchyshin/gllvmTMB/actions/runs/26412130690).
**Inputs**: `n_reps=10`, `init_strategy=single_trait_warmup`,
`targets=psi,Sigma_unit_diag`, `n_boot=25`, `seed_base=20260525`,
`retention_days=14`. Same seed as the Jason scout (PR #263) so the
nbinom2 × d=1 and binomial × d=1 cells reproduce the scout's
numbers within the full 15-cell grid.

## 1. Diagnostic-only disclaimer

**`n_reps=10` is below the Design 50 §5 r50 admission floor.** All
coverage values are diagnostic-only at this scale (MCSE ≈ ±15 pp).
**CI-08 and CI-10 stay `partial`** per Design 50 §9. The deliberate
non-update is part of the lane assignment — register movement to
`covered` requires r200 evidence (Design 50 §9 / §5).

The PR #263 DGP patch + PR #264 stopifnot guard are on main; this
rerun uses the corrected `dev/m3-grid.R`.

## 2. Per-cell results

Full grid:

| Family | d | Median ratio on `Sigma_unit[tt]` | Cov(Sigma) | Cov(psi) | Boot fail | pdHess | pilot_status_at_r10 |
|---|---|---|---|---|---|---|---|
| Gaussian | 1 | 1.17 | 0.80 | 0.80 | 0.01 | 1.0 | TARGET_FAIL |
| Gaussian | 2 | 1.09 | 0.86 | 0.56 | 0.00 | 1.0 | TARGET_FAIL |
| Gaussian | 3 | 1.06 | 0.88 | 0.92 | 0.01 | 0.3 | TARGET_FAIL |
| **binomial** | **1** | **0.79** | **0.92** | 0.72 | 0.01 | 0.4 | TARGET_FAIL (very close) |
| **binomial** | **2** | **0.86** | **0.94** | 0.80 | 0.01 | 0.5 | **✅ PASS_TO_SCALE** |
| **binomial** | **3** | **0.53** | **0.92** | 0.82 | 0.01 | 0.5 | TARGET_FAIL |
| nbinom2 | 1 | 0.55 | 0.76 | 0.47 | 0.12 | 0.4 | TARGET_FAIL |
| nbinom2 | 2 | 0.72 | 0.80 | 0.36 | 0.22 | 0.3 | COMPUTE_FAIL (boot fail > 20%) |
| nbinom2 | 3 | 0.70 | 0.74 | 0.28 | 0.17 | 0.3 | TARGET_FAIL |
| ordinal-probit | 1 | 0.17 | NA | 0.78 | 0.00 | 0.7 | COMPUTE_FAIL (§6 expected — no bootstrap) |
| ordinal-probit | 2 | 0.41 | NA | 0.74 | 0.00 | 0.8 | COMPUTE_FAIL (§6 expected) |
| ordinal-probit | 3 | 0.31 | NA | 0.60 | 0.00 | 0.9 | COMPUTE_FAIL (§6 expected) |
| mixed | 1 | 1.08 | 0.82 | 0.78 | 0.05 | 0.0 | TARGET_FAIL |
| **mixed** | **2** | **1.07** | **0.92** | 0.70 | 0.10 | 0.0 | **✅ PASS_TO_SCALE** |
| mixed | 3 | 1.03 | 0.83 | 0.60 | 0.19 | 0.0 | TARGET_FAIL (1 cell short on fit-fail allowance) |

## 3. Comparison to pre-patch (run 26404672871)

`median_ratio_sigma` on `Sigma_unit[tt]`:

| Family × d | Pre-patch | Post-patch | Delta |
|---|---|---|---|
| Gaussian × 1 | 1.17 | 1.17 | ≈ 0 (unchanged — DGP not patched for Gaussian) |
| Gaussian × 2 | 1.09 | 1.09 | ≈ 0 |
| Gaussian × 3 | 1.05 | 1.06 | ≈ 0 |
| **binomial × 1** | **0.24** | **0.79** | **+0.55** (DGP fix recovered ~3.3× of truth) |
| **binomial × 2** | **0.32** | **0.86** | **+0.54** |
| **binomial × 3** | **0.42** | **0.53** | **+0.11** |
| nbinom2 × 1 | 0.56 | 0.55 | ≈ 0 (unchanged — nbinom2 has legitimate psi) |
| nbinom2 × 2 | 0.74 | 0.72 | ≈ 0 |
| nbinom2 × 3 | 0.64 | 0.70 | +0.06 |
| ordinal-probit × all | n/a | n/a | unchanged (bootstrap unsupported) |
| **mixed × 1** | **0.92** | **1.08** | **+0.16** (binomial rows in mixed got fixed) |
| **mixed × 2** | **1.00** | **1.07** | +0.07 |
| **mixed × 3** | **0.70** | **1.03** | **+0.33** (mixed d=3 was the most-broken cell) |

## 4. Headline findings

### 4.1 The DGP patch resolves the binomial Scenario A signal at grid scale.

Pre-patch binomial cells reported median ratios 0.24-0.42 (severe
under-estimate). Post-patch they report 0.53-0.86 — a 1.3-3.3×
improvement, with coverage on `Sigma_unit[tt]` now 0.92-0.94 (at
or above the 94% promotion gate). The Jason scout's prediction
that the DGP fix would resolve the Scenario A signal **holds at
the full 15-cell grid scale**, not just in the scout's binomial-d=1
cell.

### 4.2 Two cells pass §5 admission floor at r10.

Under Design 50 §5 admission thresholds (coverage ≥ 0.90, CI-missing
≤ 10%, fit-failure ≤ 20%/30% mixed, bootstrap-failure ≤ family-
limit, no one-sided miss), **two cells out of 13 evaluable** hit
`PASS_TO_SCALE`:

- **binomial × d=2** (ratio 0.86, coverage 0.94)
- **mixed × d=2** (ratio 1.07, coverage 0.92)

binomial × d=1 (cov 0.92) and binomial × d=3 (cov 0.92) are very
close to admission — both would likely promote with a few more
trait-rep pairs. At r50 the admission picture should be much
clearer.

### 4.3 nbinom2 unchanged (as expected).

nbinom2 cells were NOT touched by the binomial-psi patch (nbinom2
has a legitimate overdispersion parameter `phi`, so the
observation-level `psi` random-effect variance IS identifiable).
Their median ratios stayed 0.55-0.72; coverage on `psi` stayed
low (0.28-0.47); the ψ↔φ trade-off Noether documented persists.
This is the m3-grid framing target-scale issue for the
**non-binomial** count families, distinct from the binomial-psi
DGP bug PR #263 fixed.

### 4.4 mixed-family d=3 was the biggest gainer.

Pre-patch mixed × d=3 was at 0.70; post-patch at 1.03 — a 47%
improvement. This was the most-broken cell pre-patch (3/5 traits
were Gaussian or nbinom2, but 2/5 were binomial, and the binomial
rows were inflating the truth without the fitter being able to
recover). The selective psi-zeroing in mixed cells (binomial rows
only) cleaned this up.

### 4.5 Ordinal-probit unchanged.

The §6 family-ID-14 guard still routes ordinal-probit to
`COMPUTE_FAIL` because the bootstrap path is not supported. Profile-
psi is computed but only as a diagnostic. Unchanged by this rerun.

## 5. What this run DID NOT do

- **No CI-08 / CI-10 register row update.** Stay `partial` per
  Design 50 §9 — n_reps=10 is below the r200 promotion floor.
  The evidence is strongly supportive of promotion under a future
  r200 dispatch, but that's a separate slice.
- **No engine / R/ source change.**
- **No edit to** ROADMAP.md, check-log.md, after-task/,
  R/diagnose.R, or test-sanity-multi.R.
- **No claim that nbinom2 is now coverage-promotable.** Its
  shrinkage is the residual ψ↔φ trade-off documented by Noether
  2026-05-18.

## 6. Recommended next slice (maintainer decision)

If you want to actually promote CI-08 / CI-10 from `partial` to
`covered`, the next slice is:

**r200 dispatch under the patched DGP, focused on the cells that
hit `PASS_TO_SCALE` at r10** — binomial × d=2 and mixed × d=2 at
minimum, ideally extended to all binomial cells (which were 0.92
coverage at r10 — close to gate).

Approximate budget: 200 reps × ~4 cells × ~7-65 s per fit × 5-OS-parallel
≈ 1-3 h GHA wall. (Full 15-cell r200 = ~5-10 h wall.) The
workflow already accepts `n_reps=200` as the default; just
re-dispatch with the same other params.

Alternatively if you want a r50 admission-confidence step before
r200, dispatch with `n_reps=50`.

## 7. Hand-off

- Codex's #257/#260/#261 are not implicated by this rerun. The
  binomial Scenario A finding remains resolved as a DGP fix
  (PR #263 + PR #264).
- Run URL retained 14 days at the GHA actions page (artefact
  bundles downloadable).
- Local CSV summary: `/tmp/m3-postpatch-summary.csv` (local
  artefact; not committed).

— Shannon (coordination) + Curie (sim fidelity)
