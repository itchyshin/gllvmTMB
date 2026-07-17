# gllvmTMB 0.5.0

This release focuses on multivariate stacked-trait models fitted through the
R/TMB engine. The optional Julia bridge remains experimental and is not
required for the main workflow.

## New

* `gllvmTMB()` now accepts both canonical long data and wide data through a
  `traits(...)` left-hand side. The two forms use the same fitting engine.
* Random slopes accept the **`||` uncorrelated coupling**: `mode(1 + x || g)`
  fits the intercept and slope with no intercept-slope covariance (equivalently
  `mode(1 | g) + mode(0 + x | g)`), alongside the correlated single-bar
  `mode(1 + x | g)`. Available for `phylo_indep`/`animal_indep`/`kernel_indep`
  (per-trait diagonal), `phylo_dep`/`animal_dep`/`kernel_dep` (block
  `Sigma_int (+) Sigma_slope`), and the source-tier `phylo_latent`/`animal_latent`/
  `spatial_latent` (which were already the uncorrelated form).
* Dense-kernel random slopes: `kernel_indep(1 + x | g, K = K)` and
  `kernel_dep(1 + x | g, K = K)` (and their `||` forms) fit a random regression on
  a supplied dense kernel `K`, byte-equivalent to the phylogenetic path with
  `vcv = K`.
* Random slopes now support **lognormal** and **student** responses in addition to
  the previous set.
* The reader-facing covariance grammar crosses five correlation sources
  (`none`, `animal`, `phylo`, `spatial`, and `kernel`) with three taught modes:
  independent, dependent, and latent. The one-shared-variance ("scalar") case is
  the parsimony modifier `common = TRUE` on any `indep` term.
* The retained pkgdown guides now focus on runnable, numerically inspected
  workflows: morphometrics, Gaussian latent-rank selection, binary joint species
  distribution modelling, behavioural covariance, reaction norms, phylogenetic
  covariance, missing responses, response screening, fit diagnostics, profile
  routes, and formula/reference concepts.
* `predictive_check()`, diagnostic residuals, `diagnostic_table()`,
  `check_gllvmTMB()`, and `gllvmTMB_diagnose()` provide complementary fitted-model
  checks. They diagnose a fitted response distribution and numerical health; they
  do not prove latent rank or interval calibration.
* `extract_Sigma_table()`, `plot_Sigma_table()`, and `plot_correlations()` provide
  report-oriented covariance and correlation displays. Correlation extraction is
  point-only by default; interval routes are explicit and carry an uncalibrated
  status rather than a coverage certificate.

## Changed

* `confint(fit, parm = "Sigma_unit")` now returns a genuine profile-likelihood
  interval for the per-trait total variance (the diagonal of `Sigma_unit`,
  combining the loadings and diagonal contributions) instead of falling back to
  the bootstrap. For Gaussian responses fitted with at least 150 grouping units
  and low latent dimension (`d <= 2`, the dimensions evaluated), repeated-sampling
  simulation validates that this interval clears a 0.94 two-sided coverage gate
  (measured coverage approximately 0.946-0.948 against a 0.95 target), for
  converged fits -- in the validating simulation about 1-3% of fits did not
  converge and returned no interval (roughly 2.9% at `d = 1`, 0.7% at `d = 2`).
  This is currently the only `confint()` target whose coverage is
  validated by simulation. Gaussian fits with fewer than 150 grouping units or
  higher latent dimension, and binomial, `nbinom2`, and ordinal responses, are
  not covered by this validation and remain recovery-grade; `Sigma_unit`
  off-diagonal (covariance) entries continue to use the bootstrap.
* Ordinary `latent()` now represents
  `Sigma = Lambda Lambda^T + Psi` by default. Use
  `latent(..., unique = FALSE)` for the earlier loadings-only subset.
  Source-specific and kernel latent terms remain loadings-only by default; pass
  `unique = TRUE` when their intended covariance includes the diagonal companion.
* The one-shared-variance ("scalar") covariance is now the parsimony modifier
  `common = TRUE` on any `indep` term: `indep(..., common = TRUE)`,
  `phylo_indep(..., common = TRUE)`, `animal_indep(..., common = TRUE)`,
  `spatial_indep(..., common = TRUE)`, and `kernel_indep(..., common = TRUE)` fit
  one variance shared across all traits (intercept-only). The covariance grid is
  taught as three modes -- independent, dependent, latent -- with `common =` as
  the scalar sub-case, rather than a separate fourth mode.
* `phylo_indep()` and `animal_indep()` with an intercept-and-slope term
  (`1 + x | g`) fit **one independent (intercept, slope) block per trait** --
  each trait its own random regression, with an estimated intercept-slope
  correlation and zero cross-trait covariance (a set of univariate random
  regressions stacked over traits). The spatial `spde` intercept-slope path is
  unchanged for now, pending its own verification.
* `fit$fit_health` separates optimiser success, raw and objective-scaled
  gradients, Hessian health, and `sdreport()` availability. Its `converged` field
  is conservative: optimiser success, a finite objective, and a small raw maximum
  gradient are all required. Hessian health remains a separate inference check.
* `extract_correlations()` now returns point estimates by default. Fisher-z/Wald
  bounds are heuristic sensitivity summaries; bootstrap routes are
  target-specific and are not labelled as universally calibrated. The nonlinear
  penalty-profile prototype is no longer a public route.
* Reader-facing pages no longer expose internal validation identifiers,
  development phases, agent roles, or capability bookkeeping.

## Fixed

* A diagonal covariance term is no longer duplicated when the `unit` and
  `cluster` columns are the same grouping factor. This removes a flat variance
  split and restores coherent covariance extraction and Wald infrastructure.
* `extract_phylo_signal()` now uses the declared species-level denominator in
  crossed site-by-species designs instead of silently returning one for every
  trait when non-phylogenetic species variance was stored at the cluster tier.
* `phylo_dep()` is treated as a full covariance parameterisation, not as a set of
  exchangeable latent axes, in rotation and weak-axis diagnostics.
* Missing or undefined link-scale residual variances now propagate as `NA`
  instead of being replaced by zero or another finite fallback. In particular,
  Student-t variance is undefined when its degrees of freedom are at most two.
* Several optional Julia-bridge shape, dispatch, missing-cell, and confidence-
  interval error paths now fail explicitly instead of silently returning malformed
  output. The bridge remains experimental.

## Deprecated compatibility syntax

* The formula parser continues to accept `unique()` as compatibility syntax;
  source-specific `*_unique()` functions remain exported soft-deprecated
  aliases. Use `indep()` / `*_indep()` in new standalone diagonal formulas.
* The scalar family -- `scalar()`, `phylo_scalar()`, `animal_scalar()`,
  `spatial_scalar()`, `kernel_scalar()` -- is soft-deprecated compatibility
  syntax that emits a one-time warning and keeps working. Use
  `indep(..., common = TRUE)` / `*_indep(..., common = TRUE)`, which fits the
  same model.
* `gllvmTMB_wide()` remains available for migration, but new wide examples use
  `gllvmTMB(traits(...) ~ ...)`.
* `meta_known_V()` remains a deprecated alias of `meta_V()`.

## Known limitations

* Interval support is target-specific. A route that returns bounds is not, by
  itself, evidence of nominal repeated-sampling coverage. The one exception is
  the `Sigma_unit` diagonal (per-trait total variance) profile interval for
  Gaussian responses at 150 or more grouping units and low latent dimension
  (`d <= 2`), whose coverage of the 0.94 gate is simulation-validated for
  converged fits (see Changed); every other route remains recovery-grade.
* The previous public `check_identifiability()` and `coverage_study()` prototypes
  have been withdrawn from the exported surface. Their fitted-model simulation
  designs did not establish unknown generating rank or retain every attempted
  replicate in the coverage denominator. They remain internal until redesigned
  around predeclared known-data-generating targets and complete failure accounting.
* Nonlinear penalty-profile prototypes for communality, correlation, variance
  proportions, and predictor-informed latent effects have been withdrawn from
  the exported surface. The approximation could accept loose constraints or
  unusable constrained optimisations without a complete status ledger. Direct
  TMB parameter profiles and simple linear-contrast profiles remain available;
  nonlinear routes will return only after an exact constraint and failure-
  diagnostic contract is verified.
* For single-trial Bernoulli cells, a default per-trait diagonal random effect can
  be unidentifiable and is mapped off. The fixed link-scale residual defines the
  liability convention; multi-trial or genuinely repeated designs have different
  information.
* `meta_V()` remains an important development target, but a dedicated public
  article will wait until its supported estimands, diagnostics, and validation
  evidence form a complete reader path.
* More advanced or weakly evidenced draft articles have been retired rather than
  published as capability claims. Their topics can return when the underlying
  model, extractor, diagnostics, comparison, and uncertainty path are ready.

# gllvmTMB 0.2.0

Earlier development release establishing the stacked-trait R/TMB engine, the
long-format API, initial covariance keywords, simulation helpers, and extractor
infrastructure. The 0.5.0 notes above describe the current taught syntax and
reader-facing scope.
