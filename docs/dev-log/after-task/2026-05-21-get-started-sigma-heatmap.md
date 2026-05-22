# After-task report: Get Started Sigma heatmap

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Pat, Florence, Fisher, Grace, Rose  
**Spawned subagents:** none

## Task Goal

Replace the Get Started vignette's raw correlation-matrix print with the
report-ready Sigma heatmap helper.

## Mathematical Contract

No likelihood, formula grammar, family, export, or extractor contract changed.
The vignette still displays the fitted unit-level trait correlation matrix:

```r
extract_Sigma_table(fit, level = "unit", measure = "correlation", entries = "all")
```

`plot_Sigma_heatmap()` displays those point estimates. It does not display
uncertainty intervals; the preceding `plot_correlations()` figure remains the
interval-bearing pairwise view.

## Scope

- Replaced `round(cov2cor(extract_Sigma(...)))` in `vignettes/gllvmTMB.Rmd`.
- Added a matrix heatmap chunk using `extract_Sigma_table()` and
  `plot_Sigma_heatmap()`.
- Left the existing pairwise forest plot as the uncertainty display.

## Files Touched

- `vignettes/gllvmTMB.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-get-started-sigma-heatmap.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is a vignette display cleanup.
3. **Documentation:** Get Started was updated and rendered locally. No roxygen,
   Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** the rendered Get Started article runs the
   fitted model, table extraction, and heatmap.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked the teaching sequence, Florence checked the
   rendered heatmap, Fisher checked that interval interpretation still points
   to pairwise rows, Grace checked local commands, and Rose checked stale
   matrix-print scaffolding.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/gllvmTMB.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("gllvmTMB", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA image inspected:
  `pkgdown-site/articles/cor-matrix-1.png`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'cov2cor\\(|round\\(cov2cor|extract_Sigma\\(fit, level = "unit"\\)\\$Sigma|plot_Sigma_heatmap\\(|sigma_corr_rows|cor-matrix' vignettes/gllvmTMB.Rmd pkgdown-site/articles/gllvmTMB.html`
  -> the old `cov2cor(extract_Sigma(...))` print is gone; helper-backed source
  and rendered HTML are present.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|estimate-vs-truth article figures remain future|plotting geometry remains" vignettes/gllvmTMB.Rmd`
  -> no hits.

## Tests Of The Tests

No new test file was added. The slice relies on the already-tested EXT-27
helper plus a local article render and visual QA of the generated heatmap.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves Get Started but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new capability was advertised. This slice reuses the existing EXT-27 helper.

## What Did Not Go Smoothly

`pkgdown::build_article("gllvmTMB")` wrote generated PNGs into `vignettes/` as
well as `pkgdown-site/articles/`; those untracked generated files were removed
before staging.

## Known Limitations And Next Actions

- The Get Started heatmap is point-estimate only; the pairwise correlation plot
  remains the interval-bearing display.
- Continue scanning remaining public and technical articles for manual
  covariance/correlation plots.
