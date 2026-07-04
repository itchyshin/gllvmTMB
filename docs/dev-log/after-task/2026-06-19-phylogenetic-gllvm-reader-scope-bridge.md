# Phylogenetic GLLVM Reader and Scope Bridge

Date: 2026-06-19 00:58 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice started the article-council triage for
`vignettes/articles/phylogenetic-gllvm.Rmd`. It added internal gating and a
reader/scope bridge; it did not promote the article.

## Changes

- Added explicit `tier: 3` YAML.
- Added an internal article gate that points readers to the current public
  article path.
- Added a reader-path table connecting biological questions to model objects,
  code sections, and readouts.
- Added validation-row anchors and point-estimate boundary wording for the
  current phylogenetic/non-phylogenetic workflow.
- Added a diagnostic table chunk showing the key fit-health rows for both long
  and wide layouts.
- Updated the article-council ledger and dashboard surfaces.

## Verification

- The focused `phylogenetic-gllvm` pkgdown article render passed.
- The source stale-scan confirmed the new gate/row anchors and no stale
  `gllvmTMB_wide`, `meta_known_V`, `diag(U)`, `diag(S)`, `\\bf S`, estimated
  rho, or calibrated-interval wording in the touched article.
- After adding the diagnostic table, the focused article render passed again
  and rendered HTML confirmed `optimizer_convergence`, `max_gradient`,
  `sdreport`, and `pd_hessian` all pass for both long and wide layouts.
- Florence review passed the current point-estimate heatmap:
  `pkgdown-site/articles/phylogenetic-gllvm_files/figure-html/extract-total-correlations-1.png`.
- `pkgdown::check_pkgdown()` passed.
- The rendered heatmap PNG exists with nonzero dimensions (`1420x883`).

## Remaining Work

- Run rendered-asset / browser review.
- Decide public placement only after those gates pass.

## Still Not Claimed

- No public article promotion.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
