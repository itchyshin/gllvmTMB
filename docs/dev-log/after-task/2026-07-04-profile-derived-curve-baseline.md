# After-Task Report: Profile-Derived Curve Baseline Repair

Date: 2026-07-04 21:13 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #679

## Goal

Make every profile-derived curve report likelihood-ratio distance from the
joint MLE objective, not from the best point on the finite candidate grid.

## Files Changed

- `R/profile-derived-curves.R`
- `tests/testthat/test-profile-derived-curves.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-profile-derived-curve-baseline.md`

## What Changed

- Added `.profile_curve_delta_deviance()` and routed repeatability,
  phylogenetic signal, communality, correlation, and variance-proportion curve
  builders through it.
- Added refit-inversion bounds to correlation and variance-proportion curve
  outputs, matching the existing bracket-bisect profile CI route.
- Added a pure regression test that distinguishes the joint-MLE baseline from a
  grid-minimum baseline.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-derived-curves.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-curves.R", reporter = "summary")'
```

Result: quick profile-derived curve tests passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-curves.R", reporter = "summary")'
```

Result: heavy profile-derived curve tests passed.

## Rose Verdict

OK as a curve-baseline and summary-alignment repair. This does not add new
source-specific LV support, mixed-family CI support, or empirical coverage
calibration.

## Next

Continue the completion arc with the next narrow inference or data-correctness
slice. Candidate next stops are the Gamma/profile full-check failure, missing
response/predictor correctness, or structural random-slope extractor guards.
