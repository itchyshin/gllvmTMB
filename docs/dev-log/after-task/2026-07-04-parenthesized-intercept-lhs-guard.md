# Parenthesized Intercept LHS Guard

Date: 2026-07-04

Goal: close issue #626 by preventing harmless parentheses around
intercept-only LHS terms from triggering the augmented-LHS fail-loud guard.

Files changed:

- `R/brms-sugar.R`
- `tests/testthat/test-augmented-lhs-guard.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`

What changed:

- `.assert_no_augmented_lhs()` now strips enclosing LHS parentheses before
  checking for the accepted intercept-only shapes.
- Added a focused parser regression for `indep((0 + trait) | site)` and
  `latent((0 + trait) | site, d = 1)`.
- Recorded the evidence in RE-12 without changing its `partial` status.

Validation:

```sh
Rscript --vanilla -e 'invisible(parse("R/brms-sugar.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-augmented-lhs-guard.R", reporter = "summary")'
```

Result: parse passed; focused augmented-LHS guard tests passed with expected
CRAN-mode skips for heavier fit rows.

Claim boundary:

- This is parser no-regression hardening only.
- No source-specific `lv = ~ env` route, non-Gaussian augmented-Psi support, or
  new random-slope capability is claimed.

Rose verdict: OK for local hardening commit.
