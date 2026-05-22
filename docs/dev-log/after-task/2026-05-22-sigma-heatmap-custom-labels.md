# After-task report: Sigma heatmap custom labels

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Florence, Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Let article authors give Sigma heatmaps biologically specific titles,
subtitles, and captions without hand-editing ggplot labels after the helper
returns.

## Mathematical Contract

No estimator, likelihood, covariance decomposition, interval calculation, or
heatmap geometry changed. `plot_Sigma_heatmap()` still displays point estimates
from `extract_Sigma_table()` and still states that heatmaps do not display
uncertainty intervals. This slice only adds optional plot labels.

## Scope

- Added optional `title`, `subtitle`, and `caption` arguments to
  `plot_Sigma_heatmap()`.
- Validated those labels as `NULL` or scalar non-missing character strings.
- Regenerated `man/plot_Sigma_heatmap.Rd`.
- Used the labels in four public articles so the heatmaps name their
  interpretation target:
  - mixed-family trait correlations;
  - exploratory item correlations;
  - genetic trait correlations;
  - phylogenetic and non-phylogenetic correlations.

## Files Touched

- `R/plot-covariance-tables.R`
- `man/plot_Sigma_heatmap.Rd`
- `tests/testthat/test-plot-covariance-tables.R`
- `vignettes/articles/mixed-family-extractors.Rmd`
- `vignettes/articles/psychometrics-irt.Rmd`
- `vignettes/articles/animal-model.Rmd`
- `vignettes/articles/phylogenetic-gllvm.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-sigma-heatmap-custom-labels.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is a plotting-label API change,
   not a new likelihood, family, keyword, estimator, or parser path.
3. **Documentation:** roxygen and `man/plot_Sigma_heatmap.Rd` were updated;
   four affected articles rendered locally.
4. **Runnable user-facing example:** the four article heatmap examples rendered
   locally and were visually inspected.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Florence checked figure clarity; Pat checked reader-facing
   specificity; Grace checked package/render gates; Rose checked stale wording
   and report completeness.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/plot_Sigma_heatmap.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 157 passes, 0 failures, 0 warnings, 0 skips.
- `for article in articles/mixed-family-extractors articles/psychometrics-irt articles/animal-model articles/phylogenetic-gllvm; do Rscript --vanilla -e "devtools::load_all(quiet = TRUE); pkgdown::build_article('$article', quiet = TRUE, new_process = FALSE)" || exit 1; done`
  -> all four articles rendered locally.
- Visual QA images inspected:
  - `pkgdown-site/articles/mixed-family-extractors_files/figure-html/corr-1.png`
  - `pkgdown-site/articles/psychometrics-irt_files/figure-html/sigma-exp-corr-1.png`
  - `pkgdown-site/articles/animal-model_files/figure-html/G3-correlation-1.png`
  - `pkgdown-site/articles/phylogenetic-gllvm_files/figure-html/extract-total-correlations-1.png`
- Florence verdict:
  `PASS`. The custom titles improve the scientific message without changing
  uncertainty semantics; subtitles fit the rendered article figures; captions
  still warn that heatmaps do not display intervals.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `tail -5 man/plot_Sigma_heatmap.Rd && grep -c '^\\keyword' man/plot_Sigma_heatmap.Rd`
  -> the tail ends cleanly at `\seealso{...}` and the keyword count is `0`.
- `rg -n 'title = "Mixed-family trait correlations"|title = "Exploratory item correlations"|title = "Genetic trait correlations"|title = "Phylogenetic and non-phylogenetic correlations"|title = NULL|subtitle = NULL|caption = NULL|title,subtitle,caption' R/plot-covariance-tables.R man/plot_Sigma_heatmap.Rd tests/testthat/test-plot-covariance-tables.R vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd pkgdown-site/articles/mixed-family-extractors.html pkgdown-site/articles/psychometrics-irt.html pkgdown-site/articles/animal-model.html pkgdown-site/articles/phylogenetic-gllvm.html`
  -> helper signature, Rd usage, roxygen parameter, tests, and four article
  calls are present.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd`
- The exact API-presence scan was:
  `rg -n 'title = "Mixed-family trait correlations"|title = "Exploratory item correlations"|title = "Genetic trait correlations"|title = "Phylogenetic and non-phylogenetic correlations"|title = NULL|subtitle = NULL|caption = NULL|title,subtitle,caption' R/plot-covariance-tables.R man/plot_Sigma_heatmap.Rd tests/testthat/test-plot-covariance-tables.R vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd pkgdown-site/articles/mixed-family-extractors.html pkgdown-site/articles/psychometrics-irt.html pkgdown-site/articles/animal-model.html pkgdown-site/articles/phylogenetic-gllvm.html`

## Tests Of The Tests

The new test covers both acceptance and rejection:

- Acceptance: a heatmap with custom `title`, `subtitle`, and `caption` returns
  a ggplot whose labels match the supplied values.
- Boundary case: `title = NA_character_` is rejected with a `title` error.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves article figure specificity but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-18 and EXT-27 remain the relevant Sigma-table / Sigma-heatmap rows. This
  slice improves presentation labels only; it does not advertise a new modeling
  capability or move validation status.

## What Did Not Go Smoothly

No blocker. The Rd keyword spot check returned grep exit status 1 because the
keyword count was correctly `0`; the output itself was inspected and recorded.

## Known Limitations And Next Actions

- `plot_Sigma_heatmap()` still does not show uncertainty intervals by design.
  Interval-aware views remain the job of tidy Sigma/correlation table plots.
- The short package check still reports the existing install warning and notes.
  This slice did not attempt to fix those repository-wide checks.
