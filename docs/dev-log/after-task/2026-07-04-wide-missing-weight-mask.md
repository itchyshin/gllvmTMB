# After-Task Report: Wide Missing-Response Weight-Mask Repair

Date: 2026-07-04 21:21 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #589

## Goal

Allow `gllvmTMB_wide()` to keep missing-response cells under
`missing = miss_control(response = "include")` while still accepting per-cell
weight matrices whose `NA`s are aligned with the missing response cells.

## Files Changed

- `R/weights-shape.R`
- `R/gllvmTMB-wide.R`
- `tests/testthat/test-weights-unified.R`
- `tests/testthat/test-missing-data-robustfix.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-wide-missing-weight-mask.md`

## What Changed

- Added an internal `drop_masked` option to `normalise_weights()`.
- Kept the previous default, where masked cells are removed from the weight
  vector.
- Passed the response NA mask from `gllvmTMB_wide()` in both drop and include
  modes.
- In include mode, retained masked cells keep full row identity and masked-cell
  weights are converted to finite zero sentinels before TMB sees them.
- Added a pure normalizer regression and a heavy `gllvmTMB_wide()` fit-level
  regression for NA-aligned per-cell weights.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/weights-shape.R")); invisible(parse("R/gllvmTMB-wide.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-weights-unified.R", reporter = "summary")'
```

Result: pure weight-shape tests passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-missing-data-robustfix.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-wide-weights-matrix.R", reporter = "summary")'
```

Result: heavy missing-data robustfix tests and wide-weight matrix tests passed.

## Rose Verdict

OK as a narrow response-missing/per-cell-weight correctness repair. This does
not promote broader missing-predictor support, missing-data calibration, or
weighted REML support.

## Next

Continue the missing/mixed correctness lane. Adjacent high-value candidates are
duplicate long-row guards (#642) and non-Gaussian positivity guards (#659).
