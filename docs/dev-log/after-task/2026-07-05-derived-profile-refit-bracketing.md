# After Task: Derived Profile Refit Bracketing

Date: 2026-07-05

## Goal

Harden the shared derived-profile endpoint search so a single failed
constrained refit does not erase a later valid likelihood-ratio crossing. This
targets the Gamma/unit-tier profile-stability canary without widening any
interval claim.

## Files Changed

- `R/profile-derived.R`
- `tests/testthat/test-profile-derived-refit.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`

## Implementation

- Reworked `.profile_ci_via_refit()` to keep a finite probe ledger on each
  side of the MLE target.
- Skipped isolated failed constrained refits and continued expanding toward
  the natural target boundary.
- Added a conservative interpolation fallback when finite bracket endpoints
  exist but `uniroot()` cannot traverse a rough non-Gaussian surface.
- Added a pure regression for the first-probe-fails/later-crossing case.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-derived.R")); invisible(parse("tests/testthat/test-profile-derived-refit.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-refit.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-matrix-gamma-unit.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-curves.R", reporter = "summary")'
git diff --check
```

All commands passed. The `test-profile-derived-curves.R` non-heavy run kept
its heavy profile-curve blocks skipped as designed; the Gamma ordinary
unit-tier integration check was run with `GLLVMTMB_HEAVY_TESTS=1`.

## Claim Boundary

This is endpoint-search reliability only. It does not promote empirical
coverage, mixed-family CIs, spatial total-covariance CIs, named-kernel
profile/confint routes, or augmented/source-specific split profile routes.

The council audits found the broader route gap: `extract_Sigma()` can see
named kernel tiers and several augmented/split levels that public profile and
`confint()` cannot yet request. That should be a later route-matrix expansion
slice, not folded into this reliability patch.
