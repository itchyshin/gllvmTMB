# After-Task: dep-slope run 32 artifact triage

## Scope

Harvest and classify the scheduled/default dep-slope campaign run 32
artifact after it completed successfully. The goal was to decide
whether the artifact changed RE-03 evidence or only added single-slope
campaign evidence.

This is a read/report slice. It does not change package code, tests,
workflow configuration, the validation-debt register, or user-facing
documentation.

## Files Touched

- `docs/dev-log/check-log.md`
  - Adds the command evidence and interpretation for run 32.
- `docs/dev-log/after-task/2026-06-07-dep-slope-run32-triage.md`
  - This after-task report.

## Evidence

- GitHub Actions run:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27082159407>
- Result-store commit:
  `9754065 dep-slope campaign: accumulate seeds (run 32)` on
  `dep-slope-sweep-results`.
- Artifact path:
  `/tmp/gllvmtmb-run27082159407/dep-slope-campaign-run-32/`
- Artifact files:
  - `dep-slope-campaign.log`
  - `dep-slope-sweep-accumulated.csv`

The accumulated CSV has 2,520 rows and 38 columns. It is the
scheduled/default single-slope campaign store: all rows have
`n_slope = 1`. The fresh run-32 rows are seeds `3201:3203`, 7
families, 5 `n_sp` values (`80,150,300,600,1200`), and `n_rep = 10`,
for 105 new fitted cells.

Fresh run-32 summary:

| family | PD | strict | loose | main failures |
|---|---:|---:|---:|---|
| gaussian | 15/15 | 15/15 | 15/15 | none |
| poisson | 12/15 | 12/15 | 12/15 | 3 nonPD/nonconv |
| binomial | 14/15 | 13/15 | 14/15 | 1 low_ratio, 1 nonPD/nonconv |
| Gamma | 14/15 | 10/15 | 14/15 | 4 low_ratio, 1 nonPD/nonconv |
| Beta | 13/15 | 10/15 | 12/15 | 3 low_ratio, 2 nonPD/nonconv |
| nbinom2 | 10/15 | 6/15 | 8/15 | 4 low_ratio, 5 nonPD/nonconv |
| ordinal_probit | 9/15 | 7/15 | 9/15 | 2 low_ratio, 6 nonPD/nonconv |

By sample size, strict recovery improved from 11/21 at `n_sp = 80`
to 20/21 at `n_sp = 1200`. All 21 high-N cells were PD at
`n_sp = 1200`; the only strict miss at that size was an
ordinal-probit low-ratio cell.

## Interpretation

Run 32 is useful single-slope campaign progress. It does not change
RE-03 because it did not run `s = 2`. The non-Gaussian
`phylo_dep(..., s >= 2)` public guard remains in place, and RE-03
remains `partial`.

The next RE-03 action is still a targeted `s = 2` weak-family
diagnostic/admission design, especially around `nbinom2` and
`ordinal_probit`, not more blind single-slope accumulation.

## Definition of Done Accounting

1. **Implementation.** Not applicable: no package code changed.
2. **Simulation recovery test.** Not applicable: this triages an
   external campaign artifact and adds no new estimator or family.
3. **Documentation.** Repo-visible dev-log and after-task report added.
   No roxygen, Rd, README, or article text changed.
4. **Runnable user-facing example.** Not applicable.
5. **Check-log entry.** Added with exact commands and artifact paths.
6. **Review pass.** No Boole/Gauss/Noether/Rose gate is triggered:
   grammar, likelihood, TMB, and public prose are untouched.

## Issue Update

Posted the interpretation on issue #341:
<https://github.com/itchyshin/gllvmTMB/issues/341#issuecomment-4641683938>.

## Local Verification

- `git diff --check`
  - Clean.
