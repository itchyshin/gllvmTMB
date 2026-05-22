# After-Task Report: Fit-Object Reference Wording Sweep

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned reference/helper wording so users are directed to a fit returned by
`gllvmTMB()` instead of being asked to know the internal `gllvmTMB_multi` class.

This is a public-interface wording and error-message cleanup. It does not
change model fitting, likelihoods, formula grammar, covariance calculations, or
plot data.

## Files Touched

- `R/bootstrap-sigma.R`
- `R/check-auto-residual.R`
- `R/check-consistency.R`
- `R/check-identifiability.R`
- `R/confint-inspect.R`
- `R/coverage-study.R`
- `R/diagnose.R`
- `R/extract-cutpoints.R`
- `R/extract-sigma.R`
- `R/extract-two-psi-cross-check.R`
- `R/gllvmTMB-wide.R`
- `R/plot-covariance-tables.R`
- `R/profile-ci.R`
- `R/profile-targets.R`
- `man/check_auto_residual.Rd`
- `man/compare_dep_vs_two_psi.Rd`
- `man/compare_indep_vs_two_psi.Rd`
- `man/extract_cutpoints.Rd`
- `man/gllvmTMB_wide.Rd`
- `man/plot_Sigma_comparison.Rd`
- `man/tmbprofile_wrapper.Rd`
- `tests/testthat/test-check-auto-residual.R`
- `tests/testthat/test-check-consistency.R`
- `tests/testthat/test-check-identifiability.R`
- `tests/testthat/test-confint-inspect.R`
- `tests/testthat/test-coverage-study.R`
- `tests/testthat/test-gllvmTMB-diagnose.R`
- `tests/testthat/test-profile-targets.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-fit-object-reference-wording.md`

## What Changed

- Roxygen argument/return text for the touched helpers now says "fit returned
  by `gllvmTMB()`" or "fitted gllvmTMB model."
- Wrong-object errors in diagnostics, profile, bootstrap, consistency,
  coverage, cutpoint, and two-psi helper paths now use the same public wording.
- Tests for non-fit inputs now assert the public-facing error message.

## Validation

- `air format R/check-auto-residual.R R/bootstrap-sigma.R R/extract-cutpoints.R R/gllvmTMB-wide.R R/plot-covariance-tables.R R/profile-ci.R R/diagnose.R R/check-consistency.R R/confint-inspect.R R/check-identifiability.R R/profile-targets.R R/coverage-study.R R/extract-two-psi-cross-check.R R/extract-sigma.R`
  -> completed without output.
- `air format tests/testthat/test-confint-inspect.R tests/testthat/test-check-consistency.R tests/testthat/test-coverage-study.R tests/testthat/test-gllvmTMB-diagnose.R tests/testthat/test-profile-targets.R tests/testthat/test-check-auto-residual.R tests/testthat/test-check-identifiability.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/check_auto_residual.Rd`, `man/extract_cutpoints.Rd`,
  `man/gllvmTMB_wide.Rd`, `man/plot_Sigma_comparison.Rd`,
  `man/tmbprofile_wrapper.Rd`, `man/compare_dep_vs_two_psi.Rd`, and
  `man/compare_indep_vs_two_psi.Rd`.
- First focused run:
  `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMB-diagnose|confint-inspect|bootstrap-Sigma|plot-covariance-tables|coverage-study|profile-ci|check-auto-residual|check-identifiability|check-consistency|profile-targets|wide-weights-matrix|gllvmTMB-wide|ordinal-probit", stop_on_failure = TRUE)'`
  -> 448 passes, 7 failures, 0 warnings. Failures were stale test assertions
  still expecting old `gllvmTMB_multi` error text.
- Final focused run:
  `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMB-diagnose|confint-inspect|bootstrap-Sigma|plot-covariance-tables|coverage-study|profile-ci|check-auto-residual|check-identifiability|check-consistency|profile-targets|wide-weights-matrix|gllvmTMB-wide|ordinal-probit", stop_on_failure = TRUE)'`
  -> 455 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Rd spot-check:
  `tail -5 man/check_auto_residual.Rd man/extract_cutpoints.Rd man/gllvmTMB_wide.Rd man/plot_Sigma_comparison.Rd man/tmbprofile_wrapper.Rd man/compare_dep_vs_two_psi.Rd man/compare_indep_vs_two_psi.Rd; grep -Hc '^\\keyword' man/check_auto_residual.Rd man/extract_cutpoints.Rd man/gllvmTMB_wide.Rd man/plot_Sigma_comparison.Rd man/tmbprofile_wrapper.Rd man/compare_dep_vs_two_psi.Rd man/compare_indep_vs_two_psi.Rd`
  -> normal endings; `gllvmTMB_wide` and `tmbprofile_wrapper` keep expected
  `internal` keywords.
- Stale wording scan:

  ```sh
  rg -n 'A `gllvmTMB_multi` fit|A `gllvmTMB_multi` object|A \\code\{gllvmTMB_multi\} fit|A \\code\{gllvmTMB_multi\} object|gllvmTMB_multi model|fitted gllvmTMB_multi model|requires a gllvmTMB_multi|Provide a \{\.cls gllvmTMB_multi\} fit|Plot a fitted multivariate `gllvmTMB_multi`|Tidy a `gllvmTMB_multi`|Predict from a `gllvmTMB_multi`|Simulate new responses from a fitted `gllvmTMB_multi`|Confidence intervals on fixed effects of a `gllvmTMB_multi`|attached plot data' R man tests/testthat/test-confint-inspect.R tests/testthat/test-check-consistency.R tests/testthat/test-coverage-study.R tests/testthat/test-gllvmTMB-diagnose.R tests/testthat/test-profile-targets.R tests/testthat/test-check-auto-residual.R tests/testthat/test-check-identifiability.R
  ```

  -> no hits.

## Definition-of-Done Notes

- Implementation: public wording and error-message cleanup only; local branch,
  not merged or pushed.
- Simulation recovery test: not applicable.
- Documentation: roxygen source and generated Rd agree for touched topics.
- Runnable user-facing example: unchanged.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose user-path wording; Grace pkgdown and focused tests.

## Residuals

- Full `devtools::test()` and `devtools::check()` were not rerun for this
  wording/error-text cleanup.
- No 3-OS CI is available until the branch is pushed.
