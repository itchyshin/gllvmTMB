# After-task report: Animal-model Sigma tables

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Florence, Darwin, Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Replace raw animal-model genetic covariance/correlation matrix printing with
the report-ready Sigma comparison, table, and heatmap helpers.

## Mathematical Contract

No likelihood, animal-model parameterization, formula grammar, extractor
internals, or plotted estimand changed. The article still targets the
rotation-invariant phylogenetic/animal-level total covariance surface. The
bivariate section now compares the fitted genetic covariance and correlation to
the known simulation truth through `compare_Sigma_table()`. The multivariate
section shows the fitted genetic covariance entries with `extract_Sigma_table()`
and the fitted genetic correlation matrix with `plot_Sigma_heatmap()`.

## Scope

- Added `dimnames(G_true)` so truth comparison rows align with trait names.
- Replaced `phy$Sigma` / `phy$R` list output in the bivariate tutorial with
  table-backed fitted-vs-truth covariance and correlation rows.
- Replaced `phy3$Sigma` / `phy3$R` list output in the multivariate tutorial
  with report-ready covariance rows and a genetic-correlation heatmap.
- Left the raw `Lambda_hat` display in place because the adjacent prose explains
  the rotation ambiguity.

## Files Touched

- `vignettes/articles/animal-model.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-animal-model-sigma-tables.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is an article presentation
   cleanup over existing animal-model and Sigma-helper surfaces (`EXT-18`,
   `EXT-25`, `EXT-27`).
3. **Documentation:** the animal-model article source was updated and rendered
   locally. No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** the affected article rendered and produced
   the new heatmap.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Florence checked visual readability and uncertainty
   honesty, Darwin checked that the genetic-correlation interpretation stayed
   biologically meaningful, Pat checked the reader path, Grace checked local
   package/doc commands, and Rose checked consistency with the helper API.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/animal-model.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/animal-model", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA image inspected:
  `pkgdown-site/articles/animal-model_files/figure-html/G3-correlation-1.png`.
  The heatmap is legible, uses equal cell sizes, and carries the caption
  "Heatmaps do not display uncertainty intervals."
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'phy <-|phy3 <-|phy\\$Sigma|phy\\$R|phy3\\$Sigma|phy3\\$R|round\\(phy|round\\(phy3|compare_Sigma_table\\(|plot_Sigma_heatmap\\(|G3-correlation|dimnames\\(G_true\\)' vignettes/articles/animal-model.Rmd pkgdown-site/articles/animal-model.html`
  -> old raw Sigma/R objects are gone; helper-backed source and rendered HTML
  are present.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains" vignettes/articles/animal-model.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- The old `phy$Sigma`, `phy$R`, `phy3$Sigma`, and `phy3$R` article calls were
  removed.
- The replacement path uses `compare_Sigma_table()`, `extract_Sigma_table()`,
  and `plot_Sigma_heatmap()`, consistent with the rest of the covariance
  article cleanup.

## Tests Of The Tests

No new test file was added. This is a rendered article change over already
tested extractor and plot helpers. Validation used article render, visual QA,
`pkgdown::check_pkgdown()`, stale-wording scans, `git diff --check`, and a
short no-tests package check.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves the animal-model reader path but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new capability was advertised. This slice uses existing rows for Sigma table
rows (`EXT-18`), Sigma truth comparison (`EXT-25`), and Sigma heatmaps
(`EXT-27`).

## What Did Not Go Smoothly

No blocker.

## Known Limitations And Next Actions

- The multivariate heatmap is point-estimate only. The plot caption makes this
  explicit, and interval views remain a separate bootstrap or pairwise
  correlation workflow.
