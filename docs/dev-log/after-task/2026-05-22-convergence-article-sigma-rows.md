# After-task report: Convergence article Sigma rows

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Make the convergence/start-values article use row-first Sigma examples in its
diagnostic and bootstrap uncertainty sections.

## Mathematical Contract

No model, estimator, likelihood, formula, bootstrap behavior, or plotted output
changed. This slice only changes static article examples to use
`extract_Sigma_table()` for fitted and bootstrap Sigma summaries.

## Scope

- Updated the diagnostic alignment table so `Sigma` points to
  `extract_Sigma_table(fit, level = "unit", part = "total")`.
- Replaced direct `boot$ci_lower$Sigma_B` / `boot$ci_upper$Sigma_B` examples
  with `extract_Sigma_table(boot, level = "unit", entries = "upper")`.

## Files Touched

- `vignettes/articles/convergence-start-values.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-convergence-article-sigma-rows.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is static article example
   wording only.
3. **Documentation:** the article rendered locally.
4. **Runnable user-facing example:** the edited bootstrap chunk is `eval =
   FALSE`; rendered HTML was checked.
5. **Check-log:** recorded in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked reader actionability; Grace checked render and
   package gates; Rose checked stale wording.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/convergence-start-values.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/convergence-start-values", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'extract_Sigma_table\\(fit, level = "unit", part = "total"\\)|extract_Sigma_table\\(boot, level = "unit", entries = "upper"\\)|boot\\$ci_lower\\$Sigma_B|boot\\$ci_upper\\$Sigma_B|extract_Sigma\\(fit, level = "unit", part = "total"\\)\\$Sigma' vignettes/articles/convergence-start-values.Rmd pkgdown-site/articles/convergence-start-values.html`
  -> row-first fitted and bootstrap Sigma examples are present; old direct
  bootstrap matrix-bound examples are gone.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/convergence-start-values.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/articles/convergence-start-values.Rmd`
- The exact presence scan was:
  `rg -n 'extract_Sigma_table\\(fit, level = "unit", part = "total"\\)|extract_Sigma_table\\(boot, level = "unit", entries = "upper"\\)|boot\\$ci_lower\\$Sigma_B|boot\\$ci_upper\\$Sigma_B|extract_Sigma\\(fit, level = "unit", part = "total"\\)\\$Sigma' vignettes/articles/convergence-start-values.Rmd pkgdown-site/articles/convergence-start-values.html`

## Tests Of The Tests

No new tests were added. This slice changes static/eval-false article examples
only; the bootstrap table path is already covered by extractor and plot tests.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves consistency but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-18 remains the relevant row for `extract_Sigma_table()`.
- EXT-20 remains the relevant row for bootstrap Sigma table rows.
- No validation status moved.

## What Did Not Go Smoothly

No blocker.

## Known Limitations And Next Actions

- The bootstrap example is still `eval = FALSE` because `n_boot = 200` is too
  expensive for article rendering.
- The short package check still reports the existing install warning and notes.
