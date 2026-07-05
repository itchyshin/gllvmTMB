# After-task: Lambda selected-profile pinned-entry guard

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`

## Goal

Repair the selected-entry Lambda profile route so exact-known pinned entries
are not sent through `loading_profile()`. The user-facing invariant is that a
pinned `Lambda:i,k` request should return the known point with
`ci_status = "pinned"` under the selected profile route, matching the Wald and
full-grid profile routes.

## Files changed

- `R/z-confint-gllvmTMB.R`
- `tests/testthat/test-confint-lambda.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-lambda-selected-profile-pinned-guard.md`

## What changed

- `.confint_lambda()` now computes the Lambda pinned-entry matrix before
  dispatching selected profile refits.
- For `parm = "Lambda:i,k"` / `"Lambda:i,k;j,l"` with explicit pins, the
  profile path filters those pinned entries out of the `loading_profile()`
  call.
- Pinned selected rows keep `estimate`, `lower`, and `upper` equal to the
  fitted value and report `ci_status = "pinned"`.
- Mixed pinned/free selections still profile the requested free entries and
  leave the pinned rows collapsed to points.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); invisible(parse("tests/testthat/test-confint-lambda.R")); cat("parse-ok\n")'
```

Result: passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-confint-lambda.R")'
```

Result: 25 passed, 0 failed, 0 warnings, 11 expected heavy-test skips.

A direct pure fixture check returned `Lambda[trait_1,LV2]` with
`estimate = lower = upper = 0` and `ci_status = "pinned"` for
`.confint_lambda(..., parm = "Lambda:1,2", method = "profile")`.

## Claim boundary

This is a route-consistency and status-truth repair for CI-02. It does not
promote empirical profile calibration, mixed-family CI coverage, or any new
structural-dependence interval surface.

## Council notes

- Fisher: selected-entry profile status is now aligned with the Wald and
  full-grid profile routes.
- Curie: pure tests pin the no-refit behavior for pinned-only requests and
  the free-only profiling behavior for mixed selected requests.
- Rose: no broad confidence-interval or calibration claim changed.
