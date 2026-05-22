# After-Task Report: Confidence-Eye Plot Option

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Florence, Fisher, Rose, Pat, Grace
**Spawned subagents:** none

## Scope

Added the public confidence-eye spelling for covariance and correlation plot
helpers. The old `style = "raindrop"` spelling remains accepted as a
compatibility alias, but the public docs and plot metadata now use confidence
eye as the main concept.

This is a plot-helper/API-display slice. It does not change fitted models,
likelihoods, covariance extraction, interval computation, or article examples.

## Files Touched

- `R/plot-covariance-tables.R`
- `man/plot_correlations.Rd`
- `man/plot_Sigma_table.Rd`
- `man/plot_Sigma_heatmap.Rd`
- `tests/testthat/test-plot-covariance-tables.R`

## What Changed

- Added `style = "eye"` to `plot_correlations()` and `plot_Sigma_table()`.
- Kept `style = "raindrop"` as a compatibility alias that normalises to the
  same confidence-eye rendering path.
- Added `eye_level` as the public interval-level argument and retained
  `raindrop_level` as an alias.
- Changed the rendered eye geometry to a pale compatibility shape plus a
  hollow, brighter estimate circle.
- Kept interval lines optional through `show_intervals = TRUE`; they are not
  drawn by default for confidence eyes.
- Added both `gllvmTMB_confidence_eye_data` and legacy
  `gllvmTMB_raindrop_data` plot attributes for downstream checks.

## Validation

- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `plot_correlations.Rd`, `plot_Sigma_table.Rd`, and
  `plot_Sigma_heatmap.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 161 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.
- `rg -n 'confidence-I|Confidence-I|style = c\\(\"interval\", \"raindrop\"\\)|correlations_raindrop|sigma_table_raindrop|has_raindrop|Drops show|Drops use|Raindrops reconstruct|raindrops, and' R/plot-covariance-tables.R man/plot_correlations.Rd man/plot_Sigma_table.Rd man/plot_Sigma_heatmap.Rd tests/testthat/test-plot-covariance-tables.R`
  -> no hits.
- `rg -n "Deprecated alias|deprecated alias" R/plot-covariance-tables.R man/plot_correlations.Rd man/plot_Sigma_table.Rd`
  -> no hits.
- Rendered `/tmp/gllvmtmb-confidence-eye.png` from a small
  `plot_correlations(..., style = "eye")` example and inspected it visually.

## Figure Review

Florence verdict: PASS for this slice. The confidence eyes read as pale
compatibility shapes, the estimate circles are hollow and visually stronger,
the row spacing is even across rows with and without interval bounds, and the
caption states that confidence eyes are not posterior densities.

Fisher guardrail: PASS with the current wording. The docs and captions describe
the geometry as reconstructed from supplied finite interval bounds, not as a
Bayesian posterior or calibrated confidence distribution.

## Definition-of-Done Notes

- Implementation: local branch only. Not merged, not pushed, and no 3-OS CI on
  this branch yet.
- Simulation recovery test: not applicable; this slice changes plot rendering
  only.
- Documentation: roxygen and generated Rd were updated together.
- Runnable user-facing example: examples remain in the function help pages; no
  new article was added because the current lane is reference/function cleanup.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Florence/Fisher/Rose-style checks were applied through visual
  QA, focused tests, stale-word scans, and pkgdown validation.

## Residuals

- The next public step is a screenshot or rendered pkgdown review once this
  branch is pushed to a PR.
- Wider S3 method pages and extractor pages still need the reference-function
  cleanup sweep recorded in the audit plan.
- Main-site verification still waits on the post-PR #233 R-CMD-check and
  pkgdown deployment.
