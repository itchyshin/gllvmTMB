# After-Task Report: Lambda Profile Return-Contract Repair

Date: 2026-07-04 21:01 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issues: #605, #695

## Goal

Repair two Lambda profile return-contract problems without widening the
inference claim:

- full-grid `confint(parm = "Lambda", method = "profile")` must keep one
  `ci_status` vector column, not matrix-split `ci_status.*` columns;
- explicit pinned entries such as `Lambda:1,2` must return the known pinned
  point with `ci_status = "pinned"`, matching the Wald/full-grid convention.

## Files Changed

- `R/z-confint-gllvmTMB.R`
- `tests/testthat/test-confint-lambda.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-lambda-profile-return-contract.md`

## What Changed

- Added `.lambda_pinned_matrix()` as the shared pinning convention for Lambda
  profile output.
- Flattened full-grid `ci_status` before constructing the data frame.
- Initialised selected-entry profile output from the point estimate and pinned
  status, then overwrote only entries that have real profile bounds.
- Added pure mocked tests for the return shape and explicit pinned-entry path.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-lambda.R", reporter = "summary")'
```

Result: pure Lambda contract tests passed; existing heavy tests skipped unless
`GLLVMTMB_HEAVY_TESTS=1`.

## Rose Verdict

OK as a return-contract repair. This does not add new interval calibration,
new Lambda profiling surfaces, or source-specific LV support.

## Next

Next inference-safety candidates are Gamma/profile curve stability (#679) or
the correlation-plot interval metadata cleanup (#702). Keep them separate.
