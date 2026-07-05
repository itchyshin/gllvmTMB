# After-Task Report: Multi-Start Non-Finite Selection Guard

Date: 2026-07-04

Branch: `codex/r-bridge-grouped-dispersion`

## Goal

Close issues #684 and #685 by making multi-start selection ignore non-finite
optimizer objectives and keeping `fit$opt` aligned with
`restart_history$selected`.

## Files Changed

- `R/fit-multi.R`
- `tests/testthat/test-multi-start-sdreport-consistency.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-multistart-nonfinite-selection-guard.md`

## What Changed

- The multi-start loop now extracts each restart objective once and treats only
  finite objectives as successful selection candidates.
- `NaN`, `Inf`, and `-Inf` objectives are recorded in `restart_history` but can
  no longer win `best_opt` or crash the `if` comparison.
- Selection marking is centralized in `.gllvmTMB_select_restart_history()`, so
  the selected restart is drawn from the same finite-success set as `best_opt`.
- Added a pure regression with `NaN`, `-Inf`, and finite objective rows.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); cat("parse-ok\n")'
```

Result: parse passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-multi-start-sdreport-consistency.R", reporter = "summary")'
```

Result: focused multi-start tests passed. Fit-heavy rows skipped under CRAN
mode; the new pure restart-selection row ran.

## Rose Verdict

OK. This is restart provenance hardening only. It does not claim that any
start strategy improves convergence rates, coverage, or model recovery.
