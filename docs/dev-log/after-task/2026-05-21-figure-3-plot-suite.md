# After-task: GLLVM overview Figure 3 plot-suite

**Date:** 2026-05-21
**Branch:** `codex/article-audit-2026-05-20`
**Issue ledger:** #230
**Slice:** plotting infrastructure follow-up after slice 10
**Active reviewers:** Ada, Florence, Pat, Fisher, Noether, Emmy, Grace, Rose.

## Goal

Use the maintainer-supplied GLLVM overview paper and example figures as a
concrete target for the next plotting infrastructure slice. The aim was not to
make a final composite article figure, but to start turning Figure-3-style
outputs into small, tested, inspectable plot helpers.

## Source Material Read

- `/Users/z3437171/Downloads/GLLVM_overview.pdf`
- `/Users/z3437171/Downloads/plot_zoom_png-12.png`
- `/Users/z3437171/Downloads/plot_zoom_png-5.png`

Figure 3 in the PDF was treated as the visual grammar target:

- ordination biplot with latent scores and trait loading arrows;
- loading matrix table;
- residual/model-implied correlation matrix;
- communality/uniqueness bars.

The maintainer PNGs add the next layer we still need: dominant-axis loading
forests, score histograms/distributions, ellipse correlation matrices, and
integration-index forests with bootstrap intervals.

## Implemented

- Added `plot(type = "correlation_ellipse")`.
  - Uses `extract_Sigma()` through the existing correlation data helper.
  - Encodes correlation sign and strength by ellipse tilt/eccentricity.
  - Preserves report columns in `attr(p, "gllvmTMB_data")`.
  - Includes future-compatible `significant` and `border_colour` columns, but
    current point-estimate plots do not claim interval-backed significance.
- Added `plot(type = "communality")`.
  - Uses `extract_communality()` for available latent tiers.
  - Draws shared latent `c^2` and trait-specific uniqueness bars.
  - Exposes two rows per trait/tier with proportions summing to 1.
- Upgraded `plot(type = "ordination")`.
  - d = 1: score strip plus loading lollipops.
  - d = 2: score/loading biplot.
  - d = 3: static pair-grid biplot for all three axis pairs.
  - d > 3: length-2 axes produce one biplot; length-3 axes produce a pair
    grid for selected axes.
- Updated roxygen and regenerated `man/plot.gllvmTMB_multi.Rd`.
- Added plot tests for the new plot types and dimension-aware ordination.
- Updated `docs/design/46-visualization-grammar.md`,
  `docs/design/53-report-ready-extractor-plot-contract.md`, and `ROADMAP.md`.
- Rendered throwaway PNG previews under `/tmp/gllvmTMB-figure3-preview` and
  tightened long captions after Florence's visual pass caught clipping at
  ordinary figure sizes.

## Mathematical And Statistical Boundaries

No likelihood, parameter transform, family, formula grammar, or fitting path
changed.

The new correlation-ellipse and communality plots are point-estimate summaries
only. They are useful visual infrastructure, but they are not yet uncertainty
claims. Florence and Fisher both require interval-aware tidy tables before
black borders, stars, or whiskers can be interpreted as evidence.

Ordination remains rotation/sign ambiguous. The plot captions and metadata
keep `rotation_status = "rotation_ambiguous_loadings"` so article code cannot
silently treat axes as rotation-invariant biological mechanisms.

## Tests And Checks

- `Rscript --vanilla -e 'invisible(parse("R/plot-gllvmTMB.R")); invisible(parse("tests/testthat/test-plot-gllvmTMB.R")); cat("parse ok\n")'`
  - Passed.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Regenerated `man/plot.gllvmTMB_multi.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`
  - Passed: 139 tests, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Passed: `No problems found.`
- `git diff --check`
  - Clean.
- Throwaway preview render:
  - `/tmp/gllvmTMB-figure3-preview/correlation-ellipse.png`
  - `/tmp/gllvmTMB-figure3-preview/communality.png`
  - `/tmp/gllvmTMB-figure3-preview/ordination-3d-pair-grid.png`
  - Visual pass: structure acceptable for an infrastructure helper; captions
    shortened to avoid clipping.
- Checks rerun after caption tightening:
  - `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`
    passed: 139 tests, 0 failures, 0 warnings, 0 skips.
  - `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
    passed: `No problems found.`
  - `git diff --check` clean.
- `rg -n "correlation_ellipse|communality|3D ordination|pair grid|Figure 3|length-3|d = 3|d > 3|static pair" R/plot-gllvmTMB.R tests/testthat/test-plot-gllvmTMB.R man/plot.gllvmTMB_multi.Rd ROADMAP.md docs/design/46-visualization-grammar.md docs/design/53-report-ready-extractor-plot-contract.md`
  - Source, tests, generated help, roadmap, and design docs agree.

## Reviewer Notes

Ada: This keeps the reset anchored in infrastructure instead of adding more
fragile articles.

Florence: The new helpers are a better visual grammar baseline, not final art.
The first preview pass caught overlong captions, which were shortened. The
next design work is dominant-axis forests and score distributions, plus
interval-aware correlation and communality overlays.

Pat: The 1D/2D/3D ordination split is important for teaching; users should not
need to guess why a rank-1 model cannot make a 2D biplot.

Fisher: Point estimates are preserved, but significance glyphs stay inactive
until interval provenance exists.

Noether: Rotation ambiguity remains explicitly attached to ordination metadata.

Emmy: Plot data are inspectable through `gllvmTMB_data`, including separate
score and loading tables for ordination.

Grace: No new package dependency was added. Targeted tests and pkgdown checks
passed.

Rose: The roadmap and design docs say what is implemented and what remains
pending, avoiding a polished-plot overclaim.

## GitHub Issue Ledger

- #230 commented:
  <https://github.com/itchyshin/gllvmTMB/issues/230#issuecomment-4508178451>.

## Known Limitations

- The loading-matrix panel in the paper should be a report-ready table, not a
  plot helper.
- Dominant-axis loading forests are not implemented yet.
- Score histograms/distributions are not implemented yet.
- Interval-aware tidy correlation and communality tables are still pending.
- True interactive 3D is still planned; current 3D is a static pair grid.
- No rendered article HTML was rebuilt for this slice because no article body
  changed.

## Next Safe Slice

Add a report-ready tidy correlation/communality table path, then use it to
support interval-aware ellipse borders/stars and communality whiskers. After
that, add dominant-axis loading forest and score-distribution helpers for the
behavioural/morphometrics article family.
