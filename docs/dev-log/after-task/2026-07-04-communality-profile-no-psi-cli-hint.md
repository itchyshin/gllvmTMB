# Communality Profile No-Psi Cli Hint

Date: 2026-07-04

## Goal

Close issue #668 by making the no-Psi communality profile error display its
actionable hint.

## Files Changed

- `R/profile-derived.R`
- `R/profile-derived-curves.R`
- `tests/testthat/test-profile-derived-curves.R`
- `docs/dev-log/check-log.md`

## What Changed

- Converted two `cli::cli_abort()` calls from scalar-message-plus-named-`...`
  form to named character-vector form, so the `i` hint is printed.
- Added a pure test that verifies the `residual = FALSE` hint is visible for
  the communality profile no-Psi boundary.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-derived.R")); invisible(parse("R/profile-derived-curves.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-curves.R", reporter = "summary")'
```

Focused tests passed. Heavy profile-grid tests were skipped unless
`GLLVMTMB_HEAVY_TESTS=1` is set; the new pure message regression ran.

## Claim Boundary

This is user-message hardening only. It does not change profile likelihood
math, interval routing, or communality support.

## Rose Verdict

OK. The user now sees the no-Psi fix hint; no capability claim should change.
