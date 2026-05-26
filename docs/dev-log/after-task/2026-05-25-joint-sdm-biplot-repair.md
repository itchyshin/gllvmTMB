# After-task: joint-SDM biplot repair

**Date:** 2026-05-25
**Branch:** `codex/joint-sdm-biplot-repair-2026-05-25`
**Spawned subagents:** none. Ada coordinated with Florence visual QA.

## Task Goal

Repair the smallest figure blocker from the `joint-sdm` rendered QA:
replace the hand-built ordination biplot with the public
`plot.gllvmTMB_multi(type = "ordination")` helper, add rendered
caption / alt text, and keep the article internal.

## Files Changed

- `vignettes/articles/joint-sdm.Rmd`
  - Replaced direct `fit_jsdm$report$Lambda_B` access and local ggplot
    geoms in the `jsdm-biplot` chunk with the public ordination helper.
  - Added `fig.cap` and `fig.alt` to the chunk.
  - Suppressed the helper's long internal caption in the article plot so
    the rendered PNG does not clip text; the rendered figure caption
    carries the rotation / sign caveat.
  - Updated nearby prose from the old `sp1` label wording to the helper's
    `trait_1` / `trait_2` labels and kept the rotation-invariance caveat.

## Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url`
  -> no open PRs before editing.
- `git log --all --oneline --since='6 hours ago'`
  -> recent #261, #265, #268, #270, and #271 activity inspected.
- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/joint-sdm.Rmd", output_file="/tmp/gllvmTMB-joint-sdm-biplot-repair.html", quiet=TRUE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/joint-sdm", lazy = FALSE)'`
  -> wrote `pkgdown-site/articles/joint-sdm.html`.
- `Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); ...; p <- plot(fit_jsdm, type="ordination", level="unit", rotation="varimax", sign_anchor="auto", standardize_loadings=TRUE); print(attr(p,"gllvmTMB_meta")); print(names(attr(p,"gllvmTMB_data"))); print(head(attr(p,"gllvmTMB_data")$loadings));'`
  -> metadata reported `rotation_status = "varimax_ordered_sign_anchored"`
  and data carried `scores`, `loadings`, and `rotation`.
- `rg -n "Ordination biplot from the fitted binary|Two-dimensional ordination|rotation-invariant|trait_1" pkgdown-site/articles/joint-sdm.html`
  -> rendered HTML contains the non-empty alt text, figure caption, and
  updated trait-label prose.
- Visual inspection of
  `pkgdown-site/articles/joint-sdm_files/figure-html/jsdm-biplot-1.png`
  -> helper biplot rendered without clipped caption text; labels are
  readable at the rendered pkgdown size.
- `git diff --check`
  -> clean.

## Florence Gate

**Verdict:** PASS for the biplot-only repair.

The biplot now uses the package plotting API, exposes the helper's
rotation metadata, avoids direct report-slot access, renders readable
labels, and attaches the rotation / sign caveat to the rendered figure
through caption and alt text.

This pass does **not** promote the full article to public Tier 1. The
Sigma heatmap remains a separate blocker from the rendered QA audit,
and the wide-format chunk is still deliberately not activated.

## Definition of Done

- **Implementation:** one article chunk and its adjacent prose changed.
- **Simulation recovery test:** not applicable; no likelihood, family,
  formula grammar, or estimator changed.
- **Documentation:** article caption / alt text and nearby prose updated.
- **Runnable user-facing example:** article renders locally and through
  `pkgdown::build_article("articles/joint-sdm", lazy = FALSE)`.
- **Check-log entry:** appended in this branch.
- **Review pass:** Florence visual QA applied to the rendered biplot.

## Known Limitations and Next Actions

- `joint-sdm` remains an internal article.
- The Sigma heatmap still needs a separate correlation-first repair.
- Wide-format live execution remains deferred.
- No `diagnostic_table()` cross-link was added.
