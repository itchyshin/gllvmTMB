# gllvmTMB (development version)

## Sigma estimate-vs-truth plot helper (2026-05-21)

* **`plot_Sigma_comparison()`** plots `compare_Sigma_table()` rows as row-labelled error plots or estimate-vs-truth scatter plots for simulation and teaching figures (EXT-26). IN: example articles can show `estimate - truth` without hand-building ggplot scaffolding. PARTIAL: this is a visual comparison helper only; it does not run simulations, compute intervals, or validate calibration. PLANNED: article-specific calibration summaries remain future visualization work.

## Sigma estimate-vs-truth table helper (2026-05-21)

* **`compare_Sigma_table()`** joins report-ready `extract_Sigma_table()` rows to a supplied covariance or correlation truth matrix for simulation and teaching figures (EXT-25). IN: example articles can build estimate-vs-truth tables without hand-indexing matrices. PARTIAL: this is a table helper only; use `plot_Sigma_comparison()` for the current visual layer, and keep richer calibration summaries as future visualization work.

## Bootstrap provenance in plot metadata (2026-05-21)

* **`plot_correlations()` and `plot_Sigma_table()`** now preserve extractor notes in `attr(p, "gllvmTMB_meta")$notes`, including cached bootstrap provenance such as `n_boot`, failed refits, and confidence level when the input came from `bootstrap_Sigma()` (EXT-19 / EXT-20 / EXT-24). IN: report and article code can audit interval provenance from the plot object. PARTIAL: this records existing extractor notes only; it does not compute new intervals or validate bootstrap calibration. PLANNED: richer article-level provenance summaries remain future reporting work.

## Cached morphometrics bootstrap plot fixture (2026-05-21)

* **Morphometrics article fixture** now ships a small cached `bootstrap_Sigma(..., what = "R")` object and uses it to render `plot_correlations(boot, style = "raindrop")` plus `plot(type = "correlation_ellipse", boot = boot)` without running bootstrap refits during pkgdown builds (MIS-22 / EXT-23 / EXT-24). IN: the article demonstrates the direct bootstrap plotting path on a reproducible stored object. PARTIAL: the fixture is for teaching and visual QA, not interval-calibration evidence for a scientific claim. PLANNED: fuller bootstrap calibration belongs in simulation-grid or study-specific workflows.

## Direct bootstrap correlation plots (2026-05-21)

* **`plot_correlations()`** now accepts `bootstrap_Sigma()` objects containing `R_B` / `R_W` summaries and converts them to the same row-first correlation plotting schema used by `extract_correlations()` rows (EXT-24). IN: users can call `plot_correlations(boot, style = "raindrop")` after `bootstrap_Sigma(..., what = "R")` without hand-building pairwise rows. PARTIAL: this is a display bridge only; it does not run bootstrap refits, and matrix-style truth overlays remain article code. PLANNED: rendered article examples using stored bootstrap fixtures remain future Figure-3 QA work.

## Correlation ellipse bootstrap intervals (2026-05-21)

* **`plot(type = "correlation")` and `plot(type = "correlation_ellipse")`** now accept a `bootstrap_Sigma()` object through `boot` and merge stored `R_B` / `R_W` percentile bounds into the plotted correlation data (EXT-23). IN: heatmap and ellipse plot metadata now report interval availability, and the ellipse plot marks supplied intervals that do not cross zero with black borders and stars. PARTIAL: the plot does not run bootstrap refits and only uses correlation summaries already present in the bootstrap object. PLANNED: vdiffr snapshots and broader hidden/technical Figure-3 QA remain future work.

## Repeatability bootstrap interval rows (2026-05-21)

* **`extract_repeatability()`** now accepts `bootstrap_Sigma()` objects containing `ICC_site` summaries and returns the stored per-trait repeatability estimates plus percentile `lower` / `upper` columns (EXT-22). IN: bootstrap repeatability already computed by `bootstrap_Sigma(..., what = "ICC", level = c("unit", "unit_obs"))` can be reused without rerunning refits, and `plot(type = "integration", boot = boot)` now accepts a raw `bootstrap_Sigma()` object for repeatability and communality whiskers. PARTIAL: this reuses bootstrap-object summaries only; fitted-model calls still compute their own profile, Wald, or bootstrap intervals through `extract_repeatability(fit, method = ...)`, and the integration plot remains object-shape tested rather than vdiffr snapshot tested. PLANNED: a broader Figure-3 visual audit remains the next inference-plot step.

## Communality bootstrap interval rows (2026-05-21)

* **`extract_communality()`** now accepts `bootstrap_Sigma()` objects containing `communality` summaries and returns the stored per-trait point estimates plus percentile `lower` / `upper` columns when `ci = TRUE` (EXT-21). IN: bootstrap communalities already computed by `bootstrap_Sigma(..., what = "communality")` can be reused in reports without rerunning refits, and `plot(type = "communality", boot = boot)` can overlay `c^2` boundary intervals on the stacked communality / uniqueness bars. PARTIAL: this reuses bootstrap-object summaries only; fitted-model calls still compute their own profile or bootstrap intervals through `extract_communality(fit, ci = TRUE, method = ...)`, and the communality plot is still object-shape tested rather than vdiffr snapshot tested. PLANNED: a broader Figure-3 visual audit remains the next inference-plot step.

## Bootstrap Sigma table rows (2026-05-21)

* **`extract_Sigma_table()`** now accepts `bootstrap_Sigma()` objects and returns the same report-ready row schema with bootstrap percentile `lower` / `upper` columns filled in (EXT-20). IN: Sigma and correlation summaries already present in the bootstrap object can be converted to tidy rows and passed directly to `plot_Sigma_table()` for interval forests or raindrop compatibility displays. PARTIAL: this does not compute bootstrap intervals itself and does not add shared/unique component covariance intervals; communality and repeatability reuse are covered separately by EXT-21 and EXT-22. PLANNED: broader Figure-3 visual QA remains future work.

## Covariance/correlation plot helpers (2026-05-21)

* **`plot_correlations()` and `plot_Sigma_table()`** are new ggplot helpers for report-ready covariance and correlation rows. IN: tidy rows from `extract_correlations()` and `extract_Sigma_table()` can be drawn as forest plots or raindrop compatibility displays with metadata attached to `gllvmTMB_meta` / `gllvmTMB_data` (EXT-19). The first public integrations are in the README example, Get Started, Morphometrics, and Covariance/correlation articles. PARTIAL: these helpers display supplied finite interval bounds but do not compute new intervals; rows without finite interval bounds are shown as open points, and `plot_Sigma_table(style = "raindrop")` needs interval-bearing input rows. For fitted correlations, open points can often be investigated with `extract_correlations(..., method = "bootstrap")`; Sigma-table raindrops need bootstrap-derived or otherwise interval-bearing rows. Raindrops show frequentist compatibility, not posterior density, and omit CI lines by default so the midpoint and shape carry the display. Set `show_intervals = TRUE` to overlay interval lines when needed. PLANNED: hidden/technical article integration and vdiffr snapshots remain future figure work.

## Missing response cells (2026-05-21)

* **Response `NA`s are now accepted in both long-format and wide `traits(...)` data.** IN: missing unit-trait response cells are dropped before fitting, preserving other observed traits for the same unit; `cbind(successes, failures)` rows are dropped when either response component is missing; weights are subset to retained response rows before validation (MIS-21). PARTIAL: this is response-missingness support only. Missing predictors, grouping variables, design-matrix entries, or all-missing traits still require user-side data cleaning or explicit modelling decisions.

## Report-ready Sigma tables (#233 follow-up, 2026-05-21)

* **`extract_Sigma_table()`** is a new report-ready table view over `extract_Sigma()` for covariance and correlation entries, with stable columns for `estimand`, trait pair, level, component, estimate, interval status, scale, validation row, and matrix position. IN: point-estimate Sigma/Psi/R tables for levels already handled by `extract_Sigma()` are covered by EXT-18, with underlying mixed-family Sigma evidence in MIX-03. PARTIAL: fitted-model interval columns are intentionally `NA` / `none`; use `extract_correlations()` or `bootstrap_Sigma()` for interval estimates, and `compare_Sigma_table()` / `plot_Sigma_comparison()` for known-truth comparisons. PLANNED: richer article-specific calibration summaries remain future work.

## `meta_V()` formula-marker syntax (#227, 2026-05-20)

* **`meta_V()`** now uses `meta_V(V = V)` or `meta_V(V, type = "exact")` as the canonical known-sampling-covariance formula marker. IN: exact additive known-V workflows remain the implemented surface (MET-01 / MET-02), and wide `traits(...)` formulas now preserve `meta_V()` as a covariance marker. PARTIAL: single-V statistical validation is still smoke-level under MET-01. PLANNED: `type = "proportional"` remains blocked under MET-03 and now errors explicitly rather than being silently treated as exact. The older parser spelling `meta_V(value, V = V)` and deprecated alias `meta_known_V(V = V)` remain accepted for compatibility.

## Bootstrap covariance scale control (M3.3a, 2026-05-19)

* **`bootstrap_Sigma()`** gains `link_residual = c("auto", "none")`, matching `extract_Sigma()` so bootstrap point estimates and refit summaries can either include family/link implicit residuals (`"auto"`, the existing default) or report the fitted latent + unique covariance only (`"none"`). IN: mixed-family bootstrap refits still preserve per-row family dispatch (MIX-08) and the default link-residual formulas remain covered (MIX-09). PARTIAL: non-Gaussian bootstrap inference remains experimental under EXT-13 / CI-08 / CI-10 until the M3 target-explicit grid is rerun with the corrected `Sigma_unit_diag` convention.

## Robust modelling diagnostics and start provenance (M3.4, 2026-05-19)

* **`check_gllvmTMB()`** is a new machine-readable fit-health table for `gllvmTMB_multi` fits. It reports optimizer convergence, maximum gradient, `sdreport()` availability, `pdHess`, maximum fixed-effect SE, restart-history availability, selected restart, and simple boundary flags. `gllvmTMBcontrol(se = FALSE)` now intentionally skips `TMB::sdreport()` and keeps the point-estimate fit for bootstrap/profile uncertainty workflows. `pdHess = FALSE` is reported as an inference / identifiability warning, not automatic proof that point estimates or rotation-invariant covariance summaries are unusable. Fits now also retain `restart_history`, `start_provenance`, `fit_health`, and `sdreport_error` fields so multi-start, residual-start, simpler-start, and optimizer-fallback workflows can be audited before they are promoted by M3 target-explicit simulation evidence.

## phylo_* `A =` / `Ainv =` aliases (M2.8b, 2026-05-17)

* The 5 `phylo_*` grid keywords (`phylo_scalar`, `phylo_unique`,
  `phylo_indep`, `phylo_dep`, `phylo_latent`) now accept **`A =`**
  and **`Ainv =`** as byte-equivalent aliases for **`vcv =`**.
  Aligns phylo_* with the M2.8 `animal_*` family's A-vs-V naming
  convention (A for relatedness, V for sampling variance —
  reserved for `meta_V()`, with `meta_known_V()` retained as a
  deprecated alias). The legacy `vcv =` continues to
  work unchanged through v0.3.0. Supplying both `vcv` and `A`
  (or both `vcv` and `Ainv`) errors with a typed message.

## New exports (M2.8 animal-model keyword family, 2026-05-17)

* **`animal_scalar()`, `animal_unique()`, `animal_indep()`,
  `animal_dep()`, `animal_latent()`, `animal_slope()`** — the
  `animal_*` keyword family for animal-model GLLVMs with
  pedigree-derived additive-genetic relatedness. Each keyword
  parallels its `phylo_*` sibling exactly; the three input forms
  `pedigree =` (3-column id/sire/dam), `A =` (dense relatedness
  matrix), and `Ainv =` (sparse precision; densified internally
  for v0.2.0) are all accepted. The keyword family expands the
  covariance keyword grid from **3 × 5 to 4 × 5**, with rows now
  going from finest-grained (individual pedigree) to broadest
  (geographic). Per
  [Design 14](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/14-known-relatedness-keywords.md).

* **`pedigree_to_A()`** — exported helper that computes the
  dense numerator-relationship matrix A from a 3-column pedigree
  via Henderson's (1976) recursive formula.

**A vs V naming boundary.** The new `animal_*` family uses **A**
/ **Ainv** / **pedigree** for relatedness inputs. The separate
`meta_V()` keyword uses **V** for *sampling variance* in
meta-analysis; `meta_known_V()` is the deprecated alias. Existing
`phylo_*(vcv = ...)` keeps working through v0.3.0; `A =` /
`Ainv =` aliases shipped 2026-05-17 (M2.8b).

## New exports (Phase 1b validation milestone)

* **`gllvmTMB_check_consistency(fit, n_sim = 100L, seed = NULL,
  estimate = FALSE)`** -- thin wrapper around
  `TMB::checkConsistency()` that tests whether the approximate
  marginal score is centred at zero. A non-centred score is a
  sign that the Laplace approximation is **unreliable** for the
  fit -- the random-effects posterior is far from Gaussian or
  the data don't constrain the random effects well. Complementary
  to `sanity_multi()` (structural / convergence checks) and
  `check_identifiability()` (Procrustes-aligned loadings recovery
  across simulate-refit replicates); slower than both but the
  only diagnostic that targets the **Laplace approximation itself**
  rather than the optimisation outcome or the parameter
  identification. Returns an object of class
  `gllvmTMB_check_consistency` with `$marginal_p_value`,
  `$marginal_bias` (per-parameter), `$joint_p_value`
  (when `estimate = TRUE`), `$flagged_parameters`,
  `$diagnostics`, `$raw` (the full TMB::checkConsistency()
  return). Diagnostic vocabulary: `"centred"` (well-behaved),
  `"marginal_score_non_centred"`, `"joint_score_non_centred"`,
  `"information_matrix_singular"`, `"marginal_p_value_unavailable"`.
  Audit + TMB-report recommendation 2026-05-15.
* **`confint_inspect(fit, parm)`** -- visual-verification companion
  to `confint(method = "profile")`. Returns the full profile-
  likelihood curve, the deviance bounds, a Wald-vs-profile
  comparison, and (when `ggplot2` is available) a ggplot showing
  the curve with MLE + chi-squared threshold + both profile and
  Wald bounds. Diagnostic flags catalogue the four canonical
  failure modes documented in the troubleshooting-profile vignette
  (PR #115):
  `"quadratic"` (well-behaved), `"asymmetric"` (Wald-profile
  disagree), `"flat_at_mle"` (weak identifiability),
  `"hits_lower_bound"` / `"hits_upper_bound"` (boundary parameter),
  `"no_lower_crossing"` / `"no_upper_crossing"` (profile didn't
  converge), `"profile_failed"`. Accepts any direct profile-target
  label from `profile_targets()` (e.g. `"sigma_eps"`, `"sd_B[1]"`,
  `"phi_nbinom2[2]"`, `"b_fix[1]"`); derived targets emit a typed
  error pointing at the matching `extract_*(method = "profile")`
  extractor. Audit + TMB-report recommendation 2026-05-15.
* **`coverage_study(fit, parm, n_reps, methods, level, seed)`** --
  empirical coverage-rate estimator. For each of `n_reps`
  parametric-bootstrap replicates, simulates from the fit, refits,
  computes confidence intervals via the requested methods, and
  counts the fraction of CIs that contain the original fit's
  estimate. Returns an object of class `gllvmTMB_coverage_study`
  with `$coverage` (rate per `parm x method`, plus a
  `passes_94pct` flag for the audit's empirical-coverage exit
  gate), `$intervals` (long-format per-rep table for
  re-aggregation), `$n_failed_refits`. Audit recommendation
  2026-05-15: the >= 94% gate is the Phase 1b validation
  milestone's empirical exit criterion. Defaults to all
  profile-ready direct targets except packed Lambda entries
  (rotation-ambiguous; coverage would be misleading).

## Behaviour changes (Phase 1b validation milestone)

* **`confint(fit, parm = "sigma_eps", method = "wald")` now
  works on non-fixed-effect direct parm labels.** Previously
  only `method = "profile"` consulted `profile_targets()`; the
  Wald path went through `tidy(fit, "fixed")$term` and returned
  NA for variance / dispersion / scaling parameters. New helper
  `.confint_wald_targets()` computes Wald CIs from
  `fit$sd_report$cov.fixed` directly and applies the registered
  natural-scale transformation. This closes the symmetric API
  gap left by PR #119 and unblocks `coverage_study()` on Wald
  CIs.

## New exports (P1a audit response)

* **`profile_targets(fit, ready_only = FALSE)`** -- profile-likelihood
  target inventory. Returns a tidy data frame with one row per
  direct or derived profile target, with columns `parm`,
  `target_class`, `tmb_parameter`, `index`, `estimate`,
  `link_estimate`, `scale`, `transformation`, `target_type`,
  `profile_ready`, `profile_note`. Direct targets correspond to
  individual TMB parameter elements (e.g. `b_fix[1]`, `sigma_eps`,
  `sd_B[2]`, `phi_nbinom2[1]`); derived targets (communality,
  repeatability, phylogenetic signal, trait correlations) point
  the user at the matching `extract_*(method = "profile")`
  extractor via the `profile_note` column. Controlled vocabularies
  on `target_type`, `profile_note`, and `transformation` mirror
  drmTMB's `profile_targets()` (per the 2026-05-15 cross-team
  scan in PR #109) so the broader TMB-package family stays
  consistent.

## Behaviour changes (P1a audit response)

* **`confint.gllvmTMB_multi(method = "profile")` now routes
  non-Sigma, non-fixed-effect `parm` labels through
  `profile_targets()`**. Previously, `confint(fit, parm =
  "sigma_eps", method = "profile")` would fall through to the
  fixed-effect Wald path and return `NA` bounds (the parm wasn't
  matched against `tidy(fit, "fixed")$term`). Now it consults
  `profile_targets(fit, ready_only = TRUE)`, looks up the matching
  TMB parameter and index, and calls `tmbprofile_wrapper()` with
  the right transformation. Derived-target requests
  (`parm = "communality"` etc.) now emit a typed warning that
  points the user at the matching `extract_*(method = "profile")`
  extractor instead. The Sigma-matrix path (parm in
  `{Sigma_B, Sigma_W, sigma_phy}`) and the fixed-effect Wald /
  profile paths are unchanged.

## New exports (Phase 1b)

* **`check_auto_residual(fit)`** -- safeguard for the
  `link_residual = "auto"` path in the multi-trait extractors. Inspects
  the fit's per-row family vector and flags two configurations that
  make the auto path incoherent: (a) **within-trait family mixing**
  (a single trait carries rows from more than one family) -- errors
  with `class = "gllvmTMB_auto_residual_incoherent"`; (b) **ordinal-probit
  traits** -- warns with `class = "gllvmTMB_auto_residual_ordinal_probit_overcount"`
  because the probit link's latent residual is already 1 by
  construction and the auto path over-counts. Silent on well-formed
  fits. Phase 1b item 3 (Emmy persona consult 2026-05-14).
* **`check_identifiability(fit, sim_reps = 100L)`** -- identifiability
  diagnostic for a `gllvmTMB_multi` fit. Simulates `sim_reps` datasets
  from the fitted model, refits each replica under the same formula,
  applies Procrustes alignment to the per-tier loading matrices, and
  aggregates per-parameter recovery statistics plus Hessian-eigenvalue
  rank checks. The canonical case this catches that no other
  diagnostic does is a **spurious extra factor masquerading as
  identified**: when `d_B` is mis-specified (e.g. fit `d = 2` when
  truth is `d = 1`), `pdHess` may be `TRUE`, `sanity_multi()` may
  pass, and profile CIs on derived quantities may look tight -- but
  the second factor is noise. Procrustes alignment across replicates
  exposes the spurious column as a near-zero residual magnitude.
  Returns an object of class `gllvmTMB_identifiability` with
  components `$recovery`, `$loadings`, `$hessian`, and `$flags`. V1
  scope: Gaussian fits only (non-Gaussian / mixed-family support is
  queued for the Phase 1b validation milestone). Phase 1b item 4
  (Fisher persona consult 2026-05-14).

## Behaviour changes (Phase 1b)

* **`extract_correlations()` `link_residual` default change.** The
  default of the new `link_residual` parameter is `"auto"`. Previously
  the function hardcoded the equivalent of `link_residual = "none"`.
  For non-Gaussian fits this means correlations are now reported on
  the latent-liability scale (with the family-specific link residual
  -- e.g. \eqn{\pi^2/3} for binomial-logit, \eqn{1} for probit,
  trigamma terms for Gamma / NB2 / Beta / etc. -- added to the
  diagonal of the implied `Sigma`). Gaussian fits are unaffected (the
  link residual is zero). A one-shot warning fires the first time a
  non-Gaussian fit is processed without an explicit `link_residual`
  argument; pass `link_residual = "auto"` to lock the new behaviour
  and suppress the warning, or `link_residual = "none"` to restore
  the previous behaviour.
* **`extract-sigma.R` Beta / beta-binomial saturation fix.** The
  `mu_t` clamp at `[1e-6, 1 - 1e-6]` (per Gauss's correctness flag)
  now applies before forming the trigamma arguments. Previously a
  saturated Beta / beta-binomial fit (`eta -> +/-Inf`) collapsed one
  of `(a_t, b_t)` to the `1e-12` floor and `trigamma(1e-12) ~ 1e24`
  crushed any reported correlation to ~0. The new clamp keeps the
  fit's degeneracy numerically visible (a large but finite trigamma
  value) rather than silently producing meaningless correlations.

# gllvmTMB 0.2.0 (first CRAN release)

First public release of `gllvmTMB`, a Template Model Builder (TMB)
engine for stacked-trait generalised linear latent variable models
(GLLVMs). `gllvmTMB()` fits multivariate models in which the same
observational units carry several responses -- traits, species,
items, behaviours, outcomes -- and the scientific question concerns
their shared latent covariance, ordination, communality,
phylogenetic signal, or spatial structure.

## User-facing API

* One `gllvmTMB()` entry point shares one long-format engine:
  * `gllvmTMB(value ~ ..., data = df_long, trait = "trait",
    unit = "...")` accepts long-format data (one row per
    `(unit, trait)` observation) and wide data frames marked with the
    formula-LHS helper `traits(...)`. The wide form uses compact syntax such as
    `traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 2)`; the parser
    expands fixed predictors, `latent()` / `unique()` / `indep()` /
    `dep()`, bar-style `phylo_indep()` / `phylo_dep()`, and
    `spatial_*()` terms to the long trait-stacked grammar.
    Species-axis `phylo_scalar()` / `phylo_unique()` /
    `phylo_latent()` calls and ordinary `(1 | group)` random
    intercepts pass through unchanged.
  * `gllvmTMB_wide(Y, ...)` remains exported as a soft-deprecated
    matrix-in wrapper for migration and the current per-cell
    weight-matrix path. New examples should use the `traits(...)`
    formula LHS.

* The covariance grammar is a 4 x 5 keyword grid (correlation source
  x mode):

  | correlation \ mode | scalar | unique | indep | dep | latent |
  |---|---|---|---|---|---|
  | none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
  | animal  | `animal_scalar()`  | `animal_unique()`  | `animal_indep()`  | `animal_dep()`  | `animal_latent()`  |
  | phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
  | spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

  The decomposition mode pairs `latent + unique`:
  `Sigma = Lambda Lambda^T + diag(psi)`. Math notation uses
  the Greek letter `\boldsymbol{\Psi}` (bold capital) for the
  unique-variance diagonal matrix and `\psi_t` (italic lowercase,
  subscripted by trait) for the per-trait derived scalar, matching
  the factor-analysis / SEM convention (Bollen 1989, Mulaik 2010,
  lavaan). The legacy "two_U" task label has been retired from
  function and file names: the PIC-based cross-check diagnostics
  (`compare_PIC_vs_joint()`, `extract_two_U_via_PIC()`) are
  removed entirely, and the joint-vs-unstructured cross-checks
  are renamed to `compare_dep_vs_two_psi()` /
  `compare_indep_vs_two_psi()` (same signatures and behaviour,
  new names matching the Psi notation). See
  `docs/dev-log/decisions.md` 2026-05-14 entries (notation reversal
  + two-U/PIC retirement) and `docs/dev-log/decisions.md`
  2026-05-15 entry (partial restoration of the joint-vs-unstructured
  cross-checks under the `two_psi` rename).

* Per-trait response families: gaussian, binomial (with multi-trial
  via `cbind(succ, fail)` or weights), betabinomial, poisson,
  lognormal, Gamma, nbinom2, tweedie, Beta, student, ordinal_probit,
  truncated_poisson, truncated_nbinom2, delta_lognormal, delta_gamma.
  Mixed-family fits are accepted via `family = list(...)` keyed by
  trait.

* `gllvmTMB()` requires at least one covariance-structure term. A
  call without any `latent()` / `unique()` / `indep()` / `dep()` /
  `phylo_*()` / `spatial_*()` term errors with a pointer to
  `glmmTMB::glmmTMB()` for single-response work.

* New technical reference articles cover the covariance keyword grid,
  the response-family surface, and the ordinal-probit threshold scale
  and cutpoint convention.

## Inference

* Maximum-likelihood point estimates via TMB's Laplace
  approximation. REML is not yet implemented; planned for a
  post-0.2.0 release as a Gaussian-only feature (matching the
  `glmmTMB` / `lme4` convention). See
  `docs/dev-log/decisions.md` 2026-05-14 REML scope note.
* Profile-likelihood confidence intervals for derived quantities
  (repeatability, communality, phylogenetic signal, pairwise
  correlations) through the `profile_ci_*()` family.
* `extract_correlations()` exposes Fisher-z (default), Wald, and
  bootstrap intervals via the `method` argument.

## Phylogenetic and spatial paths

* Phylogenetic covariance via the sparse `A^-1` representation of
  Hadfield & Nakagawa (2010), with `tree` (an `ape::phylo`) or
  `phylo_vcv = Cphy` (a precomputed covariance matrix) as input.
* Spatial covariance via the SPDE / GMRF approximation from
  `sdmTMB`. `gllvmTMB` includes SPDE / mesh / anisotropy helpers
  (`make_mesh()`, `R/crs.R`, parts of `R/plot.R`) inherited from
  `sdmTMB` under GPL-3; provenance is recorded in `inst/COPYRIGHTS`
  and at the top of each inherited R file.

## Inherited code and citation

* `Authors@R` names Shinichi Nakagawa as the sole author of
  `gllvmTMB`. Upstream copyright holders for inherited code
  (Anderson, Ward, English, Barnett for `sdmTMB` SPDE / mesh /
  anisotropy R helpers; Kristensen for `TMB`; Thorson for `VAST`
  transitively via `sdmTMB`) are recorded in `inst/COPYRIGHTS` and
  acknowledged in `inst/CITATION`, `README.md`, and file-top
  comments of the inherited R files. This follows the
  CRAN-recommended pattern in "Writing R Extensions" §1.1.1 of
  using a `Copyright: inst/COPYRIGHTS` field rather than `cph`
  entries in `Authors@R` for inherited-code copyright holders.

* `inst/CITATION` curates `citation("gllvmTMB")`. The primary
  entry is the (in-prep) Nakagawa methods paper; companion
  entries cite Kristensen et al. (2016) for TMB and Anderson
  et al. (2025) for `sdmTMB` when the spatial path is used.

## Source-tree notes

* The TMB engine is compiled at install time from
  `src/gllvmTMB.cpp`. The DLL is registered via
  `useDynLib(gllvmTMB, .registration = TRUE)`.
* `gllvmTMBcontrol()` returns an options object distinct from
  `sdmTMB::sdmTMBcontrol()`. Extra `...` arguments emit a
  warning.

## Relationship to a pre-0.2.0 development line

The pre-0.2.0 development line of `gllvmTMB` re-exported a large
surface from `sdmTMB` and exposed single-response paths; the
0.2.0 release does neither. Users who want single-response models
should install `sdmTMB` or `glmmTMB` directly, which install
side-by-side with `gllvmTMB` without conflict.
