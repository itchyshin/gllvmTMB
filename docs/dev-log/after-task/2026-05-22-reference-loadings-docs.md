# After-Task Report: Loadings / Ordination Reference Cleanup

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Commit range:** local branch after `b6fc4e0`
**Review lenses:** Ada, Rose, Pat, Grace
**Spawned subagents:** none

## Scope

Cleaned the first reference-function cluster from the 2026-05-22 audit:
loadings, ordination, and `lambda_constraint` helper documentation. This was a
documentation/API-display slice, not a formula-grammar or likelihood change.

The public help pages now lead with a fit returned by `gllvmTMB()` rather than
the internal `gllvmTMB_multi` class. The displayed `level` default is now
`"unit"` for the touched helpers while the deprecated `"B"` / `"W"` aliases
still work through the same validation path.

## Files Touched

- `R/rotate-loadings.R`
- `R/output-methods.R`
- `R/extractors.R`
- `R/suggest-lambda-constraint.R`
- `man/rotate_loadings.Rd`
- `man/compare_loadings.Rd`
- `man/getLoadings.Rd`
- `man/getLV.Rd`
- `man/getResidualCov.Rd`
- `man/ordiplot.Rd`
- `man/VP.Rd`
- `man/extract_ordination.Rd`
- `man/suggest_lambda_constraint.Rd`
- `tests/testthat/test-rotate-compare-loadings.R`
- `tests/testthat/test-suggest-lambda-constraint.R`

No articles, README, NEWS, NAMESPACE, or likelihood files were touched.

## What Changed

- Reworded titles and parameters for `rotate_loadings()`, `compare_loadings()`,
  `getLoadings()`, `getLV()`, `getResidualCov()`, `getResidualCor()`,
  `ordiplot()`, `VP()`, `extract_ordination()`, and
  `suggest_lambda_constraint()`.
- Changed the displayed defaults for the touched `level` arguments from
  `c("unit", "unit_obs", "B", "W")` to `"unit"` while preserving accepted
  values via explicit `match.arg(..., c("unit", "unit_obs", "B", "W"))`.
- Replaced "post-hoc" wording with "rotation after fitting" or equivalent
  interpretation-preserving language.
- Updated two focused tests that were still exercising deprecated `"W"` where
  canonical `"unit_obs"` was clearer.

## Validation

- `air format R/rotate-loadings.R R/output-methods.R R/extractors.R R/suggest-lambda-constraint.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated the affected Rd files. An initial redundant
  `@inheritParams` warning on `extract_ordination()` was fixed; the final run
  completed without warnings.
- `air format tests/testthat/test-suggest-lambda-constraint.R tests/testthat/test-rotate-compare-loadings.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "rotate|ordiplot|suggest-lambda-constraint|plot-gllvmTMB")'`
  -> 309 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.
- `rg -n 'Legacy aliases|post-hoc|level = c\\(\"unit\", \"unit_obs\", \"B\", \"W\"\\)|Rotate the loadings of a fitted `gllvmTMB_multi`|Loadings matrix from a `gllvmTMB_multi`|Latent-variable scores from a `gllvmTMB_multi`|Two-axis ordination plot of a `gllvmTMB_multi`|A `gllvmTMB_multi` fit|A \\\\code\\{gllvmTMB_multi\\} fit|A \\\\code\\{gllvmTMB_multi\\} object' R/rotate-loadings.R R/output-methods.R R/suggest-lambda-constraint.R man/rotate_loadings.Rd man/getLoadings.Rd man/getLV.Rd man/getResidualCov.Rd man/ordiplot.Rd man/extract_ordination.Rd man/suggest_lambda_constraint.Rd man/VP.Rd`
  -> no hits.

## Definition-of-Done Notes

- Implementation: local branch only. Not merged, not pushed, and no 3-OS CI on
  this branch yet.
- Simulation recovery test: not applicable; this slice did not change a
  likelihood, family, keyword, estimator, or fitted-value calculation.
- Documentation: roxygen and generated Rd were updated together.
- Runnable user-facing example: existing examples were kept; no new article
  example was added because the maintainer asked to pause article expansion.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Rose/Pat/Grace-style checks were applied locally through stale
  wording scans, focused tests, and `pkgdown::check_pkgdown()`.

## Residuals

- The broader reference surface still has internal `gllvmTMB_multi` wording in
  S3 method pages, extractor pages, diagnostic pages, and deprecated-alias pages.
- `lambda_constraint = list(B = M)` remains the current public syntax for that
  argument; changing it to `unit` / `unit_obs` would be a separate API slice.
- The live homepage still depends on the post-PR #233 main R-CMD-check and
  pkgdown deployment completing successfully.
