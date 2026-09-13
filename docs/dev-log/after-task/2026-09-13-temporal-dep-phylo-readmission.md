# After Task: Re-admit the qualified dependent temporal--phylogenetic AR1 cell

**Branch**: `codex/temporal-nuisance-information-20260912`  
**Date**: `2026-09-13`  
**Roles (engaged)**: Ada, Astra/Noether, Boole, Curie, Emmy, Grace, Rose

## 1. Goal

Re-admit one narrow temporal source pair: replicated Gaussian AR1
`temporal_dep() + phylo_indep()` with one fixed intercept-only phylogenetic
source. The work restores only its fitting, known-series forecast, direct
profile, and bootstrap/refit route; all other temporal phylogenetic modes and
all animal, kernel, and other spatial source pairs remain refused.

## 2. Implemented

The parser retains a public `phylo_indep()` identity alongside the temporal
specification only for the qualified AR1 dependent cell. The forecast adds the
full retained phylogenetic covariance to the within-series temporal covariance,
including the retained precision-to-covariance mapping. The profile targets
only the native temporal parameter, and bootstrap redraws/refits both additive
sources through the saved public call.

## 3a. Decisions and Rejected Alternatives

**Decision:** admit only a replicated Gaussian AR1 dependent temporal source
with one fixed intercept-only `phylo_indep()` source. **Rationale:** it has a
pre-existing model contract, independent dense likelihood and derivative
oracle, source-label tests, lifecycle contracts, and a retained passing
three-persistence recovery fixture. **Rejected:** enabling every historical
phylogenetic or source-pair route at once. Each changes the covariance and
conditioning problem. **Confidence:** high for the named local lifecycle and
recovery fixture; no broad recovery, interval, or coverage claim.

## 4. Files Touched

- API and lifecycle code: `R/temporal.R`, `R/temporal-forecast.R`,
  `R/temporal-profile.R`, and `R/temporal-bootstrap.R`.
- Tests: `tests/testthat/test-temporal-program-dep-phylo.R`,
  `tests/testthat/test-temporal-program-dep-phylo-lifecycle.R`, and
  `tests/testthat/test-temporal-provider-scope.R`.
- Contract cascade: four regenerated temporal Rd topics,
  `vignettes/articles/temporal-ar1.Rmd`,
  `vignettes/articles/api-keyword-grid.Rmd`,
  `docs/design/01-formula-grammar.md`,
  `docs/design/06-extractors-contract.md`, and
  `docs/design/35-validation-debt-register.md`.
- Evidence: ignored `.unlazy/temporal-program/re-admit-dep-phylo-GATES.md`;
  `docs/dev-log/check-log.md` records execution.

## 5. Checks Run

- Active source-pair oracle test: passed.
- New phylogenetic lifecycle test: passed.
- Provider-scope and dependent-spatial regression tests: passed.
- `Rscript --vanilla dev/temporal-program/verify.R dep-phylo`: emitted
  `TEMPORAL_DEP_PHYLO_RECOVERY_PASS`.
- `devtools::document(quiet=TRUE)`: regenerated four temporal Rd topics.
- The five-gate dependent-phylogenetic unlazy ledger: all gates met.
- `git diff --check`: passed.

## 6. Tests of the Tests

The dense oracle independently rebuilds the additive covariance and checks all
outer derivatives at three fixed persistence values. It has product and
low-complexity covariance controls. The lifecycle test verifies reproducible
retained bootstrap rows, direct parameter profiling, and the `lincomb` guard.
The recovery verifier rejects missing, stale, incomplete, or threshold-failing
retained receipts before emitting its pass marker.

## 7a. Issue Ledger

No issue was opened. The acceptance ledger records the narrow re-admission;
merge and release remain outside this slice.

## 8. Consistency Audit

The parser, methods, generated help, article boundaries, canonical grammar,
extractor contract, validation register, active tests, and retained recovery
verifier now describe the same fixed AR1 dependent-phylogenetic cell. Other
source pairs remain explicit refusals. `git diff --check` found no whitespace
errors.

## 9. What Did Not Go Smoothly

The active parser deliberately refused the historical test when it was first
restored. That failure established the starting boundary. The forecast route
then needed both the phylogenetic covariance addition and an OU refusal that
names missing mode-and-source-specific evidence. The lifecycle test was added
because the historical oracle file did not exercise bootstrap or profile.

## 10. Known Residuals

This is local evidence for one fixed three-trait, four-series, replicated
Gaussian AR1 design. It does not cover phylogeny-by-time interactions, new
series, OU, source slopes, estimated source attenuation, generic prediction,
calibrated intervals, selection, non-Gaussian families, broad recovery,
coverage, cross-platform status, merge, or release.

## 11. Team Learning

**Astra/Noether:** the covariance must remain additive, and forecasting must
invert the full phylogenetic precision rather than a tip-only slice.

**Boole/Emmy:** public tree/VCV identity and long/wide replay remain part of
the feature, rather than being metadata afterthoughts.

**Curie:** every re-admission needs a fresh active test path, lifecycle test,
and retained-receipt verifier.

**Grace/Rose:** a passing local ledger does not substitute for the active
three-OS package check or merge/release gates.

## 12. Cross-Product Coverage

This slice covers one fixed intercept-only phylogenetic source combined with
replicated Gaussian AR1 `temporal_dep()`, additive unconditional and
conditional covariance, long/wide syntax, tree/VCV identities, update/refit,
simulation, direct profile, retained bootstrap attempts, and known-series
forecasting. It does NOT cover phylogeny-by-time interactions, other temporal
modes, OU, other sources, source slopes, source-strength estimation, generic
prediction, intervals, selection, new series, non-Gaussian families, broad
recovery, coverage, cross-platform verification, merge, or release readiness.
