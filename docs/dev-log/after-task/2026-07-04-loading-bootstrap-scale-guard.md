# Loading bootstrap scale-guard floor

## Goal

Harden the confirmatory loading bootstrap pathology screen so weak-loading fits
do not get a cutoff that is only `5 * max(abs(Lambda_hat))`. That old rule could
discard legitimate bootstrap tail draws when the fitted loadings were small.

## Changes

- Added `.loading_bootstrap_scale_guard()` in `R/loading-ci-bootstrap.R`.
- Kept the 5x multiplier for true inflated-refit pathologies.
- Added an absolute floor of 2 on the loading scale.
- Added a pure regression in `tests/testthat/test-loading-ci-bootstrap.R`.
- Updated LAM-03 to cite the bootstrap-loading robustness evidence.

## Validation

Focused validation passed:

```sh
Rscript --vanilla -e 'invisible(parse("R/loading-ci-bootstrap.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-loading-ci-bootstrap.R", reporter = "summary")'
```

The new pure scale-guard regression executed. The expensive bootstrap-fit rows
skipped as expected outside `GLLVMTMB_HEAVY_TESTS=1`.

## Claim Boundary

This does not calibrate bootstrap loading coverage and does not make bootstrap
the primary uncertainty engine. It only prevents an avoidable weak-loading
tail-truncation artifact in the existing confirmatory bootstrap path.
