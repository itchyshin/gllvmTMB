# gllvmTMB (development version)

* (Post-0.2.0 development. New user-facing changes are recorded here;
  the first CRAN release notes are under **gllvmTMB 0.2.0** below.)

## Julia bridge ordinal Wald CI and residual closure (2026-07-04)

* Closed the last current R/Julia bridge capability drift rows for the narrowed
  seven-family bridge ledger. `engine = "julia"` now admits no-X Wald CI
  payloads for the GLLVM.jl `ordinal` bridge row and reconstructs
  response/Pearson ordinal-score residuals from retained category
  probabilities. Ordinal profile/bootstrap CIs, `ordinal_probit()` bridge
  admission, ordinal simulation, newdata prediction/simulation, response masks,
  mixed-family vectors/CIs, non-Gaussian fixed-effect `X`, source-specific
  `lv = ~ env`, and Julia parity for source-specific `unique=` remain gated.
  Focused pure R bridge tests passed with the expected live-Julia skips, the
  configured live bridge file passed against the local GLLVM.jl checkout, and
  the live capability drift probe now reports zero registered and zero
  unregistered rows. This is bridge truth-contract cleanup, not v1.0 completion
  or coverage calibration.

## `unique()` family soft deprecation (2026-06-18)

* Added the first parser-level lifecycle slice for the `unique()` keyword
  family. `unique()`, `phylo_unique()`, `animal_unique()`,
  `spatial_unique()`, and `kernel_unique()` now emit one-shot
  `lifecycle::deprecate_soft()` warnings when the formula parser sees them,
  while preserving the existing compatibility rewrites and fits. For
  standalone marginal diagonal tiers, new code should use `indep()` and the
  source-specific `*_indep()` spellings. Ordinary `latent()` now emits its
  diagonal Psi companion by default; use `latent(..., residual = FALSE)` for the
  old no-residual subset. Paired explicit-Psi forms such as
  `latent() + unique()` and source-specific pairs such as
  `phylo_latent() + phylo_unique()` remain accepted as compatibility syntax. The
  Paper 2 multi-kernel path remains latent-only; `kernel_unique()` warns but is
  still retained as compatibility syntax and as a guarded first-wave rejection
  in multi-kernel fits. This is a lifecycle / ordinary-Psi fold slice only: no
  exported keyword was removed, source-specific and `kernel_*()` latent-Psi
  folds remain future work, `part = "unique"` is not renamed, and
  bridge/release/scientific-coverage gates do not widen.
  A follow-up diagnostic cleanup now removes stale ordinary-user guidance that
  said communality CIs or augmented `extract_Sigma(part = "unique")` require an
  explicit `unique()` term. Those messages now refer to the diagonal Psi
  component and the default `latent()` fit, with `latent(..., residual = FALSE)`
  named as the deliberate no-Psi subset. Compatibility tests that intentionally
  exercise explicit `unique()` now quiet lifecycle warnings locally; the
  dedicated deprecation test remains the warning assertion surface. Fit-time
  ordinary augmented reaction-norm guard suggestions now prefer
  `latent(1 + x | unit, d = K)` for the default shared + diagonal-Psi fit and
  describe explicit `unique(1 + x | unit)` as compatibility syntax. Generic
  extractor no-covariance diagnostics now list `latent()` / `indep()` before
  noting explicit `unique()` as compatibility syntax.
  A rendered article cleanup updated `convergence-start-values`,
  `choose-your-model`, `profile-likelihood-ci`, and
  `functional-biogeography`, `cross-package-validation`, and
  `simulation-verification`, then extended the same cleanup to
  `morphometrics`, `api-keyword-grid`, `pitfalls`, `joint-sdm`,
  `response-families`, `model-selection-latent-rank`, `fit-diagnostics`,
  `mixed-family-extractors`, `psychometrics-irt`, `phylogenetic-gllvm`, and
  the main `gllvmTMB` vignette: ordinary examples now teach default
  `latent()` for `Lambda Lambda^T + Psi`, `dep()` for full unstructured
  covariance, and `indep()` for standalone diagonal tiers. The cleanup rendered
  all touched pages, regenerated the morphometrics and latent-rank
  model-selection teaching fixtures so their stored formulas no longer use
  explicit ordinary `unique()`, and kept `unique()` / `*_unique()` as
  compatibility syntax only. The phylogenetic article still uses
  `phylo_unique()` for an explicitly separated phylogenetic `Psi` component;
  source-specific latent-Psi folding remains future work. No keyword removal or
  extractor contract change is claimed. The simulation-recovery validation
  article now names the target as diagonal `Psi` variance under the
  default-`latent()` formula while preserving the per-trait $\psi_t$ coverage
  estimand. Tier-3 internal routing/concept drafts `data-shape-flowchart` and
  `stacked-trait-gllvm` were also refreshed so their ordinary examples point to
  default `latent()` and standalone `indep()` rather than teaching explicit
  ordinary `unique()`. The Tier-3 candidate worked example
  `behavioural-syndromes` now uses default `latent()` at the between- and
  within-individual tiers while preserving the same `Psi_B` / `Psi_W`
  interpretation.
  A follow-up implementation slice extends the ordinary Gaussian
  random-regression default to augmented `latent(1 + x | unit, d = K)` terms:
  the fit now supplies the diagonal `Psi_B,aug` companion automatically, so
  `extract_Sigma(level = "unit_slope", part = "unique")` works without an
  explicit augmented `unique()` term. The `random-regression-reaction-norms`
  article and bundled behavioural reaction-norm fixture now use the default
  `latent()` spelling in long and wide formulas. Explicit augmented
  `unique(1 + x | unit)` remains compatibility syntax and is still
  Gaussian-only; non-Gaussian augmented `latent()` remains low-rank-only.
  The standalone scalar marginal path now has a non-deprecated spelling:
  `indep(..., common = TRUE)` rewrites to the same scalar diagonal model as
  legacy standalone `unique(..., common = TRUE)`. The ordinary paired scalar
  Psi path is now re-homed as `latent(..., common = TRUE)`: it is
  objective-equivalent to legacy
  `latent(..., residual = FALSE) + unique(..., common = TRUE)` for
  intercept-only ordinary terms, while rejecting `residual = FALSE,
  common = TRUE` and augmented random-regression `common = TRUE` forms.
  Source-specific and `kernel_*()` paired-Psi folds remain future work.

## Psi / `unique()` public-story cleanup (2026-06-18)

* Continued the post-coevolution Psi cleanup. `unique()` / source-specific
  `*_unique()` remain
  compatibility and explicit-Psi syntax. New public teaching now points
  standalone marginal diagonal models to `indep()` / source-specific
  `*_indep()` while keeping `unique()` for the Psi component in
  `latent() + unique()` decompositions. The second sweep edited and rendered
  `response-families`, `animal-model`, `phylogenetic-gllvm`, and
  `functional-biogeography`: the response-family reference now separates
  identifiable observation-level `unique()` from standalone diagonal tiers;
  the animal-model article teaches `animal_indep()` for marginal genetic
  diagonals and fixes stale ANI-11 read-out wording; the phylogenetic article
  names `phylo_indep()` / `indep()` for standalone diagonals; and the
  functional-biogeography capstone now uses `spatial_indep()` /
  `phylo_indep()` for adjustment-only controls while preserving true
  explicit-Psi compatibility partitioning examples. IN/covered row anchors remain
  `FG-05` for compatibility `unique()`, `FG-06` for the explicit-Psi
  compatibility pair,
  `ANI-03` / `ANI-11` for the animal-model wording, and `FAM-06` for the
  Poisson OLRE note. PARTIAL row anchor: `FG-07` for the documentary
  `indep()` spelling, whose known-V non-Gaussian variant is still partial.
  This is documentation and claim-boundary cleanup only, not an API removal,
  parser deprecation, bridge completion, release readiness, or scientific
  coverage completion.

## Fixed named multi-kernel tiers (2026-06-18)

* Added the first fixed multi-kernel engine wave for `kernel_latent()`: two or
  more named dense kernel tiers over the same grouping levels now fit with
  separate `K_r`, loading matrices, and latent fields. `extract_Sigma(fit, level = name)`,
  `extract_Gamma(fit, level = name, ...)`, and
  `predict_cross_covariance(fit, level = name, ...)` now resolve each named
  component separately. IN (`KER-03`): fixed dense PSD kernels, same grouping factor and
  level set, and component-specific shared covariance extraction. The Paper 2
  first wave is intentionally latent-only: paired `kernel_unique()` Psi is
  deferred because explicit residual/Psi structure is a poor default for
  non-Gaussian and cross-family coevolution models. PARTIAL (`COE-03`): this
  opens the fixed two-component Paper 2 shape for `Gamma_shape_r` inspection.
  `extract_coevolution_modules()` now turns a component-specific
  `Gamma_shape` or fixed-`rho` `Gamma_effect` block into a standardized
  cross-lineage correlation-like matrix and singular-value module table, so
  Paper 2 can report coupled host/partner trait axes as point estimates. This
  is a derived extractor only: no module uncertainty, biological rank
  selection, `rho` estimation, or null-threshold calibration is claimed.
  A first heavy `COE-04` recovery gate now passes for a near-orthogonal
  Gaussian latent-only fixture: a predeclared Frobenius-style kernel-similarity
  diagnostic, now stored on multi-kernel fits as `fit$kernel_diagnostics`,
  classifies the two kernels as separable, the full two-component fit beats
  either one-component fit, and each extracted component-specific
  `Gamma_shape_r` recovers its own truth while not matching the other
  component. `diagnose_kernel_separability()` now exposes the same
  off-diagonal Frobenius-style screening before fitting; the raw/aliased
  `K_tip` fixture is flagged as `high` overlap with recommendation
  `collapse_or_single_covariance`, while the residualized/opposed candidate is
  `near_orthogonal` with recommendation `separable_candidate`. This is a
  kernel-screening and claim-boundary helper only, not a formal identifiability
  proof, interval calibration, or scientific-coverage promotion. A deterministic
  pre-fit collinearity gate now blends the residualized `K_tip` candidate
  toward `K_phy`, verifies monotone similarity, and forces
  `near_orthogonal -> separable_candidate`,
  `moderate -> sensitivity_required`, and
  `high -> collapse_or_single_covariance` before any component-specific Paper 2
  claim is advertised. The same near-orthogonal Gaussian fixture now also covers
  selective absence in both directions: if either the phy or non component has
  true zero loadings, the two-kernel fit collapses that component's
  `extract_Gamma()` while recovering the present component. A block-null smoke
  gate also collapses both component `Gamma_shape` estimates when both loading
  blocks are zero, and a 12-seed near-orthogonal null diagnostic now keeps
  null `Gamma_shape` norms near zero while quantifying the full-vs-intercept
  overfit tail (median below `2`, at most two seeds above `3`, maximum below
  `8` log-likelihood units). The paired signal side still recovers both
  `Gamma_shape` components in two medium-signal fixtures. The first
  non-Gaussian gate now includes two bounded Poisson construction fixtures
  plus two known-DGP Poisson recovery cells (`seed = 2801` and `2804`): the
  full latent-only two-kernel fit converges, beats either one-component
  Poisson comparator by more than `40` log-likelihood units, recovers both
  planted component-specific `Gamma_shape` blocks with correlations above
  `0.98`, and keeps cross-component matches below `0.10`. This is still a
  narrow Poisson log-link recovery gate, not interval calibration or
  mixed-family coverage. A fixed-`rho` sensitivity grid now refits the
  phy component over
  `rho = c(0, 0.25, 0.55, 0.85)` while holding the non component fixed; the
  positive-`rho` grid strongly beats the block-null `rho = 0` fit, but the gate
  deliberately treats the best grid point as sensitivity evidence only because
  fixed kernel strength and loading magnitudes can trade off.
  `profile_cross_rho()` now makes that fixed-kernel workflow a reusable helper:
  it rebuilds `K*` over a defended `rho` grid, calls a user-supplied refit
  function, and returns log-likelihood / relative-likelihood profile rows.
  This is still not in-engine `rho` estimation or interval calibration.
  High-overlap
  `predict_cross_covariance()` combines the shape-scale `Gamma_shape_r` block
  with fitted `K_r[i, j]` entries to return pair-specific point cross-lineage
  covariance, avoiding the false impression that there is one universal total
  `Gamma`. For `make_cross_kernel()` tiers, `K_r[i, j]` already includes the
  supplied fixed `rho`, so the helper does not multiply by
  `extract_Gamma(scale = "effect")`. High-overlap
  kernel tiers now warn during fitting and again
  when `extract_Gamma(level = ...)` is called for an affected component, while
  still returning the diagnostic table and point block for inspection. A first
  high-overlap collapse gate now covers both exact-duplicate and
  diagonal-shrink near-duplicate kernel pairs; in both cases the separated
  two-tier fit is not materially better than one collapsed rank-2 kernel tier,
  and component-specific `Gamma` extraction remains warning-only. A separate
  high-overlap non-identical gate now mixes the non kernel 85% toward the phy
  kernel before simulating (`similarity = 0.999876`): the two-kernel fit
  detects signal over either one-component comparator, but component
  `Gamma_shape` recovery fails the ordinary separation thresholds, so this is
  failure-calibration evidence rather than promoted recovery. A two-cell
  moderate-overlap grid, with the non
  association pattern blended 30% and 35% toward the phy pattern, now also
  recovers both component `Gamma_shape` matrices while keeping cross-component
  matches low. A tested 40% moderate-edge cell still converges and detects
  signal, but fails the stricter component-separation thresholds, so it is a
  claim boundary rather than a promotion. PARTIAL (`COE-04`): broader/harder
  moderate-overlap calibration,
  broader high-overlap truth-recovery/failure calibration beyond the
  collapse-equivalence, non-identical failure-calibration, and warning gates,
  formal null-threshold calibration beyond this diagnostic grid, explicit Psi
  redesign/deprecation, in-engine `rho` estimation, `rho` profile intervals,
  calibration, and broader non-Gaussian/mixed-family recovery remain gated. The
  one-name `kernel_*()` path still uses the
  phylo-equivalent KER-02 engine and the `<1e-6` equivalence gate remains
  unchanged. Guard: PR green != bridge complete != release ready != scientific
  coverage passed.

## R-side `engine = "julia"` bridge to GLLVM.jl (2026-06-13)

* Added an `engine` argument to `gllvmTMB()` (`engine = c("tmb", "julia")`,
  default `"tmb"`). With `engine = "julia"` the fit is routed through the fast
  GLLVM.jl engine via JuliaCall (`R/julia-bridge.R`, calling `GLLVM.bridge_fit`).
  IN (JUL-01): the bridge maps a single reduced-rank latent block
  (`latent(...)` -> `rr`) with per-trait intercepts for gaussian, poisson,
  binomial, nbinom2, nbinom1, beta, gamma, ordinal, and ordinal-probit rows.
  The current paired Julia checkout returns trait-labelled grouped-dispersion
  payloads for nbinom2, nbinom1, beta, and gamma; the R bridge preserves the
  engine-native nuisance values and adds explicit public-scale fields for
  parity checks. Ordinal and ordinal-probit payloads now carry trait-labelled
  per-trait cutpoint matrices plus per-trait category counts. PARTIAL (JUL-01):
  this is a narrow point-route bridge, not a full native parity claim. The
  bridge now routes one-part no-X response masks for supported non-Gaussian
  rows, and complete-response fixed-effect X point fits for gaussian, poisson,
  Bernoulli binomial, nbinom2, beta, and gamma rows. It still loudly rejects
  non-`rr` covariance terms, more than one latent block, `cbind()` binomial,
  Gaussian or mixed-family response masks, response masks with fixed-effect
  covariates, NB1-X, ordinal-X, mixed-family-X, and unsupported
  fixed-effect designs. Direct `gllvm_julia_fit()` calls can request stored
  Wald/profile/bootstrap CI payloads for complete-response no-X gaussian,
  poisson, Bernoulli binomial, nbinom2, nbinom1, beta, and gamma rows, and for
  no-X response-mask fits in poisson, Bernoulli binomial, nbinom2, nbinom1,
  beta, and gamma rows. Ordinary `gllvmTMB(..., engine = "julia",
  ci_method = "wald" / "profile" / "bootstrap")` fits can request the same
  admitted no-X CI payloads at fit time, plus complete-response fixed-effect-X
  CI payloads for gaussian, poisson, Bernoulli binomial, nbinom2, beta, and
  gamma rows. Ordinary Julia bridge fits also retain
  their bridge input so `confint(fit, method = "wald" / "profile" /
  "bootstrap")` can request the same admitted no-X CI payloads post-fit,
  including the admitted masked non-Gaussian rows and admitted
  complete-response fixed-effect-X rows. The
  admitted post-fit surface is `coef()`, `summary()`, scoped no-X `confint()`,
  and retained-payload `predict()` / `fitted()` / `residuals()` / `simulate()`
  only where the Julia payload carries the needed score and nuisance fields;
  live R tests currently admit in-sample `predict()` / `fitted()` plus
  response/Pearson `residuals()` and conditional in-sample `simulate()` for
  no-X gaussian, poisson, Bernoulli binomial, nbinom2, nbinom1, beta, and gamma
  rows and complete balanced no-X/no-mask/no-CI mixed-family vector rows,
  response-scale ordinal probability/class prediction for ordinal and
  ordinal-probit rows, and raw unit-tier covariance / ordination accessors
  (`extract_Sigma()`, `extract_Sigma_B()`, `getResidualCov()`,
  `getResidualCor()`, `extract_ordination()`, `getLoadings()`, `getLV()`) on
  the retained engine scale, including complete balanced mixed-family rows.
  The read-only `gllvm_julia_gate_registry()` table maps `GJL-GATE-*` refusals
  to status, issue, and validation-row evidence so users can distinguish
  bridge gates from engine limits.
  `newdata` prediction, `newdata` simulation, unconditional random-effect
  redraws, ordinal residuals, ordinal simulation, richer extractor parity, and
  confidence intervals for
  per-trait ordinal rows, NB1-X rows, ordinal-X rows, mixed-family CIs, and
  response masks combined with fixed-effect X remain planned follow-up rows, as
  do mixed-family masks, mixed-family fixed-effect X, native parity promotion,
  and structured covariance terms. OUT: JuliaCall
  is a `Suggests` dependency only; every `engine = "julia"` path errors cleanly
  when JuliaCall or the GLLVM.jl project is unavailable, so the default TMB
  engine and `R CMD check` are unaffected on machines without Julia.

## Loading-constraint suggestion comparison (2026-06-09)

* Added `suggest_lambda_constraints()`, a plural companion to
  `suggest_lambda_constraint()` that compares several Lambda-constraint
  conventions in one call and returns a summary table plus the full
  suggestion objects. IN: the helper orchestrates the existing
  `varimax_threshold`, `wald_retention`, and optional `profile_retention`
  paths so users can compare point-threshold, Wald-retention, and
  profile-LRT pinning before refitting a confirmatory loading model
  (LAM-03, LAM-04). PARTIAL: the helper ranks the highest-evidence
  requested method as a statistical recommendation, but the biological
  interpretation of loading axes still requires a confirmatory hypothesis
  or a clearly stated exploratory orientation. OUT: no new likelihood,
  covariance, or interval-calibration machinery is added here.

## Latent-rank model-selection article (2026-06-09)

* Added the public `model-selection-latent-rank` article, "How many latent
  dimensions should I fit?", as a worked Gaussian default-`latent()` example
  for comparing candidate latent ranks. IN: the article uses a shipped
  deterministic teaching fixture with long and `traits(...)` wide formulas,
  compares a diagonal baseline and `d = 1`, `d = 2`, and `d = 3` candidates
  with `logLik()`, AIC, BIC, and `check_gllvmTMB()` rows, and interprets the
  selected covariance through rotation-invariant `Sigma` recovery (FG-04,
  FG-06, DIA-03, DIA-08, DIA-10). PARTIAL: the fixture shows one planted
  Gaussian rank where both AIC and BIC choose `d = 2`; it is not a simulation
  study proving AIC/BIC are universally calibrated latent-rank selectors.
  PLANNED: broader selection-rate grids, non-Gaussian high-rank rank-selection
  evidence, and calibrated interval claims remain separate validation work.

## Fit diagnostics article (2026-06-09)

* Added the public `fit-diagnostics` article, "Can I trust this fit?", as the
  first post-fit triage page before users interpret covariance, ordination, or
  interval summaries. IN: the article demonstrates `check_gllvmTMB()` and
  `gllvmTMBcontrol(se = FALSE)` status rows (DIA-08 / DIA-10), exact
  randomized-quantile residuals and fitted-model predictive displays for a
  scoped Poisson example (DIA-11 / DIA-12), and report-ready metadata through
  `diagnostic_table()` (DIA-13), with both long and `traits(...)` wide
  `gllvmTMB()` calls. PARTIAL: the displayed Q-Q plot and rootogram are
  diagnostic displays, not interval calibration, formal residual tests, latent
  rank selection, or Bayesian posterior predictive checks. PLANNED: exact
  residual support for delta, hurdle, truncated, ordinal, and mixture-family
  rows remains future validation work.

## Ordinary Gaussian reaction-norm component (#341, 2026-06-08)

* **`latent(1 + x | unit, d = K)`** and the long-form
  **`latent(0 + trait + (0 + trait):x | unit, d = K)`** now fit the ordinary
  individual-level Gaussian random-regression decomposition. IN: the parser
  routes the augmented LHS to dedicated B-tier TMB blocks with `Lambda_aug` and
  the default diagonal `Psi_B,aug` over the `2T` `(intercept, slope) x trait`
  coefficient vector, and `extract_Sigma(level = "unit_slope", part =
  "shared" / "unique" / "total")` returns `Lambda_aug Lambda_aug^T`, the
  augmented diagonal, or their sum (RE-12). Evidence:
  `test-ordinary-latent-random-regression.R` and
  `test-example-behavioural-reaction-norm.R` now cover parser classification,
  long and `traits(...)` wide fits, Gaussian default composition, explicit
  `+ unique(1 + x | unit)` compatibility composition, a deterministic Gaussian
  recovery fixture for the intercept-intercept, slope-slope, and
  intercept-slope covariance blocks, the explicit compatibility diagonal path, behavioural
  fixture long/wide agreement, a Poisson latent-only smoke fit, the rank guard,
  `unit_obs` rejection, mismatched-slope rejection, and the Gaussian-only
  augmented-`unique()` guard. PARTIAL: non-Gaussian augmented `latent()` remains
  low-rank-only and non-Gaussian augmented `unique()` remains guarded. OUT: bare
  `(1 + x | g)` random slopes remain reserved, and delta / hurdle families stay
  outside this slope-covariance lane (FAM-17 / MIX-10).

## Behavioural reaction-norm article kept internal pending reader review (#466, 2026-06-08)

* The `random-regression-reaction-norms` article is a buildable internal
  behavioural-syndrome draft, not a public Model guide article yet. It ships a
  reproducible example object with `individual` as the unit, `session_id` as
  the repeated occasion, long and wide `gllvmTMB()` formulas, diagnostics from
  `check_gllvmTMB()`, an augmented-covariance recovery figure, and
  temperature-specific repeatability curves. The current draft covers Gaussian
  ordinary `latent()` random slopes with default diagonal `Psi_B,aug`;
  non-Gaussian augmented diagonal `Psi`, calibrated intervals for slope
  summaries, and the plain-language reader path remain open before promotion.

## Structured random-slope article kept internal pending the phylogenetic reader path (#341, 2026-06-08)

* The `random-slopes-nongaussian` article still records the live structured
  random-slope boundary, but it is kept out of the public model guide while the
  phylogenetic GLLVM and structured-dependence reader path matures. The
  ordinary reaction-norm article is now a separate internal behavioural-syndrome
  draft and does not use the legacy single-variance slope keywords. IN: one
  structured random slope (`s = 1`) remains a point-estimate / recovery workflow
  across the covered phylogenetic and spatial grid (PHY-11..PHY-18,
  SPA-08..SPA-10), and Gaussian `phylo_dep(1 + x1 + x2 | species)` remains
  covered under RE-03. PARTIAL: non-Gaussian `phylo_dep(..., s >= 2)` stays
  fail-loud guarded while the RE-03 diagnostics continue. REJECTED for this
  article lane: delta, hurdle, and two-stage zero-inflated families, whose
  latent-scale covariance is blocked by FAM-17 / MIX-10. The article makes no
  calibrated-interval claim; CI-08 and CI-10 remain separate coverage gates.

## Spatial random slopes: full non-Gaussian family coverage (#453, 2026-06-05)

* **`spatial_latent(1 + x | site, d)`** augmented reduced-rank random slopes (SPA-09) now recover non-skipped under **all seven** supported families -- gaussian, binomial (probit/logit), poisson, nbinom2, Gamma, Beta, and ordinal_probit -- completing the block-diagonal spatial-latent slope cell alongside the already-complete `spatial_indep` (SPA-08) and `spatial_dep` (SPA-10) modes. The three count/probit/ordinal families that previously honest-skipped at the default fixture were a finite-sample **power** artifact, not non-identifiability: they identify cleanly at `n_sites = 150`, confirmed by the new `spatial-latent-slope-nongaussian-recovery` CI gate (`0 failed, 0 errored, 0 skipped across 7 tests`). No engine change -- the families were already on the `use_spde_latent_slope` allowlist; only the heavy test fixture's site count was raised.

# gllvmTMB 0.2.0 (first CRAN release)

First public release of `gllvmTMB`, a Template Model Builder (TMB)
engine for stacked-trait generalised linear latent variable models
(GLLVMs). `gllvmTMB()` fits multivariate models in which the same
observational units carry several responses -- traits, species,
items, behaviours, outcomes -- and the scientific question concerns
their shared latent covariance, ordination, communality,
phylogenetic signal, or spatial structure.

## 0.2.0 release summary

The headline capabilities below were validated across the 0.2.0
development cycle; the full dated entries are grouped by theme in
the **Capability landings during the 0.2.0 development cycle**
section further down.

* **Random-effect slopes under every family and structured mode.**
  Augmented random regression slopes (`(1 + x | ...)`) now fit
  across the full structured-covariance grid for every supported
  family — phylogenetic (`phylo_indep` / `phylo_latent` /
  `phylo_dep`; #341 / #381 / #388 / #392 / #422 / #424) and spatial
  (`spatial_indep` / `spatial_latent` / `spatial_dep`; #427 / #429),
  plus Gaussian multi-slope (s >= 2) on the full-unstructured
  `phylo_dep` path (#341). The non-Gaussian dependent cells
  (`phylo_dep`, `spatial_dep`) are the hardest in the grid and each
  family joined the allowlist only after a non-skipped CI recovery
  cell. `nbinom1` — the last remaining family — was admitted on the
  hardest `phylo_dep` cell (at `n_sp = 400`), completing the structured
  slope grid across every supported family (#350).
* **Generic dense-kernel covariance and cross-lineage coevolution.**
  The Design 65 dense-kernel quartet `kernel_unique()` /
  `kernel_indep()` / `kernel_dep()` / `kernel_latent()`,
  `make_cross_kernel()`, and `extract_Gamma()` add a phylo-equivalent
  dense-`K` surface and a validated cross-lineage coevolution
  workflow, with a buildable internal `cross-lineage-coevolution` article
  (#361).
  An identifiability guardrail now drops a redundant uniqueness tier
  with a warning — rather than aborting — when two `kernel_unique`
  tiers lack within-species replication (Design 65 C3.2; #361).
* **Animal-model keyword family.** The `animal_*` keyword row
  (`animal_scalar/unique/indep/dep/latent/slope`), `pedigree_to_A()`,
  and the `phylo_*` `A =` / `Ainv =` aliases complete the 4 x 5
  correlation-by-mode grid (M2.8 / M2.8b).
* **Missing data.** Response `NA` cells are accepted in long and wide
  data with `predict_missing()`, and one explicitly modelled `mi()`
  predictor is supported via `miss_control(predictor = "model")`,
  `impute_model()`, and `imputed()` for Gaussian, grouped,
  phylogenetic, binary, ordered, and unordered covariate models
  (#332 / #365).
* **Meta-analysis.** `meta_V(V = V)` is the canonical known-sampling-
  covariance marker, with `block_V()` and explicit fail-loud handling
  of the still-blocked `type = "proportional"` path (#227).
* **Diagnostics, extractors, and reporting.** `check_gllvmTMB()`,
  `predictive_check()`, `residuals()`, and `diagnostic_table()`
  (#228 / #248) plus a report-ready covariance/correlation surface:
  `extract_Sigma_table()`, `compare_Sigma_table()`,
  `plot_correlations()`, `plot_Sigma_table()`,
  `plot_Sigma_heatmap()`, `plot_Sigma_comparison()`,
  rotated-loading helpers, bootstrap-interval reuse across the
  extractors, and canonical `confint()` Sigma names (#233 follow-up).
* **Inference and fitting robustness.** Profile / Wald / bootstrap /
  Fisher-z intervals, the `coverage_study()` / `confint_inspect()` /
  `profile_targets()` validation surface, `check_identifiability()`,
  `gllvmTMB_check_consistency()`, multi-start / residual-start
  provenance, and the `link_residual = "auto"` default.
* **Stacked-trait simulators.** `simulate_site_trait()` and
  `simulate_unit_trait()` generate long-format data with a paired
  `truth` object for recovery checks; `simulate_unit_trait()` is the
  generic `(unit, observation, trait)` sibling without the phylogenetic
  / spatial machinery (#306).

### User-facing API

* One `gllvmTMB()` entry point fits one stacked-trait model:
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

  The ordinary decomposition mode is default `latent()`:
  `Sigma = Lambda Lambda^T + diag(psi)`. Explicit
  `latent() + unique()` remains compatibility syntax. Math notation uses
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

### Inference

* `gllvmTMB(REML = TRUE)` adds a narrow Gaussian-only restricted maximum-likelihood pilot. IN: ordinary Gaussian random-intercept fits and Gaussian covariance fits through default `latent()` (with explicit `latent() + unique()` retained as compatibility syntax) match `glmmTMB(..., REML = TRUE)` log-likelihoods and AIC degrees of freedom in `test-gaussian-reml.R` (MIS-33). PARTIAL: fixed-effect profile CIs are not available for REML fits; use Wald CIs or refit with `REML = FALSE` for ML profiling. PLANNED: non-Gaussian REML, observation weights, `miss_control(response = "include")`, and `mi()` predictor models remain guarded / deferred (MIS-32, MIS-33).
* Maximum-likelihood point estimates via TMB's Laplace approximation remain the default estimator.
* Profile-likelihood confidence intervals for derived quantities
  (repeatability, communality, phylogenetic signal, pairwise
  correlations) through the `profile_ci_*()` family.
* `extract_correlations()` exposes Fisher-z (default), Wald, and
  bootstrap intervals via the `method` argument.

### Phylogenetic and spatial paths

* Phylogenetic covariance via the sparse `A^-1` representation of
  Hadfield & Nakagawa (2010), with `tree` (an `ape::phylo`) or
  `phylo_vcv = Cphy` (a precomputed covariance matrix) as input.
* Spatial covariance via the SPDE / GMRF approximation from
  `sdmTMB`. `gllvmTMB` includes SPDE / mesh / anisotropy helpers
  (`make_mesh()`, `R/crs.R`, parts of `R/plot.R`) inherited from
  `sdmTMB` under GPL-3; provenance is recorded in `inst/COPYRIGHTS`
  and at the top of each inherited R file.

### Inherited code and citation

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

### Source-tree notes

* The TMB engine is compiled at install time from
  `src/gllvmTMB.cpp`. The DLL is registered via
  `useDynLib(gllvmTMB, .registration = TRUE)`.
* `gllvmTMBcontrol()` returns an options object distinct from
  `sdmTMB::sdmTMBcontrol()`. Extra `...` arguments emit a
  warning.

### Relationship to a pre-0.2.0 development line

The pre-0.2.0 development line of `gllvmTMB` re-exported a large
surface from `sdmTMB` and exposed single-response paths; the
0.2.0 release does neither. Users who want single-response models
should install `sdmTMB` or `glmmTMB` directly, which install
side-by-side with `gllvmTMB` without conflict.

## Capability landings during the 0.2.0 development cycle

These are the full dated development-cycle entries, grouped by
theme, preserved verbatim from the pre-release development log so
every PR reference and validation note remains available.

### Random-effect slopes across structured covariance modes

### Binomial augmented phylo random slopes (#341, 2026-05-31)

* **`phylo_indep(1 + x | sp)`** augmented random slopes now fit under the **binomial** family (probit and logit links), extending the previously Gaussian-only diagonal-Sigma_b cell (PHY-11). IN: the intercept-slope (co)variance is recovered with the intercept-slope correlation pinned to 0 by the model contract; a 6-seed grid recovers `sigma^2_int` / `sigma^2_slope` within a 0.25 relative band with every fit converging on a positive-definite Hessian (`test-binomial-slope-recovery.R`). This needed **no new C++**: the augmented-slope contribution enters the linear predictor before the family dispatch (the engine is family-agnostic), so activation was a single relaxed family guard in the fitting code. PARTIAL: the other non-Gaussian families (poisson / nbinom2 / Gamma / Beta / ordinal) on the `phylo_indep` augmented-slope path stay reserved fail-loud pending their own validation; the family-general `phylo_unique(1 + x | sp)` path already covers them where supported. PLANNED: the remaining `phylo_indep` non-Gaussian slope cells and the dependent / latent augmented-slope modes remain later B-slices.

### Non-Gaussian augmented phylo random slopes: poisson / nbinom2 / Gamma / Beta / ordinal (#341, 2026-05-31)

* **`phylo_indep(1 + x | sp)`** augmented random slopes now fit under **poisson** (log), **nbinom2**, **Gamma** (log), **Beta**, and **ordinal_probit**, extending the diagonal-Sigma_b cell beyond the Gaussian anchor and binomial (#381). IN: each family recovers the diagonal intercept/slope variances with the intercept-slope correlation pinned to 0 by the model contract; a 6-seed grid recovers `sigma^2_int` / `sigma^2_slope` for every family with every fit converging on a positive-definite Hessian, the correct runtime `family_id`, and `cor_b` held EXACTLY at 0 (`test-phylo-indep-slope-nongaussian.R`). Each family's recovery band is **inherited** from that family's existing correlated-slope cell (`test-matrix-slope-*.R`), not widened: poisson 4x, nbinom2 0.30 relative, Gamma 3x, Beta 0.40 relative, ordinal_probit 2.5x. The Gaussian anchor cell (`test-phylo-indep-slope-gaussian.R`) is also filled this cycle with a real recovery plus a wide `(1 + x)` vs long `(0 + trait + (0 + trait):x)` byte-identity check (replacing its Stage-3 skeleton skip). This needed **no new C++**: the augmented-slope contribution enters the linear predictor before the family dispatch (the engine is family-agnostic), so activation was a single one-line family-allowlist relax in the fitting code (the guard now admits runtime `family_id in {gaussian, binomial, poisson, Gamma, nbinom2, Beta, ordinal_probit}`). DISCIPLINE: a family was added to the allowlist only after its recovery cell passed; families OFF the allowlist (e.g. tweedie) still fail-loud-abort the augmented `phylo_indep` slope (locked in `test-matrix-slope-phylo-indep.R`). PLANNED: the dependent / latent augmented-slope modes (`phylo_dep` / `phylo_latent` LHS richer than `0 + trait`) for non-Gaussian families remain later B-slices.

### Non-Gaussian augmented phylo_latent random slopes (#341, 2026-05-31)

* **`phylo_latent(1 + x | sp, d = K)`** augmented reduced-rank random slopes now fit under **binomial** (probit and logit), **poisson** (log), **nbinom2**, **Gamma** (log), **Beta**, and **ordinal_probit**, extending the block-diagonal latent-slope cell beyond the Gaussian anchor (PHY-17). IN: each family converges on a positive-definite Hessian with the live latent-slope engine flag (`use_phylo_latent_slope == 1`, `n_lhs_cols_lat == 2`) and recovers the per-column slope-block variance (`report$Sigma_phy_slope_slope`) within the band inherited from that family's `test-matrix-slope-*.R` sibling (`test-matrix-slope-phylo-latent.R`, 56/56 expectations pass, 0 fail). The latent path is BLOCK-DIAGONAL across the (intercept, slope) LHS columns, so it estimates each column's Sigma_k separately with NO intercept-slope correlation; recovery is checked on the well-identified slope block (the `Sigma_phy_slope_*` report channel the Gaussian template uses), not the unstructured `sd_b` / `cor_b` channel. This needed **no new C++**: activation was the same one-line family-allowlist relax as the `phylo_indep` sweep (the guard now admits runtime `family_id in {gaussian, binomial, poisson, Gamma, nbinom2, Beta, ordinal_probit}`). Two pre-existing speculative-test bugs were also fixed: the engine-liveness guard was mis-keyed on the unique/dep flags (`use_phylo_slope` / `n_lhs_cols`, which are 0 / 1 on a latent fit) and the recovery harness read the absent `sd_b` / `cor_b` channel -- both repointed to the latent engine's actual flags and `Sigma_phy_slope_*` report. DISCIPLINE: a family was added to the allowlist only after its recovery cell passed; families OFF the allowlist (e.g. tweedie) still fail-loud-abort. PARTIAL: the **`phylo_dep(1 + x | sp)`** full-unstructured mode stays Gaussian-only -- the C x C (`C = 2*n_traits`) covariance is not yet identifiable for non-Gaussian families at the validation fixtures (every fit returns conv != 0 / non-PD Hessian up to `n_sp = 100`), so those cells honest-skip and the guard reserves them fail-loud (PHY-18). PLANNED: non-Gaussian `phylo_dep` slopes await a more identifiable parameterisation / larger n.

### Non-Gaussian augmented spatial_latent random slopes (#341, 2026-05-31)

* **`spatial_latent(1 + x | site, d = K)`** augmented block-diagonal reduced-rank SPDE random slopes now fit under **binomial** (probit and logit), **poisson** (log), **nbinom2**, **Gamma** (log), **Beta**, and **ordinal_probit**, extending the structured spatial latent-slope cell beyond the Gaussian anchor (SPA-09). IN: each family constructs and converges through the dedicated `use_spde_latent_slope` engine (live flag `use_spde_latent_slope == 1`, `n_lhs_cols_spde_lat == 2`); at the matrix fixture (n = 100, seed 20260529) four families (binomial-probit, poisson, Gamma, Beta) are positive-definite and pass the full health + slope-loading CI smoke, and three (binomial-logit, ordinal_probit, nbinom2) are non-PD at that one seed but PD at alternate seeds (202 / 303) and at n = 150 -- a power/seed artifact, not non-identifiability, so they stay allowlisted and honest-skip at the default fixture (`test-matrix-slope-spatial-latent.R`, 24 pass / 3 honest-skip / 0 fail). This needed **no new C++**: activation was the same family-allowlist relax as the phylo sweep (the `R/fit-multi.R` `use_spde_latent_slope` guard now admits runtime `family_id in {gaussian, binomial, poisson, Gamma, nbinom2, Beta, ordinal_probit}`). Three pre-existing speculative-test bugs were fixed, mirroring the #392 phylo_latent PR: the engine-liveness assertion was mis-keyed on the intercept-only `fit$use$spatial_latent` flag (which an augmented SLOPE fit does not set -- the augmented covstruct carries `.spatial_latent_augmented`, distinct from the intercept-only `.spatial_latent` marker), now repointed to `fit$use$spde_latent_slope` plus a path-live guard on `use_spde_latent_slope` / `n_lhs_cols_spde_lat`; the CI smoke read `extract_correlations(tier = "spatial")` / `confint("rho:spatial")`, which the block-diagonal latent path cannot surface (it exposes no `rho:spatial` token and `extract_correlations` keys on the intercept-only flag), now a finite sdreport SE on the reduced-rank slope loadings `theta_rr_spde_slope` (the spatial analogue of the #392 `theta_rr_phy_slope` smoke); and the nbinom2 expected `family_id` was corrected 3 -> 5. DISCIPLINE: a family was added to the allowlist only after its recovery cell passed; families OFF the allowlist (e.g. tweedie) still fail-loud-abort. PARTIAL: the **`spatial_dep(1 + x | site)`** full-unstructured mode stays Gaussian-only (SPA-10) -- the 2T x 2T (`C = 2*n_traits`) field covariance is not identifiable for non-Gaussian families at the validation fixtures (every fit returns conv != 0 / non-PD up to n = 100), the spatial analogue of `phylo_dep` (PHY-18), so those cells honest-skip (`test-matrix-slope-spatial-dep.R`, 7/7 skip, 0 fail) and the guard reserves them fail-loud. PLANNED: non-Gaussian `spatial_dep` slopes await a more identifiable parameterisation / larger n.

### Multi-slope (s >= 2) augmented phylo_dep random regression, Gaussian (#341, 2026-05-31)

* **`phylo_dep(1 + x1 + x2 + ... | sp)`** now fits two or more random slopes per species under the **Gaussian** family, lifting the previous s = 1 cap on the full-unstructured dependent path (RE-03). IN: the dep path generalises its column count from `2T` to `(1+s)T` and stacks each trait's `(intercept, slope_1, ..., slope_s)` columns into one INTERLEAVED block carrying the full unstructured `(1+s)T x (1+s)T` covariance `Sigma_b`; at s = 2 (two distinct within-species covariates `x1`, `x2`) the fit converges on a positive-definite Hessian and recovers the full `Sigma_b` within the bands inherited from the s = 1 dep cell (`test-phylo-dep-slope-s2-gaussian.R`, 986 expectations / 0 fail; slope-variance hat `{0.515, 0.293, 0.415, 0.373}` vs truth `{0.325, 0.266, 0.322, 0.260}`). The wide `1 + x1 + x2` and long `0 + trait + (0 + trait):x1 + (0 + trait):x2` surfaces are byte-identical, and `extract_Sigma(fit, level = "phy")` labels the rows `intercept.<t>`, `slope.<x_j>.<t>` (the s = 1 extractor keeps its bare `slope.<t>` name unchanged). This needed **no new C++**: the C++ dep likelihood is already dimension-general in `C = n_lhs_cols`, so activation was a purely R-side generalisation of the parser (`R/brms-sugar.R`, a dedicated multi-slope LHS classifier used only on the `phylo_dep` path), the Z fill + column count (`R/fit-multi.R`), and the extractor dimnames (`R/extract-sigma.R`). DISCIPLINE: multi-slope recognition is scoped to `phylo_dep` ONLY; every other augmented keyword (phylo_unique / indep / latent, spatial_*, relmat_*, animal_*) keeps the single-slope classifier and rejects `1 + x1 + x2` exactly as before -- all s = 1 slope tests pass unchanged. RESERVED: non-Gaussian s >= 2 stays fail-loud under a dedicated RE-03 runtime guard because the full unstructured covariance is not yet identifiable for non-Gaussian families (PHY-18). PLANNED: s >= 3 is mechanically supported (the code is general in `(1+s)`) but not yet gating-tested, and non-Gaussian multi-slope awaits a more identifiable parameterisation.

### Non-Gaussian augmented phylo_dep random slopes: all families (#422, #424, 2026-06-02)

* **`phylo_dep(1 + x | sp)`** augmented random slopes now fit under every supported family -- **poisson** (log, #422), then **Gamma** (log), **Beta**, **binomial** (probit/logit), **nbinom2**, and **ordinal_probit** (#424) -- closing the previously Gaussian-only full-unstructured dependent cell (PHY-18) and completing the phylo slope grid (scalar / indep / latent / dep × all families). IN: the full unstructured `2T x 2T` intercept/slope covariance `Sigma_b` is recovered with its free cross-correlation; each family converges on a positive-definite Hessian and recovers `Sigma_b` within the band inherited from that family's `test-matrix-slope-*.R` sibling, established by a real-API `*_VALIDATION` recovery cell (`test-matrix-slope-phylo-dep.R`) gated by a heavy `pull_request` recovery workflow. This needed **no new C++**: the C++ dep likelihood is already dimension-general in `C = n_lhs_cols`, so activation was a per-family relax of the `R/fit-multi.R` dep-slope family guard. DISCIPLINE: a family joined the allowlist ONLY after its recovery cell passed NON-SKIPPED in CI. This supersedes the earlier "`phylo_dep` non-Gaussian stays reserved (PHY-18)" PARTIAL notes in the entries below. PLANNED: non-Gaussian `phylo_dep` multi-slope (s >= 2) awaits its own identifiability gate.

### Non-Gaussian augmented spatial_indep random slopes (#427, 2026-06-02)

* **`spatial_indep(1 + x | coords)`** augmented SPDE random slopes now fit under **poisson** (log), **Gamma** (log), **Beta**, **binomial** (multi-trial), **nbinom2**, and **ordinal_probit**, extending the diagonal cross-field cell beyond the Gaussian anchor (SPA-08) -- the spatial mirror of `phylo_indep`. IN: the intercept/slope field variances are recovered with the intercept-slope correlation pinned to 0 by the model contract; each family's recovery cell fits a real `gllvmTMB(value ~ 0 + trait + spatial_indep(1 + x | coords))`, draws the SPDE field via a stable GMRF route (`backsolve(chol(Q), z)`), and reads marginal SDs from `extract_Sigma(level = "spatial")` plus field BLUPs from `omega_spde_aug` (`test-spatial-indep-slope-nongaussian.R`). All six family cells pass NON-SKIPPED in the heavy `pull_request` recovery gate (`0 failed, 0 errored, 0 skipped across 6 tests`). This needed **no new C++**: activation was a per-family relax of the BASE `spatial_unique` / `spatial_indep` guard in `R/fit-multi.R`. DISCIPLINE: a family joined the allowlist ONLY after its recovery cell passed non-skipped; the split `spatial_dep` guard was untouched (its non-Gaussian activation followed in #429).

### Non-Gaussian augmented spatial_dep random slopes: all families (#429, 2026-06-03)

* **`spatial_dep(1 + x | coords)`** augmented random slopes -- the FULL unstructured 2T×2T SPDE field-covariance cell, the hardest mode in the whole grid -- now fit under every supported family: **gaussian, binomial, poisson, Gamma, nbinom2, Beta, and ordinal_probit** (SPA-10). This closes the spatial slope grid (scalar / indep / latent / dep × all families) and is the spatial analogue of PHY-18 (`phylo_dep`). IN: the full unstructured intercept/slope field covariance is recovered with its free cross-field correlation; identifiability was established by a real-API `*_VALIDATION` recovery cell per family (`test-spatial-dep-slope-nongaussian.R`) gated by a heavy `pull_request` recovery workflow (final gate `0 failed, 0 errored, 0 skipped across 6 tests`). The count / proportion / ordinal families (nbinom2, Beta, ordinal_probit) need `n_sites = 1000` to identify the cross-field block (vs 400 for poisson / Gamma / binomial), and Beta's simulated response is clamped off the 0/1 boundary; poisson / Gamma / binomial pass at `n_sites = 400`. This needed **no new C++**: the augmented dep field enters the linear predictor before the family dispatch, so activation was a per-family relax of the `R/fit-multi.R` `use_spde_dep_slope` guard to `c(gaussian, binomial, poisson, Gamma, nbinom2, Beta, ordinal_probit)`. DISCIPLINE: a family joined the allowlist ONLY after its recovery cell passed NON-SKIPPED in CI. Supersedes the retired #425 identifiability spike (a hand-built SPDE-precision draw that produced no usable cells); the validation instead uses the package's own validated Gaussian spatial DGP. The base `spatial_unique` / `spatial_indep` guard (SPA-08, #427) is untouched.

### Generic dense kernels and cross-lineage coevolution

### Cross-lineage kernel prototype (#361, 2026-05-31)

* **`make_cross_kernel()`** builds a PSD cross-lineage block relatedness matrix from host relatedness, partner relatedness, and an association matrix (KER-01 / COE-01). IN: the helper returns a correlation-scale `K_star` that can be passed through the existing dense `phylo_latent(..., vcv = K_star) + phylo_unique(..., vcv = K_star)` prototype path, with heavy-test evidence for planted host-partner `Gamma` recovery on block-missing `traits(...)` data. PARTIAL: this is a C0 helper and prototype only; the generic `kernel_*()` formula family (KER-02) and validated `extract_Gamma()` coevolution gate (COE-02) are covered by the later C1/C2 entries above. PLANNED: two-kernel coevolution models and in-engine `rho` estimation remain later Design 65 slices.

### Generic dense-kernel covariance keywords (#361, 2026-05-31)

* **`kernel_latent()` and `kernel_unique()`** add the Design 65 C1 dense-kernel formula surface, with `kernel_indep()` and `kernel_dep()` as the marginal-only and full-rank companion modes (KER-02 / COE-02). IN: users can pass a named dense relatedness/covariance matrix `K` directly through `kernel_latent(unit, K = A, d = q, name = "known") + kernel_unique(unit, K = A, name = "known")`, and `extract_Sigma(fit, level = "known")` returns the named kernel-tier Sigma; the equivalence gate checks log likelihood and extracted Sigma against the existing dense `phylo_latent(..., vcv = A) + phylo_unique(..., vcv = A)` path to less than `1e-6`, with direct companion-mode checks against `phylo_indep(..., vcv = A)` and `phylo_dep(..., vcv = A)`. PARTIAL: this C1 slice reuses the phylo-equivalent dense relatedness engine slot and supports one named kernel tier. Cross-lineage `Gamma` extraction and the known-`Gamma` recovery gate are covered by the later C2 entry above; two-kernel models and in-engine `rho` estimation remain planned.

### Cross-lineage coevolution Gamma extraction (#361, 2026-05-31)

* **`extract_Gamma()`** adds the Design 65 C2 extractor for cross-lineage coevolution fits (COE-02). IN: after fitting a named dense-kernel tier such as `kernel_latent(species, K = K_star, d = 2, name = "cross") + kernel_unique(species, K = K_star, name = "cross")`, users can call `extract_Gamma(fit, level = "cross", row_traits = host_traits, col_traits = partner_traits)` to slice the host-trait x partner-trait shared covariance block from `extract_Sigma(part = "shared")`. Heavy-test evidence covers planted known-`Gamma` recovery on block-missing host/partner data, a block-diagonal zero-`Gamma` null with lower log likelihood, loading-orientation checks on the fitted recovery fixture, and a sparse-versus-dense single-`W` sensitivity case (`test-coevolution-recovery.R`). PARTIAL: `rho` is still supplied through `K_star` rather than estimated inside TMB, and `extract_Gamma()` returns point estimates without intervals. The `cross-lineage-coevolution` article shows the fixed-`rho` sensitivity-grid workflow, null comparison, and data-condition warnings as a buildable internal C2 workflow until the phylogenetic GLLVM reader path is public.

### Fixed-rho `Gamma_effect` extraction (#361, 2026-06-18)

* **`make_cross_kernel()` metadata and `extract_Gamma(scale = "effect")`** now make the Paper 2 shape/effect distinction explicit. IN: `make_cross_kernel()` records the fixed supplied `rho` on the returned `K_star`, fitted single-kernel and fixed multi-kernel tiers preserve that metadata in `fit$kernel_levels`, and `extract_Gamma(..., scale = "effect")` returns `Gamma_effect = rho * Gamma_shape` for tiers built from `make_cross_kernel()`. The default remains `scale = "shape"` (`Gamma_shape = Lambda_H %*% t(Lambda_P)`). Evidence covers a fast extractor contract test, the heavy one-kernel COE-02 recovery fixture, the heavy two-kernel COE-04 near-orthogonal fixture, and the regenerated coevolution teaching fixture (`test-coevolution-prototype.R`, `test-coevolution-recovery.R`, `test-coevolution-two-kernel.R`, `test-example-coevolution-kernel.R`). PARTIAL: this is a fixed-kernel transformation, not in-engine `rho` estimation or interval evidence; generic kernels without cross-kernel metadata fail loudly for `scale = "effect"` and should use the default `scale = "shape"`. `kernel_unique()` / `*_unique()` remain compatibility/Psi syntax for the current arc; post-arc lifecycle/deprecation work is separate.

### Cross-lineage coevolution worked example (#361, 2026-06-01)

* The new internal `cross-lineage-coevolution` article turns the Design 65 C2
  recovery gate into a buildable internal C2 workflow. IN: the article builds
  `K_star` with `make_cross_kernel()`, fits paired long-format and
  wide `traits(...)` calls through `kernel_latent()` plus
  `kernel_unique()`, compares a block-diagonal null, extracts
  `Gamma` with `extract_Gamma()`, and visualises truth vs fitted vs
  null covariance blocks (`COE-02`, `KER-02`). PARTIAL: the article
  reports point estimates only and treats `rho` as a fixed-kernel sensitivity
  parameter, not an in-engine estimate. PLANNED: calibrated
  intervals, multiple simultaneous kernel tiers, and in-engine `rho`
  estimation remain later Design 65 work.

### Animal-model keyword family and phylo aliases

### New exports (M2.8 animal-model keyword family, 2026-05-17)

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

### phylo_* `A =` / `Ainv =` aliases (M2.8b, 2026-05-17)

* The 5 `phylo_*` grid keywords (`phylo_scalar`, `phylo_unique`,
  `phylo_indep`, `phylo_dep`, `phylo_latent`) now accept **`A =`**
  and **`Ainv =`** as byte-equivalent aliases for **`vcv =`**.
  Aligns phylo_* with the M2.8 `animal_*` family's A-vs-V naming
  convention (A for relatedness, V for sampling variance —
  reserved for `meta_V()`, with `meta_known_V()` retained as a
  deprecated alias). The legacy `vcv =` continues to
  work unchanged through v0.3.0. Supplying both `vcv` and `A`
  (or both `vcv` and `Ainv`) errors with a typed message.

### Missing data

### Model-based missing predictors (#332 / #365, 2026-05-31)

* **`miss_control(predictor = "model")`, `impute_model()`, and `imputed()`** now expose the shipped model-based missing-predictor layer. IN: one explicitly modelled `mi()` predictor is covered for Gaussian fixed-effect, grouped-intercept, and phylogenetic-intercept covariate models, plus fixed-effect binary, ordered, and unordered discrete predictor models (MIS-25..MIS-31); `imputed()` reports conditional modes and Hessian SEs for continuous Gaussian predictors and fitted conditional probabilities / expected scores / modal categories for the exact finite-state discrete routes. PARTIAL: the response-mask extractor remains separate as `predict_missing()` (MIS-24), and phylogenetic borrowing should be checked with `phylo_signal_mi()` before interpreting weak-signal EBLUPs (MIS-28). PLANNED: multiple `mi()` terms, EM/profile/REML engines, simulated imputations, MI pooling, structured discrete predictor models, bounded/count/lognormal/Gamma predictor families, and MNAR sensitivity are not implemented (MIS-32).

### Missing response cells (2026-05-21)

* **Response `NA`s are now accepted in both long-format and wide `traits(...)` data.** IN: missing unit-trait response cells can be treated as unobserved cells while preserving other observed traits for the same unit; for `cbind(successes, failures)` responses, a row is treated as response-missing when either component is missing; weights are subset to retained likelihood rows before validation, and `predict_missing()` reports fitted values for the masked-response route (MIS-21 / MIS-24). PARTIAL: this is response-missingness support only. Ordinary missing predictors, grouping variables, design-matrix entries, offsets, weights, or all-missing traits still require user-side cleaning unless the predictor is one of the explicitly modelled `mi()` slices covered in MIS-25..MIS-31.

### Meta-analysis

### `meta_V()` formula-marker syntax (#227, 2026-05-20)

* **`meta_V()`** now uses `meta_V(V = V)` or `meta_V(V, type = "exact")` as the canonical known-sampling-covariance formula marker. IN: exact additive known-V workflows remain the implemented surface (MET-01 / MET-02), and wide `traits(...)` formulas now preserve `meta_V()` as a covariance marker. PARTIAL: single-V statistical validation is still smoke-level under MET-01. PLANNED: `type = "proportional"` remains blocked under MET-03 and now errors explicitly rather than being silently treated as exact. The older parser spelling `meta_V(value, V = V)` and deprecated alias `meta_known_V(V = V)` remain accepted for compatibility.

### Diagnostics, extractors, and reporting helpers

### Programmatic identifiability diagnostics (#248, 2026-05-24)

* **`check_gllvmTMB()`** now adds symbolizer-facing latent-identifiability rows to its machine-readable fit-health table (DIA-08 / DIA-10). IN: the table reports Hessian rank, loading-rotation convention, weak latent-axis share, near-zero per-trait `psi` standard deviations, near-boundary estimated `sigma_eps`, and broad cross-loading structure alongside the existing optimizer, gradient, `sdreport()`, `pdHess`, fixed-effect SE, restart, and boundary rows. PARTIAL: these rows are heuristic diagnostics for fitted models; they do not calibrate interval coverage or prove that the selected latent rank is scientifically preferred. PLANNED: simulation/refit rank checks remain the job of `check_identifiability()` and the M3 validation grid.

### Fitted-model predictive diagnostics (#228, 2026-05-25)

* **`diagnostic_table()`** extracts report-ready tables from `predictive_check()` plots and diagnostic `residuals()` outputs without making articles inspect `attr(x, "gllvmTMB_diagnostic")` directly (DIA-13). IN: users can request plotted/residual `"data"`, `"row_status"` counts, `"fit_health_status"` counts, or the attached `"check_gllvmTMB"` table. PARTIAL: this is a table-extraction helper over existing metadata; it does not compute new residuals, run formal tests, refit models, or calibrate uncertainty. PLANNED: Tier-1 diagnostic articles can now build stable examples on this table path after Florence/Fisher review.
* **`predictive_check()` and `residuals()`** now provide the public fitted-model diagnostic surface promoted from the #222 prototype (DIA-11 / DIA-12). IN: `predictive_check()` returns `ggplot` objects for randomized-quantile Q-Q checks, count rootograms, grouped statistics, and density overlays, with plotted data, `check_gllvmTMB()` rows, and `fit$fit_health` metadata attached in `attr(plot, "gllvmTMB_diagnostic")`; `residuals(fit, type = "randomized_quantile")` computes exact family-CDF residuals for Gaussian, Poisson, and NB2 rows, while `type = "simulation_rank"` remains the fitted-model simulation fallback. PARTIAL: these checks diagnose the fitted response distribution but do not calibrate intervals, prove latent rank, run formal DHARMa-style tests, or draw from a Bayesian posterior. PLANNED: exact residuals for delta, hurdle, truncated, ordinal, and mixture families remain future validation work.

### Report-ready Sigma tables (#233 follow-up, 2026-05-21)

* **`extract_Sigma_table()`** is a new report-ready table view over `extract_Sigma()` for covariance and correlation entries, with stable columns for `estimand`, trait pair, level, component, estimate, interval status, scale, validation row, and matrix position. IN: point-estimate Sigma/Psi/R tables for levels already handled by `extract_Sigma()` are covered by EXT-18, with underlying mixed-family Sigma evidence in MIX-03. PARTIAL: fitted-model interval columns are intentionally `NA` / `none`; use `extract_correlations()` or `bootstrap_Sigma()` for interval estimates, and `compare_Sigma_table()` / `plot_Sigma_comparison()` for known-truth comparisons. PLANNED: richer article-specific calibration summaries remain future work.

### Covariance/correlation plot helpers (2026-05-21)

* **`plot_correlations()` and `plot_Sigma_table()`** are new ggplot helpers for report-ready covariance and correlation rows. IN: tidy rows from `extract_correlations()` and `extract_Sigma_table()` can be drawn as forest plots or confidence-eye compatibility displays with metadata attached to `gllvmTMB_meta` / `gllvmTMB_data` (EXT-19). The first public integrations are in the README example, Get Started, Morphometrics, and Covariance/correlation articles. PARTIAL: these helpers display supplied finite interval bounds but do not compute new intervals; rows without finite interval bounds are shown as open points, and `plot_Sigma_table(style = "eye")` needs interval-bearing input rows. For fitted correlations, open points can often be investigated with `extract_correlations(..., method = "bootstrap")`; Sigma-table confidence eyes need bootstrap-derived or otherwise interval-bearing rows. Confidence eyes show frequentist compatibility, not posterior density, and omit CI lines by default so the hollow estimate circle and pale compatibility shape carry the display. Set `show_intervals = TRUE` to overlay interval lines when needed. `style = "raindrop"` remains a compatibility alias. PLANNED: hidden/technical article integration and vdiffr snapshots remain future figure work.

### Bootstrap Sigma table rows (2026-05-21)

* **`extract_Sigma_table()`** now accepts `bootstrap_Sigma()` objects and returns the same report-ready row schema with bootstrap percentile `lower` / `upper` columns filled in (EXT-20). IN: Sigma and correlation summaries already present in the bootstrap object can be converted to tidy rows and passed directly to `plot_Sigma_table()` for interval forests or confidence-eye displays. PARTIAL: this does not compute bootstrap intervals itself and does not add shared/unique component covariance intervals; communality and repeatability reuse are covered separately by EXT-21 and EXT-22. PLANNED: broader Figure-3 visual QA remains future work.

### Communality bootstrap interval rows (2026-05-21)

* **`extract_communality()`** now accepts `bootstrap_Sigma()` objects containing `communality` summaries and returns the stored per-trait point estimates plus percentile `lower` / `upper` columns when `ci = TRUE` (EXT-21). IN: bootstrap communalities already computed by `bootstrap_Sigma(..., what = "communality")` can be reused in reports without rerunning refits, and `plot(type = "communality", boot = boot)` can overlay `c^2` boundary intervals on the stacked communality / uniqueness bars. PARTIAL: this reuses bootstrap-object summaries only; fitted-model calls still compute their own profile or bootstrap intervals through `extract_communality(fit, ci = TRUE, method = ...)`, and the communality plot is still object-shape tested rather than vdiffr snapshot tested. PLANNED: a broader Figure-3 visual audit remains the next inference-plot step.

### Repeatability bootstrap interval rows (2026-05-21)

* **`extract_repeatability()`** now accepts `bootstrap_Sigma()` objects containing `ICC_site` summaries and returns the stored per-trait repeatability estimates plus percentile `lower` / `upper` columns (EXT-22). IN: bootstrap repeatability already computed by `bootstrap_Sigma(..., what = "ICC", level = c("unit", "unit_obs"))` can be reused without rerunning refits, and `plot(type = "integration", boot = boot)` now accepts a raw `bootstrap_Sigma()` object for repeatability and communality whiskers. PARTIAL: this reuses bootstrap-object summaries only; fitted-model calls still compute their own profile, Wald, or bootstrap intervals through `extract_repeatability(fit, method = ...)`, and the integration plot remains object-shape tested rather than vdiffr snapshot tested. PLANNED: a broader Figure-3 visual audit remains the next inference-plot step.

### Correlation ellipse bootstrap intervals (2026-05-21)

* **`plot(type = "correlation")` and `plot(type = "correlation_ellipse")`** now accept a `bootstrap_Sigma()` object through `boot` and merge stored `R_B` / `R_W` percentile bounds into the plotted correlation data (EXT-23). IN: heatmap and ellipse plot metadata now report interval availability, and the ellipse plot marks supplied intervals that do not cross zero with black borders and stars. PARTIAL: the plot does not run bootstrap refits and only uses correlation summaries already present in the bootstrap object. PLANNED: vdiffr snapshots and broader hidden/technical Figure-3 QA remain future work.

### Direct bootstrap correlation plots (2026-05-21)

* **`plot_correlations()`** now accepts `bootstrap_Sigma()` objects containing `R_B` / `R_W` summaries and converts them to the same row-first correlation plotting schema used by `extract_correlations()` rows (EXT-24). IN: users can call `plot_correlations(boot, style = "eye")` after `bootstrap_Sigma(..., what = "R")` without hand-building pairwise rows; `style = "raindrop"` remains a compatibility alias. PARTIAL: this is a display bridge only; it does not run bootstrap refits, and matrix-style truth overlays remain article code. PLANNED: rendered article examples using stored bootstrap fixtures remain future Figure-3 QA work.

### Cached morphometrics bootstrap plot fixture (2026-05-21)

* **Morphometrics article fixture** now ships a small cached `bootstrap_Sigma(..., what = "R")` object and uses it to render the confidence-eye correlation display plus `plot(type = "correlation_ellipse", boot = boot)` without running bootstrap refits during pkgdown builds (MIS-22 / EXT-23 / EXT-24). IN: the article demonstrates the direct bootstrap plotting path on a reproducible stored object. PARTIAL: the fixture is for teaching and visual QA, not interval-calibration evidence for a scientific claim. PLANNED: fuller bootstrap calibration belongs in simulation-grid or study-specific workflows.

### Bootstrap provenance in plot metadata (2026-05-21)

* **`plot_correlations()` and `plot_Sigma_table()`** now preserve extractor notes in `attr(p, "gllvmTMB_meta")$notes`, including cached bootstrap provenance such as `n_boot`, failed refits, and confidence level when the input came from `bootstrap_Sigma()` (EXT-19 / EXT-20 / EXT-24). IN: report and article code can audit interval provenance from the plot object. PARTIAL: this records existing extractor notes only; it does not compute new intervals or validate bootstrap calibration. PLANNED: richer article-level provenance summaries remain future reporting work.

### Sigma estimate-vs-truth table helper (2026-05-21)

* **`compare_Sigma_table()`** joins report-ready `extract_Sigma_table()` rows to a supplied covariance or correlation truth matrix for simulation and teaching figures (EXT-25). IN: example articles can build estimate-vs-truth tables without hand-indexing matrices. PARTIAL: this is a table helper only; use `plot_Sigma_comparison()` for the current visual layer, and keep richer calibration summaries as future visualization work.

### Sigma estimate-vs-truth plot helper (2026-05-21)

* **`plot_Sigma_comparison()`** plots `compare_Sigma_table()` rows as row-labelled error plots or estimate-vs-truth scatter plots for simulation and teaching figures (EXT-26). IN: example articles can show `estimate - truth` without hand-building ggplot scaffolding, including `facet = "comparison"` panels for precomputed rows from several model specifications. PARTIAL: this is a visual comparison helper only; it does not run simulations, compute intervals, or validate calibration. PLANNED: article-specific calibration summaries remain future visualization work.

### Sigma heatmap plot helper (2026-05-21)

* **`plot_Sigma_heatmap()`** plots `extract_Sigma_table()` rows as trait-by-trait covariance or correlation heatmaps (EXT-27). IN: articles and reports can show matrix block structure without extracting `Sigma`, calling `cov2cor()`, or hand-building `geom_tile()` layers; the first integration replaces the functional-biogeography article's bespoke correlation heatmaps. PARTIAL: heatmaps show point estimates only and do not display uncertainty intervals or truth comparisons. PLANNED: vdiffr snapshots and richer multi-model layout helpers remain future visualization work.

### Rotated loading plot helper (2026-05-23)

* **`plot_rotated_loadings()`** draws a report-ready loading matrix from a fitted model or from `extract_rotated_loadings_table()` rows (EXT-29). IN: users can make Figure-3-style loading panels without hand-pivoting `Lambda`, with varimax/promax/none rotation, shared-variance axis ordering, sign anchoring, standardized or raw loadings, visible numeric values for small matrices, and plot metadata in `gllvmTMB_meta` / `gllvmTMB_data`. PARTIAL: the helper displays point-estimate loadings only and does not compute loading uncertainty intervals; rotated axes remain interpretive descriptions, not uniquely identified biological truths. PLANNED: bootstrap- or simulation-aligned loading uncertainty and richer gallery layouts remain later visualization slices.

### Rotated loading table helper (2026-05-23)

* **`extract_rotated_loadings_table()`** returns report-ready tidy rows from the same rotation workflow used by `rotate_loadings()` and `plot(type = "ordination")` (EXT-28). IN: users can extract one row per trait × latent axis with `loading`, `abs_loading`, raw `axis_variance` / `axis_share`, `rotation`, `order_axes`, `sign_anchor`, `anchor_trait`, and `loading_scale`, including standardized loadings that match ordination-arrow scaling. PARTIAL: this is a point-estimate interpretation table; it does not compute loading uncertainty intervals and does not replace covariance, correlation, communality, or uniqueness as the primary rotation-invariant summaries. PLANNED: bootstrap or simulation-based uncertainty for loadings remains a later inference slice.

### Rotated ordination sign anchors (2026-05-22)

* **`plot(type = "ordination")`** now exposes the rotation workflow directly through `order_axes`, `sign_anchor`, and `anchor_traits`, matching `rotate_loadings()` for report-ready biplots (EXT-15 / MIS-09). IN: users can make varimax or promax ordination plots with shared-variance axis ordering and biologically pre-specified sign anchors, e.g. `anchor_traits = c("mass", "wing")`, without hand-rotating scores and loadings. PARTIAL: this is a plotting convention for interpretable axes; covariance, correlation, communality, and uniqueness remain the primary rotation-invariant summaries. PLANNED: visual snapshots and broader article gallery coverage remain future figure QA work.

### Correlation matrix plot options (2026-05-23)

* **`plot_correlations()`** now draws report-ready matrix views from the same tidy rows used by its forest and confidence-eye displays (EXT-30). IN: users can call `style = "heatmap"` or `style = "ellipse"` / `"oval"` on fitted-model, `bootstrap_Sigma()`, or `extract_correlations()` rows; choose `triangle = "full"`, `"lower"`, or `"upper"`; include or omit diagonal cells; print estimates, interval bounds, or both inside cells; and use `matrix_layout = "estimate_ci"` for upper-triangle estimates plus lower-triangle interval bounds, or `matrix_layout = "levels"` to combine exactly two levels such as `unit` and `unit_obs` in one matrix. PARTIAL: the matrix styles display supplied intervals only as numeric labels and significance outlines/stars when bounds exclude zero; they do not compute new intervals, calibrate bootstrap uncertainty, or compare to known truth. PLANNED: broader visual snapshots and gallery/article layouts remain future visualization QA.

### Canonical `confint()` Sigma names (2026-05-22)

* **`confint()`** now accepts canonical Sigma parameter names `parm = "Sigma_unit"` and `parm = "Sigma_unit_obs"` alongside the legacy aliases `"Sigma_B"` and `"Sigma_W"` (CI-02 / CI-03; underlying extraction EXT-01). IN: users can request unit- and unit-observation covariance intervals with the same naming used by `extract_Sigma(level = "unit")` and `extract_Sigma(level = "unit_obs")`; returned `parameter` labels follow the requested `parm` so existing scripts keep their legacy labels. PARTIAL: profile intervals for full decomposed Sigma entries still fall back to bootstrap, and non-Gaussian bootstrap calibration remains experimental under EXT-13 / CI-10. PLANNED: richer derived-profile intervals and broader calibration evidence remain M3 work.

### Inference, fitting robustness, and the validation milestone surface

### Robust modelling diagnostics and start provenance (M3.4, 2026-05-19)

* **`check_gllvmTMB()`** is a new machine-readable fit-health table for `gllvmTMB_multi` fits. It reports optimizer convergence, maximum gradient, `sdreport()` availability, `pdHess`, maximum fixed-effect SE, restart-history availability, selected restart, and simple boundary flags. `gllvmTMBcontrol(se = FALSE)` now intentionally skips `TMB::sdreport()` and keeps the point-estimate fit for bootstrap/profile uncertainty workflows. `pdHess = FALSE` is reported as an inference / identifiability warning, not automatic proof that point estimates or rotation-invariant covariance summaries are unusable. Fits now also retain `restart_history`, `start_provenance`, `fit_health`, and `sdreport_error` fields so multi-start, residual-start, simpler-start, and optimizer-fallback workflows can be audited before they are promoted by M3 target-explicit simulation evidence.

### Bootstrap covariance scale control (M3.3a, 2026-05-19)

* **`bootstrap_Sigma()`** gains `link_residual = c("auto", "none")`, matching `extract_Sigma()` so bootstrap point estimates and refit summaries can either include family/link implicit residuals (`"auto"`, the existing default) or report the fitted model covariance without link-residual additions (`"none"`). IN: mixed-family bootstrap refits still preserve per-row family dispatch (MIX-08) and the default link-residual formulas remain covered (MIX-09). PARTIAL: non-Gaussian bootstrap inference remains experimental under EXT-13 / CI-08 / CI-10 until the M3 target-explicit grid is rerun with the corrected `Sigma_unit_diag` convention.

### New exports (Phase 1b validation milestone)

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

### Behaviour changes (Phase 1b validation milestone)

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

### New exports (P1a audit response)

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

### Behaviour changes (P1a audit response)

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
  `{Sigma_unit, Sigma_unit_obs, sigma_phy}`, with legacy aliases
  `{Sigma_B, Sigma_W}`) and the fixed-effect Wald / profile paths are
  unchanged.

### New exports (Phase 1b)

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

### Behaviour changes (Phase 1b)

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
