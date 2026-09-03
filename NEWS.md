# Development (unreleased)

* New `select_lv()` and an expanded `anova.gllvmTMB_multi()` for choosing and
  testing the latent rank (number of ordination axes, `d`) of an ordinary
  `latent()` term (issue #1242). `select_lv(formula, data, ..., d_max,
  criterion = c("bic", "aic", "aicc"))` fits `d = 1, ..., d_max` by sweeping
  the formula's single `latent(...)` term and reports a tidy table (`npar`,
  `logLik`, AIC/BIC/AICc, convergence, positive-definite-Hessian, seconds)
  with the criterion-minimising `d` marked; a fit that fails to converge or
  land on a positive-definite Hessian is excluded from selection (with a
  warning) but still shown. `anova.gllvmTMB_multi(object, ..., test =
  c("chibar", "chisq", "none"))` performs a sequential nested
  likelihood-ratio comparison: an ordinary fixed-effect (interior) step uses
  plain Wilks chi-square, and a rank step of exactly one new latent
  dimension uses the Self & Liang (1987) chi-bar-square mixture (new
  exported `chibar2_pvalue()`/`variance_lrt()`) as a documented
  approximation -- see `?anova.gllvmTMB_multi` for the exact caveat and
  `dev/gapclose/arcD/O5-report.md` for its measured empirical size. **In
  scope:** ML-only comparisons (REML, LA-MSPL, mismatched integration
  engines/loading ridges, mismatched data or families, and non-nested fixed
  effects are all refused, naming the reason); a single-dimension rank step
  gets the chi-bar-square correction; `select_lv()` guards `d_max` against
  the number of traits before fitting. **Not in scope:** no interval on the
  selected `d`; no automatic model averaging across `d`; a rank step
  spanning more than one new dimension, or a step that changes both fixed
  effects and rank at once, is refused rather than approximated (compare in
  separate steps, or use `select_lv()`); structured source-specific latent
  terms (`phylo_latent()`, `spatial_latent()`, `kernel_latent()`,
  `animal_latent()`) are not swept by `select_lv()`. `AIC.gllvmTMB_multi`
  and `BIC.gllvmTMB_multi` are now exported via roxygen `@export` (an
  idiomatic NAMESPACE `S3method()` entry) instead of the previous manual
  `registerS3method()` call in `.onLoad()`, which is removed as redundant.
* Three zero-inflated count families: `zi_poisson()`, `zi_nbinom2()`, and
  `zi_binomial()`. These are TRUE zero-inflation mixtures -- the ordinary
  count process is active at every observation, including `y = 0` -- and are
  distinct from the existing `delta_lognormal()`/`delta_gamma()` hurdle
  families, which have no second zero-generating process (see the family
  help and `vignette("current-limits", package = "gllvmTMB")` for the
  distinction). **In scope:** the count part carries everything the grammar
  allows (fixed effects, `latent()`, the full covariance grid, all three
  families' correlations reported on the count-process scale); `zi_nbinom2`
  reuses the ordinary per-trait `nbinom2()` dispersion convention; Laplace
  estimation only. **Not in scope:** no covariates or random effects on the
  structural-zero probability itself (`zi` is one logit-scale number per
  trait); `integration = "va"` and `estimator = "mspl"` both refuse zi_*
  families with a named reason; `aghq` DECLINES to a plain Laplace fit with
  a warning (it does not error) -- AGHQ's eligibility chain always declines
  rather than refuses, for every ineligible model, not only zi_*; no
  reported interval on `zi`; `zi_binomial()` refuses single-trial (0/1) response data (the mixture
  is not identified there) and names plain `binomial()` as the working
  alternative. `fitted()`/`predict(type = "response")` report
  `(1 - zi) * mu`; `simulate()` and `residuals(type = "randomized_quantile")`
  are wired for all three; `check_gllvmTMB()` flags a `zi` pinned near 0 or 1.
* Several refusals now name a route that actually fits, instead of pointing at
  keywords that refuse the same input. An augmented-LHS formula such as
  `indep(1 + x | trait)` or `phylo_indep(0 + trait + trait:x | species)` now
  redirects to the response-column slope grammar (`slope()`/`phylo_slope()`/
  `animal_slope()`) when grouped by the trait column, or to the group-axis
  form (`phylo_slope(x | group, tree = tree)`) otherwise -- previously both
  cases pointed at `*_indep`/`*_latent`/`*_dep`, which also refuse a slope
  LHS. A random-effect grouping column whose values are identical to the
  trait column now aborts explaining the fixed/random intercept collision,
  instead of fitting a silently meaningless model. `spatial_*()` keywords
  warn once when their `| token` grouping is not the canonical `coords`
  spelling, since that token is always ignored -- the field is driven only by
  `mesh =`/`coords =`. `gllvmTMB_diagnose()`'s runaway-loading advice now
  names `loading_ridge` (the integration-neutral spelling) instead of the
  AGHQ-specific `aghq_ridge`, and, only for fits where it actually applies --
  `latent(..., unique = FALSE)` models with at least 100 units and a latent
  rank of 2 or fewer -- mentions `integration = "va"` as a tuning-free
  alternative. A further batch of bare aborts across
  `R/gllvmTMB.R`, `R/parse-multi-formula.R`, `R/isdm-sources.R`,
  `R/family-cdf-args.R`, `R/fit-multi.R`, `R/methods-gllvmTMB.R` and
  `R/suggest-lambda-constraint.R` now say what to try next.
* Removed the accidentally-exported internal helpers `.proportions_wald_ci()`
  and `.proportions_bootstrap_ci()` (dot-prefixed, undocumented, no known
  external caller). The same numbers stay reachable through the public route:
  `confint(fit, parm = "proportion[:trait]", method = "wald")` or
  `method = "bootstrap"` returns the same per-(trait, component) variance-
  proportion intervals, and `extract_proportions()` returns the point
  estimates they are built from.
* `meta_known_V()` and `kernel_unique()` now warn, once per session, when
  called directly (via `lifecycle::deprecate_soft()`), naming their current
  replacements `meta_V()` and `kernel_indep()` /
  `kernel_latent(..., unique = TRUE)`. Both remain accepted compatibility
  syntax and keep fitting the same model; used inside a formula,
  `kernel_unique()` still separately warns the way it already did, which is
  unchanged by this.
* Corrected an internal evidence citation for the cross-lineage coevolution
  extractor (`extract_Gamma()`): it had pointed at an internal example
  article that was actually removed when the public article set was
  finalized at 0.5.0. The test-based evidence for this feature is unaffected
  and the feature itself has not changed; only the stale citation, and the
  internal tracking status it supported, are corrected.
* `gllvmTMB()`'s `unit` argument no longer defaults to `"site"`. For one
  release, omitting `unit` when `data` has a literal `"site"` column still
  works via a deprecated implicit fallback (a one-time warning); pass
  `unit = "site"` explicitly to silence it. When `data` has no `"site"`
  column, omitting `unit` now aborts naming the argument, instead of failing
  later with an opaque "column not found" error. The implicit fallback is
  removed in 0.8.0. `ridge_path()` and `suggest_lambda_constraint(s)()` carry
  the same change through their own `unit` defaults.
* Structured trait-intercept `phylo_*`, `animal_*`, `kernel_*` and `spatial_*` terms accept
  fixed `rho` between zero and one. This reduces covariance between source
  levels while preserving their marginal variances and the full trait
  covariance, including a latent term's Psi companion. Ordinary intercept
  effects remain separate. Omitted rho and explicit one retain the existing
  fitted model; coefficient-helper defaults are unchanged.
* `rho = NULL` estimates one source strength in the admitted native Gaussian
  design: complete replicated trait vectors, one known source with nonzero
  between-group relationships, retained observation residuals, and no competing
  ordinary covariance. Estimated latent terms initially require rank one and
  at least four traits. Optimizer success does not establish identification
  or accurate recovery; source-specific recovery evidence remains limited.
* Simulation, known-level prediction and `extract_Sigma()` account for the
  whole attenuated covariance. The extractor reports source strength separately
  from trait covariance. Source-allocation summaries and automatic refits that
  do not preserve attenuation give typed limitations. Source-strength intervals,
  augmented slopes and new ancestral predictions are not included. Spatial
  range remains separately estimated. In the frozen Gaussian spatial study,
  every estimated-rho cell was partial or blocked (14 partial, 2 blocked; no
  passing cell), so this release makes no spatial range–rho recovery claim.
  Attenuated spatial prediction requires known locations. See the new
  source-strength worked example for long and wide calls.

# gllvmTMB 0.7.1 (release candidate)

This candidate is a narrow trust-release closure. It adds no new response
family, likelihood, integration engine, random-slope capability, iSDM route,
or broad `predict(newdata = )` claim. No CRAN submission, tag, or public
release accompanies this candidate.

## Changed

* **Integrated-SDM point prediction now preserves fitted source-observation
  effects on prepared `newdata`.** The public `gllvmTMB(..., family =
  isdm_sources(...))` route reconstructs each source formula from its fitted
  terms, factor levels, contrasts, and retained columns. Prediction grids no
  longer need a dummy response column. Unknown sources, missing source
  covariates, unseen factor levels on rows where that source is active, and
  ambiguous encoded source-column names fail with typed errors; an all-missing
  declared source-by-trait arm is also
  refused before fitting. This is a point-prediction and safety repair, not a
  recovery promotion: held-out spatial accuracy and calibrated map intervals
  remain unverified, spatial slopes remain outside the admitted prediction
  tier, and users continue to supply their own prepared `newdata` grids.

* **Public response-column coefficient models.** `column_coef()` fits IID
  response-column random intercepts and slopes. `phylo_coef()` uses
  `K_rho = rho K + (1-rho) diag(K)` with fixed numeric `rho` or one estimated
  interior value; `animal_coef()` uses the same covariance-scale mixture from
  exactly one pedigree, relationship covariance `A`, or precision `Ainv`, with
  fixed numeric `rho`; `kernel_coef()` uses one labelled dense kernel with
  fixed numeric `rho` or one estimated interior value, retaining its supplied
  marginal scale; and `spatial_coef()` uses one labelled response-column mesh
  with fixed `rho = 1`, jointly estimating the projected-SPDE range and the
  coefficient-basis covariance. All five use the ordinary `gllvmTMB()` entry point with
  long or `traits(...)` wide data, and
  `extract_Sigma(level = "column_coef")` returns the ordered coefficient
  covariance, source, and `rho`. This is Gaussian point estimation only:
  intervals, non-Gaussian responses, and spatial IID mixtures remain
  unavailable. The
  existing `*_slope()` family remains current, warning-free, and
  non-deprecated. Exact compatibility is preserved at the no-intercept
  dense-`vcv`, `rho = 1` endpoint through the released `phylo_slope()`
  conditioning `K + 1e-8 I`; the matching no-intercept dense-`A` animal
  endpoint inherits `A + 1e-8 I` from `animal_slope()`. Other coefficient
  routes use the raw covariance-scale mixture. The no-intercept
  `kernel_coef(..., rho = 1)` endpoint is exactly the released
  `kernel_slope()` route and uses raw `K` without either ridge.
  The matching no-intercept `spatial_coef(..., rho = 1)` endpoint is exactly
  the released `spatial_slope()` projected-SPDE route. Intercept-bearing
  spatial fits add an all-ones coefficient-basis column without changing the
  spatial source normalization.

* **Predictor-informed latent axes now compose across registered native
  response families.** One complete-response ordinary unit-tier `latent(...,
  lv = ~ x)` block may combine registered family/link rows. The loadings-only
  `unique = FALSE` form admits ranks through the number of logical responses;
  the ordinary automatic `Psi` form additionally requires that its free
  loading and diagonal parameters do not exceed the available covariance
  moments. The existing cross-family correlation route
  is unchanged; the upgraded article now shows that same fit reporting both
  shared correlations and rotation-invariant `B_lv = Lambda alpha^T` effects.
  Gaussian and lognormal responses use separate within-family residual-scale
  slots when they coexist because one is on the raw scale and the other on
  `log(y)`. Live canaries cover every registered native family, but broad
  arbitrary-composition recovery and interval calibration remain partial.
  Missing responses or LV predictors, fixed `X + X_lv`, REML, extra covariance
  tiers, and structured-source `lv` remain unsupported.

* **Added an evaluated guide to predictor-informed latent ecological axes.**
  The guide teaches the ordinary native Gaussian route through the
  rotation-invariant trait-scale effect `B_lv = Lambda alpha^T`, alongside
  the decomposition of each latent score into its predictor-informed mean and
  innovation. Existing interval evidence remains limited to the named native
  Gaussian cells and rank-1 multi-trial binomial logit, probit, and cloglog
  cells. The Julia bridge remains a complete-response, loadings-only point
  route with optional uncalibrated Wald plumbing; broader families, masks,
  tiers, REML, profile, and bootstrap inference are outside this guide.

* **Explicitly unused optional grouping slots now warn (#1190).** Supplying
  `unit_obs` or `cluster` is useful only when a covariance keyword consumes
  that column. If no keyword does, `gllvmTMB()` now warns and tells the caller
  to omit the slot or use its column in the intended keyword. Omitted and
  explicit-`NULL` slots remain silent; the warning does not change the model,
  likelihood, or parameterisation.

* **`extract_Sigma_B()` and `extract_Sigma_W()` remain soft-deprecated
  compatibility wrappers (#1194).** They stay exported and retain their
  historical return names. Their help now gives the direct migration to
  `extract_Sigma(fit, level = "unit")` or `extract_Sigma(fit, level =
  "unit_obs")`; ordinary package summaries and residual helpers do not emit
  the wrapper warning.

* **Variational approximation remains an opt-in experimental route (#1189).**
  Native Laplace remains the default. This candidate makes no VA calibration,
  standard-error, confidence-interval, low-prevalence, or MSPL claim.

## Scope boundary

Existing random-slope documentation and existing MSPL material are retained.
They are not new 0.7.1 capability claims: MSPL remains opt-in experimental,
and this candidate neither expands nor promotes either topic.

# gllvmTMB 0.7.0 (development history retained for provenance)

* **Response-column slope helpers.** `slope()`, `phylo_slope()`,
  `animal_slope()`, `kernel_slope()`, and `spatial_slope()` support Gaussian
  long-format, predictor-only slopes when the RHS is the resolved response
  column. Wide-data syntax, non-Gaussian column slopes, and uncertainty
  intervals for the predictor covariance remain deferred.

* **`extract_Sigma_B()` / `extract_Sigma_W()` now warn on call (#1194).**
  The wrappers stay exported and still return the historical `Sigma_B` /
  `R_B` and `Sigma_W` / `R_W` names. Callers of the old spelling now see
  `lifecycle::deprecate_soft()` pointing at `extract_Sigma(fit, level =
  "unit")` / `level = "unit_obs"`. Runtime warning only; no unexport.

* **The augmented-LHS parser guard now honours a non-default `trait =`
  column (#1188).** `.assert_no_augmented_lhs()` decided whether a bare
  covstruct keyword (`latent`, `unique`, `indep`, `dep`, `scalar`,
  `spatial_dep`) was written in the supported per-trait-intercept form
  `0 + trait | g` by comparing the LHS symbol against the **string
  literal** `"trait"`, never consulting the resolved `trait =` argument.
  A user with `trait = "variable"` writing the CORRECT long-format spec
  `latent(0 + variable | unit, d = K)` was falsely rejected as an
  unsupported augmented LHS, and was left with no way to write per-trait
  intercepts in long format under their own column name. The guard now
  accepts either the resolved trait column name or the literal
  `"trait"`, and its abort message names the user's own trait column.
  ⚠️ This blocked an external user from writing a correct model and led
  to a wrong published analysis (the fallback spec collapsed 29 per-item
  intercepts to one shared intercept). On the reporter's direct refit,
  the d = 2 LV1-loading/prevalence association fell from R² = 0.742 with
  the shared-intercept specification to R² = 0.125 with per-item
  intercepts. Thanks to @iwogross for the report.

* **`gllvmTMB()`'s `unit_obs` and `cluster` arguments now default to
  `NULL` instead of the concrete strings `"site_species"` / `"species"`.**
  Both slots are optional -- most callers have no reason to supply them --
  but a default that reads as a required column name invites callers to
  manufacture columns just to satisfy the signature. An external systematic
  map user (paper x item design, no sites, no species) wrote
  `site_species = paste(study_ID, variable, sep = "_")` purely because
  `unit_obs` defaulted to `"site_species"`, and set `cluster = "variable"`;
  neither column had any meaning in the design or any effect on the fit.
  ⚠️ **API/signature change; fitting behaviour preserved.** The visible
  defaults are now `NULL`, while omitted and explicit-`NULL` calls still
  resolve internally to `"site_species"` / `"species"`. Existing calls
  that relied on or explicitly supplied those historical names fit
  bit-identically. Also fixed: the "Column %s not found in data" error,
   which never said which argument wanted the column, now names the argument
   (`trait`, `unit`, or `unit_obs`) and the value that was looked for.

* **`mesh=` with no spatial term is no longer silently ignored (#1165).**
  Mesh validation used to run only when a `spatial_*()` term was present,
  so `gllvmTMB(mesh = <raw fmesher mesh>)` with an ordinary non-spatial
  formula fitted identically to the no-mesh call -- a clean converged
  fit, and no signal that the spatial mechanism never ran. ⚠️
  **Behaviour change:** a supplied mesh and no spatial term now warns,
  naming both possible mistakes (the formula is missing a
  `spatial_*()` term, or `mesh` was left over from a term that was
  removed). A raw fmesher/INLA mesh is then rejected with the existing
  `make_mesh()` error -- the check that already ran when a spatial term
  *was* present. A valid `make_mesh()` object still fits as a
  non-spatial model after the warning. Fits with a spatial term, and
  fits with `mesh = NULL`, are unchanged.

* **`predict(newdata = )` now also re-adds ordinary `(1 | group)` random
  intercepts (#1138).** This corrects an earlier entry, which recorded the
  `re_int` tier as unreachable because "its group mapping is not a top-level
  field on the fit". **That was wrong** -- `fit$re_int` carries `groups`,
  `n_groups` and `offsets`, which is exactly what is needed. The tier is now
  reconstructed and held to the same acceptance test as the others:
  `predict(newdata = training rows)` reproduces `report$eta` exactly,
  including with **several** `(1 | g)` terms, which is the case that
  exercises the end-to-end packing via `re_int_offsets` -- an off-by-one
  there would give a plausible value for the first term and a silently wrong
  one for the second. An unseen level in a grouping factor still aborts, as
  it did before: for an arbitrary grouping factor there is no defined
  fixed-effects fallback, so refusing beats guessing.

* **`predict(newdata = )` no longer requires the response column (#1154).**
  A prediction grid has no response by construction -- that is the point of
  predicting on one -- but the newdata path built its design matrix with
  `model.matrix()` on the two-sided model formula, which constructs a
  `model.frame()` first and so evaluates the left-hand side. Predicting on a
  grid failed with `object '<response>' not found`, and the workaround (add
  a dummy column) was undiscoverable from the error and left the reader
  wondering whether the placeholder affected the prediction. The design is
  now built from the right-hand side only. Predictions are unchanged where
  the column was present.

* **`predict()` and `fitted()` now return the family/source column on
  mixed-family fits, and the effort-free scale is documented (#1133).** On an
  `isdm_sources()` fit the `est` column mixes scales by design -- Poisson
  expected counts beside cloglog detection probabilities -- and the in-sample
  path returned no column saying which row was which. The `newdata` path
  always did (it returns all of `newdata`), so the **default** call, and
  `fitted()` which wraps it, were the ones missing the label. The fit's
  `family_var` column is now carried through; `est` remains the last column
  and its values are unchanged. **Fits with no `family_var` column --
  every single-family fit -- return exactly what they always did.**
  Separately, `?predict.gllvmTMB_multi` now documents that `type =
  "response"` includes the row's offset (so it is an expected count *at that
  effort*), and that the effort-free / relative-intensity scale is obtained
  by zeroing the offset variable in `newdata` -- exact, because the offset is
  re-evaluated against `newdata`, which is why no new `type =` is needed.


* **`vignette("response-families")` gains seven compact worked examples,
  one per family-specific dispersion trap (#1082).** Gamma (`phi_gamma` is
  a shape, not a dispersion), student (`sigma_student` is a scale, not the
  response SD), Beta (`phi_beta` is a precision; boundary 0/1 values are
  not Beta data), multi-trial binomial (`cbind()` vs `weights = n_trials`,
  and a now-fixed `simulate()` gotcha for pre-2026-08-17 saved draws),
  `ordinal_probit()` (cutpoints depend on which categories are actually
  observed, per trait), the truncated count families (`phi_truncnb2` is
  its own vector, separate from `phi_nbinom2`), and `delta_gamma()`
  (`phi_gamma_delta` is a CV, the inverse-square of its near-identical
  neighbor `phi_gamma`) each get a minimal runnable fit and the documented
  route to reading its dispersion. The `residuals(type =
  "randomized_quantile")` diagnostics comment is also corrected: exact
  residuals cover 13 families now, not the 4 it previously named. These
  are worked examples of point estimation and fitted diagnostics, not an
  evidence-tier promotion.
* **`predict(newdata = )` now re-adds three more random-effect tiers, and
  `propto` is no longer skipped for every row when the first row has an
  unseen species (#1138, #1132).** `diag_species`, `rr_W` and `diag_W` are
  reconstructed on the `newdata` path, each pinned by the same acceptance
  test the SPDE tier had to meet: `predict(newdata = training rows)` must
  reproduce `report$eta` **exactly**. That standard matters here because
  `q_sp` is indexed `(trait, species)` -- the transpose of `p_phy` -- so a
  swapped index would still yield a plausible non-zero contribution.
  The `rr_W`/`diag_W` pair is keyed on the unit-observation column and is
  added only when `newdata` carries it; otherwise the existing warning names
  them as omitted. Also fixed: the `propto` re-add was gated on
  `!is.na(sp_id[1])` -- row *one* only -- so a single unseen species in the
  first row silently dropped the tier for the whole frame; each row is now
  guarded on its own.
  Still deliberately not re-added, and still warned about: `equalto` (indexed
  by observation, so it has no meaning for new rows), and `diag_cluster2` /
  the `*_slope` and phylo-diagonal blocks, whose reshape conventions are not
  established (see `getREsd()`).

* **Boundary screening now sees two spatial/kernel Psi companions it
  previously missed, and `check_gllvmTMB()`'s spatial psi row no longer
  returns zero rows (#1119).** ⚠️ **Behaviour change:** fits that previously
  passed clean may now emit new boundary flags / WARN rows. Two real,
  non-trivial quantities were absent from `.gllvmTMB_boundary_flags()`'s
  screening list entirely: `sd_spde_unique` (the spatial `*_unique()` Psi
  companion) and `sd_kernel_diag` (its multi-kernel analogue) -- a
  collapsed spatial or kernel Psi went unflagged. Both are now screened;
  `sd_kernel_diag` is filtered to only the tiers that actually carry a
  fitted diag, since the current multi-kernel grammar cannot request one
  yet (it is otherwise always an all-zero placeholder that would false-fire
  on every 2+-named-kernel fit). Separately, `check_gllvmTMB()`'s own
  `spatial` psi row used the dead literal `"sd_spde"` -- no such name is
  ever REPORTed (the real name is `sd_spde_unique`) -- so it silently
  produced zero rows (no PASS, no WARN) for every spatial fixture; it now
  reports correctly. The dead literals `"sd_phy"` / `"sd_spde"` are also
  removed from `.gllvmTMB_boundary_flags()`'s own list (they never matched
  a REPORTed name there either; `sd_phy_diag` and `sd_spde_b` were already
  screened under their real names).

* **Unnamed mixed-family `family = list(...)` lists no longer silently
  swap which family fits which trait (#1120).** `.align_mixed_family_list()`
  left an unnamed family list unchanged, while the selector column's levels
  for a character column were built via `sort(unique(...))` -- alphabetical,
  not the user's list order. A fit such as `family = list(student(),
  gaussian())` against a plain character `family` column
  `rep(c("student", "gaussian"), each = n)` silently fit the student data as
  Gaussian and the Gaussian data as Student-t: zero warnings, a converged
  fit, every downstream quantity wrong. This belongs to a recurring class in
  this package -- **the code chose a fallback and then reported success** --
  alongside `fitted()`'s and `deviance()`'s silent `NULL` (#1114, #1118);
  the reassuring-message variants (a converged fit, a clean summary) are the
  dangerous form, because nothing about the output signals that a guess was
  made.
  **This is a behaviour change, but not a blanket one**: an unnamed list is
  now validated by computing BOTH the order the list was written in and the
  order implied by each family object's own name (e.g. a `"student"` level
  naturally means `student()`). When they agree, nothing was ever
  ambiguous and the fit proceeds exactly as before -- most existing code,
  including every other mixed-family test in this package's own suite,
  already writes list order to match level order and is unaffected. When
  they disagree, that disagreement IS the #1120 defect firing, and the fit
  now errors (class `gllvmTMB_mixed_family_unnamed_ambiguous`) showing both
  readings explicitly and telling the user to name the list
  (`list(student = student(), gaussian = gaussian())`) or supply an
  explicit factor. Selector columns with no name evidence at all (e.g.
  arbitrary labels like `"count"`/`"binary"`) still use list order, but the
  resolved pairing is now reported once so it is auditable rather than
  assumed. A level whose text matches more than one family object's name,
  or a list where some levels have name evidence and others don't, is
  refused as ambiguous rather than partially guessed. The same defect
  pattern existed a second time, independently, in the multinomial
  mixed-family trait-identification path (`expand_multinomial_response()`,
  `R/gllvmTMB.R`, reachable before `.align_mixed_family_list()` runs) and is
  fixed the same way.
* **`predict(newdata = )` no longer silently drops the spatial field,
  ignores `re_form`, or applies the wrong arm's inverse link (#1132).**
  Three defects in one function, all measured in Design 126 §3:
  - The `newdata` branch re-added only the `rr_B`, `diag_B` and `propto`
    tiers out of ~37, so a **spatial fit's SPDE field was absent from every
    `newdata` prediction -- at training locations too** -- while the branch
    reported that random effects had been added. Measured on a converged
    spatial fit: dropped-piece sd 0.381 against a linear-predictor sd of
    0.949, and reproduced independently on a plain `gaussian()` spatial fit
    (sd 0.516 vs 0.786). The SPDE contribution is now re-added by rebuilding
    the mesh projection with `fmesher::fm_basis()`, and any remaining active
    tier this path cannot reconstruct now raises a warning **naming it**
    rather than vanishing. `newdata = NULL` was always correct and is
    unchanged.
  - `re_form` was read only on the `newdata` path, and there only as the
    literal `~ 0`. On the package's default calling convention
    `predict(fit, re_form = ~ 0)` therefore returned the full conditional
    predictor, contradicting the documentation; `NA` -- a documented form --
    and numeric `0` were ignored on both paths. All three forms are now
    honoured on both paths, and an unrecognised value warns instead of
    silently including the random effects. **This changes the numbers
    returned by existing `re_form = ~ 0` calls**, including
    `fitted(object, re_form = ~ 0)`, which forwards to the same path.
  - `type = "response"` on `newdata` reduced the per-row family/link ids to
    a per-trait *modal* id, which cannot represent an `isdm_sources()` fit
    (the family varies by source *within* trait). Detection-arm rows were
    returned through the count arm's inverse link, giving "probabilities" in
    [0.253, 2.32] -- above 1, silently. The ids are now recovered per row
    from the fit's `family_var` column, keeping each `(family, link)` pair
    together. Single-family and by-trait fits are unaffected.
  - Also fixed in the same block: with an active `lv_B` score mean, the
    `rr_B` re-add used the `z_B` innovation alone and dropped the
    predictor-informed mean `X_lv_B alpha_lv_B`; it now uses the reported
    `U_B_total`.

* **BEHAVIOUR CHANGE: `gllvmTMB_conditional_residual_saturated` now also
  warns for Gamma, Beta, and student-t fits (#1083).** A diagonal random
  effect indexed at the observed (unit x trait) resolution
  (`latent(0 + trait | unit, d = 1)` with the default `unique = TRUE`)
  perfectly interpolates every observation, driving the family's
  dispersion/scale parameter toward a degenerate confound: `sigma_eps -> 0`
  for gaussian/lognormal, Gamma's shape -> Inf, Beta's precision -> Inf,
  student's `sigma -> 0`. `residuals(fit, type = "randomized_quantile")`
  already warned about this for gaussian and (as of the previous entry
  below) lognormal fits, but Gamma/Beta/student fits with the identical
  structure were silent. A 15-seed sweep found Gamma's `phi_gamma` running
  away past `1e6` (true 6) in 9/15 seeds and student's `sigma_student`
  collapsing below 0.1 (true 0.4) in 6/15 seeds under this structure;
  Poisson, swept the same way, showed no such collapse (it has no
  continuous dispersion parameter to degenerate, so it is deliberately
  **not** included, along with binomial, NB1/NB2, tweedie, and
  beta-binomial -- all discrete-pmf families bounded by probability 1
  rather than continuous densities that can diverge to infinity). Models
  that previously fit silently under this structure will now warn; the fit
  itself is unchanged, only the residuals-time diagnostic.
* **`gllvmTMB_conditional_residual_saturated` now also warns for lognormal
  fits (#1083).** The warning was gated to `family_id == 0L` (gaussian)
  even though gaussian and lognormal share one literal `sigma_eps` and are
  auto-suppressed identically at fit time
  (`any_sigma_eps <- any(family_id_vec %in% c(0L, 3L))`,
  `R/fit-multi.R:5177`) under a per-row diagonal random effect. The gate
  now matches that fit-time decision.
* **`deviance()` no longer returns a silent `NULL` on a `gllvmTMB_multi`
  fit (#1118).** With no method registered, `deviance()` fell through to
  `stats:::deviance.default`, which reaches for `object$deviance` and
  returns `NULL` without error -- the same shape as the `fitted()` defect
  fixed in #1114. `deviance.gllvmTMB_multi()` now returns
  `-2 * logLik(object)`, delegating through `logLik()` so it inherits that
  method's existing MAP-point disclosure warning on ridged
  (`aghq_ridge`-penalised) fits rather than re-deriving it.
* **Mixed-family fits with a dispersion family now have a valid Hessian and
  SEs (#1117).** Per-trait dispersion/shape parameter vectors
  (`log_phi_nbinom2`, `log_phi_nbinom1`, `log_phi_gamma`,
  `log_phi_tweedie` + `logit_p_tweedie`, `log_phi_beta`,
  `log_phi_betabinom`, `log_sigma_student` + `log_df_student`,
  `log_phi_truncnb2`, `log_sigma_lognormal_delta`, `log_phi_gamma_delta`)
  were previously gated WHOLE-VECTOR: mapped off only when the family was
  absent from every trait. In a mixed-family fit where the family was
  present on some traits but not others, the other traits' entries were
  free parameters the likelihood never reads — a mechanically singular
  Hessian (`pdHess = FALSE`), no valid `sdreport`/Wald/profile intervals,
  and phantom entries enumerated by `profile_targets()`/`confint()`. Each
  vector is now pinned per trait to the traits that actually use its
  family. Single-family fits are unaffected (byte-identical).

* **Convergence diagnostics on ridged fits now judge the objective the fit
  actually optimised (#1092).** `aghq_ridge` applies a loading penalty in R,
  outside the TMB objective, so `fit_health$max_gradient` previously reported
  the gradient of the *unpenalised* likelihood at the penalised optimum — a
  number that equals the missing ridge term (`|Lambda|/tau^2`) rather than
  ~0, making perfectly converged ridged fits read as unconverged. The
  reported gradient, `stationary_by_gradient`, `converged`, `sanity_multi()`
  and the AGHQ stop reason now evaluate the penalised objective; the new
  `fit_health$gradient_is_penalised` field discloses when this applies, and
  the raw likelihood gradient remains available via `fit$tmb_obj$gr()`.
  Unridged fits are unchanged. Relatedly, the ridge's reach is now pinned to
  the ordinary loading block `theta_rr_B` **only**: an accidental merge had
  briefly made it also penalise spatial latent loadings
  (`theta_rr_spde_lv`), contradicting the documented exemption for spatial
  terms — a regression test now proves spatial loadings carry no silent
  penalty.

* **Multinomial fits now warn at fit time when their contrast structure is
  degenerate.** The screen added this release (collapsed contrast variance,
  rail-correlated contrasts, or a collapsed spatial range) is now surfaced
  automatically, under the existing `gllvmTMBcontrol(warn_runaway = )`
  switch and with its own once-per-session slot, so it cannot suppress or be
  suppressed by the binomial runaway warning. Set `warn_runaway = FALSE` to
  silence both; `check_gllvmTMB()` and `gllvmTMB_diagnose()` are unaffected.
  Ordinal fits deliberately emit no such warning — that family's arms ship
  disarmed (see the calibration note below), so the row reports statistics
  without a verdict.

This development release adds an opt-in separation-screening and LA-MSPL lane
for complete single-trial Bernoulli GLLVMs. Ordinary ML remains unchanged and
is still the default.

## Changed

* **`check_gllvmTMB()`'s `loading_absolute_thresh` default raised from 6 to
  8 (issue #1098).** Some binomial fits that previously reported `WARN` on
  the `binomial_prevalence_loading` row now report `PASS`; nothing that
  reported `PASS` before starts reporting `WARN`. The earlier default was
  calibrated on a pool whose true loading scale never reached the regime
  where this arm misfires. A pool built to cross `sigma_lambda in c(0.7,
  3.0)` (928 healthy / 272 degenerate binomial-probit fits) — `3.0` chosen
  to hit issue #847's `aghq_ridge` ridge-failure regime, not argued for
  realism — measured a 25% false-positive rate at the old threshold, all
  of it attributable to this one arm; raising the threshold to 8 lowers
  that rate to 15.52% while sensitivity on the same pool's degenerate fits
  falls only from 100.00% to 99.63% (one additional missed fit out of
  272). This is an improvement, not a fix: the arm remains measurably
  regime-dependent — false-positive rate 3.85% at a mild true loading
  scale versus 49.08% at the scale `aghq_ridge = 2` is already known to
  struggle at (issue #847) — so a fixed constant cannot be correct across
  every loading scale a fit may have. This is effect-size dependence, not
  the response-scale dependence #851/#855 otherwise describes: probit
  fixes the residual variance at 1, so there is no free response scale
  here to rescale against, and the class's usual per-fit device does not
  obviously transfer (see `dev/heywood/fp-scale-dependence.md`).
  `aghq_ridge = 2` reduces the problem (46.0% -> 13.5% false positives at
  that larger scale) but does not remove it.

## New

* **`screen_gllvmTMB()` now catches exact response-side dependencies
  among three or more traits (issue Ayumi-495 /
  `urbanisation_map#23`).** The pairwise duplicate/complement check only
  sees two-way exact relations; a `response_affine_rank` row (in `$design`)
  and a new `$response_dependencies` table now also flag one-hot/simplex
  blocks, most commonly a review-type, geographic-scope, or
  temporal-scope variable recorded as several dummy columns that sum to
  exactly 1 on every row, via an affine-rank check on the augmented
  response matrix. Certificates are recovered on a best-effort basis (not
  exhaustive minimal-subset discovery); the new `known_groups` argument
  lets you declare a set of trait names as a one-hot block or a
  nesting/containment chain for an exact, deterministic check instead.
  See the new "Exact response-side dependencies" section of
  `vignette("pre-fit-response-screening", package = "gllvmTMB")`.

* **New `ridge_path()`: a loading-ridge sensitivity sweep (issue
  Ayumi-495 / `urbanisation_map#23`).** Refits a model across a grid of
  `gllvmTMBcontrol(loading_ridge = tau)` scales and reports, per trait,
  how the largest loading and its communality move as the penalty
  weakens. `print()` classifies each trait as "interior (stabilises as
  penalty weakens)" or "penalty-determined (moves toward boundary)" using
  a documented slope rule on the last two finite-`tau` grid points. This
  is sensitivity evidence, not an identification certificate; `tau = Inf`
  (plain ML) can legitimately fail to converge for a pathological trait,
  and that failure is itself part of the diagnostic.

* **`fitted()` now works on the default `gllvmTMB_multi` fit (#25).**
  `fitted` was only registered as an S3 method for the `gllvmTMB_julia` and
  `gllvmTMB_va` engine classes, so `fitted(fit)` on an ordinary fit silently
  returned `NULL` rather than erroring or dispatching. `fitted.gllvmTMB_multi()`
  is a thin wrapper over `predict(object, newdata = NULL, type = )`, returning
  the same long data frame (default `type = "response"`, matching the
  `fitted()` convention; `predict()`'s own default remains `"link"`).

* **Exact randomized-quantile residuals now cover nine more families.**
  `residuals(fit, type = "randomized_quantile")` and
  `predictive_check(fit, type = "rq_qq")` compute exact family-CDF
  residuals for binomial (logit/probit/cloglog), lognormal, Gamma, Beta,
  betabinomial, Student-t, zero-truncated Poisson, zero-truncated NB2, and
  ordinal-probit rows, in addition to the existing Gaussian, Poisson, NB1,
  and NB2 support. Rows for tweedie, the delta/hurdle families
  (`delta_lognormal`, `delta_gamma`), and multinomial remain
  `status = "unsupported_family"`: tweedie has no closed-form CDF without a
  new dependency, the delta/hurdle families need a design decision for
  splitting the point mass at zero, and multinomial's categories are
  unordered so a randomized-quantile residual is undefined for it. See
  `?residuals.gllvmTMB_multi` for the full scope statement.

* **A `check_gllvmTMB()` row for multinomial K-1 contrast degeneracy.**
  `multinomial()` (fid 16) fits as K-1 baseline-category contrast
  pseudo-traits per response; `check_gllvmTMB()` now reports a
  `multinomial_contrast_degeneracy` row that screens those contrasts
  against each other for three failure modes generic loading diagnostics
  cannot see: one contrast's loading energy collapsing to ~0 (absolutely,
  or relative to its sibling contrasts), two contrasts of the same
  response loading almost perfectly on the same axis (evaluated only where
  the tier's rank is 2 or more, since rank-1 tiers reach that correlation
  on every healthy fit by construction), and a spatial field's practical
  range collapsing relative to the coordinate domain. This is a check-row
  addition only -- **no fit-time warning**, no new export, no behaviour
  change to any existing fit.

  Three screens ship armed at calibrated defaults: `multinomial_collapse_floor
  = 1e-10` (contrast variance collapse), `multinomial_rail_thresh =
  0.99` (two contrasts railed onto one axis), and
  `multinomial_range_collapse_thresh = 0.02` (spatial range collapse).
  `multinomial_collapse_rel_thresh` stays disarmed (`Inf`) -- untested.
  Measured against pre-registered labels (128 fits, 122 converged with a PD
  Hessian): the variance-collapse screen detected 6/7 labeled collapses
  **plus 7/7 on a later, entirely out-of-sample cell**; the contrast-rail
  screen detected 8/8 labeled rails, **plus four individually
  railed fits hidden inside a cell whose aggregate gate had passed**
  (refitting confirms |rho| = 1.00000, against controls at 0.49 and
  -0.15); the spatial-range screen detected 3/3. Zero false positives on 40 informative healthy fits, and
  the denominator is stated honestly: fits with no loading tier emit no row
  at all and cannot evidence specificity, so the rule-of-three bound is
  **about 7.5%, not a verified zero**. The contrast-rail screen is deliberately silent on rank-1
  tiers, where |rho| = 1 holds on every healthy fit by construction
  (verified 0/20 out-of-sample).

  The spatial-range screen was fixed before arming: it originally read the low-rank loading
  matrix `Lambda_spde`, which the engine reports only for
  `spatial_latent()`/`spatial_dep()` fits, so on `spatial_indep()` fits --
  exactly the ones it was built for -- it produced no row at all. It now
  branches on the engine route, taking the range from `log_tau_spde` on
  the diagonal route: rows emitted 0/20 to 20/20, detection 0/3 to 3/3,
  with 0/11 false positives on the same cell's healthy fits.

* **A `check_gllvmTMB()` row for ordinal-probit loading degeneracy** (fixes
  the coverage gap reported in #897, where a degenerate `ordinal_probit()`
  fit had no detector at all -- 239/239 unflagged where the binomial screen
  caught 272/272). A mechanism probe found no empirical support for
  cutpoint-underflow saturation across 24 measured degenerate fits
  (flat-row share exactly 0 throughout) -- that negative finding stands.
  The probe's third measurement, originally read as positive evidence for
  category-level quasi-complete separation (the same mechanism the
  binomial row already screens for), was later shown, on a larger 315-fit
  calibration, to fire on 86.3% of healthy fits and so does not
  discriminate; category-level separation remains the residual hypothesis,
  not a demonstrated one. The pathology's shape is a single trait's
  loading column running away while sibling traits stay near truth.
  `check_gllvmTMB()` now reports an
  `ordinal_liability_loading` row with two arms modeled directly on the
  binomial row: a trait's largest loading relative to the typical loading
  among the other ordinal traits, and the largest loading on the link
  (liability) scale, unit tiers only -- scale-free because the
  probit-liability residual variance is exactly 1 by the Wright/
  Falconer/Hadfield threshold convention. This is a check-row addition
  only -- **no fit-time warning**, no new export, no behaviour change to
  any existing fit.

  Both arms ship **DISARMED at `Inf`/`Inf`** -- the row still computes and
  reports its statistics, but neither threshold is armed by default.
  Calibration ran 315 fits across four pre-registered design arms, scored
  under the frozen pre-registration (sensitivity on the `degenerate` arm's
  `rel_frob > 10` fits; false positives measured across `healthy` +
  `transport` + `mixed` combined), and found **no threshold that clears
  the pre-registered target of 90% sensitivity with zero false alarms --
  and none can**: the healthy pool reaches a loading magnitude of 216.9
  while the degenerate arm starts at 13.5, so the classes are not
  separable on this statistic at all. At binomial's own threshold of 6,
  the absolute arm reaches 100% sensitivity but **39.2%** false positives
  and the relative arm 61.0% sensitivity at 28.6% false positives --
  *worse* than the 25% false-positive rate #897 reports for binomial
  itself, so borrowing binomial's threshold would have shipped a bigger
  problem than the one the issue complains about. The false alarms
  concentrate in designs mixing very different per-trait loading scales:
  an absolute liability-scale threshold cannot transport across
  heterogeneous trait scales, so a future screen needs a scale-invariant
  statistic rather than a better constant. Honest limits: no evidence at
  `n = 1600` (that arm was dropped for run time). What the campaign
  establishes: link saturation is refuted as the mechanism (solid);
  category-level separation, the residual hypothesis, is NOT demonstrated
  -- the evidence originally cited for it does not discriminate (see the
  correction recorded in `dev/ordinal-degeneracy/probe-criteria.md`); and
  the threshold question is answered negatively with a stated path forward.

  Neither categorical screen changes what fitting itself does: `gllvmTMB()`
  warns exactly as before, and both rows appear only when you call
  `check_gllvmTMB()` on the fit.

* **Liability-scale phylogenetic heritability for categorical families**
  (this corrects a real defect: on a phylogeny-only `ordinal_probit()` or
  `multinomial()` fit, `extract_phylo_signal()` previously reported
  **`H2 = 1.0` for every trait and every contrast**. That number was the
  species-level-latent proportion and was arithmetically correct as such,
  but as a heritability it was silent nonsense -- the fixed liability
  residual never entered the denominator, so a phylogenetic signal that
  should read around 0.3-0.4 read as 1. If you have reported a categorical
  `H2` from this function, re-run it with `link_residual = "auto"`.)
  `extract_phylo_signal()` gains a `link_residual` argument. The default
  (`"none"`) keeps the historical species-level-latent denominator
  unchanged, so no existing non-categorical result moves;
  `link_residual = "auto"` adds each trait's fixed
  distribution-specific latent residual to the denominator, returning the
  conventional liability-scale phylogenetic heritability of Mizuno et al.
  (2025, *J. Evol. Biol.* 38:1699-1715, eq 4/18/19):
  `ordinal_probit()` reports per-trait `H2 = V_a / (V_a + 1)` and
  `multinomial()` reports per-*contrast*
  `H2 = V_a(k) / (V_a(k) + pi^2/3)`. Multinomial contrast heritabilities
  are baseline-referenced (the softmax link residual couples contrasts
  through the shared baseline category) and are reported one row per
  contrast, never collapsed to a scalar. An advisory now fires when a
  categorical fit is summarised with the default denominator, and
  `ci = TRUE` with `link_residual = "auto"` refuses with a typed error
  rather than returning uncalibrated intervals. Verified against an
  MCMCglmm `family = "ordinal"` comparator on a shared phylogenetic
  fixture.

* **A Species Distribution Models article collection.** The pkgdown site
  gains a dedicated navbar menu ordering the SDM material as a curriculum —
  the joint species distribution model guide, a new presence-only opener,
  and the three integrated-source articles. The new article, *Joint
  ecological intensity from opportunistic records*
  (`vignettes/articles/gbif-joint-intensity.Rmd`), fits a joint
  relative-intensity model to GBIF-style records alone through the ordinary
  `gllvmTMB()` call (Poisson counts, an effort offset, a named recording-bias
  covariate, and one `latent()` factor). It estimates relative ecological
  intensity only — no abundance, absolute occurrence, or detectability
  claim — and states the design assumption its bias term rests on.

* **A fifth SDM article: repeated survey visits.** *What do repeated survey
  visits add to an integrated model?*
  (`vignettes/articles/integrated-repeated-visits.Rmd`) shows visit-varying
  conditions entering the survey branch on the complementary-log-log scale,
  demonstrates that within-cell replication under varying conditions is what
  separates a poor visit from low intensity, and states the boundary with
  separate-detection occupancy models. The two-source article is renamed
  *Integrating opportunistic records with a designed survey* to keep the two
  subjects distinct.

* **A sixth SDM article: rare species and separation.** *When a rare
  species breaks the JSDM* (`vignettes/articles/rare-species-jsdm.Rmd`) is
  the species-facing door to the separation workflow: a heat specialist
  recorded only at the warmest sites, the `screen_gllvmTMB()` certificate,
  what ordinary ML does at that boundary, the finite opt-in experimental
  MSPL point with its fences, and a live demonstration that the loading
  ridge does not repair separation.

* **A four-lens editorial audit of the SDM collection.** Every article under
  the Species Distribution Models menu was audited for readability, claim
  discipline, statistical correctness, and figure integrity. Fixes include:
  the two-source and design articles' displayed equations now carry the
  per-species reporting level `rho_s` their code always fitted; the stale
  "more than two sources: not available" claims are corrected to point at
  `isdm_sources()`; health-check outcomes are stated after every
  `check_gllvmTMB()` chunk; `pd_hessian` and Fisher-z are glossed at first
  use; and figures gain alt text, equal-axis identity lines, and
  non-overlapping labels.

* **The LA-MSPL worked example is rewritten around its two failure modes.**
  *Rare items and runaway estimates in Paper × Items evidence synthesis*
  (`vignettes/articles/mspl-binary-jsdm.Rmd`, same URL) now grounds the
  example in an evidence-map-shaped corpus and demonstrates, on one dataset,
  that runaway loadings and fixed-design separation are different diseases
  with different matched remedies — the opt-in loading ridge for the first,
  opt-in MSPL for the second — including the negative result that the ridge
  does not repair separation. Claim boundaries (probit vs logit ridge
  regimes, AGHQ's large-n evidence, MSPL's refused inference surface) are
  stated in the article.

* **Complete-Bernoulli GLLVMs can opt in to LA-MSPL point estimation.** Set
  `estimator = "mspl"` to fit the experimental maximum softly penalised
  Laplace objective for one ordinary `latent(d = 1:2)` block with no free Psi,
  standalone `spatial_indep()`, or standalone `spatial_latent(d = 1:2)`, with
  a common logit, probit, or complementary-log-log link. `estimator = "ml"`
  remains the unchanged default, and a separation warning never switches
  estimators automatically. The admitted surface also requires a full-rank
  resolved fixed-effect design and all-zero offsets. The implementation follows
  the construction of Sterzinger and Kosmidis (2023,
  doi:10.1007/s11222-023-10217-3) for its fixed-effect
  Jeffreys component and extends it with rotation-invariant radial penalties
  for estimated GLLVM loadings and reference-scale spatial coordinates.
  At this development checkpoint, the compiled objective and point-estimation
  API are implemented, while frozen ordinary and spatial simulation promotion
  remains in progress. Likelihood
  comparison, standard errors, confidence intervals, profiles, and hypothesis
  tests fail closed. Missing responses, grouped binomial data, mixed families,
  rank above two, extra covariance tiers, VA/AGHQ/Julia MSPL, and general
  inference remain planned rather than advertised.

* **The loading MAP penalty now has the integration-neutral spelling
  `loading_ridge`.** It is an alias for `aghq_ridge`, not a new penalty, and
  preserves unpenalised Laplace fits unless named explicitly. Loading ridge and
  LA-MSPL are distinct estimators; supplying both is an error.

* **`screen_gllvmTMB()` can opt in to fixed-design separation certificates.**
  Use `screen_control(separation = "fixed")` to classify maximal
  coefficient-connected Bernoulli fixed-effect blocks as overlap, complete
  separation, or quasi-complete separation. The detector supports the logit,
  probit, and complementary log-log links, finite known offsets, shared
  coefficients, and structural-zero `Xcoef_fixed` constraints. It requires the
  optional `detectseparation` package. The default remains
  `separation = "none"` and does not load that package. This is a fixed-design
  diagnostic only: it does not certify finite latent loadings or covariance
  parameters, and it never selects a penalized estimator automatically.

## Fixed

* **`screen_gllvmTMB()`'s `known_groups` argument no longer misses a
  partial-order nesting declaration or a certified one-hot block in its
  unresolved-dependency count (reported by @Ayumi-495,
  `urbanisation_map#23`).** Two related defects in the `known_groups`
  feature shipped in #1123: (1) a group of three or more traits whose
  containment relations form a partial order rather than a single total
  chain -- for example a broad realm indicator ("water") containing two
  mutually incomparable narrower ones ("freshwater", "marine") --
  previously fell through the chain-only check (which tested only the
  declared order and its reverse) and silently PASSed
  `known_group_checked` instead of FAILing `known_nesting`; the check now
  tests every pairwise containment among the declared members and names
  every relation it finds. (2) `$response_dependencies`' `unresolved`
  affine-dependency count never subtracted the one-hot certificates a
  user declared via `known_groups`, so a correctly certified dependency
  could still be reported as "N further exact affine dependencies ...
  could not be automatically resolved". The count is now the RANK of the
  pooled certified null-vector span (automatic certificates + declared
  one-hot blocks), not a subtraction of row counts, so declaring the same
  dependency under two names -- or via two overlapping groups -- cannot
  under-report a genuinely unresolved dependency. A nesting/containment
  relation is an inequality, not an exact affine relation, and still
  contributes nothing toward `unresolved`. Also fixed in the same pass: a
  typo'd trait name in `known_groups` was silently accepted whenever the
  affine/known-group check itself was infeasible for the data (no unit
  column, non-Bernoulli rows, duplicate unit-trait rows, too few complete
  units); trait names are now validated before that feasibility check, so
  a typo always aborts.
* **`screen_gllvmTMB()`'s `known_groups` one-hot test was whole-group
  only and is now a bounded exhaustive subset search (#1154, reported by
  @Ayumi-495).** `known_groups = list(g = c("A", "B", "C", "D"))`, where
  `{A, B, C}` is a genuine one-hot block and `D` is an unrelated trait
  declared in the same group, previously reported `known_group_checked`
  PASS -- the same "declaring a slightly-too-large group weakens the
  verdict" shape as the nesting defect fixed just above, since the test
  was `all(abs(rowSums(Yg) - 1) < tol)` over the *whole* declared group.
  A declared group of `k <= 12` members now gets an exhaustive search
  over every subset of size 2 or more (at most `2^12 - 13 = 4083`
  row-sum checks, microseconds), and every MINIMAL one-hot subset found
  is reported as its own `known_one_hot_subset` certificate -- `A + B +
  C = 1` once, never also as a redundant larger superset -- and
  contributes to the `unresolved` affine-dependency count exactly like a
  whole-group `known_one_hot` certificate. `k > 12` is never silently
  skipped: the whole-group one-hot and pairwise nesting checks still
  run, but an explicit `known_group_subset_not_attempted` row records
  that the subset search itself was not attempted at that size, rather
  than folding into a silent PASS. A subset that sums to 1 only because
  every one of its members is constant is not certified (the same guard
  the whole-group check already had). Nesting was not affected: its
  pairwise scan already covers every pair within a declared group
  regardless of unrelated members, so it had no equivalent blindness.

* **`fit_health$boundary_flags` no longer flags the auto-Psi skip block's
  mapped-off `sd_B` placeholders as `near_zero_sd_B` (#25).** The same
  `skip_psi_b_t` pinning described in the `near_zero_psi_unit` fix below
  (single-trial Bernoulli traits, and every multinomial contrast
  pseudo-trait, pinned to `sd_B = 1e-6` and mapped off) was also read raw
  by `.gllvmTMB_boundary_flags()`, which had no `diag_B_skip` filter of its
  own, so it unconditionally flagged the pinned placeholder. A default
  auto-skip fit and its explicit `latent(..., unique = FALSE)` mirror could
  therefore disagree on `boundary_flags` for an otherwise identical model.
  Both readers now share one helper, `.gllvmTMB_estimable_components()`,
  which drops the mapped-off entries before either screen runs; a genuine
  collapse among the remaining, estimable traits is still caught. This is a
  **behaviour change**: fits with a mapped-off Psi trait that previously
  carried a spurious `near_zero_sd_B` flag no longer do.

* **`simulate()` now draws from each row's true family instead of silently
  substituting a Gaussian-on-link-scale number for nine families, and
  multi-trial `binomial()` responses are drawn at the correct trial count.**
  `.draw_y_per_family()` previously fell through to a single shared branch
  for any family it did not explicitly recognise, so tweedie, Beta,
  betabinomial, Student-t, truncated Poisson, truncated NB2,
  `delta_lognormal`, `delta_gamma`, and ordinal-probit rows were redrawn as
  plain Gaussian noise on the link scale — a plausible-looking but wrong
  number, not an error. `simulate()`, `predictive_check()`'s simulation-based
  plot types (`stat_grouped`, `dens_overlay`), and anything built on
  `.gllvmTMB_predictive_draws()` (bootstrap/coverage helpers included) now
  draw correctly for 16 of these — every family except tweedie, which has no
  exact draw without a new dependency and now returns `NA` with a per-call
  warning rather than the previous wrong-distribution substitute. Multinomial
  rows draw a single grouped categorical outcome per observation rather than
  an independent draw per contrast row. Binomial rows previously ignored
  trial count and drew Bernoulli regardless of `cbind(success, failure)` /
  `weights = n_trials`; they now draw `rbinom()` at the row's actual
  `n_trials`.

* **`check_gllvmTMB()`'s `near_zero_psi_unit` screen no longer flags traits
  the auto-Psi skip block deliberately pinned off.** `R/fit-multi.R`'s
  `skip_psi_b_t` block maps a trait's between-unit `Psi` off (single-trial
  Bernoulli, and every multinomial contrast pseudo-trait) by pinning
  `theta_diag_B` at `log(1e-6)`, but `src/gllvmTMB.cpp` still `REPORT`s
  `sd_B` for every trait including the pinned ones, so the pinned `1e-6`
  entry always cleared both the absolute (`psi_thresh = 1e-4`) and relative
  (`psi_rel_thresh`) collapse thresholds. This was a structural false
  positive that predates the Design 123 arc above: `check_gllvmTMB()` WARNed
  `near_zero_psi_unit` on every fit with a single-trial-Bernoulli or
  multinomial trait sharing a `latent()` term with a free partner trait,
  regardless of whether the free trait's Psi was healthy. The screen now
  drops pinned entries (via `tmb_data$diag_B_skip`) before evaluating the
  unit-level psi row; a genuine collapse among the remaining free traits is
  still caught.

* **`multinomial()` structured-term admission is now fail-closed (Slice 0,
  Design 108/123).** Several deferred keywords previously desugared
  (`R/brms-sugar.R`) onto the same internal engine flag as an admitted
  keyword and silently reached an untested categorical path instead of
  erroring: `dep()` at the unit tier, `phylo_dep()`, `phylo_indep()` /
  `phylo_unique()` (standalone), `animal_latent()`, single-name
  `kernel_*()`, and `phylo_scalar()` / `animal_scalar()`. Every one of these
  now aborts, as the documentation always said they should. **If you fitted
  a `multinomial()` trait combined with any of the keywords above, that fit
  ran on an unvalidated structured-term path and should be re-checked** —
  the currently admitted set is unchanged: fixed effects, an ordinary shared
  `latent(0 + trait | unit, d = k)` ordination, and intercept-only
  `phylo_latent()` (default `unique = FALSE`; it emits no Psi companion at
  all). A `mi()` predictor term combined with a multinomial trait, previously
  invisible to the admission scan due to definition order, now also aborts.
  A follow-up adversarial review found the fence itself was not yet
  load-bearing everywhere: augmented (intercept + slope) `latent()` /
  `phylo_latent()` random regressions, `phylo_latent(unique = TRUE)` (a free
  phylogenetic Psi, never admitted, but the fence's first pass wrongly
  labelled it admitted), and `meta_V()` / `equalto()` (no established route
  on a categorical-contrast pseudo-trait) are now all explicitly blocked,
  with a shared classed condition (`gllvmTMB_multinomial_structured_not_admitted`)
  on every path.

* **The `multinomial()` structured-term surface now admits a bounded set of among-category and grouping
  structures, each gated on a signed, pre-registered recovery campaign
  rather than construction alone.** Every admission below is enforced by
  the same fail-closed classifier (`R/multinomial-fence.R`); anything not
  named below still aborts typed
  (`gllvmTMB_multinomial_structured_not_admitted`). The full per-cell table
  and supporting evidence are available in the
  [package repository](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/123-multinomial-structured-surface.md).

  **Admitted:** the phylogenetic/relatedness surface -- intercept-only
  `phylo_latent()`/`animal_latent()`/single-name `kernel_latent()`
  (loadings-only), `phylo_dep()`/`animal_dep()`/`kernel_dep()` (full
  unstructured `V`, the IDENTICAL parameterisation as
  `phylo_latent(d = K - 1)`), and `phylo_indep()`/`animal_indep()`/
  `kernel_indep()` (diagonal `V`); the spatial (SPDE) surface --
  `spatial_latent()`, `spatial_indep()`, and `spatial_dep()` (verified
  identical to `spatial_latent(d = n_traits)`); a generic `(1 | group)`
  random intercept (baseline-vs-rest semantics, `sigma_re`
  reference-category-specific); and the non-phylogenetic `cluster`/
  `cluster2` diagonal tier, `indep(0 + trait | g)`.

  **The honest evidence, not softened:** on the phylogenetic surface, the
  ONE-CATEGORICAL-DRAW-PER-SPECIES recovery gate **FAILED** for both the
  loadings-only route (FAM-20C: rail rate 8/20, exceeding the 6/20
  threshold, identically for `animal_latent()`/`kernel_latent()` by proven
  engine identity to `phylo_latent()`) and the mode-axis route (FAM-20D:
  `phylo_dep()` rails 8/20; `phylo_indep()`'s corrected diagonal-truth
  rerun shows larger contrast variances recover fine, median ratio 0.78,
  17/20 in band, but smaller ones collapse, median ratio 0.24, 9/20 --
  **7 of those 20 seeds collapse the smaller contrast variance to
  numerical zero (≤1e-9)**, each with `convergence = 0` AND a PD Hessian,
  and no runtime detector currently flags it (`R/diagnose.R`'s degeneracy
  gate is family_id == 1-only, issue #897's class) -- and the planted-zero
  check FAILS -- a full-`V` `phylo_latent()` refit on
  diagonal-truth data rails to median |rho| = 1.0). A pre-registered
  **replication rescue PASSED**: five categorical draws per species (`n_sp
  = 300`, `n_rep = 5`) recovers V with rail rate 4/20, median rho 0.680
  among the 16 NON-RAILED seeds (0.696 among all 20 conv+PD seeds --
  both bands, true 0.6), SD ratios 0.89/0.85 -- **one categorical draw per
  species does not identify V; five draws per species does.** This rescue
  transfers exactly to `phylo_dep()` (the identical parameterisation) but
  has NOT been tested for the diagonal-`V` mode (`phylo_indep()`). The
  spatial kappa/tau gate, by contrast, **PASSED all three cells** (median
  practical-range ratios 1.75 / 1.12 / 1.75 among the 14 conv+PD seeds per
  cell, band 0.33-3.0; rails 0, 3, 0 of those 14 against the frozen
  threshold, restated in its pre-registered form: >6/20; 6/20 seeds were
  non-PD per cell, excluded from the ratio band). Per-seed dispersion is
  wider than the median suggests: 4 of the 14 PD seeds fall outside
  [0.33, 3.0] for `latent()`/`dep()` (up to a 4.56 ratio), and
  `spatial_indep()` collapses the range in **6 of all 20 seeds** (ratios
  down to 7e-5): 3 of those 6 are PD -- the rails counted under the frozen
  criteria, at ratios 2.3e-4 to 3.4e-4 -- and the other 3 sit among the
  6/20 non-PD exclusions. A collapsed field can pass the Hessian check,
  the same pattern as the phylogenetic surface's zero-collapse above. **The group-intercept gate ((1 | group)
  ONLY) also PASSED**: 20/20 converged with a PD Hessian, median
  `sigma_re` ratio 0.947, range [0.60, 1.51]. **This PASSED verdict does
  NOT extend to the cluster/cluster2 diagonal tier** -- the s4 campaign
  fit `re_int` exclusively; `cluster`/`cluster2` are admitted with
  construction-level evidence only (the fit constructs, `extract_Sigma()`
  returns a well-formed diagonal), and their recovery axis remains OPEN
  (a correction to an earlier draft of this entry, which wrongly implied
  the same PASSED verdict covered both).

  **Refused, not merely deferred:** `phylo_scalar()`/`animal_scalar()`/
  `kernel_scalar()`/`spatial_scalar()` and `common = TRUE` on the cluster/
  cluster2 tier -- a single shared level across the `K-1` contrasts has no
  interpretable null on the `(I+J)` contrast geometry. Null-DGP evidence:
  on `V_true = 0` data, `phylo_indep()` correctly recovers near-zero
  variance in 5/5 seeds, but `phylo_dep()`'s `rho_hat` rails toward `+-1`
  in 4/5 seeds despite a PD Hessian.

  **Behaviour changes:** a `(1 | group)` or cluster/cluster2 `indep()` term
  whose grouping factor covers exactly one categorical observation per
  level now aborts typed (`gllvmTMB_multinomial_olre_not_admitted`) -- it
  is an observation-level random effect in disguise, unidentifiable
  because the softmax latent scale is fixed. `meta_V()`/`equalto()`
  (known-sampling-covariance) remains fail-closed for `multinomial()`
  traits -- confirmed Gaussian-only, no established route on a
  categorical-contrast pseudo-trait. `cluster2` co-admission alongside
  `cluster` was a maintainer decision (2026-08-16): `use_diag_species` and
  `use_diag_cluster2` are literally identical engine math on two different
  grouping columns.

# gllvmTMB 0.6.0

This release focuses on multivariate stacked-trait models fitted through the
R/TMB engine. Models are fitted by **Laplace approximation by default**; an
opt-in scalar variational research route is also available. The optional Julia
bridge remains experimental and is not required for the main workflow.

## Changed

* **Integrated models now take any number of named sources, declared with
  `isdm_sources()` (experimental).** A portal stream, digitised literature
  records, checklists, and a structured survey can each be a named source with
  its own observation law, all sharing one ecological process:
  `family = isdm_sources(gbif = poisson(), literature = poisson(), survey =
  binomial("cloglog"))`, with an `isdm_source` column in the data naming each
  row's source. Two laws are admitted — a Poisson count stream and a
  complementary-log-log detection stream — because both observe a thinning of
  the same shared intensity; that argument holds arm by arm, so it does not
  weaken as sources are added. Everything the two-source route refused stays
  refused: logit or probit detection, dispersion-carrying families, `weights`,
  multi-trial rows, and any trait not observed by every declared source. The
  existing two-source form (`list(gbif = ..., survey_pa = ...)`) keeps working
  unchanged and gives identical fits — it is now the two-source case of the
  same rule. A worked example, *Integrating three data sources at once:
  portal, atlas, and survey*, fits a three-source model end to end through the
  declared route. Everything reported remains relative intensity, and the
  interface remains experimental.

* **Integrated two-source models can now be fitted through `gllvmTMB()`
  itself (experimental).** Opportunistic presence-only records and a
  structured detection/non-detection survey of the same species can enter one
  likelihood, sharing an ecological linear predictor while each source keeps
  its own observation model. There is no separate function for this: supply
  `family = list(gbif = poisson(), survey_pa = binomial("cloglog"))` with
  `attr(family, "family_var") <- "isdm_family"`, a `source` column, and a
  matching `isdm_family` column. This is the one case where the response
  family may vary *within* a trait rather than only between traits, and it is
  admitted because the cloglog link makes a detection observation consistent
  with the same underlying intensity that generates the counts. An `offset()`
  is admitted on that arm as a known change-of-support term. Anything short of
  that exact contract still gets the ordinary one-family-per-trait error, and
  Poisson-log mixed with binomial-logit or -probit remains refused.

  **In:** the route is reachable, documented, and contract-tested. Two
  articles cover it: *Integrating opportunistic records with a repeated
  survey* fits and renders through the public route, and *How big does an
  integrated survey design need to be?* reads a known-truth design curve to
  ask whether a design is large enough before you fit at all. **Partial:** everything reported is relative intensity —
  presence-only data cannot identify absolute abundance, occupancy, or
  detectability, and none are estimated. Source-specific spatial structure is
  only weakly identified on small designs; treat a portal-only field as a
  nuisance adjustment unless the design is large. Estimator accuracy at the
  advertised scope is not certified, and the spatial arm in particular rests
  on development experience rather than a cleared recovery gate. **Not
  included in this legacy two-source spelling:** declarations with more than
  two sources; use the experimental `isdm_sources()` route described above.
  Calibrated intervals and weighted joint likelihoods remain unavailable on
  either spelling. Expect the interface to change.

* **The exact-aa confirmation completed 44,800 production fits and returned
  aggregate HOLD.** Gaussian `indep()`, Gaussian `dep()`,
  Poisson-log rank-1 `latent(unique = TRUE)`, and Binomial(10)-logit rank-1
  `latent(unique = TRUE)` passed their prespecified small/large core
  point-estimation gates. Gaussian latent and NB2 latent remained
  characterization-only. This does not establish a package-wide dependable
  core: the full eligible cell set was incomplete, every campaign contained
  failed cells, and the observable terminal-status detector identified only
  19 of 80 catastrophic truth errors. The result supports narrow tested-regime
  point-estimation statements only; it does not certify intervals, structured
  sources, slopes, mixed families, alternative integration engines, or
  reliable silent-failure detection. The package remains version 0.6.0 while
  this evidence and the remaining pre-0.7 issue backlog are reconciled.

* **A fit without standard errors no longer returns a silent all-`NA` answer.**
  When a model is fitted with `gllvmTMBcontrol(se = FALSE)`, there is no
  `sd_report`, so a Wald interval has nothing to be built from. `confint()`
  used to return a matrix of `NA` bounds with no error and no warning — a
  non-answer that looks like an answer, and that flows onward into tables and
  plots with nothing marking it.

  `confint(method = "wald")` now **raises a typed error**
  (`gllvmTMB_confint_no_sdreport`) naming both remedies:
  `fit <- standard_errors(fit)`, or `method = "profile"`, which does not need
  standard errors. This covers both Wald routes — the fixed-effects path and
  the variance-component target path (`parm = "sigma_eps"` and friends). The
  extractor-style consumers `getREsd()`, `getLV(se = TRUE)` and
  `predict(se.fit = TRUE)` already behaved this way.

  **The other way to have no usable standard errors is also covered.** A fit
  whose Hessian is not positive-definite *has* an `sd_report`, but its standard
  errors come back non-finite — and those used to print as a wall of bare `NaN`.
  `summary()` now says so, and `confint()` aborts
  (`gllvmTMB_confint_nonfinite_se`). The advice deliberately differs: this is a
  property of the fit, so `standard_errors()` cannot help and the message points
  at `gllvmTMB_diagnose()` and `method = "profile"` instead.

  **A single `NA` is left alone.** A coefficient fixed via `Xcoef_fixed` has no
  standard error, and `NA` is the right answer there — only an *entirely*
  non-finite set is treated as the pathology.

  **`summary()` deliberately still works.** Fitting fast and reading point
  estimates is a legitimate workflow, so `summary()` prints as before — but it
  now says *why* the `Std.Err` column is empty instead of leaving a column of
  bare `NA`s to be read as a computed result. `extract_cutpoints()` reports the
  same way for its `tau_se` column.

  This is a deliberate behaviour change, made rather than staged: the package
  is pre-1.0 and experimental, so no released code depends on the old return,
  and anything that did would have been depending on a wrong answer.

## New

* **`gllvmTMBcontrol(integration = "va")` now admits all 18 scalar family/link cells and defaults to seven-node Gauss-Hermite evaluation.** Each cell passed an independent arithmetic, compiled, and light-fit gate before H = 7 and automatic GH routing were promoted; analytic cells retain exact fast paths, explicit JJ remains available only for binomial-logit comparisons, and multinomial or other non-scalar architectures remain excluded. The preregistered 36,000-fit confirmation is complete: only the Poisson-log q = 5 cell passed the overall point route, while 24 of 36 family-by-rank cells failed and 11 were inconclusive. Against the campaign's cell-specific criteria, fixed-effect VA-Wald outcomes were 20 pass / 16 fail, while latent posterior-SD outcomes were 15 pass / 20 fail / 1 inconclusive. These are campaign outcomes, not public calibration certificates: `vcov()` and `confint()` remain labelled `calibrated = FALSE`, `getLV(se = TRUE)` remains a variational posterior SD rather than a frequentist standard error, and Laplace remains the package default. Both campaign stages ran on Totoro, so this is not cross-platform confirmation.

* **`vcov()` and `coef()` now work on multi-trait fits.** `coef(fit)` returns
  the named fixed-effect estimates and `vcov(fit)` their covariance, taken from
  the fit's `sdreport()`. Both were previously registered only for the
  variational `gllvmTMB_va` class — where `coef()` deliberately refuses and
  `vcov()` is now restricted to uncalibrated fixed-effect VA-Wald inference —
  so calling either on an ordinary fit raised "no applicable method", *despite
  the documentation saying otherwise*.

  `coef()` works on any fit, including one made with `se = FALSE`: point
  estimates do not depend on `sdreport()`. `vcov()` does, and raises the same
  typed conditions `confint()` does when it is missing or non-finite, so a
  caller that handles one handles the other. Rows and columns for coefficients
  held fixed via `Xcoef_fixed` are `NA` — a parameter that was not estimated has
  no sampling covariance.

* **`standard_errors()` computes standard errors after fitting.** Fitting with
  `gllvmTMBcontrol(se = FALSE)` skips the TMB `sdreport()` and is meaningfully
  faster, but it used to be a one-way door: the only route to standard errors
  afterwards was to fit the model again. `fit <- standard_errors(fit)` now
  computes them on demand from the fitted object.

  The result is the fit-time calculation deferred, not a different one — the
  same single `sdreport()` call on the same converged parameter vector,
  verified bit-exact (`tolerance = 0`) against a fit made with `se = TRUE`.
  Every existing consumer — `summary()`, `getLV()`, `getREsd()`,
  `confint(method = "wald")` — then works on the returned object.

  Note the R semantics: the fit is **returned**, not modified in place. Assign
  the result, or the standard errors are discarded.

  **Same-session only.** A TMB ADFun holds external pointers that do not
  survive `saveRDS()` or a new R session, so this cannot revive a saved fit.
  That limitation is shared by every part of the package that reuses the fitted
  TMB object; what is new is that this function says so with a clear, typed
  error instead of failing obscurely. This adds no new inference and changes no
  likelihood, parameterisation, or honesty caveat — Wald standard errors carry
  exactly the caveats they carried before.

* **Spatial mesh, CRS, and range-plot helpers were substantially rewritten
  within gllvmTMB.** The retained implementation descends from earlier
  GPL-3 `sdmTMB` helpers and keeps that attribution in `inst/COPYRIGHTS`.
  `make_mesh()` returns a `gllvmTMBmesh` built through
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

  On the default Laplace route the penalty is **opt-in and never applied unless
  you name it**, so no existing Laplace fit changes. AGHQ is itself opt-in; once
  AGHQ is enabled, its default is the penalised `tau = 2` MAP route unless
  `aghq_ridge = Inf` requests an unpenalised fit. `tau` is the prior standard
  deviation on each free loading, and
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
  auto-selection succeeded. Both pilot and returned AGHQ fits use the fixed
  9-node multi-start rule evaluated for failure/runaway avoidance in this
  Bernoulli grid; this is not interval calibration or general estimator
  certification. Conflicting `aghq` or `aghq_multistart` controls
  are replaced with a warning.

  This scope is supported as a **runaway/failure-avoidance** capability, not as
  a general accuracy improvement. In the 600-replicate evaluation,
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
  its own numbers. The guard and its tests are covered; bootstrap interval
  calibration for non-Gaussian and mixed-family fits remains uncertified.

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

* **Variance components: what is and is not claimed.** Point estimates are the
  package's primary inferential output, but their evidence is route- and
  regime-specific.
  Broad package-wide interval coverage is not certified. Three exact native
  pinned unrotated ordinary-Gaussian standardized-loading Wald cells have target-specific
  certificates: `(n_units=150,d=2)`, `(n_units=400,d=1)`, and
  `(n_units=400,d=2)`, restricted to structurally free strict-lower targets.
  This is one frozen DGP: trait intercepts `(-0.20, 0.10, 0.25)`, unique
  standard deviations `(0.70, 0.80, 0.90)`, and loading vector
  `(0.80, 0.45, -0.35)` for `d=1`, with second column `(0, 0.70, 0.40)` for
  `d=2`. Coverage is conditional on eligible fits (optimizer convergence,
  converged fit health, available `sdreport()`, and a positive-definite
  Hessian); availability was 98.82%, 93.38%, and 96.18% in the three certified
  cells. The `n_units=150,d=1` cell failed. No other truth-parameter regime
  inherits the result. Pinned diagnostics, Fisher-z Wald,
  arbitrary constraints, rotated or neighbouring regimes, and the global
  loading route remain uncalibrated. `profile_ci_total_variance()` now labels
  every computed penalty-profile approximation `route-only`; its former
  `certified-0.94` labels are withdrawn because retained endpoints do not prove
  exact constrained-refit convergence or target attainment. Intervals are
  route output, not a coverage guarantee.
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
