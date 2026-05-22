# After Task: Public Covariance Plot Surface Scan

**Branch**: `codex/florence-covariance-plots-2026-05-21`
**Date**: `2026-05-21`
**Roles (engaged)**: `Ada / Rose / Florence / Fisher / Pat / Grace`

## 1. Goal

Find the next public places where covariance, correlation, or communality
outputs were still table-first, then move the reader-facing path toward
report-ready plot helpers without hiding exact numeric rows.

## 2. Implemented

- Added a scan note at
  `docs/dev-log/audits/2026-05-21-covariance-plot-surface-scan.md`.
- Updated `README.md` so the first example stores `corr_rows` and calls
  `plot_correlations(corr_rows)`.
- Updated Get Started (`vignettes/gllvmTMB.Rmd`) so pairwise correlations are
  shown as exact tidy rows and as a plot before the optional matrix view.
- Updated `vignettes/articles/covariance-correlation.Rmd` with:
  - `extract_Sigma_table(..., entries = "upper")` +
    `plot_Sigma_table()` for upper-triangle off-diagonal `Sigma_unit` rows;
  - `extract_correlations()` + `plot_correlations()` for fitted pairwise
    correlations from the latent + unique model.
- Updated `NEWS.md` and
  `docs/design/53-report-ready-extractor-plot-contract.md` so the public
  integration status is current.
- Fixed `plot_Sigma_table()` so fitted-object calls default to
  `entries = "upper"` rather than `"offdiag"`. This prevents duplicate mirror
  rows in symmetric covariance/correlation plots while keeping `"offdiag"` as
  an explicit option.

## 3. Files Changed

- `README.md`
- `R/plot-covariance-tables.R`
- `man/plot_Sigma_table.Rd`
- `tests/testthat/test-plot-covariance-tables.R`
- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `NEWS.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/audits/2026-05-21-covariance-plot-surface-scan.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-covariance-plot-surface-scan.md`

## 4. Checks Run

- `gh pr list --state open` -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"` -> only the current PR #233
  branch was visible as recent package work.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("gllvmTMB", quiet = FALSE, new_process = FALSE)'`
  -> rendered `pkgdown-site/articles/gllvmTMB.html`.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", quiet = FALSE, new_process = FALSE)'`
  -> rendered `pkgdown-site/articles/covariance-correlation.html`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/plot_Sigma_table.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables|extract-sigma-table")'`
  -> 97 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `git diff --check` -> clean.

## 5. Visual Review

Florence: the Get Started correlation plot and the Covariance/correlation
correlation plot pass. They are readable, use the existing helper theme, and
make the comparison faster than scanning tables.

Florence's first pass on the Sigma plot was a revision: the off-diagonal
setting duplicated symmetric pairs, making some relationships appear twice.
The fix changes the fitted-object default to the upper triangle and the
rerendered figure passes.

Fisher: the Sigma plot caption explicitly says open points are point estimates
without finite interval bounds, and the text points readers toward
bootstrap-derived rows for Sigma uncertainty. The correlation plot uses
Fisher-z intervals and says so.

Pat: the public articles now keep exact rows for reporting while putting the
interpretive comparison into a plot. This is easier for first-time readers
than raw matrix indexing.

Rose: the scan found additional hidden surfaces, especially
`mixed-family-extractors`, `behavioural-syndromes`, `phylogenetic-gllvm`, and
`joint-sdm`. They should not be rushed into the public path before their tier
and validation status are current.

Grace: the affected pages rendered and `pkgdown::check_pkgdown()` passed. Full
`devtools::check()` was not rerun for this docs/plot-surface slice.

## 6. Issue Ledger

- #230 ("Article surface reset and user-first tooling gate") remains open.
  This slice is partial progress toward that gate, not a closure.

## 7. Known Limitations And Next Actions

- `plot_Sigma_table()` still displays only supplied interval bounds; it does
  not compute Sigma uncertainty.
- Communality still lacks an interval-aware table/plot helper.
- Next clean inference slice: build bootstrap-derived Sigma-table rows and
  communality interval rows, then feed them into the plot helpers without
  hand-built joins in articles.
