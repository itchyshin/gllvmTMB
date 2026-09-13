# After Task: Re-admit the qualified dependent temporal--spatial AR1 cell

**Branch**: `codex/temporal-nuisance-information-20260912`  
**Date**: `2026-09-13`  
**Roles (engaged)**: Ada, Astra/Noether, Boole, Curie, Emmy, Grace, Rose

## 1. Goal

Re-admit one deliberately narrow temporal source pair: replicated Gaussian AR1
`temporal_dep() + spatial_indep()` with one fixed mesh and an intercept-only
spatial term. The work restores only its fitting, forecast, direct profile,
and bootstrap/refit route; all other temporal source pairs remain refused.

## 2. Implemented

The formula parser now admits that precise pair and preserves the source-pair
identity in the fitted object. `forecast_temporal()`, `profile_temporal()`, and
`bootstrap_temporal()` recognize only the qualified dependent-spatial shape.
Forecasts rebuild the mesh projection, add the static SPDE covariance to the
temporal covariance, and require one coordinate pair at every temporal state.
Bootstrap replay substitutes the fitted mesh into the saved public call.

## 4. Files Touched

- API and lifecycle code: `R/temporal.R`, `R/temporal-forecast.R`,
  `R/temporal-profile.R`, `R/temporal-bootstrap.R`.
- Tests: `tests/testthat/test-temporal-provider-scope.R`,
  `tests/testthat/test-temporal-program-dep-spatial.R`, and
  `tests/testthat/test-temporal-program-dep-spatial-runner.R`.
- Public and internal contract cascade: four regenerated `man/*.Rd` topics,
  `vignettes/articles/api-keyword-grid.Rmd`,
  `vignettes/articles/temporal-ar1.Rmd`,
  `docs/design/01-formula-grammar.md`,
  `docs/design/06-extractors-contract.md`, and
  `docs/design/35-validation-debt-register.md`.
- Evidence: `.unlazy/temporal-program/re-admit-dep-spatial-GATES.md` is
  ignored locally; `docs/dev-log/check-log.md` records the commands.

## 3a. Decisions and Rejected Alternatives

**Decision:** admit only replicated Gaussian AR1 `temporal_dep()` plus one
fixed-mesh intercept-only `spatial_indep()` term. **Rationale:** its additive
covariance, dense oracle, lifecycle contract, and retained recovery receipt
already exist and are testable independently. **Rejected:** re-enable every
historical source pair by reverting the temporal-only deferral. That would
advertise routes without a current per-cell re-admission check. **Confidence:**
high for the bounded fixed-parameter/lifecycle contract; no recovery or
coverage claim.

## 5. Checks Run

- `devtools::document(quiet=TRUE)`: regenerated all four affected Rd topics.
- `pkgdown::check_pkgdown()`: no problems.
- Focused combined test command over provider scope, dependent-spatial,
  bootstrap, profile, and forecast files: passed with no failures, errors,
  warnings, or skips.
- `pkgdown::build_article("articles/temporal-ar1", lazy=FALSE,
  new_process=FALSE)` after `devtools::load_all()`: rendered all 20 chunks.
- `Rscript --vanilla dev/temporal-program/verify.R dep-spatial-corrected`:
  emitted `TEMPORAL_DEP_SPATIAL_CORRECTED_SCALE_RETAINED_FAILURE`.
- `git diff --check`: passed.

## 6. Tests of the Tests

The source-pair scope test rejects every mode/source pair except the qualified
dependent-spatial cell. The dense oracle tests an additive covariance and a
wrong time-by-space product, central gradients for every active outer
parameter, positive and negative AR1 forecasts, coordinate mismatch refusal,
wide replay, and bootstrap replay. The runner test rejects unsafe campaign
starts and a missing required campaign index.

## 8. Consistency Audit

`rg -n "temporal_dep\(\).*spatial_indep|qualified temporal-dependent spatial"`
across R code, Rd files, design contracts, articles, and tests found the same
narrow AR1 fixed-mesh contract. `git diff --check` found no whitespace errors.

## 7a. Issue Ledger

No relevant open issue was created. The branch itself carries the bounded
re-admission; merge and release decisions remain gated by later evidence.

## 9. What Did Not Go Smoothly

The default isolated pkgdown renderer loads the installed package, where this
branch's temporal helper is absent; it fails at `temporal_indep()`. Rendering
from `devtools::load_all()` in the source process succeeded. The historical
recovery verifier also required a runner test that had been moved into the
retained deferred directory; restoring that test made the retained evidence
check executable again.

## 10. Known Residuals

The fixed-mesh dependent-spatial route is partial: its retained recovery
campaign is negative evidence and it provides no coverage, calibration, or
general recovery claim. Generic prediction, intervals, selection, and other
source pairs remain refused. Cross-platform CI remains owed for this commit.

## 11. Team Learning

**Astra/Noether:** identified the wide-bootstrap, arbitrary-profile-target,
and forecast-coordinate invariants; the restored route includes each repair.

**Boole/Emmy:** parser identity and public long/wide replay remain explicit;
private mesh replacement is confined to bootstrap refit.

**Curie:** the active suite now restores both the independent oracle and the
campaign-start control test, while the retained failed recovery receipt stays
visible.

**Grace/Rose:** generated help, article source rendering, pkgdown checking,
validation-register status, and wording agree. Cross-platform CI is still
owed for this commit.

## 12. Cross-Product Coverage

This slice covers one fixed-mesh spatial provider paired with replicated
Gaussian AR1 `temporal_dep()`, one intercept-only source term, source-process
simulation, direct temporal profile, bootstrap/refit, and known-series
forecasting. It does NOT cover OU, temporal indep or latent spatial pairs,
source slopes, estimated source strength, generic prediction, intervals,
selection, new series, other source providers, recovery beyond the retained
failed fixture, calibration, coverage, cross-platform verification, merge, or
release readiness. Next: commit and run the three-OS package check for this
precise re-admission, then take the next source pair through its own contract.
