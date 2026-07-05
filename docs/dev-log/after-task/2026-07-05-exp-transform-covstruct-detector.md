# After Task: exp transform covstruct detector

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: Ada / Boole / Curie / Grace / Rose / Shannon

## 1. Goal

Fix issue #590 locally: `exp(env)` in a fixed-effect expression should not be
misread as an unsupported glmmTMB-style covariance structure.

## 2. Implemented

- Updated `detect_covstruct_terms()` so reserved spatial covariance names
  (`exp`, `gau`, `ar1`, `ou`, `cs`, `toep`, `us`) are reported only when the
  call contains a bar expression.
- Preserved fail-loud handling for bar-style reserved covariance syntax such as
  `exp(0 + trait | site)`.
- Added an argument-level regression that fits a public `gllvmTMB()` formula
  with `(0 + trait):exp(env_temp)` and an ordinary `latent()` term.

## 3. Files Changed

- `R/gllvmTMB.R`
- `tests/testthat/test-gllvmTMB-args.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-exp-transform-covstruct-detector.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep reserved covariance-name detection for bar-style calls, but stop
flagging ordinary nested function transforms. Rejected alternative: remove
`exp/gau/ar1/ou/cs/toep/us` from detection entirely, which would make unsupported
covariance syntax fail later with a less helpful message. Confidence: high for
formula parsing; no likelihood path changed.

## 4. Checks Run

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); print(gllvmTMB:::detect_covstruct_terms(value ~ 0 + trait + (0 + trait):exp(env))); print(gllvmTMB:::detect_covstruct_terms(value ~ 0 + trait + us(0 + trait | site)))'
```
Outcome before the fix: fixed-effect `exp(env)` returned `"exp"`; unsupported
`us(0 + trait | site)` returned `"us"`.

```sh
Rscript --vanilla -e 'invisible(parse("R/gllvmTMB.R")); invisible(parse("tests/testthat/test-gllvmTMB-args.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); print(gllvmTMB:::detect_covstruct_terms(value ~ 0 + trait + (0 + trait):exp(env) + rr(0 + trait | site, d = 1))); print(gllvmTMB:::detect_covstruct_terms(value ~ 0 + trait + exp(0 + trait | site)))'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-gllvmTMB-args.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-canonical-keywords.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-formula-grammar-smoke.R", reporter = "summary")'
```
Outcome: parse passed; detector no longer reports `"exp"` for fixed-effect
transforms and still reports `"exp"` for bar-style covariance syntax;
`test-gllvmTMB-args.R` passed with four existing no-covstruct skips;
`test-canonical-keywords.R` passed with three existing INLA skips;
`test-formula-grammar-smoke.R` passed.

## 5. Tests of the Tests

The new test covers both the internal detector and the public fitting path. It
also keeps the unsupported reserved-covariance spelling alive as an error so the
fix does not silently widen glmmTMB-style covariance syntax.

## 6. Consistency Audit

```sh
rg -n "detect_covstruct_terms|cov_names|unsupported.*cov|Found .* formula|not yet supported|\\bexp\\b|\\bgau\\b|\\bar1\\b|\\bou\\b|\\btoep\\b|\\bus\\b" R/gllvmTMB.R R/parse-multi-formula.R R/brms-sugar.R R/parsing.R tests/testthat/test-gllvmTMB-args.R tests/testthat/test-canonical-keywords.R
```
Verdict: the only detector logic changed is the reserved bar-covstruct guard;
existing unsupported covariance messages and tests remain.

## 7. Roadmap Tick

N/A. This is a parser false-positive repair, not a roadmap promotion.

## 7a. GitHub Issue Ledger

- Inspected issue #590:
  https://github.com/itchyshin/gllvmTMB/issues/590
- Issue #590 remains open upstream because this local fix has not been pushed or
  included in a PR.

## 8. What Did Not Go Smoothly

The first detector assertion used raw `latent()`, but `detect_covstruct_terms()`
runs after `latent()` is desugared. The test was corrected to use internal
`rr()` for the detector check while keeping the public `gllvmTMB()` fit on
`latent()`.

## 9. Team Learning

Ada kept this as a parser-only slice after the sparse-prior fixes.

Boole clarified the grammar boundary: `exp(x)` is fixed-effect syntax, while
`exp(... | group)` remains reserved covariance syntax.

Curie added both detector-level and public-fit regression evidence.

Grace verified parser tests, canonical keyword tests, and formula smoke tests.

Rose kept the claim narrow: no reserved spatial covariance implementation or
new model capability follows from this fix.

Shannon ran open-PR and recent-log lane checks before shared docs edits.

## 10. Known Limitations And Next Actions

This does not implement `exp`, `gau`, `ar1`, `ou`, `cs`, `toep`, or `us`
covariance structures. They remain reserved / unsupported. Continue the local
issue-burn-down queue and refresh the completion matrix once the small parser
and correctness tickets are exhausted.
