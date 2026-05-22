# After-task report: rotation plotting workflow docs

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice clarified how ordination rotation should be interpreted in reference
documentation and plot captions. It did not change rotation mathematics,
extractor output, fitting, or the public function signatures.

## What changed

- `plot.gllvmTMB_multi()` now documents that rotated ordination axes are for
  readable biplots, while `Sigma`, correlations, communality, and uniqueness
  remain the primary quantitative summaries.
- `standardize_loadings` now explicitly says it changes the displayed arrow
  scale, not the model's communality or variance decomposition.
- Ordination captions now point readers back to `Sigma` and correlation
  summaries for rotation-invariant interpretation.
- `rotate_loadings()` now frames rotation as an interpretable orientation among
  mathematically equivalent orientations, recommends covariance summaries
  before rotation, and tells users to rotate `unit` and `unit_obs` separately.
- `test-plot-gllvmTMB.R` now guards the caption wording.

## Validation

- `air format R/plot-gllvmTMB.R R/rotate-loadings.R tests/testthat/test-plot-gllvmTMB.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  regenerated `man/plot.gllvmTMB_multi.Rd` and `man/rotate_loadings.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB|rotate-compare-loadings|rotation-advisory", stop_on_failure = TRUE)'`
  returned 261 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- `git diff --check` was clean before adding this report.
- Wording scan:
  `rg -n 'Use Sigma and correlation summaries|raw fitted orientation|uniquely "right"|primary quantitative summaries|standardized loadings|method = "promax"' R/plot-gllvmTMB.R R/rotate-loadings.R man/plot.gllvmTMB_multi.Rd man/rotate_loadings.Rd tests/testthat/test-plot-gllvmTMB.R`
  returned expected hits in source, generated Rd, and tests.

## Review lenses

- Ada kept this to reference wording and caption guidance.
- Florence: ordination captions now reduce the risk that readers over-read raw
  or rotated axes as discovered biological truth.
- Pat: the user path is clearer: fit, inspect covariance summaries, then plot
  rotated axes.
- Rose checked source/Rd/test parity.
- Grace scope: focused tests and pkgdown checks pass; no full package check or
  3-OS CI yet.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no estimator, likelihood, family, or
   formula grammar changed.
3. Documentation: roxygen and generated Rd updated together.
4. Runnable user-facing example: existing ordination plot tests exercise the
   caption path; no vignette/article source changed in this slice.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Florence, Pat, Rose, and Grace lenses applied as above.

## Residual risk

- Full `devtools::test()` and `devtools::check()` remain for PR readiness.
