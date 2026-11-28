# Check-log: #1585 leftover — varimax-frame pins, svd restart under a mapped theta_rr_B (#1585)

**Goal.** Reproduce the remaining #1585 stuck-axis path on `origin/main` @
`f4cee11c`, then check that the branch warns on constraint matrices that leave
a trait with no estimable loading and runs the svd restart under a mapped
`theta_rr_B` without moving pinned values, with no change to any existing
test's pass/fail result.

**Environment.** Ubuntu 24.04 cloud VM, R from CRAN apt with r2u binaries,
package installed with `R CMD INSTALL -l /tmp/rlib .`, tests run through
`devtools::load_all()` + `testthat::test_file(..., package = "gllvmTMB")` with
`NOT_CRAN=true`, `OMP_NUM_THREADS=1`.

**Exact commands.**

- Repro: `/tmp/repro.R` (the issue script plus a single `M[2, 2] <- 0` pin and
  `n_init = 3` refits). On `main`: zeros-only confirmatory -3224.5 (not stuck),
  recommended `wald_retention` matrix -3240.3 with `n_init = 1` and `3`,
  trait_1 loading 0 on both axes, `restart_history` = initial/jitter/jitter.
- Test batch (same 33 files on `main` worktree and branch):
  `test-suggest-lambda-constraint.R test-confirmatory-lambda.R
  test-lambda-pinned-zero-diagonal.R`, every other file matching
  `rg -l lambda_constraint tests/testthat`, plus `test-svd-start-1331.R
  test-svd-start-runaway-1713.R test-restart-selection-1335.R
  test-stage39-multi-start.R test-multi-start-sdreport-consistency.R`.
- Profile-retention probe `/tmp/profile_probe.R` (the 11 per-entry refits of
  `test-suggest-lambda-constraint.R:188`), on `main` and branch.

**Pass/fail counts.**

| file | main | branch |
|---|---|---|
| test-suggest-lambda-constraint.R | 58 / FAIL 0 / 1 warning | 58 / FAIL 0 / 1 warning |
| test-confirmatory-lambda.R | 49 / FAIL 0 / 2 warnings | 49 / FAIL 0 / 2 warnings |
| test-lambda-pinned-zero-diagonal.R | 3 / FAIL 0 | 19 / FAIL 0 |
| test-loading-ci.R | 77 / FAIL 0 / 31 skip | 79 / FAIL 0 / 31 skip / 2 warnings |
| other 29 files | identical | identical |
| all 33 | 828 results, FAIL 0, ERROR 0, 66 skip | 846 results, FAIL 0, ERROR 0, 66 skip |

The two new `test-loading-ci.R` warnings are the new
`suggest_lambda_constraint()` warning firing on the mocked 2x2 fixtures at
lines 255 and 279, whose expected matrix `[0, NA; NA, 0]` leaves trait 1 with
no estimable loading. Their expectations are unchanged and pass.

New tests on `main` (`R/` stashed): FAIL 3, ERROR 2. Profile probe: all 11
refits identical on main and branch for convergence, `pdHess` and LR.

**Not run.** Full `devtools::test()`, `R CMD check`, `pkgdown::check_pkgdown()`
(no exported name, reference topic or article changed); CI covers the suite.

**Claim boundary.** No validation-debt row moves. No default, estimand,
convergence rule or exported signature changed. The returned
`suggest_lambda_constraint()` matrix is unchanged; only a warning is added.
