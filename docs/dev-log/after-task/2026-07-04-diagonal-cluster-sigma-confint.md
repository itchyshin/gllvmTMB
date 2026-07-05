# After-Task Report: Diagonal Cluster Sigma `confint()` Tokens

Date: 2026-07-04

## Goal

Wire `confint()` support for `parm = "Sigma_cluster"` and
`parm = "Sigma_cluster2"` as diagonal-only matrix wrappers around the existing
direct cluster log-SD profile route.

## What Changed

- Added `Sigma_cluster` and `Sigma_cluster2` to the sigma parameter-token
  metadata in `R/z-confint-gllvmTMB.R`.
- Routed Wald/profile intervals for these tiers through
  `theta_diag_species` and `theta_diag_cluster2`.
- Kept bootstrap explicitly blocked for these tokens until a simulate-refit
  calibration gate exists.
- Updated the profile route matrix and Design 73 from `planned` to `partial`
  for the diagonal cluster Sigma matrix tokens.
- Updated CI-11 in the validation-debt register to keep interval calibration
  separate from route-ledger coverage.

## Files Changed

- `R/z-confint-gllvmTMB.R`
- `R/profile-route-matrix.R`
- `tests/testthat/test-profile-route-matrix.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-diagonal-cluster-sigma-confint.md`

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); invisible(parse("R/profile-route-matrix.R")); invisible(parse("tests/testthat/test-profile-route-matrix.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-cluster2-rename.R")'
```

Result: parse passed; focused route-matrix tests passed; cluster2 focused tests
passed with the expected heavy recovery skip.

Ad-hoc smoke: a small crossed Gaussian fit returned `Sigma_cluster` profile
rows successfully. This was a route smoke only, not calibration evidence.

## Claim Boundary

This is a partial route improvement. It supports diagonal-only
`Sigma_cluster` / `Sigma_cluster2` interval plumbing for Wald/profile methods.
It does not claim full covariance calibration, non-diagonal cluster
correlation intervals, bootstrap calibration, or augmented structural split
profile support.

Rose verdict: wording remains bounded. Keep the status `partial` until a
separate calibration/simulation gate is run.
