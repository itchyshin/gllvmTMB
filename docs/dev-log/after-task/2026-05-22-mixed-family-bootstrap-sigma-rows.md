# After-task report: Mixed-family bootstrap Sigma rows

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Make the mixed-family extractor article show bootstrap Sigma intervals as tidy
rows rather than three raw matrices.

## Mathematical Contract

No model, family, likelihood, bootstrap behavior, extractor behavior, or plot
changed. The article still computes the same `bootstrap_Sigma()` object; the
display now calls `extract_Sigma_table()` on that object.

## Scope

- Replaced `boot$point_est$Sigma_unit`, `boot$ci_lower$Sigma_unit`, and
  `boot$ci_upper$Sigma_unit` prints with
  `extract_Sigma_table(boot, level = "unit", entries = "upper")`.

## Files Touched

- `vignettes/articles/mixed-family-extractors.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-mixed-family-bootstrap-sigma-rows.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is article display cleanup
   over an already computed bootstrap object.
3. **Documentation:** the mixed-family extractor article rendered locally.
4. **Runnable user-facing example:** the live bootstrap article chunk rendered.
5. **Check-log:** recorded in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked report readability; Grace checked render and
   package gates; Rose checked stale wording.

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
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'extract_Sigma_table\\(boot, level = "unit", entries = "upper"\\)|boot\\$point_est\\$Sigma_unit|boot\\$ci_lower\\$Sigma_unit|boot\\$ci_upper\\$Sigma_unit' vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/mixed-family-extractors.html`
  -> row-first bootstrap Sigma display is present; old raw matrix prints are
  gone from source.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/mixed-family-extractors.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/mixed-family-extractors.Rmd`
- The exact presence scan was:
  `rg -n 'extract_Sigma_table\\(boot, level = "unit", entries = "upper"\\)|boot\\$point_est\\$Sigma_unit|boot\\$ci_lower\\$Sigma_unit|boot\\$ci_upper\\$Sigma_unit' vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/mixed-family-extractors.html`

## Tests Of The Tests

No new tests were added. This slice changes an article display call only; the
bootstrap Sigma table path is already covered by `test-extract-sigma-table.R`
and `test-plot-covariance-tables.R`.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves consistency but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-20 remains the relevant row for bootstrap Sigma table rows.
- MIX-04 remains the relevant row for mixed-family extractor behavior.
- No validation status moved.

## What Did Not Go Smoothly

No blocker.

## Known Limitations And Next Actions

- The article still uses a small bootstrap run for rendering; it is example
  output, not interval-calibration evidence.
- The short package check still reports the existing install warning and notes.
