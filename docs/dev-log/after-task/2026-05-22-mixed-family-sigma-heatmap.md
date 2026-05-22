# After-task report: Mixed-family Sigma heatmap

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Florence, Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Replace raw mixed-family covariance/correlation matrix printing with the
report-ready Sigma table and heatmap helpers.

## Mathematical Contract

No model, likelihood, family handling, extractor internals, or plotted estimand
changed. The article still reports the `level = "unit"`, `part = "total"`
mixed-family Sigma surface with `link_residual = "auto"`. The change is only
presentation: covariance entries now use `extract_Sigma_table()`, and the
correlation matrix is drawn with `plot_Sigma_heatmap()`.

## Scope

- Replaced `Sigma$Sigma` printing in
  `vignettes/articles/mixed-family-extractors.Rmd` with tidy unique Sigma rows.
- Replaced `round(Sigma$R, 3)` with a rendered correlation heatmap.
- Preserved the article's explanation that non-Gaussian link residuals are
  included in the mixed-family denominator.

## Files Touched

- `vignettes/articles/mixed-family-extractors.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-mixed-family-sigma-heatmap.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is an article presentation
   cleanup over an existing covered extractor surface (`MIX-03`, `EXT-18`,
   `EXT-27`).
3. **Documentation:** the mixed-family article source was updated and rendered
   locally. No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** the affected article rendered and produced
   the new heatmap.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Florence checked visual readability and uncertainty
   honesty, Pat checked the reader path, Grace checked local package/doc
   commands, and Rose checked consistency with the helper API.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/mixed-family-extractors.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/mixed-family-extractors", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA image inspected:
  `pkgdown-site/articles/mixed-family-extractors_files/figure-html/corr-1.png`.
  The heatmap is legible, symmetric, and carries the caption "Heatmaps do not
  display uncertainty intervals."
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'Sigma\\$Sigma|round\\(Sigma\\$R|extract_Sigma_table\\(|plot_Sigma_heatmap\\(|fig.width = 5.8|trait\\s*=\\s*"trait"' vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/mixed-family-extractors.html`
  -> old printed matrix calls are gone; helper-backed source and rendered HTML
  are present.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains" vignettes/articles/mixed-family-extractors.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 4 notes. Notes were an inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The old `Sigma$Sigma` and `round(Sigma$R, 3)` article calls were removed.
- The replacement path uses `extract_Sigma_table()` and `plot_Sigma_heatmap()`,
  consistent with the rest of the covariance article cleanup.

## Tests Of The Tests

No new test file was added. This is a rendered article change over already
tested plot helpers. Validation used article render, visual QA,
`pkgdown::check_pkgdown()`, stale-wording scans, `git diff --check`, and a
short no-tests package check.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves the mixed-family reader path but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new capability was advertised. This slice uses existing covered/partial
rows: mixed-family Sigma extraction (`MIX-03`), Sigma table rows (`EXT-18`),
and Sigma heatmaps (`EXT-27`).

## What Did Not Go Smoothly

No blocker. The short package check produced one additional environment note:
`unable to verify current time`.

## Known Limitations And Next Actions

- The heatmap is point-estimate only. The caption makes this explicit, and
  uncertainty remains covered by the adjacent `extract_correlations()` section.
