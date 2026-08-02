#' Fit multivariate response models from wide or long data
#'
#' Top-level entry point for models with several responses per site,
#' individual, species, or study. Start from a wide data frame with
#' [traits()] on the formula left-hand side, or from already-stacked long
#' data with one row per `(unit, trait)` observation. Both routes estimate
#' the same trait covariance, pairwise correlations, shared latent axes,
#' and trait-specific variance. The formula syntax also supports fixed
#' effects plus covariance-structure keywords organised by
#' \emph{correlation source} (none / animal / phylo / spatial) and
#' three \emph{modes} (independent / dependent / latent). The `common = TRUE`
#' modifier on `*_indep()` gives the one-shared-variance special case:
#'
#' \tabular{llll}{
#'   \strong{source \\ mode} \tab \strong{independent} \tab \strong{dependent} \tab \strong{latent} \cr
#'   \emph{none}    \tab [indep()]         \tab [dep()]         \tab [latent()]         \cr
#'   \emph{animal}  \tab [animal_indep()]  \tab [animal_dep()]  \tab [animal_latent()]  \cr
#'   \emph{phylo}   \tab [phylo_indep()]   \tab [phylo_dep()]   \tab [phylo_latent()]   \cr
#'   \emph{spatial} \tab [spatial_indep()] \tab [spatial_dep()] \tab [spatial_latent()] \cr
#' }
#'
#' The three covariance modes (`indep` / `dep` / `latent`) encode
#' covstruct intent across traits:
#'
#' * `latent` — the **decomposition** mode
#'   \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi}:
#'   a low-rank shared part plus a diagonal \eqn{\boldsymbol\Psi} companion.
#'   Ordinary `latent()` carries \eqn{\boldsymbol\Psi} by default; the
#'   `unique =` argument controls it (`latent(..., unique = FALSE)` for the
#'   loadings-only subset, `*_latent(..., unique = TRUE)` to fold the
#'   \eqn{\boldsymbol\Psi} companion into a source-specific term).
#' * `indep` — the **marginal-only** mode: each trait gets its own
#'   variance, no cross-trait covariance.
#' * `dep` — the **full unstructured** mode: \eqn{\boldsymbol\Sigma}
#'   is free with \eqn{T(T+1)/2} parameters via a Cholesky factor.
#'
#' Plus the supporting [phylo_slope()] / [animal_slope()] (random
#' slopes), [meta_V()] (known-V meta-analytic; [meta_known_V()] is a
#' deprecated alias), and the engine-internal `propto()` /
#' `equalto()` covstructs (used by the canonical keywords above; not
#' typically called directly). See the
#' [formula keyword grid article](https://itchyshin.github.io/gllvmTMB/articles/api-keyword-grid.html)
#' for a one-paragraph tour of each cell.
#'
#' @param formula A glmmTMB-style formula, e.g.
#'   `value ~ 0 + trait + (0 + trait):env_temp + (0 + trait):env_precip`.
#'   Fixed effects and any of the three-mode grid covstructs above are
#'   supported (plus [phylo_slope()], [animal_slope()], and [meta_V()]).
#'
#'   An `offset()` term is supported for **count responses only** — `poisson()`,
#'   `nbinom1()`, `nbinom2()`, `truncated_poisson()`, and
#'   `truncated_nbinom2()` — where it is the usual exposure or effort
#'   adjustment. Supply it already on the link scale, e.g.
#'   `offset(log(trap_nights))`. It must be its own additive term; it is not
#'   interacted with `trait`.
#'
#'   In long format the offset column carries one value per `(unit, trait)`
#'   row, so it can differ by trait. In wide format, `offset(w)` names one
#'   unit-level column and applies it to every trait, while
#'   `offset(e1, e2, ...)` names one column per trait, in [traits()] order.
#'
#'   A **nonzero** offset on a non-count trait is an error naming that trait.
#'   Zero is always allowed and does nothing (on the log scale it is a
#'   multiplier of one), which is how a mixed-family model gives an offset to
#'   its count traits and not the rest.
#' @param data A data frame. With an ordinary response LHS such as
#'   `value ~ ...`, `data` is long: one row per `(unit, trait)`
#'   observation, with the trait column named by `trait`. With a
#'   [traits()] LHS, `data` is wide: one row per unit and one column per
#'   response named inside `traits(...)`. Missing response values are
#'   allowed: by default they are dropped before fitting, while
#'   `missing = miss_control(response = "include")` masks them out of the
#'   likelihood and keeps original-row accounting for [predict_missing()].
#'   Ordinary missing predictors, grouping variables, and design-matrix values
#'   still error; explicitly modelled missing predictors use `mi(x)` with
#'   `missing = miss_control(predictor = "model")` and `impute = list(...)`.
#' @param trait Name of the column holding the trait factor (the
#'   "trait" dimension of the unit × trait response matrix). Default
#'   `"trait"`.
#' @param unit Name of the column holding the **between-unit** grouping
#'   factor (the "unit" dimension of the unit × trait response matrix).
#'   Examples: `"site"` for site × species data, `"individual"` for
#'   behavioural-syndrome data, `"species"` for PGLLVM, `"paper"` for
#'   systematic mapping. Default `"site"`.
#' @param unit_obs Name of the column holding the **within-unit**
#'   grouping factor — one level per (unit, replicate) cell — used by
#'   `latent(0 + trait | unit_obs, ...)` and
#'   `indep(0 + trait | unit_obs)` for the W-tier covariance.
#'   Default `"site_species"` (the conventional name in joint species
#'   distribution modelling; safe for site × species data). For other
#'   domains pass e.g. `unit_obs = "obs"` for behavioural syndromes.
#' @param site (deprecated) alias for `unit`. Kept for backward
#'   compatibility. Use `unit = ...` in new code.
#' @param cluster Name of the column holding the **third grouping**
#'   factor (the "cluster" slot). When the column name matches the
#'   row/column names of `phylo_vcv` (or the tip labels of
#'   `phylo_tree`), this slot also drives the phylogenetic random
#'   effects (`phylo_latent`, `phylo_scalar`, `phylo_indep`,
#'   `phylo_slope`). When the column does **not** match a phylogenetic
#'   correlation, the slot still functions as a regular crossed/nested
#'   third grouping (e.g. `cluster = "population"` for 3-level
#'   personality data, `cluster = "study"` for multi-study
#'   meta-analysis). Default `"species"`. For datasets with no third
#'   grouping the column may be absent from `data`; the engine will
#'   synthesise a placeholder.
#'
#'   The engine does **not** enforce nesting between `unit_obs`,
#'   `unit`, and `cluster` — crossed and nested designs both fit. Two
#'   canonical patterns:
#'   \itemize{
#'     \item Functional biogeography (crossed): `unit = "site"`,
#'           `unit_obs = "site_species"`, `cluster = "species"`. Sites
#'           and species are crossed; `site_species` indexes the
#'           intersection cell.
#'     \item 3-level personality (strictly nested): `unit =
#'           "individual"`, `unit_obs = "session_id"`,
#'           `cluster = "population"`.
#'   }
#' @param cluster2 Optional name of the column holding a **second
#'   independent grouping** factor (the "cluster2" slot), for fitting two
#'   crossed (or nested) plain diagonal per-trait variance components at
#'   once. Default `NULL` (slot inactive). It is a plain crossed/nested
#'   diagonal grouping only -- it carries no phylogenetic or spatial
#'   correlation (those stay bound to `cluster` / `coords`). A
#'   `indep(0 + trait | <cluster2 col>)` term then fits a per-trait
#'   variance at this second grouping, exactly as `cluster` does at the
#'   third slot.
#'   Example: `cluster = "site"`, `cluster2 = "year"` to fit
#'   a site variance and a year variance simultaneously. As with the
#'   other slots, nesting is not enforced (crossed and nested both fit).
#'   The cluster2 column must be disjoint from the `unit` / `unit_obs` /
#'   `cluster` columns (a diagonal term routes to whichever slot its grouping
#'   column matches).
#' @param species (deprecated) alias for `cluster`. Kept for
#'   backward compatibility. Use `cluster = ...` in new code.
#' @param family A `family` object. The multivariate engine
#'   (formulas with `latent()`, `indep()`, etc.) supports `gaussian()`,
#'   `binomial()` (logit / probit / cloglog), `poisson()` (log link),
#'   [ordinal_probit()] (the gllvmTMB-native ordinal threshold family
#'   with sigma_d = 1 fixed exactly; no delta-method approximation),
#'   `lognormal()` (log link), `Gamma(link = "log")`,
#'   `nbinom2()` (NB2 negative binomial; log link),
#'   `nbinom1()` (NB1 negative binomial; log link),
#'   `tweedie()` (compound Poisson-Gamma; log link),
#'   `Beta()` (logit link, mean-precision parameterisation; y in (0, 1)),
#'   `betabinomial()` (logit link, mean-precision parameterisation;
#'   k-of-n data),
#'   `student()` (heavy-tailed continuous; identity link),
#'   `truncated_poisson()` (zero-truncated count; log link),
#'   `truncated_nbinom2()` (zero-truncated NB2; log link), and the
#'   hurdle / two-part families `delta_lognormal()` / `delta_gamma()`
#'   (Bernoulli for presence + Lognormal/Gamma for the positive
#'   component; share one linear predictor under the current
#'   implementation -- see Details). For multi-trial binomial or
#'   beta-binomial (k-of-n) data, write the LHS of `formula` as
#'   `cbind(successes, failures)` (the canonical R / `glm()` /
#'   `glmmTMB` convention); the engine then uses the per-row trial
#'   count `successes + failures` as the binomial size. A `weights =`
#'   numeric vector of trial counts is also accepted as an alternative
#'   API (see Details). The negative-binomial families fit one
#'   log-dispersion parameter per trait: `nbinom1()` uses
#'   Var = mu * (1 + phi), while `nbinom2()` uses
#'   Var = mu + mu^2 / phi. The `tweedie()` family
#'   fits one log-phi and one logit-(p-1) per trait, with p in (1, 2).
#'   The `Beta()` and `betabinomial()` families each fit one
#'   log-precision per trait (a = mu*phi, b = (1-mu)*phi; Smithson &
#'   Verkuilen 2006). The `student()` family fits one log-sigma and one
#'   log(df-1) per trait (df > 1; pass `student(df = 3)` to fix df at
#'   a known value). The `truncated_*()` families require strictly
#'   positive integer responses (y >= 1). The delta families fit one
#'   log-dispersion of the *positive* component per trait
#'   (sigma_lognormal or phi_gamma).
#' @param weights Optional numeric vector of length `nrow(data)`. Family-
#'   conditional semantics (lme4 / glmmTMB convention):
#'   * For **non-binomial** families, `weights` is interpreted as per-
#'     observation likelihood multipliers — each row's log-likelihood
#'     contribution is multiplied by `weights[i]`. This matches the
#'     `weights` argument of `lme4::lmer()`, `glmmTMB::glmmTMB()` and
#'     `stats::glm()`. Use this for relative-abundance weighting
#'     (`sqrt(p_si)`), inverse-variance weighting (`1 / var_i` for
#'     heteroscedastic Gaussian fits), or to down-weight outliers.
#'     Must be non-negative and finite; `weights[i] = 0` zeroes that
#'     row's contribution to the joint NLL.
#'   * For **binomial** families fit without a `cbind(succ, fail)` LHS,
#'     `weights` continues to be interpreted as the per-row trial count
#'     (binomial size; alternative API to `cbind(succ, fail)`). This
#'     pre-existing semantics is preserved on a per-row basis: in mixed-
#'     family fits, binomial rows use `weights[i]` as their trial count
#'     and non-binomial rows use it as the likelihood multiplier.
#'   Default `NULL` is equivalent to a length-`nrow(data)` vector of
#'   ones (unweighted Bernoulli on binomial rows). Wide matrix calls
#'   through [gllvmTMB_wide()] and wide data-frame calls through
#'   [traits()] normalise their accepted weight shapes to this same
#'   stacked response vector before fitting.
#' @param REML Logical; use restricted maximum likelihood for Gaussian-only
#'   fits. The current REML pilot is deliberately narrow: all response rows
#'   must be Gaussian, observation weights are not supported, and `mi()`
#'   predictor models, predictor-informed `latent(..., lv = ~ x)` scores, and
#'   `Xcoef_fixed` maps are not supported. The observed fixed design must be
#'   full rank with positive residual degrees of freedom. Either
#'   missing-response policy may be used: masked cells
#'   (`miss_control(response = "include")`) contribute nothing to the
#'   likelihood, so the restricted likelihood is formed over the observed rows
#'   and matches the corresponding `"drop"` fit. The default `FALSE` keeps the
#'   historical ML fit.
#' @param mesh Optional mesh object from [make_mesh()]. Required for any
#'   `spatial_*()` or `spatial()` term unless that term supplies its own
#'   `mesh =` argument; ignored only when the model has no spatial term.
#' @param phylo_tree (legacy global) Optional `ape::phylo` tree. The current
#'   syntax is to pass `tree =` inside
#'   each `phylo_*()` keyword (e.g. `phylo_latent(species, d = K, tree =
#'   tree)`); this argument is the older outer-level fallback and is
#'   slated for soft deprecation. When supplied (in either form) the
#'   `phylo_*()` terms build a sparse \eqn{\mathbf{A}^{-1}} over tips + internal
#'   nodes natively, using only \pkg{ape} and \pkg{Matrix} -- **no
#'   `MCMCglmm` dependency**. The construction is the deterministic
#'   Hadfield & Nakagawa (2010) sparse phylogenetic inverse (appendix
#'   eqs. 26-29), adopted from that method and ported from the sister
#'   package drmTMB (see `inst/COPYRIGHTS`). The result is `~5n`
#'   non-zeros for an `n`-tip tree, vs `n^2` for the dense path. **This is
#'   the recommended path** at any `n_species`; the speedup grows to ~24× at
#'   `n_species = 1000`.
#' @param phylo_vcv (legacy global) Optional tip-only `n_species ×
#'   n_species` phylogenetic correlation matrix. The canonical syntax
#'   is `vcv =` inside each `phylo_*()` keyword. **`r lifecycle::badge("superseded")`** —
#'   prefer `tree =`. The dense path inverts via `Matrix::solve()`,
#'   giving the same MLE as the sparse path but at `O(n^2)` memory and
#'   `O(n^3)` Cholesky cost. Use only when you have a Cphy in hand and
#'   no Newick tree (e.g. comparing against `nlme::corPagel`).
#' @param known_V Optional list of block-diagonal sampling-error matrices
#'   `V_t`. Used by the `equalto()` two-stage workflow when sampling-error
#'   matrices are available from a prior stage of estimation.
#' @param lambda_constraint Optional list with elements `unit` and / or
#'   `unit_obs` (plus `phy`, `spde` for structural levels), each an
#'   `n_traits × d` matrix of confirmatory loading constraints
#'   (galamm-style). `NA` entries are estimated; numerical entries are
#'   pinned. Upper-triangle entries are silently ignored — the engine's
#'   lower-triangular parameterisation already fixes those at zero.
#'   Default `NULL` uses the engine's exploratory lower-triangular
#'   convention. See [confirmatory_lambda()] to build the matrix from
#'   functional-group membership, or [suggest_lambda_constraint()] for a
#'   minimum statistical identification scaffold when you have no
#'   biological hypothesis. Deprecated legacy element names `B` and `W`
#'   are still accepted (with a one-shot soft deprecation message) and
#'   map to `unit` and `unit_obs` respectively.
#' @param Xcoef_fixed Optional named numeric vector of fixed-effect
#'   coefficient constraints. Names must match the expanded fixed-effect
#'   design columns (`fit$X_fix_names`); values must currently be `0`,
#'   pinning those coefficients exactly at structural zero. Use this when a
#'   predictor is meaningful for some responses but should be fixed at zero
#'   for others. Native TMB fits use a parameter map; admitted
#'   `engine = "julia"` fixed-effect-X rows pass the same zero mask to
#'   GLLVM.jl. This is ML-only: `REML = TRUE` stops loudly. Native fitted
#'   objects still report all fixed-effect rows; pinned rows have
#'   `estimate = 0`, `std.error = NA`, and `status = "fixed"` in
#'   `tidy(fit, "fixed")`.
#' @param control Output of `gllvmTMBcontrol()`.
#' @param missing Output of [miss_control()] configuring missing-data
#'   handling. The default `miss_control()` (`response = "drop"`,
#'   `predictor = "fail"`) omits each missing response *cell*: a unit keeps
#'   every trait it does have, so this is not case-wise deletion.
#'   `miss_control(response = "include")` instead keeps those cells and masks
#'   them out of the likelihood, preserving original-row accounting in
#'   `fit$missing_data`; it reaches the same optimum as the default and differs
#'   in which cells [predict_missing()] can return.
#' @param impute Optional specification of the covariate model for a predictor
#'   declared missing with `mi(x)` in `formula`, used only when
#'   `missing = miss_control(predictor = "model")`. Supply a two-sided
#'   predictor-model formula (for Gaussian sugar, e.g. `x ~ z`) or an
#'   [impute_model()] object for an explicit predictor family. The default
#'   `NULL` is appropriate when no `mi()` term is present.
#' @param silent Logical; suppress TMB and gllvmTMB chatter. Default `TRUE`.
#' @param engine Character; `"tmb"` (default) fits with the native TMB engine,
#'   `"julia"` routes the fit through the experimental GLLVM.jl bridge fitting
#'   path via JuliaCall (see `R/julia-bridge.R`). The Julia path currently maps
#'   the unconstrained-ordination core (a single `latent()` block + per-trait
#'   intercepts) and errors on structures it does not yet support.
#' @param ci_method Confidence-interval route requested at fit time for
#'   admitted `engine = "julia"` no-X rows. One of `"none"` (default),
#'   `"wald"`, `"profile"`, or `"bootstrap"`. Native `engine = "tmb"` fits use
#'   [confint()] after fitting; non-default `ci_*` arguments therefore error
#'   unless `engine = "julia"`. Grouped-dispersion rows, per-trait ordinal rows,
#'   response masks, mixed-family vectors, and fixed-effect-X rows remain gated.
#' @param ci_level Nominal confidence level when `ci_method != "none"` on the
#'   Julia bridge.
#' @param ci_nboot Number of parametric bootstrap replicates when
#'   `ci_method = "bootstrap"` on the Julia bridge.
#' @param ci_seed Seed passed to the Julia bootstrap CI route.
#'
#' @return A `gllvmTMB` object. With no covariance-structure terms in
#'   the formula the result has class `"gllvmTMB"` (single-response
#'   engine); with `latent()` or other covstruct sugar it has class
#'   `c("gllvmTMB_multi", "gllvmTMB")` (multi-trait engine).
#'   Either way, S3 methods such as `tidy()`, `predict()`,
#'   `vcov()`, `logLik()` etc. dispatch on `gllvmTMB`; `gllvmTMB_multi`-
#'   specific methods (e.g. trait-level `extract_ICC_site()`,
#'   `extract_communality()`) are available for multi-trait fits.
#'
#' @details
#' `gllvmTMB()` parses the glmmTMB-style formula, converts wide
#' [traits()] input to the same internal stacked-trait representation as
#' explicit long data, and dispatches to the underlying TMB template.
#' Covariance-structure terms (`latent()`, `indep()`, `propto()`,
#' `equalto()`, `spatial()`) are processed by extending the formula parser
#' and the TMB template.
#'
#' Per the manuscript, when stacking traits one should set
#' `dispformula = ~ 0` so that no implicit residual variance competes
#' with structured `indep(0 + trait | …)` terms. `gllvmTMB()` enforces
#' this internally.
#'
#' **Multi-trial binomial**. The TMB engine evaluates `dbinom(y, n_trials, p)`
#' so binomial fits are not restricted to Bernoulli (size = 1). To pass a
#' per-row trial count, use either:
#' \itemize{
#'   \item `cbind(successes, failures) ~ ...` on the LHS of the formula
#'         (canonical R / `glmmTMB` convention; recommended), or
#'   \item a flat response `y` with `weights = n_trials` (the alternative
#'         glmmTMB API).
#' }
#' Both interfaces produce identical fits. For Bernoulli data, omit
#' `weights` and use a 0/1 response; the engine sets `n_trials = 1` and
#' the likelihood is identical to the previous Bernoulli-only behaviour.
#'
#' **Missing responses and predictors.** `NA` response cells are treated as
#' unobserved unit-trait cells. Under the default
#' `miss_control(response = "drop")`, they are dropped before the TMB likelihood
#' is built; with `miss_control(response = "include")`, they are kept in the
#' model data, masked out of the likelihood, and available through
#' [predict_missing()]. For `cbind(successes, failures)` binomial responses, a
#' row is treated as missing when either response component is missing.
#' Observation weights, when supplied, are subset to retained likelihood rows
#' before validation. Ordinary missing predictors, grouping variables, or
#' fixed-effect design values still error because the model cannot construct a
#' design row; explicitly modelled missing predictors use `mi(x)`,
#' `miss_control(predictor = "model")`, and `impute = list(...)`.
#' These contracts are covered by the package's missing-data validation tests,
#' both for responses and for predictors.
#'
#' **Delta (hurdle) families.** `delta_lognormal()` and `delta_gamma()`
#' use a *single* linear predictor for both components: presence is
#' \eqn{\Pr(y > 0) = \mathrm{invlogit}(\eta)} and the positive-component
#' mean is \eqn{E[y \mid y > 0] = \exp(\eta)}. This matches sdmTMB's
#' standard delta default (one fixed-effects matrix, one set of trait
#' random effects). The shared-predictor scheme is the simplest hurdle
#' formulation; a future release may decouple the two predictors so
#' presence and abundance can have independent fixed and random effects.
#' Only `type = "standard"` (the default) is currently wired in the
#' multivariate engine; `type = "poisson-link"` is not implemented. Each
#' delta family carries one per-trait dispersion of the *positive*
#' component (no extra Bernoulli dispersion). The response must be
#' non-negative.
#'
#' ## Per-trait residual variance: when does it activate?
#'
#' "Residual" in a mixed-effects model is **scale-relative**: what
#' counts as residual variance shifts as you add levels to the model.
#' In a Gaussian fit without a per-row diagonal term, the residual is row-level
#' noise captured by a single shared `sigma_eps`. Once you add a per-row
#' `indep(0 + trait | obs)` term,
#' the *row-level* residual is now T per-trait random-effect variances and
#' `sigma_eps` is auto-suppressed to avoid double-counting. If you also add a
#' site-level diagonal term on top, the row-level term remains the residual and
#' the `site`-level term is now an additional, *higher-level* random effect, not
#' a residual at all. The dispatch table below records this explicitly for the
#' configurations the engine supports today.
#'
#' Gaussian and lognormal responses have one residual scale parameter,
#' `sigma_eps`. Ordinary Gamma responses instead carry a per-trait shape
#' `phi_gamma` (CV = `1 / sqrt(phi_gamma)`). Per-trait residual variances
#' only appear if you explicitly add a per-row `indep(...)` term.
#' The dispatch is automatic:
#'
#' \describe{
#'   \item{No per-row `indep`, Gaussian/lognormal present}{One
#'     shared `sigma_eps` across Gaussian/lognormal rows. *Not* per-trait.}
#'   \item{No per-row `indep`, no Gaussian/lognormal rows}{`sigma_eps`
#'     is mapped off; the family's intrinsic dispersion handles the residual
#'     (for ordinary Gamma, `phi_gamma`).}
#'   \item{\code{indep(0 + trait | g)} where `g` has fewer levels than
#'     rows (e.g. `g = "site"`)}{`sigma_eps` is still estimated as the
#'     row-level residual; the diagonal term adds a per-trait random
#'     effect at level `g` on top.}
#'   \item{\code{indep(0 + trait | obs)} at the per-row level (one
#'     level per row), Gaussian/lognormal rows fitted}{`sigma_eps` is
#'     auto-suppressed (mapped off, fixed at a tiny stabiliser); the
#'     T per-trait diagonal random effects *are* the residual. A
#'     one-shot `cli::cli_inform` fires at fit time announcing the
#'     auto-suppression.}
#'   \item{\code{indep(0 + trait | obs)} at the per-row level,
#'     non-Gaussian or mixed-family fit}{Treated as observation-level
#'     random effects (OLRE). For Bernoulli traits the OLRE is
#'     statistically unidentifiable and is mapped off; for hurdle /
#'     delta families a warning is emitted (see "Per-family-aware OLRE
#'     selection" below).}
#' }
#'
#' Mnemonic: Gaussian/lognormal `sigma_eps` is the default; ordinary Gamma uses
#' `phi_gamma`; per-row `indep` replaces the Gaussian/lognormal scalar residual
#' with T per-trait residuals; non-per-row `indep` adds a higher-level random
#' effect on top of the family residual;
#' non-continuous families never carry `sigma_eps` regardless.
#'
#' **Per-family-aware OLRE selection.** When
#' `indep(0 + trait | <unit_obs>)` is at
#' per-row resolution, i.e. one row per `(trait, unit_obs)` cell, the resulting
#' per-trait random effects on the linear predictor are an observation-level
#' random effect (OLRE). The engine now decides per trait what to do with the
#' OLRE variance based on the trait's response family:
#' \itemize{
#'   \item **single-trial Bernoulli** (`binomial()`, all rows have
#'         `n_trials == 1`): `theta_diag_W[t]` and the corresponding
#'         `s_W` column are mapped off. The OLRE is statistically
#'         unidentifiable here (no within-cell replication) and the MLE
#'         is the trivial boundary \eqn{\sigma_W \to 0}; pinning the
#'         parameter at \eqn{\sigma_W \approx 10^{-6}} removes the
#'         spurious free parameter and emits a one-shot informational
#'         message. Multi-trial binomial (via `cbind(succ, fail)` or
#'         `weights = n_trials`) is identifiable and fit normally.
#'   \item **delta / hurdle families** (`delta_lognormal()`,
#'         `delta_gamma()`): OLRE is fit as before, but a one-shot
#'         warning is emitted because the OLRE acts on the *shared*
#'         linear predictor of the hurdle and mixes presence and
#'         positive-component noise.
#'   \item **all other families**: OLRE is fit as before.
#' }
#' In a mixed-family fit (per-row family list) the per-trait decision
#' applies only to the affected trait. References: Nakagawa &
#' Schielzeth (2010) \emph{Biol. Rev.} 85: 935-956; Nakagawa, Johnson &
#' Schielzeth (2017) \emph{J. R. Soc. Interface} 14: 20170213.
#'
#' @seealso [traits()] for wide data-frame formula input;
#'   [gllvmTMB_wide()] for wide matrix/data-frame input;
#'   [simulate_site_trait()] for
#'   generating recovery test data;
#'   [extract_Sigma()] for the unified post-fit covariance API;
#'   [gllvmTMB_diagnose()] for a one-stop convergence + identifiability
#'   health check; [ordinal_probit()] for the gllvmTMB-native ordinal
#'   threshold family.
#'
#' @export
#' @examples
#' \dontrun{
#' set.seed(1)
#' sim <- simulate_site_trait(n_sites = 50, n_species = 8, n_traits = 3,
#'                            mean_species_per_site = 5)
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + (0 + trait):env_1 + (0 + trait):env_2,
#'   data   = sim$data,
#'   family = gaussian(),
#'   trait  = "trait",
#'   unit   = "site"
#' )
#' summary(fit)
#' }
gllvmTMB <- function(
  formula,
  data,
  trait = "trait",
  unit = "site",
  unit_obs = "site_species",
  cluster = "species",
  cluster2 = NULL,
  family = gaussian(),
  weights = NULL,
  REML = FALSE,
  mesh = NULL,
  phylo_vcv = NULL,
  phylo_tree = NULL,
  known_V = NULL,
  lambda_constraint = NULL,
  Xcoef_fixed = NULL,
  control = gllvmTMBcontrol(),
  missing = miss_control(),
  impute = NULL,
  silent = TRUE,
  engine = c("tmb", "julia"),
  ci_method = c("none", "wald", "profile", "bootstrap"),
  ci_level = 0.95,
  ci_nboot = 200L,
  ci_seed = 0L,
  site = NULL, # deprecated alias for `unit`
  species = NULL
) {
  # deprecated alias for `cluster`

  if (!is.logical(REML) || length(REML) != 1L || is.na(REML)) {
    cli::cli_abort("{.arg REML} must be a single {.code TRUE} or {.code FALSE} value.")
  }
  ## engine = "julia" routes through the experimental GLLVM.jl bridge fitting
  ## path via JuliaCall; "tmb" (default) keeps the native TMB engine below.
  engine <- match.arg(engine)
  ## An opt-in integration route must never SILENTLY fall back to Laplace. The
  ## caller would get a fit that is not the one they asked for and no signal
  ## that it happened -- the exact failure `gllvmTMBcontrol()` already records
  ## for arguments that `...` used to swallow. So the fence is checked first,
  ## here, so an out-of-region request fails on its own terms before any
  ## parsing cost -- in particular `engine = "julia"`, which has no variational
  ## route at all. Loud and wrong-shaped beats quiet and wrong.
  ##
  ## Only `engine` is knowable at this point; `q`/`p`/`n`/family/link are not
  ## resolved until the formula and data have been parsed, so the fence is
  ## called a SECOND time inside `gllvmTMB_multi_fit()` with those values.
  integration_route <- control$integration %||% "laplace"
  if (!identical(integration_route, "laplace")) {
    .gllvmTMB_check_integration_fence(integration_route, engine = engine)
    ## `gllvmTMBcontrol()` admits only "laplace" and "va", so anything else here
    ## arrives from a hand-built control list rather than the documented API.
    ## Abort rather than fall through: an unrouted value must never reach the
    ## Laplace assembly and come back looking like the route that was asked for.
    if (!identical(integration_route, "va")) {
      cli::cli_abort(c(
        "{.arg integration} = {.val {integration_route}} is not a routed
         integration method.",
        "i" = "{.fn gllvmTMBcontrol} admits {.val laplace} and {.val va}.",
        ">" = "Use {.code integration = \"laplace\"} (the default)."
      ))
    }
    ## `integration = "va"` falls through to `gllvmTMB_multi_fit()`, which
    ## performs the data-aware fence check and dispatches to the variational
    ## engine. No-silent-fallback holds there too: that branch either returns a
    ## variational fit or aborts, and never builds the Laplace objective.
  }
  ci_method <- match.arg(ci_method)
  ci_defaults <- identical(ci_method, "none") &&
    is.numeric(ci_level) &&
    length(ci_level) == 1L &&
    isTRUE(all.equal(as.numeric(ci_level), 0.95)) &&
    is.numeric(ci_nboot) &&
    length(ci_nboot) == 1L &&
    isTRUE(all.equal(as.numeric(ci_nboot), 200)) &&
    is.numeric(ci_seed) &&
    length(ci_seed) == 1L &&
    isTRUE(all.equal(as.numeric(ci_seed), 0))
  if (!identical(engine, "julia") && !ci_defaults) {
    cli::cli_abort(c(
      "{.arg ci_method}, {.arg ci_level}, {.arg ci_nboot}, and {.arg ci_seed} are currently fit-time controls only for {.code engine = \"julia\"}.",
      "i" = "For native {.code engine = \"tmb\"} fits, fit the model first and call {.fn confint} with the desired method."
    ))
  }

  ## ---- Normalise lambda_constraint element names (B -> unit, W -> unit_obs).
  ## User-facing names match `level` argument naming; legacy `B`/`W` still
  ## accepted with a one-shot soft deprecation message. See
  ## R/normalise-lambda-constraint.R.
  lambda_constraint <- .normalise_lambda_constraint_names(lambda_constraint)

  ## ---- Design 08 Stage 2: traits(...) wide-format pre-pass --------------
  ## When the formula LHS is a `traits(...)` call expression, the user is
  ## supplying wide-format data (one row per individual, one column per
  ## trait). Pivot to long format internally via tidyr::pivot_longer(),
  ## rewrite the LHS to `.y_wide_`, expand compact wide RHS syntax
  ## (`1`, `x`, `latent(1 | g)`) into the long trait-stacked grammar
  ## (`0 + trait`, `(0 + trait):x`, latent(0 + trait | g), ...), and
  ## recurse into gllvmTMB() with the long-format data + formula.
  if (is_traits_lhs(formula)) {
    .call_wide <- match.call()
    rewrite <- rewrite_traits_lhs(
      formula = formula,
      data = data,
      weights = weights,
      eval_env = environment(formula),
      missing = missing
    )
    fit <- gllvmTMB(
      formula = rewrite$formula_long,
      data = rewrite$data_long,
      trait = trait,
      unit = unit,
      unit_obs = unit_obs,
      cluster = cluster,
      cluster2 = cluster2,
      family = family,
      weights = rewrite$weights_long,
      REML = REML,
      mesh = mesh,
      phylo_vcv = phylo_vcv,
      phylo_tree = phylo_tree,
      known_V = known_V,
      lambda_constraint = lambda_constraint,
      Xcoef_fixed = Xcoef_fixed,
      control = control,
      missing = missing,
      impute = impute,
      silent = silent,
      engine = engine,
      ci_method = ci_method,
      ci_level = ci_level,
      ci_nboot = ci_nboot,
      ci_seed = ci_seed,
      site = site,
      species = species
    )
    ## Round-trip metadata: print method shows the wide form by default
    ## for readability; users who want to see the engine-level long form
    ## inspect fit$call_long_format directly.
    fit$call_wide <- .call_wide
    fit$call_long_format <- rewrite$formula_long
    fit$traits_meta <- list(
      trait_cols = rewrite$trait_cols,
      n_dropped = rewrite$n_dropped,
      source_row = rewrite$source_row,
      input_shape = "wide_data_frame"
    )
    return(fit)
  }

  ## ---- Honour deprecated `site = ...` alias for `unit = ...` -------------
  ## The package was originally written for site × species data, so the
  ## between-unit grouping argument was named `site`. The unit × trait
  ## framing makes `unit` the more natural name (rows index *units* —
  ## sites, individuals, species, papers); `site` is now a deprecated
  ## alias that emits a one-shot soft warning and is forwarded to `unit`.
  if (!is.null(site)) {
    if (!missing(unit) && !identical(unit, "site")) {
      cli::cli_abort(
        "Pass either {.arg unit} or {.arg site}, not both. {.arg site} is the deprecated alias."
      )
    }
    cli::cli_inform(
      c(
        "!" = "{.arg site = ...} is a deprecated alias; use {.arg unit = ...} instead.",
        "i" = "{.code gllvmTMB(unit = {.val {site}}, ...)}",
        ">" = "Internally, both names map to the same between-unit grouping factor."
      ),
      .frequency = "once",
      .frequency_id = "gllvmTMB-site-deprecation"
    )
    unit <- site
  }
  ## Engine-internal name remains `site` to avoid touching every line in
  ## the parser / TMB template / extractors. User-facing argument is `unit`.
  site <- unit

  ## ---- Honour deprecated `species = ...` alias for `cluster = ...` -----
  ## The package was originally written for site × species data, so the
  ## third grouping slot was named `species`. The slot is generic — it is
  ## the third grouping factor, which activates phylogenetic random
  ## effects when the column matches `phylo_vcv` rownames or `phylo_tree`
  ## tip labels, and otherwise just provides a regular crossed/nested
  ## third grouping (e.g. `cluster = "population"` for 3-level personality
  ## data). `species` is now a deprecated alias that emits a one-shot
  ## soft warning and is forwarded to `cluster`.
  if (!is.null(species)) {
    if (!missing(cluster) && !identical(cluster, "species")) {
      cli::cli_abort(
        "Pass either {.arg cluster} or {.arg species}, not both. {.arg species} is the deprecated alias."
      )
    }
    cli::cli_inform(
      c(
        "!" = "{.arg species = ...} is a deprecated alias; use {.arg cluster = ...} instead.",
        "i" = "{.code gllvmTMB(cluster = {.val {species}}, ...)}",
        ">" = "Internally, both names map to the same third grouping factor (used for phylogenetic random effects when the column matches phylo_vcv rownames)."
      ),
      .frequency = "once",
      .frequency_id = "gllvmTMB-species-deprecation"
    )
    cluster <- species
  }
  ## Engine-internal name remains `species` to avoid touching every line
  ## in the parser / TMB template / extractors. User-facing argument is
  ## `cluster`.
  species <- cluster

  ## ---- Phase L Stage 2 (2026-05-08): soft-deprecate global phylo args ---
  ## The canonical syntax (Phase L Stage 1) is to pass `tree = ...` /
  ## `vcv = ...` *inside* each phylo_*() keyword in the formula, e.g.
  ## `phylo_latent(species, d = 2, tree = tree)`. The older outer
  ## arguments `phylo_tree =` / `phylo_vcv =` to gllvmTMB() continue to
  ## work for backward compatibility but emit a one-shot soft warning
  ## per session pointing at the in-keyword form. See
  ## docs/design/04-random-effects.md for the current contract.
  if (!is.null(phylo_tree)) {
    cli::cli_inform(
      c(
        "!" = "{.arg phylo_tree = ...} as a global argument to {.fun gllvmTMB} is deprecated.",
        "i" = "Pass {.code tree = ...} inside the phylo_*() keyword instead, e.g. {.code phylo_latent(species, d = 2, tree = tree)}.",
        ">" = "The legacy global path still works; the in-keyword syntax avoids silent index/order mismatch."
      ),
      .frequency = "once",
      .frequency_id = "gllvmTMB-phylo_tree-global-deprecation"
    )
  }
  if (!is.null(phylo_vcv)) {
    cli::cli_inform(
      c(
        "!" = "{.arg phylo_vcv = ...} as a global argument to {.fun gllvmTMB} is deprecated.",
        "i" = "Pass {.code vcv = ...} inside the phylo_*() keyword instead, e.g. {.code phylo_scalar(species, vcv = Cphy)}.",
        ">" = "Prefer {.code tree = ...} where you have a phylo object: it triggers the sparse-A^{-1} path (~24x faster at n_species = 1000)."
      ),
      .frequency = "once",
      .frequency_id = "gllvmTMB-phylo_vcv-global-deprecation"
    )
  }
  ## `unit_obs` is the user's chosen within-unit (replicate) grouping
  ## column. The engine uses whatever name the user passed (default
  ## "site_species" for the legacy site × species data layout). If the
  ## column doesn't exist and `unit_obs` is the default, the engine
  ## will synthesise it from `unit` × `species` further down.
  if (!identical(unit_obs, "site_species") && !unit_obs %in% names(data)) {
    cli::cli_abort(c(
      "{.arg unit_obs = {.val {unit_obs}}} is not a column in {.arg data}.",
      "i" = "If you don't have a within-unit replicate column, omit {.arg unit_obs}; the engine will synthesise the default {.field site_species} from {.arg unit} and {.arg species}."
    ))
  }

  ## ---- Validate input ----------------------------------------------------
  assertthat::assert_that(is.data.frame(data))
  for (col in c(trait, site)) {
    assertthat::assert_that(
      col %in% names(data),
      msg = sprintf("Column %s not found in data", col)
    )
  }
  if (!is.factor(data[[trait]])) {
    data[[trait]] <- factor(data[[trait]])
  }
  if (!is.factor(data[[site]])) {
    data[[site]] <- factor(data[[site]])
  }
  if (species %in% names(data)) {
    if (!is.factor(data[[species]])) data[[species]] <- factor(data[[species]])
  } else {
    ## site-level data (e.g. Stage 6 stage-2): synthesise a species column
    ## so downstream code paths still have the column to reference, but it
    ## carries no information.
    data[[species]] <- factor(rep("placeholder", nrow(data)))
  }

  ## A within-unit grouping factor is needed for W-tier terms. The
  ## column name is whatever the user passed via `unit_obs` (default
  ## "site_species"). If the user accepted the default and the column
  ## isn't there, synthesise it from unit × species.
  if (!unit_obs %in% names(data)) {
    if (identical(unit_obs, "site_species")) {
      data$site_species <- factor(paste(
        data[[site]],
        data[[species]],
        sep = "_"
      ))
    }
    ## else: the user passed a custom name we already validated above,
    ## so this branch is unreachable for non-default `unit_obs`.
  }
  if (!is.factor(data[[unit_obs]])) {
    data[[unit_obs]] <- factor(data[[unit_obs]])
  }

  ## ---- Multinomial response expansion (Design 83) ----------------------
  ## Expand a multinomial() response into K-1 category-contrast pseudo-trait
  ## rows BEFORE desugar/parse so the ordinary trait grammar builds the
  ## per-category fixed-effect design. No-op for non-multinomial families.
  .mn_expand <- expand_multinomial_response(formula, data, family, trait_col = trait)
  data   <- .mn_expand$data
  family <- .mn_expand$family

  ## ---- Desugar brms-style sugar (phylo / gr / meta) ---------------------
  formula <- desugar_brms_sugar(formula, trait_col = trait)

  ## ---- Detect covariance-structure terms (Stages 2-4) --------------------
  has_covstruct <- detect_covstruct_terms(formula)
  unsupported <- setdiff(
    has_covstruct,
    c(
      "rr",
      "diag",
      "propto",
      "equalto",
      "spde",
      "phylo_rr",
      "phylo_slope",
      "re_int"
    )
  )
  if (length(unsupported) > 0) {
    cli::cli_abort(c(
      "Covariance-structure terms not yet supported:",
      "x" = "Found {.fn {unsupported}} in formula.",
      "i" = "{.fn exp}/{.fn gau}/{.fn ar1}/{.fn ou}/{.fn cs}/{.fn toep}/{.fn us} are not in scope; use {.fn spde} for fast spatial fields."
    ))
  }
  ## A formula with no covstruct keyword still routes through the
  ## multivariate engine (parsed has empty re_int / rr / diag / spde
  ## blocks). Earlier versions dispatched these to sdmTMB() with
  ## spatial = "off"; that path is removed in 0.2.0 because the
  ## single-response sdmTMB() engine is no longer bundled.
  parsed <- parse_multi_formula(formula)
  ## ---- Phase 2a: validate mi() BEFORE any model.frame on parsed$fixed ----
  ## drop_missing_response_rows() (below) builds a model.frame on parsed$fixed.
  ## For an invalid mi() term (e.g. mi(log(x)), mi(x):z) the parser leaves the
  ## expression verbatim in parsed$fixed, so model.frame would fail with an
  ## opaque "could not find function mi" before the missing-predictor guards
  ## run. gll_prepare_mi_setup is data-free; running it here fires the precise
  ## loud guards first. The result is recomputed (cheaply) inside the fit.
  invisible(gll_prepare_mi_setup(parsed$mi_rhs, impute, missing))
  ## Snapshot the pre-drop data so the fit can report original-row accounting
  ## (fit$data_original) regardless of the response mode.
  data_original <- data
  observed_response <- drop_missing_response_rows(
    fixed_formula = parsed$fixed,
    data = data,
    weights = weights,
    missing = missing
  )
  data <- observed_response$data
  weights <- observed_response$weights
  weights <- normalise_weights(
    weights = weights,
    response_shape = "long",
    n_obs = nrow(data)
  )
  ## ---- engine = "julia": route to the GLLVM.jl bridge ---------------------
  ## `parsed` already reflects the desugared user grammar, so the Julia path
  ## interprets latent/dep/indep/unique exactly as the TMB engine does. The
  ## dispatch maps the unconstrained-ordination core and errors loudly on
  ## anything the bridge does not yet cover (R/julia-bridge.R).
  if (identical(engine, "julia")) {
    ## The bridge marshals `parsed$fixed` only, and the offset is deliberately
    ## held out of that formula. Passing an offset through would therefore
    ## drop it from the whole fit with no error -- the silent-offset failure
    ## (#807) one level earlier in the pipeline -- so refuse instead.
    if (!is.null(parsed$offset_expr))
      cli::cli_abort(c(
        "{.code engine = \"julia\"} does not support {.fn offset} terms.",
        "i" = "The GLLVM.jl bridge has no offset in its linear predictor, so the term would be dropped from the fit rather than applied.",
        ">" = "Use the default {.code engine = \"tmb\"} for a model with an offset."
      ))
    return(.gllvmTMB_julia_dispatch(
      parsed         = parsed,
      data           = data,
      trait          = trait,
      unit_internal  = site,
      family         = family,
      weights        = weights,
      REML           = REML,
      Xcoef_fixed    = Xcoef_fixed,
      ci_method      = ci_method,
      ci_level       = ci_level,
      ci_nboot       = ci_nboot,
      ci_seed        = ci_seed,
      call           = match.call()
    ))
  }
  fit_once <- function(.control) gllvmTMB_multi_fit(
    parsed,
    data,
    trait = trait,
    site = site,
    species = species,
    cluster2 = cluster2,
    family = family,
    weights = weights,
    REML = REML,
    phylo_vcv = phylo_vcv,
    phylo_tree = phylo_tree,
    known_V = known_V,
    mesh = mesh,
    lambda_constraint = lambda_constraint,
    Xcoef_fixed = Xcoef_fixed,
    control = .control,
    silent = silent,
    unit_obs = unit_obs,
    impute = impute,
    missing = missing,
    is_y_observed = observed_response$is_y_observed,
    missing_meta = list(
      response = missing$response,
      predictor = missing$predictor,
      engine = missing$engine,
      original_row = observed_response$original_row,
      n_missing_response = observed_response$n_missing_response,
      data_original = data_original
    )
  )
  .fit <- if (.gllvmTMB_aghq_auto_requested(control)) {
    .gllvmTMB_fit_aghq_auto_ridge(fit_once, control)
  } else {
    fit_once(control)
  }
  ## Attach multinomial category metadata (baseline label + category order) so
  ## predict(type = "response") can reconstruct per-category softmax
  ## probabilities from the K-1 pseudo-trait rows.
  if (isTRUE(.mn_expand$expanded)) {
    .fit$multinomial_meta <- .mn_expand[c("K", "categories", "baseline")]
  }
  ## The variational route is built inside gllvmTMB_multi_fit(), which cannot
  ## see the user's call. Attach it here, where match.call() is the call the
  ## user actually wrote, so print() can show it.
  if (inherits(.fit, "gllvmTMB_va")) {
    .fit$call <- match.call()
  }
  ## WARN ON AN IMPLAUSIBLE LOADING SCALE -- because the failure is COMMON and SILENT.
  ##
  ## Measured, 12,000 fits, binomial p=6 q=2 (docs/dev-log/audits/
  ## 2026-07-31-campaign-stage1-verified.md): under plain defaults the fitted loading
  ## norm exceeds twice the truth in 98-99% of fits at sigma_lambda = 3 across every
  ## n, and 49% at n = 100 even at sigma_lambda = 1. That is the common case, not an
  ## edge case -- and the fit reports `convergence = 0` with a positive-definite
  ## Hessian and no message, so a user has NO signal unless one is given.
  ##
  ## This SURFACES the detection that already exists in
  ## `.gllvmTMB_binomial_prevalence_loading_row()` rather than inventing a second
  ## rule. Deliberately: a new absolute constant here would be another instance of
  ## the #857 scale-dependent-constant class, and the existing thresholds at least
  ## have a link-scale rationale (a logit loading IS the trait's latent SD in link
  ## units, so 6 saturates) and are already documented and tunable via
  ## `gllvmTMB_diagnose()`.
  ##
  ## It WARNS and does not fix. The remedy has a measured failure regime of its
  ## own, and a fix users trust that silently fails is worse than no fix.
  ##
  ## That regime is NARROW, and an earlier version of this comment stated it in a
  ## way that was wrong twice (corrected 2026-08-02). It read: "`aghq_ridge = 2`
  ## still runs away in 67% of fits at n = 1600, sigma_lambda = 3; see #847".
  ##   (a) WRONG ARM. #847's own table gives `laplace_ridge` 67% and `aghq_ridge`
  ##       0% at that cell -- same tau = 2, same DGP, same seeds, opposite
  ##       outcome. The 67% belongs to the ridge on the LAPLACE path.
  ##   (b) NO REGIME. It was quoted as a property of the ridge. It is not.
  ##       Reproduced 2026-08-02 (720 fits, 30 seeds/cell, Totoro) using #847's
  ##       own statistic, median ||Lambda_hat||_F / ||Lambda||_F, "runaway" being
  ##       that ratio > 2:
  ##
  ##         binomial-LOGIT, sigma_lambda = 3, ridge:
  ##           p = 6 : n=100 0.0%/0.671 | n=400 3.3%/1.252 | n=1600 53.3%/2.087
  ##                   (#847: 0%/0.666  |       1%/1.216   |        67%/2.185)
  ##           p = 12: 0% at EVERY n (median ratio 0.708 / 0.896 / 1.081)
  ##         binomial-PROBIT and ordinal-PROBIT, same arm, 3600 fits: 0% at the
  ##           n=1600 / sigma_lambda=3 cell under BOTH that criterion and
  ##           rel_frob > 10 (median ratio 0.959).
  ##
  ##       So the failure needs LOGIT and small p TOGETHER. Outside that corner
  ##       the ridge was strongly protective in every cell measured -- e.g.
  ##       55.2% -> 0.2% runaway at n = 60 on the probit grid. Do not cite the
  ##       67% without its regime, and do not read it as "the ridge is unsafe".
  ##
  ## Scoped to binomial because that is the family the 12,000 fits measured.
  if (!identical(control$warn_runaway, FALSE)) {
    .rw <- tryCatch(
      .gllvmTMB_binomial_prevalence_loading_row(.fit),
      error = function(e) NULL
    )
    if (!is.null(.rw) && identical(as.character(.rw$status), "WARN")) {
      ## Surface the check's OWN message/action verbatim rather than writing a
      ## second copy here. Two reasons: the wording is already reviewed and shipped
      ## via `gllvmTMB_diagnose()`, and a second copy would drift from the first the
      ## moment either is edited.
      cli::cli_warn(c(
        "This fit shows a runaway trait loading; {.emph treat it as unusable until checked}.",
        "*" = "{as.character(.rw$value)}",
        "i" = "{as.character(.rw$message)}",
        ">" = "{as.character(.rw$action)}",
        ">" = "Full check: {.run gllvmTMB_diagnose(fit)}. Silence this with \\
               {.code gllvmTMBcontrol(warn_runaway = FALSE)}."
      ), .frequency = "once", .frequency_id = "gllvmTMB-loading-runaway")
    }
  }
  .fit
}

## Multinomial (baseline-category logit) response expansion (Design 83).
## A multinomial() response over K unordered categories is expanded, BEFORE
## desugar/parse, into K-1 contiguous "category-contrast" pseudo-trait rows per
## observation: pseudo-trait `<trait>:<cat_k>` for k = 2..K, response set to the
## 0/1 indicator "observed category == this contrast", and a per-observation
## `.multinom_group_` id (0-based, contiguous). The ordinary
## `0 + trait + (0 + trait):x` grammar then builds the (K-1) per-category
## baseline-category logits, and the softmax likelihood (fid 16) is evaluated
## once per observation-group in the TMB engine. Tier 1: fixed-effects only.
expand_multinomial_response <- function(formula, data, family, trait_col) {
  ## A single family object is itself a list, so test the class FIRST; only a
  ## bare list-of-families (mixed-family API) is treated as a list.
  fams <- if (inherits(family, "family")) list(family)
          else if (is.list(family)) family
          else list(family)
  fam_is_mn <- vapply(fams, function(f) {
    if (inherits(f, "family")) identical(f$family, "multinomial")
    else identical(as.character(f)[1L], "multinomial")
  }, logical(1))
  if (!any(fam_is_mn)) {
    return(list(data = data, family = family, expanded = FALSE))
  }
  ## Idempotency / pre-expanded guard: if the data already carries the
  ## multinomial expansion columns (.multinom_group_ / .multinom_L_), treat it
  ## as already expanded and pass through unchanged. This is the entry point
  ## for a multinomial trait that lives INSIDE a multi-trait long dataset
  ## (item 2a-ii cross-family): the caller supplies the expanded long frame
  ## directly, and the family list (with its family_var) already tags the
  ## K-1 pseudo-trait rows as multinomial.
  if (".multinom_group_" %in% names(data)) {
    return(list(data = data, family = family, expanded = TRUE))
  }
  if (sum(fam_is_mn) > 1L) {
    cli::cli_abort(c(
      "More than one {.fn multinomial} trait in a single fit is not supported yet.",
      "i" = "Fit one categorical response per model (item 2a-ii admits exactly one)."
    ))
  }
  ## A mixed-family list with exactly one multinomial: expand ONLY the
  ## categorical trait's rows (item 2a-ii cross-family). Other-family rows pass
  ## through untouched (tagged .multinom_group_ = -1, .multinom_L_ = 0); each
  ## multinomial observation becomes K-1 baseline-contrast pseudo-trait rows
  ## carrying its 0-based observation id and .multinom_L_ = K-1.
  if (!inherits(family, "family") && is.list(family) && length(family) > 1L) {
    resp <- all.vars(formula[[2L]])
    if (length(resp) != 1L || !(resp %in% names(data))) {
      cli::cli_abort("multinomial(): the response must be a single column on the formula LHS.")
    }
    mn_family <- fams[[which(fam_is_mn)[1L]]]
    requested_baseline <- if (inherits(mn_family, "family")) mn_family$baseline else NULL
    fam_var <- attr(family, "family_var") %||% "family"
    if (!(fam_var %in% names(data))) {
      cli::cli_abort(c(
        "A mixed-family {.code list(...)} needs a {.var {fam_var}} column mapping each row to a family.",
        "i" = "Set {.code attr(family, 'family_var') <- 'colname'} or add a {.var family} column."
      ))
    }
    ## Identify the multinomial family level, matching the fit's family_var ->
    ## list alignment (named lists by name; unnamed lists in family_var-level
    ## order).
    fam_col    <- data[[fam_var]]
    fam_levels <- if (is.factor(fam_col)) levels(fam_col) else sort(unique(as.character(fam_col)))
    fam_names  <- names(fams)
    mn_pos     <- which(fam_is_mn)[1L]
    mn_level   <- if (!is.null(fam_names) && all(nzchar(fam_names))) fam_names[mn_pos] else fam_levels[mn_pos]
    mn_rows    <- which(as.character(fam_col) == as.character(mn_level))
    if (length(mn_rows) == 0L) {
      cli::cli_abort("No rows map to the {.fn multinomial} family level {.val {mn_level}} in {.var {fam_var}}.")
    }
    mn_trait_lvls <- unique(as.character(data[[trait_col]])[mn_rows])
    if (length(mn_trait_lvls) != 1L) {
      cli::cli_abort(c(
        "The {.fn multinomial} family must map to exactly one trait.",
        "i" = "Found trait(s) {paste(mn_trait_lvls, collapse = ', ')} on multinomial rows."
      ))
    }
    mn_trait <- mn_trait_lvls
    if (anyNA(data[[resp]][mn_rows])) {
      cli::cli_abort("multinomial(): missing categorical responses are not supported in this release.")
    }
    yf <- droplevels(if (is.factor(data[[resp]])) data[[resp]][mn_rows]
                     else factor(data[[resp]][mn_rows]))
    if (!is.null(requested_baseline)) {
      requested_baseline <- as.character(requested_baseline)
      if (!(requested_baseline %in% levels(yf))) {
        cli::cli_abort("{.fn multinomial}: baseline {.val {requested_baseline}} is not a category.")
      }
      yf <- stats::relevel(yf, ref = requested_baseline)
    }
    cats <- levels(yf); K <- length(cats)
    if (K < 3L) {
      cli::cli_abort("{.fn multinomial} requires an unordered response with >= 3 categories.")
    }
    L <- K - 1L
    yint <- as.integer(yf)
    other <- data[-mn_rows, , drop = FALSE]
    ## Tag off-family rows (rep() keeps the columns present even if nrow == 0, so
    ## the later rbind never column-mismatches).
    other[[trait_col]] <- as.character(other[[trait_col]])
    other[[".multinom_group_"]] <- rep(-1L, nrow(other))
    other[[".multinom_L_"]]     <- rep(0L, nrow(other))
    n_mn     <- length(mn_rows)
    rep_idx  <- rep(seq_len(n_mn), each = L)
    contrast <- rep(seq_len(L), times = n_mn)
    mn_new <- data[mn_rows[rep_idx], , drop = FALSE]
    mn_new[[trait_col]] <- paste0(mn_trait, ":", cats[contrast + 1L])
    mn_new[[resp]] <- as.numeric(yint[rep_idx] == (contrast + 1L))
    mn_new[[".multinom_group_"]] <- as.integer(rep_idx - 1L)
    mn_new[[".multinom_L_"]]     <- as.integer(L)
    other_lvls <- setdiff(unique(as.character(data[[trait_col]])), mn_trait)
    ps_levels  <- paste0(mn_trait, ":", cats[-1L])
    combined <- rbind(other, mn_new)
    combined[[trait_col]] <- factor(as.character(combined[[trait_col]]),
                                    levels = c(other_lvls, ps_levels))
    rownames(combined) <- NULL
    return(list(data = combined,
                family = family, expanded = TRUE,
                K = K, categories = cats, baseline = cats[1L]))
  }
  ## The user-requested reference category, if any (multinomial(baseline=)).
  mn_family <- fams[[which(fam_is_mn)[1L]]]
  requested_baseline <- if (inherits(mn_family, "family")) mn_family$baseline else NULL
  resp <- all.vars(formula[[2L]])
  if (length(resp) != 1L || !(resp %in% names(data))) {
    cli::cli_abort("multinomial(): the response must be a single categorical variable on the formula LHS.")
  }
  y_raw <- data[[resp]]
  if (anyNA(y_raw)) {
    cli::cli_abort("multinomial(): missing categorical responses are not supported in this release.")
  }
  yf   <- droplevels(if (is.factor(y_raw)) y_raw else factor(y_raw))
  cats <- levels(yf)
  K    <- length(cats)
  if (K < 3L) {
    cli::cli_abort(c(
      "{.fn multinomial} requires an unordered response with >= 3 categories.",
      "i" = "A 2-category response is {.fn binomial}; use {.code family = binomial(link = \"logit\")}."
    ))
  }
  ## Honour multinomial(baseline=): pin the requested category at eta = 0 by
  ## making it the first factor level, so the K-1 contrasts run against it.
  ## Equivalent to relevel()-ing the response before the fit.
  if (!is.null(requested_baseline)) {
    requested_baseline <- as.character(requested_baseline)
    if (length(requested_baseline) != 1L || !(requested_baseline %in% cats)) {
      cli::cli_abort(c(
        "{.fn multinomial}: {.code baseline = {requested_baseline}} is not a category of the response.",
        "i" = "Response categories are {.val {cats}}."
      ))
    }
    yf   <- stats::relevel(yf, ref = requested_baseline)
    cats <- levels(yf)
  }
  yint <- as.integer(yf)                       # observed category 1..K
  L    <- K - 1L
  n    <- nrow(data)
  idx      <- rep(seq_len(n), each = L)        # original-row index per pseudo-row
  contrast <- rep(seq_len(L), times = n)       # 1..L -> categories 2..K
  new <- data[idx, , drop = FALSE]
  orig_trait  <- as.character(data[[trait_col]])[idx]
  orig_levels <- unique(as.character(data[[trait_col]]))
  ps_levels   <- unlist(lapply(orig_levels, function(ol) paste0(ol, ":", cats[-1L])))
  new[[trait_col]] <- factor(paste0(orig_trait, ":", cats[contrast + 1L]),
                             levels = ps_levels)
  new[[resp]] <- as.numeric(yint[idx] == (contrast + 1L))   # 0/1 one-hot indicator
  new[[".multinom_group_"]] <- as.integer(idx - 1L)         # 0-based, contiguous
  new[[".multinom_L_"]]     <- as.integer(L)                # K-1, per multinomial row
  rownames(new) <- NULL
  list(data = new, family = multinomial(baseline = requested_baseline),
       expanded = TRUE, K = K, categories = cats, baseline = cats[1L])
}

drop_missing_response_rows <- function(fixed_formula, data, weights = NULL,
                                       missing = miss_control()) {
  mf <- stats::model.frame(
    fixed_formula,
    data = data,
    na.action = stats::na.pass
  )
  y_raw <- stats::model.response(mf)
  n_row <- nrow(data)
  if (is.null(y_raw)) {
    return(list(
      data = data, weights = weights, n_dropped = 0L,
      is_y_observed = NULL, original_row = seq_len(n_row),
      n_missing_response = 0L, response = missing$response
    ))
  }

  response_missing <- if (is.matrix(y_raw) || is.data.frame(y_raw)) {
    rowSums(is.na(y_raw)) > 0L
  } else {
    is.na(y_raw)
  }
  response_missing <- as.logical(response_missing)
  response_missing[is.na(response_missing)] <- TRUE
  n_missing_response <- sum(response_missing)

  ## ---- response = "include": keep every row, build the observed mask ------
  ## The masked rows stay in `data` (original-row identity preserved); the
  ## NA response is replaced with a safe sentinel downstream and the C++
  ## likelihood is gated by is_y_observed so the row contributes nothing.
  if (identical(missing$response, "include")) {
    if (!any(!response_missing)) {
      cli::cli_abort(c(
        "All response rows are missing.",
        "i" = "At least one observed response value is required to fit a model."
      ))
    }
    return(list(
      data = data,
      weights = weights,
      n_dropped = 0L,
      is_y_observed = as.integer(!response_missing),
      original_row = seq_len(n_row),
      n_missing_response = n_missing_response,
      response = "include"
    ))
  }

  ## ---- response = "drop" (default): historical complete-case behaviour ----
  n_dropped <- n_missing_response
  if (n_dropped == 0L) {
    return(list(
      data = data, weights = weights, n_dropped = 0L,
      is_y_observed = NULL, original_row = seq_len(n_row),
      n_missing_response = 0L, response = "drop"
    ))
  }

  keep <- !response_missing
  if (!any(keep)) {
    cli::cli_abort(c(
      "All response rows are missing.",
      "i" = "At least one observed response value is required to fit a model."
    ))
  }

  if (!is.null(weights)) {
    w_dim <- dim(weights)
    if (!is.null(w_dim)) {
      cli::cli_abort(c(
        "{.arg weights} must be a length-{nrow(data)} numeric vector in the long-format API.",
        "i" = "Got {.code dim(weights)} = c({paste(w_dim, collapse = ', ')}).",
        "i" = "For per-cell weights aligned with a wide response matrix, use {.fn gllvmTMB_wide}."
      ))
    }
    if (!is.numeric(weights)) {
      cli::cli_abort(c(
        "{.arg weights} must be numeric.",
        "i" = "Got class {.cls {class(weights)[1]}}."
      ))
    }
    if (length(weights) != nrow(data)) {
      cli::cli_abort(c(
        "{.arg weights} must be a length-{nrow(data)} numeric vector in the long-format API.",
        "i" = "Got length {length(weights)}."
      ))
    }
    weights <- as.numeric(weights)[keep]
  }

  original_row <- which(keep)
  data <- data[keep, , drop = FALSE]
  cli::cli_inform(c(
    "i" = "{.fn gllvmTMB}: dropped {n_dropped} row{?s} with {.code NA} response."
  ))

  list(
    data = data,
    weights = weights,
    n_dropped = n_dropped,
    is_y_observed = NULL,
    original_row = original_row,
    n_missing_response = n_missing_response,
    response = "drop"
  )
}


#' Control parameters for [gllvmTMB()]
#'
#' @param d_B,d_W Latent dimensions for the between-unit and within-unit
#'   reduced-rank components. Set to a positive integer to enable
#'   `latent()` / `indep()` covariance structures at the corresponding tier.
#' @param spde_mode `"per_trait"` (default) fits one independent SPDE field
#'   per trait when a `spatial()` term is present; `"shared"` fits one shared
#'   SPDE field with trait-specific scalar loadings.
#' @param n_init Number of random-start replicates. Reduced-rank GLLVMs
#'   are often multimodal because the latent-factor likelihood has many
#'   equivalent local maxima; running several restarts with different
#'   starting values and keeping the fit with the lowest `-logLik`
#'   reduces the risk of settling on a suboptimal solution. Default
#'   1 (single fit). Increase to 5–10 for two-level rr models.
#' @param optimizer One of `"nlminb"` (default) or `"optim"`. Use the
#'   latter together with `optArgs` for finicky two-level rr fits.
#' @param optArgs A list of arguments passed to the optimiser. For
#'   `optim` the most useful is `list(method = "BFGS")`.
#' @param init_jitter Standard deviation of N(0, sigma) jitter applied to
#'   the starting parameter vector across the `n_init` restarts.
#'   Default 0.3.
#' @param init_strategy One of `"default"` (current behaviour) or
#'   `"single_trait_warmup"`. The warmup option fits an intercept-only univariate GLM
#'   per trait — with that trait's family — and seeds the matching
#'   `log_phi_*` entries before `MakeADFun()`. Recommended for count
#'   families (especially `nbinom2`) where the default initialisation
#'   can leave the optimiser walking the
#'   \eqn{(\psi_t, \phi_t)} trade-off ridge. No effect for traits whose
#'   family doesn't carry a `phi` parameter (Gaussian, Poisson, binomial).
#'   Default `"default"`.
#' @param start_method Optional reduced-rank starting-value method, modelled
#'   after `glmmTMB::glmmTMBControl(start_method = ...)` but extended for
#'   two-level gllvmTMB models. Use `list(method = "res", jitter.sd = 0.2)`
#'   to seed `latent()` loadings and latent scores from a reduced-rank
#'   decomposition of fixed-effect residuals. Use `list(method = "indep")`
#'   to first fit the matching independent diagonal GLMM/GLLVM and
#'   copy its estimated fixed effects, per-trait variance starts, and random
#'   effects into the full latent covariance fit. `jitter.sd` adds Normal jitter
#'   to residual-start latent scores. Default
#'   `list(method = NULL, jitter.sd = 0)` keeps the historical starts.
#' @param start_from Optional fitted `gllvmTMB` object, usually a simpler
#'   model such as one `latent()` tier or an independent diagonal model
#'   (`indep()`). Any estimated TMB
#'   parameters with shapes matching the current model are copied into the
#'   starting parameter list before optimisation.
#'   This implements the "fit simpler, then use it as starting values"
#'   workflow recommended for complex reduced-rank models.
#' @param se Logical; if `TRUE`, compute `TMB::sdreport()` after
#'   optimisation so Wald standard errors and Hessian diagnostics are
#'   available. If `FALSE`, skip standard-error calculation and return the
#'   point-estimate fit with `sd_report = NULL` and a diagnostic note. This
#'   is useful for hard models where the point estimate is needed and
#'   uncertainty will be obtained by bootstrap or profile methods. Default
#'   `TRUE`.
#' @param verbose If `TRUE`, prints a one-line summary per restart so
#'   the user can see which seed led to the winning fit. Default
#'   `FALSE`.
#' @param integration Which method evaluates the latent-variable integral.
#'   `"laplace"` (default) is the Laplace approximation and is the **only**
#'   route that yields a marginal likelihood, so it is the only one for which
#'   [logLik()], [AIC()], [BIC()] and likelihood-ratio tests are defined.
#'
#'   `"va"` selects an opt-in **research** route whose objective is an evidence
#'   lower bound, not a marginal likelihood. It reports no calibrated
#'   uncertainty: no standard errors, no confidence intervals, and no coverage
#'   claim. A bound must not be compared across ranks or models, so it cannot
#'   be used for model or rank selection.
#'
#'   It is admitted only inside the region for which evidence exists —
#'   `latent(..., unique = FALSE)`, binomial-logit or Poisson-log, `d` up to
#'   2, up to 80 responses, at least 100 units, and the native TMB engine — and
#'   requesting it outside that region is an **error**, not a warning. The `d`
#'   limit is where a pre-registered recovery gate actually passed: `d = 4` was
#'   measured and refused, because with few responses the planted axes collapse
#'   far more often than the gate's tolerance allows.
#'   It cannot be combined with `aghq`, which is an alternative evaluation of
#'   the same integral rather than an additional layer.
#'
#'   Offering this value advertises nothing about its accuracy.
#'
#'   `"va"` returns an object of class `"gllvmTMB_va"` (see
#'   [gllvmTMB_va-methods]) rather than an ordinary fit, so that every method
#'   which would treat its objective as a likelihood fails loudly instead of
#'   returning a number. Because the engine runs its own multi-start and
#'   optimiser policy, the search settings of [gllvmTMBcontrol()] — `n_init`,
#'   `optimizer`, `optArgs`, `start_from`, `init_*` and `se` — have no effect
#'   on this route. Any model structure the route cannot represent (a latent
#'   term away from the unit grouping, a constrained ordination, an offset,
#'   weights, `REML`, `lambda_constraint`, `Xcoef_fixed`, or a further random
#'   effect) is an **error**, never a silent omission.
#'
#'   There is no `"eva"` value. The EVA engine exists in this package and is
#'   reachable as a research route, but it is not wired to [gllvmTMB()], and an
#'   argument value that could only ever raise an error would advertise a
#'   capability the package does not have. Its own measurements are the reason
#'   it is not a candidate here: EVA delivers valid inference for the
#'   regression coefficients but not for `Lambda Lambda'`, which is the
#'   between-response covariance this package exists to estimate.
#' @param aghq Adaptive Gauss-Hermite quadrature for the between-unit latent
#'   block. `FALSE` (default) fits by Laplace approximation. A positive integer
#'   requests that many quadrature nodes. `"auto"` lets the package decide, and
#'   it declines to Laplace whenever the model is ineligible or the expected
#'   gain does not justify the cost. **Opt-in and experimental**: no capability
#'   claim is made for quadrature-fitted models, and eligibility is narrow — the
#'   random part must be a single ordinary `latent()` block on the unit tier.
#' @param aghq_iter_cap Optimiser iteration budget for the first adaptation
#'   pass. Default `1L`. Later passes escalate when continuation is enabled.
#' @param aghq_n_adapt Maximum number of adaptation passes. Default `400L`.
#' @param aghq_ridge Ridge penalty on the loadings, as the scale `tau`;
#'   `Inf` disables it. Default `2`. Naming a numeric value explicitly also
#'   makes the `Laplace + ridge` control reachable without quadrature.
#'   `"auto"` is an **opt-in experimental** route for pure single-trial
#'   Bernoulli models with one ordinary unit-tier `latent()` block. It uses an
#'   unpenalised 9-node multi-start AGHQ pilot, then
#'   `tau = min(6, max(1, ||Lambda_pilot||_F / sqrt(pq)))`. If the pilot or
#'   scale-aware final fit is unusable, the returned fit transparently falls
#'   back to the shipped `tau = 2` route; inspect
#'   `fit$aghq$ridge_auto`. Evidence supports failure/runaway avoidance in this
#'   scope, not a broad loading-accuracy improvement. The measured grid used a
#'   logit link with `p = 6`, `q = 2`, and `n = 100`, `400`, or `1600`; other
#'   links and dimensions are extrapolations (validation row MIS-36). The
#'   `"auto"` route always uses 9-node multi-start AGHQ for both pilot and final
#'   fits; a conflicting node/start control is replaced with a warning, while an
#'   explicit `aghq = FALSE` is incompatible.
#' @param warn_runaway If `TRUE` (default), warn once per session when a
#'   binomial latent-variable fit triggers the package's existing runaway-loading
#'   diagnostic. Set `FALSE` to silence the fit-time warning; the diagnostic
#'   remains available through [gllvmTMB_diagnose()].
#' @param aghq_continuation If `TRUE` (default), the adaptation loop may raise
#'   `aghq_iter_cap` across passes. `FALSE` pins the cap and disables escalation.
#' @param aghq_shift_tol,aghq_grad_tol,aghq_f_tol Convergence tolerances for the
#'   adaptation loop: the quadrature-point shift, the gradient at the adaptation
#'   point, and the change in objective. Defaults `1e-4`, `1e-4`, `1e-9`.
#' @param aghq_grad_tol_rel Relative gradient tolerance, tested as
#'   `max|grad| / max(1, |objective|)`. Default `1e-6`. The gradient of a
#'   likelihood summed over many observations grows with the sample, so the
#'   absolute `aghq_grad_tol` on its own becomes unreachable at scale. The two are
#'   combined with `OR`, so this can only ever admit more fits as converged, never
#'   fewer; set it to `0` to test the absolute tolerance only. Read
#'   `fit$aghq$converged` for the verdict — **not** `fit$opt$convergence`, which
#'   on the quadrature path records the optimiser's per-pass iteration cap and so
#'   reports a limit even on a healthy fit.
#' @param aghq_multistart If `TRUE` (default), the quadrature is run from two
#'   starting points — the Laplace optimum and a data-driven alternative that uses
#'   no knowledge of the truth — and the fit with the better final objective is
#'   kept. `FALSE` uses the Laplace warm start only, reproducing the behaviour of
#'   earlier versions. The extra start costs one additional adaptation run, and
#'   exists because the Laplace optimum is sometimes itself a runaway that the
#'   quadrature would otherwise inherit.
#' @param aghq_escalate_patience Number of accepted passes before the iteration
#'   cap is escalated. Default `3L`.
#' @param aghq_rho_min Minimum trust-region-style acceptance ratio for a pass.
#'   Default `1/64`.
#' @param allow_nongaussian_reml Permit `REML = TRUE` for non-Gaussian families.
#'   Default `FALSE`; the restricted likelihood is defined by a Gaussian
#'   marginalisation, so this is an escape hatch, not an endorsement.
#' @param ... Reserved for future use. Currently ignored with a warning.
#'
#' @return A `gllvmTMBcontrol` list.
#'
#' @details
#' **Recommended workflow for two-level latent models.** Reduced-rank
#' likelihoods are notoriously multimodal in two-level fits like
#' `value ~ 0 + trait + latent(0+trait|ID, d_B) + latent(0+trait|obs_ID, d_W)`.
#' The recommended workflow is:
#'
#' 1. Run several restarts (`n_init = 5` to `10`) and keep the one
#'    with the lowest `-logLik`.
#' 2. If that fails to converge cleanly, switch the optimiser to
#'    `optim` with `BFGS`:
#'    `gllvmTMBcontrol(optimizer = "optim", optArgs = list(method = "BFGS"))`.
#' 3. `start_method = list(method = "res", jitter.sd = 0.2)` is
#'    **soft-deprecated as of 0.6.0** and warns once per session. It still
#'    fits: it decomposes the fixed-effect residual matrix into starting
#'    values for \eqn{\Lambda} and the latent scores. Do not reach for it.
#'
#'    It was retired on measurement. Across 89 simulated fits — Gaussian,
#'    Poisson and negative-binomial, `d = 1` to `3`, three and five traits —
#'    it was **never materially better** than the default start (its three
#'    best margins were 0.07, 0.29 and 0.66 log-likelihood units) and was
#'    materially worse eight times, once by 14.6 units. At `d >= 2` it made
#'    no difference at all. Every failure reported `convergence == 0` and a
#'    positive-definite Hessian on both sides, so the worse fit was silent,
#'    and restarts did not detect it: in one such fit all five `n_init = 5`
#'    restarts returned the same worse optimum.
#'
#'    If you use it anyway, compare `fit$opt$objective` against a
#'    default-start fit and keep the lower value.
#' 4. For Gaussian two-level models, prefer
#'    `start_method = list(method = "indep")` or manually fit a simpler
#'    model and pass it through `start_from = simpler_fit`. This is a GLMM
#'    warm start rather than a fixed-effect-only GLM residual start.
#'
#' @examples
#' # gllvmTMBcontrol() is a pure-R constructor: it builds and validates a
#' # control list without fitting anything.
#' gllvmTMBcontrol()                                  # historical defaults
#'
#' # Multi-start to guard against multimodal reduced-rank likelihoods, with
#' # jitter on the starting parameter vector across restarts.
#' gllvmTMBcontrol(n_init = 3, init_jitter = 0.2)
#'
#' # Switch the optimiser to optim + BFGS for finicky two-level rr fits.
#' gllvmTMBcontrol(optimizer = "optim", optArgs = list(method = "BFGS"))
#'
#' # Experimental, opt-in scale-aware ridge for the calibrated Bernoulli AGHQ
#' # scope. The route uses the calibrated 9-node multi-start rule.
#' gllvmTMBcontrol(aghq_ridge = "auto")
#'
#' @export
gllvmTMBcontrol <- function(
  d_B = NULL,
  d_W = NULL,
  spde_mode = c("per_trait", "shared"),
  n_init = 1L,
  optimizer = c("nlminb", "optim"),
  optArgs = list(),
  init_jitter = 0.3,
  init_strategy = c("default", "single_trait_warmup"),
  start_method = list(method = NULL, jitter.sd = 0),
  start_from = NULL,
  se = TRUE,
  verbose = FALSE,
  ## Which integration method evaluates the latent-variable integral. "eva" is
  ## deliberately NOT admitted: its engine exists and is reachable as a research
  ## route, but it is not wired to gllvmTMB(), and offering an argument value
  ## that can only ever error would advertise a capability the package does not
  ## have. See the note on the `integration` parameter.
  ## "laplace" is the default and the only route carrying a marginal
  ## likelihood, so it is the only one for which logLik()/AIC()/BIC()/LRT are
  ## defined. "va" and "eva" are OPT-IN research routes whose objective is an
  ## ELBO -- not a marginal likelihood (Design 85 s10) -- with no calibrated
  ## uncertainty. Offering a value here does NOT advertise it: admission to any
  ## user-facing claim is Design 85 s11 Gate 3's to grant, not this argument's.
  integration = c("laplace", "va"),
  aghq = FALSE,
  aghq_iter_cap = 1L,
  aghq_n_adapt = 400L,
  aghq_ridge = 2,
  ## The adaptation loop reads all six of these. They were previously absent
  ## from this signature, so `...` swallowed them with an "ignored" warning and
  ## the engine quietly used its own fallbacks -- a caller who set one had a
  ## misconfigured fit that looked configured. These defaults MUST stay equal to
  ## the `%||%` fallbacks in the loop (R/fit-multi.R:5242-5263).
  aghq_continuation = TRUE,
  aghq_shift_tol = 1e-4,
  aghq_grad_tol = 1e-4,
  ## RELATIVE gradient tolerance, and why it exists (#874).
  ##
  ## `aghq_grad_tol` is ABSOLUTE, and the gradient of a log-likelihood summed over
  ## n x p observations grows with the data. Measured, binomial p=6 q=2: the
  ## max |grad| the loop stops at runs 1.39e-4 -> 2.68e-4 -> 6.72e-4 for
  ## n = 100 -> 400 -> 1600 (step ratios 1.93 and 2.51 against an n-ratio of 4).
  ## Against a fixed 1e-4 that made convergence UNREACHABLE at scale: 0% of fits
  ## converged at n = 400 and n = 1600, in gaussian, poisson AND binomial -- i.e.
  ## in exactly the large-n regime AGHQ is for. Gaussian makes it sharpest: AGHQ
  ## returns the Laplace optimum BIT-FOR-BIT (par_shift = 0), Laplace certifies
  ## that point converged, and AGHQ did not.
  ##
  ## The test is an OR -- absolute OR relative, relative being
  ## max|grad| / max(1, |F|). Keeping the absolute leg means nothing that
  ## converged before stops converging; the relative leg only ever ADDS
  ## convergent cases. Set `aghq_grad_tol_rel = 0` for the old absolute-only rule.
  aghq_grad_tol_rel = 1e-6,
  ## READ at R/fit-multi.R but never PRODUCED here, so `control$aghq_multistart`
  ## was always NULL and the documented off-switch was unreachable -- `...` swallowed
  ## it with an "ignored" warning (#871). Same defect class as the six AGHQ fields
  ## noted above and as #844's dead k-ladder. Now load-bearing: it is the opt-out
  ## for the two-start AGHQ search (#843).
  aghq_multistart = TRUE,
  aghq_f_tol = 1e-9,
  aghq_escalate_patience = 3L,
  aghq_rho_min = 1 / 64,
  ## Warn when the fitted loading scale is implausible. Default TRUE: the failure is
  ## common (98-99% of fits at large loadings) and otherwise SILENT. Set FALSE to
  ## suppress; the check itself is always available via `gllvmTMB_diagnose()`.
  warn_runaway = TRUE,
  allow_nongaussian_reml = FALSE,
  ...
) {
  ## Did the CALLER name `aghq_ridge`, or is this the package default? The
  ## distinction is load-bearing and must be captured before any other
  ## statement can touch the promise.
  ##
  ## The ridge was authored inside the AGHQ branch, so `Laplace + ridge` -- the
  ## fair control for every claim that credits the QUADRATURE rather than the
  ## PENALTY -- was unreachable. That coupling is a packaging accident, not a
  ## property of the method: the ridge is a prior on the loadings and has no
  ## dependence on the quadrature whatsoever. Unbundling it makes the control
  ## runnable.
  ##
  ## But `aghq_ridge` DEFAULTS to 2, so applying the default on the Laplace
  ## path would silently penalise every existing fit in the package -- a change
  ## to every user's numbers that touches no export and that `R CMD check`
  ## cannot see. So the Laplace-path ridge is opt-in ONLY: it fires when the
  ## caller names `aghq_ridge` and never from the default.
  aghq_ridge_explicit <- !missing(aghq_ridge)
  aghq_explicit <- !missing(aghq)
  aghq_multistart_explicit <- !missing(aghq_multistart)
  spde_mode <- match.arg(spde_mode)
  optimizer <- match.arg(optimizer)
  init_strategy <- match.arg(init_strategy)
  start_method <- .gllvmTMB_normalize_start_method(start_method)
  integration <- match.arg(integration)
  aghq <- .gllvmTMB_normalize_aghq(aghq)
  aghq_ridge <- .gllvmTMB_normalize_aghq_ridge(aghq_ridge)
  if (identical(aghq_ridge, "auto")) {
    if (isTRUE(aghq_explicit) && isFALSE(aghq)) {
      cli::cli_abort(c(
        "{.code aghq_ridge = \"auto\"} cannot be combined with an explicit {.code aghq = FALSE}.",
        "i" = "The scale yardstick is an unpenalised multi-start AGHQ pilot, never a plain Laplace fit.",
        ">" = "Omit {.arg aghq} to use the calibrated 9-node rule, or set {.code aghq = 9}."
      ))
    }
    if (isTRUE(aghq_explicit) && !identical(aghq, 9L)) {
      cli::cli_warn(c(
        "{.code aghq_ridge = \"auto\"} uses the calibrated {.code aghq = 9} final estimator.",
        "i" = "The requested {.arg aghq} setting has been replaced by 9 nodes."
      ))
    }
    if (isTRUE(aghq_multistart_explicit) && !isTRUE(aghq_multistart)) {
      cli::cli_warn(c(
        "{.code aghq_ridge = \"auto\"} uses multi-start AGHQ for both the pilot and final fit.",
        "i" = "The requested {.code aghq_multistart = FALSE} setting has been replaced by {.code TRUE}."
      ))
    }
    aghq <- 9L
    aghq_multistart <- TRUE
  }
  ## AGHQ and the variational routes are alternative evaluations of the SAME
  ## latent integral, not layers. Requesting both is incoherent, and silently
  ## letting one win would hand back a fit that is not the one asked for.
  if (!identical(integration, "laplace") && !isFALSE(aghq)) {
    cli::cli_abort(c(
      "{.arg integration} = {.val {integration}} cannot be combined with {.arg aghq}.",
      "i" = "AGHQ and the variational routes are alternative evaluations of the same latent integral, not layers.",
      ">" = "Set {.code aghq = FALSE}, or use {.code integration = \"laplace\"}."
    ))
  }
  if (!is.logical(se) || length(se) != 1L || is.na(se)) {
    cli::cli_abort("{.arg se} must be a single {.code TRUE} or {.code FALSE} value.")
  }
  if (...length() > 0L) {
    cli::cli_warn(
      "Extra arguments to {.fun gllvmTMBcontrol} are ignored in this version."
    )
  }
  list(
    d_B = d_B,
    d_W = d_W,
    spde_mode = spde_mode,
    integration = integration,
    n_init = as.integer(n_init),
    optimizer = optimizer,
    optArgs = optArgs,
    init_jitter = init_jitter,
    init_strategy = init_strategy,
    start_method = start_method,
    start_from = start_from,
    se = se,
    verbose = verbose,
    aghq = aghq,
    aghq_iter_cap = as.integer(aghq_iter_cap),
    aghq_n_adapt = as.integer(aghq_n_adapt),
    aghq_ridge = aghq_ridge,
    aghq_ridge_explicit = aghq_ridge_explicit,
    aghq_continuation = isTRUE(aghq_continuation),
    aghq_shift_tol = as.numeric(aghq_shift_tol),
    aghq_grad_tol = as.numeric(aghq_grad_tol),
    aghq_grad_tol_rel = as.numeric(aghq_grad_tol_rel),
    aghq_multistart = isTRUE(aghq_multistart),
    aghq_f_tol = as.numeric(aghq_f_tol),
    aghq_escalate_patience = as.integer(aghq_escalate_patience),
    aghq_rho_min = as.numeric(aghq_rho_min),
    warn_runaway = isTRUE(warn_runaway),
    allow_nongaussian_reml = isTRUE(allow_nongaussian_reml)
  )
}

## `aghq` accepts FALSE (Laplace, the current default), "auto" (let the package
## decide), or a positive integer node count. Anything else is a user error and is
## caught here rather than surfacing as a template failure deep inside a fit.
##
## The DEFAULT IS DELIBERATELY `FALSE`, not "auto": the maintainer's decision of
## 2026-07-28 is that AGHQ ships opt-in and Laplace stays the default until the
## head-to-head evidence decides, because flipping it would change every existing
## user's numbers while touching no export and so would be invisible to R CMD check.
## See docs/dev-log/decisions.md. When that evidence lands, this one word is the flip.
.gllvmTMB_normalize_aghq <- function(aghq) {
  if (is.null(aghq) || isFALSE(aghq)) return(FALSE)
  if (is.character(aghq) && length(aghq) == 1L && identical(aghq, "auto")) return("auto")
  if (isTRUE(aghq)) return("auto")
  if (is.numeric(aghq) && length(aghq) == 1L && is.finite(aghq) &&
      aghq >= 1 && aghq == as.integer(aghq)) {
    return(as.integer(aghq))
  }
  cli::cli_abort(c(
    "{.arg aghq} must be {.code FALSE}, {.val auto}, or a single positive integer.",
    "i" = "{.code aghq = FALSE} uses the Laplace approximation (the current default).",
    "i" = "{.code aghq = \"auto\"} lets the package choose the node count.",
    "i" = "{.code aghq = 9} uses a fixed 9-node rule per latent dimension."
  ))
}

#' Missing-data control for [gllvmTMB()]
#'
#' Configures how [gllvmTMB()] treats missing **responses** and missing
#' **predictors**. Pass the result to the `missing =` argument of
#' [gllvmTMB()].
#'
#' @param response How to treat rows whose response value is `NA`.
#'   `"drop"` (default) omits each missing response *cell* before the
#'   likelihood is built. In long format one row is one `(unit, trait)` cell,
#'   and the wide `traits()` route drops the same cells, so a unit keeps every
#'   trait it does have -- this is cell-wise omission, not case-wise deletion.
#'   `"include"`
#'   keeps those rows, builds an observed-response mask (`is_y_observed`), and
#'   contributes nothing to the likelihood for the masked rows -- the
#'   frequentist observed-data likelihood. For the supported routes, the
#'   observed-response likelihood contribution matches the corresponding
#'   observed rows, while cell identity is preserved for [predict_missing()].
#' @param predictor How to treat missing **predictors** (covariates).
#'   `"fail"` (the default): a missing value in the fixed-effect design matrix
#'   is an error, exactly as today. `"model"` treats a missing predictor
#'   declared with `mi(x)` as a latent variable integrated out by the Laplace
#'   approximation, with its covariate model supplied via the `impute =`
#'   argument of [gllvmTMB()]. The current routes fit one modelled predictor
#'   at a time: Gaussian fixed-effect, grouped-intercept, or phylogenetic-
#'   intercept covariate models, plus fixed-effect binary, ordered, and
#'   unordered discrete predictors.
#' @param engine The estimation engine. The supported value is `"laplace"`
#'   (TMB Laplace
#'   approximation). `"em"` (the Gaussian-only EM special case) and `"profile"`
#'   are **reserved names, not yet supported**.
#'
#' @details
#' There is deliberately **no** `estimator` argument in `miss_control()`:
#' estimator choice belongs to [gllvmTMB()]. The default `gllvmTMB()` fit uses
#' ML; `gllvmTMB(REML = TRUE)` is a Gaussian-only pilot. It combines with either
#' missing-response policy -- including `miss_control(response = "include")`,
#' where the restricted likelihood is formed over the observed rows -- but not
#' yet with `mi()` predictor models. There
#' is **no** MI ("multiple imputation") engine here; multiple imputation is a
#' separate workflow.
#'
#' Under the default `miss_control(response = "drop", predictor = "fail",
#' engine = "laplace")` the missing-data layer is an exact no-op: a complete-
#' data fit is byte-identical to a fit built before this layer existed.
#'
#' @return A named list with elements `response`, `predictor`, and `engine`.
#'
#' @seealso [gllvmTMB()] for the `missing =` argument; [gllvmTMBcontrol()] for
#'   optimiser / initialisation control.
#'
#' @export
#' @examples
#' miss_control()                          # defaults: drop / fail / laplace
#' miss_control(response = "include")      # keep missing-response rows (masked)
miss_control <- function(
  response = c("drop", "include"),
  predictor = c("fail", "model"),
  engine = "laplace"
) {
  ## `estimator` is NOT a public v1 argument (design 59 sec.4 / sec.10). Catch
  ## it explicitly via a named check so a user passing it gets a clear error
  ## instead of a silent no-op (the formals above do not include it, but a
  ## caller could still write miss_control(estimator = "REML")).
  call_args <- names(match.call())[-1L]
  if ("estimator" %in% call_args) {
    cli::cli_abort(c(
      "{.arg estimator} is not a {.fn miss_control} argument.",
      "i" = "Use {.code gllvmTMB(REML = TRUE)} for the narrow Gaussian-only REML pilot.",
      "i" = "Remove {.arg estimator} from the {.fn miss_control} call."
    ))
  }

  response <- match.arg(response)
  predictor <- match.arg(predictor)

  ## predictor = "model" engages the mi() latent-covariate grammar (Phase 2a:
  ## one continuous Gaussian missing predictor with a fixed-effect covariate
  ## model). predictor = "fail" (default) keeps the historical hard stop on
  ## missing predictors.

  ## v1 engine surface is "laplace" only. "em"/"profile" are reserved names.
  if (!identical(engine, "laplace")) {
    if (engine %in% c("em", "profile")) {
      cli::cli_abort(c(
        "{.code engine = {.val {engine}}} is a reserved name, not yet supported.",
        "i" = "This version supports {.code engine = \"laplace\"} only."
      ))
    }
    cli::cli_abort(c(
      "Unknown {.arg engine}: {.val {engine}}.",
      "i" = "This version supports {.code engine = \"laplace\"} only ({.val em} / {.val profile} are reserved names)."
    ))
  }

  list(
    response = response,
    predictor = predictor,
    engine = engine
  )
}

.gllvmTMB_normalize_start_method <- function(start_method) {
  if (is.null(start_method)) {
    return(list(method = NULL, jitter.sd = 0))
  }
  if (is.character(start_method) && length(start_method) == 1L) {
    start_method <- list(method = start_method)
  }
  if (!is.list(start_method)) {
    cli::cli_abort("{.arg start_method} must be a list, e.g. {.code list(method = \"res\", jitter.sd = 0.2)}.")
  }

  method <- start_method$method
  if (is.null(method) || length(method) == 0L ||
      (length(method) == 1L && is.na(method))) {
    method <- NULL
  } else {
    if (!is.character(method) || length(method) != 1L) {
      cli::cli_abort("{.arg start_method$method} must be NULL or the string {.val res}.")
    }
    if (!method %in% c("res", "indep")) {
      cli::cli_abort(c(
        "Unknown {.arg start_method$method}: {.val {method}}.",
        "i" = "Currently supported: {.code NULL} (default), {.code \"res\"}, or {.code \"indep\"}."
      ))
    }
    ## `"res"` remains accepted compatibility syntax but warns once per session:
    ## it was measured to be never materially better than the default start and
    ## sometimes much worse, silently. See
    ## `.gllvmTMB_warn_start_method_res_deprecated()` for the evidence.
    if (identical(method, "res")) {
      .gllvmTMB_warn_start_method_res_deprecated()
    }
  }

  jitter.sd <- start_method$jitter.sd %||% 0
  if (!is.numeric(jitter.sd) || length(jitter.sd) != 1L ||
      !is.finite(jitter.sd) || jitter.sd < 0) {
    cli::cli_abort("{.arg start_method$jitter.sd} must be one finite non-negative number.")
  }
  list(method = method, jitter.sd = as.numeric(jitter.sd))
}


#' Detect glmmTMB-style covariance-structure terms in a formula
#'
#' Walks the formula RHS and reports covariance-structure function calls. The
#' glmmTMB spatial names `exp`, `gau`, `ar1`, `ou`, `cs`, `toep`, and `us` are
#' reported only when they look like covariance terms with a bar argument, not
#' when they are ordinary fixed-effect transformations such as `exp(x)`.
#'
#' @param formula A formula.
#' @return Character vector of term names found.
#' @keywords internal
#' @noRd
detect_covstruct_terms <- function(formula) {
  rhs <- formula[[length(formula)]]
  found <- character(0)
  supported_covstruct <- c(
    "rr",
    "diag",
    "propto",
    "equalto",
    "spde",
    "phylo_rr",
    "phylo_slope"
  )
  reserved_bar_covstruct <- c("exp", "gau", "ar1", "ou", "cs", "toep", "us")
  has_bar_call <- function(e) {
    if (!is.call(e)) {
      return(FALSE)
    }
    if (identical(e[[1L]], as.name("|"))) {
      return(TRUE)
    }
    any(vapply(as.list(e)[-1L], has_bar_call, logical(1)))
  }
  walk <- function(e) {
    if (is.call(e)) {
      ## Defensive: only treat `e[[1L]]` as a function name when it is a
      ## plain symbol. Namespaced calls (`pkg::fn` / `pkg:::fn`) — which
      ## can appear inside argument expressions like
      ## `vcv = gllvmTMB:::.pedigree_to_A(ped)` (M2.8 animal-keyword
      ## rewrite) — must not crash this walk.
      head <- e[[1L]]
      fn <- if (is.name(head)) as.character(head) else ""
      if (fn %in% supported_covstruct ||
          (fn %in% reserved_bar_covstruct && has_bar_call(e))) {
        found <<- c(found, fn)
      }
      ## Bar syntax `(... | g)`: detected as the parens wrapping a `|`
      ## call. We label it "re_int" regardless of LHS shape — the actual
      ## dispatch and validation happens in parse_re_int_call().
      if (
        fn == "(" &&
          length(e) == 2L &&
          is.call(e[[2L]]) &&
          identical(e[[2L]][[1L]], as.name("|"))
      ) {
        found <<- c(found, "re_int")
      }
      for (i in seq_along(e)[-1L]) {
        walk(e[[i]])
      }
    }
  }
  walk(rhs)
  unique(found)
}
