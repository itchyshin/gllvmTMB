# After-Task Report: Profile-Derived Non-Finite Inversion Repair

Date: 2026-07-04 22:35 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #653

## Goal

Prevent a single failed extreme grid refit from erasing an otherwise valid
profile-derived confidence-bound crossing.

## Files Changed

- `R/profile-derived-curves.R`
- `tests/testthat/test-profile-derived-curves.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-profile-derived-nonfinite-inversion.md`

## What Changed

- `.invert_profile_derived()` now drops non-finite `profile_value` /
  `delta_deviance` rows on each side before fitting the interpolation or
  smoothing curve used for root-finding.
- The inverter still returns `NA` when a side has fewer than two finite points
  after filtering.
- Added a pure regression where both edge refits fail but finite interior
  points bracket the chi-square cutoff on both sides.
- Updated CI-12 in the validation register.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-derived-curves.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-curves.R", reporter = "summary")'
```

Result: normal profile-derived curve tests passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-curves.R", reporter = "summary")'
```

Result: heavy profile-derived curve tests passed.

## Rose Verdict

OK as a profile-curve robustness repair. This does not promote source-specific
profile intervals, mixed-family CIs, coverage calibration, or bootstrap rescue
language.

## Next

Continue inference hardening. Good adjacent candidates are unmatched
`confint()` parameter names (#660), profile fallback seed/nsim handling (#606),
and curve tie handling (#643).
