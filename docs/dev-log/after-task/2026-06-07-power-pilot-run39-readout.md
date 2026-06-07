# After-Task: Power pilot run 39 combined readout

## Scope

Harvest the latest completed Power pilot GitHub run, combine its remote
result store with the local LaunchAgent store, and record the current
target-scale interpretation for the capstone simulation lane.

This is a read/report slice. It does not change package code, tests,
workflow configuration, the validation-debt register, or user-facing
documentation.

## Files Touched

- `docs/dev-log/check-log.md`
  - Adds the command evidence and interpretation for the run-39 readout.
- `docs/dev-log/after-task/2026-06-07-power-pilot-run39-readout.md`
  - This after-task report.

## Evidence

- GitHub Actions run:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27082083668>
- Result-store commit:
  `b598007 power-pilot: accumulate reps (run 39)` on
  `power-pilot-results`.
- Remote result-store archive:
  `/tmp/gllvmtmb-power-run39.OogZOr/dev/m3-pilot-results`
- Local LaunchAgent store:
  `/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local`
- Local LaunchAgent status:
  `com.gllvmtmb.power-pilot-local` running with PID `48465`,
  `LOCAL_CORES = 10`, and `LOCAL_N_SIM_CAP = 10000`.

Generated local outputs:

- `/tmp/gllvmtmb-power-run39-summary.md`
- `/tmp/gllvmtmb-power-run39-summary.rds`
- `/tmp/gllvmtmb-power-run39-scoring-audit.md`
- `/tmp/gllvmtmb-power-run39-scoring-audit.rds`
- `/tmp/gllvmtmb-power-run39-figures/pilot-coverage-vs-nominal.png`
- `/tmp/gllvmtmb-power-run39-figures/pilot-zero-exclusion-diagnostic.png`

The combined store has 48 cells, 76,192 accumulated replicates, and
0 of 48 cells complete at the 10,000-replicate cap. Across the 24
signal cells with coverage rows, mean `coverage_primary` is 0.754;
3 of 24 cells meet the 94% gate and 2 of 24 meet the 95% gate.

The CLI issue emitter reports 28 flagged cells, led by
binomial-probit non-PD cells and nbinom2 fit-health / non-PD cells.

## Target-Scale Audit

Representative rows:

| cell | n_sim | coverage | zero-excl | median truth | median estimate | median est/truth | nonPD |
|---|---:|---:|---:|---:|---:|---:|---:|
| `gaussian-d1-n150-sig0p0` | 1504 | 0.389 | 1.000 | 0.839 | 1.078 | 1.305 | 0.000 |
| `nbinom2-d2-n50-sig0p0` | 1354 | 0.900 | 1.000 | 0.844 | 0.672 | 0.757 | 0.751 |
| `binomial_probit-d1-n50-sig0p2` | 1504 | 0.959 | 1.000 | 0.192 | 0.351 | 2.191 | 0.328 |

## Interpretation

Run 39 completed and persisted successfully, but the capstone campaign
is not complete. The current evidence is still diagnostic.

The zero-exclusion panel is correctly demoted: it is saturated at 1.0
and is not a Type-I or power measure for `Sigma_unit_diag`, including
`signal = 0` cells where the variance target remains positive.

Coverage remains below the target for most cells. nbinom2 also carries
the largest fit-health / non-PD burden. No validation-debt row moves:
CI-08 and CI-10 remain `partial` until a target-explicit, adequately
replicated capstone gate passes.

## Local Verification

- `pilot_collect()` returned 48 cells on the combined remote + local
  stores.
- `pilot_report` API compatibility check passed:
  `zero_exclusion_rate` is present, the legacy `power` alias is
  byte-identical, and `pilot_plot()` returns `coverage` and
  `zero_exclusion`.
- Both generated PNGs were visually inspected and rendered nonblank.
- `--emit-issues` completed and reported 28 flagged cells.
- `rg -n "CI-08|CI-10|zero_exclusion_rate|zero-exclusion|run 39|Power pilot" docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-07-power-pilot-run39-readout.md`
  confirmed that the report points to the run-39 evidence and the
  validation-debt register still marks CI-08 and CI-10 `partial`.
- `git diff --check` completed cleanly.

## Issue Updates

- Capstone issue #349:
  <https://github.com/itchyshin/gllvmTMB/issues/349#issuecomment-4642061792>
- Capability board #340:
  <https://github.com/itchyshin/gllvmTMB/issues/340#issuecomment-4642061860>

## Definition of Done Accounting

1. **Implementation.** Not applicable: no package code changed.
2. **Simulation recovery test.** Not applicable: this triages accumulated
   campaign artifacts and adds no new estimator, family, or DGP.
3. **Documentation.** Repo-visible dev-log and after-task report added.
   No roxygen, Rd, README, article, or pkgdown text changed.
4. **Runnable user-facing example.** Not applicable.
5. **Check-log entry.** Added with exact commands and artifact paths.
6. **Review pass.** Simulation-check lens applied to the interpretation:
   target alignment, fit-health, and zero-exclusion are kept separate.
   Rose-style after-task audit applied. No Boole/Gauss/Noether or
   Rose pre-publish gate is triggered because grammar, likelihood,
   TMB, and public prose are untouched.
