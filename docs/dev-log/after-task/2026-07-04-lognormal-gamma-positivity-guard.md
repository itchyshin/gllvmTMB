# After-Task Report: Lognormal/Gamma Positivity Guard

Date: 2026-07-04 21:24 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #659

## Goal

Fail loudly before TMB evaluation when observed lognormal or Gamma responses
contain zero or negative values.

## Files Changed

- `R/fit-multi.R`
- `tests/testthat/test-family-lognormal.R`
- `tests/testthat/test-family-gamma.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-lognormal-gamma-positivity-guard.md`

## What Changed

- Added a shared observed-response positivity guard for `lognormal()` and
  `Gamma(link = "log")` rows.
- Kept masked missing-response sentinel rows exempt by using the existing
  `!masked_response` convention in the family range-check block.
- Tightened the lognormal regression to expect the explicit strict-positivity
  message.
- Added a Gamma regression for non-positive observed responses.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-family-lognormal.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-family-gamma.R", reporter = "summary")'
```

Result: lognormal and Gamma family tests passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-missing-response-gaussian.R", reporter = "summary")'
```

Result: heavy missing-response sentinel tests passed.

## Rose Verdict

OK as an input-domain guard. This does not change Gamma/lognormal recovery
status, interval coverage, or missing-data claims.

## Next

Continue the correctness lane with duplicate long-row guards (#642) or another
small robustness issue before returning to broader release checks.
