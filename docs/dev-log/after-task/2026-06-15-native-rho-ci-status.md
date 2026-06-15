# After Task: Native Rho CI-Status Semantics

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Fisher / Rose / Hopper`

## 1. Goal

Make native R/TMB rho interval status explicit before admitting any broader
mixed-family Julia CI endpoint work. In particular, a boundary-partial profile
interval such as `[NA, 0.999]` should not require users or downstream tests to
infer the failure mode from an `NA` endpoint.

## 2. Implemented

- `extract_correlations()` now returns a `ci_status` column.
- `confint(fit, parm = "rho:<tier>:i,j")` now attaches a row-named
  `ci_status` attribute to the returned two-column matrix.
- `profile_boundary` marks a one-sided finite profile interval.
- `profile_failed`, `bootstrap_failed`, `wald_unavailable`, and
  `fisher_z_unavailable` mark method-specific unavailable intervals.
- The public `confint()` matrix shape is unchanged.

## 3. Files Changed

R code:

- `R/extract-correlations.R`
- `R/z-confint-gllvmTMB.R`

Tests:

- `tests/testthat/test-fisher-z-correlations.R`
- `tests/testthat/test-m1-4-extract-correlations-mixed-family.R`
- `tests/testthat/test-profile-ci.R`

Docs and ledger:

- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-native-rho-ci-status.md`
- `man/extract_correlations.Rd`
- `man/confint.gllvmTMB_multi.Rd`

## 3a. Decisions and Rejected Alternatives

Decision: keep `confint()` as a numeric matrix and expose statuses as an
attribute.

Rationale: this preserves base-R shape and existing caller expectations while
making status inspectable for tests, dashboards, and future visual aids.

Rejected alternative: add a third matrix column. That would make interval
metadata visible but would break the standard `confint()` two-column convention.

Rejected alternative: only add an invisible attribute and leave
`extract_correlations()` unchanged. That would hide the status from the report
table route where users actually inspect many pairwise correlations.

## 4. Checks Run

- `Rscript -e 'devtools::load_all(".", quiet=TRUE); fit <- gllvmTMB:::fit_mixed_family_fixture(3L); ci <- suppressWarnings(suppressMessages(confint(fit, parm="rho:unit:1,2", method="profile"))); print(ci); print(attr(ci, "ci_status")); cors <- suppressMessages(extract_correlations(fit, tier="unit", pair=c(1,2), method="profile", link_residual="auto")); print(cors)'`
  - passed; observed profile matrix `[NA, 0.999]` with
    `ci_status = "profile_boundary"` on both the matrix attribute and
    extractor row.
- `Rscript -e 'devtools::test(filter="fisher-z-correlations|profile-ci|m1-4-extract-correlations-mixed-family")'`
  - `PASS 17`, `SKIP 18`, `FAIL 0`, `WARN 0`.
- `Rscript -e 'devtools::test(filter="stage37-mixed-family")'`
  - `PASS 40`, `SKIP 0`, `FAIL 0`, `WARN 0`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript -e 'devtools::test(filter="m1-4-extract-correlations-mixed-family")'`
  - `PASS 64`, `SKIP 0`, `FAIL 0`, `WARN 0` in `29.0s`.
- `Rscript -e 'devtools::document()'`
  - completed; regenerated the two relevant Rd pages. Pre-existing
    unresolved-link warnings remain.
- `Rscript -e 'devtools::test()'`
  - `PASS 2951`, `SKIP 724`, `FAIL 0`, `WARN 3` in `125.1s`.
- `Rscript -e 'pkgdown::check_pkgdown()'`
  - no problems found.
- `git diff --check`
  - clean.

## 5. Tests of the Tests

The manual probe exercised the exact boundary case from the previous slice:
the profile endpoint is one-sided (`NA`, finite upper bound), and the new
status reports `profile_boundary`. The heavy M1.4 gate then exercised
Fisher-z, Wald, profile, bootstrap, and public `confint()` routes on the
mixed-family fixtures.

## 6. Consistency Audit

- The two-column `confint()` matrix shape is unchanged.
- `extract_correlations()` now has a richer output schema; tests that asserted
  the exact old column set were deliberately updated.
- Plotting/table callers only require the old columns, so the extra status
  column is backward-compatible for visual routes.
- Documentation now mentions both the extractor column and the rho matrix
  attribute.

## 7. Roadmap Tick

Native R/TMB mixed-family rho inference remains `partial`, but the status
contract is no longer implicit. The next R-first inference slice should decide
whether to standardize these statuses across other derived-quantity
`confint()` routes before broadening Julia CI endpoints.

## 7a. GitHub Issue Ledger

No issue comments were posted. This supports the open mixed-family inference
and capability-status-board work but remains local evidence until the branch is
pushed.

## 8. What Did Not Go Smoothly

`devtools::document()` regenerated unrelated Rd files, as it has in nearby
slices. Those unrelated changes were reverted so the final diff only includes
the rho status documentation.

## 9. Team Learning

Ada: R-first does not mean "more R features at any cost"; it means making the
R user contract precise enough for Julia to target.

Fisher: a one-sided profile interval is useful information, but it is not the
same claim as a fully bracketed or calibrated interval.

Hopper: keeping the matrix shape unchanged matters for downstream S3 users.

Rose: verdict is `partial`. This closes the silent-`NA` gap for rho intervals,
but it does not establish calibrated coverage or Julia endpoint support.

## 10. Known Limitations And Next Actions

- Consider a shared status vocabulary for all derived-quantity `confint()`
  routes, not just rho.
- Add visual handling for `ci_status` in correlation/covariance figures.
- Keep Julia mixed-family CI endpoints blocked until native R statuses and
  coverage gates are more complete.
