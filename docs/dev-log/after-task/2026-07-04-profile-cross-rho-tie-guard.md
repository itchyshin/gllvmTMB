# After-Task Report: profile_cross_rho Tie Guard

Date: 2026-07-04 23:25 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #643

## Goal

Keep `profile_cross_rho()` outputs scalar and deterministic when two or more
rho values produce tied log likelihoods.

## Files Changed

- `R/kernel-helpers.R`
- `man/profile_cross_rho.Rd`
- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-profile-cross-rho-tie-guard.md`

## What Changed

- Best-row selection now uses the first maximum among finite log likelihoods.
- `is_best` marks exactly one row under ties.
- `attr(out, "best_rho")` remains length one.
- The exported help text now states the first-maximum tie rule.
- Added a fast tie regression using a rho-insensitive `lm()` refit.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/kernel-helpers.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-two-kernel.R", reporter = "summary", desc = "profile_cross_rho resolves tied logLik best rho to a scalar first maximum")'
```

Result: targeted tie regression passed.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE); cat("document-ok\n")'
```

Result: roxygen documentation regenerated.

## Rose Verdict

OK as a deterministic contract repair for fixed-rho sensitivity profiles. This
does not promote in-engine rho estimation, rho intervals, or coevolution
calibration.

## Next

Continue with non-Gaussian summary semantics, especially VP residual accounting
(#615), or choose another small inference robustness issue after a fresh status
check.
