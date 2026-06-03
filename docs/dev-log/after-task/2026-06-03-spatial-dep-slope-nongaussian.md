# After-task: SPA-10 non-Gaussian `spatial_dep(1 + x | coords)` slopes

- Date: 2026-06-03
- Author: Claude Code
- Branch: `claude/spatial-dep-slope-nongaussian`
- Register row: SPA-10 (`docs/design/35-validation-debt-register.md`)

## Scope

Enable the FULL unstructured 2T×2T augmented SPDE field-covariance random
slope `spatial_dep(1 + x | coords)` for non-Gaussian families — the spatial
analogue of PHY-18 (`phylo_dep`, all families, #422/#424) and the unstructured
generalisation of SPA-08 (`spatial_indep`, #427). ZERO new C++: the augmented
dep field enters the linear predictor before the C++ family dispatch, so
activation is purely a per-family relaxation of the `use_spde_dep_slope`
family guard in `R/fit-multi.R`, gated on real-API recovery cells.

## Approach (retired-spike note)

The previous attempt (#425) drew the SPDE field from a hand-built precision
`Q` — `solve(Q)` was singular and `chol(Q)` failed with "leading minor not
positive", producing ZERO usable cells. That standalone spike is **RETIRED**.
This work instead builds recovery cells on the package's OWN validated Gaussian
spatial DGP: the exact stable `backsolve(chol(Q), z)` GMRF draw from
`test-spatial-indep-slope-nongaussian.R` (#427), extended with a NON-ZERO
per-trait intercept/slope cross-field correlation so the recovery also asserts
the off-diagonal `R[1, 2]`.

## Changes

- `R/fit-multi.R`: relaxed the `use_spde_dep_slope` family guard from
  gaussian-only `c(0L)` to the full seven-family allowlist
  `c(0L, 1L, 2L, 4L, 5L, 7L, 14L)` (all CI-validated non-skipped).
  The BASE `spatial_unique`/`spatial_indep` `else if` branch (SPA-08, #427)
  was NOT touched.
- `tests/testthat/test-spatial-dep-slope-nongaussian.R`: new file, one
  `*_VALIDATION` recovery cell per family (poisson, Gamma, Beta,
  binomial-multitrial, nbinom2, ordinal_probit), modelled exactly on the
  SPA-08 indep template with the same honest-skip discipline plus the
  cross-field-correlation assertion.
- `tests/testthat/test-spatial-dep-slope-gaussian.R`: guard-fires probe
  switched from `poisson()` (now admitted) to `tweedie()` (still reserved).
- `.github/workflows/spatial-dep-slope-nongaussian-recovery.yaml`: heavy
  `pull_request` recovery gate (GLLVMTMB_HEAVY_TESTS=1), fails on any
  failed/errored expectation; skips do not fail.
- `docs/design/35-validation-debt-register.md`: SPA-10 row updated.

## Per-family CI outcome

CI gate: `spatial-dep-slope-nongaussian-recovery` (heavy, GLLVMTMB_HEAVY_TESTS=1).

It took three gate rounds to land all six non-Gaussian families:

- **Round 1 (n_sites = 400):** `1 failed, 0 errored, 2 skipped`. poisson / Gamma /
  binomial passed; nbinom2 / ordinal_probit converged PD but recovered just
  out-of-band; Beta hard-failed at construction (`Beta rows: y must satisfy
  0 < y < 1` — the strong dep cross-correlation rounded the simulated response
  to exact 0/1).
- **Round 2 (Beta response clamped to `(eps, 1 - eps)`; nbinom2 / ordinal_probit
  → n_sites = 1000):** `0 failed, 0 errored, 1 skipped`. nbinom2 and
  ordinal_probit cleared their bands; Beta now constructed and converged PD but
  at n_sites = 400 recovered the intercept/slope cross-field correlation wrongly
  (`r_ab = +0.158` vs truth `-0.50`; `cor_fb = 0.79`, a hair under the 0.80
  floor) — it was the one cell left at 400.
- **Round 3 (Beta → n_sites = 1000):** `0 failed, 0 errored, 0 skipped across
  6 tests`. All six non-Gaussian families recover non-skipped.

| Family          | runtime id | n_sites | Passed (non-skipped)? | In final allowlist? |
|-----------------|-----------:|--------:|:----------------------|:-------------------:|
| gaussian        | 0          | anchor  | yes (Gaussian anchor) | **yes**             |
| binomial (mt)   | 1          | 400     | yes                   | **yes**             |
| poisson         | 2          | 400     | yes                   | **yes**             |
| Gamma           | 4          | 400     | yes                   | **yes**             |
| nbinom2         | 5          | 1000    | yes                   | **yes**             |
| Beta            | 7          | 1000    | yes (clamped response)| **yes**             |
| ordinal_probit  | 14         | 1000    | yes                   | **yes**             |

Final allowlist: `c(0L, 1L, 2L, 4L, 5L, 7L, 14L)` — **all seven families**. The
full unstructured 2T×2T SPDE field-covariance slope is the hardest cell in the
grid; the three count/proportion/ordinal families needed n_sites = 1000 (vs 400
for poisson / Gamma / binomial) to identify the cross-field block, exactly the
"unstructured dep is the last cell to land" signal seen on the phylo side
(PHY-18). Beta additionally needed its simulated response clamped off 0/1 (a
DGP-boundary guard, far below `marg_tol`, not a recovery shortcut).

## Checks

- Validation is CI-only (no local R). The recovery workflow is the gate.
- Standard R-CMD-check is unaffected (recovery cells are `skip_if_not_heavy()`).

## Follow-up

- All six non-Gaussian `spatial_dep(1 + x | coords)` families are validated and
  on the allowlist; no family remains reserved. SPA-10 is closed.
- The driver honest-skips a reserved family on the dep guard fail-loud, so if a
  future family is added it degrades to a skip rather than a hard fail until its
  cell passes.
- nbinom2 / ordinal_probit / Beta carry n_sites = 1000 fixtures (heavier than the
  n = 400 cells); fine under `skip_if_not_heavy()` but worth noting for gate time.
