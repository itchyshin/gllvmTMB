# Profile Route-Matrix Checkpoint

Date: 2026-07-04

## Goal

Make the profile-likelihood route truth explicit enough to guide the next
uncertainty slices across ordinary, source-specific, cluster, cluster2, and
augmented split tiers.

## Changes

- Expanded Design 73 with the current route snapshot by level and estimand.
- Clarified that direct parameter profiles do not imply profile-ready derived
  intervals for covariance matrices, correlations, communalities, or variance
  proportions.
- Tightened `test-profile-route-matrix.R` so all augmented split estimands
  remain blocked until a symbolic target table exists.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-route-matrix.R")); invisible(parse("tests/testthat/test-profile-route-matrix.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
```

Result: parse passed; the focused route-matrix test file passed.

## Claim Boundary

This is a truth-lock checkpoint. It does not add new profile algorithms, expose
source-specific `lv`, promote augmented split intervals, or claim interval
calibration from `pdHess`.

## Rose Verdict

OK for local commit. The profile route map is clearer, and no partial or
blocked route was promoted without evidence.
