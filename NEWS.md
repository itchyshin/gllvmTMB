# gllvmTMB 0.6.0

This release focuses on multivariate stacked-trait models fitted through the
R/TMB engine. Models are fitted by **Laplace approximation**. The optional Julia
bridge remains experimental and is not required for the main workflow.

## New

* **Spatial mesh, CRS, and range-plot helpers are now independently authored
  gllvmTMB code.** `make_mesh()` returns a `gllvmTMBmesh` built through
  fmesher's public mesh, finite-element, and basis APIs, while valid legacy
  `sdmTMBmesh` objects receive a temporary lifecycle warning and conversion.
  `plot_anisotropy()` and `plot_anisotropy2()` now show the fitted isotropic
  practical range, `sqrt(8) / kappa`, for native gllvmTMB spatial fits. Equal
  axes are explicitly the model assumption `H = I`; gllvmTMB does not estimate
  directional anisotropy. Delta and spatiotemporal states remain unsupported.
  This changes no TMB likelihood or spatial covariance parameterisation.
  The mesh/plotting helpers themselves are covered by focused tests; broader
  spatial-family evidence remains partial; directional anisotropy,
  delta/spatiotemporal fields, barriers, and new spatial likelihoods are
  rejected here.

* **`offset()` now works, for count responses.** `offset(log(trap_nights))`
  in a Poisson or negative-binomial model is the standard way to model a rate
  rather than a raw count, and until now gllvmTMB rejected it. Both closest
  comparators offer offsets, so this was a gap rather than a rough edge — and
  for counts there is no workaround, since an effort adjustment cannot be
  folded into the response the way a Gaussian one can be centred by hand.

  **It is deliberately restricted to count families** — `poisson()`,
  `nbinom1()`, `nbinom2()`, `truncated_poisson()`, `truncated_nbinom2()`.
  An offset is a multiplicative rate adjustment on the log link; under
  `gaussian()` it would be an unexplained mean shift and under `binomial()`
  a fixed shift in log-odds, neither of which is what the term is for. In a
  stacked model the check is per trait, so the refusal says which one:

  ```
  offsets are supported for count families (poisson, nbinom) only;
  trait `t2` uses `gaussian`.
  ```

  This is the advantage of a mixed-family design rather than a cost of one.
  A single-family package can only recycle one offset across every response.

  **A zero offset is allowed everywhere and does nothing**, because zero on
  the log scale is a multiplier of one. That is how a mixed-family model
  gives an offset to its count traits and not the rest — set the offset
  column to `0` on the other rows. In wide format, `offset(w)` applies one
  unit-level column to every trait, while `offset(e1, e2)` gives one column
  per trait in `traits()` order.

  The offset also reaches `simulate()`, `bootstrap_Sigma()`,
  `coverage_study()`, and `predict(newdata = )` — all of which rebuild the
  linear predictor themselves and would otherwise have used a model you did
  not fit. `predict(newdata = )` needs the offset variable present in
  `newdata` and says so if it is missing. `engine = "julia"` has no offset in
  its predictor and refuses the term rather than dropping it.

  Offsets inside an `lv = ~ ...` sub-formula, or inside an `impute` / `mi()`
  covariate formula, are still not supported.

* **A loading penalty is available for fits that run away, via
  `gllvmTMBcontrol(aghq_ridge = tau)`.** Binomial fits at small sample sizes can
  drive one trait's loading to an absurd value while reporting every
  conventional sign of health — `convergence = 0` and a positive-definite
  Hessian — because quasi-complete separation makes that solution the genuine
  maximum of the likelihood. A Gaussian ridge on the loadings adds curvature
  where the likelihood is flat and removes the runaway: measured at **47% of
  fits down to 0%** at n = 100, and on one reproduction fit it takes the largest
  implied loading norm from 979.1 to 3.35.

  The penalty is **opt-in and never applied unless you name it**, so no existing
  fit changes. `tau` is the prior standard deviation on each free loading, and
  its scale is set by the model rather than tuned: the latent scores are
  standard normal by identification, so a loading is the trait's latent standard
  deviation in link units, making `tau = 2` weakly informative. Its influence
  also vanishes as the sample grows, because a fixed penalty contributes a
  constant against a log-likelihood growing with n. The penalty is
  rotation-invariant.

  Two costs, stated plainly. A penalised fit is a **maximum-a-posteriori point,
  not a maximum-likelihood estimate**, so `logLik()`, `AIC()` and `BIC()` no
  longer describe it — set `aghq_ridge = Inf` and refit every model being
  compared if you need likelihood-based comparison. And the penalty currently
  covers the unit-tier loadings only. `check_gllvmTMB()` now names this remedy
  when it reports a runaway loading.

  `aghq_ridge = "auto"` adds a narrower **experimental, opt-in** scale-aware
  route for pure single-trial Bernoulli models with one ordinary unit-tier
  `latent()` block. It first runs an unpenalised 9-node multi-start AGHQ pilot,
  then uses
  `tau = min(6, max(1, ||Lambda_pilot||_F / sqrt(p q)))`. A plain Laplace fit is
  never used as the scale yardstick. If that pilot or the scale-aware final fit
  is unusable, the function returns an independently started `tau = 2` fit and
  records the reason in `fit$aghq$ridge_auto`; it does not silently claim that
  auto-selection succeeded. Both pilot and returned AGHQ fits use the calibrated
  9-node multi-start estimator; conflicting `aghq` or `aghq_multistart` controls
  are replaced with a warning.

  This scope is supported as a **runaway/failure-avoidance** capability, not as
  a general accuracy improvement. In the 600-replicate calibration,
  the auto fit was usable in 135 replicates. A transparent auto-when-usable,
  otherwise-`tau = 2` policy did not increase per-cell failure or runaway rates
  and stayed within the preregistered +0.02 loading-error non-inferiority margin,
  but its six-cell macro-mean loading-error difference was +0.00282 (slightly
  worse).
  Caps 5, 6, and 8 were indistinguishable for fresh valid pilots; cap 6 is the
  smallest candidate supported by the stored wider-range rescore. Other
  families, covariance tiers, and likelihood-based model comparison remain
  outside this claim. The measured grid used logit, `p = 6`, `q = 2`, and
  `n = 100`, `400`, or `1600`; other links and dimensions are explicit
  extrapolations, not covered accuracy claims. The package default stays
  `tau = 2`.

* **Adaptive quadrature (`gllvmTMBcontrol(aghq = k)`) now tries two starting
  points and keeps the better fit.** It previously ran from a single start — the
  Laplace optimum — on the grounds that without a penalty there is nothing to
  choose between two starts. That holds for two *starting points*; it does not
  hold for two *converged fits*, which can simply be compared. It matters
  because the Laplace optimum is sometimes itself a runaway, and quadrature then
  inherits it: measured over 40 binomial fits at n = 100, sixteen ran away
  catastrophically, and on **all sixteen** the second start reached a strictly
  better objective — by 1.1 to 12.9 in negative log-likelihood — and a far more
  plausible loading matrix. Catastrophic fits fell from **16 in 40 to 1 in 40**.

  The second start is data-driven and uses no knowledge of the truth; the cost
  is one extra adaptation run. `aghq_multistart = FALSE` restores the previous
  single-start behaviour exactly. Note that this switch was documented but
  **did not previously take effect**, because it was not among the arguments
  `gllvmTMBcontrol()` accepted.

* **Quadrature fits can now report convergence at realistic sample sizes, and
  every stop says why.** The convergence test compared the gradient against a
  fixed threshold. Because a likelihood's gradient grows with the amount of
  data, that threshold became unreachable as the sample grew: no fit at n = 400
  or n = 1600 could be certified as converged, in any family tried — including
  cases where the quadrature had landed on precisely the point the Laplace fit
  reported as converged. The test now also accepts a **relative** gradient
  (`aghq_grad_tol_rel`). This changes the verdict, not the estimate: fits are
  identical either way.

  Every stopping condition now reports its gradient, including the one that
  previously reported none, so a genuine stall can be distinguished from a near
  miss. Read `fit$aghq$converged` for the verdict — **not**
  `fit$opt$convergence`, which on this path records the optimiser's per-pass
  iteration cap and therefore reports a limit even on a healthy fit. `fit$aghq`
  also now carries `grad_max`, `grad_rel`, and how many starts were run.

* `getLV()` gains an `se = TRUE` argument that returns the standard error of
  every unit-level (or within-unit) latent score, alongside the scores, as
  `list(scores, se)`. The default `se = FALSE` is unchanged (a bare matrix).
  SEs come from the fitted model's TMB `sdreport()` random-effect block and
  were cross-checked against an independent joint-precision-inversion route
  to machine precision. Requires `rotate = "none"`; predictor-informed
  `latent(..., lv = ~ x)` fits and `engine = "julia"` bridge fits are not
  yet supported and raise an informative error.
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
  responses. This is fit admission only:
  direct route-specific recovery and inference evidence are not yet covered, so
  this release makes no scientific-validation claim for those combinations.
* New **`multinomial()`** response family for an *unordered* categorical response
  with three or more categories (baseline-category logit / softmax). It recovers the
  per-category intercepts and slopes as contrasts against a reference category, and
  `predict(type = "response")` returns per-category probabilities. Use
  `multinomial(baseline = ...)` to choose the reference category. The validation
  boundary is explicit: **fixed-effect point recovery is validated** — no
  detectable bias (|bias| ≤ 0.02 per coefficient across a 500-seed calibration,
  with recovery asserted on a 20-seed aggregate at `K = 3` and `K = 4` rather
  than any single fit) — and that is a statement about the estimates, not about
  their intervals. The two covariance routes — a single `phylo_latent()` term,
  and the narrow ordinary shared-`latent()` cross-family route — are
  **only partially validated**, meaning
  they fit and report but their recovery has not been certified. The latter reports the nominal
  trait as its `K - 1` baseline-contrast block rather than inventing one scalar
  categorical correlation; it permits one multinomial trait per fit and rejects
  unsupported tiers before TMB construction. Multiple multinomial traits,
  augmented slopes, explicit multinomial `unique()`/`indep()`, and unlisted
  source tiers remain blocked. A two-category response is
  `binomial(link = "logit")`. For
  *ordered* categories use `ordinal_probit()`. See the *Unordered categories with
  `multinomial()`* article for a worked diet-guild example.
* **`phylo_latent()` on a `multinomial()` trait (partially validated)** reports the
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
* For the admitted cross-family nominal route (partially validated), ordinary
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
* **Known limitation — random-slope covariance is not calibrated when each
  cluster carries little information.** This is a limitation of the *data
  regime*, not of one keyword: it applies to any random-slope covariance fitted
  on **single-trial binary responses with few observations per grouping level**,
  and it affects both the current `phylo_indep()` / `animal_indep()` /
  `spatial_indep()` slope forms and the soft-deprecated `*_unique()` forms.
  Measured on a phylogenetic slope fit with a logit link (60 species, 4
  replicates, 3 traits — 12 single-Bernoulli observations per species), the
  **whole 2x2 slope covariance is over-estimated**, not just its slope entry:

  | target | true | relative error |
  |---|---|---|
  | intercept variance | 0.40 | **0.82** |
  | slope variance | 0.30 | **0.78** |
  | intercept-slope correlation | 0.50 | **0.367** (absolute) |

  The bias does **not** shrink with more clusters — it persists across 60, 120
  and 240 species — on fits that are otherwise healthy (converged,
  positive-definite Hessian, valid `sdreport`). The cause is too little
  information per cluster: with a handful of single-trial binary observations
  per species, the sampling variance of each species' estimated slope is
  comparable to the true between-species variance itself, so roughly half the
  spread across species is sampling noise. The identical design recovers cleanly
  under a Gaussian response, which is what rules out an engine problem.

  **Do not read a random-slope variance or correlation from sparse binary data
  as calibrated.** The remedy is more information *per* grouping level — more
  replicates per species, or multi-trial `cbind(successes, failures)` data
  instead of single 0/1 draws — rather than more species. Note also that the
  binomial slope routes are covered by a **structural** contract only: those
  tests check that the model fits and reports the right shapes, and
  **deliberately do not certify variance recovery or interval calibration**. The
  corresponding recovery test is deliberately skipped rather than passed by
  retuning its data-generating truth.
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

* **The default number of bootstrap replicates is now 999, raised from 200.**
  `bootstrap_Sigma()` is the only exported function whose signature changes.
  The same raise was applied to the internal bootstrap paths behind
  `extract_lv_effects()`, `extract_communality()`, `extract_repeatability()`,
  the loading intervals, and the phylogenetic-signal intervals, so every
  bootstrap interval in the package now uses one replicate count — those
  extractors take longer and return slightly different bounds without any
  change to their own arguments. **Calls that relied on the old default return
  slightly different interval bounds and take roughly five times longer.** Pass
  `n_boot = 200` to `bootstrap_Sigma()` to restore the previous behaviour; for
  exploratory work that remains a reasonable time-for-precision trade.

  Two distinct things bound this argument, and only the lower one is a
  correctness constraint. A percentile interval built from `B` draws is bounded
  by its widest possible realisation, whose coverage cannot exceed
  `(B - 1) / (B + 1)` whatever the data are — so below roughly `2 / (1 - conf)`
  the interval *cannot* reach the requested level. Above that threshold what
  remains is Monte Carlo error in the endpoints, which is a precision question.
  The old default of 200 already cleared the ceiling comfortably (0.990 at
  `conf = 0.95`), so this change buys endpoint precision for intervals that get
  reported — it does not fix a correctness bug. 999 rather than 1000 so that
  `(1 - conf) / 2 * (B + 1)` is a whole number at `conf = 0.95`, letting the
  bounds land on order statistics instead of being interpolated between them.

  `bootstrap_Sigma()` refuses an `n_boot` below the arithmetic floor, warns
  below the default, and returns `$coverage_ceiling` so a simulation campaign
  can assert `coverage_ceiling >= conf` on its own configuration before trusting
  its own numbers (IN: the guard and its tests; PARTIAL: non-Gaussian and
  mixed-family bootstrap calibration remain uncertified, CI-08/CI-10).

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
  `*_indep()` shape. **Admission is decided separately for each response family
  and each random-effect route**, so a combination that fits is not thereby
  validated: some routes are admitted with recovery evidence, others are
  permitted at fit time only. **This release does not publish a per-route
  coverage table, so the documentation will not tell you which of the two a
  given combination is.** Treat a successful fit as evidence that the model is
  *admissible*, not that its variance components or intervals have been
  validated. Where a route is known to be weak this changelog says so
  explicitly — see the random-slope limitation above.
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

* Standardized loading inference now uses the model-implied total variance,
  `rho[t,k] = Lambda[t,k] / sqrt(Sigma_total[t,t])`, rather than an entrywise
  loading-plus-scalar approximation. `loading_ci(method = "wald_asym")`,
  `suggest_lambda_constraint(method = "wald_retention")`, and
  `suggest_lambda_constraint(method = "varimax_threshold")` now account for
  every latent axis in the trait denominator; the Wald routes propagate the
  full joint fixed-parameter covariance, including fitted variance components
  and parameter-dependent link residuals. Loading CI, flagging, plotting,
  bootstrap, and `confint(..., parm = "Lambda")` outputs now label their
  `loading_scale`; raw symmetric Wald inference remains the default.

  Deterministic algebra and routing are covered, but standardized interval
  coverage is not yet calibrated. Wald retention treats the fitted varimax
  rotation as fixed, and standardized profile/bootstrap intervals are not
  currently available. Per-axis loading intervals therefore remain
  rotation-conditional sensitivity summaries rather than the primary
  rotation-invariant evidence.

* **Ordination no longer collapses when the response is on a large scale.**
  Starting values for the latent structure were built as though the response had
  a standard deviation of about 1 — a hardcoded loading start, a matching
  variance start, and latent scores beginning at exactly zero. Standardising the
  latent scores is precisely what pushes the response scale into the loadings, so
  where that assumption did not hold the fit could collapse: loadings, the
  covariance, the fixed effects, **and the correlations and communality that most
  users actually report** all came back wrong, with every convergence signal
  green. Nothing warned you.

  All three starts now follow the data. The loadings and the variance term are
  placed on the scale of the working residuals, and the latent scores are seeded
  from the data instead of from zero — scaled to unit variance, since the scores
  are standardised by definition and it is the starting *direction* that was
  missing, not the magnitude.

  For an ordinary single-tier `latent()` model on 4 traits, multiplying the
  response by 100 now reproduces every expected transformation to within about
  one part in 100,000. At a factor of 5000 it holds to about 1% in the worst of
  eight simulated datasets — looser, but well inside the 2% we accept, and the
  quantities most people report (the correlations and the communality) hold
  there too. Two other implementations of the same model do not hold that law on
  the same data: their worst cases are roughly 100% and 200% out, meaning a
  loading that should have doubled did not move. If you have worked around this
  by rescaling your response by hand, you no longer need to.

  This covers **Gaussian responses**, and the ordinary latent structure on your
  unit grouping — `latent()` and the variance term it carries. Everything else
  deliberately keeps its previous starting values: any model with a
  non-Gaussian response, the phylogenetic, spatial, kernel and random-slope
  latent terms, and the **second grouping of a nested two-tier fit** (the
  within-unit level, e.g. species-within-site). Starting values for the latent
  scores are also left alone when you give `latent()` a predictor with
  `lv = ~ ...`, because there the scores have a fitted mean rather than a free
  one.

  The reason for drawing the line there rather than wider: "multiply the
  response by 100" is only a meaningful thing to do to an unbounded continuous
  response, and that is the only case the collapse was measured on. A count or a
  presence/absence on an awkward scale may well have the same problem — but
  moving a starting value that has not been measured trades a known problem for
  an unmeasured one, which is the whole reason the old default was dangerous. If
  you fit any of the excluded forms on a response far from unit scale, rescaling
  it by hand is still worth doing.

  One case is **not** fully resolved. In a nested two-tier fit the residual scale
  error is around 2%, and that remainder is a property of the likelihood surface
  rather than of the starting values — a fit can report convergence while sitting
  some distance from the optimum, because a wide region of parameter space is
  nearly flat there. That is tracked separately and no starting value will
  address it.

* **`check_gllvmTMB()` no longer passes a binomial fit whose loading has run
  away.** The loading row could only fire when the trait's marginal prevalence
  was also extreme (at or beyond 0.9). But quasi-complete separation is a
  property of the fitted linear predictor, not of the marginal rate, so it runs
  a loading away while prevalence stays entirely ordinary — and the row was
  keyed on a quantity the pathology does not move. Across 3,944 simulated
  binomial fits the worst-affected trait's prevalence never left 0.20 to 0.807,
  and its distance from 0.5 was essentially uncorrelated with the size of the
  blow-up, while loadings reached 24,000 times the typical trait's. On one
  Bernoulli fit the row reported `PASS` with a loading 6,980 times typical and
  every fitted probability saturated, while the implied covariance was wrong by
  a factor of 156,645. A loading at or beyond `loading_runaway_thresh` (new
  argument, default 25) now reports on its own, naming the improper solution
  (Heywood case) and pointing at the loading penalty in
  `gllvmTMBcontrol(aghq_ridge = )`. The existing `loading_relative_thresh` of 8
  keeps its prevalence conjunct, because healthy fits with a sparse loading
  structure reach that level routinely — so nothing that was flagged before
  stops being flagged, including a genuinely near-constant trait, which the row
  still reports as it always did.

  A second, complementary criterion is added alongside it. A relative
  criterion cannot see a loading matrix that is inflated *as a whole*, because
  scaling every loading leaves every ratio unchanged — so
  `loading_absolute_thresh` (new argument, default 6) reports a loading that is
  simply too large on the link scale. That threshold is meaningful because the
  latent scores are standard normal by identification, making a binomial
  loading the trait's latent standard deviation in link units; a value of 6
  already implies a fitted probability indistinguishable from 0 or 1 across an
  ordinary swing of the axis. Measured over the same 3,944 fits: no healthy fit
  exceeded 3.99, none was flagged, and it reported 97.3% of degenerate fits —
  catching 14 that the relative criterion missed. Being a link-scale quantity
  it does not transport to families whose response scale is arbitrary, which is
  why this row remains binomial-only.

  Two limits on the calibration are stated plainly. It was measured on
  single-family binomial fits at the true latent rank, where it reports 96.3% of
  fits whose implied covariance is wrong by a factor of five or more, with no
  healthy fit reaching the threshold (the largest was 12.1). When the fitted
  rank is larger than the truth, several traits can inflate together, which
  lifts the very yardstick the ratio is measured against; in one such run the
  row missed 3 of 8 degenerate fits, and they were the three worst. A scale
  diagnostic, not a ratio, is the right instrument for that case and none is
  wired yet.

* **`check_gllvmTMB()` now reports a unique variance that has collapsed only
  relative to its siblings.** A Heywood case in a Gaussian or Poisson fit
  usually appears as a per-trait unique variance driven to the boundary, not as
  a runaway loading — and because `psi` is estimated on the log scale, the
  boundary is an interior point of the transformed space, so `pdHess` stays
  positive definite and nothing else objects. Across 360 fits with a
  deliberately over-specified latent rank, **58% drove a unique standard
  deviation below a tenth of its true value while reporting `convergence = 0`
  and `pdHess = TRUE`** — one reached 6e-50. The covariance itself was still
  recovered to within 7%, so this is a failure of the
  `Lambda Lambda' + Psi` decomposition rather than of the fitted covariance,
  and no recovery-based check can see it.

  `psi_rel_thresh` is raised from 0.001 to **0.01**, which reports 96.2% of
  those fits rather than 73.7%. The measured false-positive rate is **zero**
  both on 151 healthy fits and on 359 healthy fits whose true unique variances
  differ by up to a factor of 1000 — the case that decides whether the number
  transports, since a small ratio is then correct rather than pathological.
  Looser values do not transport: 0.1 reaches full sensitivity but flags 19% of
  those healthy fits. **Some fits that previously passed will now warn**; on
  this evidence they are fits with a genuinely boundary-pinned component.

* **The typical loading size is now taken over the traits being screened.**
  Previously it pooled every trait in the fit regardless of family, so in a
  mixed-family model a trait on a large response scale could set the yardstick
  for a binomial one — masking a genuine runaway, or manufacturing a spurious
  one when the other family's loadings were small.

* **Profile confidence intervals no longer lose their bounds at higher
  confidence levels.** The profile search used a fixed deviance budget that did
  not depend on `level`, and that budget was smaller than the threshold a
  profile must cross for any level above roughly 0.955. Above it the search
  could stop short and the bound was reported as infinite. On a four-trait
  Gaussian fit, `level = 0.99` returned an infinite bound for four of ten
  targets where `level = 0.95` returned all ten finite. The budget is now sized
  from the requested `level`, with headroom — merely reaching the threshold is
  not enough, because the bound is located by interpolating across it. The
  default `level = 0.95` also gains margin it did not previously have.
* **An unbounded interval is no longer reported where the bound is simply
  unknown.** A profile that stops without crossing its threshold can mean two
  different things, and only one was reported. If the profile has flattened out,
  no finite bound exists and an infinite bound is the honest answer. If the
  profile was still climbing when the search stopped, the bound is *unknown* —
  calling it infinite asserts an unbounded parameter on the strength of having
  stopped looking. The two are now distinguished from the shape of the profile
  itself, and the second returns `NA`.
* **Interval bounds are more accurate.** Bounds are now interpolated on the
  signed-square-root (`zeta`) scale rather than the deviance scale. For a
  quadratic log-likelihood `zeta` is exactly linear in the parameter, so the
  interpolation is exact there; on the deviance scale it carried curvature error
  that grew with the spacing of the profile grid. Reported bounds may shift
  slightly, and are closer to what a finer grid would give.
* **The internal coverage-study helper no longer counts an interval it could not
  compute as a success.** A missing bound was already treated as non-coverage,
  but an *infinite* bound fell through that guard, was scored as covering, and
  stayed in the denominator. A method returning an unbounded interval on every
  replicate would have reported perfect coverage. Missing and infinite bounds
  are now both excluded and reported as excluded. The helper is internal and
  unexported; the correction is recorded because any coverage figure produced
  with an earlier version of it is affected.
* Near-zero variance components are now detected **relative to their
  siblings**, not only against an absolute threshold. A boundary-pinned
  (Heywood) component — one trait's unique variance collapsing to zero — could
  previously pass every check the package had: `check_gllvmTMB()` reported
  `near_zero_psi_unit … PASS` and `fit_health$boundary_flags` stayed empty for a
  component whose variance was six orders of magnitude below the others. The
  absolute threshold is expressed on the standard-deviation scale, so the old
  `1e-4` demanded a variance below `1e-8` before flagging anything. `pdHess`
  could not catch it either: `psi` is estimated on the log scale, so a collapsed
  component is an interior point of the transformed parameter space and the
  Hessian stays positive definite there. `check_gllvmTMB()` gains
  `psi_rel_thresh` (default `0.001`) and reports the offending ratio in the
  check message; `.gllvmTMB_boundary_flags()` applies the same relative test to
  every variance block it already covered. Fits that were flagged before are
  still flagged.
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

* The `sigma_d2` argument to `loading_ci()`,
  `suggest_lambda_constraint()`, and `suggest_lambda_constraints()` is
  deprecated and ignored. Standardized loading denominators are now derived
  from each fitted model's total trait variance.

* `gllvmTMBcontrol(start_method = list(method = "res"))` is **soft-deprecated**
  and warns once per session. It still fits; prefer the default starts.

  It was retired on measurement. Across 89 simulated fits — Gaussian, Poisson
  and negative-binomial, `d = 1` to `3`, three and five traits — the residual
  start was **never materially better** than the default start (its three best
  margins were 0.07, 0.29 and 0.66 log-likelihood units, the scale of landing on
  a slightly different point of the same optimum), was **materially worse eight
  times**, once by 14.6 units, and was **exactly neutral at `d >= 2`**
  (objectives agreed to seven decimals in 34 of 34 fits). Every failure reported
  `convergence == 0` and a positive-definite Hessian on both sides, so the worse
  fit was silent, and restarts were not a guard: in one such fit all five
  `n_init = 5` restarts returned the same worse optimum.

  The damage concentrates at `d = 1` with three traits, the exactly identified
  corner where a per-trait variance can collapse to zero. Seeding from the
  residual covariance commits the optimiser to that matrix's leading direction,
  which there is not the best-likelihood factor. This is not a residual-noise
  problem — a start built from noise-free random-effect estimates lands in the
  same wrong place — so it is not fixable by a better residual.

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

* **Variance components: what is and is not claimed.** For all families,
  **point estimates** of variance components are the supported claim. No cell's
  interval coverage is certified; the available covariance routes have focused-test
  evidence only. Intervals are route output, not a coverage guarantee.
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
infrastructure. The 0.6.0 notes above describe the current taught syntax and
reader-facing scope.
