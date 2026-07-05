# After-Task Report: predict newdata Modal Family/Link IDs

Date: 2026-07-04 24:08 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #678

## Goal

Prevent `predict(..., newdata = ..., type = "response")` from constructing
impossible family/link ids by taking numeric medians of categorical ids.

## Files Changed

- `R/methods-gllvmTMB.R`
- `tests/testthat/test-missing-data-robustfix.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-predict-newdata-modal-family-link.md`

## What Changed

- Added `.modal_integer_id()`.
- The `newdata` branch in `predict.gllvmTMB_multi()` now maps each trait to
  the modal training family/link id.
- Ties are deterministic: first modal id in the observed order wins.
- Added pure coverage for the former `median(c(2, 4)) -> 3` failure.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/methods-gllvmTMB.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-missing-data-robustfix.R", reporter = "summary")'
```

Result: normal missing-data robustness tests passed; heavy-only tests skipped as
expected.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-missing-data-robustfix.R", reporter = "summary", desc = "BUG-2 predict(type='response') uses per-row inverse link (mixed family)")'
```

Result: targeted heavy mixed-family response-prediction test passed.

## Rose Verdict

OK as a point-prediction dispatch repair. This does not promote family-aware
`newdata` simulation, prediction intervals, or new response-family support.

## Next

The next adjacent issue is larger: Gamma dispersion decoupling (#622) touches
likelihood parameterisation and should be planned as a separate TMB slice, not
a quick cleanup.
