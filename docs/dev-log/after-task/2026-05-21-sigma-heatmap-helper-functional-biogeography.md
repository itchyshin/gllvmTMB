# After-task report: Sigma heatmap helper and functional biogeography

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Florence, Fisher, Grace, Rose, Emmy
**Spawned subagents:** none

## Task Goal

Add a report-ready Sigma heatmap helper and use it to replace the
functional-biogeography article's hand-built cross-trait correlation heatmaps.

## Mathematical Contract

No likelihood, formula grammar, family, or TMB parameterisation changed. The
new helper displays point-estimate rows from `extract_Sigma_table()`:

```r
R = cor(Sigma)
cell = extract_Sigma_table(..., measure = "correlation", entries = "all")$estimate
```

Heatmap fill is clamped to `[-1, 1]` on the correlation display scale to avoid
floating-point diagonal values such as `1 + 1e-12` becoming out-of-bounds fill
values. The original estimate is preserved in the attached `gllvmTMB_data`.

## Scope

- Added exported `plot_Sigma_heatmap()`.
- Added tests for heatmap geoms, facet-order preservation, correlation fill
  clamping, diagonal omission, label omission, and input validation.
- Added roxygen documentation, regenerated `NAMESPACE`, and generated
  `man/plot_Sigma_heatmap.Rd`.
- Added `plot_Sigma_heatmap()` to `_pkgdown.yml`, `NEWS.md`,
  `docs/design/06-extractors-contract.md`, and validation-debt row `EXT-27`.
- Replaced article-local `heatmap_df()` / `geom_tile()` /
  `scale_fill_gradient2()` scaffolding in
  `vignettes/articles/functional-biogeography.Rmd`.
- Updated the same article's long-format `gllvmTMB()` calls to use
  `trait = "trait"` explicitly.

## Files Touched

- `R/plot-covariance-tables.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `NAMESPACE`
- `man/plot_Sigma_heatmap.Rd`
- `_pkgdown.yml`
- `NEWS.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `vignettes/articles/functional-biogeography.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-sigma-heatmap-helper-functional-biogeography.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is a display helper and article
   integration; it does not add an estimator, likelihood, family, or simulation
   layer.
3. **Documentation:** roxygen, generated Rd, `_pkgdown.yml`, NEWS, extractor
   contract, validation-debt register, and the functional-biogeography article
   were updated.
4. **Runnable user-facing example:** the rendered article runs the fits,
   creates correlation rows with `extract_Sigma_table()`, and draws the
   helper-backed heatmaps.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked the helper API and metadata contract, Florence
   checked the rendered heatmaps for facet order, fill handling, label
   readability, and interval honesty, Fisher checked the no-interval caption,
   Pat checked the article path, Grace checked local commands, and Rose checked
   stale manual heatmap code plus long-format `trait = "trait"` consistency.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R vignettes/articles/functional-biogeography.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `NAMESPACE` and `plot_Sigma_heatmap.Rd`.
- `tail -5 man/plot_Sigma_heatmap.Rd`
  -> final lines were the expected `\seealso{}` block.
- `grep -c '^\\keyword' man/plot_Sigma_heatmap.Rd`
  -> `0`.
- `Rscript --vanilla -e 'tools::Rd2txt("man/plot_Sigma_heatmap.Rd", out = tempfile())'`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 153 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/functional-biogeography", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA images inspected:
  `pkgdown-site/articles/functional-biogeography_files/figure-html/heatmap-rb-1.png`
  and
  `pkgdown-site/articles/functional-biogeography_files/figure-html/heatmap-rw-1.png`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'heatmap_df|geom_tile\\(|geom_text\\(|scale_fill_gradient2\\(|facet_wrap\\(~ model\\)|Sigma_B_adj|Sigma_W_adj|cov2cor\\(' vignettes/articles/functional-biogeography.Rmd`
  -> no hits.
- `rg -n 'plot_Sigma_heatmap\\(|EXT-27|sigma_heatmap|not_displayed|entries = "all"' R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R vignettes/articles/functional-biogeography.Rmd NAMESPACE NEWS.md _pkgdown.yml docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md man/plot_Sigma_heatmap.Rd`
  -> helper export, tests, article integration, docs, pkgdown, and register row
  are present.
- `rg -n "gllvmTMB\\(" vignettes/articles/functional-biogeography.Rmd`
  -> all runnable/static long-format calls now include `trait = "trait"`; the
  wide `traits(...)` inline example intentionally does not take `trait =`.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|estimate-vs-truth article figures remain future|plotting geometry remains" R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R vignettes/articles/functional-biogeography.Rmd NEWS.md docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md man/plot_Sigma_heatmap.Rd _pkgdown.yml`
  -> hits only in existing NEWS / validation-register compatibility rows, not
  in the new helper or touched article code.
- `rg -n "in prep|in preparation|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/functional-biogeography.Rmd R/plot-covariance-tables.R man/plot_Sigma_heatmap.Rd NEWS.md docs/design/06-extractors-contract.md`
  -> no hits.

## Tests Of The Tests

The heatmap tests include a boundary case where a displayed correlation is
`1 + 1e-12`, which catches the visual-QA failure where diagonal cells could be
drawn with missing-value fill. The facet-order assertion catches the article
story-order failure where alphabetical facets put the adjusted model before the
core model. The label/diagonal tests cover display options, and the validation
test covers malformed input.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  adds a new helper and advances hidden/technical article cleanup but does not
  close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

Added `EXT-27` to `docs/design/35-validation-debt-register.md` with covered
test evidence in `test-plot-covariance-tables.R`.

## What Did Not Go Smoothly

The first rendered heatmaps exposed two issues that were not obvious from the
object-shape tests alone: facet labels were alphabetically ordered rather than
article-order-preserving, and diagonal correlations slightly above 1 were
treated as out-of-bounds fill. Both are now tested.

## Known Limitations And Next Actions

- `plot_Sigma_heatmap()` is a point-estimate display. It keeps interval columns
  in `gllvmTMB_data` but does not display uncertainty.
- Multi-model heatmap layout beyond `facet = "level"` remains a future helper
  surface.
- The next cleanup slice should rescan other technical articles for manual
  covariance/correlation displays and long-format calls without explicit
  `trait = "trait"`.
