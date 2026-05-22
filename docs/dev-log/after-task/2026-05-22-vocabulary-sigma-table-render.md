# After-task report: Vocabulary Sigma table render cleanup

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Make the vocabulary article name `extract_Sigma_table()` as the reporting shape
for implied trait covariance and remove existing Pandoc `\rm` math warnings.

## Mathematical Contract

No model, estimator, formula, likelihood, extractor behavior, or figure changed.
The glossary still defines implied trait covariance as the rotation-invariant
target computed by `extract_Sigma()`; it now says `extract_Sigma_table()` reports
the same target as tidy rows.

## Scope

- Added `extract_Sigma_table(fit, level = ...)` to the implied trait covariance
  glossary entry.
- Replaced legacy TeX `\rm` atoms with `\mathrm{}` so the article renders
  without Pandoc math warnings.

## Files Touched

- `vignettes/articles/gllvm-vocabulary.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-vocabulary-sigma-table-render.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is glossary prose/math render
   cleanup only.
3. **Documentation:** the vocabulary article rendered locally without the
   previous `\rm` warnings.
4. **Runnable user-facing example:** no runnable chunk changed; rendered HTML
   was checked.
5. **Check-log:** recorded in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked reader wording; Grace checked render/pkgdown and
   package gates; Rose checked stale wording and TeX drift.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/gllvm-vocabulary.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/gllvm-vocabulary", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally without the earlier Pandoc `\rm` warnings.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'extract_Sigma_table\\(fit, level = \\.\\.\\.\\)|extract_Sigma\\(fit, level = \\.\\.\\.\\)|\\\\rm|Report-ready|tidy rows|mathrm\\{unit\\}|mathrm\\{phy\\}|mathrm\\{non\\}' vignettes/articles/gllvm-vocabulary.Rmd pkgdown-site/articles/gllvm-vocabulary.html`
  -> source and rendered HTML contain the row-table wording and `\mathrm{}`
  atoms; no `\rm` remains.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/gllvm-vocabulary.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/gllvm-vocabulary.Rmd`
- The exact presence/render scan was:
  `rg -n 'extract_Sigma_table\\(fit, level = \\.\\.\\.\\)|extract_Sigma\\(fit, level = \\.\\.\\.\\)|\\\\rm|Report-ready|tidy rows|mathrm\\{unit\\}|mathrm\\{phy\\}|mathrm\\{non\\}' vignettes/articles/gllvm-vocabulary.Rmd pkgdown-site/articles/gllvm-vocabulary.html`

## Tests Of The Tests

No new tests were added. This slice changes glossary prose and TeX only.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves consistency and removes render warnings but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-18 remains the relevant row for `extract_Sigma_table()`.
- No validation status moved.

## What Did Not Go Smoothly

The first render exposed existing `\rm` math warnings in this article. They were
fixed in the same slice and the article was re-rendered cleanly.

## Known Limitations And Next Actions

- The glossary still mentions `extract_Sigma()` because it is the matrix
  backend. That is intentional; the reporting path now points to table rows.
- The short package check still reports the existing install warning and notes.
