# After Task: LV Gaussian Wald Local Pilot

## Goal

Run a local, non-production pilot of the ordinary Gaussian
`latent(..., lv = ~ x)` `B_lv` Wald coverage harness across all current
Gaussian cells, including the small-N `wald_t_unit` comparator, before moving
the campaign to the >=500 reps/cell evidence tier.

## Implemented

No implementation changed in this slice. The existing
`dev/lv-wald-coverage.R` harness was exercised locally at four reps per cell
over the four current Gaussian cells:

- `gaussian-d1-n72-t3`
- `gaussian-d1-n144-t3`
- `gaussian-d2-n96-t4`
- `gaussian-d2-n160-t4`

Both interval methods, `wald_z` and `wald_t_unit`, were emitted for every
`B_lv` target. The output shape matched the harness contract: 112 long rows
and 28 summary rows.

## Mathematical Contract

The target remains:

```text
z_i = M_i alpha + e_i,    e_i ~ N(0, I_K)
B_lv = Lambda alpha'
```

The pilot checks execution and denominator accounting only. It does not
calibrate Wald intervals, does not promote the t-critical comparator, and does
not change the production evidence bar of >=500 reps/cell with MCSE and
failed-fit denominators.

## Files Changed

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-28-lv-wald-local-pilot.md`

## Checks Run

- Pre-edit lane check:
  `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> REVIEWED; only PR #569 was open, non-draft, and merge-clean.
- Pre-edit lane check:
  `git log --all --oneline --since="6 hours ago" -- dev/lv-wald-coverage.R dev/lv-wald-coverage-slurm.sh tests/testthat/test-lv-wald-coverage-harness.R docs/dev-log/check-log.md docs/dev-log/after-task docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; only this queued Gaussian coverage branch had touched the
  same files recently.
- `rm -rf /tmp/gllvmtmb-lv-wald-local-pilot-20260628; GLLVMTMB_LV_WALD_COVERAGE_CLI=true NOT_CRAN=true Rscript --vanilla dev/lv-wald-coverage.R --mode=cell --cell=gaussian-d1-n72-t3 --n-reps=4 --seed-base=20260628 --rep-start=1 --rep-end=4 --interval-methods=wald_z,wald_t_unit --results-dir=/tmp/gllvmtmb-lv-wald-local-pilot-20260628`
  -> PASS; wrote six summary rows for the one-cell pilot, with four eligible
  rows per target and method. `production_n_reps_met` was `FALSE`.
- `rm -rf /tmp/gllvmtmb-lv-wald-local-pilot-allcells-20260628; GLLVMTMB_LV_WALD_COVERAGE_CLI=true NOT_CRAN=true Rscript --vanilla - <<'RS' ... RS`
  -> PASS; ran four reps/cell over all four cells and wrote long and summary
  CSV/RDS files under `/tmp/gllvmtmb-lv-wald-local-pilot-allcells-20260628`.
- `wc -l /tmp/gllvmtmb-lv-wald-local-pilot-allcells-20260628/lv-wald-coverage-long.csv /tmp/gllvmtmb-lv-wald-local-pilot-allcells-20260628/lv-wald-coverage-summary.csv`
  -> PASS; 113 long CSV lines and 29 summary CSV lines, meaning 112 long rows
  and 28 summary rows after headers.
- `Rscript --vanilla -e 's <- read.csv("/tmp/gllvmtmb-lv-wald-local-pilot-allcells-20260628/lv-wald-coverage-summary.csv"); cat("rows", nrow(s), "\n"); print(s[, c("cell_id", "target_id", "interval_method", "n_attempted", "n_converged", "n_eligible", "coverage", "coverage_mcse", "production_n_reps_met", "passes_coverage_band")], row.names = FALSE)'`
  -> PASS; summary had 28 rows, all `n_attempted = 4`, all
  `n_converged = 4`, `n_eligible = 4` except the `gaussian-d2-n96-t4` rows
  where replicate 3 had `pd_hessian = FALSE` and therefore
  `n_eligible = 3`. All `production_n_reps_met` and `passes_coverage_band`
  values were `FALSE`.
- `Rscript --vanilla -e 'x <- read.csv("/tmp/gllvmtmb-lv-wald-local-pilot-allcells-20260628/lv-wald-coverage-long.csv"); print(subset(x, !eligible | !ci_available | !fit_converged | !sdreport_ok)[, c("cell_id", "rep", "target_id", "interval_method", "fit_converged", "pd_hessian", "sdreport_ok", "ci_available", "eligible")], row.names = FALSE)'`
  -> PASS; the only ineligible rows were `gaussian-d2-n96-t4`, replicate 3,
  all four `B_lv` targets and both interval methods. The fit converged and
  `sdreport_ok` was true, but `pd_hessian` was false, so CI rows were not
  eligible.
- `git diff --check` -> PASS.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "lv-wald-coverage-harness", reporter = "summary")'`
  -> PASS; the opt-in live fit smoke remained skipped.

## Tests Of The Tests

This pilot is a smoke/evidence-run check, not a new unit test. It exercised the
same denominator logic that the harness tests protect: failed or non-PD fits
must reduce `n_eligible`, keep `n_attempted` and `n_converged` visible, and
avoid counting ineligible rows as coverage successes.

## Consistency Audit

No user-facing documentation changed. The new report and check-log entry label
the run as local pilot evidence only, keep `LV-02` partial, and repeat that
>=500 reps/cell remain required before interval calibration can be claimed.

## What Did Not Go Smoothly

The all-cells R snippet was launched with
`GLLVMTMB_LV_WALD_COVERAGE_CLI=true` while sourcing
`dev/lv-wald-coverage.R`, which caused an accidental untracked
`dev/lv-wald-results/` plan output. It was generated run output, inspected, and
removed before any staging.

## Team Learning

Fisher: a tiny pilot can reveal denominator behaviour but cannot estimate
coverage. The non-PD `gaussian-d2-n96-t4` replicate is a useful reminder to
report eligible denominators, not just attempted fits.

Curie: the all-cells pilot confirms the long/summary table shape before the
same harness is scaled to 500 reps/cell.

Rose: the wording must stay "pilot completed" rather than "coverage passed";
the summary correctly keeps `passes_coverage_band = FALSE` because the
production replicate threshold is not met.

## Known Limitations

No production coverage grid was run. No DRAC array was submitted. No
profile/bootstrap rescue, binomial interval grid, non-Gaussian interval grid,
mixed-family row, mask row, `X + X_lv` row, or source-specific `lv` interval
claim changed.

## Next Actions

Move the same harness to DRAC or an equivalent batch environment at >=500
reps/cell for `wald_z` and `wald_t_unit`, then audit coverage, MCSE, failed-fit
denominators, and the small-N t comparator before changing any public interval
claim.
