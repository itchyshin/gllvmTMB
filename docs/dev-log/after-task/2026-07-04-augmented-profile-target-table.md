# After-Task Report: Augmented Profile Target Table

Date: 2026-07-04

## Goal

Write the symbolic target table required before any augmented structural
random-slope profile-likelihood route is implemented.

## What Changed

- Added `.profile_augmented_target_table()` as the internal target ledger for
  `unit_slope`, `phy_unique_slope`, `phy_dep`, `phy_slope`,
  `spde_base_slope`, `spde_dep`, and `spde_slope`.
- Kept every augmented split `Sigma`, communality, `rho`, and proportion route
  `blocked` in `.profile_route_matrix()`.
- Added pure tests that force every augmented level x estimand pair to have
  exactly one target row.
- Added Design 74 as the durable target source for shapes, flattening order,
  numerator/denominator boundaries, and next gates.
- Updated Design 73 and CI-11 so the operating truth says target symbols are
  declared, but profile CI implementation and calibration are still pending.

## Files Changed

- `R/profile-route-matrix.R`
- `tests/testthat/test-profile-route-matrix.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/design/74-augmented-profile-target-table.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-augmented-profile-target-table.md`

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-route-matrix.R")); invisible(parse("tests/testthat/test-profile-route-matrix.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
```

Result: parse passed and `test-profile-route-matrix.R` passed.

## Claim Boundary

This is a route-truth and design slice only. It does not implement a new
profile interval, does not change public `confint()` behavior, and does not
promote any augmented split target to covered. Point extraction/recovery rows
remain separate from interval support. The recommended next canary is a
selected Gaussian `unit_slope` `Sigma` or `rho` route.

Rose verdict: acceptable as a prerequisite lock. The table makes the next
implementation smaller, but all augmented profile routes remain blocked until a
direct implementation and evidence gate land.
