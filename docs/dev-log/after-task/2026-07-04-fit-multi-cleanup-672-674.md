# Fit-multi cleanup issues #672, #673, #674

## Goal

Close three confirmed `R/fit-multi.R` cleanup issues without changing the fitted
model contract.

## Changes

- Removed the unused `has_int` assignment and stale intercept-stripping comment.
- Removed a dead SPDE `A_proj` sparse allocation that was overwritten
  immediately by `mesh$A_st`.
- Removed the redundant second `log_phi` regex pass in
  `.gllvmTMB_reclamp_start_par()`.
- Added a pure regression for the reclamp helper covering top-level, dotted,
  and non-phi parameter names.

## Validation

Focused validation passed:

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-m3-4-warmstart-phi-clamp.R", reporter = "summary")'
```

The heavy recovery rows in the test file were intentionally skipped because
`GLLVMTMB_HEAVY_TESTS` was not set; the new pure helper regression ran and
passed.

## Claim Boundary

This is an internal cleanup slice. It does not move a validation-debt row, alter
formula grammar, change likelihood parameterization, or promote any new
inference/capability claim.
