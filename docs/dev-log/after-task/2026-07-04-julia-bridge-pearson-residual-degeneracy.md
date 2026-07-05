# Julia Bridge Pearson Residual Degeneracy Guard

Date: 2026-07-04

## Goal

Close issue #641 for the R-side Julia bridge postfit surface by preventing one
degenerate Pearson-residual variance cell from aborting the entire residual
matrix.

## Changes

- Updated `.gllvm_julia_residual_variance()` so non-positive or non-finite
  cell-level residual variances are marked `NA_real_`.
- Added a pure bridge regression where a saturated binomial row has
  `plogis(eta) == 1` exactly. Pearson residuals now return `NA` for the
  degenerate row and finite values for the unaffected row.
- Added a JUL-01 validation-register addendum while keeping the bridge row
  partial.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); invisible(parse("tests/testthat/test-julia-bridge.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

Result: parse passed; the focused bridge test file passed. Thirteen live
GLLVM.jl integration sections skipped because `GLLVM_JL_PATH` was not
configured.

## Claim Boundary

This is a postfit robustness guard only. It does not widen Julia bridge family,
CI, mask, mixed-family, newdata, or structured-term support.

## Rose Verdict

OK for local commit. The failure mode is corrected with pure evidence, and the
bridge capability row stays partial.
