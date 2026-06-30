# Extractors Contract

**Maintained by:** Emmy (R package architecture / S3 surface)
and Fisher (statistical inference semantics).
**Reviewers:** Curie (test fixtures cross-check), Boole
(extractor-vs-keyword consistency), Rose (validation-debt
audit), Pat (applied user-facing return-value clarity).

Every `extract_*()` function on the `gllvmTMB_multi` class is
a public contract: it must return a well-typed object whose
shape, dimensions, and meaning are stable, documented, and
tested. This doc records the contract for each extractor, its
current coverage state, and the boundary statements
distinguishing what an extractor returns from what it does NOT
return.

## Status discipline

4-state vocabulary (`covered / claimed / reserved / planned`).
Each row in the coverage matrix below labels its (extractor x
regime) cell with one of these states. **Vocabulary
clarification**: this doc uses the parser-syntax 4-state
vocabulary, *not* the validation-debt-register 4-state
vocabulary (`covered / partial / opt-in / blocked`). The
validation-debt register
(`docs/design/35-validation-debt-register.md`, Phase 0A step 7)
will translate between them.

**The promotion rule**: an extractor cell moves from
`claimed` to `covered` only when a `tests/testthat/test-*.R`
file exercises that extractor on a fit of that regime AND the
test makes a concrete assertion about the return value
(shape + numerical value within a documented tolerance).

## Coverage matrix (Phase 0A 2026-05-16 snapshot)

For each extractor, the columns are:

- **G** = Gaussian single-family (the M0 baseline).
- **B** = binomial single-family (the M2 milestone).
- **N** = non-Gaussian single-family
  (Poisson / NB2 / Gamma / Beta / etc., post-CRAN families).
- **M** = mixed-family (`family = list(...)`), the
  unparalleled-capability differentiator per vision item 5
  (non-delta families only; delta families deferred — see
  `docs/design/02-family-registry.md`).

Status legend: `c` covered, `cl` claimed (Phase 0B
verification pending), `r` reserved (planned for M1/M2),
`p` planned (post-CRAN).

| Extractor | G | B | N | M | Notes |
|-----------|---|---|---|---|-------|
| `extract_Sigma(fit, level, part)` | c | cl | cl | cl | per-level $\Sigma = \Lambda\Lambda^\top + \Psi$; `level = "phy"/"spatial"` are variance-share shortcuts, not peer levels |
| `extract_Sigma_table(fit, level, part, measure)` | c | cl | cl | c | report-ready point-estimate table view over `extract_Sigma()`; intervals intentionally absent |
| `extract_Sigma_B(fit)` | c | cl | cl | cl | legacy alias for `level = "B"` ($\equiv$ `"unit"`) |
| `extract_Sigma_W(fit)` | c | cl | cl | cl | legacy alias for `level = "W"` ($\equiv$ `"unit_obs"`) |
| `extract_Omega(fit)` | c | cl | cl | cl | cross-partition integration (phy/spatial shares back into unit-tier) |
| `extract_correlations(fit, method, link_residual)` | c | cl | cl | cl | Fisher-z, Wald, profile, bootstrap |
| `extract_communality(fit)` | c | cl | cl | cl | $H^2 + C^2 + \psi^2 = 1$ partition |
| `extract_repeatability(fit)` | c | cl | cl | cl | ICC / R |
| `extract_phylo_signal(fit)` | c | cl | cl | cl | phylogenetic $H^2$ |
| `extract_residual_split(fit)` | c | cl | cl | cl | OLRE $\sigma^2_d / \sigma^2_e / \sigma^2_{\text{total}}$ |
| `extract_ordination(fit, level)` | c | cl | cl | cl | factor scores (rotation-invariant up to orthogonal transform) |
| `extract_proportions(fit)` | r | r | r | r | delta-family conditional probability — reserved (post-CRAN; depends on delta-family support) |
| `extract_cutpoints(fit)` | r | r | cl | r | ordinal-probit thresholds, including mixed-family fits with ordinal traits |
| `extract_ICC_site(fit)` | c | cl | cl | cl | legacy ICC; superseded by `extract_repeatability()` |
| `bootstrap_Sigma(fit, n_boot, level, what, link_residual)` | c | cl | cl | cl | parametric-bootstrap path |
| `getLoadings(fit, level, rotate)` | c | cl | cl | cl | raw or rotated $\Lambda$ matrix |
| `rotate_loadings(fit, level, method)` | c | cl | cl | cl | none / varimax / promax post-fit rotation |
| `extract_rotated_loadings_table(fit, level, method, loading_scale)` | c | cl | cl | cl | report-ready tidy rows over `rotate_loadings()` for ordination tables and figures |
| `getLV(fit)` | c | cl | cl | cl | legacy ordination alias |
| `getResidualCor(fit)` | c | cl | cl | cl | glmmTMB-style residual correlation matrix |
| `getResidualCov(fit)` | c | cl | cl | cl | glmmTMB-style residual covariance matrix |
| `profile_ci_repeatability(fit)` | c | cl | cl | r | Phase 1b PR #105 |
| `profile_ci_phylo_signal(fit)` | c | cl | cl | r | Phase 1b PR #105 |
| `profile_ci_communality(fit)` | c | cl | cl | r | Phase 1b PR #120 |
| `profile_ci_correlation(fit)` | c | cl | cl | r | Phase 1b PR #122 |
| `profile_targets(fit)` | c | cl | cl | cl | Phase 1b PR #109 (drmTMB-style controlled vocabulary) |
| `tmbprofile_wrapper(fit, target)` | c | cl | cl | cl | Phase 1b PR #109 |
| `confint_inspect(fit, parameter)` | c | cl | cl | cl | Phase 1b PR #121 |
| `coverage_study(fit, R)` | c | cl | cl | r | Phase 1b PR #120 |
| `extract_lv_effects(fit, level, type)` | cl | p | p | p | Design 73 C1 extractor for admitted ordinary unit-tier `latent(..., lv = ~ x)` fits; default public output is the axis / CLV coefficient (`alpha`), with `B_lv = Lambda alpha^T` available as the induced trait-scale effect; calibrated intervals remain gated |
| `compare_loadings(fit1, fit2)` | c | cl | cl | cl | legacy; for two-stage cross-checks |
| `compare_dep_vs_two_psi(fit)` | c | r | r | r | legacy task-label (PR #40 logic) |
| `compare_indep_vs_two_psi(fit)` | c | r | r | r | legacy task-label |

The honest `cl` (claimed) labels are the point of this doc:
none of the non-Gaussian, non-binomial regimes have been
walked through the Phase 0B smoke-test layer (parse + fit +
extractor sanity-check) yet. Phase 0B verifies; Phase 0C
revises the validation-debt register accordingly.

## Per-extractor contracts

The contract for each function defines: argument signature,
return-value shape, key invariants, and rotation /
link-residual / OLRE caveats.

### 1. Covariance family

#### `extract_Sigma(fit, level = c("unit", "unit_obs", "cluster", "phy", "spatial"), part = c("total", "shared", "unique"))`

**Return**: a `T x T` symmetric positive-semidefinite matrix
with row and column names = trait labels.

The `level` argument accepts two conceptually distinct
classes of value. The engine treats both uniformly as
internal $\Lambda$-slot selectors, but users should read
them differently.

**Grouping levels (peer values)** — distinct random-effect
grouping factors:

- `level = "unit"` (default): the full between-unit
  covariance. When phylogenetic or spatial keywords are
  present *at the unit grouping factor* (the canonical
  `unit = species` or `unit = sites` cases), their shares
  are partitions of this level — see
  `extract_Omega()` for the cross-partition integration.
- `level = "unit_obs"`: the within-unit (observation-level)
  covariance.
- `level = "cluster"`: the third-slot cluster-level
  covariance (when a `cluster` argument was provided).

**Within-unit variance-share shortcuts** — kept for direct
engine-internal-slot inspection. Conceptually these are
*parts* of the unit-tier variance, not peers of
`level = "unit"`, in the canonical case where the phylo or
spatial keyword's grouping factor equals `unit`:

- `level = "phy"`: the phylogenetic *share* of the between-
  unit variance, $\Lambda_{\text{phy}}\Lambda_{\text{phy}}^\top
  + \Psi_{\text{phy}}$. Errors with class
  `gllvmTMB_extract_sigma_no_phy` for fits without any
  `phylo_*` term. In the canonical case (`unit = species`),
  this is a partition of `level = "unit"`, not a separate
  grouping level — the distinction matters for users
  coming from the "tier" mental model.
- `level = "spatial"`: the spatial *share* of the between-
  unit variance — same logic. Errors with class
  `gllvmTMB_extract_sigma_no_spatial` for fits without any
  `spatial_*` term.

**Partition within the chosen level** (the `part` argument):

- `part = "total"` (default): $\Sigma = \Lambda\Lambda^\top
  + \Psi$ (shared + unique) *at the chosen level*.
- `part = "shared"`: $\Lambda\Lambda^\top$ alone.
- `part = "unique"`: $\Psi = \text{diag}(\psi^2)$ alone.

"Total" means total within the chosen level, not total
across the model. Cross-level integration is
`extract_Omega()`'s job.

**Invariants**:

- $\Sigma$ is symmetric to numerical precision.
- $\Sigma$ is PSD; eigenvalues $\ge 0$ to numerical
  precision (Gauss + Noether contract).
- The diagonal of $\Sigma_{\text{total}}$ is the sum of
  $\Sigma_{\text{shared}}$ and $\Sigma_{\text{unique}}$
  diagonals.
- For non-Gaussian fits, the diagonal includes the
  per-trait link-residual variance via the `link_residual`
  argument of downstream extractors (this function returns
  the raw model-implied $\Sigma$; link-residual is a
  downstream concern).

**Rotation invariance**: $\Sigma$ itself is rotation-invariant
because $\Lambda\Lambda^\top = (\Lambda Q)(\Lambda Q)^\top$
for any orthogonal $Q$. Tests assert $\Sigma$ identity rather
than $\Lambda$ identity.

#### `extract_Sigma_table(fit, level, part, measure, entries)`

**Return**: a data frame with one row per requested covariance,
variance, or correlation entry. It is a report-ready view over
`extract_Sigma()` or over a `bootstrap_Sigma()` result, not a
second covariance implementation.

Stable columns:

- `estimand`, `trait_i`, `trait_j`, integer indices `i` and `j`;
- `level`, `component`, `matrix`, `estimate`;
- `lower`, `upper`, `interval_method`, `interval_status`;
- `scale`, `validation_row`, `diagonal`, and `triangle`.

`entries = "unique"` returns the diagonal plus upper triangle,
one row per symmetric estimand. `entries = "all"` returns every
matrix cell for heatmaps and plot helpers. `measure = "correlation"`
is allowed only for `part = "total"` because report-ready
correlations should be based on the full
$\Lambda\Lambda^\top + \Psi$ covariance. For fitted-model input,
interval columns are present for table compatibility but deliberately
set to `NA` / `"none"`; interval estimation remains the job of
`extract_correlations()` and `bootstrap_Sigma()`. For `bootstrap_Sigma`
input, the same columns carry bootstrap percentile bounds already
stored in the object, with `interval_method = "bootstrap"` and
row-level `interval_status` values.

Validation-debt rows: `EXT-18` for fitted-model point tables and
`EXT-20` for bootstrap interval rows. Underlying Sigma coverage still
inherits the relevant `extract_Sigma()` / `bootstrap_Sigma()` rows
(`EXT-01`, `EXT-13`, and `MIX-03` for mixed-family fits).

Plot helpers consume the same row schema rather than indexing matrices
directly. `plot_Sigma_table()` draws row-first interval or confidence-eye
views for selected entries (`EXT-19`); `style = "raindrop"` is only a
compatibility alias. `plot_Sigma_heatmap()` draws
matrix-style point-estimate heatmaps from `entries = "all"` rows and
does not display uncertainty intervals (`EXT-27`). Known-truth displays
use `compare_Sigma_table()` plus `plot_Sigma_comparison()` (`EXT-25` /
`EXT-26`).

#### `extract_Sigma_B(fit)` and `extract_Sigma_W(fit)`

Legacy aliases. `extract_Sigma_B(fit) = extract_Sigma(fit,
level = "unit")`; `extract_Sigma_W(fit) = extract_Sigma(fit,
level = "unit_obs")`. Kept for back-compat through 0.2.x;
slated for `lifecycle::deprecate_soft()` in 0.3.0 per Phase
2 export audit (Emmy).

#### `extract_Omega(fit, level)`

**Return**: a `T x T` symmetric matrix representing the
cross-partition integrated covariance — the natural place
where phylogenetic and spatial *shares* re-enter as
partitions of the unit-tier variance rather than as
separate levels. For paired phylogenetic fits with
default `latent()` on the unit grouping factor (or explicit
`latent + unique` compatibility syntax) and `phylo_latent +
phylo_unique` adding a phylogenetically-correlated share to
the same unit-level variance:

$$
\Omega = \Lambda_{\text{phy}}\Lambda_{\text{phy}}^\top
       + \Lambda_{\text{non}}\Lambda_{\text{non}}^\top
       + \Psi
$$

For three-piece fallback fits (when paired is not
identifiable), Ω uses a single non-tier-specific Ψ. See
`docs/design/03-phylogenetic-gllvm.md`.

#### `bootstrap_Sigma(fit, n_boot = 200, level, what, conf, seed, n_cores = 1, progress = TRUE, keep_draws = FALSE, link_residual = c("auto", "none"))`

**Return**: a `list` with elements

- `point_est`: named list of point estimates for the requested
  summaries and levels, such as `Sigma_B`, `R_B`,
  `communality_B`, or `ICC_site`.
- `ci_lower` / `ci_upper`: named lists with empirical percentile
  intervals matching `point_est` shapes.
- `ci_method`: currently `"percentile"`.
- `link_residual`: the link-residual convention used for the point
  estimate and every bootstrap refit summary.
- `conf`, `n_boot`, `n_failed`, `level`, `what`, and optional
  `draws`.

`link_residual = "auto"` matches `extract_Sigma()` and adds
family/link implicit residual variance to non-Gaussian trait
diagonals before computing `Sigma`, `R`, `communality`, and `ICC`.
`link_residual = "none"` returns the fitted model covariance without
link-residual additions. Use `"none"` for validation targets whose DGP
truth is $\Lambda\Lambda^\top + \Psi$ rather than the marginal latent
response variance.

Mixed-family bootstrap is **claimed** — the per-row family
must be preserved in each resample. M1 slice 1.8 in the
function-first roadmap is the validation gate.

### 2. Decomposition family

#### `extract_correlations(fit, method = c("Fisher-z", "Wald", "profile", "bootstrap"), link_residual = c("auto", "none"), level)`

**Return**: a `T x T` correlation matrix (point estimate)
with attribute `confint` carrying the lower / upper bounds
in the chosen method.

The `link_residual = "auto"` default invokes the per-family
link-residual computation (`R/extract-sigma.R`
`link_residual_per_trait()`) before computing Pearson
correlations. This is the latent-scale correlation
guarantee for non-Gaussian fits and is the engine path that
makes mixed-family correlations meaningful.

**Mixed-family contract**: each row's family is consulted
to pick the correct link-residual formula
(see `docs/design/03-likelihoods.md` for the per-family
table). For delta / hurdle families the latent-scale
correlation is *not defined* and `link_residual = "auto"`
errors with class
`gllvmTMB_auto_residual_delta_undefined`
(`check_auto_residual()` safeguard).

**Method semantics**:

- `Fisher-z`: closed-form Fisher's z-transform CI on
  Pearson correlations from the bootstrap distribution.
- `Wald`: Wald CI on the latent-scale correlation
  parameter (cheapest; under-covers near $\pm 1$).
- `profile`: profile-likelihood CI via
  `profile_ci_correlation()` (Phase 1b PR #122).
- `bootstrap`: bootstrap CI from `bootstrap_Sigma()`.

#### `extract_communality(fit, level)`

**Return**: by default a named numeric vector with one entry per trait,
containing

$$
c_t^2 =
\frac{(\Lambda\Lambda^\top)_{tt}}{\Sigma_{tt}},
$$

for the requested `level` (`unit` / internal `B`, or `unit_obs` / internal
`W`). When `ci = TRUE`, the return is a `data.frame` with columns `trait`,
`tier`, `c2`, `lower`, `upper`, and `method`.

For fitted `gllvmTMB_multi` objects, `method = "profile"` delegates to
`profile_ci_communality()`, while `method = "bootstrap"` runs
`bootstrap_Sigma(..., what = "communality")` and returns the resulting
percentile bounds. For existing `bootstrap_Sigma()` objects that already
contain `communality_B` / `communality_W` summaries, `extract_communality()`
reuses the stored point estimates and percentile bounds without rerunning
bootstrap refits (EXT-21). This bootstrap-object path is intentionally a
reporting bridge; it does not compute new intervals.

The companion `plot(type = "communality", boot = boot)` path uses the same
stored `communality` summaries to overlay `c^2` boundary intervals on the
stacked communality / uniqueness bars.

#### `extract_repeatability(fit)`

**Return**: a `data.frame` with one row per trait and
columns `trait`, `R` (the ICC / repeatability), `lower`, `upper`, and
`method`.

For fitted `gllvmTMB_multi` objects, `method = "profile"` currently reports an
honest fallback to `method = "wald"` for full-Sigma repeatability, while
`method = "bootstrap"` runs `bootstrap_Sigma(..., what = "ICC")` with both the
`unit` and `unit_obs` levels. For existing `bootstrap_Sigma()` objects that
already contain `ICC_site`, `extract_repeatability()` reuses the stored point
estimates and percentile bounds without rerunning bootstrap refits (EXT-22).

The companion `plot(type = "integration", boot = boot)` path accepts a raw
`bootstrap_Sigma()` object and pulls repeatability plus communality intervals
directly for the integration dot-and-whisker panel.

#### `extract_phylo_signal(fit)`

**Return**: a `data.frame` with columns `trait`,
`phylo_signal_H2`, plus the per-trait $\Psi$-share scaled
to the partition. Convention from Adams (2014); see
`docs/design/03-phylogenetic-gllvm.md`.

#### `extract_residual_split(fit)`

**Return**: a `data.frame` with one row per trait and
columns `trait`, `sigma2_d` (distribution-specific
link-residual), `sigma2_e` (OLRE additive residual),
`sigma2_total`. For non-OLRE fits, `sigma2_e = 0` and
`sigma2_total = sigma2_d + 0`.

For Gaussian-identity fits, `sigma2_d = 0` and the OLRE
captures all residual variance.

For Bernoulli with logit link, `sigma2_d = pi^2 / 3 ~ 3.290`.

See Nakagawa & Schielzeth (2010) and Nakagawa, Johnson, &
Schielzeth (2017) for the underlying decomposition.

### 3. Multivariate family

#### `extract_ordination(fit, level = c("unit", "unit_obs", "B", "W"))`

**Return**: an `N x d` matrix of factor scores (latent
positions), where $N$ is the number of unique levels at the
requested tier and $d$ is the rank chosen by the user. Row
names = unit IDs; column names = `"LV1", "LV2", ...`.

**Rotation caveat**: factor scores are rotation-invariant
up to an orthogonal transform of the underlying
$\Lambda$. Pat's request: every helper that returns
loadings or ordinations carries a rotation-disclaimer
caption (`getLoadings()` and `rotate_loadings()` already
warn explicitly).

Design 73 adds a C1
`component = c("total", "mean", "innovation")` argument for
predictor-informed latent-score fits. In that regime, `"mean"` returns
`M alpha`, `"innovation"` returns the fitted innovation `e_hat`, and
`"total"` returns `M alpha + e_hat`. The live C1 surface is ordinary
unit-tier Gaussian plus pure binomial logit/probit/cloglog on the TMB
path, plus a narrow complete-response Gaussian and binomial
logit/probit/cloglog Julia bridge point route. Other Julia bridge rows
still accept only `component = "total"`.

#### `extract_lv_effects(fit, level = "unit", type = "axis_effect")`

**Status**: C1 extractor for admitted ordinary unit-tier
`latent(..., lv = ~ x)` fits; Wald SEs are available only when
`se = TRUE` yields a positive-definite `sdreport()`.

For `latent(..., lv = ~ x)` fits, this extractor returns the
predictor-informed latent-score effects. The default public return is
`type = "axis_effect"`, a row-first table for the axis / CLV coefficient
`alpha` with columns `level`, `axis`, `predictor`, `estimate`,
`std.error`, `lower`, `upper`, `rotation_status`,
`uncertainty_status`, and `validation_row`. Axis-effect intervals are
conditional on the fitted loading constraint and axis orientation.
`type = "trait_effect"` returns the induced trait-scale slope surface
$B_\text{lv} = \Lambda\alpha^\top$ with columns `level`, `trait`,
`predictor`, `estimate`, `std.error`, `lower`, `upper`,
`uncertainty_status`, and `validation_row`. Axis-scale `std.error`
values are copied from the fixed-parameter `alpha_lv_B` block when
available; trait-scale `std.error` values are copied from the TMB
delta-method `ADREPORT(B_lv_unit)` output. Both are labelled
`wald_sdreport_no_ci_validation` because coverage calibration remains
target- and regime-specific. Narrow Julia bridge `X_lv` rows return
point-estimate `alpha_lv`/`lv_effects` rows unless a retained Wald
payload is present; bridge interval payloads are reader plumbing only
until the named Julia bridge CI rows pass.

#### `getLoadings(fit, level = "unit", rotate = c("none", "varimax", "promax"))`

**Return**: a `T x d` matrix of loadings ($\Lambda$). Row
names = trait labels; column names = `"LV1", ..., "LVd"`.

`rotate = "varimax"` applies a post-fit orthogonal rotation, ordered by shared
variance and sign-anchored for interpretation; the rotated $\Lambda$ satisfies
$\Lambda_{\text{rotated}}\Lambda_{\text{rotated}}^\top =
\Lambda\Lambda^\top$. `rotate = "promax"` applies an oblique rotation for users
who deliberately want correlated latent axes.

#### `rotate_loadings(fit, level, method)`

**Return**: a `list` with elements `Lambda` (rotated
loadings), `scores` (rotated latent scores), `T` (rotation matrix),
`axis_variance`, `axis_order`, `axis_sign`, and `anchor_traits`.

#### `extract_rotated_loadings_table(fit, level, method, loading_scale)`

**Return**: a data frame with one row per trait and latent
axis. Stable columns are `level`, `trait`, `axis`, `loading`,
`abs_loading`, `axis_variance`, `axis_share`, `rotation`,
`order_axes`, `sign_anchor`, `anchor_trait`, and
`loading_scale`.

The function is a row-first view over `rotate_loadings()`, not
a second rotation implementation. It uses the same rotation
method, shared-variance axis ordering, and sign-anchoring
rules as `plot(type = "ordination")`. `loading_scale = "raw"`
returns the fitted loading scale; `loading_scale =
"standardized"` divides each trait's loading by the square root
of that trait's model-implied total variance, matching
`plot(type = "ordination", standardize_loadings = TRUE)`.
`axis_variance` and `axis_share` are computed from the rotated
raw loading matrix before optional standardization because
those values define the axis-ordering convention.

Validation-debt row: `EXT-28`. Covered tests rebuild the
matrix from tidy rows, assert varimax covariance invariance
under ordering and sign flips, and check explicit anchor-trait
signs.

#### `getLV(fit)`

Legacy alias for `extract_ordination(fit)`. Kept through
0.2.x; slated for `lifecycle::deprecate_soft()` in 0.3.0.

### 4. Family-specific extractors

#### `extract_cutpoints(fit)`

**Return**: a `T x (K - 1)` matrix of ordered cutpoints
where $K$ is the number of ordinal categories. Defined only
for fits where at least one trait has
`family = ordinal_probit()`. Errors with class
`gllvmTMB_extract_cutpoints_not_ordinal` otherwise.

Covered for ordinal-probit traits, including mixed-family fits
where only some traits are ordinal. Non-ordinal fits fail loudly
with the class above rather than returning an empty or ambiguous
threshold table.

#### `extract_proportions(fit)`

Delta / hurdle conditional probability. **Reserved** for
0.3.0+ because delta families are deferred (vision +
registry). The function exists for parity with sdmTMB but
its return value is undefined under the current engine.

#### `extract_ICC_site(fit, link_residual)`

Legacy; superseded by `extract_repeatability()`. Kept
through 0.2.x.

### 5. Profile-CI extractors

The Phase 1b validation milestone added a family of
profile-likelihood CI helpers:

#### `profile_ci_repeatability(fit, trait_idx, level)` (PR #105)

**Return**: a `data.frame` with `trait`, `lower`, `upper`,
`level`. Uses the Lagrange fix-and-refit approach
documented in `R/profile-derived.R`.

#### `profile_ci_phylo_signal(fit, trait_idx, level)` (PR #105)

Same shape as `profile_ci_repeatability()`.

#### `profile_ci_communality(fit, ...)` (PR #120)

**Return**: same shape, computing CI on each of
$H^2_t / C^2_t / \psi^2_t$ separately.

#### `profile_ci_correlation(fit, trait_pair, level)` (PR #122)

**Return**: a `data.frame` with `trait1`, `trait2`,
`lower`, `upper`, `level`. CI on the latent-scale
correlation between the named trait pair.

#### `profile_targets(fit, ready_only = FALSE)` (PR #109)

**Return**: a `data.frame` with columns `parm`,
`target_class`, `dpar`, `term`, `tmb_parameter`, `index`,
`estimate`, `link_estimate`, `scale`, `transformation`,
`target_type`, `profile_ready`, `profile_note`.
drmTMB-style controlled vocabulary; consulted by
`confint(fit, method = "profile")`.

#### `tmbprofile_wrapper(fit, target, ...)` (PR #109)

Low-level wrapper around `TMB::tmbprofile()` consulted by
`profile_ci_*()` and `confint_inspect()`.

#### `confint_inspect(fit, parameter, method)` (PR #121)

**Return**: a `data.frame` of (parameter grid, deviance,
excess-over-threshold) + a ggplot showing profile shape.
Used by `troubleshooting-profile.Rmd` to visualise
profile-curve anatomy.

#### `coverage_study(fit, R, families, dims)` (PR #120)

**Return**: a `list` with elements `coverage_matrix`,
`bias_matrix`, `runtime_summary`. The Phase 1b ≥ 94 %
empirical-coverage gate is realised by this function.
M3 milestone close gate consumes it.

### 6. Glue extractors

#### `getResidualCor(fit)` and `getResidualCov(fit)`

glmmTMB-style residual correlation / covariance matrices.
Used by users coming from `glmmTMB::VarCorr()` for API
familiarity. Identical to `extract_correlations(fit)` and
`extract_Sigma(fit, part = "unique")` modulo presentation.

### 7. Legacy comparison helpers

#### `compare_dep_vs_two_psi(fit)`, `compare_indep_vs_two_psi(fit)`, `compare_loadings(fit1, fit2)`

Two-stage cross-check helpers documented in
`docs/design/03-phylogenetic-gllvm.md`. Function names
retain the legacy "two_psi" task label per PR #40 logic;
math prose uses Ψ notation. These are kept through 0.2.x
and revisited in Phase 2 export audit.

### 8. Coevolution extractors (Design 65)

Added with the cross-lineage coevolution engine (#494) and the
salvage of the module/diagnostic layer (gllvmTMB #500). All are
point-estimate only — no uncertainty, rank-selection, in-engine
ρ estimation, or null-threshold calibration (stated in the return
`note`). Status: `partial` (register COE-03/COE-04).

#### `extract_coevolution_modules(fit, level, row_traits, col_traits, scale = c("shape", "effect"), n_modules = NULL, tol)`

Module / community decomposition of the cross-lineage covariance.
`fit` must be a `gllvmTMB_multi`; `level` is the kernel level
(e.g. `"cross"` for a `kernel_latent(..., name = "cross")` fit, or
the named source tier). Reads the shared covariance via
`extract_Sigma(level, part = "shared")`, takes the
`row_traits × col_traits` cross-block, and returns an SVD-based
module decomposition. **Returns** an object of class
`gllvmTMB_coevolution_modules` (a list): `R` (the
`row_traits × col_traits` cross-correlation matrix, named),
`modules` (data frame: `component`, `module`, `singular_value`,
`squared_share`), `row_axes` / `col_axes` (per-module axis tables),
`level`, `scale`, `row_traits`, `col_traits`, and `note`. `scale =
"effect"` rescales by the level ρ. Recovery-tested on the shipped
`coevolution-kernel-example.rds` (`test-coevolution-modules-salvage.R`).

#### `diagnose_kernel_separability(..., thresholds = c(near_orthogonal = 0.25, high = 0.70))`

Pre-fit diagnostic: Frobenius-style similarity between two or more
**dense fixed kernel matrices** (same dimensions). **Returns** an
object of class `gllvmTMB_kernel_separability` (a list): `similarity`
(symmetric tier × tier matrix, unit diagonal), `pairs` (data frame:
`level_1`, `level_2`, `similarity`, `overlap_class`,
`recommendation`), `thresholds`, and `note`. High overlap means
component-specific Γ_shape separation is weak evidence — report one
network-conditioned covariance unless simulations justify the split.
Pure-R; no fit required.

## Rotation-invariance contract

Per `docs/design/03-likelihoods.md` and the
rotation-disclaimer captions Pat flagged 2026-05-14: any
extractor whose return value depends on $\Lambda$ identity
(not $\Lambda\Lambda^\top$) is rotation-ambiguous. The
contract:

| Extractor | Rotation-invariant? | Convention |
|-----------|---------------------|------------|
| `extract_Sigma`, `extract_Sigma_B`, `extract_Sigma_W`, `extract_Omega` | ✅ yes | uses $\Lambda\Lambda^\top$ |
| `extract_correlations` | ✅ yes | derived from $\Sigma$ |
| `extract_communality`, `extract_repeatability`, `extract_phylo_signal`, `extract_residual_split` | ✅ yes | partition of $\Sigma$ |
| `bootstrap_Sigma` | ✅ yes | resamples $\Sigma$, not $\Lambda$ |
| `getLoadings`, `rotate_loadings` | ❌ no | $\Lambda$ identity; warn |
| `extract_ordination`, `getLV` | ❌ no | factor scores; warn |
| `extract_lv_effects(type = "trait_effect")` | ✅ yes, after Design 73 implementation | reports $B_\text{lv} = \Lambda\alpha^\top$ |
| `extract_lv_effects(type = "axis_effect")` | ❌ no, after Design 73 implementation | raw `alpha`; warn |
| `compare_loadings` | partial | uses Procrustes alignment |

The rotation-disclaimer caption (Darwin's rotational-
ambiguity enforcement) is added to every rotation-variant
helper's roxygen and to every article that prints loadings
or ordinations. The Phase 1c article-port pass enforces
this.

## Link-residual contract

For non-Gaussian fits, the latent-scale per-trait residual
variance is added to the diagonal of $\Sigma$ when
`link_residual = "auto"` is consulted. The covered
extractors that surface this argument:

- `extract_correlations(fit, link_residual = "auto" | "none")`
- `extract_ICC_site(fit, link_residual = "auto" | "none")` (legacy)
- Internally, all `extract_*()` that read the diagonal of
  $\Sigma$ for OLRE / repeatability / phylo-signal /
  communality computations consult `link_residual_per_trait()`
  in `R/extract-sigma.R`.

**Auto-safeguard** (`check_auto_residual()`, PR #104):

- Errors when delta / hurdle family is present
  (`class = "gllvmTMB_auto_residual_delta_undefined"`).
- Warns when ordinal-probit family is present (the latent
  residual is fixed to 1 by construction; `auto` is OK
  but `none` is cleaner).
- Errors when a single trait mixes incompatible families
  (binomial + Poisson on the same trait).

## Boundary statements — what extractors do NOT do

The honest scope-boundary discipline (Pat + Rose + drmTMB
team pattern) requires every extractor doc to state what it
does NOT do. From this contract:

- **No fitted-value computation**: `predict.gllvmTMB_multi()`
  is the entry point for fitted values; extractors return
  parameters / their transformations.
- **No fitted-scale / response-scale conversion**:
  `extract_*()` always returns on the latent (link) scale.
  Response-scale fitted values belong to `predict(type = "response")`,
  which dispatches by row / trait for mixed-family fits.
- **No probability-output for delta / hurdle**:
  `extract_proportions()` is reserved for the post-CRAN
  delta-family extension.
- **No mixed-family latent-scale correlation for delta /
  hurdle**: the two-scales problem makes this undefined; see
  vision item 5 boundary statement.
- **No rotation-pinning**: `rotate_loadings()` provides
  post-fit varimax / promax for users who want a fixed
  rotation, but the engine does not pin $\Lambda$ during
  fitting; the rotation chosen at fit time is identifiability-
  algorithm-dependent.
- **No Hessian / SE on derived quantities except via
  profile-CI helpers**: Wald SEs on $H^2$ etc. are not
  exposed; profile CI is the canonical path (per Phase 1b
  validation milestone).
- **No automatic dispatch on `confint(fit, parm,
  method = "profile")` for arbitrary parameters**: only the
  parameters listed in `profile_targets(fit, ready_only =
  TRUE)` have a defined profile path; others error with
  `profile_note != "ready"`.

## Cross-references

- `docs/design/00-vision.md` — vision item 5 (mixed-family
  latent-scale correlations restricted to non-delta
  families); audience scope.
- `docs/design/01-formula-grammar.md` — Status map listing
  which keyword combinations the parser accepts; the
  extractor table here mirrors that vocabulary.
- `docs/design/02-family-registry.md` — per-family
  link-residual rule; delta-family deferral.
- `docs/design/03-likelihoods.md` — per-family likelihood
  contracts; link-residual formulas; mixed-family per-row
  routing.
- `docs/design/03-phylogenetic-gllvm.md` — paired vs
  three-piece phylo fallback for `extract_Omega()`.
- `docs/design/04-random-effects.md` — random-slope cap
  for M1; coverage of `extract_*()` on random-slope fits
  is M1-scoped.
- `docs/design/05-testing-strategy.md` — test layers per
  extractor; what counts as `covered`.
- `docs/design/35-validation-debt-register.md` (Phase 0A
  step 7) — the row-by-row ledger linking advertised
  extractor capability to test evidence.

## Persona-active engagement

- **Emmy** (lead): S3 surface coherence. Owns the
  return-value contract for each extractor; signs off on
  any new extractor's argument signature and return shape.
  Owns `lifecycle::deprecate_soft()` decisions for legacy
  aliases.
- **Fisher** (lead): statistical-inference semantics. Owns
  the link-residual contract, the profile-CI extractor
  semantics, the rotation-invariance contract for derived
  quantities.
- **Curie** (review): test-fixture cross-check. Each
  extractor's coverage cell in the matrix above maps to a
  `tests/testthat/test-*.R` file with concrete assertions;
  Curie audits this mapping in Phase 0B.
- **Boole** (review): extractor-vs-keyword consistency.
  Every keyword that produces an estimable parameter has a
  defined extractor path; Boole audits the keyword-grid x
  extractor matrix for completeness.
- **Rose** (review): validation-debt audit. The honest
  `claimed` labels in the coverage matrix above feed
  directly into the validation-debt register.
- **Pat** (review): applied user-facing return-value
  clarity. Every return-value contract that prints to the
  console needs a clear S3 print method (Phase 1c).

Ada (orchestrator) confirms alignment between this doc and
the vision's "user-first / transparent / reproducible"
principles.

## How this doc grows

This is the contract surface as of 2026-05-16. The doc
grows in three ways:

1. **New extractors** added with each milestone (M1 mixed-
   family rigour; M2 binary IRT extras; M3 reproducible
   coverage). Every new extractor adds a row to the
   coverage matrix and a per-extractor section in this doc.
2. **Coverage promotions** as Phase 0B walks `claimed`
   cells to `covered`. The matrix above is the audit input;
   Phase 0B's after-task report attaches a diff against
   this matrix.
3. **Deprecations** as Phase 2 export audit retires legacy
   aliases (`extract_Sigma_B`, `extract_Sigma_W`,
   `extract_ICC_site`, `getLV`, the comparison helpers).
   Each retirement adds a `lifecycle::deprecate_soft()`
   layer and updates the matrix to reflect the new public
   surface.

This doc is **not** a roxygen replacement. Every extractor
function still carries full roxygen with `@param` + `@return`
+ `@examples`. This doc is the cross-extractor consistency
contract.
