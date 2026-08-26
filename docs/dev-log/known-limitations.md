# Known limitations

Single source of truth for what `gllvmTMB` does and does not currently
support. The `after-task-audit` skill greps this file for terms like
"rejected", "only diagonal", "planned" to catch stale wording. Update
this file in the same PR that changes the supported surface, so the
durable record never lags the code.

Last refreshed 2026-08-24 (0.7.1 trust-release boundary review; this is a
status fence, not a new validation claim).

## Exact-aa production boundary

The frozen v4 study completed 44,800/44,800 production fits across 28
pilot-admitted cells under source archive SHA-256
`ca6c3feb474d9cbfb44cec3c08e380e8d5810bef8e226cb5b426a6ade9b5f630`.
The aggregate closeout was HOLD. The full eligible cell set was incomplete,
every campaign contained failed admitted cells, and the observable
terminal-status detector identified 19 of 80 catastrophic truth errors
(sensitivity 0.2375; specificity 0.9627236).

The implemented two-sample-size point-estimation pair gates passed for
Gaussian `indep()`, Gaussian `dep()`, Poisson-log rank-1
`latent(unique = TRUE)`, and Binomial(10)-logit rank-1
`latent(unique = TRUE)`. Independent review treats these as narrow
tested-regime evidence, not as a package-wide dependable core. Gaussian
`latent(unique = TRUE)` and NB2-log `latent(unique = TRUE)` remain
characterization-only. The campaign does not certify intervals, raw loading
orientation, structured sources, slopes, mixed families, ordinal routes, or
alternative integration engines. Exact receipts and cell verdicts are in
`docs/dev-log/simulation-artifacts/2026-08-09-cran07-v4-exact-aa-production/`.

## Implemented

### Covariance grammar

- The 5 x 3 covariance keyword grid has sources `none`, `animal`, `phylo`,
  `spatial`, and `kernel`, crossed with modes `indep`, `dep`, and `latent`.
  `common = TRUE` on `*_indep()` and `unique = TRUE` on `*_latent()` are
  modifiers, not modes. Named `scalar()` and `unique()` families remain
  soft-deprecated compatibility syntax.
- The ordinary decomposition is
  `Sigma = Lambda Lambda^T + Psi`, where `Psi = diag(psi)`, and ordinary
  `latent()` includes this companion by default. Source-specific and kernel
  latent terms are loadings-only by default; request `unique = TRUE` for the
  decomposition. `dep()` estimates a full unstructured Sigma.

### Response families

Per-trait families supported through the engine `family_to_id()` map:
gaussian, binomial (with multi-trial via `cbind(succ, fail)` or
weights), betabinomial, poisson, lognormal, Gamma, nbinom2, tweedie,
Beta, student, truncated_poisson, truncated_nbinom2, delta_lognormal,
delta_gamma, ordinal_probit, and nbinom1. Mixed-family fits are accepted
via `family = list(...)` keyed by trait.

The live map also includes baseline-category-logit `multinomial()` for an
unordered response with three or more categories. Its fixed-effect route is
covered. One multinomial trait may use the separately evidenced
`phylo_latent()` route or share an ordinary `latent()` ordination with other
families, but those routes remain partial. Multiple multinomial traits,
explicit multinomial `unique()` / `indep()` terms, augmented slopes, and other
structured tiers are not admitted.

### Structured-effect representations

- Phylogenetic covariance via sparse `A^-1` (Hadfield & Nakagawa 2010)
  plus optional `phylo_vcv = Cphy` direct VCV input.
- Spatial covariance via SPDE/GMRF helpers substantially rewritten for
  gllvmTMB against the public `fmesher` API after an earlier GPL-3 sdmTMB-derived
  implementation. The current engine estimates an isotropic spatial range;
  it does not estimate directional anisotropy.
- Known sampling covariance via `meta_V(V = V)` for
  multivariate meta-analytic models. `meta_known_V()` is retained
  as a deprecated alias.

### Inference

- ML point estimates by default, plus the guarded Gaussian-only
  `gllvmTMB(REML = TRUE)` pilot, with Laplace approximation under TMB.
- Direct or target-specific profile machinery remains available for fixed
  effects, direct scale parameters, `Lambda` entries, the supported
  phylogenetic-signal cases, and `profile_ci_total_variance()`. The last route
  is a penalty-profile approximation and every returned interval is
  `route-only`. Historical `n_units = 150`, `d` in `{1, 2}` and new
  `n_units = 400`, `d = 2` numerical coverage gates passed, but the retained
  endpoints do not prove constrained-refit convergence and exact target
  attainment. The former exact-cell certificate is therefore withdrawn.
- The former nonlinear profile routes for canonical repeatability,
  communality, correlations, and variance proportions are withdrawn. Explicit
  requests stop with a typed explanation rather than returning bounds.
- `extract_correlations()` defaults to `method = "none"` and returns point
  estimates only. Fisher-z is an opt-in heuristic sensitivity interval,
  `wald` is its compatibility alias, and bootstrap support remains
  route-specific and uncalibrated.
- Per-entry loading intervals require a confirmatory rotation frame. Raw
  `Lambda` supports Wald, profile, and bootstrap routes; standardized
  `rho[t,k] = Lambda[t,k] / sqrt(Sigma_total[t,t])` supports joint-delta
  Wald and Fisher-z Wald routes. Standardized profile intervals are not
  implemented. Symmetric joint-delta Wald intervals are certified only for the
  structurally free strict-lower targets in native pinned unrotated ordinary
  Gaussian three-trait cells `(n_units=150,d=2)`, `(n_units=400,d=1)`, and
  `(n_units=400,d=2)`. The `n_units=150,d=1` cell failed. Pinned diagnostic
  rows, Fisher-z Wald, arbitrary constraints, other rotations, and every
  neighbouring cell remain uncalibrated.

### Variational approximation

Variational approximation (VA) is an opt-in experimental integration route;
native Laplace remains the default. Its present evidence is limited to the
named routes and regimes recorded in the validation register and the Current
limitations and boundaries article. It is not a general estimator or an
inference/calibration claim: VA standard errors, confidence intervals, and
posterior standard deviations are not frequentist calibration certificates.
No MSPL work, low-prevalence expansion, or broad variance-approximation claim
is part of the 0.7.1 trust-release candidate.

### Data shapes

One user-facing entry point, two data shapes:

- `gllvmTMB(value ~ ..., data = df_long, unit = "...", trait = "...")` -- the
  canonical long-format path.
- `gllvmTMB(traits(t1, t2, ...) ~ <compact RHS>, data = df_wide,
  unit = "...")` -- the wide data-frame path. `traits()` captures a
  tidyselect-style column selection, pivots internally, and expands
  the compact RHS (per "Sugar parser" below).

Both shapes go through `gllvmTMB()`. The legacy
`gllvmTMB_wide(Y, ...)` matrix wrapper is **soft-deprecated as of
0.2.0**; new code should use the formula API above. Per-cell weight
matrices (previously the unique selling point of `gllvmTMB_wide()`)
are supported via the long-format API by passing a `weights` column
aligned with `(unit, trait)` rows.

## Sugar parser (PR #39)

The `traits(...)` LHS marker enables a compact wide-format RHS. The
parser performs a `tidyr::pivot_longer()` pre-pass, then rewrites the
following RHS terms before dispatching to the long-format engine:

- `1` -> `0 + trait` (trait-specific intercepts);
- `x` -> `(0 + trait):x` (trait-specific slopes);
- `latent(1 | g)` / `unique(1 | g)` / `indep(1 | g)` / `dep(1 | g)`
  -> the matching `0 + trait | g` long covariance term;
- `phylo_indep(1 | g)` / `phylo_dep(1 | g)` and `spatial_*(1 | g)`
  variants get the same expansion;
- Species-axis phylogenetic calls such as
  `phylo_latent(species, d = K, tree = tree)` and
  `phylo_unique(species, tree = tree)` pass through unchanged
  because they already name their species axis;
- Ordinary random intercepts such as `(1 | batch)` pass through
  unchanged because they are not trait-stacked;
- The literal `-1` is preserved verbatim for intercept control
  (it is not rewritten as `-(0 + trait)`).

The explicit long RHS form (`0 + trait + latent(0 + trait | g)`)
remains accepted on both `value ~ ...` and `traits(...) ~ ...`
left-hand sides, so existing user code does not need to change.

### Sugar parser edge cases

These are intentional design boundaries of the sugar layer, not bugs:

- **Per-cell weight matrices** are not accepted as a matrix on the
  formula-wide path. Per-row weight vectors of length `nrow(data)`
  are replicated across traits automatically. For per-cell weights,
  pass a long-format `weight` column on a long-pivoted data frame
  (`pivot_longer()` your wide weights to match the long fit). The
  legacy `gllvmTMB_wide(Y, weights = W, ...)` matrix-of-weights
  path still works but is soft-deprecated as of 0.2.0.
- **Mixed-family fits** (`family = list(...)` keyed by trait) are
  not intercepted by `traits()`; the family list flows through to
  the long-format engine. The compact RHS still expands correctly.
- **Subtractive controls beyond `-1`** are not part of the recognised
  edge-case set. The parser preserves `-1` literally because it is
  an intercept-control idiom; arbitrary `- x` or `- x:y` terms
  inside a `traits(...)`-marked formula are not specifically
  guarded and may rewrite unexpectedly. If you need a subtractive
  predictor, prefer the long-format path.
- **Conditional formulas** (e.g. two-sided
  `traits(...) | covariate ~ ...`) are not part of the supported
  grammar.
- The factor levels of the auto-generated `trait` column follow the
  order the user supplies to `traits()`, not alphabetical order;
  this controls the column order in `Lambda`, `S`, and `Sigma` and
  the row order in `extract_correlations()`.

## Not yet implemented

- **Random slopes outside the structured keyword contract.** One structured
  slope (`s = 1`) is implemented for the named RE-02 routes and core-family
  cells; lognormal, Student-t, and betabinomial additions remain C1-partial
  under RE-14. Gaussian long-format, slope-only response-column effects now
  support two predictors through `phylo_indep(0 + x1 + x2 | trait)`
  (diagonal) or `phylo_dep(...)` (full), with `phylo_slope()` /
  `animal_slope()` helpers. This does not admit non-Gaussian multi-predictor
  slopes, wide column-predictor grammar, or spatial/kernel/latent slope-only
  variants. Bare `(1 + x | g)` does not provide a first-class trait-stacked
  slope API.
- **Zero-inflated families** (ZINB / ZIP). Cut from the 0.2.0 family
  list; planned for a later phase.
- **SPDE barrier path** (`add_barrier_mesh`) for coastal data. A future barrier
  implementation requires its own design, independently authored code, and
  validation against the native spatial contract.
- **First-class two-level phylogeny + non-phylogeny decomposition**
  (the legacy audit's "two-U" path). The decomposition is currently
  exposed only via the diagnostic cross-checks
  `compare_dep_vs_two_U()` and `compare_indep_vs_two_U()`, plus the
  `extract_two_U_via_PIC()` helper. A first-class single-call API
  is planned per the Codex item #1 doc-validation lane.
- **Bayesian sampling**. Out of scope by design; use `MCMCglmm` or
  `brms` for posterior samples.

In math, the unique-variance diagonal is written as `Psi` (the
diagonal matrix) and `psi` (its per-trait scalar), per the
2026-05-14 notation reversal in `docs/dev-log/decisions.md`.
The function names `compare_dep_vs_two_U()` /
`compare_indep_vs_two_U()` / `extract_two_U_via_PIC()` and the
informal task label "two-U" remain as historical implementation
labels only.

## Pre-CRAN backlog (Phase 5, in flight)

Tracked in `docs/dev-log/shannon-audits/2026-05-12-phase5-cran-readiness-pre-audit.md`.
These are not user-facing limitations; they are CRAN-readiness items:

- ~22 exported functions currently lack `\examples` Rd blocks.
  ~10 need `\dontrun` examples (TMB-fit-dependent); ~6 should be
  demoted to `@keywords internal`; ~4-6 `profile_ci_*` helpers
  share a template.
- Slow-test gating via `RUN_SLOW_TESTS` per the Phase 4 audit
  (`2026-05-12-phase4-test-classification.md`). 30 of 76 test files
  are recovery / identifiability / integration / phylo-misc and
  should be skipped without the env var to keep `R CMD check` fast.

These will land in dedicated Phase 5 PRs before the CRAN submission
window; they do not affect what the public API can model today.
