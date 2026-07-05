# After-Task Report: Beta-Binomial Weights-As-Trials Guard

Date: 2026-07-05

## Goal

Close issue #634 by making single-column `betabinomial()` rows treat
`weights = n_trials` as trial counts, the same way binomial rows do.

## What Changed

- `R/fit-multi.R`
  - The weights-as-trials branch now activates for family ids `1` and `8`
    (`binomial` and `betabinomial`).
  - `weights_i` is reset to `1` for both binomial and beta-binomial rows after
    weights are absorbed into `n_trials`, preventing double application as a
    likelihood multiplier.
- `tests/testthat/test-lme4-style-weights.R`
  - Added a focused beta-binomial regression proving `n_trials` receives the
    supplied weights and `weights_i` is all ones.
- `docs/design/35-validation-debt-register.md`
  - Updated `FAM-05` to record the weights-as-trials contract guard.
- `docs/dev-log/check-log.md`
  - Added command/results evidence for this slice.

## Tests

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); invisible(parse("tests/testthat/test-lme4-style-weights.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-lme4-style-weights.R", desc = "Beta-binomial: weights = n_trials is not double-applied")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-lme4-style-weights.R")'
```

Results:

- Parse check: `parse-ok`.
- Focused beta-binomial regression: 3 pass, 0 fail, 0 skip.
- Full `test-lme4-style-weights.R`: 17 pass, 0 fail, 2 expected CRAN skips.

## Rose Verdict

OK as a narrow likelihood-contract guard. This does not promote new
beta-binomial recovery, profile, bootstrap, or interval-calibration claims.

## Not Done

- No broad `devtools::test()` or `devtools::check()`.
- No profile/bootstrap calibration.
- No Totoro or DRAC compute.
- No public issue closure until the local branch is pushed/merged.

## Next

Continue the Ultra-Plan with the next live non-Gaussian / missing-mixed
correctness gap, after separating already-fixed local issue debt from genuinely
live code debt.
