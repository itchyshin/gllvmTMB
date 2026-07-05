# After-Task Report: Unit-Slope Rho Profile Canary

Date: 2026-07-04

## Goal

Wire the first augmented structural profile-likelihood canary after Design 74:
Gaussian selected-entry `rho:unit_slope:i,j`, without promoting
`Sigma_unit_slope`, source-specific slope routes, proportions, or
non-Gaussian augmented profile claims.

## What Changed

- `profile_ci_correlation()` now accepts `tier = "unit_slope"` and targets the
  augmented ordinary `2T` coefficient covariance returned by
  `extract_Sigma(level = "unit_slope")`.
- `confint()` now accepts `parm = "rho:unit_slope:i,j"` for
  `method = "profile"` only.
- The `unit_slope` route is explicitly Gaussian-only; non-Gaussian augmented
  profiles remain behind a separate calibration gate.
- `.profile_route_matrix()` marks only `rho` / `unit_slope` as `partial`; every
  other augmented split target remains `blocked`.
- Roxygen documentation and generated Rd were updated for the new token.

## Files Changed

- `R/profile-derived.R`
- `R/z-confint-gllvmTMB.R`
- `R/profile-route-matrix.R`
- `tests/testthat/test-profile-route-matrix.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/design/74-augmented-profile-target-table.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-unit-slope-rho-profile-canary.md`
- `man/confint.gllvmTMB_multi.Rd`
- `man/profile_ci_correlation.Rd`

## Validation

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'invisible(parse("R/profile-derived.R")); invisible(parse("R/z-confint-gllvmTMB.R")); invisible(parse("R/profile-route-matrix.R")); invisible(parse("tests/testthat/test-profile-route-matrix.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
env NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R", reporter = "summary")'
git diff --check
```

Result: documentation, parse checks, route-matrix tests, augmented ordinary
random-regression tests, and whitespace checks passed.

Ad-hoc live smoke on a small Gaussian `latent(1 + temperature | individual)`
fit:

- `confint(fit, parm = "rho:unit_slope:1,2", method = "profile")` returned
  finite bounds for an interior selected entry in the second smoke fixture.
- A near-boundary selected entry returned a labelled one-sided/failed endpoint
  rather than crashing, reinforcing that boundary calibration is still pending.

## Claim Boundary

This is a partial route canary. It proves parser, dispatch, target-function,
documentation, and small live-smoke behavior for selected Gaussian
`unit_slope` correlations. It does not claim empirical coverage, simultaneous
coverage, non-Gaussian validity, augmented `Sigma` profile support, source-
specific augmented profile support, or augmented proportion support.

Rose verdict: acceptable as the first canary if kept partial and followed by a
known-DGP plus boundary-calibration gate before wider promotion.
