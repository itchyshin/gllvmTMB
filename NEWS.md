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
* Random-slope routes are runtime-permitted for **lognormal** and **Student-t**
  responses under the C1-partial RE-14 contract. This is fit admission only:
  direct route-specific recovery and inference evidence are not yet covered, so
  this release makes no scientific-validation claim for those combinations.
* New **`multinomial()`** response family for an *unordered* categorical response
  with three or more categories (baseline-category logit / softmax). It recovers the
  per-category intercepts and slopes as contrasts against a reference category, and
  `predict(type = "response")` returns per-category probabilities. Use
  `multinomial(baseline = ...)` to choose the reference category. The validation
  boundary is explicit: fixed-effect recovery is `covered` (FAM-20), while the
  single `phylo_latent()` route (FAM-20A) and the narrow ordinary
  shared-`latent()` cross-family route (FAM-20B) are `partial`. The latter reports the nominal
  trait as its `K - 1` baseline-contrast block rather than inventing one scalar
  categorical correlation; it permits one multinomial trait per fit and rejects
  unsupported tiers before TMB construction. Multiple multinomial traits,
  augmented slopes, explicit multinomial `unique()`/`indep()`, and unlisted
  source tiers remain blocked. A two-category response is
  `binomial(link = "logit")`. For
  *ordered* categories use `ordinal_probit()`. See the *Unordered categories with
  `multinomial()`* article for a worked diet-guild example.
* **`phylo_latent()` on a `multinomial()` trait (Design 84; FAM-20A `partial`)** reports the
  `(K-1) x (K-1)` among-category phylogenetic covariance V (how the category
  liabilities coevolve) via
  `extract_Sigma(fit, level = "phy", part = "shared", link_residual = "none")`.
  The default total/`"auto"` extraction instead reports V plus the fixed softmax
  residual `(pi^2/6)(I + J)`. Two honest caveats:
  recovery of V is **data-hungry** (it needs per-species replication or large N; a
  single categorical draw per species is weakly informative, so one-per-species point
  estimates are high-variance and can reach the +/-1 boundary), and V is on the
  baseline-**contrast** scale, so a diagonal V is not independence -- the null contrast
  covariance is `(I + J)`-structured (equal diagonal, equal off-diagonal; the
  observation-scale link residual is applied as `(pi^2/6)(I + J)` -- the softmax
  analog of binomial's `pi^2/3`). Treat this phylogenetic V route as
  recovery-oriented and data-hungry, not universally validated.
* For the admitted cross-family nominal route (FAM-20B `partial`), ordinary
  `latent()` keeps its default diagonal companion but the current engine maps
  off multinomial-contrast `Psi`. That variance is not identified with one
  categorical draw per unit; replication can identify it in principle, but the
  current conservative implementation still suppresses it. Explicitly adding
  `unique()` or `indep()` for those contrasts remains fail-closed. Point
  extraction and target-specific
  Wald/bootstrap interval plumbing exist, but their repeated-sampling
  calibration is not covered. Nonlinear profile intervals are withdrawn.
* `extract_cross_correlations()` now restricts `level` to the ordinary unit tier
  for **every** method. Previously only `method = "profile"` enforced this, so
  `level = "unit_obs"`, `"phy"`, or `"spatial"` combined with `method = "point"`,
  `"wald"`, or `"bootstrap"` were reachable. Those combinations now raise a typed
  error. This is a deliberate reduction rather than a regression: the estimand for
  a source-tier cross-family correlation was never validated on those paths, and
  returning an uncalibrated number was worse than refusing. Use
  `extract_Sigma()` for source-tier covariance.
* **Known limitation — phylogenetic slope variance under `binomial(link = "logit")`.**
  For a `phylo_unique()` random-slope fit with a logit link, the estimated
  slope variance is **upward-biased by roughly 50-60%** at realistic signal
  levels. The bias does **not** shrink with sample size: it persists across
  `n = 60`, `120`, and `240` (21 seeds tested), on fits that are otherwise
  healthy (converged, positive-definite Hessian, valid `sdreport`). The cause is
  **too little information per cluster**, not a defect: with only a handful of
  single-trial binary observations per species, the sampling variance of each
  species' estimated slope is comparable to the true between-species variance
  itself, and roughly half the spread across species is sampling noise. The
  identical design recovers cleanly under a Gaussian response, which is what
  rules out an engine problem. **Do not read a logit phylo-slope variance as
  calibrated.** The remedy is more information per species -- more replicates
  per species, or multi-trial `cbind(successes, failures)` data rather than
  single 0/1 draws -- rather than more species. The
  corresponding recovery test is deliberately skipped rather than passed by
  retuning its data-generating truth; see
  `docs/dev-log/known-residuals-register.md` (R-2).
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
* Current `phylo_indep()`, `animal_indep()`, and `spatial_indep()`
  intercept-and-slope terms fit **one independent 2 x 2 (intercept, slope)
  block per trait**: within-trait correlation is estimated for `|`, fixed to
  zero for `||`, and cross-trait covariance is zero. Current `*_dep()` routes
  instead use a full 2T x 2T augmented covariance. The soft-deprecated
  `phylo_unique()`, `animal_unique()`, and `spatial_unique()` slope forms retain
  their legacy shared 2 x 2 channels; they are not aliases for the current
  `*_indep()` shape. Admission remains family- and route-specific (ANI-11;
  PHY-11 to PHY-16, PHY-18; SPA-08, SPA-10; RE-14).
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
