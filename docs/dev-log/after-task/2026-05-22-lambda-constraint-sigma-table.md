# After-task report: Lambda-constraint Sigma table wording

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Make the lambda-constraint article point readers at the report-ready Sigma table
helper when explaining that Sigma is rotation-invariant.

## Mathematical Contract

No model, estimator, likelihood, formula, extractor behavior, or figure changed.
The article still says the implied trait covariance is rotation-invariant; the
example call now uses `extract_Sigma_table(fit, level = "unit")` and includes
the `fit` argument.

## Scope

- Replaced `extract_Sigma(level = "unit")` in the decision table with
  `extract_Sigma_table(fit, level = "unit")`.

## Files Touched

- `vignettes/articles/lambda-constraint.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-lambda-constraint-sigma-table.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is article wording only.
3. **Documentation:** the article rendered locally.
4. **Runnable user-facing example:** the edited row is prose-table guidance,
   not a runnable chunk; rendered HTML was checked.
5. **Check-log:** recorded in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked copyability; Grace checked render/pkgdown and
   package gates; Rose checked stale wording.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/lambda-constraint.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'extract_Sigma_table\\(fit, level = "unit"\\)|extract_Sigma\\(level = "unit"\\)|extract_Sigma\\(fit, level = "unit"\\)' vignettes/articles/lambda-constraint.Rmd pkgdown-site/articles/lambda-constraint.html`
  -> new row-table helper call is present in source and rendered HTML; the old
  missing-`fit` snippet is gone.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/lambda-constraint.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/lambda-constraint.Rmd`
- The exact presence scan was:
  `rg -n 'extract_Sigma_table\\(fit, level = "unit"\\)|extract_Sigma\\(level = "unit"\\)|extract_Sigma\\(fit, level = "unit"\\)' vignettes/articles/lambda-constraint.Rmd pkgdown-site/articles/lambda-constraint.html`

## Tests Of The Tests

No new tests were added. This slice changes one prose-table helper call only.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves consistency but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-18 remains the relevant row for `extract_Sigma_table()`.
- No validation status moved.

## What Did Not Go Smoothly

No blocker.

## Known Limitations And Next Actions

- The article still focuses on loadings constraints; Sigma rows are mentioned
  only to keep users from constraining loadings unnecessarily.
- The short package check still reports the existing install warning and notes.
