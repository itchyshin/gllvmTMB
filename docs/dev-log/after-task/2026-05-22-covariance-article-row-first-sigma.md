# After-task report: Covariance article row-first Sigma section

**Date:** 2026-05-22  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Pat, Florence, Grace, Rose  
**Spawned subagents:** none

## Task Goal

Make the canonical covariance/correlation article teach the report-ready
`extract_Sigma_table()` workflow before showing raw matrices from
`extract_Sigma()`.

## Mathematical Contract

No model, estimator, formula, likelihood, extractor behavior, or plot geometry
changed. The article still describes the same decomposition,
`Sigma = Lambda Lambda^T + Psi`; it now presents the tidy row helper as the
default reporting surface and keeps `extract_Sigma()` as the matrix backend for
algebra checks.

## Scope

- Updated the symbolic alignment table to point reporting readers at
  `extract_Sigma_table()` for shared, unique, and total Sigma parts.
- Renamed the matrix-first section to `Report-ready Sigma rows`.
- Moved the total Sigma row table before raw matrix output.
- Added a small decomposition-row example for shared, unique, and total
  diagonal entries.
- Kept the raw `extract_Sigma()` examples under a matrix-backend paragraph.

## Files Touched

- `vignettes/articles/covariance-correlation.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-covariance-article-row-first-sigma.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is article wording and example
   ordering only.
3. **Documentation:** the affected article was updated and rendered locally. No
   roxygen, Rd, NEWS, pkgdown navigation, or design docs changed.
4. **Runnable user-facing example:** the changed article chunks rendered
   locally.
5. **Check-log:** recorded in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked copy-the-workflow order; Florence checked the
   existing Sigma table plot; Grace checked render/pkgdown/package gates; Rose
   checked stale wording.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/covariance-correlation.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA image inspected:
  `pkgdown-site/articles/covariance-correlation_files/figure-html/sigma-table-plot-1.png`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'Report-ready Sigma rows|sigma_part_rows_B|sigma-matrix-backend|extract_Sigma_table\\(fit, level = "unit", part = "shared"\\)|extract_Sigma_table\\(fit_B|extract_Sigma\\(fit_B, level = "unit", part = "shared"\\)\\$Sigma' vignettes/articles/covariance-correlation.Rmd pkgdown-site/articles/covariance-correlation.html`
  -> row-first heading, decomposition-row chunk, matrix-backend chunk, and
  rendered HTML are present.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains|What `extract_Sigma\\(\\)` gives you' vignettes/articles/covariance-correlation.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains|What `extract_Sigma\\(\\)` gives you' vignettes/articles/covariance-correlation.Rmd`
- The exact presence scan was:
  `rg -n 'Report-ready Sigma rows|sigma_part_rows_B|sigma-matrix-backend|extract_Sigma_table\\(fit, level = "unit", part = "shared"\\)|extract_Sigma_table\\(fit_B|extract_Sigma\\(fit_B, level = "unit", part = "shared"\\)\\$Sigma' vignettes/articles/covariance-correlation.Rmd pkgdown-site/articles/covariance-correlation.html`

## Tests Of The Tests

No new tests were added. This slice changes article ordering and examples only;
the table helper itself is covered by `test-extract-sigma-table.R` and the plot
helper by `test-plot-covariance-tables.R`.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves the canonical teaching path but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-18 remains the relevant row for `extract_Sigma_table()`.
- EXT-19 remains the relevant row for `plot_Sigma_table()`.
- No validation status moved.

## What Did Not Go Smoothly

No blocker.

## Known Limitations And Next Actions

- The article still includes raw matrix output for algebra checks. That is
  intentional, but the copy-first reporting path is now row-first.
- The short package check still reports the existing install warning and notes.
