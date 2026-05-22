# After-task report: wrong-object message regression tests

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice added regression tests for the wrong-object wording cleanup. It did
not change implementation behavior beyond test coverage.

## What changed

- `test-plot-covariance-tables.R` now checks that `plot_correlations(list())`,
  `plot_Sigma_table(list())`, and `plot_Sigma_heatmap(list())` ask for a fit
  returned by `gllvmTMB()`.
- `test-suggest-lambda-constraint.R` now checks the same wording for
  `suggest_lambda_constraint(list())`.

## Validation

- `air format tests/testthat/test-plot-covariance-tables.R tests/testthat/test-suggest-lambda-constraint.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables|suggest-lambda-constraint", stop_on_failure = TRUE)'`
  returned 237 passes, 0 failures, 0 warnings, 0 skips.
- `git diff --check` was clean before adding this report.
- Test-guard scan:
  `rg -n 'wrong object|fit returned by .*gllvmTMB|plot_correlations\(list\(\)\)|plot_Sigma_table\(list\(\)\)|plot_Sigma_heatmap\(list\(\)\)|suggest_lambda_constraint\(list\(\)\)' tests/testthat/test-plot-covariance-tables.R tests/testthat/test-suggest-lambda-constraint.R`
  returned expected tests for all four wrong-object surfaces.

## Review lenses

- Ada treated this as a guard slice after the message cleanup.
- Pat: errors now stay constructor-first for applied users.
- Rose: tests make the wording less likely to regress.
- Grace scope: no dependency, docs, or platform change.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no model, estimator, likelihood, or
   formula grammar changed.
3. Documentation: not applicable; test-only guard.
4. Runnable example: focused test files exercise the new errors.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Pat, Rose, and Grace lenses applied as above.

## Residual risk

- Full package tests and 3-OS CI still need to run before merge.
