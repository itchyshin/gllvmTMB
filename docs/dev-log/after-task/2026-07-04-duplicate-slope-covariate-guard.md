# Duplicate Slope Covariate Guard

Date: 2026-07-04

Goal: close issue #625 by rejecting repeated augmented-LHS slope covariates
before they can create duplicated design columns in the multi-slope
`phylo_dep()` path.

Files changed:

- `R/brms-sugar.R`
- `tests/testthat/test-phylo-dep-slope-s2-gaussian.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`

What changed:

- Added a shared distinct-slope assertion for augmented LHS slope classifiers.
- Applied it to both wide and long multi-slope classifier helpers.
- Added parser-only regressions for duplicate wide and long `phylo_dep()`
  slope syntax.
- Recorded the guard under RE-03 while preserving its `partial` status.

Validation:

```sh
Rscript --vanilla -e 'invisible(parse("R/brms-sugar.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-phylo-dep-slope-s2-gaussian.R", reporter = "summary")'
```

Result: parse passed; focused parser assertions passed and heavy recovery rows
skipped as expected under normal local mode.

Claim boundary:

- This is malformed-input and rank-deficiency prevention only.
- No non-Gaussian s >= 2 promotion, source-specific `lv = ~ env` exposure, or
  new interval claim is made.

Rose verdict: OK for local hardening commit.
