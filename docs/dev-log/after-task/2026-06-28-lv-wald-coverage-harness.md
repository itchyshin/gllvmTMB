# 2026-06-28 -- LV Gaussian Wald coverage harness

## 1. Goal

Add the next LV-02 evidence slice for `latent(..., lv = ~ x)`: a native
TMB ordinary Gaussian Wald coverage campaign harness for trait-scale
`B_lv`, without promoting interval calibration before production reps.

## 2. Implemented

- Added `dev/lv-wald-coverage.R`, a dev-only runner for four complete-response
  ordinary Gaussian cells: rank 1 / rank 2 and smaller / larger `n`.
- The runner records one seed per replicate/SLURM array task, per-replicate
  RDS files, long and summary artifacts, `sessionInfo()`, and fit-health
  denominators.
- Added `tests/testthat/test-lv-wald-coverage-harness.R` for grid/task seed
  construction, failed-fit denominator arithmetic, MCSE formulas, and an
  opt-in live fit smoke.
- Updated Design 73, the validation-debt register, and capability status to
  say the harness exists but 500-rep calibration evidence is still pending.

## 3a. Decisions and Rejected Alternatives

- Targeted `B_lv = Lambda alpha^T` rather than raw `alpha` or raw `Lambda`,
  because `B_lv` is the trait-scale estimand and raw axes are not stable for
  `K > 1`.
- Kept the runner in `dev/` rather than exporting an R API. This is campaign
  infrastructure for LV-02, not a user-facing diagnostic.
- Kept Wald-only output in this slice. If the 500-rep grid undercovers, the
  next inference slice should add profile/bootstrap rescue rather than
  re-labeling Wald as calibrated.
- Made the live fit smoke opt-in with `GLLVMTMB_LV_WALD_SMOKE=true`; the
  always-on tests cover the denominator and summary logic without forcing a
  numerical fit in every test run.

## 4. Files Touched

- `dev/lv-wald-coverage.R`
- `tests/testthat/test-lv-wald-coverage-harness.R`
- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-28-lv-wald-coverage-harness.md`

## 5. Checks Run

- `air format dev/lv-wald-coverage.R tests/testthat/test-lv-wald-coverage-harness.R`
  -> PASS.
- Parse check for the new dev runner and test file -> PASS.
- `devtools::test(filter = "lv-wald-coverage-harness")` -> PASS with the
  opt-in fit smoke skipped.
- `GLLVMTMB_LV_WALD_SMOKE=true devtools::test(filter = "lv-wald-coverage-harness")`
  -> PASS, including the one-fit smoke.
- CLI-style temp pilot (`preflight` plus two reps for `gaussian-d1-n72-t3`)
  -> PASS; wrote plan, per-rep files, long/summary outputs, and session info.
- `devtools::test(filter = "lv-gaussian-recovery")` -> PASS, with the rank-2
  heavy test skipped as intended.
- `devtools::test(filter = "lv-parser-guard")` -> PASS.
- `git diff --check` -> PASS.
- `pkgdown::check_pkgdown()` -> PASS.
- `devtools::check(args = "--no-manual")` with `NOT_CRAN=true` and the temp
  MCMCglmm-capable library -> PASS, 0 errors, 0 warnings, 0 notes.

## 6. Tests of the Tests

The denominator test creates two eligible rows and one failed-fit row. It would
fail if the summariser silently dropped failed fits before computing
`n_attempted`, `fit_failure_rate`, or MCSE. The opt-in live smoke would fail if
`extract_lv_effects()` stopped returning finite `B_lv` estimates/SEs with the
expected `wald_sdreport_no_ci_validation` status.

## 7a. Issue Ledger

- Fixed during development: the first source probe ran the whole recovery test
  file and hit a missing test helper; subsequent probes sourced only helper
  definitions.
- Fixed during development: the first summariser implementation attempted to
  set row names on a `do.call()` expression; patched to store the summary
  object first.
- Deferred: the production grid, profile/bootstrap fallback, Bernoulli depth,
  missing-response compatibility, and phylo Model A DRAC campaign.

## 8. Consistency Audit

Stale-claim scans reviewed LV-02, coverage, calibration, "complete", partial,
blocked, MCSE, and failed-fit denominator wording across the edited design
docs, dev runner, and test. The expected hits keep LV-02 partial, label the
harness as infrastructure rather than calibration evidence, and keep source-
specific / mixed-family / interval claims gated. The register count stayed at
213 rows: 173 covered, 30 partial, 0 opt-in, 10 blocked.

## 9. What Did Not Go Smoothly

Two small process bumps: sourcing the full Gaussian recovery test file was the
wrong way to inspect helper output, and one initial `rg` scan needed rerunning
with safer quoting because the regex contained Markdown-style backticks.

## 10. Known Residuals

No 500-rep Gaussian Wald coverage grid has been run. The one-rep and two-rep
smokes only prove the runner/file path. `LV-02` remains partial. Wald intervals
remain labelled `wald_sdreport_no_ci_validation`; profile/bootstrap rescue is
not implemented in this slice.

## 11. Team Learning

Curie/Fisher's rule for this arc is now encoded in the harness: coverage tables
must carry MCSE and failed-fit denominators. Gauss/Noether's rule is also
preserved: `B_lv`, not raw axis parameters, is the interval target for the
ordinary Gaussian `lv` path.
