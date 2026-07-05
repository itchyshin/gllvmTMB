# Profile Route Parser-Boundary Truth Lock

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `4817db59`

## Goal

Make the profile route matrix harder to drift from the public parser
contract for structural-dependence interval targets.

## Changes

- Added focused parser-boundary tests in
  `tests/testthat/test-profile-route-matrix.R`.
- The new rho contract check verifies that accepted public tiers and legacy
  aliases map to route-matrix rows with `covered`, `partial`, or `point_only`
  status.
- The new rho blocked-token check verifies that kernel and augmented
  source/split tiers fail before dispatch while the matrix records them as
  blocked.
- The new communality contract check verifies that only `unit`, `unit_obs`,
  `phy`, `B`, and `W` parse today; cluster tiers stay not applicable, and
  spatial/kernel/augmented split tiers stay planned or blocked.

## Evidence

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
```

Result: `test-profile-route-matrix.R` passed.

## Boundaries

- This is a truth-lock/test slice only.
- No new profile route was exposed.
- No source-specific `lv = ~ env`, mixed-family CI, likelihood,
  calibration, or package API claim changed.
