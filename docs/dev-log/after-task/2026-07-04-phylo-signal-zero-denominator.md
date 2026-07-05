# Phylogenetic-signal zero-denominator guard

## Goal

Prevent `extract_phylo_signal()` from returning `NaN` for a single degenerate
trait when other traits have positive `V_eta` denominators.

## Changes

- Added `.safe_phylo_signal_components()`.
- Routed `H2`, `C2_non`, and `Psi` through the shared safe proportion helper.
- Added a pure regression in `tests/testthat/test-extractors-extra.R`.
- Updated PHY-07 and EXT-07 in the validation-debt register.

## Validation

Focused validation passed:

```sh
Rscript --vanilla -e 'invisible(parse("R/extract-omega.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-extractors-extra.R", reporter = "summary")'
```

## Claim Boundary

This is a zero-denominator correctness guard for an existing point extractor.
It does not change phylogenetic-signal interval calibration or profile routing.
