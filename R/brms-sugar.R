## Formula keyword sugar for gllvmTMB.
##
## The package exposes a layer of plain-English formula keywords that
## desugar to the underlying glmmTMB-style covstruct calls. The new
## canonical names match the unit x trait framework directly. The full
## 3 x 5 keyword grid (correlation x mode) is:
##
##                    | scalar          | unique          | latent
##   -----------------+-----------------+-----------------+------------------
##   none             | (no keyword)    | unique()        | latent()
##   phylo            | phylo_scalar()  | phylo_unique()  | phylo_latent()
##   spatial          | spatial_scalar()| spatial_unique()| spatial_latent()
##
## The "clean quartet" for explicit covstruct intent:
##
##   * `latent(...)`        --- shared cross-trait covariance (Sigma_shared = Lambda Lambda^T)
##   * `unique(...)`        --- trait-specific residual paired with `latent()` (Sigma_unique = S)
##   * `indep(...)`         --- per-trait marginal variance, no decomposition (Sigma = diag(sigma^2_t))
##   * `dep(...)`           --- full unstructured cross-trait covariance (Sigma free, PSD via Cholesky)
##
## `indep` is the always-alone canonical for marginal-only fits; `dep` is
## the always-alone canonical for full-unstructured fits. `dep(0+trait|g)`
## is mathematically identical to `latent(0+trait|g, d = n_traits)`
## standalone --- the engine's packed-triangular Lambda at full rank IS
## the Cholesky factor of unstructured Sigma = L L^T. `unique` standalone
## (without `latent`) and `indep` standalone are mathematically identical
## (both produce diag(sigma^2_t)); the keyword distinction is documentary,
## not operational. The hard-enforcement rules are that `indep` (or
## `phylo_indep` / `spatial_indep`) and `dep` (or `phylo_dep` /
## `spatial_dep`) MUST NOT be combined with the matching `latent` (or
## `phylo_latent` / `spatial_latent`) on the same correlation side ---
## the parser raises a `cli::cli_abort()` explaining the
## over-parameterisation. Combining `dep` with `unique` or `indep` on the
## same grouping is also redundant and aborts.
##
## Mapping to engine-internal names:
##
##   CANONICAL (new)                              ENGINE-INTERNAL (old)
##   --------------------------------             ----------------------------
##   latent(0 + trait | g, d = K)                 rr(0 + trait | g, d = K)
##   unique(0 + trait | g)                        diag(0 + trait | g)
##   phylo_latent(species, d = K)                 phylo_rr(species, d = K)
##   phylo_scalar(species)                        phylo(species)
##   phylo_unique(species)                        phylo_rr(species, d = T) +
##                                                lambda_constraint = diag(NA, T)
##   spatial_unique(0 + trait | coords)           spde(0 + trait | coords)
##   spatial_scalar(0 + trait | coords)           spde(0 + trait | coords,
##                                                     common = TRUE)
##                                                (ties log_tau across traits via map)
##   spatial_latent(0 + trait | coords, d = K)    (engine path: spde_lv_k = K)
##   spatial(0 + trait | coords)                  DEPRECATED alias for
##                                                spatial_unique()
##   meta_known_V(value, V = V)                   meta(value, sampling_var = V)
##                                                (still desugars further to
##                                                equalto(...) for the engine)
##
## Spatial-keyword orientation. The canonical orientation for every
## spatial_* keyword is `0 + trait | coords` (LHS = trait factor, RHS =
## the `coords` placeholder), which matches the rest of the keyword grid
## (`latent(0 + trait | g)`, `unique(0 + trait | g)`) and glmmTMB's
## spatial conventions (`gau(0 + trait | pos)`, `exp(0 + trait | pos)`).
## The earlier orientation `coords | trait` is accepted as a deprecated
## alias and emits a one-shot lifecycle warning per session before being
## normalised to the canonical orientation. See the note in
## `?spatial_unique` and `lifecycle::deprecate_warn(when = "0.1.4")` in
## `normalise_spatial_orientation()`.
##
## The old engine-internal names (rr, diag, phylo_rr, phylo, spde,
## meta, gr, propto, equalto) keep working but emit a one-shot soft
## deprecation warning per session, pointing the user at the canonical
## name. Aliases will be dropped at gllvmTMB 1.0 / 0.2 (see NEWS.md).
##
## All of these are *formula markers* -- they are never actually evaluated.
## We define no-op stubs so the formula parser doesn't choke when
## model.frame() walks the AST. See parse_multi_formula().

## ---- One-shot deprecation tracker -------------------------------------
## Issued once per old keyword per R session. Avoids spamming when an
## article (or a user's pasted code) uses the old name throughout.
.gllvmTMB_deprecation_seen <- new.env(parent = emptyenv())
.gllvmTMB_warn_keyword_deprecated <- function(old, new_name, args = "...") {
  if (!isTRUE(.gllvmTMB_deprecation_seen[[old]])) {
    ## Use our own env-based tracker only (no cli `.frequency = "once"`)
    ## so that test code can re-trigger the warning by unbinding the
    ## tracker entry without fighting cli's internal frequency cache.
    cli::cli_inform(c(
      "!" = "Formula keyword {.fn {old}} is a deprecated alias; use {.fn {new_name}} for new code.",
      "i" = "{.code {new_name}({args})} =/=> {.code {old}({args})}",
      ">" = "Aliases will be dropped at the next minor release. See {.code ?diag_re} / {.fn latent}."
    ))
    .gllvmTMB_deprecation_seen[[old]] <- TRUE
  }
  invisible(NULL)
}

#' Phylogenetic random effect: lme4-bar mode-dispatch wrapper
#'
#' `phylo()` is a unified entry point for the package's five canonical
#' phylogenetic keywords (`phylo_scalar`, `phylo_unique`, `phylo_indep`,
#' `phylo_latent`, `phylo_dep`). It accepts an lme4-bar formula on the
#' first argument and dispatches to the appropriate canonical keyword
#' based on the LHS shape and the optional `mode = ...` argument. The
#' five canonical keywords stay first-class — `phylo()` is an additive
#' alias matching the lme4 / brms / drmTMB convention.
#'
#' @section Dispatch rules:
#' | Form                                            | Mode default | Rewrites to                                |
#' |-------------------------------------------------|--------------|--------------------------------------------|
#' | `phylo(1 \| species)`                           | `"scalar"`   | `phylo_scalar(species)`                    |
#' | `phylo(0 + trait \| species, mode = "diag")`    | (mandatory)  | `phylo_unique(species)`                    |
#' | `phylo(0 + trait \| species, mode = "indep")`   | (mandatory)  | `phylo_indep(0 + trait \| species)`        |
#' | `phylo(0 + trait \| species, mode = "latent", d = K)` | (mandatory) | `phylo_latent(species, d = K)`        |
#' | `phylo(0 + trait \| species, mode = "dep")`     | (mandatory)  | `phylo_dep(0 + trait \| species)`          |
#'
#' When the LHS expands to a single column (`1`, intercept-only), `mode`
#' is degenerate: it defaults silently to `"scalar"`, and explicit
#' `mode = "scalar"` is accepted (no warning). When the LHS is
#' `0 + trait`, `mode` is **mandatory** — choosing between `"diag"` /
#' `"indep"` / `"latent"` / `"dep"` is a meaningful decision (per-trait
#' diagonal vs reduced-rank decomposition vs full unstructured) and the
#' parser refuses to silently default.
#'
#' @section Backward compatibility:
#' Legacy bare-name calls `phylo(species)` and `phylo(species, vcv = Cphy)`
#' continue to work as deprecated aliases of `phylo_scalar(species)` /
#' `phylo_scalar(species, vcv = Cphy)`. The legacy form rewrites to
#' `propto(0 + species | trait)` internally, picking up the phylogenetic
#' covariance from the top-level `phylo_vcv =` argument to [gllvmTMB()].
#'
#' @section Augmented LHS (Stage 3, not yet shipped):
#' Augmented LHS forms — `1 + x` (intercept + slope), `0 + trait + (0 + trait):x`
#' (per-trait intercepts + per-trait slopes on covariate `x`), `x || species`
#' (uncorrelated) — are reserved for Design 07 Stage 3 engine work. The
#' parser currently raises an error pointing at this status.
#'
#' @section Cross-package coexistence:
#' drmTMB also exposes `phylo(1 | species, tree = tree)` with the same
#' Hadfield–Nakagawa sparse \eqn{\mathbf A^{-1}} internal path. Both
#' packages share the same calling convention; user muscle memory
#' transfers.
#'
#' @param formula An lme4-bar formula (`<lhs> | <species_column>`) OR,
#'   for backward-compat, a bare unquoted column name (legacy form).
#'   The bar's RHS is the species factor; the LHS determines the
#'   covariance structure (combined with `mode`, see Dispatch rules).
#' @param tree An `ape::phylo` object. **Canonical.** Sparse
#'   \eqn{\mathbf A^{-1}} via Hadfield & Nakagawa (2010).
#' @param vcv A tip-only phylogenetic correlation matrix
#'   (`n_species x n_species`). Legacy / superseded.
#' @param mode One of `"scalar"` / `"diag"` / `"indep"` / `"latent"` /
#'   `"dep"`. Optional when LHS is `1` (defaults silently to
#'   `"scalar"`). Mandatory when LHS is `0 + trait`.
#' @param d Latent rank for `mode = "latent"`. Default 1.
#' @return A formula marker; never evaluated.
#' @seealso [phylo_scalar()], [phylo_unique()], [phylo_indep()],
#'   [phylo_latent()], [phylo_dep()].
#' @export
#' @examples
#' \dontrun{
#' library(ape)
#' tree <- rcoal(20); tree$tip.label <- paste0("sp", 1:20)
#' # Single shared phylogenetic variance (= phylo_scalar)
#' fit_s <- gllvmTMB(value ~ 0 + trait + phylo(1 | species, tree = tree),
#'                   data = df)
#' # Per-trait phylogenetic variances on shared A (= phylo_unique)
#' fit_u <- gllvmTMB(value ~ 0 + trait +
#'                     phylo(0 + trait | species, mode = "diag", tree = tree),
#'                   data = df)
#' # Reduced-rank cross-trait phylogenetic decomposition (= phylo_latent)
#' fit_l <- gllvmTMB(value ~ 0 + trait +
#'                     phylo(0 + trait | species, mode = "latent",
#'                           d = 2, tree = tree),
#'                   data = df)
#' # Backward-compat: legacy bare-name form
#' Cphy <- vcv(tree, corr = TRUE)
#' fit_legacy <- gllvmTMB(value ~ 0 + trait + phylo(species),
#'                        data = df, phylo_vcv = Cphy)
#' }
phylo <- function(formula, tree = NULL, vcv = NULL, mode = NULL, d = 1) {
  ## Marker function. Body unused -- never called at evaluation time.
  invisible(NULL)
}

#' Reduced-rank phylogenetic random effect (PGLLVM)
#'
#' Adds a reduced-rank phylogenetic random effect on the species
#' dimension. For each of `d` phylogenetic latent factors, the
#' species-level scores are drawn from a multivariate normal with
#' the user-supplied phylogenetic correlation matrix; the factors
#' are then linearly combined into trait-specific contributions via
#' a lower-triangular `n_traits x d` loading matrix. Mathematically:
#'
#' \deqn{p_{it} = \sum_{k=1}^{d} \Lambda_{\mathrm{phy},tk}\, g_{ik},
#'       \qquad g_{\cdot k} \sim \mathcal{N}(\mathbf{0}, \mathbf{A}_{\mathrm{phy}}).}
#'
#' This is the model of Nakagawa et al. (*in prep*).
#' When the user supplies `phylo_tree` (an `ape::phylo` object), the
#' implementation builds the sparse inverse \eqn{\mathbf{A}_{\mathrm{phy}}^{-1}}
#' over tips + internal nodes via `MCMCglmm::inverseA(tree)` and
#' evaluates the prior through the quadratic form
#' \eqn{g^\top \mathbf{A}_{\mathrm{phy}}^{-1} g}, exploiting tree-topology
#' sparsity (Hadfield & Nakagawa 2010 *Journal of Evolutionary
#' Biology* 23:494-508; Hadfield 2010 *Journal of Statistical Software*
#' 33(2):1-22). When the user supplies only `phylo_vcv` (the dense
#' tip-only covariance matrix), the package falls back to inverting it
#' densely via `Matrix::solve()` -- correct, but does not exploit
#' sparsity.
#'
#' Used inside a `gllvmTMB()` formula:
#'
#' ```r
#' # recommended: pass tree
#' gllvmTMB(value ~ 0 + trait + phylo_rr(species, d = 2),
#'          data = df, phylo_tree = tree)
#'
#' # legacy: pass dense covariance only
#' gllvmTMB(value ~ 0 + trait + phylo_rr(species, d = 2),
#'          data = df, phylo_vcv = Cphy)
#' ```
#'
#' @param species An unquoted column name giving the species factor.
#'   Levels must match the rownames of `phylo_vcv` passed to
#'   [gllvmTMB()].
#' @param d Integer; the number of phylogenetic latent factors.
#'
#' @return A formula marker; never evaluated.
#' @export
#' @examples
#' \dontrun{
#' library(ape)
#' tree   <- rcoal(20); tree$tip.label <- paste0("sp", 1:20)
#' Cphy   <- vcv(tree, corr = TRUE)
#' fit <- gllvmTMB(value ~ 0 + trait + phylo_rr(species, d = 2),
#'                 data = df, phylo_vcv = Cphy)
#' }
phylo_rr <- function(species, d = 1) {
  invisible(NULL)
}

#' Generic group-with-known-covariance random effect (brms-style)
#'
#' A user-friendly wrapper for any random effect whose covariance is a
#' user-supplied matrix. Mirrors brms's `(1 | gr(species, cov = M))`.
#' Inside a `gllvmTMB()` formula, this desugars to
#' `propto(0 + group | trait)`. The actual covariance matrix used by
#' the engine is whatever is passed to the top-level `phylo_vcv =`
#' argument of [gllvmTMB()]; the optional `cov =` argument inside the
#' formula is retained for backward compatibility and as a hint to the
#' reader, but is **not** used by the engine. Same convention as
#' [phylo()] and [phylo_rr()].
#'
#' @param group An unquoted column name giving the grouping factor.
#' @param cov Optional, ignored by the engine. The matrix actually
#'   used is whatever is passed to the `phylo_vcv` argument of
#'   [gllvmTMB()].
#'
#' @return A formula marker; never evaluated.
#' @export
#' @examples
#' \dontrun{
#' # Recommended:
#' fit <- gllvmTMB(value ~ 0 + trait + gr(species),
#'                 data = df, phylo_vcv = Cphy)
#' # Also valid (cov = Cphy ignored by engine):
#' fit <- gllvmTMB(value ~ 0 + trait + gr(species, cov = Cphy),
#'                 data = df, phylo_vcv = Cphy)
#' }
gr <- function(group, cov = NULL) {
  invisible(NULL)
}

#' Known sampling-error term (brms-style, deprecated alias)
#'
#' A formula keyword for the two-stage meta-regression workflow's
#' stage-2 entry, where the responses are stage-1 estimates (or
#' pre-computed effect sizes such as Hedges' g) and their marginal
#' sampling variances are known. This keyword desugars to
#' `equalto(0 + obs | grp_V, V)` inside `gllvmTMB()`.
#'
#' **Deprecated alias.** Use [meta_known_V()] in new code:
#' `meta_known_V(value, V = V)`.
#'
#' ## Diagonal vs block-diagonal V
#'
#' `meta(value, sampling_var = vi)` describes the **diagonal** case --
#' rows independent. For multivariate meta-analyses with multiple
#' effect sizes per study (multiple outcomes, multiple traits per
#' individual, etc.), within-study sampling errors are correlated and
#' V is **block-diagonal**. The engine supports any positive-definite
#' \eqn{n \times n} V via `solve(V)` internally. Build a block-diagonal
#' V with [block_V()] and pass it to `gllvmTMB()` as `known_V = V_block`.
#'
#' @param value The response column name (typically the column called
#'   `value` in a stage-1 summary, or an effect-size column in a
#'   meta-analytic dataset).
#' @param sampling_var Either an unquoted column name holding the
#'   per-row sampling variance, or a length-1 numeric used for every row.
#'   Deprecated in favour of `meta_known_V(value, V = V)`.
#'
#' @return A formula marker; never evaluated.
#' @seealso [meta_known_V()] (canonical replacement); [block_V()] for
#'   constructing a block-diagonal sampling-V from a study factor;
#'   [gllvmTMB()] for the stage-2 fit.
#' @export
#' @examples
#' \dontrun{
#' # Preferred (canonical) form -- use meta_known_V():
#' V    <- diag(stage1_summary$sampling_var)
#' fit2 <- gllvmTMB(value ~ 0 + trait +
#'                    latent(0 + trait | site, d = 2) +
#'                    meta_known_V(value, V = V),
#'                  data = stage1_summary, known_V = V)
#'
#' # Deprecated form (still works, emits a warning):
#' fit2 <- gllvmTMB(value ~ 0 + trait +
#'                    latent(0 + trait | site, d = 2) +
#'                    meta(value, sampling_var = sampling_var),
#'                  data = stage1_summary, known_V = V)
#' }
meta <- function(value, sampling_var) {
  invisible(NULL)
}


## ============================================================
## Canonical user-facing keywords (the ones to use going forward)
## ============================================================

#' Latent-factor (reduced-rank) random effect: `latent(0 + trait | g, d = K)`
#'
#' Canonical name for a reduced-rank latent-factor random effect at a
#' grouping `g`. Formerly `rr(0 + trait | g, d = K)` -- same engine, new
#' name. The "rr" alias still works for backward compat but emits a
#' one-shot deprecation warning per session.
#'
#' Used inside a `gllvmTMB()` formula:
#' ```r
#' value ~ 0 + trait + latent(0 + trait | unit, d = 2)
#' ```
#'
#' For the canonical decomposition
#' \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi},
#' add an explicit [unique()] term:
#' ```r
#' value ~ 0 + trait + latent(0 + trait | unit, d = 2) +
#'                     unique(0 + trait | unit)
#' ```
#'
#' @param formula `0 + trait | g` style formula (LHS is the response
#'   factor, typically `0 + trait`; RHS is the grouping factor).
#' @param d Integer; number of latent factors.
#' @return A formula marker; never evaluated.
#' @seealso [unique()], [phylo_latent()], [diag_re], [extract_Sigma()].
#' @export
latent <- function(formula, d = 1) {
  invisible(NULL)
}

#' Trait-specific unique variance: `unique(0 + trait | g)`
#'
#' Canonical name for the trait-specific unique-variance covstruct
#' inside a `gllvmTMB()` formula. Formerly `diag(0 + trait | g)` --
#' same engine, new name. The new name avoids the clash with
#' `base::diag()`. The `diag()` keyword still works for backward compat
#' but emits a one-shot deprecation warning per session.
#'
#' Used inside a `gllvmTMB()` formula:
#' ```r
#' value ~ 0 + trait + latent(0 + trait | unit, d = 2) +
#'                     unique(0 + trait | unit)
#' ```
#'
#' This is a **formula keyword** -- it's recognised by the parser inside
#' a `gllvmTMB()` formula's RHS but is never evaluated as a function
#' call. `unique` is *not* exported as an R function (because that
#' would shadow `base::unique()`); the parser handles the symbol
#' directly.
#'
#' ## `common = TRUE` parsimony mode
#'
#' For non-Gaussian fits or small-sample data where the trait-specific
#' \eqn{\sigma_S} estimates are weakly identified, pass `common = TRUE`
#' to fit a single shared \eqn{\sigma_S} across all traits at this tier
#' (one parameter instead of T). Recovers the "compound symmetric"
#' parsimony pattern -- one variance, no per-trait flexibility.
#' Default `common = FALSE` keeps the per-trait estimation.
#'
#' @param formula `0 + trait | g` style formula.
#' @param common `FALSE` (default) for trait-specific variances;
#'   `TRUE` for one shared variance across traits at this tier.
#' @return A formula marker; never evaluated.
#' @seealso [latent()], [diag_re], [extract_Sigma()].
#' @name unique_keyword
#' @aliases unique
#' @keywords internal
NULL

#' Reduced-rank phylogenetic latent factors: `phylo_latent(species, d = K)`
#'
#' Canonical name for the reduced-rank phylogenetic random effect.
#' Formerly `phylo_rr(species, d = K)` -- same engine, new name.
#'
#' ## Two phylogeny inputs: `tree =` (canonical) and `vcv =` (legacy)
#'
#' Pass the phylogeny inside the keyword via one of two arguments:
#'
#' * **`tree = phylo`** (canonical, recommended) -- the full
#'   `ape::phylo` object. Triggers the sparse \eqn{\mathbf{A}^{-1}}
#'   path (Hadfield & Nakagawa 2010, appendix eqs. 26-29) which
#'   scales linearly in `n_species`. About 24x faster than the dense
#'   path at `n_species = 1000` on the published benchmark.
#' * **`vcv = Cphy`** (`r lifecycle::badge("superseded")`) -- a
#'   tip-only `n_species x n_species` correlation matrix. Forces the
#'   dense O(n^2) memory / O(n^3) Cholesky path. Provided for users
#'   who have a Cphy in hand and no Newick tree (e.g. comparing
#'   against `nlme::corPagel`); soft deprecation in 0.2.0.
#'
#' Both arguments give the **same MLE** -- they differ only in
#' computational cost. Internal-node ancestral states are estimated
#' as latent random effects on the sparse path; on the dense path
#' only tip-level loadings are estimated.
#'
#' See `vignette("phylogenetic-gllvm")` for the benchmark and
#' `dev/design/01-phylo-api-canonical-tree.md` for the technical
#' justification.
#'
#' @param species Unquoted column name for the species factor.
#' @param d Integer; number of phylogenetic latent factors.
#' @param tree An `ape::phylo` object. **Canonical.** Use this if
#'   you have a tree.
#' @param vcv A tip-only phylogenetic correlation matrix
#'   (`n_species x n_species`). Legacy / superseded.
#' @return A formula marker; never evaluated.
#' @seealso [phylo_scalar()], [phylo_unique()], [phylo_indep()],
#'   [phylo_dep()], [phylo_rr()] (deprecated alias).
#' @references Hadfield JD, Nakagawa S (2010). General quantitative
#'   genetic methods for comparative biology: phylogenies, taxonomies
#'   and multi-trait models for continuous and categorical characters.
#'   *J. Evol. Biol.* 23: 494-508. \doi{10.1111/j.1420-9101.2009.01915.x}
#' @examples
#' \dontrun{
#'   tree <- ape::rcoal(20); tree$tip.label <- paste0("sp", seq_len(20))
#'   sim <- simulate_site_trait(
#'     n_sites = 1, n_species = 20, n_traits = 4,
#'     mean_species_per_site = 20,
#'     Cphy = ape::vcv(tree, corr = TRUE),
#'     sigma2_phy = rep(0.3, 4), seed = 1
#'   )
#'   sim$data$species <- factor(sim$data$species, levels = tree$tip.label)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait + phylo_latent(species, d = 2),
#'     data = sim$data, phylo_tree = tree
#'   )
#' }
#' @export
phylo_latent <- function(species, d = 1, tree = NULL, vcv = NULL) {
  invisible(NULL)
}

#' Phylogenetic random slope on a continuous covariate
#'
#' Adds a per-species random slope on a continuous covariate `x`, with
#' species-level slopes correlated according to the supplied phylogeny.
#' Mathematically:
#'
#' \deqn{\eta_{it} \;\mathrel{{+}{=}}\; \beta_{\text{phy}}(i)\, x_{io}, \qquad
#'       \boldsymbol\beta_{\text{phy}} \sim \mathcal{N}\bigl(\mathbf 0, \,
#'       \sigma^2_{\text{slope}}\,\mathbf A_{\text{phy}}\bigr).}
#'
#' The slope vector \eqn{\boldsymbol\beta_{\text{phy}}} has length
#' \eqn{n_{\text{species}}} (one slope per species). It is shared
#' across traits -- the same \eqn{\beta_{\text{phy}}(i)} multiplies
#' \eqn{x_{io}} for every trait \eqn{t} of species \eqn{i}. This is
#' the "random regression" pattern from quantitative genetics, with the
#' phylogenetic A-matrix as the slope-covariance prior.
#'
#' Used inside a `gllvmTMB()` formula:
#' ```r
#' value ~ 0 + trait + (0 + trait):x +     # fixed-effect of x per trait
#'         phylo_latent(species, d = 2) +  # main phylogenetic random effect
#'         phylo_slope(x | species)        # phylo random slope on x
#' ```
#'
#' Reuses the same \eqn{\mathbf A_{\text{phy}}^{-1}} as
#' [phylo_latent()] (sparse via `phylo_tree =`, dense via
#' `phylo_vcv =`); only one tree / VCV is needed even with both terms.
#'
#' ## Scope (initial release)
#'
#' This first cut supports:
#' * **One** continuous covariate `x` (a single column name).
#' * **One** shared slope variance \eqn{\sigma^2_{\text{slope}}}.
#' * **Slopes shared across traits** (same \eqn{\beta_{\text{phy}}}(i)
#'   for every trait of species \eqn{i}).
#'
#' Multi-covariate / per-trait / reduced-rank phylogenetic random
#' slopes are on the roadmap.
#'
#' @param formula `x | species` style formula (LHS is the continuous
#'   covariate column name; RHS must be the species factor).
#' @return A formula marker; never evaluated.
#' @seealso [phylo_latent()], [phylo_scalar()].
#' @examples
#' \dontrun{
#'   tree <- ape::rcoal(20); tree$tip.label <- paste0("sp", seq_len(20))
#'   sim <- simulate_site_trait(
#'     n_sites = 10, n_species = 20, n_traits = 3,
#'     mean_species_per_site = 10,
#'     Cphy = ape::vcv(tree, corr = TRUE),
#'     sigma2_phy = rep(0.3, 3), seed = 1
#'   )
#'   sim$data$species <- factor(sim$data$species, levels = tree$tip.label)
#'   sim$data$x <- rnorm(nrow(sim$data))
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait + (0 + trait):x + phylo_slope(x | species),
#'     data = sim$data, phylo_tree = tree
#'   )
#' }
#' @export
phylo_slope <- function(formula) {
  invisible(NULL)
}

#' Single-shared-variance phylogenetic random effect: `phylo_scalar(species)`
#'
#' Canonical name for the single-scalar (per-trait) phylogenetic random
#' intercept. Each trait carries an independent length-`n_species` draw
#' \eqn{\mathbf p_t \sim \mathcal{N}(\mathbf{0}, \sigma^{2}_{\text{phy}}\,\mathbf{C}_{\text{phy}})}
#' with **one shared scaling** \eqn{\sigma^{2}_{\text{phy}}} across all
#' traits. Formerly `phylo(species)` -- same engine, new name. Compare to
#' [phylo_unique()] (D independent variances) and [phylo_latent()]
#' (K-dim factor decomposition).
#'
#' Pass the phylogeny via `tree = phylo` (canonical, sparse \eqn{\mathbf{A}^{-1}};
#' Hadfield & Nakagawa 2010) or `vcv = Cphy`
#' (`r lifecycle::badge("superseded")`, dense). See [phylo_latent()]
#' for the full discussion of the two paths.
#'
#' @param species Unquoted column name for the species factor.
#' @param tree An `ape::phylo` object. **Canonical.**
#' @param vcv A tip-only phylogenetic correlation matrix
#'   (`n_species x n_species`). Legacy / superseded.
#' @return A formula marker; never evaluated.
#' @seealso [phylo_unique()], [phylo_latent()], [phylo_indep()],
#'   [phylo_dep()], [phylo()] (deprecated alias).
#' @examples
#' \dontrun{
#'   tree <- ape::rcoal(8); tree$tip.label <- paste0("sp", seq_len(8))
#'   sim <- simulate_site_trait(
#'     n_sites = 1, n_species = 8, n_traits = 3,
#'     mean_species_per_site = 8,
#'     Cphy = ape::vcv(tree, corr = TRUE),
#'     sigma2_phy = rep(0.3, 3), seed = 1
#'   )
#'   sim$data$species <- factor(sim$data$species, levels = tree$tip.label)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait + phylo_scalar(species),
#'     data = sim$data, phylo_tree = tree
#'   )
#' }
#' @export
phylo_scalar <- function(species, tree = NULL, vcv = NULL) {
  invisible(NULL)
}

#' Per-trait independent phylogenetic random intercepts: `phylo_unique(species)`
#'
#' Canonical name for the **D independent** phylogenetic random
#' intercepts. Each trait \eqn{t} gets its own variance
#' \eqn{\sigma^{2}_{\text{phy},t}} on the same phylogenetic correlation
#' matrix \eqn{\mathbf{C}_{\text{phy}}}; the per-trait random vectors are
#' otherwise independent. Mathematically:
#'
#' \deqn{\mathbf p_t \sim \mathcal{N}(\mathbf{0},\, \sigma^{2}_{\text{phy},t}\,\mathbf{C}_{\text{phy}}),\qquad t = 1,\dots,T,}
#'
#' giving a phylogenetic counterpart of [unique()] -- one independent
#' variance per trait, all sharing the same phylogenetic precision.
#'
#' Compare to [phylo_scalar()] (one shared variance), which collapses
#' the T variances to a single \eqn{\sigma^{2}_{\text{phy}}}; and
#' [phylo_latent()] (K factors), which induces *across-trait*
#' correlation through a low-rank loading matrix.
#'
#' ## Two co-fitting modes
#'
#' `phylo_unique()` has two complementary modes:
#'
#' \describe{
#'   \item{**Alone** (legacy)}{When written without a paired
#'     `phylo_latent(species, d = K)`, the engine implements the term
#'     internally as `phylo_latent(species, d = T)` with a diagonal
#'     \eqn{\boldsymbol\Lambda_{\text{phy}}}. The diagonal entries of
#'     \eqn{\boldsymbol\Lambda_{\text{phy}}} are the per-trait
#'     phylogenetic SDs. This path stays for backward compatibility.}
#'   \item{**Paired with `phylo_latent()`** (two-U PGLLVM, recommended)}{
#'     When written together with `phylo_latent(species, d = K)`, the
#'     two terms co-fit as **separate covariance components**:
#'     \deqn{\boldsymbol\Sigma_\text{phy} \;=\; \underbrace{\boldsymbol\Lambda_\text{phy}\boldsymbol\Lambda_\text{phy}^{\!\top}}_{\text{shared (rank K)}} \;+\; \underbrace{\mathbf S_\text{phy}}_{\text{per-trait unique}}.}
#'     \eqn{\boldsymbol\Lambda_\text{phy}} is filled by the rank-K shared
#'     latent factors; \eqn{\mathbf S_\text{phy}} carries
#'     the per-trait phylogenetic variances not absorbed by the K shared
#'     axes. This is the manuscript-aligned PGLLVM decomposition
#'     (Hadfield & Nakagawa 2010; Meyer & Kirkpatrick 2008; Halliwell et
#'     al. 2025). Replication (multiple sites per species) is required
#'     to break the Psi_phy / Psi_non confound at the species level.}
#' }
#'
#' Use [extract_Sigma()] with `level = "phy"` and `part = "shared"`,
#' `"unique"`, or `"total"` to pull each component, the diagonal psi_phy,
#' or their sum.
#'
#' Pass the phylogeny via `tree = phylo` (canonical, sparse \eqn{\mathbf{A}^{-1}}) or
#' `vcv = Cphy` (`r lifecycle::badge("superseded")`, dense). See
#' [phylo_latent()] for the full discussion of the two paths.
#'
#' @param species Unquoted column name for the species factor.
#' @param tree An `ape::phylo` object. **Canonical.**
#' @param vcv A tip-only phylogenetic correlation matrix
#'   (`n_species x n_species`). Legacy / superseded.
#' @return A formula marker; never evaluated.
#' @seealso [phylo_scalar()], [phylo_latent()], [phylo_indep()],
#'   [phylo_dep()], [extract_Sigma()].
#' @references
#' * **Hadfield, J. D. & Nakagawa, S.** (2010) General quantitative
#'   genetic methods for comparative biology: phylogenies, taxonomies and
#'   multi-trait models for continuous and categorical characters.
#'   *Journal of Evolutionary Biology* 23(3): 494-508.
#'   \doi{10.1111/j.1420-9101.2009.01915.x}
#' * **Meyer, K. & Kirkpatrick, M.** (2008) Perils of parsimony:
#'   properties of reduced-rank estimates of genetic covariance matrices.
#'   *Genetics* 178(4): 2223-2240.
#' @examples
#' \dontrun{
#'   tree <- ape::rcoal(8); tree$tip.label <- paste0("sp", seq_len(8))
#'   sim <- simulate_site_trait(
#'     n_sites = 1, n_species = 8, n_traits = 3,
#'     mean_species_per_site = 8,
#'     Cphy = ape::vcv(tree, corr = TRUE),
#'     sigma2_phy = rep(0.3, 3), seed = 1
#'   )
#'   sim$data$species <- factor(sim$data$species, levels = tree$tip.label)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait + phylo_unique(species),
#'     data = sim$data, phylo_tree = tree
#'   )
#' }
#' @export
phylo_unique <- function(species, tree = NULL, vcv = NULL) {
  invisible(NULL)
}

#' Per-trait independent spatial random fields: `spatial_unique(0 + trait | coords)`
#'
#' Canonical name for the SPDE / GMRF Matern spatial random field with
#' **one independent field per trait** (per-trait variance
#' \eqn{\tau^{2}_t}, shared range parameter \eqn{\kappa}). This is the
#' "unique-rank" cell of the spatial column of the API grid.
#'
#' Formerly `spde(0 + trait | coords)` and `spatial(0 + trait | coords)`
#' -- same engine, new name. See [spde()] for the technical details on
#' the Matern \eqn{\nu = 1} kernel.
#'
#' Compare to [spatial_scalar()] (ONE shared variance across traits)
#' and [spatial_latent()] (K-dim spatial latent factors with a loading
#' matrix).
#'
#' @section Formula orientation:
#' The canonical orientation is `0 + trait | coords` (LHS = trait factor,
#' RHS = the `coords` placeholder), parallel to [latent()],
#' [unique()], and glmmTMB's `gau(0 + trait | pos)` / `exp(0 + trait | pos)`.
#' The earlier orientation `coords | trait` is accepted as a deprecated
#' alias: it emits a one-shot `lifecycle::deprecate_warn()` per session
#' (introduced at gllvmTMB 0.1.4) and is internally normalised to the
#' canonical orientation, so existing fits remain byte-identical.
#'
#' @param formula `0 + trait | coords` style formula (LHS is the trait
#'   factor `0 + trait`; RHS is the `coords` placeholder symbol that
#'   points at the [make_mesh()] coordinate columns).
#' @param coords Character; the column-name pair of spatial coordinates
#'   in `data` (e.g. `c("lon", "lat")`). Resolved by the parser when
#'   supplied as keyword argument; `NULL` when the orientation expresses
#'   the coordinates via the formula RHS.
#' @param mesh Optional `fmesher` mesh object built via [make_mesh()]. If
#'   `NULL`, the engine constructs a default mesh from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_scalar()], [spatial_latent()], [spde()] (deprecated alias).
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 20, n_species = 4, mean_species_per_site = 4,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 4), seed = 1
#'   )
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_unique(0 + trait | site, coords = c("lon", "lat")),
#'     data = sim$data
#'   )
#' }
#' @export
spatial_unique <- function(formula, coords = NULL, mesh = NULL) {
  invisible(NULL)
}

#' One shared spatial-field variance across traits: `spatial_scalar(0 + trait | coords)`
#'
#' Canonical name for the SPDE / GMRF Matern spatial random field with
#' **one shared variance \eqn{\tau^{2}}** across all traits and a shared
#' range parameter \eqn{\kappa}. Each trait carries its own independent
#' field draw on the mesh, but every trait's field has the same marginal
#' variance and the same correlation length. Implementation: the same
#' SPDE engine as [spatial_unique()], with the per-trait
#' `log_tau_spde` parameters tied via TMB's `map` mechanism so they
#' collapse to a single estimable scalar.
#'
#' Use this when domain knowledge (or parsimony) says all traits should
#' share the same amount of spatial structure. Compare to
#' [spatial_unique()] (D independent variances) and [spatial_latent()]
#' (K-dim factor decomposition).
#'
#' @section Formula orientation:
#' The canonical orientation is `0 + trait | coords` (parallel to
#' [latent()] / [unique()] and glmmTMB's spatial keywords). The
#' earlier orientation `coords | trait` is accepted as a deprecated
#' alias and emits a one-shot `lifecycle::deprecate_warn()` per session
#' (introduced at gllvmTMB 0.1.4).
#'
#' @param formula `0 + trait | coords` style formula (LHS is the trait
#'   factor `0 + trait`; RHS is the `coords` placeholder symbol).
#' @param coords Character; the column-name pair of spatial coordinates
#'   in `data` (e.g. `c("lon", "lat")`). Resolved by the parser when
#'   supplied as keyword argument; `NULL` when the orientation expresses
#'   the coordinates via the formula RHS.
#' @param mesh Optional `fmesher` mesh object built via [make_mesh()]. If
#'   `NULL`, the engine constructs a default mesh from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_unique()], [spatial_latent()], [spde()] (deprecated alias).
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 20, n_species = 4, mean_species_per_site = 4,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 4), seed = 1
#'   )
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_scalar(0 + trait | site, coords = c("lon", "lat")),
#'     data = sim$data
#'   )
#' }
#' @export
spatial_scalar <- function(formula, coords = NULL, mesh = NULL) {
  invisible(NULL)
}

#' Reduced-rank spatial latent factors: `spatial_latent(0 + trait | coords, d = K)`
#'
#' Canonical name for the reduced-rank spatial random effect: K shared
#' SPDE fields drive all T traits via a T x K loading matrix
#' \eqn{\boldsymbol\Lambda_{\mathrm{spa}}}. The spatial analogue of
#' [phylo_latent()] and the third cell of the spatial column of the API
#' grid (alongside [spatial_scalar()] and [spatial_unique()]).
#'
#' Internally this rewrites to `spde(form, .spatial_latent = TRUE, d = K)`
#' and toggles the TMB template's `spde_lv_k` switch to K. The C++ kernel
#' then reads a packed lower-triangular `Lambda_spde` and K shared spatial
#' fields `omega_spde_lv` (each prior \eqn{\mathrm{N}(\mathbf{0},
#' \mathbf{Q}^{-1})} where \eqn{\mathbf{Q}} is the SPDE precision built
#' from the mesh), and accumulates
#' \eqn{\eta_o \mathrel{{+}{=}} \sum_k \Lambda_{\mathrm{spa},tk}\,
#' \omega_k(\mathbf{s}_o)} per observation. Per-field \eqn{\tau} is
#' absorbed into \eqn{\boldsymbol\Lambda_{\mathrm{spa}}} for
#' identifiability, mirroring the [phylo_latent()] convention. Like all
#' rr loadings, \eqn{\boldsymbol\Lambda_{\mathrm{spa}}} is identified
#' only up to rotation; pin via `lambda_constraint = list(spde = ...)`
#' or post-hoc rotate via [rotate_loadings()].
#'
#' @section Formula orientation:
#' The canonical orientation is `0 + trait | coords` (parallel to
#' [latent()] / [unique()] and glmmTMB's spatial keywords). The
#' earlier orientation `coords | trait` is accepted as a deprecated
#' alias and emits a one-shot `lifecycle::deprecate_warn()` per session
#' (introduced at gllvmTMB 0.1.4).
#'
#' @param formula `0 + trait | coords` style formula (LHS is the trait
#'   factor `0 + trait`; RHS is the `coords` placeholder symbol).
#' @param d Integer; number of spatial latent factors (rank K). Defaults
#'   to 1.
#' @param coords Character; the column-name pair of spatial coordinates
#'   in `data` (e.g. `c("lon", "lat")`). Resolved by the parser when
#'   supplied as keyword argument; `NULL` when the orientation expresses
#'   the coordinates via the formula RHS.
#' @param mesh Optional `fmesher` mesh object built via [make_mesh()]. If
#'   `NULL`, the engine constructs a default mesh from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_unique()], [spatial_scalar()], [phylo_latent()].
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 30, n_species = 6, mean_species_per_site = 5,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 6), seed = 1
#'   )
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_latent(0 + trait | site, d = 2,
#'                            coords = c("lon", "lat")),
#'     data = sim$data
#'   )
#' }
#' @export
spatial_latent <- function(formula, d = 1, coords = NULL, mesh = NULL) {
  invisible(NULL)
}

#' Spatial random field: lme4-bar mode-dispatch wrapper
#'
#' `spatial()` is a unified entry point for the package's five canonical
#' spatial keywords (`spatial_scalar`, `spatial_unique`, `spatial_indep`,
#' `spatial_latent`, `spatial_dep`). It accepts an lme4-bar formula on
#' the first argument and dispatches to the appropriate canonical
#' keyword based on the LHS shape and the optional `mode = ...` argument.
#' The five canonical keywords stay first-class — `spatial()` is an
#' additive alias matching the lme4 / brms / drmTMB convention.
#'
#' This is the spatial parallel of the [phylo()] mode-dispatch wrapper:
#' same dispatch logic, different engine slots (SPDE Matern instead of
#' Hadfield A^-1).
#'
#' @section Dispatch rules:
#' | Form                                                 | Mode default | Rewrites to                                |
#' |------------------------------------------------------|--------------|--------------------------------------------|
#' | `spatial(1 \| site)`                                 | `"scalar"`   | `spatial_scalar(0 + trait \| coords)`      |
#' | `spatial(0 + trait \| coords, mode = "diag")`        | (mandatory)  | `spatial_unique(0 + trait \| coords)`      |
#' | `spatial(0 + trait \| coords, mode = "indep")`       | (mandatory)  | `spatial_indep(0 + trait \| coords)`       |
#' | `spatial(0 + trait \| coords, mode = "latent", d = K)` | (mandatory) | `spatial_latent(0 + trait \| coords, d = K)` |
#' | `spatial(0 + trait \| coords, mode = "dep")`         | (mandatory)  | `spatial_dep(0 + trait \| coords)`         |
#'
#' When the LHS expands to a single column (`1`, intercept-only), `mode`
#' is degenerate: it defaults silently to `"scalar"`, and explicit
#' `mode = "scalar"` is accepted (no warning). When the LHS is
#' `0 + trait`, `mode` is **mandatory** — choosing between `"diag"` /
#' `"indep"` / `"latent"` / `"dep"` is a meaningful decision (per-trait
#' marginal vs reduced-rank decomposition vs full unstructured) and the
#' parser refuses to silently default.
#'
#' @section Backward compatibility:
#' Legacy bare-formula calls `spatial(0 + trait | coords)` and
#' `spatial(coords | trait)` (no `mode` argument) continue to work as
#' deprecated aliases of `spatial_unique(0 + trait | coords)` (with an
#' additional orientation-flip lifecycle warning for the pre-0.1.4
#' orientation). The legacy form rewrites to `spde()` internally,
#' picking up the SPDE mesh from the top-level `mesh =` argument to
#' [gllvmTMB()].
#'
#' @section Augmented LHS (Stage 3, not yet shipped):
#' Augmented LHS forms — `1 + x` (intercept + slope), `0 + trait + (0 + trait):x`
#' (per-trait intercepts + per-trait slopes on covariate `x`), `x || coords`
#' (uncorrelated) — are reserved for Design 07 Stage 3 engine work. The
#' parser currently raises an error pointing at this status.
#'
#' @section Cross-package coexistence:
#' drmTMB also exposes `spatial(1 | site, mesh = mesh)` with the same
#' SPDE Matern internal path. Both packages share the same calling
#' convention; user muscle memory transfers.
#'
#' @param formula An lme4-bar formula. The bar's RHS is the spatial
#'   coordinate placeholder (typically `coords` or `site`); the LHS
#'   determines the covariance structure (combined with `mode`, see
#'   Dispatch rules). For backward compatibility, `0 + trait | coords`
#'   and `coords | trait` (no `mode`) also work as deprecated aliases
#'   of `spatial_unique`.
#' @param mesh A `fmesher` mesh constructed via [make_mesh()]. **Canonical.**
#'   Required for the new dispatch path; optional for the legacy
#'   bare-formula form (where the mesh is passed at the top level of
#'   [gllvmTMB()]).
#' @param coords Optional, retained as a hint of which coordinate
#'   columns correspond to the spatial grouping. The mesh actually
#'   used is whatever is passed to the `mesh` argument of [gllvmTMB()]
#'   or this function.
#' @param mode One of `"scalar"` / `"diag"` / `"indep"` / `"latent"` /
#'   `"dep"`. Optional when LHS is `1` (defaults silently to
#'   `"scalar"`). Mandatory when LHS is `0 + trait`.
#' @param d Latent rank for `mode = "latent"`. Default 1.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_scalar()], [spatial_unique()], [spatial_indep()],
#'   [spatial_latent()], [spatial_dep()], [phylo()] (phylogenetic
#'   parallel), [spde()] (deeper deprecated alias).
#' @export
#' @examples
#' \dontrun{
#' library(fmesher)
#' # Single shared spatial-field variance (= spatial_scalar)
#' fit_s <- gllvmTMB(value ~ 0 + trait + spatial(1 | site, mesh = mesh),
#'                   data = df)
#' # Per-trait independent fields on shared mesh (= spatial_unique)
#' fit_u <- gllvmTMB(value ~ 0 + trait +
#'                     spatial(0 + trait | coords, mode = "diag",
#'                             mesh = mesh),
#'                   data = df)
#' # Reduced-rank shared spatial latent factors (= spatial_latent)
#' fit_l <- gllvmTMB(value ~ 0 + trait +
#'                     spatial(0 + trait | coords, mode = "latent",
#'                             d = 2, mesh = mesh),
#'                   data = df)
#' # Backward-compat: legacy bare-formula form
#' fit_legacy <- gllvmTMB(value ~ 0 + trait + spatial(0 + trait | coords),
#'                        data = df, mesh = mesh)
#' }
spatial <- function(formula, mesh = NULL, coords = NULL, mode = NULL, d = 1) {
  ## Marker function. Body unused -- never called at evaluation time.
  invisible(NULL)
}

#' Known-V meta-analytic random effect: `meta_known_V(value, V = V)`
#'
#' Canonical name for the known-sampling-error term in two-stage
#' meta-regression workflows. Formerly `meta(value, sampling_var = v)`
#' -- same engine, new name; the new name makes it explicit that what's
#' "known" is the **V** matrix (the sampling-error covariance), not
#' some piece of metadata.
#'
#' @param value Response column name (typically the stage-1 BLUP or an
#'   effect-size column).
#' @param V Either a column name holding per-row sampling variances
#'   (diagonal V) or a length-1 numeric used for every row. For
#'   block-diagonal V, build it via [block_V()] and pass as the
#'   `known_V =` argument to [gllvmTMB()].
#' @return A formula marker; never evaluated.
#' @seealso [meta_known_V()] (canonical name); [meta()] (deprecated alias); [block_V()]; [gllvmTMB()].
#' @export
meta_known_V <- function(value, V) {
  invisible(NULL)
}

## ============================================================
## The "indep" mode of the quartet: marginal-only canonical keywords
## ============================================================

#' Per-trait marginal variance: `indep(0 + trait | g)`
#'
#' Canonical name for the **always-alone marginal-only** per-trait
#' diagonal variance term. Mathematically identical to
#' `unique(0 + trait | g)` standalone (both produce
#' \eqn{\boldsymbol\Sigma = \mathrm{diag}(\sigma^2_t)} with identity
#' off-diagonals); the keyword choice is documentary, not operational.
#'
#' The package's covstruct API organises around two mutually exclusive
#' modes, distinguished by convention:
#'
#' \describe{
#'   \item{**Decomposition** (`latent + unique`)}{Shared cross-trait
#'     covariance plus trait-specific residual:
#'     \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi}.}
#'   \item{**Marginal** (`indep` standalone)}{Per-trait total variance
#'     with no cross-trait decomposition: \eqn{\boldsymbol\Sigma = \mathrm{diag}(\sigma^2_t)}.}
#' }
#'
#' Use `indep()` when you want to commit to the marginal-only
#' interpretation explicitly. Use `unique()` paired with `latent()` when
#' you want the cross-trait decomposition; `unique()` standalone (e.g.
#' for observation-level random effects in mixed-response fits) also
#' remains legitimate.
#'
#' ## Mutual exclusion with `latent()`
#'
#' Combining `indep(0 + trait | g)` with `latent(0 + trait | g, d = K)`
#' on the same grouping is **over-parameterised** (the model cannot
#' decide whether trait variance lives in the shared component or the
#' marginal component). The parser raises a `cli::cli_abort()` in this
#' case. Combining `indep` with `unique` on the same grouping is
#' similarly redundant and also errors.
#'
#' @param formula `0 + trait | g` style formula (LHS is the trait
#'   factor, typically `0 + trait`; RHS is the grouping factor).
#' @return A formula marker; never evaluated.
#' @seealso [unique()], [latent()], [phylo_indep()], [spatial_indep()],
#'   [extract_Sigma()].
#' @export
#' @examples
#' \dontrun{
#' # Marginal-only fit (per-trait variance, identity correlation):
#' fit <- gllvmTMB(value ~ 0 + trait + indep(0 + trait | site),
#'                 data = df, unit = "site")
#'
#' # The mathematically-equivalent decomposition form:
#' fit <- gllvmTMB(value ~ 0 + trait + unique(0 + trait | site),
#'                 data = df, unit = "site")
#'
#' # ERROR: indep + latent on the same grouping is over-parameterised.
#' # gllvmTMB(value ~ 0 + trait +
#' #           indep(0 + trait | site) +
#' #           latent(0 + trait | site, d = 2), data = df)
#' }
indep <- function(formula) {
  invisible(NULL)
}

#' Per-trait phylogenetic marginal variance: `phylo_indep(0 + trait | species)`
#'
#' Canonical name for **T per-trait phylogenetic variances coupled by
#' the phylo correlation matrix \eqn{\mathbf A}**. Mathematically
#' identical to `phylo_unique(species)` standalone; standalone =
#' T univariate phylogenetic mixed models stacked.
#'
#' Each trait \eqn{t} gets its own variance
#' \eqn{\sigma^2_{\text{phy},t}} on the same phylogenetic correlation
#' matrix \eqn{\mathbf A_{\text{phy}}}; trait-specific random vectors
#' are otherwise independent.
#'
#' \deqn{\mathbf p_t \sim \mathcal{N}(\mathbf 0,\, \sigma^2_{\text{phy},t}\,\mathbf A_{\text{phy}}), \qquad t = 1, \dots, T.}
#'
#' Use `phylo_indep()` for an explicit marginal-only phylogenetic fit
#' (no cross-trait phylogenetic decomposition). Use `phylo_latent()`
#' paired with `phylo_unique()` for the paired phylogenetic decomposition
#' \eqn{\boldsymbol\Sigma_{\text{phy}} = \boldsymbol\Lambda_{\text{phy}}\boldsymbol\Lambda_{\text{phy}}^\top + \mathbf S_{\text{phy}}}.
#'
#' ## Mutual exclusion with `phylo_latent()`
#'
#' Combining `phylo_indep(0 + trait | species)` with
#' `phylo_latent(species, d = K)` is **over-parameterised** and the
#' parser raises a `cli::cli_abort()`. Combining `phylo_indep` with
#' `phylo_unique` is redundant and also errors.
#'
#' ## Future extensibility
#'
#' The formula syntax `phylo_indep(0 + trait + trait:x | species)` is
#' reserved as a future path for **trait-specific phylogenetic random
#' slopes** on covariate `x`. The parser recognises the syntax but the
#' engine currently supports only the simple `0 + trait | species` form;
#' richer LHS expressions are deferred.
#'
#' Pass the phylogeny via `tree = phylo` (canonical, sparse \eqn{\mathbf{A}^{-1}}) or
#' `vcv = Cphy` (`r lifecycle::badge("superseded")`, dense). See
#' [phylo_latent()] for the full discussion of the two paths.
#'
#' @param formula `0 + trait | species` style formula. The LHS must be
#'   `0 + trait` (the trait factor); the RHS is the species column.
#' @param tree An `ape::phylo` object. **Canonical.**
#' @param vcv A tip-only phylogenetic correlation matrix
#'   (`n_species x n_species`). Legacy / superseded.
#' @return A formula marker; never evaluated.
#' @seealso [phylo_unique()], [phylo_latent()], [phylo_dep()], [indep()],
#'   [spatial_indep()], [extract_Sigma()].
#' @references
#' * **Williams et al.** (2025) Phylogenetic generalised linear mixed
#'   models for multi-trait comparative analyses. *bioRxiv*
#'   2025.12.20.695312. The marginal `phylo_indep + indep` standalone
#'   form stacked across traits matches their PGLMM Eq. 3.
#' @export
#' @examples
#' \dontrun{
#' library(ape)
#' tree <- rcoal(20); tree$tip.label <- paste0("sp", 1:20)
#' fit <- gllvmTMB(value ~ 0 + trait +
#'                   phylo_indep(0 + trait | species, tree = tree),
#'                 data = df)
#' }
phylo_indep <- function(formula, tree = NULL, vcv = NULL) {
  invisible(NULL)
}

#' Per-trait spatial marginal field: `spatial_indep(0 + trait | coords)`
#'
#' Canonical name for **T per-trait spatial fields coupled by the SPDE
#' precision matrix \eqn{\mathbf Q}**. Mathematically identical to
#' `spatial_unique(0 + trait | coords)` standalone; standalone =
#' T univariate spatial fits stacked.
#'
#' Each trait \eqn{t} gets its own variance
#' \eqn{\tau^2_t} on a Matern \eqn{\nu = 1} GMRF, with a shared range
#' parameter \eqn{\kappa}.
#'
#' Use `spatial_indep()` for an explicit marginal-only spatial fit (no
#' cross-trait spatial decomposition). Use `spatial_latent()` for
#' K shared spatial fields driving all T traits via a T x K loading
#' matrix.
#'
#' @section Formula orientation:
#' Same convention as the rest of the `spatial_*` keywords: the
#' canonical orientation is `0 + trait | coords` (LHS = trait factor,
#' RHS = the `coords` placeholder). Spatial keywords adopted this
#' orientation at gllvmTMB 0.1.4; `spatial_indep` is born with it
#' (no legacy `coords | trait` orientation is accepted).
#'
#' ## Mutual exclusion with `spatial_latent()`
#'
#' Combining `spatial_indep(0 + trait | coords)` with
#' `spatial_latent(0 + trait | coords, d = K)` is **over-parameterised**
#' and the parser raises a `cli::cli_abort()`. Combining `spatial_indep`
#' with `spatial_unique` is redundant and also errors.
#'
#' @param formula `0 + trait | coords` style formula (LHS is the trait
#'   factor `0 + trait`; RHS is the `coords` placeholder symbol that
#'   points at the [make_mesh()] coordinate columns).
#' @param coords Character; the column-name pair of spatial coordinates
#'   in `data` (e.g. `c("lon", "lat")`). Resolved by the parser when
#'   supplied as keyword argument; `NULL` when the orientation expresses
#'   the coordinates via the formula RHS.
#' @param mesh Optional `fmesher` mesh object built via [make_mesh()]. If
#'   `NULL`, the engine constructs a default mesh from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_unique()], [spatial_latent()], [indep()],
#'   [phylo_indep()], [extract_Sigma()].
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 20, n_species = 4, mean_species_per_site = 4,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 4), seed = 1
#'   )
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_indep(0 + trait | site, coords = c("lon", "lat")),
#'     data = sim$data
#'   )
#' }
#' @export
spatial_indep <- function(formula, coords = NULL, mesh = NULL) {
  invisible(NULL)
}


## ============================================================
## The "dep" mode of the quartet: full unstructured-Sigma canonical keywords
## ============================================================

#' Full unstructured trait covariance: `dep(0 + trait | g)`
#'
#' Canonical name for the **always-alone full-unstructured** trait
#' covariance term. Fits a full \eqn{T \times T} \eqn{\boldsymbol\Sigma}
#' with \eqn{T(T+1)/2} free parameters via a Cholesky parameterisation
#' \eqn{\boldsymbol\Sigma = \mathbf{L}\mathbf{L}^\top}. Mathematically
#' identical to `latent(0 + trait | g, d = T)` standalone (where \eqn{T}
#' is the number of traits) — the engine's existing packed-triangular
#' \eqn{\boldsymbol\Lambda} at full rank IS the Cholesky factor of an
#' unstructured \eqn{\boldsymbol\Sigma}. The keyword choice is
#' documentary: `dep` declares user intent that the full unstructured
#' trait covariance is the model.
#'
#' This completes the structural-mode quartet:
#'
#' \describe{
#'   \item{**Decomposition** (`latent + unique`)}{Shared low-rank
#'     loadings plus trait-specific residual:
#'     \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi}.
#'     \eqn{TK + T} parameters (rotation-removed).}
#'   \item{**Marginal** (`indep` standalone)}{Per-trait variance with
#'     identity correlation: \eqn{\boldsymbol\Sigma = \mathrm{diag}(\sigma^2_t)}.
#'     \eqn{T} parameters.}
#'   \item{**Full / unstructured** (`dep` standalone)}{Free unstructured
#'     \eqn{\boldsymbol\Sigma}, PSD via Cholesky.
#'     \eqn{T(T+1)/2} parameters.}
#' }
#'
#' Use `dep()` when you want to commit to the full unstructured
#' interpretation explicitly. Maintainer's framing: this is just a
#' standard multivariate response model. Computational scope: tractable
#' for \eqn{T \le \sim 30} with the default optimiser; for larger
#' \eqn{T}, prefer `latent(d = K)` with \eqn{K \ll T} as the
#' rank-reduced approximation.
#'
#' ## Mutual exclusion
#'
#' Combining `dep(0 + trait | g)` with `latent(0 + trait | g, d = K)`
#' on the same grouping is **over-parameterised**. Combining `dep` with
#' `unique` or `indep` on the same grouping is **redundant** (`dep`
#' standalone already includes the trait-level diagonal). The parser
#' raises `cli::cli_abort()` in any of these cases.
#'
#' @param formula `0 + trait | g` style formula (LHS is the trait
#'   factor, typically `0 + trait`; RHS is the grouping factor).
#' @return A formula marker; never evaluated.
#' @seealso [latent()], [unique()], [indep()], [phylo_dep()],
#'   [spatial_dep()], [extract_Sigma()].
#' @export
#' @examples
#' \dontrun{
#' # Full unstructured trait covariance fit:
#' fit <- gllvmTMB(value ~ 0 + trait + dep(0 + trait | site),
#'                 data = df, unit = "site")
#'
#' # The mathematically-equivalent decomposition form (full rank):
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = T),
#'                 data = df, unit = "site")
#'
#' # ERROR: dep + latent on the same grouping is over-parameterised.
#' # gllvmTMB(value ~ 0 + trait +
#' #           dep(0 + trait | site) +
#' #           latent(0 + trait | site, d = 2), data = df)
#' }
dep <- function(formula) {
  invisible(NULL)
}

#' Full unstructured phylogenetic trait covariance: `phylo_dep(0 + trait | species)`
#'
#' Canonical name for the **full unstructured cross-trait phylogenetic
#' covariance** \eqn{\boldsymbol\Sigma_{\text{phy}} \otimes \mathbf{A}},
#' with \eqn{T(T+1)/2} free parameters (\eqn{\boldsymbol\Sigma_{\text{phy}}}
#' parameterised via Cholesky for PSD-ness). Mathematically identical to
#' `phylo_latent(species, d = T)` standalone; the keyword choice is
#' documentary.
#'
#' \deqn{\mathrm{vec}(\mathbf P) \sim \mathcal{N}(\mathbf 0,\,
#'   \boldsymbol\Sigma_{\text{phy}} \otimes \mathbf{A}_{\text{phy}}).}
#'
#' Use `phylo_dep()` when you want an explicit full-unstructured
#' cross-trait phylogenetic covariance fit. Use `phylo_latent()` paired
#' with `phylo_unique()` for the rank-reduced paired phylogenetic decomposition. Use
#' `phylo_indep()` for the marginal-only per-trait variance fit.
#'
#' ## Mutual exclusion with `phylo_latent()` / `phylo_unique()` / `phylo_indep()`
#'
#' Combining `phylo_dep(0 + trait | species)` with `phylo_latent` is
#' **over-parameterised**; combining with `phylo_unique` or
#' `phylo_indep` is **redundant** (`phylo_dep` already includes the
#' diagonal). The parser raises `cli::cli_abort()` in any of these
#' cases.
#'
#' Pass the phylogeny via `tree = phylo` (canonical, sparse \eqn{\mathbf{A}^{-1}}) or
#' `vcv = Cphy` (`r lifecycle::badge("superseded")`, dense). See
#' [phylo_latent()] for the full discussion of the two paths.
#'
#' @param formula `0 + trait | species` style formula. The LHS must be
#'   `0 + trait` (the trait factor); the RHS is the species column.
#' @param tree An `ape::phylo` object. **Canonical.**
#' @param vcv A tip-only phylogenetic correlation matrix
#'   (`n_species x n_species`). Legacy / superseded.
#' @return A formula marker; never evaluated.
#' @seealso [phylo_latent()], [phylo_unique()], [phylo_indep()],
#'   [dep()], [spatial_dep()], [extract_Sigma()].
#' @examples
#' \dontrun{
#'   tree <- ape::rcoal(8); tree$tip.label <- paste0("sp", seq_len(8))
#'   sim <- simulate_site_trait(
#'     n_sites = 1, n_species = 8, n_traits = 3,
#'     mean_species_per_site = 8,
#'     Cphy = ape::vcv(tree, corr = TRUE),
#'     sigma2_phy = rep(0.3, 3), seed = 1
#'   )
#'   sim$data$species <- factor(sim$data$species, levels = tree$tip.label)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait + phylo_dep(0 + trait | species),
#'     data = sim$data, phylo_tree = tree
#'   )
#' }
#' @export
phylo_dep <- function(formula, tree = NULL, vcv = NULL) {
  invisible(NULL)
}

#' Full unstructured spatial trait covariance: `spatial_dep(0 + trait | coords)`
#'
#' Canonical name for the **full unstructured cross-trait spatial
#' covariance** \eqn{\boldsymbol\Sigma_{\text{spa}} \otimes \mathbf{Q}^{-1}},
#' with \eqn{T(T+1)/2} free parameters
#' (\eqn{\boldsymbol\Sigma_{\text{spa}}} parameterised via Cholesky).
#' Mathematically identical to `spatial_latent(0 + trait | coords, d = T)`
#' standalone; the keyword choice is documentary.
#'
#' Use `spatial_dep()` when you want an explicit full-unstructured
#' cross-trait spatial covariance fit. Use `spatial_latent()` for the
#' rank-reduced K-factor model. Use `spatial_indep()` for the
#' marginal-only per-trait spatial fit.
#'
#' @section Formula orientation:
#' Same convention as the rest of the `spatial_*` keywords: the
#' canonical orientation is `0 + trait | coords` (LHS = trait factor,
#' RHS = the `coords` placeholder). `spatial_dep` is born with this
#' orientation; the legacy `coords | trait` form is not accepted.
#'
#' ## Mutual exclusion with `spatial_latent()` / `spatial_unique()` / `spatial_indep()`
#'
#' Combining `spatial_dep(0 + trait | coords)` with `spatial_latent` is
#' **over-parameterised**; combining with `spatial_unique` or
#' `spatial_indep` is **redundant**. The parser raises
#' `cli::cli_abort()` in any of these cases.
#'
#' @param formula `0 + trait | coords` style formula (LHS is the trait
#'   factor `0 + trait`; RHS is the `coords` placeholder symbol that
#'   points at the [make_mesh()] coordinate columns).
#' @param coords Character; the column-name pair of spatial coordinates
#'   in `data` (e.g. `c("lon", "lat")`). Resolved by the parser when
#'   supplied as keyword argument; `NULL` when the orientation expresses
#'   the coordinates via the formula RHS.
#' @param mesh Optional `fmesher` mesh object built via [make_mesh()]. If
#'   `NULL`, the engine constructs a default mesh from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_latent()], [spatial_unique()], [spatial_indep()],
#'   [dep()], [phylo_dep()], [extract_Sigma()].
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 30, n_species = 6, mean_species_per_site = 5,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 6), seed = 1
#'   )
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_dep(0 + trait | site, coords = c("lon", "lat")),
#'     data = sim$data
#'   )
#' }
#' @export
spatial_dep <- function(formula, coords = NULL, mesh = NULL) {
  invisible(NULL)
}


#' Desugar brms-style covstruct calls to glmmTMB-style
#'
#' Walks the RHS of a formula and rewrites any `phylo(...)`, `gr(...)`,
#' or `meta(...)` calls into the equivalent `propto(...)` / `equalto(...)`
#' covstruct calls. Backward compatible: formulas without the brms-style
#' calls are returned unchanged.
#'
#' @param formula A formula.
#' @param trait_col Name of the trait factor column (default `"trait"`).
#' @param obs_col Name of a per-observation factor column for the
#'   `equalto` covstruct (default `"obs"`).
#' @param grp_V Name of a single-level factor column used as the
#'   grouping for the `equalto` covstruct (default `"grp_V"`).
#'
#' @return A formula with brms-style calls replaced by glmmTMB-style.
#' @keywords internal
#' @noRd
## Spatial-keyword formula orientation.
##
## The canonical orientation for every spatial_* keyword is
## `0 + trait | coords` (LHS = trait factor, RHS = the `coords`
## placeholder), parallel to `latent(0 + trait | g)`,
## `unique(0 + trait | g)`, and glmmTMB's `gau(0 + trait | pos)` /
## `exp(0 + trait | pos)`. The pre-0.1.4 orientation `coords | trait` is
## accepted as a deprecated alias and emits a one-shot
## `lifecycle::deprecate_warn()` per session before being normalised to
## the canonical orientation. The downstream engine reads neither side
## of the bar (the `spde()` covstruct's parsed `lhs` / `group` are
## placeholders only — see `parse_multi_formula()` and `R/fit-multi.R`),
## so the flip is purely cosmetic on the parser side and existing fits
## remain byte-identical.
##
## `normalise_spatial_orientation(call)` accepts a `spatial_*()` call
## expression, inspects the bar inside it, and returns the call with the
## bar normalised to `0 + trait | coords`. The first time the deprecated
## orientation is seen in a session, a lifecycle warning is emitted via
## `lifecycle::deprecate_warn(when = "0.1.4", ...)` keyed off the
## per-keyword name (`spatial_unique`, `spatial_scalar`, `spatial_latent`,
## `spatial`) so multiple keywords in one formula each get their own
## first-time warning.
.is_zero_plus_trait <- function(e) {
  ## TRUE if `e` is the call `0 + <name>`, i.e. `+(0, name)`.
  is.call(e) &&
    identical(e[[1L]], as.name("+")) &&
    length(e) == 3L &&
    is.numeric(e[[2L]]) && length(e[[2L]]) == 1L && e[[2L]] == 0 &&
    is.name(e[[3L]])
}

## Design 07 Stage 2.5 (May 2026): fail-loud guard against augmented LHS
## in the BARE covstruct keywords (`latent`, `unique`, `indep`, `dep`,
## `spatial_dep`). The `phylo()` and `spatial()` mode-dispatch wrappers
## already abort fail-loud on augmented LHS (df76c705 / 8b1ddc92); the
## bare keywords inherited the silent-collapse path because the engine
## hardcodes `n_traits` at nine sites in fit-multi.R (see
## dev/dev-log/after-task/15-design-07-oq1-engine-audit.md).
##
## Sokal's empirical confirmation (2026-05-09 gating verification, commit
## 7e90f036): two fits with intercept-only and augmented LHS produced
## byte-identical objectives (677.4103) and identical T x d_B Lambda_hat
## instead of 2T x d_B. Engine collapsed at fit time without warning.
##
## Contract: `e` is the user's call (e.g. `latent(<bar>, d = 1)`); `fn`
## is the keyword name. If the first arg of `e` is an lme4 bar with LHS
## anything other than `1` or `0 + trait`, abort with a Stage-3 redirect.
## If the first arg is not a bar at all (e.g. legacy `unique(grp)` bare-
## name form), this helper is a no-op.
.assert_no_augmented_lhs <- function(fn, e) {
  if (!is.call(e) || length(e) < 2L) return(invisible(NULL))
  bar <- e[[2L]]
  if (!(is.call(bar) && identical(bar[[1L]], as.name("|")) &&
        length(bar) == 3L)) {
    return(invisible(NULL))
  }
  lhs <- bar[[2L]]
  ## Match exactly the same shape detection the phylo()/spatial() wrappers
  ## use (df76c705 / 8b1ddc92): `1` (intercept-only) or `0 + trait`
  ## (per-trait intercepts). Anything else is augmented LHS, not yet
  ## supported by the engine.
  is_intercept_only <- (is.numeric(lhs) && length(lhs) == 1L && lhs == 1) ||
                       (is.symbol(lhs) && identical(as.character(lhs), "1"))
  is_zero_plus_trait <- is.call(lhs) &&
    identical(lhs[[1L]], as.name("+")) &&
    length(lhs) == 3L &&
    is.numeric(lhs[[2L]]) && lhs[[2L]] == 0 &&
    is.symbol(lhs[[3L]]) && identical(as.character(lhs[[3L]]), "trait")
  if (is_intercept_only || is_zero_plus_trait) return(invisible(NULL))
  cli::cli_abort(c(
    "{.fn {fn}} augmented LHS is not yet supported.",
    "i" = "You wrote {.code {fn}({deparse(bar)})}.",
    "x" = "Augmented LHS forms (intercept + slope, per-trait slopes, uncorrelated `||`) require {.strong Design 07 Stage 3} engine work (extending {.code n_traits} to {.code n_lhs_cols} in the TMB template).",
    ">" = "For Stage 2, use {.code 0 + trait | g} (per-trait intercepts) or {.code 1 | g} (single shared variance)."
  ))
}

normalise_spatial_orientation <- function(e) {
  ## `e` is a call like spatial_unique(<bar>, ...). Replace its first
  ## positional argument with the canonically-oriented bar.
  if (!is.call(e) || length(e) < 2L) return(e)
  fn <- as.character(e[[1L]])
  if (!(fn %in% c("spatial_unique", "spatial_scalar", "spatial_latent",
                  "spatial", "spatial_indep"))) {
    return(e)
  }
  bar <- e[[2L]]
  if (!(is.call(bar) && identical(bar[[1L]], as.name("|")) &&
        length(bar) == 3L)) {
    cli::cli_abort(c(
      "{.fn {fn}} expects a {.code 0 + trait | coords} formula as its first argument.",
      "i" = "Got: {.code {deparse(bar)}}.",
      ">" = "Use {.code {fn}(0 + trait | coords)}; the deprecated orientation {.code coords | trait} is also accepted."
    ))
  }
  lhs <- bar[[2L]]
  rhs <- bar[[3L]]
  if (.is_zero_plus_trait(lhs) && is.name(rhs)) {
    ## Already canonical (`0 + trait | coords`). Nothing to flip.
    return(e)
  }
  ## `spatial_indep` is born post-flip: it never accepted the legacy
  ## `coords | trait` orientation, so reject anything other than the
  ## canonical form with a clean error rather than a deprecation warn.
  if (identical(fn, "spatial_indep")) {
    cli::cli_abort(c(
      "{.fn spatial_indep} bar must be {.code 0 + trait | coords}.",
      "i" = "Got: {.code {deparse(bar)}}.",
      ">" = "{.fn spatial_indep} was introduced post-orientation-flip and only accepts the canonical orientation."
    ))
  }
  if (is.name(lhs) && is.name(rhs)) {
    ## Deprecated `coords | trait` orientation -- flip and warn (once).
    ## lifecycle::deprecate_warn() doesn't process cli markup in
    ## `details`, so we use plain backticks here for legibility.
    lifecycle::deprecate_warn(
      when = "0.1.4",
      what = I(sprintf("%s(coords | trait)", fn)),
      with = I(sprintf("%s(0 + trait | coords)", fn)),
      details = c(
        i = paste0("The canonical formula orientation for spatial_* keywords is now ",
                   "`0 + trait | coords`, matching `latent()`, `unique()`, and ",
                   "glmmTMB's `gau(0 + trait | pos)` / `exp(0 + trait | pos)`."),
        ">" = sprintf("Update `%s(coords | trait)` to `%s(0 + trait | coords)`.", fn, fn)
      ),
      id = sprintf("gllvmTMB-spatial-orientation-flip-%s", fn)
    )
    new_bar <- call("|", call("+", 0, rhs), lhs)
    new_call <- e
    new_call[[2L]] <- new_bar
    return(new_call)
  }
  ## Anything else is malformed.
  cli::cli_abort(c(
    "{.fn {fn}} bar must be {.code 0 + trait | coords}.",
    "i" = "Got LHS = {.code {deparse(lhs)}}, RHS = {.code {deparse(rhs)}}.",
    ">" = "Expected LHS {.code 0 + trait} and RHS a single name (e.g. {.code coords})."
  ))
}

## Rewrite canonical aliases to engine-internal names. This runs BEFORE
## the existing brms-style sugar so that e.g. `phylo_scalar(species)`
## becomes `phylo(species)` which then becomes `propto(0 + species | trait)`.
##
##   latent(form, d)                  -> rr(form, d)
##   unique(form, common = bool)      -> diag(form, common = bool)
##   phylo_latent(species, d)         -> phylo_rr(species, d)
##   phylo_scalar(species)            -> phylo(species)
##   phylo_unique(species)            -> phylo_rr(species, .phylo_unique = TRUE)
##                                      [diagonal lambda_constraint added by fit-multi]
##   indep(form)                      -> diag(form, .indep = TRUE)
##                                      [identical engine path to `unique` standalone;
##                                       the `.indep` marker only changes the printed
##                                       label and triggers the indep+latent guard]
##   phylo_indep(0 + trait | species) -> phylo_rr(species, .phylo_unique = TRUE,
##                                                .indep = TRUE)
##                                      [reuses the phylo_unique-alone engine path;
##                                       the `.indep` marker only changes the printed
##                                       label and triggers the indep+latent guard]
##   spatial_indep(0 + trait | coords) -> spde(form, .spatial_indep = TRUE)
##                                      [identical engine path to `spatial_unique`
##                                       standalone; the `.spatial_indep` marker only
##                                       changes the printed label and triggers the
##                                       indep+latent guard]
##   dep(0 + trait | g)               -> rr(form, d = .deferred_n_traits, .dep = TRUE)
##                                      [identical engine path to `latent(d=n_traits)`
##                                       standalone; the packed-triangular Lambda at
##                                       full rank IS the Cholesky factor of
##                                       unstructured Sigma. The `.dep` marker only
##                                       changes the printed label and triggers the
##                                       dep+{latent,unique,indep} guards. The
##                                       `.deferred_n_traits` symbol is resolved to
##                                       n_traits in fit-multi.R after data parsing]
##   phylo_dep(0 + trait | species)   -> phylo_rr(species, d = .deferred_n_traits,
##                                                .dep = TRUE)
##                                      [reuses the phylo_latent(d=n_traits) engine
##                                       path; .dep marker triggers phylo_dep guards]
##   spatial_dep(0 + trait | coords)  -> spde(form, .spatial_latent = TRUE,
##                                            d = .deferred_n_traits, .dep = TRUE)
##                                      [reuses the spatial_latent(d=n_traits) engine
##                                       path; .dep marker triggers spatial_dep guards]
##   spatial_unique(form)             -> spde(form)
##   spatial_scalar(form)             -> spde(form, .spatial_scalar = TRUE)
##                                      [common = TRUE log_tau map applied by fit-multi]
##   spatial_latent(form, d)          -> spde(form, .spatial_latent = TRUE, d = d)
##                                      [fit-multi flips spde_lv_k = d and
##                                       allocates Lambda_spde + omega_spde_lv]
##   spatial(form)                    -> spde(form) (deprecation warn on the way)
##   meta_known_V(value, V = V)       -> meta(value, sampling_var = V)
##
## Spatial keywords additionally get their bar normalised to
## `0 + trait | coords` via `normalise_spatial_orientation()` before the
## rename. The pre-0.1.4 orientation `coords | trait` triggers a one-shot
## lifecycle deprecation warning per keyword per session; the engine
## itself reads neither side of the bar so the flip is purely cosmetic.
rewrite_canonical_aliases <- function(formula) {
  ## Phase L (May 2026): per-term `tree = ...`, `vcv = ...`,
  ## `coords = ...`, `mesh = ...` arguments inside phylo_*() / spatial_*()
  ## keywords must survive the rewrite to the canonical engine kinds
  ## (phylo_rr / spde / etc.). Helper extracts named args matching `keep`
  ## from the original call so the rewritten call carries them through.
  .pass_through_extras <- function(e, keep) {
    args <- as.list(e)[-c(1L, 2L)]
    nms  <- names(args)
    if (is.null(nms) || length(args) == 0L) return(list())
    args[nms %in% keep & nzchar(nms)]
  }
  rewrite <- function(e) {
    if (is.call(e)) {
      fn <- as.character(e[[1L]])
      ## `spatial(formula, mode = ..., mesh = ..., coords = ..., d = ...)`
      ## -> one of spatial_scalar / spatial_unique / spatial_indep /
      ## spatial_latent / spatial_dep based on (LHS, mode). Design 07
      ## Stage 2, spatial parallel of the phylo() dispatch above.
      ##
      ## Only fires when the first arg is an lme4-bar formula AND the
      ## user supplied `mode = ...` (or LHS = `1` which has degenerate
      ## mode). Legacy bare-formula calls without `mode` -- e.g.
      ## `spatial(0 + trait | coords)` and `spatial(coords | trait)`
      ## with LHS = `0 + trait` -- fall through to the existing
      ## `spatial -> spatial_unique` deprecation alias rewrite below.
      ##
      ## Must run BEFORE normalise_spatial_orientation() because (a)
      ## LHS = `1` and (b) augmented LHS would both be rejected as
      ## malformed bars by the orientation flip otherwise.
      if (fn == "spatial" && length(e) >= 2L && is.call(e[[2L]]) &&
          identical(e[[2L]][[1L]], as.name("|"))) {
        bar <- e[[2L]]
        lhs <- bar[[2L]]
        rhs <- bar[[3L]]
        ## Inspect named args.
        args_named <- as.list(e)[-c(1L, 2L)]
        nms        <- names(args_named)
        if (is.null(nms)) nms <- rep("", length(args_named))
        get_arg <- function(name, default = NULL) {
          ix <- which(nms == name)
          if (length(ix) == 0L) return(default)
          args_named[[ix[1L]]]
        }
        mode_arg   <- get_arg("mode",   default = NULL)
        mesh_arg   <- get_arg("mesh",   default = NULL)
        coords_arg <- get_arg("coords", default = NULL)
        d_arg      <- get_arg("d",      default = NULL)

        ## Detect LHS shape.
        is_intercept_only <- (is.numeric(lhs) && length(lhs) == 1L &&
                              lhs == 1) ||
                             (is.symbol(lhs) && identical(as.character(lhs), "1"))
        is_zero_plus_trait <- is.call(lhs) &&
          identical(lhs[[1L]], as.name("+")) &&
          length(lhs) == 3L &&
          is.numeric(lhs[[2L]]) && lhs[[2L]] == 0 &&
          is.symbol(lhs[[3L]]) && identical(as.character(lhs[[3L]]),
                                            "trait")

        ## The dispatch fires only when the user gave us a clear hint
        ## that they want the new path: an intercept-only LHS (`1`),
        ## an explicit `mode = ...`, or an explicit `mesh = ...`. The
        ## legacy form `spatial(0 + trait | coords)` (no mode, no mesh,
        ## LHS = `0 + trait`) keeps flowing through the existing
        ## deprecation alias rewrite to `spatial_unique`.
        new_path <- is_intercept_only || !is.null(mode_arg) ||
                    !is.null(mesh_arg)

        if (new_path) {
          ## Helper: extras to splice into the rewritten call (named
          ## args mesh/coords only -- mode/d are interpreted here, not
          ## forwarded).
          extras <- list()
          if (!is.null(mesh_arg))   extras$mesh   <- mesh_arg
          if (!is.null(coords_arg)) extras$coords <- coords_arg

          ## Augmented LHS (intercept + slope, per-trait + slope, ||):
          ## not yet supported by the engine. Stage 3 deliverable.
          ## Error with a clear redirect.
          if (!is_intercept_only && !is_zero_plus_trait) {
            cli::cli_abort(c(
              "{.fn spatial} augmented LHS is not yet supported.",
              "i" = "You wrote {.code spatial({deparse(bar)})}.",
              "x" = "Augmented LHS forms (intercept + slope, per-trait slopes, uncorrelated `||`) require {.strong Design 07 Stage 3} engine work (extending {.code n_traits} to {.code n_lhs_cols} in the TMB template).",
              ">" = "For Stage 2, use {.code 1 | site} (scalar mode) or {.code 0 + trait | coords} (with explicit {.arg mode = }). See {.code ?spatial}."
            ))
          }

          ## Validate mode.
          mode_str <- if (is.null(mode_arg)) NULL else as.character(mode_arg)
          if (is_intercept_only) {
            ## LHS = `1`: mode is degenerate. Default to "scalar"; accept
            ## explicit "scalar"; error on any other explicit value.
            if (is.null(mode_str)) mode_str <- "scalar"
            if (!identical(mode_str, "scalar")) {
              cli::cli_abort(c(
                "{.code mode = {.val {mode_str}}} is degenerate when LHS is {.code 1} (intercept-only).",
                "i" = "Use {.code 0 + trait} LHS for per-trait covariance modes."
              ))
            }
            ## Rewrite to spatial_scalar(0 + trait | coords, mesh = ...).
            ## The downstream spde engine reads neither side of the bar,
            ## so we synthesise the canonical bar regardless of what the
            ## user wrote on the RHS (could be `site`, `coords`, ...).
            new_bar <- call("|", call("+", 0, as.name("trait")),
                            as.name("coords"))
            new_call <- as.call(c(list(as.name("spatial_scalar"), new_bar),
                                  extras))
            return(rewrite(new_call))
          }

          ## LHS = `0 + trait`: mode is mandatory; pick from
          ## diag / indep / latent / dep.
          if (is.null(mode_str)) {
            cli::cli_abort(c(
              "{.fn spatial} requires {.arg mode} when LHS is {.code 0 + trait}.",
              "i" = "Choose one of {.val diag} (per-trait independent fields; = spatial_unique), {.val indep} (= spatial_indep), {.val latent} (reduced-rank shared spatial factors, requires {.arg d}; = spatial_latent), or {.val dep} (full unstructured T x T; = spatial_dep)."
            ))
          }
          valid_modes <- c("diag", "indep", "latent", "dep")
          if (!mode_str %in% valid_modes) {
            cli::cli_abort(c(
              "{.code mode = {.val {mode_str}}} is not a recognised mode.",
              "i" = "Valid modes for LHS = {.code 0 + trait}: {.val {valid_modes}}."
            ))
          }

          if (mode_str == "diag") {
            new_call <- as.call(c(list(as.name("spatial_unique"), bar),
                                  extras))
            return(rewrite(new_call))
          }
          if (mode_str == "indep") {
            new_call <- as.call(c(list(as.name("spatial_indep"), bar),
                                  extras))
            return(rewrite(new_call))
          }
          if (mode_str == "latent") {
            d_use <- if (is.null(d_arg)) 1 else d_arg
            new_call <- as.call(c(list(as.name("spatial_latent"), bar,
                                       d = d_use), extras))
            return(rewrite(new_call))
          }
          if (mode_str == "dep") {
            new_call <- as.call(c(list(as.name("spatial_dep"), bar),
                                  extras))
            return(rewrite(new_call))
          }
        }
      }
      ## For all spatial keywords, normalise the bar orientation
      ## (`coords | trait` -> `0 + trait | coords`) BEFORE the rename so
      ## the lifecycle deprecation warning fires once per keyword per
      ## session and downstream code sees only the canonical form.
      if (fn %in% c("spatial_unique", "spatial_scalar", "spatial_latent",
                    "spatial", "spatial_indep", "spatial_dep")) {
        e <- normalise_spatial_orientation(e)
      }
      ## latent / unique / phylo_latent / spatial_unique: just rename the head
      if (fn %in% c("latent", "phylo_latent", "spatial_unique", "spatial")) {
        ## Stage 2.5 (May 2026): fail-loud against augmented LHS for the
        ## BARE `latent()` keyword. `phylo_latent` / `spatial_unique` /
        ## `spatial` already fail loud through their own dedicated guards
        ## (phylo_indep/phylo_dep at line ~1672/1738, spatial via
        ## normalise_spatial_orientation at line ~1198), so we only need
        ## to gate the non-phylo non-spatial `latent` here.
        if (identical(fn, "latent")) .assert_no_augmented_lhs(fn, e)
        target <- switch(fn,
                         latent         = "rr",
                         phylo_latent   = "phylo_rr",
                         spatial_unique = "spde",
                         spatial        = "spde")
        new_call <- e
        new_call[[1L]] <- as.name(target)
        return(new_call)
      }
      ## `unique(form, common = bool)` -> `diag(form, common = bool)`
      if (fn == "unique") {
        ## Stage 2.5: fail-loud against augmented LHS.
        .assert_no_augmented_lhs(fn, e)
        new_call <- e
        new_call[[1L]] <- as.name("diag")
        return(new_call)
      }
      ## `phylo(formula, mode = ..., tree = ..., d = ...)` ->
      ## one of phylo_scalar / phylo_unique / phylo_indep / phylo_latent /
      ## phylo_dep based on (LHS, mode). Design 07 Stage 2.
      ##
      ## Only fires when the first argument is an lme4-bar formula
      ## (i.e. a call with head `|`). Legacy bare-name calls like
      ## `phylo(species)` and `phylo(species, vcv = Cphy)` fall through
      ## to the existing legacy rewrite in walk() (line ~1505) which
      ## maps them to `propto(0 + species | trait)`.
      if (fn == "phylo" && length(e) >= 2L && is.call(e[[2L]]) &&
          identical(e[[2L]][[1L]], as.name("|"))) {
        bar      <- e[[2L]]
        lhs      <- bar[[2L]]
        rhs      <- bar[[3L]]   # the species factor (bare name)
        ## Inspect named args.
        args_named <- as.list(e)[-c(1L, 2L)]
        nms        <- names(args_named)
        if (is.null(nms)) nms <- rep("", length(args_named))
        get_arg <- function(name, default = NULL) {
          ix <- which(nms == name)
          if (length(ix) == 0L) return(default)
          args_named[[ix[1L]]]
        }
        mode_arg <- get_arg("mode", default = NULL)
        tree_arg <- get_arg("tree", default = NULL)
        vcv_arg  <- get_arg("vcv",  default = NULL)
        d_arg    <- get_arg("d",    default = NULL)

        ## Helper: extras to splice into the rewritten call (named args
        ## tree/vcv only -- mode/d are interpreted here, not forwarded).
        extras <- list()
        if (!is.null(tree_arg)) extras$tree <- tree_arg
        if (!is.null(vcv_arg))  extras$vcv  <- vcv_arg

        ## Detect LHS shape.
        is_intercept_only <- (is.numeric(lhs) && length(lhs) == 1L &&
                              lhs == 1) ||
                             (is.symbol(lhs) && identical(as.character(lhs), "1"))
        is_zero_plus_trait <- is.call(lhs) &&
          identical(lhs[[1L]], as.name("+")) &&
          length(lhs) == 3L &&
          is.numeric(lhs[[2L]]) && lhs[[2L]] == 0 &&
          is.symbol(lhs[[3L]]) && identical(as.character(lhs[[3L]]),
                                            "trait")

        ## Augmented LHS (intercept + slope, per-trait + slope, ||): not
        ## yet supported by the engine. Stage 3 deliverable. Error with
        ## a clear redirect.
        if (!is_intercept_only && !is_zero_plus_trait) {
          cli::cli_abort(c(
            "{.fn phylo} augmented LHS is not yet supported.",
            "i" = "You wrote {.code phylo({deparse(bar)})}.",
            "x" = "Augmented LHS forms (intercept + slope, per-trait slopes, uncorrelated `||`) require {.strong Design 07 Stage 3} engine work (extending {.code n_traits} to {.code n_lhs_cols} in the TMB template).",
            ">" = "For Stage 2, use {.code 1 | species} (scalar mode) or {.code 0 + trait | species} (with explicit {.arg mode = }). See {.code ?phylo}."
          ))
        }

        ## Validate mode.
        mode_str <- if (is.null(mode_arg)) NULL else as.character(mode_arg)
        if (is_intercept_only) {
          ## LHS = `1`: mode is degenerate. Default to "scalar"; accept
          ## explicit "scalar"; error on any other explicit value.
          if (is.null(mode_str)) mode_str <- "scalar"
          if (!identical(mode_str, "scalar")) {
            cli::cli_abort(c(
              "{.code mode = {.val {mode_str}}} is degenerate when LHS is {.code 1} (intercept-only).",
              "i" = "Use {.code 0 + trait} LHS for per-trait covariance modes."
            ))
          }
          ## Rewrite to phylo_scalar(rhs, tree = tree, vcv = vcv).
          new_call <- as.call(c(list(as.name("phylo_scalar"), rhs), extras))
          return(rewrite(new_call))   # recurse so phylo_scalar -> engine
        }

        ## LHS = `0 + trait`: mode is mandatory; pick from
        ## diag / indep / latent / dep.
        if (is.null(mode_str)) {
          cli::cli_abort(c(
            "{.fn phylo} requires {.arg mode} when LHS is {.code 0 + trait}.",
            "i" = "Choose one of {.val diag} (per-trait variances on A; = phylo_unique), {.val indep} (= phylo_indep), {.val latent} (reduced-rank cross-trait, requires {.arg d}; = phylo_latent), or {.val dep} (full unstructured T x T; = phylo_dep)."
          ))
        }
        valid_modes <- c("diag", "indep", "latent", "dep")
        if (!mode_str %in% valid_modes) {
          cli::cli_abort(c(
            "{.code mode = {.val {mode_str}}} is not a recognised mode.",
            "i" = "Valid modes for LHS = {.code 0 + trait}: {.val {valid_modes}}."
          ))
        }

        if (mode_str == "diag") {
          ## phylo_unique(rhs, tree = ..., vcv = ...).
          new_call <- as.call(c(list(as.name("phylo_unique"), rhs), extras))
          return(rewrite(new_call))
        }
        if (mode_str == "indep") {
          ## phylo_indep(0 + trait | species, tree = ..., vcv = ...).
          new_call <- as.call(c(list(as.name("phylo_indep"), bar), extras))
          return(rewrite(new_call))
        }
        if (mode_str == "latent") {
          ## phylo_latent(species, d = K, tree = ..., vcv = ...).
          d_use <- if (is.null(d_arg)) 1 else d_arg
          new_call <- as.call(c(list(as.name("phylo_latent"), rhs,
                                     d = d_use), extras))
          return(rewrite(new_call))
        }
        if (mode_str == "dep") {
          ## phylo_dep(0 + trait | species, tree = ..., vcv = ...).
          new_call <- as.call(c(list(as.name("phylo_dep"), bar), extras))
          return(rewrite(new_call))
        }
      }
      ## `phylo_scalar(species)` -> `phylo(species)`
      if (fn == "phylo_scalar") {
        new_call <- e
        new_call[[1L]] <- as.name("phylo")
        return(new_call)
      }
      ## `phylo_unique(species)` -> `phylo_rr(species, .phylo_unique = TRUE)`
      ## fit-multi.R adds a diagonal lambda_constraint and sets d = n_traits
      ## when it detects the marker, so the engine reuses the phylo_rr
      ## machinery without a new TMB switch.
      if (fn == "phylo_unique") {
        extras <- .pass_through_extras(e, c("tree", "vcv"))
        new_call <- as.call(c(list(as.name("phylo_rr"), e[[2L]]),
                              list(.phylo_unique = TRUE),
                              extras))
        return(new_call)
      }
      ## `spatial_scalar(form)` -> `spde(form, .spatial_scalar = TRUE)`
      ## fit-multi.R ties log_tau_spde across traits via the map mechanism
      ## when it sees the marker.
      if (fn == "spatial_scalar") {
        extras <- .pass_through_extras(e, c("coords", "mesh"))
        new_call <- as.call(c(list(as.name("spde"), e[[2L]]),
                              list(.spatial_scalar = TRUE),
                              extras))
        return(new_call)
      }
      ## `spatial_latent(form, d)` -> `spde(form, .spatial_latent = TRUE, d = d)`.
      ## fit-multi.R flips the cpp template's `spde_lv_k` switch to d and
      ## allocates Lambda_spde (T x K_S) plus K_S shared spatial fields.
      if (fn == "spatial_latent") {
        nm <- names(e)
        d_val <- if (!is.null(nm) && "d" %in% nm) e[[which(nm == "d")]] else 1L
        extras <- .pass_through_extras(e, c("coords", "mesh"))
        new_call <- as.call(c(list(as.name("spde"), e[[2L]]),
                              list(.spatial_latent = TRUE, d = d_val),
                              extras))
        return(new_call)
      }
      ## `indep(form)` -> `diag(form, .indep = TRUE)`
      ## Same engine path as `unique()` (the `diag` covstruct with no
      ## `common = TRUE` flag). The `.indep` marker only changes the
      ## printed label and lets fit-multi.R fire the indep+latent
      ## over-parameterisation guard.
      if (fn == "indep") {
        ## Stage 2.5: fail-loud against augmented LHS.
        .assert_no_augmented_lhs(fn, e)
        new_call <- as.call(c(list(as.name("diag"), e[[2L]]),
                              list(.indep = TRUE)))
        return(new_call)
      }
      ## `phylo_indep(0 + trait | species)` -> `phylo_rr(species,
      ##                            .phylo_unique = TRUE, .indep = TRUE)`
      ## Reuses the phylo_unique-alone engine path (rank-T diagonal
      ## Lambda_phy on the phylogenetic correlation matrix). The `.indep`
      ## marker labels the printed term as `phylo_indep` and triggers the
      ## phylo_indep+phylo_latent over-parameterisation guard.
      if (fn == "phylo_indep") {
        bar <- e[[2L]]
        if (!(is.call(bar) && identical(bar[[1L]], as.name("|")) &&
              length(bar) == 3L)) {
          cli::cli_abort(c(
            "{.fn phylo_indep} expects a {.code 0 + trait | species} formula.",
            "i" = "Got: {.code {deparse(bar)}}.",
            ">" = "Use {.code phylo_indep(0 + trait | species)}."
          ))
        }
        lhs_bar <- bar[[2L]]
        species_arg <- bar[[3L]]
        if (!is.name(species_arg)) {
          cli::cli_abort(c(
            "{.fn phylo_indep} RHS must be a single column name (the species factor).",
            "i" = "Got RHS: {.code {deparse(species_arg)}}.",
            ">" = "Use {.code phylo_indep(0 + trait | species)}."
          ))
        }
        ## Future extensibility hook: `phylo_indep(0 + trait + trait:x | species)`
        ## is reserved for trait-specific phylogenetic random slopes. Recognise
        ## the syntax but error gracefully for now.
        if (!.is_zero_plus_trait(lhs_bar)) {
          cli::cli_abort(c(
            "{.fn phylo_indep} LHS richer than {.code 0 + trait} is not yet supported.",
            "i" = "Got LHS: {.code {deparse(lhs_bar)}}.",
            ">" = "Trait-specific phylogenetic random slopes (e.g. {.code phylo_indep(0 + trait + trait:x | species)}) are reserved for a future release; use {.code phylo_indep(0 + trait | species)} for the per-trait phylogenetic variance fit."
          ))
        }
        extras <- .pass_through_extras(e, c("tree", "vcv"))
        new_call <- as.call(c(list(as.name("phylo_rr"), species_arg),
                              list(.phylo_unique = TRUE, .indep = TRUE),
                              extras))
        return(new_call)
      }
      ## `spatial_indep(0 + trait | coords)` -> `spde(form, .spatial_indep = TRUE)`
      ## Same engine path as `spatial_unique()` (per-trait omega_spde with
      ## independent log_tau per trait). The `.spatial_indep` marker only
      ## changes the printed label and triggers the spatial_indep+spatial_latent
      ## over-parameterisation guard.
      if (fn == "spatial_indep") {
        extras <- .pass_through_extras(e, c("coords", "mesh"))
        new_call <- as.call(c(list(as.name("spde"), e[[2L]]),
                              list(.spatial_indep = TRUE),
                              extras))
        return(new_call)
      }
      ## `dep(0 + trait | g)` -> `rr(form, d = .deferred_n_traits, .dep = TRUE)`
      ## Same engine path as `latent(d = n_traits)` standalone. The packed
      ## lower-triangular Lambda at full rank is exactly the Cholesky factor
      ## L of an unstructured Sigma = L L^T (T(T+1)/2 free parameters). The
      ## `.dep` marker only changes the printed label and triggers the
      ## dep+{latent,unique,indep} over-parameterisation/redundancy guards.
      ##
      ## n_traits is resolved at parse time in fit-multi.R (we don't have
      ## access to `data` here); the `.deferred_n_traits` symbol is the
      ## marker that triggers the resolution. Mirrors the phylo_unique
      ## d = n_traits resolution pattern.
      if (fn == "dep") {
        ## Stage 2.5: fail-loud against augmented LHS.
        .assert_no_augmented_lhs(fn, e)
        new_call <- as.call(c(list(as.name("rr"), e[[2L]]),
                              list(d = as.name(".deferred_n_traits"),
                                   .dep = TRUE)))
        return(new_call)
      }
      ## `phylo_dep(0 + trait | species)` -> `phylo_rr(species,
      ##                                     d = .deferred_n_traits, .dep = TRUE)`
      ## Same engine path as `phylo_latent(species, d = n_traits)` standalone:
      ## full-rank packed-triangular Lambda_phy on the phylogenetic correlation
      ## matrix, which is exactly the Cholesky factor of unstructured Sigma_phy.
      if (fn == "phylo_dep") {
        bar <- e[[2L]]
        if (!(is.call(bar) && identical(bar[[1L]], as.name("|")) &&
              length(bar) == 3L)) {
          cli::cli_abort(c(
            "{.fn phylo_dep} expects a {.code 0 + trait | species} formula.",
            "i" = "Got: {.code {deparse(bar)}}.",
            ">" = "Use {.code phylo_dep(0 + trait | species)}."
          ))
        }
        lhs_bar <- bar[[2L]]
        species_arg <- bar[[3L]]
        if (!is.name(species_arg)) {
          cli::cli_abort(c(
            "{.fn phylo_dep} RHS must be a single column name (the species factor).",
            "i" = "Got RHS: {.code {deparse(species_arg)}}.",
            ">" = "Use {.code phylo_dep(0 + trait | species)}."
          ))
        }
        if (!.is_zero_plus_trait(lhs_bar)) {
          cli::cli_abort(c(
            "{.fn phylo_dep} LHS richer than {.code 0 + trait} is not yet supported.",
            "i" = "Got LHS: {.code {deparse(lhs_bar)}}.",
            ">" = "Use {.code phylo_dep(0 + trait | species)} for the full unstructured cross-trait phylogenetic covariance fit."
          ))
        }
        extras <- .pass_through_extras(e, c("tree", "vcv"))
        new_call <- as.call(c(list(as.name("phylo_rr"), species_arg),
                              list(d = as.name(".deferred_n_traits"),
                                   .dep = TRUE),
                              extras))
        return(new_call)
      }
      ## `spatial_dep(0 + trait | coords)` -> `spde(form, .spatial_latent = TRUE,
      ##                                            d = .deferred_n_traits, .dep = TRUE)`
      ## Same engine path as `spatial_latent(form, d = n_traits)` standalone:
      ## the K_S = T case of the spatial latent factor model, with the
      ## packed-triangular Lambda_spde at full rank acting as the Cholesky
      ## factor of unstructured Sigma_spatial.
      if (fn == "spatial_dep") {
        ## Stage 2.5: fail-loud against augmented LHS. (Sister spatial
        ## keywords -- spatial_unique / spatial_indep / spatial_scalar /
        ## spatial_latent -- already fail loud via
        ## normalise_spatial_orientation at line ~1198.)
        .assert_no_augmented_lhs(fn, e)
        extras <- .pass_through_extras(e, c("coords", "mesh"))
        new_call <- as.call(c(list(as.name("spde"), e[[2L]]),
                              list(.spatial_latent = TRUE,
                                   d = as.name(".deferred_n_traits"),
                                   .dep = TRUE),
                              extras))
        return(new_call)
      }
      ## `meta_known_V(value, V = X)` -> `meta(value, sampling_var = X)`
      if (fn == "meta_known_V") {
        ## V= argument is named "V" (or positional 3rd arg); rename to
        ## sampling_var= which the existing meta() sugar consumes.
        new_call <- e
        new_call[[1L]] <- as.name("meta")
        nm <- names(new_call)
        if (!is.null(nm)) {
          nm[nm == "V"] <- "sampling_var"
          names(new_call) <- nm
        }
        return(new_call)
      }
      ## Recurse into subexpressions
      for (i in seq_along(e)[-1L]) e[[i]] <- rewrite(e[[i]])
    }
    e
  }
  rhs <- formula[[length(formula)]]
  formula[[length(formula)]] <- rewrite(rhs)
  formula
}

## Scan the user's formula AST for deprecated keywords and emit
## one-shot soft warnings. Runs BEFORE any rewriting so we see what
## the user actually typed.
##
## Deprecated keywords (each fires once per session):
##   rr        -> use latent()
##   diag      -> use unique()
##   phylo_rr  -> use phylo_latent()
##   phylo     -> use phylo_scalar()
##   spde      -> use spatial_unique()
##   spatial   -> use spatial_unique() (lifecycle::deprecate_warn at 0.1.2)
##   meta      -> use meta_known_V()
##   gr        -> use phylo_scalar() (or propto() power-user)
##   propto    -> internal; users should use phylo_scalar / phylo_latent
##   equalto   -> internal; users should use meta_known_V
##
## We do NOT warn on `propto` / `equalto` even though they're internal,
## because the brms-sugar layer rewrites phylo()/meta() to those before
## the parser sees them -- so they appear in every formula post-desugar.
scan_for_deprecated <- function(rhs) {
  deprecated_map <- list(
    rr        = list(new = "latent",         args = "0 + trait | g, d = K"),
    diag      = list(new = "unique",         args = "0 + trait | g"),
    phylo_rr  = list(new = "phylo_latent",   args = "species, d = K"),
    phylo     = list(new = "phylo_scalar",   args = "species"),
    spde      = list(new = "spatial_unique", args = "coords | trait"),
    meta      = list(new = "meta_known_V",   args = "value, V = V"),
    gr        = list(new = "phylo_scalar",   args = "species")
  )
  walk <- function(e) {
    if (is.call(e)) {
      fn <- as.character(e[[1L]])
      ## `spatial()` -> `spatial_unique()` is a fresh rename in 0.1.2;
      ## use lifecycle's deprecate_warn so it integrates with the
      ## standard tidyverse deprecation tooling and the `lifecycle`
      ## verbosity option.
      if (fn == "spatial") {
        lifecycle::deprecate_warn(
          when = "0.1.2",
          what = "spatial()",
          with = "spatial_unique()",
          details = c(
            "i" = "spatial(coords | trait) is now an alias for spatial_unique(0 + trait | coords), the unique cell of the 3 x 5 keyword grid.",
            ">" = "Update existing code to spatial_unique() to keep the rank explicit."
          )
        )
      } else if (fn %in% names(deprecated_map)) {
        d <- deprecated_map[[fn]]
        .gllvmTMB_warn_keyword_deprecated(fn, d$new, d$args)
      }
      for (i in seq_along(e)[-1L]) walk(e[[i]])
    }
    invisible(NULL)
  }
  walk(rhs)
  invisible(NULL)
}


desugar_brms_sugar <- function(formula,
                               trait_col = "trait",
                               obs_col   = "obs",
                               grp_V_col = "grp_V") {
  ## ---- Pass 0: scan the original AST for deprecated keywords and emit
  ## one-shot soft warnings. Done before any rewriting so we see what the
  ## user actually typed.
  scan_for_deprecated(formula[[length(formula)]])

  ## ---- Pass 1: rewrite canonical aliases (latent / unique / phylo_latent
  ## / phylo_scalar / spatial / meta_known_V) to engine-internal names.
  ## Done before the legacy brms desugaring below so e.g. phylo_scalar
  ## becomes phylo() which then becomes propto().
  formula <- rewrite_canonical_aliases(formula)

  walk <- function(e) {
    if (is.call(e)) {
      fn <- as.character(e[[1L]])
      if (fn == "phylo" || fn == "gr") {
        # phylo(species)             -> propto(0 + species | trait)        [recommended]
        # phylo(species, vcv = Cphy) -> propto(0 + species | trait, Cphy)  [backward-compat]
        # phylo(species, tree = phy) -> propto(0 + species | trait, tree = phy) [Phase L Stage 1]
        # gr(group)                  -> propto(0 + group   | trait)
        # gr(group,  cov = M)        -> propto(0 + group   | trait, M)
        # The covariance matrix used by the engine comes from the top-level
        # `phylo_vcv` argument to gllvmTMB(); the formula-level vcv/cov is
        # decorative and not consumed by the engine. The in-keyword
        # `tree =` IS consumed by fit-multi.R via cs$extra$tree -- this
        # path now forwards it as a named kwarg on propto so the
        # downstream Phase L Stage 1 harvester picks it up.
        species_arg <- e[[2L]]
        nm <- names(e)
        if (is.null(nm)) nm <- rep("", length(e))
        vcv_idx  <- which(nm %in% c("vcv", "cov"))
        tree_idx <- which(nm == "tree")
        if (length(vcv_idx) == 0L && length(tree_idx) == 0L &&
            length(e) >= 3L)
          vcv_idx <- 3L  # positional fallback only when no named args
        bar <- call("|", call("+", 0, species_arg), as.name(trait_col))
        out <- if (length(vcv_idx) > 0L) {
          call("propto", bar, e[[vcv_idx]])
        } else {
          call("propto", bar)
        }
        if (length(tree_idx) > 0L) {
          out[["tree"]] <- e[[tree_idx]]
        }
        return(out)
      }
      if (fn == "meta") {
        # meta(value, sampling_var = v) -> equalto(0 + obs | grp_V, V_diag)
        bar <- call("|", call("+", 0, as.name(obs_col)), as.name(grp_V_col))
        return(call("equalto", bar, as.name("V")))
      }
      for (i in seq_along(e)[-1L]) e[[i]] <- walk(e[[i]])
    }
    e
  }
  rhs <- formula[[length(formula)]]
  formula[[length(formula)]] <- walk(rhs)
  formula
}
