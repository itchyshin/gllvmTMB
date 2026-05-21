# After-task: extraction and plotting contract metadata

**Date:** 2026-05-21
**Branch:** `codex/article-audit-2026-05-20`
**Issue ledger:** #230; #228 inspected and left parked
**Slice:** 10
**Active reviewers:** Ada, Emmy, Fisher, Florence, Pat, Grace, Rose, Noether.
**Spawned review agents:** Pat/user tester, Noether-Fisher reviewer,
Grace/reproducibility, Rose/systems audit.

## Goal

Add the first concrete extraction/plotting infrastructure needed before more
articles return: report-ready table conventions and plot objects that carry
metadata useful for article and figure audits.

## Mathematical Contract

No likelihood, parameter transform, formula grammar, family, or NAMESPACE
contract changed.

The plotting metadata distinguishes rotation-invariant summaries
(`Sigma`, correlations, repeatability, communality, variance shares) from
rotation-ambiguous summaries (loadings and ordination axes). This is a
reporting contract, not a new estimator.

## Implemented

- Added `docs/design/53-report-ready-extractor-plot-contract.md`.
- Added internal helper `.gtmb_plot_contract()` to attach
  `attr(p, "gllvmTMB_meta")` to every `plot.gllvmTMB_multi()` result.
- Added internal helper `.gtmb_canonical_levels()` for metadata-level labels.
- Attached `gllvmTMB_meta` to plot types:
  - `correlation`
  - `loadings`
  - `integration`
  - `variance`
  - `ordination`
- Attached `attr(p, "gllvmTMB_data")` to ordination plots, with `scores` and
  `loadings`.
- Extended `gllvmTMB_data` to correlation, loadings, integration, and variance
  plots so most plot types expose the prepared data through both `p$data` and
  the attribute.
- Added a first Florence safety pass: internal colourblind-safe palette and
  figure theme; muted correlation diagonals and visible between/within tier
  borders; loadings/ordination captions about rotation and sign ambiguity;
  integration row-level interval status; and horizontal reader-labelled
  variance decomposition.
- Preserved `extract_Sigma()` notes in correlation plot metadata so latent-only
  warnings are not hidden by a polished heatmap.
- Fixed Morphometrics heatmap caption drift: it now says total
  `Sigma_B = Lambda Lambda^T + Psi`, not `Lambda Lambda^T` alone.
- Fixed `plot(type = "ordination")` default behavior/documentation: omitted
  `level` now defaults to between-unit (`unit`), while explicit multi-level
  ordination remains an error.
- Updated plot tests to assert metadata, plot data, interval columns, and
  ordination default behavior.
- Updated roxygen and regenerated `man/plot.gllvmTMB_multi.Rd`.
- Updated `ROADMAP.md` slice 10 and infrastructure rows.

## Files Changed

- `R/plot-gllvmTMB.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- `man/plot.gllvmTMB_multi.Rd`
- `vignettes/articles/morphometrics.Rmd`
- `docs/design/46-visualization-grammar.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `ROADMAP.md`
- `docs/dev-log/team-improvements.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-extraction-plotting-contract.md`
- `docs/dev-log/recovery-checkpoints/2026-05-21-052517-codex-checkpoint.md`

## Tests And Checks

- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`
  - Initial metadata pass: 85 tests, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`
  - After data-first and Florence palette/default updates: 98 tests,
    0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Regenerated `man/plot.gllvmTMB_multi.Rd`.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/morphometrics", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/morphometrics.html`; only the pre-existing
    `../logo.png` warning.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Passed: `No problems found.`
- `git diff --check`
  - Clean.

## Tests Of The Tests

The updated plot tests now check the public object contract, not only that
`ggplot2` can print the plot:

- every plot type has `gllvmTMB_meta`;
- metadata names are stable;
- source extractors are named;
- canonical levels are recorded;
- loadings and ordination are marked rotation-ambiguous;
- ordination exposes `scores` and `loadings` via `gllvmTMB_data`.
- correlation exposes report-ready pair columns plus display-support columns;
- integration exposes row-level `has_interval`, `interval_method`, and
  `interval_status`;
- omitted `level` now works for `plot(type = "ordination")` and defaults to
  `unit`.

This would catch a future plotting refactor that silently drops audit metadata
while still returning a valid ggplot object.

## Consistency Audit

Exact scan:

```sh
rg -n "gllvmTMB_meta|gllvmTMB_data|report-ready|slice 10|Extraction/plotting" R/plot-gllvmTMB.R tests/testthat/test-plot-gllvmTMB.R man/plot.gllvmTMB_multi.Rd docs/design/53-report-ready-extractor-plot-contract.md ROADMAP.md
```

Verdict: source, tests, generated help, design doc, and roadmap all mention the
metadata/report-ready contract.

Additional scans:

```sh
rg -n "steelblue|firebrick|#d33|#3b82c6|scale_fill_gradient2\\(" R/plot-gllvmTMB.R vignettes/articles/morphometrics.Rmd
rg -n "covered / partial / blocked|covered.*boundary|blocked.*boundary|interval_status.*covered" docs/design/46-visualization-grammar.md docs/design/53-report-ready-extractor-plot-contract.md
rg -n "ordination.*default|single level required|omitted.*level" R/plot-gllvmTMB.R man/plot.gllvmTMB_multi.Rd
rg --pcre2 -n "Sigma_B = Lambda Lambda\\^T(?!\\s*\\+\\s*Psi)" vignettes/articles/morphometrics.Rmd pkgdown-site/articles/morphometrics.html
```

Verdict: old blue/red literals were removed from plot helpers and the
Morphometrics heatmap; interval-status vocabulary is harmonised; ordination
default wording is regenerated in Rd; no Morphometrics heatmap caption remains
with `Sigma_B = Lambda Lambda^T` missing `+ Psi`.

No user-facing formula examples, likelihood code, family code, or exported
function names changed, so no convention-change cascade was needed.

## Reviewer Notes

Ada: This keeps the reset moving toward infrastructure instead of adding more
articles.

Emmy: Plot objects now carry a small, stable metadata contract that downstream
article code can inspect.

Fisher: The metadata explicitly separates interval status from point estimates
and marks rotation-ambiguous outputs.

Florence: This remains a revise-before-publication surface, but it is now a
credible visual baseline: colourblind-safe palettes, muted fixed diagonals,
rotation/interval captions, and plot data that can be audited.

Pat: Future articles can use plot metadata rather than explaining hidden fit
internals in prose.

Grace: Targeted plot tests and pkgdown checks passed; no new dependencies were
added. `ggplot2::linewidth` remains an existing compatibility point to watch
before release.

Rose: The design docs now state that metadata/palette work is not a visual-
quality claim. Morphometrics caption drift was fixed. Hidden figure-heavy
articles still need per-figure ledgers before restoration.

Noether/Fisher: Correlation plots now preserve extractor notes, loadings and
ordination state rotation ambiguity in captions, and integration stores
row-level interval status.

## Roadmap Tick

`ROADMAP.md` now includes slice 10, "Extraction/plotting contracts". The
infrastructure-gates table points to
`docs/design/53-report-ready-extractor-plot-contract.md` and records the new
plot metadata/data attributes plus the first Florence palette/caption safety
pass.

## GitHub Issue Ledger

- #230 inspected: still open and remains the owner issue for article reset.
- #228 inspected: still open; intentionally left parked until diagnostic
  terminology, tables, and plot semantics are stable.
- #230 commented with slice update:
  <https://github.com/itchyshin/gllvmTMB/issues/230#issuecomment-4507597850>.
- #230 commented with Florence follow-up:
  <https://github.com/itchyshin/gllvmTMB/issues/230#issuecomment-4507836372>.

## Known Limitations

- No tidy covariance/correlation table helper has been added yet.
- No `vdiffr` snapshots were added.
- Plot helpers are improved but not Florence-approved as publication-grade
  until rendered HTML review passes.
- Full `devtools::test()` and `devtools::check()` were not run.

## Next Safe Slice

Add the first tidy table helper for covariance/correlation heatmaps, then use it
to replace remaining hand-built public article heatmap chunks and create a
per-figure ledger for Morphometrics.
