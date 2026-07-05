# After-Task Report: Extractor Zero-Boundary Guards

Date: 2026-07-04 22:10 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issues: #681, #682, #683

## Goal

Make report extractors behave locally and honestly when fitted covariance
components contain zero-variance rows, instead of converting one degenerate
trait into a whole-matrix `NA` result or leaking `NaN` into variance-share and
ICC summaries.

## Files Changed

- `R/extract-sigma.R`
- `R/extract-omega.R`
- `R/extractors.R`
- `tests/testthat/test-extractors-extra.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-extractor-zero-boundary-guards.md`

## What Changed

- Added `.safe_cov2cor()` and reused it for `extract_Sigma()` and
  `extract_Omega()` correlation construction.
- Preserved finite correlations for the positive-variance submatrix while
  returning `NA` only for zero-variance rows and columns.
- Added `.safe_variance_proportion_matrix()` so zero total variance in
  `extract_proportions()` produces `NA`, not `NaN`.
- Added `.safe_icc_ratio()` for the same zero-denominator boundary in
  `extract_ICC_site()`.
- Recorded the boundary evidence in EXT-01, EXT-03, EXT-12, and EXT-31.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/extract-sigma.R")); invisible(parse("R/extract-omega.R")); invisible(parse("R/extractors.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-extractors-extra.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-extractors.R", reporter = "summary")'
```

Result: pure boundary and base extractor tests passed.

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-mixed-response-sigma.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-proportions-ci.R", reporter = "summary")'
```

Result: NOT_CRAN mixed-response Sigma tests and heavy proportions CI tests
passed. `test-mixed-response-sigma.R` still emits the existing
`level = "B"` deprecation warning.

## Rose Verdict

OK as a narrow extractor boundary repair. This does not promote delta/hurdle
`extract_proportions()`, new interval support, source-specific `lv`, or
calibration claims.

## Next

Continue the gllvmTMB completion arc with the next high-value local correctness
slice. Issue #642 remains parked unless the R-Julia bridge lane is explicitly
reopened, because the live failure is in `.gllvmTMB_julia_dispatch()`.
