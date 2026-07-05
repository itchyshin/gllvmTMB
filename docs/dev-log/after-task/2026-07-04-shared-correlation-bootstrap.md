# Shared correlation bootstrap across tiers

## Goal

Make `extract_correlations(method = "bootstrap", tier = "all")` reuse one
`bootstrap_Sigma(what = "R")` result for all bootstrappable tiers instead of
rerunning the same parametric bootstrap once per tier.

## Changes

- Hoisted the bootstrap call in `R/extract-correlations.R`.
- The shared call requests all bootstrappable internal tiers among `B`, `W`,
  and `phy`.
- Existing spatial/SPDE fallback remains a labelled Wald/Fisher-z fallback.
- Added a mock-based regression in `tests/testthat/test-fisher-z-correlations.R`
  proving a B/W `tier = "all"` request calls `bootstrap_Sigma()` exactly once.
- Updated CI-09 with the runtime-plumbing guard.

## Validation

Focused validation passed:

```sh
Rscript --vanilla -e 'invisible(parse("R/extract-correlations.R")); cat("parse-ok\n")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-fisher-z-correlations.R", reporter = "summary")'
```

## Claim Boundary

This is a runtime and reproducibility cleanup. It does not add a new
correlation interval method, does not calibrate bootstrap coverage, and does
not change the spatial/SPDE fallback boundary.
