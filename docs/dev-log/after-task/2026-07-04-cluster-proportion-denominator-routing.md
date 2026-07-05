# After-Task Report: Cluster Proportion Denominator Routing

Date: 2026-07-04

## Goal

Add denominator-aware variance-proportion routing for the diagonal `cluster`
and `cluster2` tiers without claiming spatial proportion support or calibrated
interval coverage.

## What Changed

- `extract_proportions()` now includes `unique_cluster` and
  `unique_cluster2` when the corresponding diagonal grouping tiers are active.
- `proportion:*` token parsing accepts the new components.
- Wald reconstruction reads `sd_q` and `sd_c2` from the report object.
- Profile targets include `theta_diag_species` and `theta_diag_cluster2` in
  both the numerator and all-tier denominator.
- Proportion bootstrap refits now forward canonical `unit`, `unit_obs`,
  `cluster`, and `cluster2` arguments; this is route plumbing, not calibration
  evidence.
- Route-matrix rows for cluster and cluster2 proportions moved from `planned`
  to `partial`; spatial proportions remain `planned`.

## Files Changed

- `R/extract-omega.R`
- `R/proportions-ci.R`
- `R/profile-derived.R`
- `R/profile-route-matrix.R`
- `R/z-confint-gllvmTMB.R`
- `NEWS.md`
- `man/extract_proportions.Rd`
- `tests/testthat/test-proportions-cluster-components.R`
- `tests/testthat/test-profile-route-matrix.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-cluster-proportion-denominator-routing.md`

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/extract-omega.R")); invisible(parse("R/proportions-ci.R")); invisible(parse("R/profile-derived.R")); invisible(parse("R/z-confint-gllvmTMB.R")); invisible(parse("R/profile-route-matrix.R")); invisible(parse("tests/testthat/test-proportions-cluster-components.R")); invisible(parse("tests/testthat/test-profile-route-matrix.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-proportions-cluster-components.R")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R")'
```

Result: parse passed; `test-proportions-cluster-components.R` passed; route
matrix tests passed.

Ad-hoc live smokes on a small crossed Gaussian `cluster + cluster2` fit:

- `extract_proportions(..., link_residual = "none")` returned
  `unique_cluster` and `unique_cluster2`.
- `confint(..., parm = "proportion:unique_cluster", method = "wald")` returned
  finite bounds in `[0, 1]`.
- One selected profile row returned a bounded interval.
- A tiny bootstrap smoke ran but warned that simulation is conditional for the
  diagonal RE tiers, so it is not calibration evidence.

## Claim Boundary

This is a partial route improvement. It supports diagonal cluster and cluster2
variance components in the all-tier proportion denominator. It does not claim
spatial variance-proportion support, augmented split proportion support,
non-diagonal cluster covariance/correlation intervals, or empirical interval
coverage.

Rose verdict: acceptable if advertised as denominator plumbing and kept at
`partial` until a calibration gate is run.
