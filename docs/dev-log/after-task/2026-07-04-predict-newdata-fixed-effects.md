# predict(newdata) fixed-effect column alignment

## Goal

Close issue #645 by preventing `predict.gllvmTMB_multi(newdata = ...)` from
silently pairing fixed-effect columns with coefficients by position when factor
levels in `newdata` differ from the training data.

## Changes

- Added a helper to restore training factor levels for factor columns in
  `newdata`, fail loudly on unseen fixed-effect factor levels, and preserve the
  documented population-mean path for unseen unit/species grouping levels.
- Added a helper to align `X_new` columns to named fitted fixed-effect
  coefficients via `fit$X_fix_names`.
- Replaced the positional `bfix[seq_len(ncol(X_new))]` prediction path.
- Added a pure regression using a fake fit with a `trait:habitat` fixed-effect
  design where `newdata` contains only non-baseline habitat levels, including a
  new-site row that should remain allowed.
- Updated validation-debt row MIS-07.

## Validation

Focused validation passed:

```sh
Rscript --vanilla -e 'invisible(parse("R/methods-gllvmTMB.R")); invisible(parse("tests/testthat/test-tidy-predict.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-tidy-predict.R", reporter = "summary")'
```

The focused test file passed with three expected CRAN skips.

## Claim Boundary

This repairs fixed-effect point prediction for `newdata`. It does not add
prediction intervals, `newdata` simulation, unconditional random-effect redraws,
or new family support.
