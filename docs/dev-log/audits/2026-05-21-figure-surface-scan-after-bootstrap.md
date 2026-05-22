# Figure Surface Scan After Bootstrap Plot Slices

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Review lenses:** Rose, Florence, Fisher, Pat, Grace
**Spawned subagents:** none

## Purpose

Re-scan the article surface after the covariance table helpers, raindrop plots,
bootstrap interval plumbing, morphometrics cached bootstrap fixture, and
missing-response public-docs slices. The goal is to choose the next figure work
from repository evidence rather than from memory.

## Command

```sh
rg -n "extract_Sigma\\(|extract_Sigma_table\\(|extract_correlations\\(|plot_correlations\\(|plot_Sigma_table\\(|cov2cor\\(|geom_tile\\(|geom_text\\(|extract_communality\\(|extract_repeatability\\(|plot\\(fit.*type = \\\"correlation|type = \\\"communality|type = \\\"integration" vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd README.md
```

## Public Path Status

| Surface | Current status | Next action |
|---|---|---|
| `README.md` | Wide-first wording, `plot_correlations()` quick example, and MIS-21 missing-response boundary are now present. | Keep stable unless user asks for landing-page polish. |
| `vignettes/gllvmTMB.Rmd` | Get Started now has wide-formula route, missing-response boundary, tidy correlation rows, `plot_correlations()`, and optional matrix view. | Candidate for later ordination plot polish; not urgent for covariance/correlation. |
| `vignettes/articles/morphometrics.Rmd` | Now uses `extract_Sigma_table()` for fitted heatmap data, cached bootstrap raindrops via `plot_correlations(boot)`, and cached bootstrap ellipse borders/stars. | Next improvement is a reusable estimate-vs-truth helper, not more hand-built heatmap code. |
| `vignettes/articles/covariance-correlation.Rmd` | Already has `extract_Sigma_table()` + `plot_Sigma_table()` and `extract_correlations()` + `plot_correlations()`. Still has a teaching heatmap for latent-only vs latent+unique truth comparison. | Keep the heatmap for now; replace only after an estimate-vs-truth helper exists. |

## Hidden Or Technical Surface

| Surface | Evidence from scan | Florence / Rose action |
|---|---|---|
| `vignettes/articles/functional-biogeography.Rmd` | Uses `extract_Sigma()` matrices, `extract_communality()`, raw `R_B` / `R_W` matrices, `geom_tile()`, and `geom_text()` around lines 224, 238, 371-424. | High-value future plot-helper slice. Replace raw correlation heatmaps with metadata-bearing helper output only after article tier / validation status is refreshed. |
| `vignettes/articles/behavioural-syndromes.Rmd` | Uses `extract_Sigma()` `$R`, `extract_repeatability()`, `extract_communality()`, truth-vs-fit correlations, and recovery tables around lines 385-538. | Strong candidate for a future Figure-3 family: repeatability + communality + between/within correlations. Keep hidden until interpretation and validation story are current. |
| `vignettes/articles/mixed-family-extractors.Rmd` | Shows `extract_Sigma()`, `extract_correlations()`, bootstrap rows, and `extract_communality()` around lines 86-151. | Good candidate for `plot_correlations()` and bootstrap-provenance metadata once mixed-family public wording is reviewed. |
| `vignettes/articles/joint-sdm.Rmd` | Uses `extract_correlations()` and raw `extract_Sigma()` matrices around lines 304-315. | Candidate for `plot_correlations()` after binary/JSDM validation status is checked. |
| `vignettes/articles/phylogenetic-gllvm.Rmd` | Shows phylogenetic/non-phylogenetic Sigma matrices and communalities around lines 172-193 and 259. | Defer until phylogenetic validation and notation audit are current; avoid promoting unsupported strength. |
| `vignettes/articles/lambda-constraint.Rmd` | Uses custom `geom_tile()` / `geom_text()` for constraint heatmaps around lines 354-357. | Not a Sigma/correlation plot-helper target; leave as constraint-matrix teaching figure. |
| `vignettes/articles/profile-likelihood-ci.Rmd` | Focuses on CI targets and uses `extract_repeatability()` / `extract_correlations()` examples around lines 207-247. | Defer; plot helpers could help but profile diagnostics should remain the article's centre. |

## Prioritized Next Slices

1. **Estimate-vs-truth table helper for example objects.** This would replace
   article-local `cov2cor()` / `geom_tile()` truth comparisons in
   Morphometrics and Covariance/correlation with a reusable row-first table.
2. **Functional-biogeography hidden article scan/fix.** It has the densest raw
   heatmap surface, but should stay hidden unless validation status is refreshed.
3. **Behavioural-syndromes figure family.** Needs careful Florence + Fisher work
   because repeatability, communality, and between/within correlations can
   mislead if row spacing or interval provenance is weak.
4. **Mixed-family extractor article plotting.** Use the new metadata notes so
   bootstrap provenance is visible, but only after Rose checks mixed-family
   public claims against the validation-debt register.

## Decision

The public first-reader path is now acceptable for this overnight lane. The
next code slice should be the estimate-vs-truth table helper if we continue
plot infrastructure. The next article slice should be hidden-surface work, not
new public promotion.
