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

## Addendum: r25 Local Pilot

After the four-reps/cell pilot, a larger local pilot ran 25 reps/cell over the
same four Gaussian cells with both `wald_z` and `wald_t_unit` interval rows.
This remains pilot evidence only.

Checks:

- Pre-edit lane check:
  `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> REVIEWED; only PR #569 was open, non-draft, and merge-clean.
- Pre-edit lane check:
  `git log --all --oneline --since="6 hours ago" -- dev/lv-wald-coverage.R dev/lv-wald-coverage-slurm.sh tests/testthat/test-lv-wald-coverage-harness.R docs/dev-log/check-log.md docs/dev-log/after-task docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; only this queued Gaussian coverage branch had touched the
  same files recently.
- `rm -rf /tmp/gllvmtmb-lv-wald-local-r25-20260628; NOT_CRAN=true Rscript --vanilla - <<'RS' ... RS`
  -> PASS with one `sqrt(diag(cov))` NaN warning during sdreport extraction;
  wrote long and summary CSV/RDS files under
  `/tmp/gllvmtmb-lv-wald-local-r25-20260628`.
- `wc -l /tmp/gllvmtmb-lv-wald-local-r25-20260628/lv-wald-coverage-long.csv /tmp/gllvmtmb-lv-wald-local-r25-20260628/lv-wald-coverage-summary.csv`
  -> PASS; 701 long CSV lines and 29 summary CSV lines, meaning 700 long rows
  and 28 summary rows after headers.
- `Rscript --vanilla -e 's <- read.csv("/tmp/gllvmtmb-lv-wald-local-r25-20260628/lv-wald-coverage-summary.csv"); cat("summary rows", nrow(s), "\n"); print(s[, c("cell_id", "target_id", "interval_method", "n_attempted", "n_converged", "n_eligible", "coverage", "coverage_mcse", "production_n_reps_met", "passes_coverage_band")], row.names = FALSE)'`
  -> PASS; all 28 target/method rows had `n_attempted = 25` and
  `n_converged = 25`; rank-1 cells had `n_eligible = 25`, while both rank-2
  cells had `n_eligible = 24` because one replicate per rank-2 cell was
  non-PD. All `production_n_reps_met` and `passes_coverage_band` values
  remained `FALSE`.
- `Rscript --vanilla -e 'x <- read.csv("/tmp/gllvmtmb-lv-wald-local-r25-20260628/lv-wald-coverage-long.csv"); bad <- subset(x, !eligible | !ci_available | !fit_converged | !sdreport_ok | !pd_hessian); cat("long rows", nrow(x), "bad rows", nrow(bad), "\n"); print(unique(bad[, c("cell_id", "rep", "rep_seed", "interval_method", "fit_converged", "pd_hessian", "sdreport_ok", "ci_available", "eligible", "fit_convergence_code", "max_gradient")]), row.names = FALSE)'`
  -> PASS; the only excluded replicates were `gaussian-d2-n96-t4` rep 3 and
  `gaussian-d2-n160-t4` rep 6. Both optimizer runs had convergence code 0 and
  `sdreport_ok = TRUE`, but `pd_hessian = FALSE`, so CI rows were not
  eligible.
- `Rscript --vanilla -e 's <- read.csv("/tmp/gllvmtmb-lv-wald-local-r25-20260628/lv-wald-coverage-summary.csv"); z <- subset(s, interval_method == "wald_z")[, c("cell_id","target_id","coverage","n_eligible")]; t <- subset(s, interval_method == "wald_t_unit")[, c("cell_id","target_id","coverage","n_eligible")]; names(z)[3:4] <- c("coverage_z","n_eligible_z"); names(t)[3:4] <- c("coverage_t","n_eligible_t"); m <- merge(z, t, by=c("cell_id","target_id")); m$delta_t_minus_z <- m$coverage_t - m$coverage_z; print(m[order(m$cell_id, m$target_id), ], row.names = FALSE); print(table(m$delta_t_minus_z))'`
  -> PASS; `wald_t_unit` exceeded `wald_z` for two of 14 target rows by 0.04,
  and matched `wald_z` for the other 12 target rows. This is descriptive
  pilot behaviour, not calibration evidence.

## Addendum: Local r500 Coverage Grid

The local machine completed the production-size ordinary Gaussian grid after
Totoro remained unavailable non-interactively. This is now local validation
evidence for the four current native TMB Gaussian `B_lv` cells; it is still
subject to branch audit/merge discipline before any public wording changes.

Checks and artifacts:

- `ssh -o BatchMode=yes -o ConnectTimeout=12 totoro 'hostname; pwd; uname -a; command -v Rscript || true; command -v git || true; command -v julia || true'`
  -> FAIL; `Permission denied (publickey,password)`.
- `rm -rf /tmp/gllvmtmb-lv-wald-local-r500-20260628; NOT_CRAN=true nice -n 10 Rscript --vanilla - <<'RS' ... RS`
  -> PASS; completed in 26.94 minutes, attempted 500 fits/cell across the four
  Gaussian cells, and emitted both `wald_z` and `wald_t_unit` rows.
- `wc -l /tmp/gllvmtmb-lv-wald-local-r500-20260628/lv-wald-coverage-long.csv /tmp/gllvmtmb-lv-wald-local-r500-20260628/lv-wald-coverage-summary.csv`
  -> PASS; 14,001 long CSV lines and 29 summary CSV lines, meaning 14,000
  long rows and 28 summary rows after headers.
- `Rscript --vanilla -e 's <- read.csv("/tmp/gllvmtmb-lv-wald-local-r500-20260628/lv-wald-coverage-summary.csv"); cat("summary rows", nrow(s), "\n"); cat("all_production", all(s$production_n_reps_met), "all_pass_band", all(s$passes_coverage_band), "\n"); print(aggregate(cbind(n_attempted,n_converged,n_eligible) ~ cell_id + interval_method, s, unique), row.names=FALSE); print(range(s$coverage)); print(range(s$coverage_mcse));'`
  -> PASS; all rows had `production_n_reps_met = TRUE` and
  `passes_coverage_band = TRUE`; coverage ranged 0.9269--0.9610 and MCSE
  ranged 0.0088--0.0119.
- `Rscript --vanilla -e 'x <- read.csv("/tmp/gllvmtmb-lv-wald-local-r500-20260628/lv-wald-coverage-long.csv"); bad <- subset(x, !eligible | !ci_available | !fit_converged | !sdreport_ok | !pd_hessian); cat("long rows", nrow(x), "bad rows", nrow(bad), "\n"); print(aggregate(rep ~ cell_id + interval_method, unique(bad[, c("cell_id", "interval_method", "rep")]), length), row.names=FALSE); print(unique(bad[, c("cell_id", "rep", "rep_seed", "fit_converged", "pd_hessian", "sdreport_ok", "ci_available", "eligible", "fit_convergence_code", "max_gradient")]), row.names=FALSE)'`
  -> PASS; all optimizer fits converged and all `sdreport_ok` values were
  true, but non-PD Hessians made 47 fitted replicates ineligible: 13 in
  `gaussian-d1-n72-t3`, 13 in `gaussian-d2-n96-t4`, and 21 in
  `gaussian-d2-n160-t4`.
- `Rscript --vanilla -e 's <- read.csv("/tmp/gllvmtmb-lv-wald-local-r500-20260628/lv-wald-coverage-summary.csv"); z <- subset(s, interval_method == "wald_z")[, c("cell_id","target_id","coverage","coverage_mcse","n_eligible")]; t <- subset(s, interval_method == "wald_t_unit")[, c("cell_id","target_id","coverage","coverage_mcse","n_eligible")]; names(z)[3:5] <- c("coverage_z","mcse_z","n_eligible_z"); names(t)[3:5] <- c("coverage_t","mcse_t","n_eligible_t"); m <- merge(z, t, by=c("cell_id","target_id")); m$delta_t_minus_z <- m$coverage_t - m$coverage_z; print(m[order(m$cell_id, m$target_id), ], row.names=FALSE); print(summary(m$delta_t_minus_z)); cat("t better count", sum(m$delta_t_minus_z > 0), "equal", sum(m$delta_t_minus_z == 0), "worse", sum(m$delta_t_minus_z < 0), "\n")'`
  -> PASS; `wald_t_unit` exceeded `wald_z` for 12 of 14 target rows, tied for
  two, and was never worse. The improvement range was 0.0020--0.0063 where
  positive.
- Compact artifacts committed under
  `docs/dev-log/artifacts/lv-wald-coverage/`:
  `2026-06-28-local-r500-summary.csv`,
  `2026-06-28-local-r500-excluded-replicates.csv`, and
  `2026-06-28-local-r500-t-vs-z.csv`.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-check-lib:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS after the r500 artifacts and docs were recorded; R CMD check
  completed in 4m46.7s with 0 errors, 0 warnings, and 0 notes. As in earlier
  slices, `check()` did not re-document because local roxygen2 8.0.0 differs
  from the declared 7.3.2.

## Consistency Audit

No user-facing documentation changed. The early local runs are labelled as
pilot evidence only; the later r500 run is labelled as local validation
evidence for `LV-02`. The broader `latent(lv = ~ x)` arc remains incomplete, and
non-Gaussian/binomial/mixed/source-specific intervals still require their own
coverage evidence before interval claims can be widened.

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

No DRAC array was submitted, and no 3-OS PR/merge evidence exists for this
queued branch yet. The queued branch now has a local R CMD check 0/0/0 after
the evidence updates. The local r500 grid covers the current ordinary Gaussian
native TMB cells only; it does not cover binomial intervals, non-Gaussian
intervals, mixed-family rows, masks, `X + X_lv`, Julia bridge CIs, or
source-specific `lv`. Profile/bootstrap rescue was not needed for these four
ordinary Gaussian Wald cells, but remains a separate slice if later cells
under-cover.

## Next Actions

Move the same harness to DRAC or an equivalent batch environment at >=500
reps/cell for `wald_z` and `wald_t_unit`, then audit coverage, MCSE, failed-fit
denominators, and the small-N t comparator before changing any public interval
claim.
