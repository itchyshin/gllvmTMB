# After-task report: Covariance/correlation truth-comparison figure

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Pat, Florence, Fisher, Grace, Rose, Emmy  
**Spawned subagents:** none

## Task Goal

Replace the hand-built three-panel correlation heatmap in the
Covariance/correlation article with a package-helper comparison figure that
shows model error against the known truth.

## Mathematical Contract

No likelihood, formula grammar, family, NAMESPACE, or generated Rd changed.
The article now plots `estimate - truth` for the upper-triangle correlation
rows from two model specifications:

```r
compare_Sigma_table(fit_A, truth = Sigma_true, measure = "correlation")
compare_Sigma_table(fit_B, truth = Sigma_true, measure = "correlation")
plot_Sigma_comparison(..., facet = "comparison")
```

The plotted segments are comparison residuals, not confidence intervals.

## Scope

- Replaced article-local `make_long()` / `geom_tile()` / `geom_text()`
  heatmap scaffolding with `compare_Sigma_table()` and
  `plot_Sigma_comparison(facet = "comparison")`.
- Kept the article's core interpretation: latent-only correlations are
  inflated because the diagonal omits `Psi`; `latent + unique` brings errors
  closer to zero.
- Fixed the helper's `sort = "trait"` ordering so comparison facets receive
  contiguous y positions instead of interleaved row labels.
- Added a regression expectation for the facet ordering.

## Files Touched

- `R/plot-covariance-tables.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `vignettes/articles/covariance-correlation.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-covariance-correlation-truth-comparison.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is an article integration plus
   a plot-helper row-ordering fix.
3. **Documentation:** the Covariance/correlation article source was updated.
   No roxygen, Rd, or pkgdown navigation changed.
4. **Runnable user-facing example:** the rendered article uses the prepared
   covariance edge-case object and the fitted models already built in the
   article.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked the reader path, Florence checked the rendered
   figure, Fisher checked error-versus-uncertainty wording, Grace checked local
   commands, Rose checked stale heatmap scaffolding, and Emmy checked the
   helper data-ordering fix.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 126 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA image inspected:
  `pkgdown-site/articles/covariance-correlation_files/figure-html/corr-comparison-1.png`.
- `Rscript --vanilla -e 'devtools::test(filter = "example-covariance-edge-cases")'`
  -> 31 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'make_long|df_corr|geom_tile\\(|geom_text\\(|scale_fill_gradient2\\(|facet_wrap\\(~ panel\\)|compare_Sigma_table\\(|plot_Sigma_comparison\\(|facet = "comparison"' vignettes/articles/covariance-correlation.Rmd R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> old article-local heatmap scaffolding is gone from the touched article;
  the helper and comparison-facet path are present in article and tests.

## Tests Of The Tests

The added regression assertion checks that `sort = "trait"` keeps comparison
facets in contiguous y ranges. This catches the visual bug where row labels
from the two model panels interleaved and duplicated across facet scales.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  advances the public Covariance/correlation article but does not close the
  issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Known Limitations And Next Actions

- The visible Covariance/correlation and Morphometrics articles now use the
  truth-comparison helpers, but hidden/technical articles still contain
  hand-indexed Sigma/R comparisons.
- The next narrow article slice should target `simulation-verification.Rmd` or
  one hidden article where a truth-vs-fit table is still hand-built.
