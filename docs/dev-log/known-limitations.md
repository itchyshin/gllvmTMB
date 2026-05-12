# Known limitations

Single source of truth for what `gllvmTMB` does and does not currently
support. The `after-task-audit` skill greps this file for terms like
"rejected", "only diagonal", "planned" to catch stale wording. Update
this file in the same PR that changes the supported surface, so the
durable record never lags the code.

Last refreshed 2026-05-12 (post-PR #39 sugar pivot; Phase 5
CRAN-readiness pre-audit per PR #44).

## Implemented

### Covariance grammar

- The 3 x 5 covariance keyword grid (correlation x mode):
  - none: `unique`, `indep`, `dep`, `latent`;
  - phylogenetic: `phylo_scalar`, `phylo_unique`, `phylo_indep`,
    `phylo_dep`, `phylo_latent`, `phylo_slope`;
  - spatial: `spatial_scalar`, `spatial_unique`, `spatial_indep`,
    `spatial_dep`, `spatial_latent`.
- The decomposition mode `latent + unique` paired:
  `Sigma = Lambda Lambda^T + diag(s)`. Standalone `latent()` is the
  no-residual reduced-rank subset; standalone `unique()` is the
  marginal independent mode and is equivalent to `indep()`; `dep()`
  estimates a full unstructured Sigma.

### Response families

Per-trait families supported through the engine `family_to_id()` map:
gaussian, binomial (with multi-trial via `cbind(succ, fail)` or
weights), betabinomial, poisson, lognormal, Gamma, nbinom2, tweedie,
Beta, student, truncated_poisson, truncated_nbinom2, delta_lognormal,
delta_gamma, ordinal_probit. Mixed-family fits are accepted via
`family = list(...)` keyed by trait.

### Structured-effect representations

- Phylogenetic covariance via sparse `A^-1` (Hadfield & Nakagawa 2010)
  plus optional `phylo_vcv = Cphy` direct VCV input.
- Spatial covariance via the SPDE/GMRF approximation inherited from
  `sdmTMB`; supports isotropic and anisotropic mesh choices.
- Known sampling covariance via `meta_known_V(V = V)` for
  multivariate meta-analytic models.

### Inference

- ML / REML point estimates with Laplace approximation under TMB.
- Profile-likelihood confidence intervals for derived quantities
  (repeatability, communality, phylogenetic signal, pairwise
  correlations).
- Fisher-z, Wald, and bootstrap intervals are also exposed via
  `extract_correlations(method = ...)` with `fisher-z` as the
  default.

### Data shapes

Two user-facing entry points, both reach the same long-format engine:

- `gllvmTMB(value ~ ..., data = df_long, unit = "...")` -- the
  canonical long-format path.
- `gllvmTMB(traits(t1, t2, ...) ~ <compact RHS>, data = df_wide,
  unit = "...")` -- the wide data-frame path. `traits()` captures a
  tidyselect-style column selection, pivots internally, and expands
  the compact RHS (per "Sugar parser" below).
- `gllvmTMB_wide(Y, ...)` -- the wide matrix wrapper for matrix-first
  workflows (and the only path that accepts per-cell weight matrices).

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

- **Per-cell weight matrices** are not accepted on the formula-wide
  path. Per-row weight vectors of length `nrow(data)` are replicated
  across traits automatically. For per-cell weights, use the matrix
  entry point `gllvmTMB_wide(Y, weights = W, ...)`.
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

- **Random slopes** via the bar syntax `(1 + x | g)`. Currently only
  intercept-only random terms are supported on the structured-effect
  paths (`latent`, `unique`, `indep`, `dep`, and their phylogenetic
  / spatial variants). Random slopes via ordinary `(1 + x | g)` for
  non-structured random effects are accepted in the formula but flow
  through to the long-format engine without trait-stacking. A
  first-class trait-stacked random-slope API is planned.
- **Zero-inflated families** (ZINB / ZIP). Cut from the 0.2.0 family
  list; planned for a later phase.
- **SPDE barrier path** (`add_barrier_mesh`) for coastal data.
  Planned; the upstream `sdmTMB` code path is GPL-3-compatible and
  re-import is straightforward.
- **First-class two-level phylogeny + non-phylogeny decomposition**
  (the legacy audit's "two-U" path). The decomposition is currently
  exposed only via the diagnostic cross-checks
  `compare_dep_vs_two_U()` and `compare_indep_vs_two_U()`, plus the
  `extract_two_U_via_PIC()` helper. A first-class single-call API
  is planned per the Codex item #1 doc-validation lane.
- **Bayesian sampling**. Out of scope by design; use `MCMCglmm` or
  `brms` for posterior samples.

In math, the unique-variance diagonal is written as `S` (the
diagonal matrix) and `s` (its diagonal vector), per the
2026-05-12 naming convention in `docs/dev-log/decisions.md`.
The function names `compare_dep_vs_two_U()` /
`compare_indep_vs_two_U()` / `extract_two_U_via_PIC()` and the
informal task label "two-U" remain as is.

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
