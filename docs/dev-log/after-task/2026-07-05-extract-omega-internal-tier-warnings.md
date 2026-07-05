# extract_Omega Internal Tier Warning Guard

Date: 2026-07-05 03:34 MDT

Branch: `codex/r-bridge-grouped-dispersion`

## Goal

Close the local issue #587 repair: `extract_Omega()` should not leak
deprecated `level = "B"` / `level = "W"` warnings when those tier names were
auto-detected internally rather than typed by the user.

## Changes

- `R/extract-omega.R`: pass `.skip_warn = TRUE` when `extract_Omega()` calls
  `extract_Sigma()` inside its internal tier loop.
- `tests/testthat/test-extract-omega.R`: add a pure mocked regression that
  checks auto-detected `B` / `W` tiers pass `.skip_warn = TRUE` and produce no
  lifecycle warning.
- `docs/design/35-validation-debt-register.md`: update EXT-03 with the local
  issue #587 closeout boundary.
- `docs/dev-log/check-log.md`: record focused parse and test evidence.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/extract-omega.R")); invisible(parse("tests/testthat/test-extract-omega.R")); cat("parse-ok\n")'
```

Outcome: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-extract-omega.R")'
```

Outcome: passed, 25 assertions, 0 failures, 0 warnings, 0 skips.

## Claim Boundary

This is a warning-surface and extractor-hygiene fix only. It does not promote a
new covariance tier, interval route, profile target, or calibration claim.

## Rose Verdict

OK for local commit. The user-facing behavior is narrower and quieter without
widening the advertised capability surface.
