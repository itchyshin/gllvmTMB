# After-task report: Phylogenetic Sigma tables

**Date:** 2026-05-22  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Florence, Darwin, Pat, Grace, Rose  
**Spawned subagents:** none

## Task Goal

Replace raw phylogenetic and non-phylogenetic covariance matrix printing with
report-ready Sigma tables and a faceted correlation heatmap.

## Mathematical Contract

No likelihood, phylogenetic parameterization, formula grammar, extractor
internals, or plotted estimand changed. The article still explains the paired
phylogenetic decomposition into shared, unique, and total components. The
change is presentation: component entries are shown with
`extract_Sigma_table()`, and total phylogenetic versus non-phylogenetic
correlations are compared with `plot_Sigma_heatmap()`.

## Scope

- Replaced `Sigma_phy_*` matrix extraction/rounding with component table rows.
- Replaced `Sigma_non_*` matrix extraction/rounding with component table rows.
- Added a faceted total-correlation heatmap for `level = c("phy", "unit")`.
- Rewired the phylogenetic communality calculation to use the new
  `Sigma_phy_rows` table instead of removed matrix objects.
- Rephrased heritability prose that referred to removed matrix variable names.

## Files Touched

- `vignettes/articles/phylogenetic-gllvm.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-phylogenetic-sigma-tables.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is an article presentation
   cleanup over existing phylogenetic and Sigma-helper surfaces (`EXT-18`,
   `EXT-27`).
3. **Documentation:** the phylogenetic article source was updated and rendered
   locally. No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** the affected article rendered and produced
   the new heatmap.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Florence checked visual readability and uncertainty
   honesty, Darwin checked the biological interpretation, Pat checked the
   reader path, Grace checked local package/doc commands, and Rose checked
   consistency with the helper API.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/phylogenetic-gllvm.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/phylogenetic-gllvm", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally after the communality chunk was rewired to
  use `Sigma_phy_rows`.
- Visual QA image inspected:
  `pkgdown-site/articles/phylogenetic-gllvm_files/figure-html/extract-total-correlations-1.png`.
  The faceted heatmap has balanced phy/unit panels, readable labels, and the
  explicit caption that heatmaps do not display uncertainty intervals.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'Sigma_phy_shared|Sigma_phy_unique|Sigma_phy_total|Sigma_non_shared|Sigma_non_unique|Sigma_non_total|round\\(Sigma_phy|round\\(Sigma_non|extract_Sigma_table\\(|plot_Sigma_heatmap\\(|extract-total-correlations|phy_shared_diag' vignettes/articles/phylogenetic-gllvm.Rmd pkgdown-site/articles/phylogenetic-gllvm.html`
  -> removed matrix objects are gone; helper-backed source/rendered HTML and
  the table-backed communality ratio are present.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains" vignettes/articles/phylogenetic-gllvm.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- The old `Sigma_phy_*` and `Sigma_non_*` matrix objects and `round()` calls
  were removed.
- The communality and heritability prose no longer depends on removed matrix
  object names.
- The replacement path uses `extract_Sigma_table()` and `plot_Sigma_heatmap()`,
  consistent with the rest of the covariance article cleanup.

## Tests Of The Tests

No new test file was added. This is a rendered article change over already
tested extractor and plot helpers. Validation used article render, visual QA,
`pkgdown::check_pkgdown()`, stale-wording scans, `git diff --check`, and a
short no-tests package check.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves the phylogenetic reader path but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new capability was advertised. This slice uses existing rows for Sigma table
rows (`EXT-18`) and Sigma heatmaps (`EXT-27`).

## What Did Not Go Smoothly

The first render failed because the communality chunk still referred to the
removed `Sigma_phy_shared` matrix. Rewiring that calculation to
`Sigma_phy_rows` fixed the render.

## Known Limitations And Next Actions

- The heatmap is point-estimate only. The plot caption makes this explicit, and
  interval views remain a separate bootstrap or pairwise correlation workflow.
