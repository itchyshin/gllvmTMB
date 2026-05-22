# After-task report: wrong-object message cleanup

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice cleaned a small set of user-facing wrong-object errors that still
exposed the internal `gllvmTMB_multi` class. It did not change object classes,
dispatch, or exported function signatures.

## What changed

- `plot_correlations()` now asks for a fit returned by `gllvmTMB()`, a
  `bootstrap_Sigma` object, or `extract_correlations()` rows.
- `plot_Sigma_table()` and `plot_Sigma_heatmap()` now ask for a fit returned by
  `gllvmTMB()`, a `bootstrap_Sigma` object, or `extract_Sigma_table()` rows.
- `suggest_lambda_constraint()` now asks for a fit returned by `gllvmTMB()` or a
  formula.

## Validation

- `air format R/plot-covariance-tables.R R/suggest-lambda-constraint.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables|suggest-lambda-constraint", stop_on_failure = TRUE)'`
  returned 233 passes, 0 failures, 0 warnings, 0 skips.
- `git diff --check` was clean before adding this report.
- Wrong-object wording scan:
  `rg -n '\{\.cls gllvmTMB_multi\} fit|must be a .*gllvmTMB_multi.*fit|Pass a gllvmTMB_multi|fit returned by \{\.fun gllvmTMB\}' R/plot-covariance-tables.R R/suggest-lambda-constraint.R tests/testthat`
  found no stale wrong-object hits in the touched files and confirmed the
  replacement `gllvmTMB()` messages.

## Review lenses

- Ada kept this as a narrow reference-message cleanup.
- Pat checked the user path: users should see the constructor they know, not an
  internal class name.
- Rose checked the stale-message scan.
- Grace scope: no docs, dependency, or platform change.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no model, estimator, likelihood, or
   formula grammar changed.
3. Documentation: not applicable; no roxygen or Rd changed.
4. Runnable example: focused tests covering the touched functions still pass.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Pat, Rose, and Grace lenses applied as above.

## Residual risk

- Other reference pages intentionally expose S3 method names such as
  `plot.gllvmTMB_multi()` because those are the actual R method topics.
