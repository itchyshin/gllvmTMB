# Cluster Sigma Profile Canary

Date: 2026-07-05 03:38 MDT

Branch: `codex/r-bridge-grouped-dispersion`

## Goal

Strengthen the profile route matrix with one fitted Gaussian canary for the
diagonal `Sigma_cluster` and `Sigma_cluster2` matrix-token routes.

## Changes

- `tests/testthat/test-profile-route-matrix.R`: added a small crossed Gaussian
  fixture with species and year diagonal tiers, then profiled
  `Sigma_cluster` and `Sigma_cluster2`.
- `R/profile-route-matrix.R`: updated the route claims to mention the fitted
  Gaussian canary while keeping status `partial`.
- `docs/design/73-profile-likelihood-route-matrix.md`: documented that the
  canary is route evidence, not bootstrap or empirical coverage calibration.
- `docs/design/35-validation-debt-register.md`: updated CI-11 with the canary
  result and boundary.
- `docs/dev-log/check-log.md`: recorded parse and focused test evidence.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("tests/testthat/test-profile-route-matrix.R")); cat("parse-ok\n")'
```

Outcome: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R")'
```

Outcome: passed, 301 assertions, 0 failures, 0 warnings, 0 skips.

## Claim Boundary

The route remains `partial`. The canary proves fitted Gaussian diagonal profile
rows are finite for `Sigma_cluster` / `Sigma_cluster2` and that off-diagonals
stay structural zeros. It does not claim bootstrap support, simulation
calibration, non-Gaussian calibration, or non-diagonal cluster covariance
intervals.

## Council Notes

Fisher accepted this as the economical next profile slice because it strengthens
an already declared diagonal route. Rose blocks broader language: this is not a
general cluster covariance interval claim. Grace notes no Totoro/DRAC run was
needed for this local canary.
