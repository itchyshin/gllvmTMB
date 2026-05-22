# After-task report: confidence-eye reference docs

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice updated exported function help for the confidence-eye plotting
surface. It did not change plotting code or article examples.

## What changed

- `plot_correlations()` now describes `style = "eye"` as a pale frequentist
  compatibility shape with a hollow, sign-coloured estimate circle.
- `plot_Sigma_table()` now uses the same wording and states that covariance
  rows use the displayed estimate scale.
- `man/plot_correlations.Rd` and `man/plot_Sigma_table.Rd` were regenerated.

## Validation

- `air format R/plot-covariance-tables.R` completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated the two
  Rd files.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables", stop_on_failure = TRUE)'`
  returned 161 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned `No problems
  found.`
- `git diff --check` was clean before adding this report.
- Reference wording scan:
  `rg -n 'pale frequentist compatibility shape|hollow,|sign-coloured estimate circle|posterior density|raindrop" is accepted' R/plot-covariance-tables.R man/plot_correlations.Rd man/plot_Sigma_table.Rd`
  returned expected roxygen and Rd hits.

## Review lenses

- Ada kept the slice to exported help only.
- Florence checked that reference prose matches the intended visual grammar.
- Pat checked that the help says what users should expect to see.
- Rose checked roxygen/Rd agreement.
- Grace checked pkgdown.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no model, estimator, likelihood, or
   formula grammar changed.
3. Documentation: roxygen and generated Rd updated together.
4. Runnable example: existing reference examples were unchanged; focused plot
   tests still pass.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Florence, Pat, Rose, and Grace lenses applied as above.

## Residual risk

- Articles still need a later pass to switch visible example calls from the
  compatibility alias `style = "raindrop"` to the preferred `style = "eye"`.
