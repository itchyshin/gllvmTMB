# gllvmTMB 0.5.0

This release focuses on multivariate stacked-trait models fitted through the
R/TMB engine. The optional Julia bridge remains experimental and is not
required for the main workflow.

## New

* `gllvmTMB()` now accepts both canonical long data and wide data through a
  `traits(...)` left-hand side. The two forms use the same fitting engine.
* The reader-facing covariance grammar crosses four correlation sources
  (`none`, `animal`, `phylo`, and `spatial`) with four taught modes: scalar,
  independent, dependent, and latent.
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

* Ordinary `latent()` now represents
  `Sigma = Lambda Lambda^T + Psi` by default. Use
  `latent(..., unique = FALSE)` for the earlier loadings-only subset.
  Source-specific and kernel latent terms remain loadings-only by default; pass
  `unique = TRUE` when their intended covariance includes the diagonal companion.
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
* `gllvmTMB_wide()` remains available for migration, but new wide examples use
  `gllvmTMB(traits(...) ~ ...)`.
* `meta_known_V()` remains a deprecated alias of `meta_V()`.

## Known limitations

* Interval support is target-specific. A route that returns bounds is not, by
  itself, evidence of nominal repeated-sampling coverage.
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
