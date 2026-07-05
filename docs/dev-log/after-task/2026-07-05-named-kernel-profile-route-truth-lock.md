# After Task: Named Kernel Profile Route Truth Lock

Date: 2026-07-05

## Goal

Record named `kernel_*()` tiers in the profile route matrix as explicitly
blocked for profile/confint intervals. This aligns the route ledger with the
audit finding that `extract_Sigma()` and `extract_Sigma_table()` can see more
levels than `confint()` can request.

## Files Changed

- `R/profile-route-matrix.R`
- `tests/testthat/test-profile-route-matrix.R`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`

## Implementation

- Added `kernel_named` to `.profile_route_levels()`.
- Added blocked `direct_sd`, `Sigma`, `communality`, `rho`, and `proportion`
  rows for named kernel tiers.
- Added pure route-matrix coverage proving named-kernel interval routes remain
  blocked.
- Updated Design 73 and validation-debt row `CI-11`.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-route-matrix.R")); invisible(parse("tests/testthat/test-profile-route-matrix.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
```

Both commands passed.

## Claim Boundary

This is a route-ledger truth-lock only. It does not implement named-kernel
`confint()` tokens, profile likelihood intervals, variance-proportion
denominators, or calibration evidence.

Next kernel interval work should start from a selected target and denominator
design, not from the fact that point covariance extraction already works.
