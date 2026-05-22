# After-task report: confidence-eye no-outline refinement

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice refined the confidence-eye visual contract after maintainer review.
It did not change the public API, interval calculations, or data contracts.

## What changed

- Removed the outer upper/lower line layers from confidence eyes, so the
  uncertainty area is a soft filled shape rather than a bordered eye.
- Added a quiet bottom x-axis line to the covariance-table plot theme.
- Extended tests to assert that confidence-eye plots do not include `GeomLine`
  perimeter layers and do include the bottom-axis line.

## Validation

- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables", stop_on_failure = TRUE)'`
  returned 180 passes, 0 failures, 0 warnings, 0 skips.
- Rendered
  `/tmp/gllvmTMB-confidence-eye-qa/confidence-eye-no-outline.png`.
  Florence verdict: PASS for this slice; the compatibility area is unoutlined,
  the hollow estimate circle remains legible, and the bottom axis line provides
  enough structure.
- `git diff --check` was clean before adding this report.
- Layer-contract scan:
  `rg -n 'geom_line\\(|GeomLine|axis\\.line\\.x\\.bottom|gtmb_has_bottom_axis_line' R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  returned expected hits only in the bottom-axis implementation and tests that
  forbid confidence-eye `GeomLine` layers.

## Review lenses

- Ada kept the change to visual grammar only.
- Florence checked the rendered PNG against the maintainer sketch.
- Fisher: uncertainty semantics remain unchanged; confidence eyes still display
  compatibility reconstructed from finite interval bounds.
- Rose checked that the visual choice is guarded by tests.
- Grace scope: focused plot tests pass; no dependency or documentation rebuild
  was needed.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no model, estimator, likelihood, or
   formula grammar changed.
3. Documentation: not changed; this is a visual refinement of an already
   documented style.
4. Runnable example: rendered PNG and focused tests exercise the change.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Florence, Fisher, Rose, and Grace lenses applied as above.

## Residual risk

- Full visual snapshot coverage still remains future work.
