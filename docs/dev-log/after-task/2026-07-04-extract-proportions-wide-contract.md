# extract_proportions Wide-Format Contract

Date: 2026-07-04

## Goal

Close issue #663 by making `extract_proportions(format = "wide")` return
per-component proportions, as documented.

## Files Changed

- `R/extract-omega.R`
- `tests/testthat/test-extract-omega.R`
- `tests/testthat/test-mixed-response-sigma.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`

## What Changed

- Wide output now returns the proportion matrix `P`.
- `total_variance` remains the absolute per-trait denominator.
- Existing tests now require wide component columns to sum to one directly.
- Mixed-response expectations now recover absolute link residual variance by
  multiplying the wide proportion column by `total_variance`.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/extract-omega.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-extract-omega.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-mixed-response-sigma.R", reporter = "summary")'
```

`test-extract-omega.R` passed. The mixed-response file parsed and its heavy
fit rows were skipped under CRAN mode.

## Claim Boundary

This is an extractor return-contract fix for the existing ordinary
variance-share surface. It does not add delta-family support, interval
calibration, or new variance-partition estimands.

## Rose Verdict

OK. The function now matches its name and documentation; downstream users can
treat wide component columns as shares and use `total_variance` for absolute
scale recovery.
