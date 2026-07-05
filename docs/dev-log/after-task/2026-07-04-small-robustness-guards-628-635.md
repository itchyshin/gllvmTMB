# Small Robustness Guards For #628 And #635

Date: 2026-07-04

## Goal

Close two small robustness issues found during the gllvmTMB completion arc:
the single-row residual-scale initializer (#635) and the `meta_V(type = ...)`
unknown-value diagnostic (#628).

## Changes

- Added `.gllvmTMB_log_sigma_eps_start()` and routed Gaussian
  `log_sigma_eps` starts through it so one-row, empty, and constant residual
  vectors use the intended `1e-3` floor instead of `NA`/`NaN`.
- Replaced the `meta_V(type = ...)` parser's internal `match.arg()` call with
  explicit validation and a package cli error for unrecognised literal values.
- Added pure regressions for the residual floor and
  `meta_V(type = "approximate")`.
- Updated MET-03 to record the parser guard evidence while keeping
  proportional known-V blocked.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); invisible(parse("R/brms-sugar.R")); invisible(parse("tests/testthat/test-formula-grammar-smoke.R")); invisible(parse("tests/testthat/test-m3-4-warmstart-phi-clamp.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-formula-grammar-smoke.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-m3-4-warmstart-phi-clamp.R", reporter = "summary")'
```

Result: parse passed; both focused test files passed. The warmstart file kept
its expected heavy skips because `GLLVMTMB_HEAVY_TESTS` was not set.

## Claim Boundary

This is a robustness and diagnostics slice only. It does not promote
proportional known-V meta-analysis, profile intervals, bootstrap calibration,
or any new response-family capability.

## Rose Verdict

OK for local commit. MET-03 remains blocked; #628 and #635 are closed locally
by focused tests without widening public claims.
