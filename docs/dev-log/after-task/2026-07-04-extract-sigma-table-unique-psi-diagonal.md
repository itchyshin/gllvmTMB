# extract_Sigma_table Unique-Psi Diagonal Rows

Date: 2026-07-04

## Goal

Close issue #664 by preventing `extract_Sigma_table(part = "unique")` from
emitting fabricated off-diagonal zero rows for diagonal Psi components.

## Files Changed

- `R/extract-sigma-table.R`
- `tests/testthat/test-extract-sigma-table.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`

## What Changed

- Unique-part Sigma tables now use diagonal entries internally.
- Added a regression for the default `part = "unique"` call, without requiring
  users or tests to pass `entries = "diag"` explicitly.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/extract-sigma-table.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-extract-sigma-table.R", reporter = "summary")'
```

Focused Sigma-table tests passed. The existing mixed-family link-residual row
was skipped under CRAN mode.

## Claim Boundary

This is report-table truth hardening. It does not alter `extract_Sigma()` point
estimates, interval computation, or mixed-family support.

## Rose Verdict

OK. Psi report tables now expose only genuine diagonal estimands.
