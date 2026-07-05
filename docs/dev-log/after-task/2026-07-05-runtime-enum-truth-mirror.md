# Runtime Enum Truth Mirror

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`

## Goal

Close issue #676 locally by removing the stale sdmTMB / single-response enum
hazard from `R/enum.R`. The internal table now mirrors the multivariate runtime
encoding used by `family_to_id()` in `R/fit-multi.R` and by the C++ switch
comments.

## Changes

- Replaced the generated-enum comment with an explicit runtime-mirror warning.
- Updated `.valid_family` to the live ids: gaussian 0, binomial 1, poisson 2,
  lognormal 3, Gamma 4, nbinom2 5, tweedie 6, Beta 7, betabinomial 8, student
  9, truncated_poisson 10, truncated_nbinom2 11, delta_lognormal 12,
  delta_gamma 13, ordinal_probit 14, and nbinom1 15.
- Reduced `.valid_link` to binomial runtime link ids only: logit 0, probit 1,
  and cloglog 2.
- Added `test-enum-runtime-ids.R` to guard the mirror and block stale unsupported
  ids (`gamma_mix`, `lognormal_mix`, `nbinom2_mix`, `gengamma`,
  `censored_poisson`, `truncated_nbinom1`).
- Updated `FAM-07` in the validation-debt register to replace the stale
  maintenance note with the repaired evidence.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/enum.R")); invisible(parse("tests/testthat/test-enum-runtime-ids.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-enum-runtime-ids.R")'
rg -n "Enum mirror repaired|test-enum-runtime-ids|sdmTMB:::make_enum" docs/design/35-validation-debt-register.md R/enum.R tests/testthat/test-enum-runtime-ids.R
```

Result:

- Parse check: `parse-ok`.
- Focused enum test: 3 pass, 0 fail, 0 warn, 0 skip.
- Stale-warning audit found the repaired register note and test reference only.

## Claim Boundary

This does not promote any response family, interval route, or structural
dependency route. It only prevents an internal diagnostic object from
contradicting the live engine encoding.

## Rose Verdict

OK for a local truth-lock commit. No source-specific `lv`, mixed-family CI,
profile/bootstrap calibration, or non-Gaussian support claim changed.
