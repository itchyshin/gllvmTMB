# 2026-06-30 -- LV binomial Wald coverage harness

## 1. Goal

Extend the Design 73 native LV Wald coverage infrastructure from the
ordinary Gaussian `B_lv` cells to the first pure-binomial standard-link
cells, without promoting binomial interval calibration before production
replicates exist.

Mathematical contract: no public R API, likelihood, formula grammar, family,
NAMESPACE, generated Rd, vignette, or pkgdown navigation changed. The dev
harness still targets the trait-scale effect
`B_lv = Lambda alpha^T`; the new binomial DGP uses
`z_i = x_i alpha + e_i` and
`y_it ~ Binomial(n_trials, g^{-1}(beta_t + lambda_t z_i))` for
`g` in logit, probit, and cloglog.

## 2. Implemented

- Extended `dev/lv-wald-coverage.R` from four Gaussian cells to seven native
  cells: the existing Gaussian grid plus `binomial-logit-d1-n160-t3`,
  `binomial-probit-d1-n160-t3`, and `binomial-cloglog-d1-n160-t3`.
- Added family/link/trial metadata to the plan, replicate rows, and summaries,
  and added a multi-trial binomial DGP using the same trait-scale
  `B_lv = Lambda alpha^T` estimand.
- Routed binomial cells through native TMB
  `latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x)` with
  `se = TRUE`, preserving the existing `wald_z` and `wald_t_unit` interval
  comparators.
- Updated the SLURM wrapper text and task-count path so a full default run is
  now a 7 x 500-rep campaign.
- Updated Design 73, the validation-debt register, and capability status to
  say binomial interval coverage is launch-ready infrastructure only.

## 3a. Decisions and Rejected Alternatives

- Kept binomial interval calibration out of the public claim. The new cells
  create a production-run gate; they do not make `LV-05` interval-covered.
- Started with rank-1 multi-trial logit/probit/cloglog cells because those are
  the native binomial point/recovery rows already admitted under `LV-05`.
- Did not bundle mixed-family, ordinal, native count-family, source-specific,
  or Julia bridge interval work into this slice. Those remain separate rows.
- Kept the live binomial fit smoke opt-in through `GLLVMTMB_LV_WALD_SMOKE=true`
  so default tests check the harness logic without forcing numerical fits.

## 4. Files Touched

- `dev/lv-wald-coverage.R`
- `dev/lv-wald-coverage-slurm.sh`
- `tests/testthat/test-lv-wald-coverage-harness.R`
- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-30-lv-binomial-wald-coverage-harness.md`

## 5. Checks Run

- `air format dev/lv-wald-coverage.R tests/testthat/test-lv-wald-coverage-harness.R`
  -> PASS.
- `Rscript --vanilla -e 'invisible(parse("dev/lv-wald-coverage.R")); invisible(parse("tests/testthat/test-lv-wald-coverage-harness.R")); cat("parse-ok\n")'`
  -> PASS.
- `git diff --check` -> PASS before dev-log/report edits.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-wald-coverage-harness", reporter = "summary")'`
  -> PASS; 50 expectations passed and the two opt-in live fit smokes skipped.
- `GLLVMTMB_LV_WALD_SMOKE=true NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-wald-coverage-harness", reporter = "summary")'`
  -> PASS; the Gaussian and binomial one-rep live smokes both ran.
- `GLLVMTMB_LV_WALD_COVERAGE_CLI=true NOT_CRAN=true ... Rscript --vanilla dev/lv-wald-coverage.R --mode=preflight --n-reps=2 --seed-base=20260630 --results-dir=/tmp/gllvmtmb-lv-binomial-preflight-20260630`
  -> PASS; wrote a 14-task plan with 8 Gaussian tasks and 6 binomial tasks.
- `bash -n dev/lv-wald-coverage-slurm.sh` -> PASS.
- `SLURM_ACTION=write RESULTS_DIR=/tmp/gllvmtmb-lv-binomial-slurm-write-20260630 N_REPS=2 SEED_BASE=20260630 bash dev/lv-wald-coverage-slurm.sh`
  -> PASS; wrote an sbatch file with `#SBATCH --array=1-14`.
- `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,isDraft,url`
  -> PASS; `[]`, no open gllvmTMB PRs.
- `git log --all --oneline --since="6 hours ago" -- <touched lane files>`
  -> PASS; no recent commits touched this lane's files.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'LV-05 binomial interval' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; no matching open issue.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'latent lv interval coverage' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; no matching open issue.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-30-lv-binomial-wald-coverage-harness.md`
  -> PASS.
- `git diff --check`
  -> PASS after dev-log / after-task edits.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-wald-coverage-harness", reporter = "summary")'`
  -> PASS after dev-log / after-task edits; the opt-in live fit smokes skipped.

## 6. Tests of the Tests

The expanded grid test would fail if the default campaign silently reverted to
four Gaussian-only cells or dropped any standard binomial link. The binomial
DGP test checks that the generated data uses `success`/`failure`, preserves
the 18-trial denominator, and stores the expected link-scale `B_lv` truth.
The binomial summary test would fail if link or `n_trials` metadata were lost
before aggregation. The opt-in smoke would fail if the new binomial cell could
not reach a native TMB fit with finite `extract_lv_effects()` standard errors.

## 7a. Issue Ledger

- No dedicated open issue was found for `LV-05 binomial interval` or
  `latent lv interval coverage`; this slice records evidence through Design 73
  and the validation-debt register rather than closing an issue.
- Roadmap tick: N/A; no `ROADMAP.md` row, status chip, or progress bar changed.
- Fixed during development: the first cell-table patch duplicated the `d`
  column before the parser/checks were run. It was corrected before tests.
- Deferred: the >= 500-rep/cell binomial production run, artifact audit, any
  profile/bootstrap rescue, mixed-family `X_lv`, ordinal `X_lv`, and phylo
  Model A exposure.

## 8. Consistency Audit

The edited design rows keep `LV-05` partial and explicitly call the new
binomial cells launch infrastructure rather than interval evidence. The
Gaussian `LV-02` row remains the only covered native `B_lv` interval row. The
capability-status text now says binomial interval calibration is still gated,
while the next bounded action is to run the binomial production interval
campaign. The SLURM wrapper now says 7 x 500 reps, matching the generated plan.

## 9. What Did Not Go Smoothly

Only one small code-edit bump: the first patch to `LV_WALD_CELLS` duplicated
the `d` column while adding binomial metadata. The file was inspected and fixed
before formatting, parsing, or tests.

## 10. Known Residuals

No binomial production coverage artifact exists yet. No row should be read as
claiming calibrated native binomial `B_lv` intervals. No GLLVM.jl change was
made in this slice, and GLLVM.jl PR #127 remains separate from this gllvmTMB
branch. `devtools::check()` and `pkgdown::check_pkgdown()` were not rerun
because this slice changes dev-only harness code, focused tests, and design
ledger text, not exported functions, roxygen, Rd, examples, or pkgdown
navigation.

## 11. Team Learning

Curie: make non-Gaussian interval gates look like Gaussian gates before
launching them: one seed per replicate, link/trial metadata, MCSE, and
failed-fit denominators.

Fisher: keep point/recovery admission and interval calibration separate. A
finite binomial `sdreport()` is enough to launch coverage, not enough to claim
coverage.

Rose: high-level status must distinguish "harness exists" from "artifact passed";
otherwise the mission-control story will overread this slice.
