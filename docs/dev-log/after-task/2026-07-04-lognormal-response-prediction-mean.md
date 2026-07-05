# After-Task Report: Lognormal Response Prediction Mean

Date: 2026-07-04 23:58 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #614

## Goal

Make `predict(..., type = "response")` return the conditional response mean for
lognormal traits rather than the median.

## Files Changed

- `R/methods-gllvmTMB.R`
- `tests/testthat/test-missing-data-robustfix.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-lognormal-response-prediction-mean.md`

## What Changed

- `.apply_linkinv_per_row()` now accepts `sigma_eps`.
- Family id 3 uses `exp(eta + sigma_eps^2 / 2)` on the response scale.
- Other log-link families keep `exp(eta)`.
- `predict.gllvmTMB_multi()` passes the fitted `object$report$sigma_eps` into
  the per-row inverse-link helper for training-row and `newdata` predictions.
- Added a pure regression showing lognormal differs from Poisson under the same
  `eta` vector.

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

OK as a response-scale point-prediction correction for the ordinary lognormal
family. This does not add delta-lognormal prediction semantics, prediction
intervals, or uncertainty calibration.

## Next

Continue with bounded prediction/family correctness, especially modal
family/link selection for `newdata` predictions (#678), before considering
larger Gamma dispersion decoupling (#622).
