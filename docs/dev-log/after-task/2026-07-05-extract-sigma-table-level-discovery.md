# After-task: extract_Sigma_table cluster2/kernel level discovery

Date: 2026-07-05

## Goal

Repair issue #588 locally: `extract_Sigma_table()` should discover and route the
same tableable point-estimate tiers that `extract_Sigma()` already supports,
including `cluster2` and named `kernel_*()` tiers.

## Files Changed

- `R/extract-sigma-table.R`
- `tests/testthat/test-extract-sigma-table.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-extract-sigma-table-level-discovery.md`

## Implementation

- Added `cluster2` to `.sigma_available_levels()` when
  `fit$use$diag_cluster2` is active.
- Added fitted `fit$kernel_levels$name` entries to the same table-level
  availability ledger.
- Left interval columns unchanged: this remains a point-estimate table helper,
  not a new Wald/profile/bootstrap interval route.

## Tests Added

- Added a mocked regression in `test-extract-sigma-table.R` showing that
  `level = "all"` reaches both `cluster2` and a named kernel tier.
- The same test checks that a direct named-kernel table request returns the
  expected matrix entries.

## Validation

Focused checks passed:

```sh
Rscript --vanilla -e 'invisible(parse("R/extract-sigma-table.R")); invisible(parse("tests/testthat/test-extract-sigma-table.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-extract-sigma-table.R", reporter = "summary")'
git diff --check
```

Outcome: parse passed; roxygen regenerated `man/extract_Sigma_table.Rd`; focused
`test-extract-sigma-table.R` passed with one pre-existing CRAN skip for the
mixed-family link-residual row; whitespace check passed.

## Scope Boundary

This slice does not add new covariance tiers, new kernel fitting support, or new
interval claims. It only fixes table-level discovery for tiers already supported
by `extract_Sigma()`.

## Review Notes

- Ada: kept the slice to one extractor-table routing bug.
- Curie: focused test is pure/mocked to avoid heavy coevolution or cluster2
  family sweeps.
- Rose: claim remains point-only; no interval or calibration language promoted.

## Remaining Work

- Commit by explicit filenames if validation passes.
