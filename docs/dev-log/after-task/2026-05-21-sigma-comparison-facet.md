# After-task report: Sigma comparison facets

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Emmy, Florence, Fisher, Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Extend `plot_Sigma_comparison()` so one plot can compare several model
specifications against the same truth matrix using row-first comparison panels.

## Mathematical Contract

No likelihood, formula grammar, family, or TMB parameterisation changed. The
helper still plots `error = estimate - truth`; the new `facet = "comparison"`
mode only groups precomputed rows by a user-supplied `comparison` column.

## Scope

- Added `facet = "comparison"` to `plot_Sigma_comparison()`.
- Required a `comparison` column when that facet mode is requested.
- Reused the existing row-labelled difference plot and scatter plot styles.
- Added focused tests for the new facet path.
- Updated NEWS, validation row EXT-26, roxygen/Rd, and the report-ready plot
  contract.

## Files Touched

- `R/plot-covariance-tables.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `man/plot_Sigma_comparison.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-sigma-comparison-facet.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is plot-helper grouping only.
3. **Documentation:** roxygen/Rd, NEWS, validation-debt register, and design
   contract were updated.
4. **Runnable user-facing example:** unchanged; the helper's documented example
   remains a single comparison. Multi-comparison use is covered by tests and
   will be exercised in the next article slice.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked data contract and metadata, Florence checked
   the panel route for article figures, Fisher checked that the grouping adds
   no new calibration claim, Pat checked the intended article workflow, Grace
   checked local package commands, and Rose checked cross-file wording.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `man/plot_Sigma_comparison.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 125 passes, 0 failures, 0 warnings, 0 skips.
- `tail -5 man/plot_Sigma_comparison.Rd; grep -c '^\\keyword' man/plot_Sigma_comparison.Rd`
  -> Rd tail was well formed and keyword count was `0`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'facet = "comparison"|comparison column|model/specification|plot_Sigma_comparison|EXT-26' NEWS.md R/plot-covariance-tables.R man/plot_Sigma_comparison.Rd tests/testthat/test-plot-covariance-tables.R docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md`
  -> comparison-facet support is present in code, tests, NEWS, generated help,
  validation debt, and the report-ready contract.

## Tests Of The Tests

The new test constructs two labelled model comparisons, binds them, requests
`facet = "comparison"`, and checks both the stored plotting data and the
`FacetWrap` object. This is the feature-combination path needed for the
Covariance/correlation article.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  prepares the next public article integration but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Known Limitations And Next Actions

- `facet = "comparison"` assumes precomputed rows already carry a clear
  `comparison` label. It does not generate model labels automatically.
- The next slice should replace the hand-built three-panel heatmap in
  `vignettes/articles/covariance-correlation.Rmd` with comparison-faceted
  `plot_Sigma_comparison()` output.
