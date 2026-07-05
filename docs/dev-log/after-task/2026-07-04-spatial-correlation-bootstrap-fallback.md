# After Task: Spatial Correlation Bootstrap Fallback

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Fisher / Grace / Rose / Shannon`

## 1. Goal

Continue the derived-CI route matrix audit without losing the forest view. The
specific route bug was `extract_correlations(tier = "spatial", method =
"bootstrap")`: `bootstrap_Sigma()` does not yet resample SPDE spatial tiers,
but the extractor's fallback branch only emitted a message and could return an
empty result.

## 2. Implemented

- Factored the Fisher-z/Wald correlation row construction into internal helpers.
- Routed unsupported spatial bootstrap requests through the same helper, with
  `method = "wald"` rows and an explicit fallback message.
- Removed the older fixed-effect-only `confint.gllvmTMB_multi()` stub from
  `R/methods-gllvmTMB.R`; the real route-matrix method in
  `R/z-confint-gllvmTMB.R` is now the only definition and the help page is no
  longer a merged chimera.
- Updated `confint()` dispatcher wording, `extract_correlations()` help,
  extractor contract docs, and validation-debt rows.
- Cleaned two stale test comments found by the read-only audit.

## 3. Files Changed

- `R/extract-correlations.R`
- `R/methods-gllvmTMB.R`
- `R/z-confint-gllvmTMB.R`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `man/confint.gllvmTMB_multi.Rd`
- `man/extract_correlations.Rd`
- `tests/testthat/test-spatial-depindep-binary.R`
- `tests/testthat/test-profile-proportions.R`
- `tests/testthat/test-communality-ci.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-spatial-correlation-bootstrap-fallback.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep the public function set. The forest-level audit did not find a
reason to delete derived-summary helpers; the real redundancy was the shadowed
old `confint.gllvmTMB_multi()` definition and repeated Fisher-z row code.

Rejected alternative: claim spatial bootstrap support.

Reason rejected: no SPDE bootstrap route exists in `bootstrap_Sigma()` yet.
The fix is an explicit Wald/Fisher-z fallback, not new bootstrap calibration.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/methods-gllvmTMB.R")); invisible(parse("R/extract-correlations.R")); invisible(parse("R/z-confint-gllvmTMB.R")); cat("parse-ok\n")'
```

Outcome: passed.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Outcome: passed; regenerated `man/extract_correlations.Rd` and
`man/confint.gllvmTMB_multi.Rd`. It emitted the same unrelated unresolved-link
warnings seen earlier for mixed-family fixtures, `parse_multi_formula`, and
`0, 1` links.

```sh
Rscript --vanilla -e 'tools::checkRd("man/extract_correlations.Rd"); tools::checkRd("man/confint.gllvmTMB_multi.Rd"); cat("rd-ok\n")'
```

Outcome: passed.

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-fisher-z-correlations.R", reporter = "summary")'
```

Outcome: passed; `fisher-z-correlations: ................`.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-spatial-depindep-binary.R", reporter = "summary")'
```

First run outcome: failed the new assertion because `expect_message()` returned
the captured message condition when assigned directly.

Fix: assign `cor_boot` inside `expect_message()`.

Second run outcome: passed; `spatial-depindep-binary: ...........................`.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-proportions.R", reporter = "summary")'
```

Outcome: passed; `profile-proportions: ........................................`.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R", reporter = "summary")'
```

Outcome: passed; `confint-derived` completed with no failures.

```sh
rg -n "Two parameter-class dispatch paths|Two parm-class dispatch paths|Profile-only|wald / bootstrap error early|outside the supported set|T x T.*attribute.*confint|from the bootstrap distribution|Fixed-effect confidence intervals|proportion.*omit|spatial bootstrap.*covered|elsewhere --" R/z-confint-gllvmTMB.R R/extract-correlations.R tests/testthat/test-profile-proportions.R tests/testthat/test-communality-ci.R docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md man/confint.gllvmTMB_multi.Rd man/extract_correlations.Rd
```

Outcome: no stale hits.

```sh
git diff --check
```

Outcome: passed.

## 5. Tests of the Tests

The new spatial assertion uses the existing SPDE binary fixture and checks the
public extractor route end to end. It verifies non-empty rows, `method =
"wald"`, finite point correlations, and bounded finite interval rows.

## 6. Consistency Audit

The source, help, extractor contract, validation-debt register, and tests now
say the same thing: SPDE bootstrap is not supported, but the user receives an
explicit Wald fallback rather than an empty frame or a mislabeled bootstrap
claim.

## 7. Roadmap Tick

Derived-CI route matrix: `rho` / spatial bootstrap fallback row is truth-locked.
No interval calibration status changed.

## 7a. GitHub Issue Ledger

No issue was closed or commented. This is adjacent to issue #670
(`bootstrap_Sigma()` tier batching) but does not resolve it.

## 8. What Did Not Go Smoothly

The first spatial test failed because of a test harness assignment pattern with
`expect_message()`. That was fixed without touching implementation logic.

## 9. Team Learning

Rose's "forest and trees" audit found a shadowed `confint()` method definition.
Removing it was a better consolidation than adding another doc patch over a
duplicated method.

## 10. Known Limitations And Next Actions

- SPDE bootstrap calibration remains unimplemented.
- Profile correlation for spatial total covariance remains partial pending a
  heavier constrained-refit gate.
- Broader interval calibration still belongs to the M3 / Totoro / DRAC
  campaign, not this focused route repair.
