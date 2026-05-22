# Covariance / Correlation Plot Surface Scan

**Date**: 2026-05-21  
**Branch**: `codex/florence-covariance-plots-2026-05-21`  
**Review lenses**: `Rose / Florence / Fisher / Pat / Grace`

## Purpose

Find public or soon-public places where covariance, correlation, or
communality output is still shown as raw matrices or tables even though the
package now has report-ready plot helpers.

## Public Surface

| Surface | Finding | Action in this slice |
|---|---|---|
| `README.md` | The first example printed `extract_correlations()` rows but did not show the plot helper. | Changed the quick example to store `corr_rows` and call `plot_correlations(corr_rows)`. |
| `vignettes/gllvmTMB.Rmd` | Get Started printed pairwise correlation rows and then a matrix. | Kept the tidy rows, added `plot_correlations(corr_rows)` before the optional matrix view. |
| `vignettes/articles/morphometrics.Rmd` | Already integrated a raindrop plot over `extract_correlations()` rows. | No new edit beyond the prior Morphometrics raindrop slice. |
| `vignettes/articles/covariance-correlation.Rmd` | The concept article had a heatmap, but `extract_Sigma()` output still appeared as matrices and fitted correlations were not shown through the helper. | Added `extract_Sigma_table()` + `plot_Sigma_table()` for upper-triangle off-diagonal `Sigma_unit` entries, and `extract_correlations()` + `plot_correlations()` for the latent + unique model. |
| `vignettes/articles/api-keyword-grid.Rmd` | Technical syntax reference; not a fitted-output interpretation article. | Leave unchanged. |
| `vignettes/articles/response-families.Rmd` | Technical family reference; covariance/correlation language is cautionary rather than a rendered fitted example. | Leave unchanged until a mixed-family worked example is promoted. |
| `vignettes/articles/convergence-start-values.Rmd` | Focuses on fit health, no table-heavy covariance interpretation surface. | Leave unchanged. |
| `vignettes/articles/pitfalls.Rmd` | Uses short diagnostic snippets to show failure modes. | Leave unchanged for now; revisit only if a full covariance failure-mode plot is added. |

## Hidden Or Technical Surface

| Surface | Finding | Recommended next action |
|---|---|---|
| `vignettes/articles/mixed-family-extractors.Rmd` | Shows Sigma matrices, pairwise correlations, bootstrap rows, and communality in a hidden mixed-family article. | Good next candidate once mixed-family public status is settled; use `plot_correlations()` for Fisher/bootstrap rows and `plot_Sigma_table()` only for interval-bearing bootstrap-derived Sigma rows. |
| `vignettes/articles/behavioural-syndromes.Rmd` | Large hidden worked example with between/within correlation matrices, repeatability, communality, and recovery tables. | High-value future Florence slice, but keep hidden until the article tier and validation story are refreshed. |
| `vignettes/articles/phylogenetic-gllvm.Rmd` | Shows phylogenetic and non-phylogenetic Sigma matrices and communalities. | Future slice should pair visual decomposition plots with careful Fisher wording; do not promote before phylogenetic validation rows are current. |
| `vignettes/articles/joint-sdm.Rmd` | Has latent-scale species-correlation output with CIs. | Good candidate for `plot_correlations()` after binary/JSDM evidence status is checked. |
| `vignettes/articles/profile-likelihood-ci.Rmd` | Already focused on uncertainty methods; plot helper use may be useful but should not distract from profile diagnostics. | Defer until interval-target wording is stable. |

## Decision

This slice promotes plot helpers on the public path only where the helper
improves interpretation without widening the statistical claim. `plot_correlations()`
is ready for first-reader articles because interval provenance is carried by
`extract_correlations()`. `plot_Sigma_table()` is useful for report-ready point
estimates, but captions must say when finite interval bounds are absent.

The next clean slice is not more public surface expansion. It is interval
plumbing: bootstrap-derived Sigma-table rows, communality interval rows, and
tests that those rows feed the plot helpers without hand-built joins.
