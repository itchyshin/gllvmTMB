# After Task: Derived Confint CI-Status Contract

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Fisher / Rose / Hopper`

## 1. Goal

Standardize row-level interval status metadata across native R derived
`confint()` matrix routes before using them as Julia bridge targets.

## 2. Implemented

- Added a shared internal `.gtmb_ci_status()` classifier and
  `.gtmb_attach_ci_status()` matrix helper.
- Kept `.gtmb_rho_ci_status()` as a thin compatibility wrapper.
- Attached row-named `ci_status` attributes to `confint()` matrices for
  `icc`, `phylo_signal`, `communality`, and `proportion`.
- Preserved the existing two-column numeric matrix shape.
- Updated the `confint()` return documentation, NEWS, tests, and check-log.

## 3. Files Changed

R code:

- `R/ci-status.R`
- `R/extract-correlations.R`
- `R/z-confint-gllvmTMB.R`

Tests:

- `tests/testthat/test-confint-derived.R`
- `tests/testthat/test-profile-proportions.R`

Docs and ledger:

- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-derived-confint-ci-status.md`
- `man/confint.gllvmTMB_multi.Rd`

## 3a. Decisions and Rejected Alternatives

Decision: keep derived `confint()` returns as ordinary two-column matrices and
attach a row-named `ci_status` attribute.

Rationale: this preserves the base `confint()` shape while making interval
availability explicit for tests, visual aids, and future R-Julia bridge parity.

Rejected alternative: add a third matrix column. That would be more visible but
would break the conventional interval matrix contract.

Rejected alternative: leave each derived route to classify statuses
independently. That would invite drift between rho, ICC, communality,
proportion, and phylogenetic-signal routes.

## 4. Checks Run

- `Rscript -e 'devtools::load_all(".", quiet=TRUE); print(gllvmTMB:::.gtmb_ci_status("profile", c(NA, 0.1, NA), c(0.9, 0.8, NA))); print(gllvmTMB:::.gtmb_ci_status("wald", c(NA, 0.1), c(0.9, 0.8)))'`
  - passed; returned `profile_boundary`, `ok`, `profile_failed`;
    `wald_unavailable`, `ok`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript -e 'devtools::test(filter="confint-derived|profile-proportions")'`
  - `PASS 121`, `SKIP 0`, `FAIL 0`, `WARN 0` in `214.1s`.
- `Rscript -e 'devtools::test(filter="confint-derived|profile-proportions")'`
  - `PASS 0`, `SKIP 50`, `FAIL 0`, `WARN 0`.
- `Rscript -e 'devtools::document()'`
  - completed; regenerated `man/confint.gllvmTMB_multi.Rd`. Pre-existing
    unresolved-link warnings remain.
- `Rscript -e 'devtools::test()'`
  - `PASS 2951`, `SKIP 724`, `FAIL 0`, `WARN 3` in `126.5s`.
- `Rscript -e 'pkgdown::check_pkgdown()'`
  - no problems found.
- `git diff --check`
  - clean.

## 5. Tests of the Tests

The heavy `confint-derived` and `profile-proportions` gates exercise the
public `confint()` routes and now assert the row-named `ci_status` attribute
for finite Wald/bootstrap intervals and profile intervals. The manual helper
probe covers one-sided profile, failed profile, and unavailable Wald endpoints.

## 6. Consistency Audit

- The R matrix shape did not change.
- Rho status semantics are preserved through the compatibility wrapper.
- Documentation now describes a derived-quantity matrix status attribute for
  `icc`, `phylo_signal`, `communality`, `rho`, and `proportion`.
- NEWS states this as metadata/status propagation only, not a coverage claim.

## 7. Roadmap Tick

Native R/TMB derived interval routes are still `partial`, but their interval
availability status is now explicit and shared. This gives Julia bridge work a
clearer target for CI payload reconstruction.

## 7a. GitHub Issue Ledger

No issue comments were posted. This supports the open R-first inference and
bridge-contract work and remains local evidence until the branch is pushed.

## 8. What Did Not Go Smoothly

`air format` initially rewrote nearby style-only lines and
`devtools::document()` regenerated unrelated Rd pages. Both were narrowed so
the final diff stays on the CI-status contract.

## 9. Team Learning

Fisher: interval status is part of the inferential result, not decoration.

Hopper: R-side metadata must be stable before Julia bridge payloads can be
considered parity-complete.

Rose: the word "ok" is method-local. It means both endpoints are finite; it
does not mean calibrated coverage.

## 10. Known Limitations And Next Actions

- This does not change interval numerics or profile/bootstrap algorithms.
- This does not add Julia bridge CI endpoints.
- This does not claim coverage calibration for any derived quantity.
- Next R-first inference slices should teach visual/table methods to display
  `ci_status` clearly.

## 11. Rose Verdict

Rose verdict: PASS WITH NOTES - status metadata is covered for the native R
derived matrix routes, but calibrated coverage and Julia bridge endpoint parity
remain open.
