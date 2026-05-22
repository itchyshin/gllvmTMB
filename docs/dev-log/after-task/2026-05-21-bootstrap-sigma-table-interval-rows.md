# After Task: Bootstrap Sigma Table Interval Rows

**Branch**: `codex/florence-covariance-plots-2026-05-21`
**Date**: `2026-05-21`
**Roles (engaged)**: `Ada / Emmy / Fisher / Florence / Rose / Grace`

## 1. Goal

Give `plot_Sigma_table()` real interval-bearing Sigma rows without making
article authors join bootstrap matrices by hand.

## 2. Implemented

- `extract_Sigma_table()` now accepts a `bootstrap_Sigma()` object.
- Bootstrap `Sigma_*` and `R_*` summaries are converted into the existing
  report-ready row schema.
- The returned rows fill `lower`, `upper`, `interval_method = "bootstrap"`,
  and row-level `interval_status`.
- Rows use validation-debt row `EXT-20`.
- The returned table carries a `bootstrap` attribute with `conf`, `n_boot`,
  `n_failed`, `ci_method`, and `link_residual`.
- `plot_Sigma_table()` now accepts a `bootstrap_Sigma()` object directly.
- Tests cover Sigma rows, correlation rows, missing interval bounds, unsupported
  bootstrap table requests, and direct plotting from a synthetic bootstrap
  object.

## 3. Files Changed

- `R/extract-sigma-table.R`
- `R/plot-covariance-tables.R`
- `tests/testthat/test-extract-sigma-table.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `man/extract_Sigma_table.Rd`
- `man/plot_Sigma_table.Rd`
- `NEWS.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-bootstrap-sigma-table-interval-rows.md`

## 4. Checks Run

- `gh pr list --state open` -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"` -> recent package work was
  the current plot-helper branch plus PR #233's base slice.
- `Rscript --vanilla -e 'parse("R/extract-sigma-table.R"); parse("R/plot-covariance-tables.R")'`
  -> parsed successfully.
- `air format R/extract-sigma-table.R R/plot-covariance-tables.R tests/testthat/test-extract-sigma-table.R tests/testthat/test-plot-covariance-tables.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/extract_Sigma_table.Rd` and `man/plot_Sigma_table.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma-table|plot-covariance-tables|bootstrap-Sigma")'`
  -> 167 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `git diff --check` -> clean.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 local install warning, 3 existing notes.

## 5. Visual Review

The synthetic bootstrap-object render wrote
`/tmp/gllvmTMB-bootstrap-sigma-raindrop.png`.

Florence verdict: PASS. The plot displays three unique Sigma pairs with finite
raindrop compatibility shapes and no duplicated mirror rows.

Fisher verdict: PASS for display provenance. The intervals are explicitly
bootstrap percentile bounds already present in the `bootstrap_Sigma()` object;
the helper does not claim to compute new uncertainty.

Grace verdict: PASS for the narrow slice. The short package check reproduced
the existing local install warning and notes, with no errors. Full
`devtools::check()` with tests was not rerun.

## 6. Known Limitations And Next Actions

- This does not add communality interval rows.
- This does not add repeatability interval rows.
- This does not compute bootstrap intervals from a fitted model; users still
  call `bootstrap_Sigma()` first.
- Next clean slice: add a communality interval-row helper over
  `bootstrap_Sigma()` output, then feed those rows into a `plot_communality()`
  helper.
