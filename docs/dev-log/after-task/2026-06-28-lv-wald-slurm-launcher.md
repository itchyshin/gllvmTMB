# After Task: LV Gaussian Wald SLURM Launcher

## Goal

Make the Design 73 ordinary Gaussian `B_lv` coverage campaign launchable as a
DRAC-style one-seed-per-array-task run, without claiming production coverage
before the array actually finishes.

## Implemented

Added `dev/lv-wald-coverage-slurm.sh`, a dev-only shell wrapper around
`dev/lv-wald-coverage.R`. The default action is `SLURM_ACTION=test`, which
writes the plan and sbatch file and asks `sbatch --test-only` to validate the
batch script. `SLURM_ACTION=submit` submits the full array, and
`SLURM_ACTION=summarise` collects replicate RDS files into the existing long
and summary outputs.

The wrapper computes the task count from `lv_wald_coverage_grid()`. With the
default four Gaussian cells and `N_REPS=500`, the array has 2,000 tasks. Each
task calls the existing `--mode=task` CLI with one `SLURM_ARRAY_TASK_ID`, so one
array task equals one seed/replicate.

## Mathematical Contract

No statistical target changed in this slice. The launcher preserves the
existing coverage harness target:

```text
B_lv = Lambda alpha'
```

and the paired interval-method rows:

```text
wald_z       = normal-critical Wald interval
wald_t_unit  = unit-df t-critical Wald comparator
```

The launcher affects execution topology only; it does not change the DGP,
estimand, critical values, pass band, MCSE formula, or failed-fit denominator
logic.

## Files Changed

- `dev/lv-wald-coverage-slurm.sh`
- `docs/design/35-validation-debt-register.md`
- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-28-lv-wald-slurm-launcher.md`

## Checks Run

- Pre-edit lane check:
  `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> REVIEWED; only PR #569 was open.
- Pre-edit lane check:
  `git log --all --oneline --since="6 hours ago" -- 'dev/lv-wald-coverage*.sh' dev/lv-wald-coverage.R tests/testthat/test-lv-wald-coverage-harness.R docs/dev-log/check-log.md docs/dev-log/after-task docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; only the known LV bridge / coverage commits were present.
- `bash -n dev/lv-wald-coverage-slurm.sh` -> PASS.
- `SLURM_ACTION=write RESULTS_DIR=/tmp/gllvmtmb-lv-wald-slurm-write N_REPS=500 bash dev/lv-wald-coverage-slurm.sh`
  -> PASS; wrote a 2,000-task plan and sbatch file without submitting work.
- `Rscript --vanilla -e 'p <- read.csv("/tmp/gllvmtmb-lv-wald-slurm-write/lv-wald-coverage-plan.csv"); stopifnot(nrow(p) == 2000L, length(unique(p$task_id)) == 2000L, all(table(p$cell_id) == 500L)); print(table(p$cell_id)); cat("plan-ok\n")'`
  -> PASS; each of the four Gaussian cells had exactly 500 tasks.
- `rg -n '#SBATCH --array=1-2000|--mode=task|SLURM_ARRAY_TASK_ID|--n-reps="500"|--seed-base="20260628"|--interval-methods="wald_z,wald_t_unit"|--results-dir="/tmp/gllvmtmb-lv-wald-slurm-write"' /tmp/gllvmtmb-lv-wald-slurm-write/_slurm/lv-wald-coverage.sbatch`
  -> PASS; generated sbatch file uses task mode, the array task id, 500 reps,
  the default seed base, and both interval methods.
- `SLURM_ACTION=write RESULTS_DIR=/tmp/gllvmtmb-lv-wald-slurm-write-small N_REPS=3 SLURM_ARRAY_LIMIT=2 bash dev/lv-wald-coverage-slurm.sh`
  plus `rg -n '#SBATCH --array=1-12%2' ...` -> PASS; the optional concurrency
  cap is written into the array specification.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "lv-wald-coverage-harness", reporter = "summary")'`
  -> PASS with the opt-in live fit smoke skipped.
- `git diff --check` -> PASS.

## Tests Of The Tests

The launcher is shell infrastructure rather than R package code. Its practical
test is a write-mode dry run that should produce an sbatch file with the
expected array size and task-mode R command, plus a plan CSV/RDS. A broken task
count, wrong `--mode`, or missing results directory would be visible before any
DRAC submission.

The write-mode dry run exercised that contract at the production task count:
four cells by 500 reps generated 2,000 unique `task_id` rows, and the sbatch
file routed `SLURM_ARRAY_TASK_ID` to `dev/lv-wald-coverage.R --mode=task`.

## Consistency Audit

The validation-debt row `LV-02` and Design 73 now mention the SLURM launcher as
infrastructure only. The row stays `partial`; no wording says coverage has
passed, that t intervals are calibrated, or that the arc is complete.

- `rg -n 'coverage (passed|validated|calibrated)|calibrated intervals|complete.*coverage|SLURM.*(passed|coverage evidence|calibrated)|t-based.*(validated|covered|calibrated)|t-critical.*(validated|covered|calibrated)' dev/lv-wald-coverage-slurm.sh docs/design/35-validation-debt-register.md docs/design/73-predictor-informed-latent-scores.md docs/dev-log/after-task/2026-06-28-lv-wald-slurm-launcher.md docs/dev-log/check-log.md`
  -> REVIEWED; hits were historical check-log cautions, existing register
  partial/gated wording, and the scan command itself. No new SLURM or
  t-critical calibration claim was introduced.
- `rg -n 'LV-02|one-seed|array task|SLURM_ACTION|500|2000|wald_z|wald_t_unit|partial|not coverage|not production evidence' dev/lv-wald-coverage-slurm.sh docs/design/35-validation-debt-register.md docs/design/73-predictor-informed-latent-scores.md docs/dev-log/after-task/2026-06-28-lv-wald-slurm-launcher.md docs/dev-log/check-log.md`
  -> REVIEWED; expected hits show the launcher, 500-rep target, 2,000-task
  plan, paired interval methods, and `LV-02` partial boundary.

## What Did Not Go Smoothly

Totoro and DRAC were not available non-interactively from this session. Totoro
failed with `Permission denied (publickey,password)`, and DRAC hosts required
keyboard-interactive MFA. That is expected infrastructure friction, not a code
failure. This slice therefore stops at login-node-safe launch wiring and local
dry-run validation.

## Team Learning

Grace: coverage campaigns need a small submitter wrapper so login-node work is
limited to plan generation, sbatch validation, and collection. The actual fits
remain SLURM array tasks.

Fisher and Curie: one task per seed keeps failed-fit denominators auditable and
makes partial reruns straightforward.

Rose: the launch wrapper is not evidence. Keep the row partial until the
finished outputs, MCSE, failed-fit rates, and pass/fail decisions are audited.

## Known Limitations

No DRAC array was submitted. No 500-rep coverage table exists yet. No
profile/bootstrap rescue, binomial/non-Gaussian interval grid, mixed-family
row, mask row, `X + X_lv` row, or source-specific `lv` interval claim changed.
No roxygen, Rd, vignette, article, README, NEWS, or pkgdown navigation files
changed, so `devtools::document()`, `pkgdown::check_pkgdown()`, and a full
R CMD check were not rerun in this launcher-only slice.

## Next Actions

After MFA/ControlMaster is primed, run:

```sh
bash dev/power-pilot-drac-setup.sh
SLURM_ACTION=test RESULTS_DIR=/project/$USER/gllvmtmb-lv-wald \
  bash dev/lv-wald-coverage-slurm.sh
SLURM_ACTION=submit SLURM_ACCOUNT=<account> SLURM_ARRAY_LIMIT=40 \
  RESULTS_DIR=/project/$USER/gllvmtmb-lv-wald bash dev/lv-wald-coverage-slurm.sh
```

After the array finishes, run:

```sh
SLURM_ACTION=summarise RESULTS_DIR=/project/$USER/gllvmtmb-lv-wald \
  bash dev/lv-wald-coverage-slurm.sh
```
