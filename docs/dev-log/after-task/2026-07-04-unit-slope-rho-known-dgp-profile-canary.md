# Unit-slope rho known-DGP profile canary

Date: 2026-07-04

## Goal

Add one direct known-DGP integration check for the Gaussian
`rho:unit_slope:i,j` selected-entry profile canary.

## Files Changed

- `R/profile-route-matrix.R`
- `tests/testthat/test-ordinary-latent-random-regression.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/design/74-augmented-profile-target-table.md`
- `docs/dev-log/check-log.md`

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-route-matrix.R")); invisible(parse("tests/testthat/test-ordinary-latent-random-regression.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
env NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R", reporter = "summary")'
```

All three checks passed.

## Claim Boundary

The route remains `partial`. The new evidence is one Gaussian selected-entry
known-DGP truth-inclusion canary. It does not prove empirical coverage,
boundary calibration, `Sigma_unit_slope` intervals, augmented proportions,
source-specific augmented profiles, or non-Gaussian augmented profiles.

## Rose Verdict

OK as a narrow canary hardening slice. Do not promote beyond `partial` until
boundary behavior and empirical calibration are directly tested.
