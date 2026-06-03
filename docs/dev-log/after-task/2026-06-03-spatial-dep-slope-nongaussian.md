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

First gate run (`26866309053`): `1 failed, 0 errored, 2 skipped across 6 tests`.
Allowlist trimmed to the NON-SKIPPED passers; the driver now honest-skips a
reserved family on the dep guard fail-loud (rather than hard-failing).

| Family          | runtime id | n_sites | Passed (non-skipped)? | In final allowlist? |
|-----------------|-----------:|--------:|:----------------------|:-------------------:|
| poisson         | 2          | 400     | yes                   | **yes**             |
| Gamma           | 4          | 400     | yes                   | **yes**             |
| binomial (mt)   | 1          | 400     | yes                   | **yes**             |
| gaussian        | 0          | anchor  | yes (Gaussian anchor) | **yes**             |
| nbinom2         | 5          | 400     | no — recovers out-of-band (honest-skip) | no (reserved) |
| ordinal_probit  | 14         | 400     | no — recovers out-of-band (honest-skip) | no (reserved) |
| Beta            | 7          | 400     | no — 0/1 response boundary at construction (DGP artifact) | no (reserved) |

Final allowlist: `c(0L, 1L, 2L, 4L)` (gaussian, binomial, poisson, Gamma).

Notes on the three reserved families:

- **nbinom2 / ordinal_probit**: the fit converges PD but the recovered
  marginal / cross-field block lands outside the inherited band at
  `n_sites = 400` — the same "unstructured `2T x 2T` is the hardest cell"
  signal that made dep the last phylo slope mode to land. They honest-skip
  ("partial pending bigger n") and stay off the allowlist.
- **Beta**: the recovery cell never reached a recovery number — under the
  strong dep cross-correlation the simulated Beta response hit exact 0/1
  (`Beta rows: y must satisfy 0 < y < 1`), a **DGP boundary artifact**, not an
  engine/identifiability result. This is the most likely of the three to pass
  with a clamped response in a follow-up (its closest analogue, Gamma, passes).
  Reserved here to keep the allowlist to confirmed non-skipped cells.

## Checks

- Validation is CI-only (no local R). The recovery workflow is the gate.
- Standard R-CMD-check is unaffected (recovery cells are `skip_if_not_heavy()`).

## Follow-up

- **Beta** is the highest-value follow-up: clamp the simulated response into
  `(eps, 1 - eps)` (the precedented GAP-B1 Beta 0/1 clamp) and re-run; if it
  recovers in-band, add id `7L` to the `use_spde_dep_slope` allowlist.
- **nbinom2 / ordinal_probit**: re-test at 600 / 1000 sites (binomial-style
  size bumps do not apply); add to the allowlist only if a cell then passes
  non-skipped.
- Result this PR: `spatial_dep(1 + x | coords)` enabled for **gaussian,
  binomial, poisson, Gamma** (`c(0L, 1L, 2L, 4L)`); the other three stay
  reserved fail-loud and their VALIDATION cells honest-skip on the guard.
