# After Task: Posterior-Predictive And Simulation-Rank Diagnostic Prototype

**Branch**: `codex/ppc-rq-diagnostics-2026-05-20`
**Date**: `2026-05-20`
**Roles (engaged)**: `Ada / Jason / Boole / Fisher / Florence / Pat / Grace / Rose / Shannon`

## 1. Goal

Issue #222 asked for a diagnostic lane beyond static fit summaries. The goal
was to start a design/prototype surface for fitted-model predictive checks
and randomized-quantile-style residuals without advertising an exported API
or exact residual method before the semantics are ready.

## 2. Implemented

- Added non-exported `inst/prototypes/ppcheck-diagnostics.R`.
- Added `gllvmTMB_ppc_draws_prototype()` for fitted-model draw tables.
- Added `gllvmTMB_simulation_rank_residuals_prototype()` with explicit row
  status for non-finite observed or simulated values.
- Added `gllvmTMB_pp_check_prototype()` returning `ggplot` objects for
  `dens_overlay`, `stat_grouped`, and `rq_qq`.
- Added attached plot metadata under
  `attr(plot, "gllvmTMB_diagnostic")`.
- Added Design 51 to separate fitted-model predictive checks,
  simulation-rank residuals, and future exact randomized-quantile residuals.
- Added DIA-11 and DIA-12 to the validation-debt register as `partial`.
- Updated `ROADMAP.md` M3.4 notes without moving the M3 progress bar.

## 3. Files Changed

- `inst/prototypes/ppcheck-diagnostics.R`
- `tests/testthat/test-ppcheck-diagnostics-prototype.R`
- `docs/design/51-posterior-predictive-diagnostics.md`
- `docs/design/35-validation-debt-register.md`
- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-20-ppc-rq-diagnostics.md`

No `R/`, `NAMESPACE`, generated `man/*.Rd`, README, NEWS, or vignette file
changed. This is intentional: the prototype is not exported.

## 3a. Decisions and Rejected Alternatives

Decision: call the implemented residual a **simulation-rank residual**.
Rationale: exact randomized-quantile residuals require family-specific fitted
CDF plumbing; the prototype uses simulation ranks from `simulate()`. Rejected:
shipping this as `residuals(type = "randomized_quantile")`.
Confidence: high.

Decision: keep the predictive-check helper non-exported. Rationale:
`bayesplot::pp_check()` and `brms::pp_check()` are posterior-predictive
interfaces; `gllvmTMB` currently supplies fitted-model simulation draws, not
Bayesian parameter draws. Rejected: exporting `pp_check.gllvmTMB_multi()` in
this lane. Confidence: high.

Decision: create follow-up issue #228. Rationale: public API promotion,
exact residuals, and count-specific figures are a real next slice, not
cleanup inside #222. Confidence: high.

## 4. Checks Run

- `Rscript --vanilla -e 'parse("inst/prototypes/ppcheck-diagnostics.R"); parse("tests/testthat/test-ppcheck-diagnostics-prototype.R")'`
  -> both files parsed successfully.
- `Rscript --vanilla -e 'devtools::test(filter = "ppcheck-diagnostics-prototype")'`
  -> passed: 45 tests, no warnings, no skips.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB|ppcheck-diagnostics-prototype")'`
  -> passed: 82 tests, no warnings, no skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> passed: `No problems found.`
- `git diff --check`
  -> clean.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> first run failed because tests sourced a checkout-only `dev/` file from
  the source-tarball check environment. The prototype was moved to
  `inst/prototypes/` so the installed package can test it without exporting it.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> rerun completed with 0 errors, 1 local installation warning, and 5 notes.
  The PR-specific source-tarball test error was gone. The remaining install
  warning is the local Apple `xcrun --show-sdk-version` warning, reproduced by
  direct `R CMD INSTALL`; notes are pre-existing top-level file, NEWS heading,
  unused-import, and missing-import-suggestion notes.
- `tmp=$(mktemp -d); R CMD INSTALL --library="$tmp" .`
  -> installed successfully and reproduced only the local Apple
  `xcrun --show-sdk-version` warning.
- One-off visual QA rendered `/tmp/gllvmTMB-ppc-rq-qq.png` and
  `/tmp/gllvmTMB-ppc-density-v3.png` from a Poisson fit. The Q-Q plot was
  acceptable for prototype. The density plot legend was revised after the
  first visual check.

## 5. Tests of the Tests

The new test file satisfies the feature-combination rule: it fits real
Gaussian, Poisson, and NB2 `gllvmTMB` models and checks the prototype
against `simulate.gllvmTMB_multi()`, ggplot construction, attached metadata,
and family labels.

It also satisfies the boundary-case rule: one test forces a non-finite
observed response in the fitted object and verifies that the residual table
keeps the row with `status = "nonfinite_observed"` rather than silently
dropping it. Argument-validation tests cover bad objects, `nsim`/`ndraws`
conflicts, and missing grouping variables.

## 6. Consistency Audit

- `rg -n "pp_check\\.gllvmTMB|residuals\\.gllvmTMB_multi|randomized_quantile" R NAMESPACE man README.md NEWS.md docs/design vignettes tests/testthat inst/prototypes`
  -> only intentional prototype/design mentions of future public API names and
  out-of-scope boundaries.
- `rg -n "posterior predictive|posterior-predictive|randomized[- ]quantile|simulation-rank|DIA-11|DIA-12|pp_check|gllvmTMB_pp_check_prototype" README.md ROADMAP.md NEWS.md docs/design vignettes R inst/prototypes tests/testthat`
  -> hits confined to the new prototype, Design 51, ROADMAP partial-status
  note, validation-debt rows, and tests.
- `rg -n "S_B|S_W|\\\\bf S|gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(|in prep|in preparation" docs/design/51-posterior-predictive-diagnostics.md inst/prototypes/ppcheck-diagnostics.R tests/testthat/test-ppcheck-diagnostics-prototype.R`
  -> no hits in the new design/prototype/test files.
- `rg -n "meta_known_V" README.md NEWS.md docs vignettes`
  -> pre-existing intentional deprecated-alias / historical hits only; no
  new hit from this lane.
- `rg -n "gllvmTMB_wide" README.md NEWS.md docs vignettes`
  -> pre-existing soft-deprecation / historical hits only; no new hit from
  this lane.
- `rg -n "in prep|in preparation" docs vignettes`
  -> pre-existing internal/historical hits only; no new hit from this lane.

## 7. Roadmap Tick

**Roadmap tick**: M3 progress stays `███░░░░░` 3/8. M3.4 notes now mention
the #222 non-exported fitted-model predictive / simulation-rank residual
prototype, and name DIA-11 / DIA-12 as partial.

## 7a. GitHub Issue Ledger

- Inspected #222 before implementation.
- Commented on #222 with branch status and scope summary.
- Created #228 for public API / exact residual promotion.
- #222 should close with this PR after merge; #228 carries the non-prototype
  continuation.

## 8. What Did Not Go Smoothly

The first full local R CMD check caught that tests cannot source a
checkout-only `dev/` file from the source-tarball check environment. Grace
moved the prototype to `inst/prototypes/`, which keeps it non-exported but
available to installed-package tests.

The first density-overlay visual check produced a clumsy legend for a line
plot. Florence caught it, and the prototype switched to line-based density
layers. More importantly, density overlays are not the final count-family
diagnostic; Poisson and NB2 need a better public figure such as a rootogram,
zero-fraction, or tail-count check.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the lane bounded: #222 becomes a prototype PR, while #228 carries
the public API and exact residual promotion.

Jason checked sister-package patterns. The useful lesson is not to copy a
surface name blindly: `sdmTMB` separates analytical and simulation-based
residuals; `bayesplot` and `brms` show useful interface shapes but assume
posterior draws.

Boole kept the API grammar tentative. `trait`, `group`, `ndraws` / `nsim`,
`seed`, and `condition_on_RE` are represented in the prototype, but no
exported S3 method is claimed.

Fisher enforced the residual-semantics boundary. Simulation-rank residuals
are useful, but exact randomized-quantile residuals remain future work.

Florence reviewed the prototype figures. The Q-Q plot is acceptable for a
prototype; count-density overlays need replacement before public docs.

Pat's reader concern is wording: users should see "fitted-model predictive"
and "simulation-rank" until the package can honestly support stronger
claims.

Grace checked local package health via targeted tests and
`pkgdown::check_pkgdown()`.

Rose checked stale public-claim wording and kept DIA-11 / DIA-12 partial.

Shannon checked the lane board and open-PR state before edits; no open PR
collision was present.

## 10. Known Limitations And Next Actions

- The prototype is non-exported and lives under `inst/prototypes/` so R CMD
  check can test it from the installed package source.
- Exact randomized-quantile residuals are not implemented.
- The prototype is not DHARMa-compatible.
- Density overlays for count data are temporary, not publication-quality.
- Delta, hurdle, truncated, ordinal, and mixture-family residual semantics
  remain out of scope.
- Next slice: issue #228.
