# After-Task Report: Method and Plot Reference Wording

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned a narrow group of fitted-model method and plot-helper reference pages.
The goal was to make `?print`, `?summary`, `?plot`, `?predict`,
`?simulate`, `?tidy`, and the covariance plot helpers read as user-facing
gllvmTMB help instead of an internal class map.

This is a documentation and wording slice. It does not change model fitting,
extractor calculations, plotting geometry, or article examples. The only code
message changed was the `sanity_multi()` wrong-object error, which now asks for
"a fit returned by gllvmTMB()" rather than a `gllvmTMB_multi` class name.

## Files Touched

- `R/methods-gllvmTMB.R`
- `R/plot-gllvmTMB.R`
- `R/plot-covariance-tables.R`
- `man/gllvmTMB_multi-methods.Rd`
- `man/confint.gllvmTMB_multi.Rd`
- `man/tidy.gllvmTMB_multi.Rd`
- `man/simulate.gllvmTMB_multi.Rd`
- `man/sanity_multi.Rd`
- `man/predict.gllvmTMB_multi.Rd`
- `man/plot.gllvmTMB_multi.Rd`
- `man/plot_correlations.Rd`
- `man/plot_Sigma_table.Rd`
- `man/plot_Sigma_heatmap.Rd`

## What Changed

- Changed fitted-model method titles from internal-class wording such as
  "`gllvmTMB_multi` fit" to "fitted gllvmTMB model".
- Changed method `@param x` / `@param object` text to "A fit returned by
  `gllvmTMB()`."
- Changed plot-helper input text to say fitted-object calls accept a fit
  returned by `gllvmTMB()`.
- Replaced the user-visible phrase "attached plot data" with "returned plot
  data" on `plot_Sigma_heatmap()`.

## Validation

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated the affected Rd files.
- `Rscript --vanilla -e 'devtools::test(filter = "^(plot-covariance-tables|plot-gllvmTMB|sanity-multi|tidy-predict)$")'`
  -> 385 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.
- Stale wording scan:
  `rg -n 'attached plot data|Plot a fitted multivariate `gllvmTMB_multi` model|Confidence intervals on fixed effects of a `gllvmTMB_multi` fit|Tidy a `gllvmTMB_multi` fit|Simulate new responses from a fitted `gllvmTMB_multi`|Predict from a `gllvmTMB_multi` fit|Convergence and parameter sanity report for a `gllvmTMB_multi` fit|A `gllvmTMB_multi` fit\\.|A \\\\code\\{gllvmTMB_multi\\} fit\\.' ...`
  -> no hits in the touched source/Rd files.

## Definition-of-Done Notes

- Implementation: local branch only. Not merged, not pushed, and no 3-OS CI on
  this branch yet.
- Simulation recovery test: not applicable; this slice changes documentation
  and one user-facing error message only.
- Documentation: roxygen and generated Rd were updated together.
- Runnable user-facing example: unchanged; this slice deliberately edited
  method and plot reference wording, not examples or articles.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose-style checks were applied through stale-word scans,
  focused tests, and `pkgdown::check_pkgdown()`.

## Residuals

- Many extractor and diagnostic pages still use `gllvmTMB_multi` in argument
  text; those are the next audit clusters.
- The `_pkgdown.yml` Reference contents still use S3 method topic aliases such
  as `print.gllvmTMB_multi`; that is expected unless a later regrouping slice
  changes topic aliases or index presentation.
- Main-site deployment for PR #233 still waits on the Windows R-CMD-check job
  for commit `c1dc2e4`.
