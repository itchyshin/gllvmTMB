# After Task: Extract Communality Wald Route

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Fisher / Curie / Grace / Rose / Shannon`

## 1. Goal

Close the next small row in the derived-CI route matrix: make
`extract_communality(ci = TRUE, method = "wald")` use the same scalar
delta-method Wald helper already used by `confint(..., parm =
"communality:...", method = "wald")`, instead of printing the old
"not implemented" message and falling back to bootstrap.

## 2. Implemented

- `.communality_wald_ci()` now accepts `link_residual = "auto"` or `"none"`.
- `extract_communality(ci = TRUE, method = "wald")` now returns Wald rows
  directly, one row per trait.
- The extractor passes canonical tier names into the helper so internal `B` /
  `W` storage does not leak as a deprecation warning.
- `test-communality-ci.R` now verifies that the extractor Wald route uses
  method `"wald"` and matches `.communality_wald_ci()` for a selected trait.
- EXT-05 records the route evidence.

## 3. Files Changed

- `R/communality-ci.R`
- `R/extractors.R`
- `tests/testthat/test-communality-ci.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-extract-communality-wald-route.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep this as route consistency, not a new calibration claim.

Rejected alternative: keep falling back to bootstrap from the extractor.

Reason rejected: the scalar Wald helper already exists and is the route used by
`confint()`, so the extractor fallback message had become stale and misleading.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/communality-ci.R")); invisible(parse("R/extractors.R")); invisible(parse("tests/testthat/test-communality-ci.R")); cat("parse-ok\n")'
```

Outcome: passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-communality-ci.R", reporter = "summary")'
```

Outcome: passed after one warning-cleanup patch.

## 5. Tests of the Tests

The new assertion compares the public extractor output against
`.communality_wald_ci()` on the same fitted object, trait, confidence level, and
`link_residual = "none"` setting. The first run failed because the test was too
strict about expected binomial link-residual messages and because the extractor
passed internal `B` into the helper; the second run passed after the route was
made warning-clean.

## 6. Consistency Audit

The change removes one stale fallback message. It does not change profile-LR,
bootstrap, or coverage-calibration claims.

## 7. Roadmap Tick

Phase 1 derived-CI route matrix: one extractor/communality row is now covered.

## 7a. GitHub Issue Ledger

No GitHub issue was closed or commented in this slice.

## 8. What Did Not Go Smoothly

The initial no-message assertion ignored the expected binomial link-residual
message. The test now requests `link_residual = "none"` when checking that the
old bootstrap-fallback message is gone.

## 9. Team Learning

Fisher kept this as a routing consistency fix. Curie made the public extractor
path compare directly to the scalar helper. Rose kept CI calibration claims
unchanged.

## 10. Known Limitations And Next Actions

- CI-08 / CI-10 calibration rows remain unchanged.
- Continue the route matrix with `icc`, `rho`, `proportion`, spatial
  total-covariance profile behavior, and explicit unavailable statuses for
  non-Gaussian or mixed-family surfaces that are not directly supported.
