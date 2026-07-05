# Rootogram Auto Max-Count Cap

Date: 2026-07-04

## Goal

Close issue #693 by preventing one extreme fitted-model simulated count from
forcing `predictive_check(type = "rootogram")` to allocate and render thousands
of empty count bins when `max_count = NULL`.

## Files Changed

- `R/predictive-diagnostics.R`
- `tests/testthat/test-predictive-diagnostics.R`
- `man/predictive_check.Rd`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`

## What Changed

- Added `.gllvmTMB_auto_rootogram_max_count()` for the default rootogram display
  range.
- Capped automatic rootograms at counts `0:100` plus a `>100` pooled tail bin.
- Preserved explicit user-supplied `max_count` behavior.
- Updated the documented `max_count = NULL` contract.
- Added a pure regression test showing a simulated count of 5000 is pooled into
  `>100` instead of widening the display to thousands of bins.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/predictive-diagnostics.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-predictive-diagnostics.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE); cat("document-ok\n")'
```

Focused predictive-diagnostics tests passed. Existing fit-heavy rows were
skipped under CRAN mode; the new pure rootogram-tail regression ran.

## Claim Boundary

This is DIA-11 diagnostic plotting hardening only. It does not add a formal
residual test, latent-rank proof, interval calibration, or family coverage
beyond the existing Gaussian / Poisson / NB2 scoped diagnostics.

## Rose Verdict

OK to treat as a bounded robustness fix. Keep the public claim as an automatic
display guard with an explicit override, not as a new statistical diagnostic.
