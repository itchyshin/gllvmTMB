# After Task: Native Mixed-Family confint Profile/Bootstrap Route Evidence

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Fisher / Rose`

## 1. Goal

Extend the R-first native mixed-family inference evidence from Fisher-z/Wald
rho intervals to the public `confint()` profile and bootstrap routes, while
keeping the claim boundary honest.

## 2. Implemented

- Added a heavy-gated test for
  `confint(fit, parm = "rho:unit:1,2", method = "profile")` on the native
  three-family mixed fixture.
- Added a heavy-gated test for
  `confint(fit, parm = "rho:unit:1,2", method = "bootstrap", nsim = 20L,
  link_residual = "none")` on the same fixture.
- The profile test permits a boundary-partial interval (`NA` on one endpoint)
  but requires at least one finite endpoint inside `[-1, 1]`.
- The bootstrap test requires finite ordered bounds inside `[-1, 1]`.

## 3. Files Changed

Tests:

- `tests/testthat/test-m1-4-extract-correlations-mixed-family.R`

Docs and ledger:

- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-native-mixed-family-confint-profile-bootstrap.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep these tests behind `GLLVMTMB_HEAVY_TESTS=1`.

Rationale: profile/bootstrap mixed-family rho intervals require repeated
refitting; they are too slow for the default PR test lane but are exactly the
kind of evidence needed for nightly/pre-release gates.

Rejected alternative: run these in the default Stage 37 smoke. That would make
routine tests slower and less predictable.

Confidence: medium-high for route coverage; low for calibrated coverage, which
is explicitly outside this slice.

## 4. Checks Run

- `Rscript -e 'devtools::load_all(".", quiet=TRUE); fit <- gllvmTMB:::fit_mixed_family_fixture(3L); ci <- suppressWarnings(suppressMessages(confint(fit, parm="rho:unit:1,2", method="profile"))); print(ci); stopifnot(is.matrix(ci), nrow(ci)==1L, ncol(ci)==2L)'`
  - passed; observed profile interval was `[NA, 0.999]`.
- `Rscript -e 'devtools::load_all(".", quiet=TRUE); fit <- gllvmTMB:::fit_mixed_family_fixture(3L); ci <- suppressWarnings(suppressMessages(confint(fit, parm="rho:unit:1,2", method="bootstrap", nsim=20L, seed=20260615L, link_residual="none"))); print(ci); stopifnot(is.matrix(ci), nrow(ci)==1L, ncol(ci)==2L)'`
  - passed; observed bootstrap interval was `[-0.05, 1]`.
- `Rscript -e 'devtools::test(filter="m1-4-extract-correlations-mixed-family")'`
  - `PASS 0`, `SKIP 8`, `FAIL 0`, `WARN 0`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript -e 'devtools::test(filter="m1-4-extract-correlations-mixed-family")'`
  - `PASS 56`, `SKIP 0`, `FAIL 0`, `WARN 0` in `29.2s`.

## 5. Tests of the Tests

The probe before editing confirmed both public routes already returned matrices
on the fixture. The new tests lock this behavior into the heavy inference lane
and encode the boundary semantics explicitly instead of requiring all profile
endpoints to be finite.

## 6. Consistency Audit

- Default lane still skips the profile/bootstrap mixed-family route tests under
  the existing heavy gate.
- Heavy lane executes all eight mixed-family correlation tests and passes
  without warnings.
- The NEWS entry now says route evidence, not calibrated coverage.

## 7. Roadmap Tick

Native mixed-family rho inference moves from Fisher-z/Wald-only public-route
evidence to Fisher-z/Wald/profile/bootstrap route evidence. Status remains
`partial` until coverage and richer CI-status reporting are added.

## 7a. GitHub Issue Ledger

No issue comments were posted. This continues to support the open #340
capability/status-board umbrella and the mixed-family inference rows, but it is
local evidence only until the branch is pushed.

## 8. What Did Not Go Smoothly

The profile route produced a boundary-partial interval (`NA` lower endpoint).
That is acceptable route evidence but reinforces that this is not yet a
calibrated inference claim.

## 9. Team Learning

Ada: small route-evidence tests are a useful bridge between "function exists"
and "claim is mature."

Fisher: profile/bootstrap route availability and interval calibration are
different claims. This slice proves the former only.

Rose: verdict is `partial`. The tests are strong enough for the route row but
not for release wording about calibrated mixed-family correlation CIs.

## 10. Known Limitations And Next Actions

- Add CI-status vocabulary for boundary-partial native `confint()` matrices.
- Run ADEMP/coverage studies before claiming calibrated mixed-family
  correlation intervals.
- Keep Julia mixed-family CI endpoints blocked until native R status semantics
  are clear.
