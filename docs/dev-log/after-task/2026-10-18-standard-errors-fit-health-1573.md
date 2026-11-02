# check_gllvmTMB() after standard_errors() (#1573)

## Scope
`standard_errors()` filled `fit$sd_report` but left the `fit$fit_health` cached
at fit time, so `check_gllvmTMB()` kept reporting `sdreport`, `pd_hessian` and
`max_fixed_se` as WARN ("standard-error calculation skipped") after the
deferred-SE workflow (`se = FALSE` -> `standard_errors()` -> `check_gllvmTMB()`).

## Outcome
`standard_errors()` now rebuilds `fit$fit_health` from the updated fit. Fields
set on the old health list but not produced by the builder (for example
`min_random_curvature`) are carried over. The early return for a fit that
already has an sdreport is unchanged. No API, likelihood or grammar change; no
roxygen change, so no `man/` regeneration.

## Checks
- New test in `tests/testthat/test-standard-errors.R`: RED before the fix
  (WARN rows persisted, status differed from an eager `se = TRUE` fit), GREEN
  after; it also asserts the lazy and eager `check_gllvmTMB()` statuses match.
- Full `devtools`-style `test_dir()` run: see the PR description.

## Follow-up
None for this issue.
