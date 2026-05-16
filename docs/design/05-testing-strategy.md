# Testing Strategy

**Maintained by:** Curie (simulation + testing + recovery
studies) and Fisher (statistical inference semantics).
**Reviewers:** Grace (CI / pkgdown / CRAN mechanics), Rose
(test-honesty audit + tests-of-the-tests discipline), Boole
(formula-grammar test coverage), Gauss (numerical-stability
tests).

Testing must constrain the modelling ambitions of `gllvmTMB`.
Every advertised capability is backed by a test; conversely,
every promotion of a `claimed` row to `covered` in
`docs/design/35-validation-debt-register.md` requires a test
file with concrete assertions.

**Status discipline**: 4-state vocabulary (`covered / claimed /
reserved / planned`). This doc lays out the testing **design**;
the validation-debt register (forthcoming, Phase 0A step 7)
links specific test files to specific advertised claims.

## Test layers

1. **Unit tests for formula parsing and family validation** —
   Does the parser accept the syntax? Does the family
   constructor produce a well-formed registry object? Does the
   wide-format `traits(...)` LHS pivot correctly to long?
2. **Simulation-recovery tests per likelihood** — Simulate
   from known parameters; fit the corresponding `gllvmTMB`
   model; check estimates within tolerance.
3. **Comparative smoke tests against established packages** —
   Where parameterisations match, fit the same data in
   `glmmTMB`, `gllvm`, `galamm`, `sdmTMB`, etc. and compare
   log-likelihoods, point estimates, or parameter recovery
   (rotation-aware where appropriate).
4. **Prediction and simulation method tests** — `predict()`
   returns correct shapes on the link scale and the response
   scale; `simulate.gllvmTMB_multi()` returns the right family
   per row (M2 work for the mixed-family case).
5. **Snapshot tests for clear user-facing errors** — Banned
   syntax (e.g. `(1 | g1/g2)` slash form, $\ge 2$ random
   slopes in M1, mixed-family with delta) errors with a
   specific message; the message is snapshot-pinned so prose
   changes are caught.
6. **Boundary-case tests** — Variance components near zero;
   rank-deficient $\boldsymbol\Lambda$; saturated Beta /
   beta-binomial fits; mis-specified $d$; family $\times$ d
   regimes flagged by `gllvmTMB_check_consistency()`.
7. **Optional long simulation tests outside CRAN** — Recovery
   grids across sample size, slope counts, rank choices,
   slope-counts, family combinations.

## Two-tier validation

`gllvmTMB` should validate models in two complementary ways.

### Tier 1: comparison against established software

Useful for simple overlapping models. The Phase 5.5 external
validation sprint runs the full comparator roster on shared
fixtures (`docs/dev-log/audits/2026-05-15-external-audit-2-response.md`);
the per-package routine smoke tests are CRAN-safe with
`skip_if_not_installed()` guards.

Implemented (or planned) comparator smoke tests:

| Test path | Comparator | gllvmTMB feature exercised | Status |
|-----------|------------|---------------------------|--------|
| `glmmTMB::rr() + diag()` for Gaussian | `glmmTMB::glmmTMB(..., rr(0 + trait \| g, d = K) + diag(0 + trait \| g))` | `latent + unique` paired decomposition; log-likelihood match to 1e-4 (per `tests/testthat/test-stage2-rr-diag.R`) | covered (verify in Phase 0B) |
| `glmmTMB::propto()` for phylogenetic | `glmmTMB::glmmTMB(..., propto(0 + trait \| species, A))` | `phylo_scalar()`; log-likelihood match to 1e-4 (per `tests/testthat/test-stage3-propto-equalto.R`) | covered |
| `glmmTMB::equalto()` for known-V | `glmmTMB::glmmTMB(..., equalto(0 + obs \| grp_V, V))` | `meta_V(value, V = V)` (renamed from `meta_known_V`); LL match to 1e-3 | covered |
| `gllvm::gllvm()` binary GLLVM | Procrustes-aligned loadings + per-factor $\rho > 0.95$ | binary GLLVM with `latent()`; rotation-aware comparison via `compare_loadings()` | claimed (M2 work) |
| `sdmTMB::sdmTMB()` single-trait spatial | LL match to TMB tolerance | single-trait `spatial_unique()` reduces correctly | planned (Phase 5.5) |
| `lme4::lmer()` Gaussian random intercepts | LL match on `(1 \| g)` ordinary RE | ordinary RE path | claimed |
| `MCMCglmm` for phylogenetic | $\sigma^2_\text{phy}$ MLE vs MCMCglmm posterior mean | sparse $A^{-1}$ alignment | planned (Phase 5.5) |
| `Hmsc` for phylogenetic + spatial JSDM | Residual correlation structure comparison | `phylo_latent + spatial_unique` capstone | planned (Phase 5.5) |
| `galamm` for SEM / IRT | one shared fixture; mixed-response API mapping | `lambda_constraint` confirmatory loadings | planned (Phase 5.5) |

**Comparator-test guard**: Fast CRAN tests use
`skip_if_not_installed()` and only tiny comparator cases (under
60 seconds each). Full comparator sweeps belong in optional
local scripts or scheduled CI; package conventions, likelihood
constants, priors, and optimiser settings can differ
non-trivially.

`brms` and `lavaan` are **deferred post-CRAN** per the
audit-2 2026-05-15 decision (brms has known identifiability
pathologies on GLLVM-style models; lavaan is SEM-style without
the spatial/phylogenetic surface).

### Tier 2: simulation recovery

The primary truth source. Per-likelihood recovery tests:

1. Simulate from known parameters via `simulate_site_trait()`.
2. Fit the matching `gllvmTMB` model.
3. Check convergence and Hessian diagnostics
   (`sanity_multi()`, `gllvmTMB_diagnose()`).
4. Check parameter recovery on identifiable quantities (the
   implied $\boldsymbol\Sigma_B$, $\boldsymbol\Sigma_W$
   matrices; per-trait communality $H^2$; per-trait
   repeatability; phylogenetic signal $\psi^2_t$).
5. Check rotation-aware loading comparison via
   `compare_loadings()` (Procrustes alignment + per-factor
   correlation).
6. Check edge cases: variance components near zero, rank
   deficiency, family $\times$ d boundary regimes, etc.

The audit-1 ≥ 94% empirical coverage gate (Phase 0C deliverable
0C.1–0C.2) is the formal Tier-2 exit criterion for the Phase
1b validation milestone closure.

## Per-keyword required tests (the 3 × 5 grid)

Every cell of the 3 × 5 grid + ordinary RE + `meta_V()` gets
its own simulation-recovery test. The minimum contract per
keyword:

- **Convergence**: `fit$opt$convergence == 0L`.
- **Hessian**: `fit$pdHess == TRUE` (or boundary-pinned
  flagged by `sanity_multi()`).
- **Extractor recovery**: the implied $\boldsymbol\Sigma$
  matrix matches truth within tolerance.
- **Rotation-aware loadings** (for `latent` cells): Procrustes
  alignment via `compare_loadings()`.
- **Failure path**: malformed inputs are rejected before TMB
  evaluation.

### Phase 0B per-keyword smoke-test plan

Phase 0B writes a `test-formula-grammar-smoke.R` file that hits
every `claimed` row in `docs/design/01-formula-grammar.md`'s
status map:

```r
# Pseudocode for the smoke-test pattern:
test_that("latent(0 + trait | site, d = K) accepts + fits + extracts", {
  sim <- simulate_site_trait(n_sites = 60, n_traits = 3,
                             Lambda_B = ..., psi_B = ...)
  fit <- gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | site, d = 2) +
      unique(0 + trait | site),
    data = sim$data, unit = "site"
  )
  expect_equal(fit$opt$convergence, 0L)
  Sigma_hat <- extract_Sigma(fit, level = "unit")$Sigma
  expect_equal(dim(Sigma_hat), c(3, 3))
  expect_lt(max(abs(Sigma_hat - sim$Sigma_B_true)), 0.5)
})
```

Each test pattern is small (~30 lines) and runs under 5 seconds.

## Per-family required edge cases

For each family in `02-family-registry.md`, the simulation-
recovery test exercises:

**Continuous (gaussian, student, lognormal, Gamma, gengamma,
tweedie):**
- `sigma` small and `sigma` large.
- Mixed-trait fits with different `sigma` per trait.
- Tweedie `p` near boundary $1$ and near boundary $2$.

**Bounded continuous (Beta, betabinomial):**
- `mu` near 0 and near 1 (the saturation regime).
- The clamp at $[10^{-6}, 1 - 10^{-6}]$ before trigamma (Gauss
  correctness flag).

**Counts (poisson, nbinom1, nbinom2, truncated counts,
censored Poisson):**
- `mu` small (near-Poisson limit for NB2).
- `sigma` near zero (overdispersion → Poisson limit).
- Truncated counts: minimum-value support correctly enforced.

**Binomial / beta-binomial:**
- Number of trials varies (single trial, many trials).
- Mixed link tests: logit / probit / cloglog.

**Ordinal probit:**
- Multiple cutpoints with adequate per-category counts.
- Latent residual fixed at 1 (`check_auto_residual()` warns if
  `link_residual = "auto"` on ordinal-probit traits).
- Mode-fixing convention via `extract_cutpoints()`.

**Mixed-family:**
- `family = list(gaussian, binomial, poisson)` on the 3-family
  fixture (Phase 0B + M1 + M2 build this fixture).
- 5-family fixture: + Gamma + nbinom2 (Phase 0B audit slice).
- Within-trait family mixing rejected with the typed error
  class.
- Delta/hurdle family in mixed-family list: rejected (Phase 0B
  writes the `gllvmTMB_auto_residual_delta_undefined` test).

## Random-effects tests

### M1 random-slope tests (s ∈ {0, 1})

Per slope count, per family (Gaussian first, then binomial):

1. **Convergence**: fit converges on the simulated DGP.
2. **Per-trait random-intercept variance recovery**: $\psi_t^2$
   matches truth.
3. **Per-trait random-slope variance recovery** (at $s = 1$):
   the slope variance matches truth.
4. **Within-trait intercept-slope correlation recovery** (at
   $s = 1$): the implied $\rho_{\text{int,slope}}$ per trait
   matches truth.
5. **Rotation-aware loadings recovery**: $\boldsymbol\Lambda$
   matches truth up to rotation via Procrustes alignment.

Per the `04-random-effects.md` M1 design plan: $s \in \{0, 1\}$
in M1 scope; $s \ge 2$ rejected at parse time with
`gllvmTMB_too_many_slopes`.

### Phylogenetic random effects

- `phylo_scalar(species, vcv = Cphy)` on a known tree;
  $\sigma^2_\text{phy}$ recovers within 10% bias.
- `phylo_latent(species, d = K) + phylo_unique(species)` paired;
  $\boldsymbol{\Sigma}_\text{phy}$ entries match truth (per
  `docs/design/03-phylogenetic-gllvm.md` identifiability
  levels 1 and 2).
- Three-piece fallback when paired form under-identifies; the
  fallback's $\boldsymbol\Omega$ matches truth.

### Spatial random effects

- `spatial_unique(0 + trait | sites, mesh = mesh)` on a
  60-site grid; spatial range recovers within 30% bias (the
  SPDE finite-sample artefact noted in
  `simulation-recovery.Rmd`).
- Mesh size sweeps: cutoff 0.05 (fine), 0.10 (moderate), 0.20
  (coarse).

### `meta_V()` tests

- Diagonal `V`: comparator vs `metafor::rma.mv(random = ~ 1 |
  obs, V = V)`.
- Block-diagonal `V` via `block_V(study_id, sampling_var,
  rho_within)`: log-likelihood agreement to TMB tolerance vs
  `glmmTMB::equalto()`.
- The future proportional mode (`meta_V(scale =
  "proportional")`) is planned post-CRAN.

## Diagnostics tests

Each of the 7 diagnostic functions in `04-random-effects.md`
has its own test file:

- `sanity_multi()`: passes on a clean fit; flags pdHess failure
  on a degenerate fit.
- `gllvmTMB_diagnose()`: returns the expected named list shape
  on clean and degenerate fits.
- `check_identifiability()`: catches a spurious extra factor
  ($d_\text{fit} = d_\text{true} + 1$ regime); returns
  `recovery$flags` with the spurious-column flag.
- `gllvmTMB_check_consistency()`: detects non-centred marginal
  score under deliberate mis-specification.
- `confint_inspect()`: returns the four diagnostic flags
  (`quadratic`, `asymmetric`, `flat_at_mle`, boundary).
- `coverage_study()`: aggregates ≥ 94% on the audit-1 fixture
  (Gaussian / NB2 / ordinal-probit).
- `extract_residual_split()`: matches a hand-computed split on
  a Gaussian fit with known $\boldsymbol{\Sigma}_B$ +
  $\boldsymbol{\Sigma}_W$ truth.

## CRAN-safe vs long tests

Routine package tests must be **deterministic, fast, and
small**. Larger recovery grids belong in optional local scripts
or scheduled CI.

| Test class | Scope | Wall-time budget | Where it lives |
|------------|-------|------------------|----------------|
| Unit (parser, family registry) | tiny, in-memory | < 1 s each | `tests/testthat/test-*-basics.R` |
| Simulation recovery — small | $n \sim 60$, $T \sim 3-5$, $R = 1$ rep | < 10 s each | `tests/testthat/test-stage*-recovery.R` |
| Comparator smoke (CRAN-safe) | tiny comparator + `skip_if_not_installed()` | < 60 s each | `tests/testthat/test-stage*-comparator.R` |
| Snapshot tests | error message pins | < 1 s each | `tests/testthat/test-snapshots.R` |
| Coverage study (long; non-CRAN) | $R = 200$, multi-family, multi-slope | hours | `dev/precompute-vignettes.R` |
| External-validation sprint (long; non-CRAN) | full comparator grid | days | `docs/dev-log/audits/` artefacts |

Optional long-test grids (in `dev/precompute-*.R` scripts):

- Per-family recovery across sample size, $T$, $K$,
  missingness.
- Mixed-family combinations: 2, 3, 5 families per fit.
- Random-slope coverage at $s = 0$ and $s = 1$ (the M1 scope).
- Phylogenetic A⁻¹ sparse-vs-dense equivalence and tree-size
  sweeps.
- SPDE spatial recovery across mesh density, range, field SD,
  sampling design.

## Profile-likelihood CI tests

When profile-likelihood intervals are exercised, tests check:

- direct TMB parameters recover sensible intervals on the
  transformed response scale.
- `uniroot()` bounds agree with a small diagnostic grid in
  simple models.
- boundary variance components return flagged one-sided
  intervals.
- failed constrained optimisations produce informative
  fallbacks (the `profile_failed` flag in `confint_inspect()`).
- profile CIs have better small-sample behaviour than Wald
  intervals in targeted long simulations.
- per-derived-quantity (communality, repeatability, phylo
  signal, pairwise correlation) profile CIs return the
  expected shape (the Phase 1b validation milestone closed
  most of these via PRs #105, #120, #121, #122).

## Tests of the tests

For every new test, verify at least one of:

- the new test **failed before the fix** (the canonical "test
  caught the bug" pattern).
- the test compares the log-likelihood to an **independent
  calculation** (e.g. base-R `dnorm`, `stats::dnbinom`,
  `MASS::glm.nb` for the constant-dispersion case).
- the test exercises a **boundary case** (variance near zero,
  saturated mean, weak identifiability).
- the test **combines the new feature with an existing
  neighbouring feature** (e.g. when adding `meta_V`, test it
  with a `latent + unique` decomposition too, not just
  alone).

Generic "the function returned without error" assertions are
NOT sufficient. Each test must assert something specific about
the **value** returned.

## Honest-failure discipline

When a test fails:

- Inspect the failure message before relaxing expectations.
- Check whether the test is testing the intended behaviour, or
  testing an artefact of the implementation.
- Use deterministic seeds (`set.seed(2025)` etc.) for
  simulation tests to ensure reproducibility.
- Add a negative test when a rule should reject unsupported
  syntax (the `gllvmTMB_too_many_slopes`,
  `gllvmTMB_auto_residual_incoherent`,
  `gllvmTMB_auto_residual_delta_undefined` error classes).

## Test-file organisation

The current `tests/testthat/` follows a `test-stage*-*.R`
pattern (legacy from the 2026-05 development phases). Future
test files should adopt a more semantic naming convention:

| Category | New naming pattern | Examples |
|----------|---------------------|----------|
| Formula-grammar smoke | `test-formula-grammar-*.R` | `test-formula-grammar-latent.R`, `test-formula-grammar-spatial.R` |
| Per-family | `test-family-*.R` | `test-family-gaussian.R`, `test-family-binomial.R` |
| Per-extractor | `test-extract-*.R` | `test-extract-sigma.R`, `test-extract-correlations.R` |
| Per-diagnostic | `test-diagnostic-*.R` | `test-diagnostic-check-identifiability.R` |
| Random effects | `test-random-effects-*.R` | `test-random-effects-slopes.R` |
| Comparator | `test-comparator-*.R` | `test-comparator-glmmTMB.R`, `test-comparator-gllvm.R` |
| Mixed-family | `test-mixed-family-*.R` | `test-mixed-family-extractors.R` (M1 work) |
| Snapshots | `test-snapshots-*.R` | `test-snapshots-error-messages.R` |

This semantic naming is **planned** (post-CRAN, when the test
suite reorganises); current files keep their `test-stage*-*.R`
names.

## Cross-references

- `docs/design/00-vision.md` — package vision; the
  unparalleled-capability claim (mixed-family latent-scale
  correlations) drives the mixed-family test requirements.
- `docs/design/01-formula-grammar.md` — every `claimed` row in
  the status map gets a smoke test (Phase 0B).
- `docs/design/02-family-registry.md` — every family row gets
  a per-family recovery test.
- `docs/design/03-likelihoods.md` — per-family TMB density
  matched against an independent calculation (the
  comparator-test discipline).
- `docs/design/04-random-effects.md` — every keyword in the
  3 × 5 grid gets a recovery test; M1.5 coverage study at
  $s \in \{0, 1\}$.
- `docs/design/06-extractors-contract.md` (forthcoming) — every
  `extract_*()` gets a per-family + per-keyword test.
- `docs/design/35-validation-debt-register.md` (forthcoming,
  Phase 0A step 7) — every advertised capability links to its
  test file.
- `.agents/skills/add-family/SKILL.md` — checklist for adding a
  new family (includes simulation tests).
- `.agents/skills/add-simulation-test/SKILL.md` — checklist for
  writing a new simulation test.
- `.agents/skills/after-task-audit/SKILL.md` — pre-merge audit
  including stale-wording grep + tests-of-the-tests check.
- `.agents/skills/tmb-likelihood-review/SKILL.md` — review
  checklist for C++ template changes.
- AGENTS.md Design Rule #1: no new family without simulation
  tests.
- AGENTS.md Design Rule #5: no new tier without simulation
  recovery on a known DGP at the new tier.

## Persona-active engagement

- **Curie** owns the per-keyword and per-family simulation-
  recovery test suite. Writes the new tests; runs them locally
  before merge; flags coverage gaps.
- **Fisher** owns the inference-semantic tests: profile-CI
  accuracy per family; coverage study design; per-derived-
  quantity CI tests.
- **Boole** owns the formula-grammar parser tests + the typed-
  error tests (parse-time rejections like `gllvmTMB_too_many_slopes`).
- **Gauss** owns the numerical-stability tests: boundary cases,
  saturated fits, near-rank-deficiency.
- **Emmy** owns the S3 dispatch tests: `predict()`,
  `simulate()`, `fitted()`, `residuals()` per family.
- **Grace** owns the CRAN-test discipline (skip-on-cran gates,
  `skip_if_not_installed()` guards, wall-time budgets, the
  3-OS CI sustainability).
- **Rose** owns the tests-of-the-tests audit (every test
  asserts a specific value; every error has a snapshot pin).
- **Pat** owns the user-experience tests on the error messages
  (does the error tell the user what to try next?).
- **Jason** owns the comparator-roster maintenance (when a new
  sister-package release lands, are our comparator tests still
  appropriate?).
- **Shannon** owns the cross-team test coordination (when a
  feature touches multiple test categories, are the test files
  named coherently?).
- **Ada** ratifies the per-test promotion `claimed → covered`
  in the validation-debt register.

## How this doc grows

This testing strategy doc is the design contract. Specific test
files are documented in the validation-debt register (Phase 0A
step 7). As `claimed` rows promote to `covered`:

- New simulation-recovery tests get added to
  `tests/testthat/`.
- The validation-debt register row updates with the test-file
  path.
- The CRAN-safe-vs-long allocation reviewed for runtime budget.
- Per-keyword and per-family smoke tests proliferate; the test
  file count grows from ~85 today toward ~150-200 at v0.2.0
  release.

drmTMB's `tests/testthat/` has 39 test files at v0.1.1 because
they cover fewer families and a narrower keyword grid; ours
will exceed that as the 3 × 5 keyword grid × 15+ families
matrix fills in. The discipline is the same: each test
asserts a specific value; each new feature ships with a test;
each ` claimed → covered` promotion is backed by a test-file
path in the register.
