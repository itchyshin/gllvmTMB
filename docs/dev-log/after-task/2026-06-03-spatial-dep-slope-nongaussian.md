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
  gaussian-only `c(0L)` to the allowlist (trimmed to CI-passing families).
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

| Family          | runtime id | n_sites used | Passed (non-skipped)? | In final allowlist? |
|-----------------|-----------:|-------------:|:---------------------:|:-------------------:|
| poisson         | 2          | _TBD_        | _TBD_                 | _TBD_               |
| Gamma           | 4          | _TBD_        | _TBD_                 | _TBD_               |
| Beta            | 7          | _TBD_        | _TBD_                 | _TBD_               |
| binomial (mt)   | 1          | _TBD_        | _TBD_                 | _TBD_               |
| nbinom2         | 5          | _TBD_        | _TBD_                 | _TBD_               |
| ordinal_probit  | 14         | _TBD_        | _TBD_                 | _TBD_               |

(Filled in from the recovery job log: the `N failed, N errored, N skipped`
summary line. Allowlist trimmed to exactly the NON-SKIPPED families.)

## Checks

- Validation is CI-only (no local R). The recovery workflow is the gate.
- Standard R-CMD-check is unaffected (recovery cells are `skip_if_not_heavy()`).

## Follow-up

- Any family still skipping after escalation (600 / 1000 sites; binomial
  size 12 → 20) stays reserved (honest-skip); its allowlist entry is removed.
- PR opened as DRAFT (high-risk family-guard change); do NOT merge.
