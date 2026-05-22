# After-task report: Simulation-verification truth comparison

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Florence, Fisher, Grace, Rose, Emmy
**Spawned subagents:** none

## Task Goal

Replace the hand-built Sigma truth-vs-fit table in the simulation-verification
article with the report-ready comparison helper and a figure.

## Mathematical Contract

No likelihood, formula grammar, family, NAMESPACE, or generated Rd changed.
The article still compares the fitted between-site Sigma to the known DGP:

```r
Sigma_truth = Lambda_B Lambda_B^T + diag(psi_B)
error = estimate - truth
```

`plot_Sigma_comparison()` displays those errors; the plotted segments are not
confidence intervals.

## Scope

- Replaced manual `row()` / `col()` / `as.numeric(Sigma_fit - Sigma_truth)`
  table construction with `compare_Sigma_table()`.
- Added a Sigma recovery figure with `plot_Sigma_comparison()`.
- Updated helper title logic so plots that include diagonal rows say
  "Sigma error by entry" rather than "trait pair".
- Added a regression expectation for diagonal-row plot titles.

## Files Touched

- `R/plot-covariance-tables.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `vignettes/articles/simulation-verification.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-simulation-verification-truth-comparison.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice improves an article's
   recovery display and a plot title guard; it does not change simulation
   machinery.
3. **Documentation:** the simulation-verification article source was updated.
   No roxygen, Rd, or pkgdown navigation changed.
4. **Runnable user-facing example:** the rendered article runs the DGP, fit,
   comparison table, and comparison figure.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked the teaching path, Florence checked the
   rendered figure title and spacing, Fisher checked error-versus-interval
   wording, Grace checked local commands, Rose checked stale matrix-flattening
   scaffolding, and Emmy checked the helper title contract.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 127 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/simulation-verification", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA image inspected:
  `pkgdown-site/articles/simulation-verification_files/figure-html/recover-sigma-1.png`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'row\\(|col\\(|Sigma_fit|diff\\s*=|data.frame\\(|compare_Sigma_table\\(|plot_Sigma_comparison\\(|Sigma error by entry' vignettes/articles/simulation-verification.Rmd R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> the changed recovery section now uses comparison helpers; remaining
  `Sigma_fit` / `Sigma_truth` wording is the intentional trait-factor-order
  failure-mode explanation.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|estimate-vs-truth article figures remain future|plotting geometry remains" vignettes/articles/simulation-verification.Rmd`
  -> no hits.

## Tests Of The Tests

The new title expectation catches the diagonal-row wording failure that visual
QA found in the rendered article. The article render exercises the real DGP,
fit, comparison table, and comparison plot.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  advances the hidden/technical article cleanup but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Known Limitations And Next Actions

- Several hidden/technical articles still hand-index Sigma, R, or loading
  matrices.
- The next narrow cleanup target is likely `behavioural-syndromes.Rmd` or
  `functional-biogeography.Rmd`, where covariance/correlation comparisons are
  still assembled manually.
