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
#' \emph{mode} (scalar / unique / indep / dep / latent):
#'
#' \tabular{llllll}{
#'   \strong{source \\ mode} \tab \strong{scalar} \tab \strong{unique} \tab \strong{indep} \tab \strong{dep} \tab \strong{latent} \cr
#'   \emph{none}    \tab (omit)             \tab [unique()]         \tab [indep()]         \tab [dep()]         \tab [latent()]         \cr
#'   \emph{animal}  \tab [animal_scalar()]  \tab [animal_unique()]  \tab [animal_indep()]  \tab [animal_dep()]  \tab [animal_latent()]  \cr
#'   \emph{phylo}   \tab [phylo_scalar()]   \tab [phylo_unique()]   \tab [phylo_indep()]   \tab [phylo_dep()]   \tab [phylo_latent()]   \cr
#'   \emph{spatial} \tab [spatial_scalar()] \tab [spatial_unique()] \tab [spatial_indep()] \tab [spatial_dep()] \tab [spatial_latent()] \cr
#' }
#'
#' The four "quartet" modes (`unique` / `indep` / `dep` / `latent`)
#' encode covstruct intent under a strict always-paired-vs-always-alone
#' convention:
#'
#' * `latent + unique` (paired) — the **decomposition** mode:
#'   \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi}.
#'   `unique` standalone is also legitimate (e.g. observation-level
#'   random effects), but the canonical pattern is paired with `latent`.
#' * `indep` (alone) — the **marginal-only** mode: each trait gets its
#'   own variance, no cross-trait covariance.
#' * `dep` (alone) — the **full unstructured** mode: \eqn{\boldsymbol\Sigma}
#'   is free with \eqn{T(T+1)/2} parameters via a Cholesky factor.
#'
#' Plus the supporting [phylo_slope()] / [animal_slope()] (random
#' slopes), [meta_V()] (known-V meta-analytic; [meta_known_V()] is a
#' deprecated alias), and the engine-internal `propto()` /
#' `equalto()` covstructs (used by the canonical keywords above; not
#' typically called directly). See `vignette("api-keyword-grid")` for a
#' one-paragraph tour of each cell.
#'
#' @param formula A glmmTMB-style formula, e.g.
#'   `value ~ 0 + trait + (0 + trait):env_temp + (0 + trait):env_precip`.
#'   Fixed effects and any of the 4 x 5 keyword-grid covstructs above are
#'   supported (plus [phylo_slope()], [animal_slope()], and [meta_V()]).
#' @param data A data frame. With an ordinary response LHS such as
#'   `value ~ ...`, `data` is long: one row per `(unit, trait)`
#'   observation, with the trait column named by `trait`. With a
#'   [traits()] LHS, `data` is wide: one row per unit and one column per
#'   response named inside `traits(...)`. Missing response values are
#'   allowed and are dropped before fitting, so other observed traits for
#'   the same unit remain in the likelihood; missing predictor or
#'   design-matrix values still error.
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
#'   `unique(0 + trait | unit_obs)` for the W-tier covariance.
#'   Default `"site_species"` (the conventional name in joint species
#'   distribution modelling; safe for site × species data). For other
#'   domains pass e.g. `unit_obs = "obs"` for behavioural syndromes.
#' @param site (deprecated) alias for `unit`. Kept for backward
#'   compatibility. Use `unit = ...` in new code.
#' @param cluster Name of the column holding the **third grouping**
#'   factor (the "cluster" slot). When the column name matches the
#'   row/column names of `phylo_vcv` (or the tip labels of
#'   `phylo_tree`), this slot also drives the phylogenetic random
#'   effects (`phylo_latent`, `phylo_scalar`, `phylo_unique`,
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
#' @param species (deprecated) alias for `cluster`. Kept for
#'   backward compatibility. Use `cluster = ...` in new code.
#' @param family A `family` object. The multivariate engine
#'   (formulas with `latent()`, `unique()`, etc.) supports `gaussian()`,
#'   `binomial()` (logit / probit / cloglog), `poisson()` (log link),
#'   [ordinal_probit()] (the gllvmTMB-native ordinal threshold family
#'   with sigma_d = 1 fixed exactly; no delta-method approximation),
#'   `lognormal()` (log link), `Gamma(link = "log")`,
#'   `nbinom2()` (NB2 negative binomial; log link),
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
#'   API (see Details). The `nbinom2()` family fits one log-dispersion
#'   parameter per trait (Var = mu + mu^2 / phi). The `tweedie()` family
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
#' @param mesh Optional mesh object from `make_mesh()`. Required when the
#'   formula includes a `spatial()` term; ignored otherwise.
#' @param phylo_tree (legacy global) Optional `ape::phylo` tree. The
#'   **canonical Phase L (May 2026) syntax** is to pass `tree =` inside
#'   each `phylo_*()` keyword (e.g. `phylo_latent(species, d = K, tree =
#'   tree)`); this argument is the older outer-level fallback and is
#'   slated for soft deprecation. When supplied (in either form) the
#'   `phylo_*()` terms build a sparse \eqn{\mathbf{A}^{-1}} over tips + internal
#'   nodes via `MCMCglmm::inverseA(tree)` (Hadfield & Nakagawa 2010,
#'   appendix eqs. 26-29). The result is `~5n` non-zeros for an `n`-tip
#'   tree, vs `n^2` for the dense path. **This is the recommended
#'   path** at any `n_species`; the speedup grows to ~24× at
#'   `n_species = 1000`. Requires the `MCMCglmm` package.
#' @param phylo_vcv (legacy global) Optional tip-only `n_species ×
#'   n_species` phylogenetic correlation matrix. The canonical syntax
#'   is `vcv =` inside each `phylo_*()` keyword. **`r lifecycle::badge("superseded")`** —
#'   prefer `tree =`. The dense path inverts via `Matrix::solve()`,
#'   giving the same MLE as the sparse path but at `O(n^2)` memory and
#'   `O(n^3)` Cholesky cost. Use only when you have a Cphy in hand and
#'   no Newick tree (e.g. comparing against `nlme::corPagel`). See
#'   `dev/design/01-phylo-api-canonical-tree.md` for the full
#'   technical justification.
#' @param known_V Optional list of block-diagonal sampling-error matrices
#'   `V_t`. Used by the `equalto()` two-stage workflow when sampling-error
#'   matrices are available from a prior stage of estimation.
#' @param lambda_constraint Optional list with elements `B` and / or `W`,
#'   each an `n_traits × d` matrix of confirmatory loading constraints
#'   (galamm-style). `NA` entries are estimated; numerical entries are
#'   pinned. Upper-triangle entries are silently ignored — the engine's
#'   lower-triangular parameterisation already fixes those at zero.
#'   Default `NULL` uses the engine's exploratory lower-triangular
#'   convention.
#' @param control Output of `gllvmTMBcontrol()`.
#' @param silent Logical; suppress TMB and gllvmTMB chatter. Default `TRUE`.
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
#' Covariance-structure terms (`latent()`, `unique()`, `propto()`,
#' `equalto()`, `spatial()`) are processed by extending the formula parser
#' and the TMB template.
#'
#' Per the manuscript, when stacking traits one should set
#' `dispformula = ~ 0` so that no implicit residual variance competes
#' with structured `unique(0 + trait | …)` terms. `gllvmTMB()` enforces
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
#' **Missing responses.** `NA` response cells are treated as unobserved
#' unit-trait cells and are dropped before the TMB likelihood is built.
#' This applies to both explicit long-format data and wide
#' `traits(...)` formulas. For `cbind(successes, failures)` binomial
#' responses, a row is dropped when either response component is missing.
#' Observation weights, when supplied, are subset to the retained
#' response rows before validation. This is response-missingness support
#' only: missing predictors, grouping variables, or fixed-effect design
#' values still error because the model cannot construct a design row.
#' This contract is covered by validation-debt register row MIS-21.
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
#' multivariate engine; `type = "poisson-link"` is on the roadmap. Each
#' delta family carries one per-trait dispersion of the *positive*
#' component (no extra Bernoulli dispersion). The response must be
#' non-negative.
#'
#' ## Per-trait residual variance: when does it activate?
#'
#' "Residual" in a mixed-effects model is **scale-relative**: what
#' counts as residual variance shifts as you add levels to the model.
#' In a no-`unique` Gaussian fit, the residual is row-level noise
#' captured by a single shared `sigma_eps`. Once you add a per-row
#' `unique(0 + trait | obs)` term, the *row-level* residual is now T
#' per-trait random-effect variances and `sigma_eps` is auto-suppressed
#' to avoid double-counting. Once you also add `unique(0 + trait | site)`
#' on top, the row-level term remains the residual and the `site`-level
#' term is now an additional, *higher-level* random effect — not a
#' residual at all. The dispatch table below records this explicitly
#' for the configurations the engine supports today.
#'
#' For continuous-family responses (Gaussian, lognormal, Gamma) the
#' engine has one residual scale parameter, `sigma_eps`. By default
#' `sigma_eps` is **estimated as a single shared scalar across all
#' continuous-family rows** — per-trait residual variances only appear
#' if you explicitly add a per-row `unique(...)` (or, when Phase B
#' lands, `indep(...)`) term. The dispatch is automatic:
#'
#' \describe{
#'   \item{No `unique` / `indep`, continuous families present}{One
#'     shared `sigma_eps` across all rows. *Not* per-trait.}
#'   \item{No `unique` / `indep`, no continuous families}{`sigma_eps`
#'     is mapped off; the family's intrinsic dispersion handles the
#'     residual.}
#'   \item{\code{unique(0 + trait | g)} where `g` has fewer levels than
#'     rows (e.g. `g = "site"`)}{`sigma_eps` is still estimated as the
#'     row-level residual; the `unique` term adds a per-trait random
#'     effect at level `g` on top.}
#'   \item{\code{unique(0 + trait | obs)} at the per-row level (one
#'     level per row), continuous families fitted}{`sigma_eps` is
#'     auto-suppressed (mapped off, fixed at a tiny stabiliser); the
#'     T per-trait `unique` random effects *are* the residual. A
#'     one-shot `cli::cli_inform` fires at fit time announcing the
#'     auto-suppression.}
#'   \item{\code{unique(0 + trait | obs)} at the per-row level,
#'     non-Gaussian or mixed-family fit}{Treated as observation-level
#'     random effects (OLRE). For Bernoulli traits the OLRE is
#'     statistically unidentifiable and is mapped off; for hurdle /
#'     delta families a warning is emitted (see "Per-family-aware OLRE
#'     selection" below).}
#'   \item{\code{indep(0 + trait | obs)} at the per-row level (Phase B,
#'     not yet implemented)}{Mathematically equivalent to the per-row
#'     `unique` case; same auto-suppression dispatch.}
#' }
#'
#' Mnemonic: continuous-family `sigma_eps` is the default; per-row
#' `unique` / `indep` replaces it with T per-trait residuals; non-per-row
#' `unique` / `indep` adds a higher-level random effect on top of
#' `sigma_eps`; non-continuous families never carry `sigma_eps`
#' regardless.
#'
#' **Per-family-aware OLRE selection.** When `unique(0 + trait | <unit_obs>)`
#' is at per-row resolution (i.e. one row per `(trait, unit_obs)` cell),
#' the resulting per-trait random effects on the linear predictor are an
#' observation-level random effect (OLRE). The engine now decides per
#' trait what to do with the OLRE variance based on the trait's response
#' family:
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
  family = gaussian(),
  weights = NULL,
  mesh = NULL,
  phylo_vcv = NULL,
  phylo_tree = NULL,
  known_V = NULL,
  lambda_constraint = NULL,
  control = gllvmTMBcontrol(),
  silent = TRUE,
  site = NULL, # deprecated alias for `unit`
  species = NULL
) {
  # deprecated alias for `cluster`

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
      eval_env = environment(formula)
    )
    fit <- gllvmTMB(
      formula = rewrite$formula_long,
      data = rewrite$data_long,
      trait = trait,
      unit = unit,
      unit_obs = unit_obs,
      cluster = cluster,
      family = family,
      weights = rewrite$weights_long,
      mesh = mesh,
      phylo_vcv = phylo_vcv,
      phylo_tree = phylo_tree,
      known_V = known_V,
      lambda_constraint = lambda_constraint,
      control = control,
      silent = silent,
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
      n_dropped = rewrite$n_dropped
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
  ## dev/design/01-phylo-api-canonical-tree.md for the full migration.
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
  observed_response <- drop_missing_response_rows(
    fixed_formula = parsed$fixed,
    data = data,
    weights = weights
  )
  data <- observed_response$data
  weights <- observed_response$weights
  weights <- normalise_weights(
    weights = weights,
    response_shape = "long",
    n_obs = nrow(data)
  )
  gllvmTMB_multi_fit(
    parsed,
    data,
    trait = trait,
    site = site,
    species = species,
    family = family,
    weights = weights,
    phylo_vcv = phylo_vcv,
    phylo_tree = phylo_tree,
    known_V = known_V,
    mesh = mesh,
    lambda_constraint = lambda_constraint,
    control = control,
    silent = silent,
    unit_obs = unit_obs
  )
}

drop_missing_response_rows <- function(fixed_formula, data, weights = NULL) {
  mf <- stats::model.frame(
    fixed_formula,
    data = data,
    na.action = stats::na.pass
  )
  y_raw <- stats::model.response(mf)
  if (is.null(y_raw)) {
    return(list(data = data, weights = weights, n_dropped = 0L))
  }

  response_missing <- if (is.matrix(y_raw) || is.data.frame(y_raw)) {
    rowSums(is.na(y_raw)) > 0L
  } else {
    is.na(y_raw)
  }
  response_missing <- as.logical(response_missing)
  response_missing[is.na(response_missing)] <- TRUE

  n_dropped <- sum(response_missing)
  if (n_dropped == 0L) {
    return(list(data = data, weights = weights, n_dropped = 0L))
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

  data <- data[keep, , drop = FALSE]
  cli::cli_inform(c(
    "i" = "{.fn gllvmTMB}: dropped {n_dropped} row{?s} with {.code NA} response."
  ))

  list(data = data, weights = weights, n_dropped = n_dropped)
}


#' Control parameters for [gllvmTMB()]
#'
#' @param d_B,d_W Latent dimensions for the between-unit and within-unit
#'   reduced-rank components. Set to a positive integer to enable
#'   `latent()` / `unique()` covariance structures at the corresponding tier.
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
#' @param init_jitter Standard deviation of N(0, σ) jitter applied to
#'   the starting parameter vector across the `n_init` restarts.
#'   Default 0.3.
#' @param init_strategy One of `"default"` (current behaviour) or
#'   `"single_trait_warmup"`. The warmup option (Design 48 Mitigation A
#'   for M3.4 boundary regimes) fits an intercept-only univariate GLM
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
#'   to first fit the matching independent `unique()`-only GLMM/GLLVM and
#'   copy its estimated fixed effects, per-trait variance starts, and random
#'   effects into the full latent+unique fit. `jitter.sd` adds Normal jitter
#'   to residual-start latent scores. Default
#'   `list(method = NULL, jitter.sd = 0)` keeps the historical starts.
#' @param start_from Optional fitted `gllvmTMB` object, usually a simpler
#'   model such as one `latent()` tier or an independent `unique()`-only
#'   model. Any estimated TMB parameters with shapes matching the current
#'   model are copied into the starting parameter list before optimisation.
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
#' 3. For factor-analytic models, try
#'    `start_method = list(method = "res", jitter.sd = 0.2)`. This fits
#'    the fixed-effects part first, decomposes the residual matrix into
#'    starting values for \eqn{\Lambda} and the latent scores, and can be
#'    combined with `n_init > 1` to check whether the optimiser repeatedly
#'    reaches the same likelihood basin.
#' 4. For Gaussian two-level models, prefer
#'    `start_method = list(method = "indep")` or manually fit a simpler
#'    model and pass it through `start_from = simpler_fit`. This is a GLMM
#'    warm start rather than a fixed-effect-only GLM residual start.
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
  ...
) {
  spde_mode <- match.arg(spde_mode)
  optimizer <- match.arg(optimizer)
  init_strategy <- match.arg(init_strategy)
  start_method <- .gllvmTMB_normalize_start_method(start_method)
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
    n_init = as.integer(n_init),
    optimizer = optimizer,
    optArgs = optArgs,
    init_jitter = init_jitter,
    init_strategy = init_strategy,
    start_method = start_method,
    start_from = start_from,
    se = se,
    verbose = verbose
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
#' Walks the formula RHS and reports which of `rr`, `diag`, `propto`,
#' `equalto`, `spde`, `exp`, `gau`, `ar1`, `ou`, `cs`, `toep`, `us`
#' appear as function calls. Used by [gllvmTMB()] to decide which
#' Stage's machinery a formula needs.
#'
#' @param formula A formula.
#' @return Character vector of term names found.
#' @keywords internal
#' @noRd
detect_covstruct_terms <- function(formula) {
  rhs <- formula[[length(formula)]]
  found <- character(0)
  walk <- function(e) {
    if (is.call(e)) {
      ## Defensive: only treat `e[[1L]]` as a function name when it is a
      ## plain symbol. Namespaced calls (`pkg::fn` / `pkg:::fn`) — which
      ## can appear inside argument expressions like
      ## `vcv = gllvmTMB:::.pedigree_to_A(ped)` (M2.8 animal-keyword
      ## rewrite) — must not crash this walk.
      head <- e[[1L]]
      fn <- if (is.name(head)) as.character(head) else ""
      if (
        fn %in%
          c(
            "rr",
            "diag",
            "propto",
            "equalto",
            "spde",
            "phylo_rr",
            "phylo_slope",
            "exp",
            "gau",
            "ar1",
            "ou",
            "cs",
            "toep",
            "us"
          )
      ) {
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
