# After Task: Native temporal sixth covariance source

**Branch**: `codex/temporal-sixth-source-20260909`
**Date**: `2026-09-09`
**Roles (engaged)**: Ada, Boole, Gauss, Noether, Curie, Pat, Rose, Grace

## 1. Goal

Add a sixth, native temporal covariance source with AR1 and OU kernels and all
three trait-covariance modes, while preserving the ordinary `unit` and
`unit_obs` components and making the migration boundary from the earlier AR1
prototype explicit.

## 2. Implemented and Mathematical Contract

The temporal provider owns a private `(series, time)` state index and never
overwrites public `unit` or `unit_obs` labels.  The fitted covariance is

\[
V = J_{unit}\otimes\Sigma_B + K_{temporal}\otimes\Sigma_T +
J_{unit\_obs}\otimes\Sigma_W + R.
\]

`temporal_indep()`, `temporal_dep()`, and `temporal_latent()` now accept AR1
and OU structures.  Their temporal trait covariances are respectively
`diag(v)`, `Sigma_T`, `Lambda Lambda^T`, and
`Lambda Lambda^T + Psi_T` when `unique = TRUE`; the Psi term is correlated
through time by the same temporal kernel.  AR1 uses
`phi = (1 - 1e-6) tanh(theta)` and preserves ordered integer gaps.  OU uses
`kappa = exp(xi)` and `exp(-kappa |t-s|)` on supplied numeric elapsed time.
The OU innovation variance uses `-expm1(-2*kappa*gap)`, and AR1 gap powers use
AD-safe logarithmic-time exponentiation.

This does not reclassify ordinary `unit_obs` as a temporal replicate or make
space-time, phylo-time, animal-time, or kernel-time providers available.  The
admitted native route remains Gaussian identity-link ML/Laplace; higher rank,
slopes, non-Gaussian families, new-data temporal forecasts, intervals,
profiles, selection, and bootstrap are refused early.  The former prototype's
`K ⊗ Lambda Lambda^T + I ⊗ Psi_W` remains a migration fixture only.
The only equality claim is its no-Psi, rank-one, consecutive-AR1 common
submodel; IID-Psi is deliberately not equivalent to the new public model.

## 3. Files Changed

- Engine and parser: `R/temporal.R`, `R/fit-multi.R`, `R/gllvmTMB.R`,
  `R/traits-keyword.R`, `R/methods-gllvmTMB.R`, `R/extractors.R`,
  `R/select-lv.R`, and `src/gllvmTMB.cpp`.
- Support and generated interface: `R/imports.R`, `R/julia-bridge.R`,
  `R/aghq-report.R`, `NAMESPACE`, and regenerated `man/*.Rd` files.
- Tests and independent evidence: the retained
  `test-temporal-ar1-{parser,oracles,methods}.R` regressions, the four new
  `test-temporal-sixth-source-*.R` files, and
  `dev/temporal-sixth-source/{CONTRACT.md,verify.R,run-recovery.R}`.
- Reader and design surfaces: `README.md`, `NEWS.md`, `AGENTS.md`,
  `CLAUDE.md`, `docs/design/{00-vision,01-formula-grammar,03-likelihoods,04-random-effects,06-extractors-contract,35-validation-debt-register}.md`,
  `vignettes/articles/{api-keyword-grid,temporal-ar1}.Rmd`, and
  `R/brms-sugar.R`.
- Records: `.unlazy/temporal-grid/GATES.md` (ignored local ledger), the
  recovery checkpoint, this after-task report, and `docs/dev-log/check-log.md`.

## 3a. Decisions and Rejected Alternatives

The temporal tier is a peer source rather than a reinterpretation of ordinary
grouping.  That keeps ordinary `unit` and `unit_obs` covariance additive and
lets their latent scores remain extractable.  We reject combined structured
providers because they would require an explicit separable model contract.
We also reject unconditional composed simulation rather than silently holding
ordinary fitted effects fixed.  Confidence is high for the bounded Gaussian
route because the independent dense oracle, gradients, lifecycle tests, and
fixed-seed recovery all exercise it; no broader claim is made.

## 4. Checks Run

- `Rscript --vanilla dev/temporal-sixth-source/verify.R self-test` ->
  `TEMPORAL_SIXTH_SELF-TEST_PASS`; the runner rejects a missing fixture,
  warnings/skips, zero assertions, and deliberate failures.
- `Rscript --vanilla dev/temporal-sixth-source/verify.R parser` ->
  `TEMPORAL_SIXTH_PARSER_PASS`.
- `Rscript --vanilla dev/temporal-sixth-source/verify.R oracle` ->
  `TEMPORAL_SIXTH_ORACLE_PASS`, including eight AR1/OU cells, dense NLL and
  central gradients, odd negative AR1 lag, additive ordinary covariance, OU
  translation/rescaling, and theta extremes.
- `Rscript --vanilla dev/temporal-sixth-source/verify.R methods` ->
  `TEMPORAL_SIXTH_METHODS_PASS`; `Rscript --vanilla
  dev/temporal-sixth-source/verify.R recovery` ->
  `TEMPORAL_SIXTH_RECOVERY_PASS`; `Rscript --vanilla
  dev/temporal-sixth-source/verify.R regression` ->
  `TEMPORAL_SIXTH_REGRESSION_PASS`.
- `Rscript --vanilla -e 'devtools::test(filter="temporal", reporter="summary")'`
  -> all retained and sixth-source temporal files passed without warnings or
  errors.
- `Rscript --vanilla -e 'devtools::document(quiet=TRUE); tools::checkRd("man/anova.gllvmTMB_multi.Rd")'`
  -> pass; `R CMD INSTALL --library=/tmp .` -> pass; clean-library BIC and
  Julia help lookup -> pass.
- `Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); rmarkdown::render("vignettes/articles/temporal-ar1.Rmd", output_dir=tempdir(), quiet=TRUE); rmarkdown::render("vignettes/articles/api-keyword-grid.Rmd", output_dir=tempdir(), quiet=TRUE)'`
  -> pass.  `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found`.
- `Rscript --vanilla -e 'devtools::check(args="--no-manual", quiet=TRUE)'`
  -> exit 0 in 23m00.2s: 0 errors, 0 warnings, and only the environmental
  system-clock and `xcrun_db` notes.
- `git diff --check` -> clean.

## 5. Tests of the Tests

The independent oracle never calls production temporal simulation.  It first
showed that the wrong IID-Psi covariance differs from the declared temporal
Psi covariance, then compared dense marginal NLL central differences with the
native gradient.  The verifier self-test injects missing, warning, skip,
zero-assertion, and failing fixtures.  Fixed seeds cover every AR1/OU mode and
record both successful and failed fits; the verifier recalculates frozen
thresholds rather than checking file presence.  The earlier bounded prototype
tests were retained as migration regressions; tests whose premise was its
old B-tier/IID-Psi implementation were replaced only by an explicit native
migration fixture.

## 6. Consistency Audit

- `rg -n "5 × 3|5 x 3|five correlation sources" README.md NEWS.md R man docs/design vignettes CLAUDE.md AGENTS.md` found historical records and the separately documented response-column five-source scope only; current covariance-grid surfaces use six sources.
- `rg -n "temporal_iid_total|theta_temporal_phi|occasion_variance|measurement_variance|consecutive integer occasions" R tests/testthat README.md NEWS.md docs vignettes man` found only inert retained fixture fields and the explicit prototype migration oracle; there is no public IID-Psi claim.
- `git diff --check` found no whitespace errors.  The final reviewer confirmed dedicated temporal state, source-combination refusals, ordinary `unit_obs` admission, temporal-Psi labels, and preservation of ordinary latent ordination.

## 7. Roadmap Tick

**Roadmap tick**: N/A.  This local bounded implementation adds no public
roadmap or release-status claim.

## 7a. GitHub Issue Ledger

No relevant open issue was inspected or changed.  `gh pr list --state open`
could not reach `api.github.com`; the local lane was committed only after the
repository audit and makes no remote claim.

## 8. What Did Not Go Smoothly

The first package checks exposed a BIC NAMESPACE defect and missing Julia and
`anova.gllvmTMB_multi()` Rd parameters.  The lane repaired all three at their
roxygen/import sources, regenerated help, and reran the entire 23-minute
check.  Review also found the OU cancellation at extreme negative decay,
unconditional composed simulation, ordinary ordination dispatch, and an
overstated prototype equivalence; each received a targeted engine/test repair.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept the six-cell contract and gates separate from the earlier bounded
prototype, which prevented an IID-Psi migration from being called equivalence.

**Boole** checked long/wide grammar, explicit refusal messages, and the
six-by-three reader-facing grid.  Future grammar changes need the same
source/generated-help sweep.

**Gauss** identified the OU cancellation and linear AR1 gap loop.  Standard-
normal innovations plus stable reconstruction make extreme decay finite while
retaining the covariance contract.

**Noether** required the common-submodel comparison to cover objective,
gradient, draw, and extraction, and required the IID-Psi non-equivalence to be
stated plainly.

**Curie** required independent dense covariance/NLL/gradient and all-eight-
cell recovery evidence, including recorded failures and recomputed thresholds.

**Pat** drove the long/wide examples, labels, update/prediction expectations,
and early unsupported-route guidance.

**Rose** found cross-component simulation and ordinary-latent extraction
regressions, then checked the final diff for retained old coverage and stale
five-source wording.

**Grace** required the full local package check after NAMESPACE and Rd repairs;
the final check is clean apart from two environmental notes.

## 10. Design Documentation and User Documentation

The six-source grammar, covariance decomposition, parameter transforms,
admission matrix, extractor contract, and validation status were updated in
the named design files in Section 3.  The README, NEWS, primary help,
temporal help, keyword-grid article, and temporal article describe the same
bounded route.  The long and `traits(...)` wide examples in the temporal
article rendered successfully, as did pkgdown's reference audit.

## 11. Known Limitations And Next Actions

The temporal provider is locally implemented and verified only.  It is not
merged, released, cross-platform verified, or a general recovery/coverage
claim.  Temporal combinations with spatial, phylogenetic, animal, or kernel
sources, and the refused forecast/interval/profile/selection/bootstrap routes,
need their own model contracts and evidence before they can be admitted.
