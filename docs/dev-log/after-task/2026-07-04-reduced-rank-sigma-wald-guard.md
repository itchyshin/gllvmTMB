# Reduced-rank Sigma Wald guard

## Goal

Add direct regression evidence that Wald intervals for total `Sigma_unit` do
not silently reuse the `theta_diag` standard error when a reduced-rank
`latent()` block contributes to the same total covariance.

## Changes

- Added a heavy-gated `confint()` regression to
  `tests/testthat/test-confint-bootstrap.R`.
- Reused the existing reduced-rank-plus-Psi `make_tiny_B_fit()` fixture.
- Asserted finite point estimates and unavailable `lower` / `upper` bounds for
  `confint(fit, parm = "Sigma_unit", method = "wald")`.
- Added `test-confint-bootstrap.R` to the CI-01 validation-debt evidence list.

## Validation

Focused validation passed:

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'Sys.setenv(GLLVMTMB_HEAVY_TESTS = "1", NOT_CRAN = "true"); pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-bootstrap.R", reporter = "summary")'
```

## Claim Boundary

This does not promote reduced-rank total-Sigma Wald intervals. It preserves the
opposite claim: the point target is available, but bounds remain unavailable
until a correct total-covariance interval route is used.
