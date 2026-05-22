# After-task report: Morphometrics truth-comparison helper integration

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Florence, Fisher, Grace, Rose
**Spawned subagents:** none

## Task Goal

Replace the hand-built true-vs-fitted correlation heatmap in the canonical
Morphometrics article with the new row-first comparison helpers.

## Mathematical Contract

No likelihood, formula grammar, family, NAMESPACE, or generated Rd changed.
The article now compares fitted and known-truth between-unit correlations with:

```r
compare_Sigma_table(fit, truth = Sigma_true, measure = "correlation")
plot_Sigma_comparison(...)
```

The plotted residual is `estimate - truth`; it is not an uncertainty interval.

## Scope

- Replaced the article-local `make_corr_long()` / `ggplot2::geom_tile()`
  correlation heatmap scaffold with `compare_Sigma_table()` and
  `plot_Sigma_comparison()`.
- Kept the known-truth recovery point but changed the figure from two matrix
  panels to one row-labelled error plot.
- Rendered the Morphometrics article and visually checked the new figure.

## Files Touched

- `vignettes/articles/morphometrics.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-morphometrics-truth-comparison-helper.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is an article integration of
   existing comparison helpers.
3. **Documentation:** the Morphometrics article source was updated. No
   roxygen, Rd, or pkgdown navigation changed.
4. **Runnable user-facing example:** the rendered article uses the prepared
   morphometrics object and the fitted model already built in the article.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked that the article uses package helpers instead
   of article-local matrix plumbing; Florence checked row spacing and visual
   honesty; Fisher checked that the plotted segments are labelled as
   comparison errors, not intervals; Grace checked local package commands; Rose
   checked stale wording and removed hand-built heatmap scaffolding. Boole,
   Gauss, Noether, Curie, Darwin, Jason, Emmy, and Shannon were not active.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics", quiet = TRUE, new_process = FALSE)'`
  -> wrote `pkgdown-site/articles/morphometrics.html`.
- Visual QA image inspected:
  `pkgdown-site/articles/morphometrics_files/figure-html/corr-comparison-1.png`.
- `Rscript --vanilla -e 'devtools::test(filter = "example-morphometrics")'`
  -> 49 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'corr-heatmap|make_corr_long|df_corr|geom_tile\\(|geom_text\\(|scale_fill_gradient2\\(|compare_Sigma_table\\(|plot_Sigma_comparison\\(' vignettes/articles/morphometrics.Rmd`
  -> only `compare_Sigma_table()` and `plot_Sigma_comparison()` remain in the
  changed section; the article-local heatmap scaffolding is gone.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains|estimate-vs-truth article figures remain future" vignettes/articles/morphometrics.Rmd`
  -> no hits.

## Tests Of The Tests

The article render exercises the real article chunk after loading the local
package namespace, so it catches missing helper exports and malformed plotting
calls. The focused `example-morphometrics` test still checks the prepared
fixture, long/wide agreement, truth recovery, and bootstrap plot fixture.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  advances its public exemplar path but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Known Limitations And Next Actions

- The Morphometrics article now uses the comparison helper for its main
  truth-recovery figure, but the hidden/technical articles still contain
  matrix-indexed truth comparisons.
- The next narrow article slice should target `covariance-correlation.Rmd`
  or `simulation-verification.Rmd`, where known-truth Sigma/R comparisons are
  still built by hand.
