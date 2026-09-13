# After Task: Re-admit the qualified dependent temporal--animal AR1 cell

**Branch**: `codex/temporal-nuisance-information-20260912`  
**Date**: `2026-09-13`  
**Roles (engaged)**: Ada

## 1. Goal

Re-admit one narrow temporal source pair: replicated Gaussian AR1
`temporal_dep() + animal_indep()` with one fixed intercept-only relationship
source. The work restores fitting, known-animal forecasting, direct profile,
and bootstrap/refit while leaving other temporal animal routes refused.

## 2. Implemented

The parser admits only the qualified dependent-animal pair. Lifecycle guards
recognize its static diagonal relationship tier. Forecasting adds the labelled
relationship covariance recovered from the fitted precision matrix to the
within-series temporal covariance. Profile targets only the native temporal
parameter, and bootstrap redraws/refits the saved public call.

## 3a. Decisions and Rejected Alternatives

**Decision:** admit only replicated Gaussian AR1 `temporal_dep()` with one fixed
intercept-only `animal_indep()` source. **Rationale:** the repository already
contained a dense likelihood/gradient oracle, relationship-representation
checks, forecast contract, lifecycle contract, and frozen recovery receipt.
**Rejected:** animal-by-time products, other animal modes, OU, slopes, and
generic lifecycle routes. **Confidence:** high for the named local fixture and
its public method paths; no general recovery or coverage claim.

## 4. Files Touched

- API and lifecycle code: `R/temporal.R`, `R/temporal-forecast.R`,
  `R/temporal-profile.R`, and `R/temporal-bootstrap.R`.
- Tests: `tests/testthat/test-temporal-program-dep-animal.R` and the matching
  retained developer fixture.
- Contract cascade: regenerated lifecycle Rd files, the two temporal articles,
  canonical grammar, extractor contract, validation register, and check log.
- Evidence: ignored `.unlazy/temporal-program/re-admit-dep-animal-GATES.md`.

## 5. Checks Run

- The developer animal fixture was red before the parser change only at the
  expected source-pair refusal, then passed after implementation.
- `testthat::test_file("tests/testthat/test-temporal-program-dep-animal.R")`
  passed. The focused profile, bootstrap, and forecast files also passed.
- `Rscript --vanilla dev/temporal-program/verify.R dep-animal-retained-failure`
  emitted `TEMPORAL_DEP_ANIMAL_RETAINED_FAILURE_PASS`.
- `devtools::document(quiet = TRUE)` regenerated the lifecycle Rd files.
- `pkgdown::check_pkgdown()` reported no problems; the temporal and keyword
  grid articles rendered directly. `git diff --check` passed.

## 6. Tests of the Tests

The active fixture independently assembles the additive dense Gaussian
covariance and checks every outer derivative at `-.4`, `0`, and `.6`. It has
diagonal, rank-one, and product-covariance controls. It also checks A,
pedigree, Ainv, long/wide, update, simulation, forecasts at both persistence
signs, row order, unseen-animal refusal, native profile, and reproducible
retained bootstrap rows. The recovery verifier rejects malformed or altered
receipts before emitting its retained-failure marker.

## 7a. Issue Ledger

No issue was opened. The acceptance ledger records this narrow re-admission;
the exact-head package check is an Actions gate, and merge/release are outside
this slice.

## 8. Consistency Audit

`rg -n -i "temporal.*animal.*(deferred|unavailable)|animal.*temporal.*(deferred|unavailable)" R man docs/design vignettes/articles`
was reviewed. Remaining matches describe only deferred cells and other animal
combinations. Parser, public methods, generated help, articles, grammar,
extractor contract, register, active test, and retained-failure verifier agree.

## 9. What Did Not Go Smoothly

The broad local temporal suite finished outside the tool's retained stdout
window, so it is not counted as a passed gate. Focused test output and the
receipt verifier are retained. The already running three-OS check targets the
previous head, so a fresh exact-head run remains required after it becomes
terminal.

## 10. Known Residuals

The retained nine-attempt animal recovery fixture fails its frozen
animal-variance threshold. This cell therefore has no recovery, coverage, or
calibrated-interval claim. Cross-platform verification of this new commit,
merge, and release remain pending.

## 11. Team Learning

**Ada:** a parser re-admission must be matched by explicit lifecycle guards and
forecast covariance construction. Otherwise a model can fit while its public
methods silently refuse it or omit its static relationship component.

## 12. Cross-Product Coverage

This slice covers one fixed intercept-only animal relationship combined with
replicated Gaussian AR1 `temporal_dep()`, additive conditional and
unconditional covariance, A/pedigree/Ainv identities, long/wide syntax,
update/refit, simulation, direct profile, retained bootstrap attempts, and
known-animal forecasting. It does NOT cover animal-by-time interactions, other
temporal modes, OU, source slopes, source-strength estimation, generic
prediction, intervals, selection, new animals or series, non-Gaussian
families, broad recovery, coverage, cross-platform verification, merge, or
release readiness.
