# After-task report: Guide articles row extractors

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Remove two matrix-first teaching references from guide articles so readers copy
tidy extractors for Sigma and correlations.

## Mathematical Contract

No model, estimator, formula, likelihood, extractor behavior, or figure changed.
This slice only changes static guide text/code examples from raw matrix
extractors to row-first extractor calls.

## Scope

- In `choose-your-model`, changed the diagnostic checklist's implied covariance
  row from `extract_Sigma()` to `extract_Sigma_table()`.
- In `stacked-trait-gllvm`, changed the biological-summary examples from
  `extract_Sigma(... )$R` to `extract_correlations()`.

## Files Touched

- `vignettes/articles/choose-your-model.Rmd`
- `vignettes/articles/stacked-trait-gllvm.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-guide-articles-row-extractors.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is static article example
   wording only.
3. **Documentation:** both edited articles rendered locally.
4. **Runnable user-facing example:** the edited chunks are static/eval-false or
   prose-table examples; rendered HTML was checked.
5. **Check-log:** recorded in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked copyable reader path; Grace checked render and
   package gates; Rose checked stale wording.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/choose-your-model.Rmd vignettes/articles/stacked-trait-gllvm.Rmd`
  -> completed without output.
- `for article in articles/choose-your-model articles/stacked-trait-gllvm; do Rscript --vanilla -e "devtools::load_all(quiet = TRUE); pkgdown::build_article('$article', quiet = TRUE, new_process = FALSE)" || exit 1; done`
  -> both articles rendered locally.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'extract_Sigma_table\\(fit, level = "unit"\\)|extract_correlations\\(fit, tier = "unit"\\)|extract_correlations\\(fit, tier = "unit_obs"\\)|extract_Sigma\\(fit, level = "unit"\\)\\$R|extract_Sigma\\(fit, level = "unit"\\)' vignettes/articles/choose-your-model.Rmd vignettes/articles/stacked-trait-gllvm.Rmd pkgdown-site/articles/choose-your-model.html pkgdown-site/articles/stacked-trait-gllvm.html`
  -> new row extractor calls are present; the old `$R` examples are gone.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/choose-your-model.Rmd vignettes/articles/stacked-trait-gllvm.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/choose-your-model.Rmd vignettes/articles/stacked-trait-gllvm.Rmd`
- The exact presence scan was:
  `rg -n 'extract_Sigma_table\\(fit, level = "unit"\\)|extract_correlations\\(fit, tier = "unit"\\)|extract_correlations\\(fit, tier = "unit_obs"\\)|extract_Sigma\\(fit, level = "unit"\\)\\$R|extract_Sigma\\(fit, level = "unit"\\)' vignettes/articles/choose-your-model.Rmd vignettes/articles/stacked-trait-gllvm.Rmd pkgdown-site/articles/choose-your-model.html pkgdown-site/articles/stacked-trait-gllvm.html`

## Tests Of The Tests

No new tests were added. This slice changes static guide examples only; the
extractor behavior is already covered by extractor tests.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves consistency but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-04 remains the relevant row for `extract_correlations()`.
- EXT-18 remains the relevant row for `extract_Sigma_table()`.
- No validation status moved.

## What Did Not Go Smoothly

No blocker.

## Known Limitations And Next Actions

- The edited examples are static/eval-false guide snippets. The render confirms
  the examples are visible, not executed.
- The short package check still reports the existing install warning and notes.
