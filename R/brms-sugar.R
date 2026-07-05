## Formula keyword sugar for gllvmTMB.
##
## The package exposes a layer of plain-English formula keywords that
## desugar to the underlying glmmTMB-style covstruct calls. The new
## canonical names match the unit x trait framework directly. The full
## 4 x 5 keyword grid (correlation source x mode) is:
##
##                    | scalar           | unique           | latent
##   -----------------+------------------+------------------+-------------------
##   none             | (no keyword)     | unique()         | latent()
##   animal           | animal_scalar()  | animal_unique()  | animal_latent()
##   phylo            | phylo_scalar()   | phylo_unique()   | phylo_latent()
##   spatial          | spatial_scalar() | spatial_unique() | spatial_latent()
##
## The "clean quartet" for explicit covstruct intent:
##
##   * `latent(...)`        --- shared cross-trait covariance (Sigma_shared = Lambda Lambda^T)
##   * `unique(...)`        --- trait-specific residual paired with `latent()` (Sigma_unique = Psi)
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
##   meta_V(V = V)                                meta(sampling_var = V)
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
.gllvmTMB_warn_keyword_deprecated <- function(
  old,
  new_name,
  args = "...",
  guidance = NULL,
  see = NULL
) {
  if (!isTRUE(.gllvmTMB_deprecation_seen[[old]])) {
    ## Use our own env-based tracker only (no cli `.frequency = "once"`)
    ## so that test code can re-trigger the warning by unbinding the
    ## tracker entry without fighting cli's internal frequency cache.
    msg <- c(
      "!" = "Formula keyword {.fn {old}} is a deprecated alias; use {.fn {new_name}} for new code.",
      "i" = "{.code {new_name}({args})} =/=> {.code {old}({args})}",
      ">" = paste0(
        "Aliases will be dropped at the next minor release. See ",
        see %||% "{.code ?diag_re} / {.fn latent}",
        "."
      )
    )
    if (!is.null(guidance)) {
      msg <- c(msg, ">" = guidance)
    }
    cli::cli_inform(msg)
    .gllvmTMB_deprecation_seen[[old]] <- TRUE
  }
  invisible(NULL)
}

.gllvmTMB_warn_unique_family_deprecated <- function(fn) {
  lifecycle::deprecate_soft(
    when = "0.2.0",
    what = I(sprintf("The `%s()` formula keyword", fn)),
    details = c(
      "i" = "`unique()` / `*_unique()` are compatibility syntax while Psi moves into the latent-family grammar.",
      ">" = "For standalone diagonal tiers, use `indep()` / `*_indep()`; ordinary `latent()` now carries Psi by default, while source-specific folds and removal remain future slices."
    ),
    id = sprintf("gllvmTMB-unique-family-%s", fn)
  )
  invisible(NULL)
}

## Resolve the `latent(..., unique = )` argument from a parsed call. `unique =
## TRUE` (default) keeps the per-trait unique-variance diagonal Psi companion;
## `unique = FALSE` requests the rotation-invariant low-rank-only subset. The
## legacy `residual = ` spelling is a soft-deprecated alias. Shared by the
## ordinary intercept-only and the augmented random-regression `latent`
## branches.
.gllvmTMB_resolve_latent_unique <- function(e) {
  unique_arg <- e[["unique"]]
  residual_arg <- e[["residual"]]
  if (!is.null(residual_arg)) {
    if (!is.null(unique_arg)) {
      cli::cli_abort(c(
        "Pass only one of {.arg unique} or the deprecated {.arg residual} to {.fn latent}.",
        ">" = "Use {.arg unique} for new code."
      ))
    }
    lifecycle::deprecate_warn(
      when = "0.2.0",
      what = I("The `residual` argument of `latent()`"),
      with = I("the `unique` argument"),
      details = c(
        "i" = "The diagonal Psi companion is now controlled by `unique = ` (default `TRUE`).",
        ">" = "Replace `residual = FALSE` with `unique = FALSE`."
      ),
      id = "gllvmTMB-latent-residual"
    )
    unique_arg <- residual_arg
  }
  if (is.null(unique_arg)) {
    return(TRUE)
  }
  if (!is.logical(unique_arg) || length(unique_arg) != 1L || is.na(unique_arg)) {
    cli::cli_abort(c(
      "{.arg unique} in {.fn latent} must be a literal {.code TRUE} or {.code FALSE}.",
      ">" = "Use {.code latent(..., unique = FALSE)} for the low-rank-only subset."
    ))
  }
  unique_arg
}

#' Phylogenetic random effect: lme4-bar mode-dispatch wrapper
#'
#' `phylo()` is a unified entry point for the package's five canonical
#' phylogenetic keywords (`phylo_scalar`, `phylo_unique`, `phylo_indep`,
#' `phylo_latent`, `phylo_dep`). It accepts an lme4-bar formula on the
#' first argument and dispatches to the appropriate canonical keyword
#' based on the LHS shape and the optional `mode = ...` argument. The
#' five canonical keywords stay first-class -- `phylo()` is an additive
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
#' `0 + trait`, `mode` is **mandatory** -- choosing between `"diag"` /
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
#' Augmented LHS forms -- `1 + x` (intercept + slope), `0 + trait + (0 + trait):x`
#' (per-trait intercepts + per-trait slopes on covariate `x`), `x || species`
#' (uncorrelated) -- are reserved for Design 07 Stage 3 engine work. The
#' parser currently raises an error pointing at this status.
#'
#' @section Cross-package coexistence:
#' drmTMB also exposes `phylo(1 | species, tree = tree)` with the same
#' Hadfield-Nakagawa sparse \eqn{\mathbf A^{-1}} internal path. Both
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
#'                   data    = df,
#'                   trait   = "trait",
#'                   unit    = "species",
#'                   cluster = "species")
#' # Per-trait phylogenetic variances on shared A (= phylo_unique)
#' fit_u <- gllvmTMB(value ~ 0 + trait +
#'                     phylo(0 + trait | species, mode = "diag", tree = tree),
#'                   data    = df,
#'                   trait   = "trait",
#'                   unit    = "species",
#'                   cluster = "species")
#' # Reduced-rank cross-trait phylogenetic decomposition (= phylo_latent)
#' fit_l <- gllvmTMB(value ~ 0 + trait +
#'                     phylo(0 + trait | species, mode = "latent",
#'                           d = 2, tree = tree),
#'                   data    = df,
#'                   trait   = "trait",
#'                   unit    = "species",
#'                   cluster = "species")
#' # Backward-compat: legacy bare-name form
#' Cphy <- vcv(tree, corr = TRUE)
#' fit_legacy <- gllvmTMB(value ~ 0 + trait + phylo(species),
#'                        data      = df,
#'                        trait     = "trait",
#'                        unit      = "species",
#'                        cluster   = "species",
#'                        phylo_vcv = Cphy)
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
#'          data       = df,
#'          trait      = "trait",
#'          unit       = "species",
#'          cluster    = "species",
#'          phylo_tree = tree)
#'
#' # legacy: pass dense covariance only
#' gllvmTMB(value ~ 0 + trait + phylo_rr(species, d = 2),
#'          data      = df,
#'          trait     = "trait",
#'          unit      = "species",
#'          cluster   = "species",
#'          phylo_vcv = Cphy)
#' ```
#'
#' @param species An unquoted column name giving the species factor.
#'   Levels must match the rownames of `phylo_vcv` passed to
#'   [gllvmTMB()].
#' @param d Integer; the number of phylogenetic latent factors.
#'
#' @return A formula marker; never evaluated.
#' @export
#' @keywords internal
#' @examples
#' \dontrun{
#' library(ape)
#' tree   <- rcoal(20); tree$tip.label <- paste0("sp", 1:20)
#' Cphy   <- vcv(tree, corr = TRUE)
#' fit <- gllvmTMB(value ~ 0 + trait + phylo_rr(species, d = 2),
#'                 data      = df,
#'                 trait     = "trait",
#'                 unit      = "species",
#'                 cluster   = "species",
#'                 phylo_vcv = Cphy)
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
#' @keywords internal
#' @examples
#' \dontrun{
#' # Recommended:
#' fit <- gllvmTMB(value ~ 0 + trait + gr(species),
#'                 data      = df,
#'                 trait     = "trait",
#'                 unit      = "species",
#'                 cluster   = "species",
#'                 phylo_vcv = Cphy)
#' # Also valid (cov = Cphy ignored by engine):
#' fit <- gllvmTMB(value ~ 0 + trait + gr(species, cov = Cphy),
#'                 data      = df,
#'                 trait     = "trait",
#'                 unit      = "species",
#'                 cluster   = "species",
#'                 phylo_vcv = Cphy)
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
#' **Deprecated alias.** Use [meta_V()] in new code:
#' `meta_V(V = V)`.
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
#'   Deprecated in favour of `meta_V(V = V)`.
#'
#' @return A formula marker; never evaluated.
#' @seealso [meta_V()] (canonical replacement); [block_V()] for
#'   constructing a block-diagonal sampling-V from a study factor;
#'   [gllvmTMB()] for the stage-2 fit.
#' @export
#' @keywords internal
#' @examples
#' \dontrun{
#' # Preferred (canonical) form -- use meta_V():
#' V    <- diag(stage1_summary$sampling_var)
#' fit2 <- gllvmTMB(value ~ 0 + trait +
#'                    latent(0 + trait | site, d = 2) +
#'                    meta_V(V = V),
#'                  data    = stage1_summary,
#'                  trait   = "trait",
#'                  unit    = "site",
#'                  known_V = V)
#'
#' # Deprecated form (still works, emits a warning):
#' fit2 <- gllvmTMB(value ~ 0 + trait +
#'                    latent(0 + trait | site, d = 2) +
#'                    meta(value, sampling_var = sampling_var),
#'                  data    = stage1_summary,
#'                  trait   = "trait",
#'                  unit    = "site",
#'                  known_V = V)
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
#' By default, ordinary `latent()` now fits the canonical decomposition
#' \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi},
#' with the diagonal \eqn{\boldsymbol\Psi} companion included automatically:
#' ```r
#' value ~ 0 + trait + latent(0 + trait | unit, d = 2)
#' ```
#' Set `unique = FALSE` for the old low-rank-only / rotation-invariant subset.
#' For a scalar diagonal \eqn{\boldsymbol\Psi} companion shared across traits,
#' use `common = TRUE`; this replaces the legacy paired
#' `latent(..., unique = FALSE) + unique(..., common = TRUE)` spelling for
#' ordinary intercept-only latent terms.
#'
#' For the augmented random-regression form -- `latent(1 + x | g)` (wide) or
#' `latent(0 + trait + (0 + trait):x | g)` (long) -- the per-trait
#' unique-variance diagonal \eqn{\boldsymbol\Psi} companion is likewise on by
#' default and is controlled by `unique = TRUE` (the default) or
#' `unique = FALSE` (the low-rank-only, rotation-invariant subset). On this
#' augmented form `residual =` is a soft-deprecated alias for `unique =`. For
#' non-Gaussian families the estimated diagonal stays off and the family/link
#' latent-scale residual is used instead (see the `link_residual` argument of
#' [extract_Sigma()]); the free intercept-slope correlation lives in the shared
#' reduced-rank block and is unaffected by `unique`.
#'
#' @param formula `0 + trait | g` style formula (LHS is the response
#'   factor, typically `0 + trait`; RHS is the grouping factor).
#' @param d Integer; number of latent factors.
#' @param unique Logical; `TRUE` (default) auto-includes the diagonal
#'   trait-unique \eqn{\boldsymbol\Psi} companion. Set `FALSE` for the
#'   low-rank-only / rotation-invariant subset. Renamed from `residual` in
#'   gllvmTMB 0.2.0.
#' @param common Logical; `FALSE` (default) estimates one diagonal
#'   \eqn{\boldsymbol\Psi} variance per trait. `TRUE` ties the default ordinary
#'   diagonal \eqn{\boldsymbol\Psi} companion to one shared variance across
#'   traits. Only applies when `unique = TRUE`.
#' @param residual `r lifecycle::badge("deprecated")` Soft-deprecated alias for
#'   `unique`; passing `residual =` emits a deprecation warning and is mapped to
#'   `unique =`.
#' @return A formula marker; never evaluated.
#' @seealso [unique()], [phylo_latent()], [diag_re], [extract_Sigma()].
#' @export
latent <- function(formula, d = 1, unique = TRUE, common = FALSE,
                   residual = lifecycle::deprecated()) {
  invisible(NULL)
}

#' Trait-specific unique variance: `unique(0 + trait | g)`
#'
#' `r lifecycle::badge("deprecated")`
#'
#' `unique()` is soft-deprecated as compatibility syntax in gllvmTMB 0.2.0.
#' Use [indep()] for standalone marginal diagonal tiers, including
#' `indep(..., common = TRUE)` for the scalar standalone marginal case.
#' Ordinary `latent()` now carries \eqn{\boldsymbol\Psi} by default, so paired
#' `latent() + unique()` remains accepted as transition compatibility until the
#' later removal slice lands. The paired legacy `unique(..., common = TRUE)`
#' parsimony knob remains accepted, but new ordinary intercept-only code should
#' use `latent(..., common = TRUE)`.
#'
#' Canonical name for the trait-specific unique-variance covstruct
#' inside a `gllvmTMB()` formula. Formerly `diag(0 + trait | g)` --
#' same engine, new name. The new name avoids the clash with
#' `base::diag()`. The `diag()` keyword still works for backward compat
#' but emits a one-shot deprecation warning per session.
#'
#' Compatibility spelling inside a `gllvmTMB()` formula:
#' ```r
#' value ~ 0 + trait + latent(0 + trait | unit, d = 2) +
#'                     unique(0 + trait | unit)
#' ```
#' New code can write the ordinary decomposition as `latent()` alone; the
#' explicit `unique()` companion is retained for compatibility.
#'
#' This is a **formula keyword** -- it's recognised by the parser inside
#' a `gllvmTMB()` formula's RHS but is never evaluated as a function
#' call. `unique` is *not* exported as an R function (because that
#' would shadow `base::unique()`); the parser handles the symbol
#' directly.
#'
#' ## `common = TRUE` parsimony mode
#'
#' For new standalone marginal fits where the trait-specific \eqn{\sigma_S}
#' estimates are weakly identified, write `indep(..., common = TRUE)` to fit a
#' single shared \eqn{\sigma_S} across all traits at this tier (one parameter
#' instead of T). Legacy standalone `unique(..., common = TRUE)` remains accepted
#' and objective-equivalent as compatibility syntax. Paired
#' `latent() + unique(..., common = TRUE)` also remains compatibility syntax; new
#' ordinary intercept-only decompositions can write
#' `latent(..., common = TRUE)` instead.
#'
#' @param formula `0 + trait | g` style formula.
#' @param common `FALSE` (default) for trait-specific variances; `TRUE` for one
#'   shared variance across traits at this tier. For new standalone marginal
#'   code, prefer `indep(..., common = TRUE)`; for new paired ordinary
#'   intercept-only decompositions, prefer `latent(..., common = TRUE)`.
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
#'   (`n_species x n_species`). Legacy alias of `A =`.
#' @param A Tip-level relatedness matrix (`n_species x n_species`)
#'   -- alias of `vcv =`, aligned with the `animal_*` family's
#'   argument naming (M2.8b, 2026-05-17). Supply one of `tree`,
#'   `vcv`, or `A` / `Ainv`.
#' @param Ainv Sparse precision matrix (inverse of `A`). Densified
#'   via `solve()` internally for v0.2.0; sparse direct engine
#'   path is a v0.3.0 follow-up.
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
#'     data       = sim$data,
#'     trait      = "trait",
#'     unit       = "species",
#'     cluster    = "species",
#'     phylo_tree = tree
#'   )
#' }
#' @export
phylo_latent <- function(
  species,
  d = 1,
  tree = NULL,
  vcv = NULL,
  A = NULL,
  Ainv = NULL
) {
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
#'     data       = sim$data,
#'     trait      = "trait",
#'     unit       = "species",
#'     cluster    = "species",
#'     phylo_tree = tree
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
#'   (`n_species x n_species`). Legacy alias of `A =`.
#' @param A Tip-level relatedness matrix (`n_species x n_species`)
#'   -- alias of `vcv =`, aligned with the `animal_*` family's
#'   argument naming (M2.8b, 2026-05-17).
#' @param Ainv Sparse precision matrix (inverse of `A`).
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
#'     data       = sim$data,
#'     trait      = "trait",
#'     unit       = "species",
#'     cluster    = "species",
#'     phylo_tree = tree
#'   )
#' }
#' @export
phylo_scalar <- function(
  species,
  tree = NULL,
  vcv = NULL,
  A = NULL,
  Ainv = NULL
) {
  invisible(NULL)
}

#' Per-trait independent phylogenetic random intercepts: `phylo_unique(species)`
#'
#' `r lifecycle::badge("deprecated")`
#'
#' `phylo_unique()` is soft-deprecated as compatibility syntax in gllvmTMB
#' 0.2.0. Use [phylo_indep()] for standalone marginal diagonal phylogenetic
#' tiers. Paired explicit-Psi use remains accepted until the latent-Psi fold
#' lands.
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
#'   \item{**Paired with `phylo_latent()`** (paired PGLLVM, recommended)}{
#'     When written together with `phylo_latent(species, d = K)`, the
#'     two terms co-fit as **separate covariance components**:
#'     \deqn{\boldsymbol\Sigma_\text{phy} \;=\; \underbrace{\boldsymbol\Lambda_\text{phy}\boldsymbol\Lambda_\text{phy}^{\!\top}}_{\text{shared (rank K)}} \;+\; \underbrace{\boldsymbol\Psi_\text{phy}}_{\text{per-trait unique}}.}
#'     \eqn{\boldsymbol\Lambda_\text{phy}} is filled by the rank-K shared
#'     latent factors; \eqn{\boldsymbol\Psi_\text{phy}} carries
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
#'   (`n_species x n_species`). Legacy alias of `A =`.
#' @param A Tip-level relatedness matrix (`n_species x n_species`)
#'   -- alias of `vcv =`, aligned with the `animal_*` family's
#'   argument naming (M2.8b, 2026-05-17).
#' @param Ainv Sparse precision matrix (inverse of `A`).
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
#'     data       = sim$data,
#'     trait      = "trait",
#'     unit       = "species",
#'     cluster    = "species",
#'     phylo_tree = tree
#'   )
#' }
#' @export
phylo_unique <- function(
  species,
  tree = NULL,
  vcv = NULL,
  A = NULL,
  Ainv = NULL
) {
  invisible(NULL)
}

#' Per-trait independent spatial random fields: `spatial_unique(0 + trait | coords)`
#'
#' `r lifecycle::badge("deprecated")`
#'
#' `spatial_unique()` is soft-deprecated as compatibility syntax in gllvmTMB
#' 0.2.0. Use [spatial_indep()] for standalone marginal diagonal spatial
#' fields. Paired explicit-Psi use remains accepted until the latent-Psi fold
#' lands.
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
#'     data  = sim$data,
#'     trait = "trait",
#'     unit  = "site"
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
#'     data  = sim$data,
#'     trait = "trait",
#'     unit  = "site"
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
#' and toggles the TMB template's `spde_lv_k` switch to K. With
#' `unique = TRUE`, the same SPDE tier also keeps the per-trait
#' `omega_spde` fields active, giving
#' \eqn{\boldsymbol\Sigma_{\mathrm{spa}} =
#' \boldsymbol\Lambda_{\mathrm{spa}}\boldsymbol\Lambda_{\mathrm{spa}}^\top +
#' \boldsymbol\Psi_{\mathrm{spa}}}. The default `unique = FALSE` preserves
#' the older low-rank-only path. Legacy
#' `spatial_latent(...) + spatial_unique(...)` is accepted as compatibility
#' syntax for the same total-covariance decomposition.
#'
#' The C++ kernel
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
#' @param unique Logical; include a per-trait unique spatial diagonal
#'   companion. `FALSE` preserves the old low-rank-only
#'   `spatial_latent()` path; `TRUE` fits the total spatial covariance
#'   \eqn{\Lambda\Lambda^\top + \Psi}.
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
#'     data  = sim$data,
#'     trait = "trait",
#'     unit  = "site"
#'   )
#' }
#' @export
spatial_latent <- function(formula, d = 1, unique = FALSE,
                           coords = NULL, mesh = NULL) {
  invisible(NULL)
}

#' Spatial random field: lme4-bar mode-dispatch wrapper
#'
#' `spatial()` is a unified entry point for the package's five canonical
#' spatial keywords (`spatial_scalar`, `spatial_unique`, `spatial_indep`,
#' `spatial_latent`, `spatial_dep`). It accepts an lme4-bar formula on
#' the first argument and dispatches to the appropriate canonical
#' keyword based on the LHS shape and the optional `mode = ...` argument.
#' The five canonical keywords stay first-class -- `spatial()` is an
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
#' `0 + trait`, `mode` is **mandatory** -- choosing between `"diag"` /
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
#' Augmented LHS forms -- `1 + x` (intercept + slope), `0 + trait + (0 + trait):x`
#' (per-trait intercepts + per-trait slopes on covariate `x`), `x || coords`
#' (uncorrelated) -- are reserved for Design 07 Stage 3 engine work. The
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
#' @param unique Logical; for `mode = "latent"`, forward to
#'   [spatial_latent()] to include the per-trait unique spatial diagonal
#'   companion. Ignored by the non-latent dispatch modes.
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
#'                   data  = df,
#'                   trait = "trait",
#'                   unit  = "site")
#' # Per-trait independent fields on shared mesh (= spatial_unique)
#' fit_u <- gllvmTMB(value ~ 0 + trait +
#'                     spatial(0 + trait | coords, mode = "diag",
#'                             mesh = mesh),
#'                   data  = df,
#'                   trait = "trait",
#'                   unit  = "site")
#' # Reduced-rank shared spatial latent factors (= spatial_latent)
#' fit_l <- gllvmTMB(value ~ 0 + trait +
#'                     spatial(0 + trait | coords, mode = "latent",
#'                             d = 2, mesh = mesh),
#'                   data  = df,
#'                   trait = "trait",
#'                   unit  = "site")
#' # Backward-compat: legacy bare-formula form
#' fit_legacy <- gllvmTMB(value ~ 0 + trait + spatial(0 + trait | coords),
#'                        data  = df,
#'                        trait = "trait",
#'                        unit  = "site",
#'                        mesh  = mesh)
#' }
spatial <- function(formula, mesh = NULL, coords = NULL, mode = NULL, d = 1,
                    unique = FALSE) {
  ## Marker function. Body unused -- never called at evaluation time.
  invisible(NULL)
}

#' Known-V meta-analytic random effect (deprecated alias): `meta_known_V(V = V)`
#'
#' Deprecated alias for [meta_V()] (renamed 2026-05-16 per vision
#' item 4). Both names desugar identically; new code should prefer
#' `meta_V(V = V)`. The shorter `meta_V` is the canonical
#' 0.2.0 name; `meta_known_V` is retained as an alias for
#' back-compatibility.
#'
#' @param V Known sampling variance or covariance marker. In current
#'   exact-additive fits, pass the actual matrix via the top-level
#'   `known_V =` argument to [gllvmTMB()]. Formula-level `V = V` names
#'   the marker and keeps the syntax aligned with `drmTMB::meta_V()`.
#' @param type Sampling-covariance mode. `"exact"` is implemented.
#'   `"proportional"` is reserved for the planned post-CRAN extension
#'   and currently fails loud in the formula parser.
#' @return A formula marker; never evaluated.
#' @seealso [meta_V()] (canonical name; preferred for new code);
#'   [meta()] (older deprecated short alias); [block_V()];
#'   [gllvmTMB()].
#' @export
#' @keywords internal
meta_known_V <- function(V, type = "exact") {
  invisible(NULL)
}

#' Known-V meta-analytic random effect (canonical name): `meta_V(V = V)`
#'
#' Canonical formula keyword for the known-sampling-error term in
#' two-stage meta-regression workflows. The name makes it explicit
#' that what is "known" is the **V** matrix (the sampling-error
#' covariance). Renamed from [meta_known_V()] in 0.2.0 per vision
#' item 4 (2026-05-16); the older name is retained as a deprecated
#' alias. Both names desugar identically in the formula parser.
#'
#' Pass the matrix `V` via the top-level `known_V = V` argument to
#' [gllvmTMB()] when using the exact-additive (default) form. For
#' block-diagonal within-study correlation, build `V` via [block_V()].
#' The future proportional-sampling-variance mode will use
#' `type = "proportional"`; in 0.2.x this value is deliberately
#' rejected rather than silently treated as exact.
#'
#' @param V Known sampling variance or covariance marker. In current
#'   exact-additive fits, pass the actual matrix via the top-level
#'   `known_V =` argument to [gllvmTMB()]. Formula-level `V = V` names
#'   the marker and keeps the syntax aligned with `drmTMB::meta_V()`.
#' @param type Sampling-covariance mode. `"exact"` is implemented.
#'   `"proportional"` is reserved for the planned post-CRAN extension
#'   and currently fails loud in the formula parser.
#' @return A formula marker; never evaluated.
#' @seealso [meta_known_V()] (deprecated alias); [block_V()];
#'   [gllvmTMB()]; vision doc "Planned extensions" for the future
#'   `meta_V(type = "proportional")` mode (Nakagawa 2022).
#' @export
meta_V <- function(V, type = "exact") {
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
#'   \item{**Decomposition** (`latent` by default)}{Shared cross-trait
#'     covariance plus the default trait-specific Psi companion:
#'     \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi}.}
#'   \item{**Marginal** (`indep` standalone)}{Per-trait total variance
#'     with no cross-trait decomposition: \eqn{\boldsymbol\Sigma = \mathrm{diag}(\sigma^2_t)}.}
#' }
#'
#' Use `indep()` when you want to commit to the marginal-only
#' interpretation explicitly. Ordinary `latent()` now carries the
#' diagonal Psi companion by default when you want the cross-trait
#' decomposition; `unique()` standalone (e.g. for observation-level random
#' effects in mixed-response fits) remains compatibility syntax.
#'
#' For a scalar marginal-only tier with one variance shared by all traits,
#' use `common = TRUE`. This is the non-deprecated standalone replacement for
#' legacy `unique(..., common = TRUE)` when no `latent()` term is paired on the
#' same grouping.
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
#' @param common `FALSE` (default) for trait-specific marginal variances;
#'   `TRUE` to tie all traits to one shared variance at this grouping tier.
#' @return A formula marker; never evaluated.
#' @seealso [unique()], [latent()], [phylo_indep()], [spatial_indep()],
#'   [extract_Sigma()].
#' @export
#' @examples
#' \dontrun{
#' # Marginal-only fit (per-trait variance, identity correlation):
#' fit <- gllvmTMB(value ~ 0 + trait + indep(0 + trait | site),
#'                 data = df, trait = "trait", unit = "site")
#'
#' # Scalar marginal-only fit (one shared variance across traits):
#' fit <- gllvmTMB(value ~ 0 + trait + indep(0 + trait | site, common = TRUE),
#'                 data = df, trait = "trait", unit = "site")
#'
#' # ERROR: indep + latent on the same grouping is over-parameterised.
#' # gllvmTMB(value ~ 0 + trait +
#' #           indep(0 + trait | site) +
#' #           latent(0 + trait | site, d = 2), data = df)
#' }
indep <- function(formula, common = FALSE) {
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
#' \eqn{\boldsymbol\Sigma_{\text{phy}} = \boldsymbol\Lambda_{\text{phy}}\boldsymbol\Lambda_{\text{phy}}^\top + \boldsymbol\Psi_{\text{phy}}}.
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
#'   (`n_species x n_species`). Legacy alias of `A =`.
#' @param A Tip-level relatedness matrix (`n_species x n_species`)
#'   -- alias of `vcv =`, aligned with the `animal_*` family's
#'   argument naming (M2.8b, 2026-05-17).
#' @param Ainv Sparse precision matrix (inverse of `A`).
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
#'                 data    = df,
#'                 trait   = "trait",
#'                 unit    = "species",
#'                 cluster = "species")
#' }
phylo_indep <- function(
  formula,
  tree = NULL,
  vcv = NULL,
  A = NULL,
  Ainv = NULL
) {
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
#'     data  = sim$data,
#'     trait = "trait",
#'     unit  = "site"
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
#' is the number of traits) -- the engine's existing packed-triangular
#' \eqn{\boldsymbol\Lambda} at full rank IS the Cholesky factor of an
#' unstructured \eqn{\boldsymbol\Sigma}. The keyword choice is
#' documentary: `dep` declares user intent that the full unstructured
#' trait covariance is the model.
#'
#' This completes the structural-mode quartet:
#'
#' \describe{
#'   \item{**Decomposition** (`latent` by default)}{Shared low-rank
#'     loadings plus the default trait-specific Psi companion:
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
#'                 data = df, trait = "trait", unit = "site")
#'
#' # The mathematically-equivalent decomposition form (full rank):
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = T),
#'                 data = df, trait = "trait", unit = "site")
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
#'   (`n_species x n_species`). Legacy alias of `A =`.
#' @param A Tip-level relatedness matrix (`n_species x n_species`)
#'   -- alias of `vcv =`, aligned with the `animal_*` family's
#'   argument naming (M2.8b, 2026-05-17).
#' @param Ainv Sparse precision matrix (inverse of `A`).
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
#'     data       = sim$data,
#'     trait      = "trait",
#'     unit       = "species",
#'     cluster    = "species",
#'     phylo_tree = tree
#'   )
#' }
#' @export
phylo_dep <- function(formula, tree = NULL, vcv = NULL, A = NULL, Ainv = NULL) {
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
#'     data  = sim$data,
#'     trait = "trait",
#'     unit  = "site"
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
## placeholders only -- see `parse_multi_formula()` and `R/fit-multi.R`),
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
.strip_lhs_parens <- function(e) {
  while (
    is.call(e) &&
      identical(e[[1L]], as.name("(")) &&
      length(e) == 2L
  ) {
    e <- e[[2L]]
  }
  e
}

.is_one_lhs <- function(e) {
  e <- .strip_lhs_parens(e)
  (is.numeric(e) && length(e) == 1L && e == 1) ||
    (is.symbol(e) && identical(as.character(e), "1"))
}

.is_zero_plus_trait <- function(e) {
  ## TRUE if `e` is the call `0 + trait`, i.e. `+(0, trait)`.
  e <- .strip_lhs_parens(e)
  is.call(e) &&
    identical(e[[1L]], as.name("+")) &&
    length(e) == 3L &&
    is.numeric(e[[2L]]) &&
    length(e[[2L]]) == 1L &&
    e[[2L]] == 0 &&
    is.name(e[[3L]]) &&
    identical(as.character(e[[3L]]), "trait")
}

## Flatten a left-nested `a + b + c` LHS expression into the ordered list of
## its additive terms `list(a, b, c)`, stripping enclosing parens at every
## level. `1 + x1 + x2` parses as `+(+(1, x1), x2)`, so a single descent down
## the left `+` spine recovers `list(1, x1, x2)` in source order. A bare
## (non-`+`) expression returns a length-1 list. Used to generalise the
## augmented intercept+slope LHS from one covariate (s = 1) to s >= 1.
.flatten_lhs_plus <- function(e) {
  e <- .strip_lhs_parens(e)
  ## `0 + trait` is itself a `+` call but is an ATOMIC per-trait-intercept
  ## term (the leading term of the long form), never a `0`/`trait` pair to
  ## split. Treat it as a leaf so `0 + trait + (0+trait):x1 + ...` flattens to
  ## list(`0 + trait`, (0+trait):x1, ...) rather than splitting the head.
  if (.is_zero_plus_trait(e)) {
    return(list(e))
  }
  if (
    is.call(e) &&
      identical(e[[1L]], as.name("+")) &&
      length(e) == 3L
  ) {
    return(c(.flatten_lhs_plus(e[[2L]]), list(.strip_lhs_parens(e[[3L]]))))
  }
  list(e)
}

## Recognise the WIDE multi-slope LHS `1 + x1 + x2 + ...` (s >= 1 plain
## covariate names after the leading intercept `1`). Returns the ordered
## character vector of slope columns, or NULL when the shape does not match.
.assert_distinct_slope_cols <- function(cols) {
  dups <- unique(cols[duplicated(cols)])
  if (length(dups)) {
    dup_label <- paste(dups, collapse = ", ")
    cli::cli_abort(c(
      "Duplicate slope covariates are not allowed in augmented LHS terms.",
      "x" = "Repeated slope column(s): {.field {dup_label}}.",
      "i" = "Each slope column creates a separate random-effect block; duplicates make the design rank deficient.",
      ">" = "Use each slope covariate once, for example {.code 1 + x1 + x2 | group}."
    ))
  }
  invisible(cols)
}

.match_wide_intercept_slopes <- function(lhs) {
  terms <- .flatten_lhs_plus(lhs)
  if (length(terms) < 2L || !.is_one_lhs(terms[[1L]])) {
    return(NULL)
  }
  cols <- character(0L)
  for (term in terms[-1L]) {
    if (!is.name(term) || identical(as.character(term), "trait")) {
      return(NULL)
    }
    cols <- c(cols, as.character(term))
  }
  .assert_distinct_slope_cols(cols)
  cols
}

## Recognise the LONG multi-slope LHS
## `0 + trait + (0 + trait):x1 + (0 + trait):x2 + ...` (s >= 1 interactions
## after the leading `0 + trait`). Returns the ordered character vector of
## slope columns, or NULL when the shape does not match.
.match_long_intercept_slopes <- function(lhs) {
  terms <- .flatten_lhs_plus(lhs)
  if (length(terms) < 2L || !.is_zero_plus_trait(terms[[1L]])) {
    return(NULL)
  }
  cols <- character(0L)
  for (term in terms[-1L]) {
    slope <- .strip_lhs_parens(term)
    if (
      !(is.call(slope) &&
        identical(slope[[1L]], as.name(":")) &&
        length(slope) == 3L &&
        .is_zero_plus_trait(slope[[2L]]))
    ) {
      return(NULL)
    }
    sc <- .strip_lhs_parens(slope[[3L]])
    if (!is.name(sc) || identical(as.character(sc), "trait")) {
      return(NULL)
    }
    cols <- c(cols, as.character(sc))
  }
  .assert_distinct_slope_cols(cols)
  cols
}

## Single-slope (s == 1) LHS classifier -- the back-compatible contract shared
## by EVERY augmented covstruct keyword (phylo_unique/indep/latent,
## spatial_unique/indep/latent/dep, relmat_*, animal_*) and the predicate
## helpers below. It recognises ONLY the single-covariate augmented forms
## (`1 + x | g` wide, `0 + trait + (0 + trait):x | g` long); the leading
## intercept-only forms; everything else -- including the MULTI-slope
## `1 + x1 + x2 | g` -- stays `"unsupported"` exactly as before. Multi-slope is
## activated for the phylo_dep path ONLY, via `.gllvmTMB_lhs_form_multi()`.
.gllvmTMB_lhs_form <- function(lhs) {
  info <- .gllvmTMB_lhs_form_multi(lhs)
  if (
    info$lhs_form %in% c("wide_intercept_slope", "long_intercept_slope") &&
      length(info$slope_cols) != 1L
  ) {
    return(list(lhs_form = "unsupported", slope_col = NULL, slope_cols = NULL))
  }
  info
}

## Multi-slope (s >= 1) LHS classifier for the phylo_dep augmented path
## (RE-03). Identical to `.gllvmTMB_lhs_form()` for the single-covariate and
## intercept-only forms, but ADDITIONALLY accepts `1 + x1 + x2 + ... | g`
## (wide) and `0 + trait + (0 + trait):x1 + (0 + trait):x2 + ... | g` (long)
## with s >= 2 distinct slope covariates, returning the full ordered
## `slope_cols` vector (`slope_col` keeps the first for back-compat consumers).
.gllvmTMB_lhs_form_multi <- function(lhs) {
  lhs <- .strip_lhs_parens(lhs)
  if (.is_one_lhs(lhs) || .is_zero_plus_trait(lhs)) {
    return(list(lhs_form = "intercept_only", slope_col = NULL, slope_cols = NULL))
  }
  wide_cols <- .match_wide_intercept_slopes(lhs)
  if (!is.null(wide_cols)) {
    return(list(
      lhs_form = "wide_intercept_slope",
      slope_col = wide_cols[[1L]],
      slope_cols = wide_cols
    ))
  }
  long_cols <- .match_long_intercept_slopes(lhs)
  if (!is.null(long_cols)) {
    return(list(
      lhs_form = "long_intercept_slope",
      slope_col = long_cols[[1L]],
      slope_cols = long_cols
    ))
  }
  list(lhs_form = "unsupported", slope_col = NULL, slope_cols = NULL)
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
  if (!is.call(e) || length(e) < 2L) {
    return(invisible(NULL))
  }
  bar <- e[[2L]]
  if (
    !(is.call(bar) && identical(bar[[1L]], as.name("|")) && length(bar) == 3L)
  ) {
    return(invisible(NULL))
  }
  lhs <- .strip_lhs_parens(bar[[2L]])
  ## Match exactly the same shape detection the phylo()/spatial() wrappers
  ## use (df76c705 / 8b1ddc92): `1` (intercept-only) or `0 + trait`
  ## (per-trait intercepts). Anything else is augmented LHS, not yet
  ## supported by the engine.
  is_intercept_only <- (is.numeric(lhs) && length(lhs) == 1L && lhs == 1) ||
    (is.symbol(lhs) && identical(as.character(lhs), "1"))
  is_zero_plus_trait <- is.call(lhs) &&
    identical(lhs[[1L]], as.name("+")) &&
    length(lhs) == 3L &&
    is.numeric(lhs[[2L]]) &&
    lhs[[2L]] == 0 &&
    is.symbol(lhs[[3L]]) &&
    identical(as.character(lhs[[3L]]), "trait")
  if (is_intercept_only || is_zero_plus_trait) {
    return(invisible(NULL))
  }
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
  if (!is.call(e) || length(e) < 2L) {
    return(e)
  }
  fn <- as.character(e[[1L]])
  if (
    !(fn %in%
      c(
        "spatial_unique",
        "spatial_scalar",
        "spatial_latent",
        "spatial",
        "spatial_indep"
      ))
  ) {
    return(e)
  }
  bar <- e[[2L]]
  if (
    !(is.call(bar) && identical(bar[[1L]], as.name("|")) && length(bar) == 3L)
  ) {
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
  ## Design 60 §2.3 / §3.4: BASE augmented SPDE random-slope LHS.
  ## `spatial_unique(1 + x | coords)` (wide) and its long-form equivalent
  ## `spatial_unique(0 + trait + (0 + trait):x | coords)` -- and the same two
  ## forms for `spatial_indep` -- carry an intercept + slope LHS that the
  ## now-integrated base SPDE slope engine (use_spde_slope) consumes via a
  ## SECOND SPDE field on the covariate. The bar is already canonically
  ## oriented (RHS = the coords name); pass it through UNCHANGED so the
  ## per-keyword rename branch (`fn == "spatial_unique"` / `"spatial_indep"`)
  ## can classify the LHS and route it to `spde(..., .spatial_*_augmented =
  ## TRUE)`. The C++ dimension asserts (src/gllvmTMB.cpp:925-938) are the
  ## fail-loud backstop (Design 56 §7.1). Only `spatial_unique` and
  ## `spatial_indep` are wired in this slice; `spatial_latent` / `spatial_dep`
  ## augmented LHS need additional new C++ (Design 60 §3.5) and are NOT lifted
  ## here -- they fall through to the abort below.
  if (
    is.name(rhs) &&
      fn %in% c("spatial_unique", "spatial_indep") &&
      .gllvmTMB_lhs_form(lhs)$lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
  ) {
    return(e)
  }
  ## Design 64 §3: augmented spatial_latent(1 + x | coords) (wide) and its long
  ## form carry an intercept + slope LHS that the spatial_latent slope engine
  ## (use_spde_latent_slope) consumes via a per-column reduced-rank field
  ## structure. The bar is already canonically oriented (RHS = coords name);
  ## pass it through UNCHANGED so the per-keyword `fn == "spatial_latent"`
  ## branch can classify the LHS and route it to
  ## `spde(..., .spatial_latent_augmented = TRUE)`. (spatial_dep is NOT in this
  ## orientation list, so it bypasses normalisation and is handled directly in
  ## the `fn == "spatial_dep"` rename branch.)
  if (
    is.name(rhs) &&
      identical(fn, "spatial_latent") &&
      .gllvmTMB_lhs_form(lhs)$lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
  ) {
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
    if (!identical(as.character(rhs), "trait")) {
      cli::cli_abort(c(
        "{.fn {fn}} bar must be {.code 0 + trait | coords}.",
        "i" = "Got LHS = {.code {deparse(lhs)}}, RHS = {.code {deparse(rhs)}}.",
        "x" = "Only the deprecated orientation {.code coords | trait} may use a bare-name LHS/RHS pair.",
        ">" = "Use {.code {fn}(0 + trait | coords)} for the canonical spatial orientation."
      ))
    }
    ## Deprecated `coords | trait` orientation -- flip and warn (once).
    ## lifecycle::deprecate_warn() doesn't process cli markup in
    ## `details`, so we use plain backticks here for legibility.
    lifecycle::deprecate_warn(
      when = "0.1.4",
      what = I(sprintf("%s(coords | trait)", fn)),
      with = I(sprintf("%s(0 + trait | coords)", fn)),
      details = c(
        i = paste0(
          "The canonical formula orientation for spatial_* keywords is now ",
          "`0 + trait | coords`, matching `latent()`, `unique()`, and ",
          "glmmTMB's `gau(0 + trait | pos)` / `exp(0 + trait | pos)`."
        ),
        ">" = sprintf(
          "Update `%s(coords | trait)` to `%s(0 + trait | coords)`.",
          fn,
          fn
        )
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
##   indep(form, common = bool)       -> diag(form, common = bool, .indep = TRUE)
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
##   meta_V(V = V)                    -> meta(sampling_var = V)
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
    nms <- names(args)
    if (is.null(nms) || length(args) == 0L) {
      return(list())
    }
    args[nms %in% keep & nzchar(nms)]
  }
  .named_or_positional_arg <- function(e, name, position, default = NULL) {
    nm <- names(e)
    if (!is.null(nm)) {
      named_idx <- which(!is.na(nm) & nm == name)
      if (length(named_idx) > 0L) {
        return(e[[named_idx[[1L]]]])
      }
    }
    if (length(e) >= position) {
      pos_name <- ""
      if (!is.null(nm) && length(nm) >= position && !is.na(nm[[position]])) {
        pos_name <- nm[[position]]
      }
      if (!nzchar(pos_name)) {
        return(e[[position]])
      }
    }
    default
  }
  .abort_source_specific_lv <- function(e, fn) {
    nm <- names(e)
    if (is.null(nm) || !"lv" %in% nm) {
      return(invisible(NULL))
    }
    cli::cli_abort(c(
      "{.arg lv} is reserved for ordinary {.fn latent} only.",
      "x" = "{.fn {fn}} does not currently support predictor-informed latent means.",
      "i" = "Source-specific {.arg lv} support needs a separate structural-dependence gate; silently dropping {.arg lv} is not allowed.",
      ">" = "Remove {.code lv = ~ ...} from {.fn {fn}}, or use the supported structural random-slope syntax such as {.code {fn}(1 + env | group, d = K)} when that route is validated for the source."
    ))
  }
  .source_specific_lv_keywords <- c(
    "phylo", "phylo_scalar", "phylo_unique", "phylo_indep",
    "phylo_latent", "phylo_dep", "phylo_rr", "phylo_slope",
    "spatial", "spatial_scalar", "spatial_unique", "spatial_indep",
    "spatial_latent", "spatial_dep", "spde",
    "animal_scalar", "animal_unique", "animal_indep",
    "animal_latent", "animal_dep", "animal_slope",
    "kernel_latent", "kernel_unique", "kernel_indep", "kernel_dep"
  )
  .meta_type <- function(e, fn) {
    nm <- names(e)
    type_idx <- if (is.null(nm)) integer(0L) else which(nm == "type")
    if (length(type_idx) == 0L) {
      return("exact")
    }
    type_expr <- e[[type_idx[[1L]]]]
    if (!is.character(type_expr) || length(type_expr) != 1L) {
      cli::cli_abort(c(
        "{.fn {fn}} requires {.arg type} to be a literal string.",
        ">" = "Use {.code {fn}(V = V, type = \"exact\")}.",
        "i" = "{.code type = \"proportional\"} is planned but not implemented in 0.2.x."
      ))
    }
    valid_types <- c("exact", "proportional")
    if (!type_expr %in% valid_types) {
      cli::cli_abort(c(
        "{.fn {fn}} does not recognise {.arg type} = {.val {type_expr}}.",
        "i" = "{.code type = \"proportional\"} is planned but not implemented in 0.2.x.",
        ">" = "Use {.code type = \"exact\"}."
      ))
    }
    type <- type_expr
    if (identical(type, "proportional")) {
      cli::cli_abort(c(
        "{.code {fn}(type = \"proportional\")} is planned but not implemented.",
        "i" = "The current implementation supports exact additive known sampling covariance only.",
        ">" = "Use {.code {fn}(V = V, type = \"exact\")} with {.arg known_V = V}."
      ))
    }
    type
  }
  .meta_V_expr <- function(e, fn) {
    nm <- names(e)
    if (is.null(nm)) {
      nm <- rep("", length(e))
    }
    nm[is.na(nm)] <- ""
    V_idx <- which(nm == "V")
    if (length(V_idx) > 0L) {
      return(e[[V_idx[[1L]]]])
    }
    unnamed_idx <- which(nm == "")
    unnamed_idx <- unnamed_idx[unnamed_idx != 1L]
    if (length(unnamed_idx) >= 2L) {
      ## Back-compat for the old positional spelling
      ## `meta_V(value, V)` / `meta_known_V(value, V)`.
      return(e[[unnamed_idx[[2L]]]])
    }
    if (length(unnamed_idx) == 1L) {
      ## Canonical short spelling: `meta_V(V)`.
      return(e[[unnamed_idx[[1L]]]])
    }
    cli::cli_abort(c(
      "{.fn {fn}} requires a known sampling variance/covariance marker.",
      ">" = "Use {.code {fn}(V = V)} and pass the matrix itself as {.code known_V = V} to {.fn gllvmTMB}."
    ))
  }
  ## Animal-keyword input normaliser. Resolves any of `pedigree = ped`,
  ## `A = A_matrix`, `Ainv = Ainv_matrix` to an unevaluated expression
  ## that yields the dense relatedness matrix A when evaluated in the
  ## formula's environment (later, in parse_covstruct_call). Returns
  ## NULL if no relatedness input is given -- animal_slope() allows this
  ## (the engine reuses A from a sibling animal_* term in the same
  ## formula).
  .animal_resolve_vcv_call <- function(e, fn) {
    nm <- names(e)
    if (is.null(nm)) {
      if (fn == "animal_slope") {
        return(NULL)
      }
      cli::cli_abort(c(
        "{.fn {fn}} requires one of {.arg pedigree}, {.arg A}, or {.arg Ainv}.",
        ">" = "e.g. {.code {fn}(id, pedigree = ped)}."
      ))
    }
    if ("pedigree" %in% nm) {
      ped_expr <- e[[which(nm == "pedigree")]]
      ## Design 47 follow-on (2026-05-18): route pedigree through
      ## the sparse A^{-1} engine path. `pedigree_to_Ainv_sparse()`
      ## returns a sparse dgCMatrix; the phylo VCV preparation
      ## block in `R/fit-multi.R` detects sparse input and uses it
      ## directly as Ainv_phy_rr (mirroring the phylo_tree route at
      ## `R/fit-multi.R:1037`).
      return(bquote(pedigree_to_Ainv_sparse(.(ped_expr))))
    }
    if ("A" %in% nm) {
      return(e[[which(nm == "A")]])
    }
    if ("Ainv" %in% nm) {
      Ainv_expr <- e[[which(nm == "Ainv")]]
      ## If user passes a sparse Ainv directly, pass it through
      ## unchanged so fit-multi.R's sparse-Ainv path detects it.
      ## Dense Ainv inputs are inverted to dense A for the legacy
      ## dense path (preserves backward compatibility).
      return(bquote(.gllvmTMB_maybe_keep_sparse_ainv(.(Ainv_expr))))
    }
    if (fn == "animal_slope") {
      return(NULL)
    }
    cli::cli_abort(c(
      "{.fn {fn}} requires one of {.arg pedigree}, {.arg A}, or {.arg Ainv}.",
      ">" = "e.g. {.code {fn}(id, pedigree = ped)}."
    ))
  }
  rewrite <- function(e) {
    if (is.call(e)) {
      fn <- as.character(e[[1L]])
      if (fn %in% .source_specific_lv_keywords) {
        .abort_source_specific_lv(e, fn)
      }
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
      if (
        fn == "spatial" &&
          length(e) >= 2L &&
          is.call(e[[2L]]) &&
          identical(e[[2L]][[1L]], as.name("|"))
      ) {
        bar <- e[[2L]]
        lhs <- bar[[2L]]
        rhs <- bar[[3L]]
        ## Inspect named args.
        args_named <- as.list(e)[-c(1L, 2L)]
        nms <- names(args_named)
        if (is.null(nms)) {
          nms <- rep("", length(args_named))
        }
        get_arg <- function(name, default = NULL) {
          ix <- which(nms == name)
          if (length(ix) == 0L) {
            return(default)
          }
          args_named[[ix[1L]]]
        }
        mode_arg <- get_arg("mode", default = NULL)
        mesh_arg <- get_arg("mesh", default = NULL)
        coords_arg <- get_arg("coords", default = NULL)
        d_arg <- get_arg("d", default = NULL)

        ## Detect LHS shape.
        is_intercept_only <- (is.numeric(lhs) &&
          length(lhs) == 1L &&
          lhs == 1) ||
          (is.symbol(lhs) && identical(as.character(lhs), "1"))
        is_zero_plus_trait <- is.call(lhs) &&
          identical(lhs[[1L]], as.name("+")) &&
          length(lhs) == 3L &&
          is.numeric(lhs[[2L]]) &&
          lhs[[2L]] == 0 &&
          is.symbol(lhs[[3L]]) &&
          identical(as.character(lhs[[3L]]), "trait")

        ## The dispatch fires only when the user gave us a clear hint
        ## that they want the new path: an intercept-only LHS (`1`),
        ## an explicit `mode = ...`, or an explicit `mesh = ...`. The
        ## legacy form `spatial(0 + trait | coords)` (no mode, no mesh,
        ## LHS = `0 + trait`) keeps flowing through the existing
        ## deprecation alias rewrite to `spatial_unique`.
        new_path <- is_intercept_only ||
          !is.null(mode_arg) ||
          !is.null(mesh_arg)

        if (new_path) {
          ## Helper: extras to splice into the rewritten call (named
          ## args mesh/coords only -- mode/d are interpreted here, not
          ## forwarded).
          extras <- list()
          if (!is.null(mesh_arg)) {
            extras$mesh <- mesh_arg
          }
          if (!is.null(coords_arg)) {
            extras$coords <- coords_arg
          }

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
            if (is.null(mode_str)) {
              mode_str <- "scalar"
            }
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
            new_bar <- call(
              "|",
              call("+", 0, as.name("trait")),
              as.name("coords")
            )
            new_call <- as.call(c(
              list(as.name("spatial_scalar"), new_bar),
              extras
            ))
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
            new_call <- as.call(c(list(as.name("spatial_unique"), bar), extras))
            return(rewrite(new_call))
          }
          if (mode_str == "indep") {
            new_call <- as.call(c(list(as.name("spatial_indep"), bar), extras))
            return(rewrite(new_call))
          }
          if (mode_str == "latent") {
            d_use <- if (is.null(d_arg)) 1 else d_arg
            unique_use <- e[["unique"]]
            if (is.null(unique_use)) unique_use <- FALSE
            new_call <- as.call(c(
              list(as.name("spatial_latent"), bar, d = d_use,
                   unique = unique_use),
              extras
            ))
            return(rewrite(new_call))
          }
          if (mode_str == "dep") {
            new_call <- as.call(c(list(as.name("spatial_dep"), bar), extras))
            return(rewrite(new_call))
          }
        }
      }
      ## For all spatial keywords, normalise the bar orientation
      ## (`coords | trait` -> `0 + trait | coords`) BEFORE the rename so
      ## the lifecycle deprecation warning fires once per keyword per
      ## session and downstream code sees only the canonical form.
      if (
        fn %in%
          c(
            "spatial_unique",
            "spatial_scalar",
            "spatial_latent",
            "spatial",
            "spatial_indep",
            "spatial_dep"
          )
      ) {
        e <- normalise_spatial_orientation(e)
      }
      ## PHYLO `A =` / `Ainv =` alias normaliser. Per Design 14 sec 3
      ## (A-vs-V boundary): `A` / `Ainv` are the canonical relatedness
      ## inputs across phylo_* and animal_*; `vcv` is the legacy phylo
      ## input retained for backward compatibility. Translate `A =` /
      ## `Ainv =` to `vcv =` BEFORE the phylo_X branch dispatches, so
      ## the existing rewrite logic is unchanged.
      if (
        fn %in%
          c(
            "phylo_scalar",
            "phylo_unique",
            "phylo_latent",
            "phylo_indep",
            "phylo_dep"
          )
      ) {
        nm <- names(e)
        if (!is.null(nm) && "A" %in% nm) {
          if ("vcv" %in% nm) {
            cli::cli_abort(c(
              "{.fn {fn}} got both {.arg A} and {.arg vcv}.",
              "i" = "These are aliases -- supply only one."
            ))
          }
          e[["vcv"]] <- e[[which(nm == "A")]]
          e[["A"]] <- NULL
          nm <- names(e)
        }
        if (!is.null(nm) && "Ainv" %in% nm) {
          if ("vcv" %in% nm) {
            cli::cli_abort(c(
              "{.fn {fn}} got both {.arg Ainv} and {.arg vcv}.",
              "i" = "These are aliases -- supply only one."
            ))
          }
          Ainv_expr <- e[[which(nm == "Ainv")]]
          e[["vcv"]] <- bquote(solve(as.matrix(.(Ainv_expr))))
          e[["Ainv"]] <- NULL
        }
      }
      ## ANIMAL-model keyword family -- resolves `pedigree =` / `A =` /
      ## `Ainv =` to a `vcv =` named arg, then emits the same engine-
      ## recognised target form that the equivalent `phylo_*` branch
      ## emits. No new TMB likelihood, no parser change downstream;
      ## animal_* is sugar that routes through the existing phylo_rr /
      ## propto engine path. Per docs/design/14-known-relatedness-keywords.md.
      if (
        fn %in%
          c(
            "animal_scalar",
            "animal_unique",
            "animal_latent",
            "animal_indep",
            "animal_dep",
            "animal_slope"
          )
      ) {
        vcv_expr <- .animal_resolve_vcv_call(e, fn)
        nm <- names(e)
        ## animal_scalar(id, ...) -> phylo(id, vcv = A)   (then desugar to propto)
        if (fn == "animal_scalar") {
          new_call <- call("phylo", e[[2L]])
          new_call[["vcv"]] <- vcv_expr
          return(new_call)
        }
        ## animal_unique(id, ...) -> phylo_rr(id, .phylo_unique = TRUE, vcv = A)
        if (fn == "animal_unique") {
          .gllvmTMB_warn_unique_family_deprecated(fn)
          ## animal_unique(1 + x | id, pedigree = ped) is a CORRELATED
          ## intercept + slope additive-genetic reaction norm:
          ## vec(B) ~ N(0, Sigma_b (x) A), Sigma_b a 2x2 (intercept, slope)
          ## covariance with a FREE cross-correlation. Route it through the
          ## phylo_unique augmented engine -- byte-identical to the
          ## phylo_unique(1 + x | sp) branch and to animal_indep's augmented
          ## branch, but WITHOUT `.indep = TRUE`, so atanh_cor_b stays free
          ## (the intercept-slope correlation is estimated, not pinned to 0).
          ## No new C++; routes through the same b_phy_aug / log_sd_b /
          ## atanh_cor_b path as phylo_unique(1 + x | sp). Design 60 sec.3.6.
          ## For the diagonal (rho = 0) special case use animal_indep(1 + x | id).
          arg <- e[[2L]]
          arg_is_bar <- is.call(arg) &&
            identical(arg[[1L]], as.name("|")) &&
            length(arg) == 3L
          if (arg_is_bar) {
            lhs_info <- .gllvmTMB_lhs_form(arg[[2L]])
          }
          if (
            arg_is_bar &&
              lhs_info$lhs_form %in%
                c("wide_intercept_slope", "long_intercept_slope")
          ) {
            new_call <- as.call(c(
              list(as.name("phylo_slope"), arg),
              list(
                .phylo_unique_augmented = TRUE,
                lhs_form = lhs_info$lhs_form,
                slope_col = lhs_info$slope_col
              ),
              list(vcv = vcv_expr)
            ))
            return(new_call)
          }
          ## A bar whose LHS is neither intercept-only nor a recognised
          ## intercept+slope form (e.g. a slope-only or multi-covariate LHS)
          ## is genuinely unsupported here: fail loud rather than silently
          ## drop structure in the phylo_rr fall-through below.
          if (arg_is_bar && identical(lhs_info$lhs_form, "unsupported")) {
            cli::cli_abort(c(
              "{.fn animal_unique} augmented LHS form is not supported.",
              "i" = "You wrote {.code animal_unique({deparse(arg)})}.",
              "x" = "Only {.code 1 + x | id} (correlated intercept + slope) and the bare intercept-only {.code id} / {.code 0 + trait | id} forms are accepted.",
              ">" = "For a correlated intercept+slope reaction norm use {.code animal_unique(1 + x | id, pedigree = ped)}; for the diagonal case use {.code animal_indep(1 + x | id, pedigree = ped)}."
            ))
          }
          new_call <- as.call(c(
            list(as.name("phylo_rr"), e[[2L]]),
            list(.phylo_unique = TRUE),
            list(vcv = vcv_expr)
          ))
          return(new_call)
        }
        ## animal_latent(id, d = K, ...) -> phylo_rr(id, d = K, vcv = A)
        ## For an augmented intercept+slope bar (`1 + x | id` or the long form
        ## `0 + trait + (0 + trait):x | id`) the route mirrors `phylo_latent`
        ## (Design 56 Sec. 9.5a): the `.latent_slope` marker tells fit-multi.R
        ## to drive the block-diagonal reduced-rank latent-slope engine
        ## (use_phylo_latent_slope). No new C++; the vcv = A is forwarded.
        if (fn == "animal_latent") {
          d_val <- .named_or_positional_arg(e, "d", 3L, default = 1L)
          ## Detect augmented bar.
          arg <- e[[2L]]
          arg_is_bar <- is.call(arg) &&
            identical(arg[[1L]], as.name("|")) &&
            length(arg) == 3L
          if (arg_is_bar) {
            lhs_form <- .gllvmTMB_lhs_form(arg[[2L]])
            if (
              lhs_form$lhs_form %in%
                c("wide_intercept_slope", "long_intercept_slope")
            ) {
              species_arg <- arg[[3L]]
              new_call <- as.call(c(
                list(as.name("phylo_rr"), species_arg),
                list(d = d_val),
                list(
                  .latent_slope = TRUE,
                  lhs_form = lhs_form$lhs_form,
                  slope_col = lhs_form$slope_col
                ),
                list(vcv = vcv_expr)
              ))
              return(new_call)
            }
          }
          new_call <- as.call(c(
            list(as.name("phylo_rr"), e[[2L]]),
            list(d = d_val),
            list(vcv = vcv_expr)
          ))
          return(new_call)
        }
        ## animal_indep(0 + trait | id, ...) -> phylo_rr(id, .phylo_unique = TRUE,
        ##                                               .indep = TRUE, vcv = A)
        if (fn == "animal_indep") {
          bar <- e[[2L]]
          if (
            !(is.call(bar) &&
              identical(bar[[1L]], as.name("|")) &&
              length(bar) == 3L)
          ) {
            cli::cli_abort(c(
              "{.fn animal_indep} expects a {.code 0 + trait | id} formula.",
              "i" = "Got: {.code {deparse(bar)}}.",
              ">" = "Use {.code animal_indep(0 + trait | id, pedigree = ped)}."
            ))
          }
          species_arg <- bar[[3L]]
          ## Augmented intercept+slope LHS (`1 + x | id` or the long form
          ## `0 + trait + (0 + trait):x | id`). animal_indep means the
          ## intercept-slope correlation is FIXED at 0, i.e. the SAME
          ## augmented b_phy_aug engine as phylo_indep() / phylo_unique()
          ## but with the structural matrix A (pedigree/A/Ainv) supplied
          ## via vcv, and atanh_cor_b pinned to 0 via the TMB map
          ## (fit-multi.R reads the `.indep` marker). No new C++.
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            new_call <- as.call(c(
              list(as.name("phylo_slope"), bar),
              list(
                .phylo_unique_augmented = TRUE,
                .indep = TRUE,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              list(vcv = vcv_expr)
            ))
            return(new_call)
          }
          new_call <- as.call(c(
            list(as.name("phylo_rr"), species_arg),
            list(.phylo_unique = TRUE, .indep = TRUE),
            list(vcv = vcv_expr)
          ))
          return(new_call)
        }
        ## animal_dep(bar, ...) -> for intercept-only bar: phylo_rr(id, .dep, vcv=A)
        ##                         for augmented bar (1 + x | id or long form):
        ##                           phylo_slope(bar, .phylo_dep_augmented, vcv=A)
        ## Mirrors `phylo_dep` (Design 56 Sec. 9.5c): the `.phylo_dep_augmented`
        ## marker tells fit-multi.R to expand n_lhs_cols to 2T and free
        ## theta_dep_chol for the full 2T x 2T unstructured Sigma_b. No new C++.
        if (fn == "animal_dep") {
          bar <- e[[2L]]
          if (
            !(is.call(bar) &&
              identical(bar[[1L]], as.name("|")) &&
              length(bar) == 3L)
          ) {
            cli::cli_abort(c(
              "{.fn animal_dep} expects a {.code 0 + trait | id} formula.",
              "i" = "Got: {.code {deparse(bar)}}.",
              ">" = "Use {.code animal_dep(0 + trait | id, pedigree = ped)}."
            ))
          }
          species_arg <- bar[[3L]]
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          ## Augmented intercept+slope LHS: route via the dep-slope engine.
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            new_call <- as.call(c(
              list(as.name("phylo_slope"), bar),
              list(
                .phylo_dep_augmented = TRUE,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              list(vcv = vcv_expr)
            ))
            return(new_call)
          }
          ## Intercept-only bar: the original non-augmented dep path.
          new_call <- as.call(c(
            list(as.name("phylo_rr"), species_arg),
            list(d = as.name(".deferred_n_traits"), .dep = TRUE),
            list(vcv = vcv_expr)
          ))
          return(new_call)
        }
        ## animal_slope(x | id) -> phylo_slope(x | id, vcv = A) if A given;
        ## otherwise the engine reuses A from a sibling animal_* term.
        if (fn == "animal_slope") {
          new_call <- e
          new_call[[1L]] <- as.name("phylo_slope")
          if (!is.null(vcv_expr)) {
            new_call[["vcv"]] <- vcv_expr
          }
          return(new_call)
        }
      }
      ## Generic dense-kernel keyword family (Design 65 C1).
      ##
      ## C1 deliberately reuses the phylo_rr dense relatedness path:
      ## `kernel_latent(unit, K = A, d = q)` must be byte-equivalent to
      ## `phylo_latent(unit, vcv = A, d = q)`. The `.kernel_*` markers are
      ## metadata only; fit-multi.R uses them to expose `level = name` in
      ## extract_Sigma() while the TMB data and parameters remain the proven
      ## phylo-equivalent path.
      if (
        fn %in%
          c("kernel_latent", "kernel_unique", "kernel_indep", "kernel_dep")
      ) {
        nm <- names(e)
        if (is.null(nm) || !"K" %in% nm) {
          cli::cli_abort(c(
            "{.fn {fn}} requires a named {.arg K} matrix.",
            ">" = "Use {.code {fn}(unit, K = K_matrix)}."
          ))
        }
        K_expr <- e[[which(nm == "K")]]
        name_expr <- if ("name" %in% nm) e[[which(nm == "name")]] else "kernel"
        unit_arg <- e[[2L]]
        kernel_meta <- list(
          vcv = K_expr,
          .kernel_name = name_expr,
          .kernel_mode = sub("^kernel_", "", fn)
        )
        if (fn == "kernel_latent") {
          d_val <- .named_or_positional_arg(e, "d", 4L, default = 1L)
          return(as.call(c(
            list(as.name("phylo_rr"), unit_arg),
            list(d = d_val),
            kernel_meta
          )))
        }
        if (fn == "kernel_unique") {
          .gllvmTMB_warn_unique_family_deprecated(fn)
          return(as.call(c(
            list(as.name("phylo_rr"), unit_arg),
            list(.phylo_unique = TRUE),
            kernel_meta
          )))
        }
        if (fn == "kernel_indep") {
          return(as.call(c(
            list(as.name("phylo_rr"), unit_arg),
            list(.phylo_unique = TRUE, .indep = TRUE),
            kernel_meta
          )))
        }
        if (fn == "kernel_dep") {
          return(as.call(c(
            list(as.name("phylo_rr"), unit_arg),
            list(d = as.name(".deferred_n_traits"), .dep = TRUE),
            kernel_meta
          )))
        }
      }
      ## latent / unique / phylo_latent / spatial_unique: just rename the head
      if (fn %in% c("latent", "phylo_latent", "spatial_unique", "spatial")) {
        ## Ordinary individual-level random regression:
        ## latent(1 + x | unit, d = K) and the long form
        ## latent(0 + trait + (0 + trait):x | unit, d = K) route to a marked
        ## rr() term. fit-multi.R drives that marker through the augmented
        ## B-tier latent engine whose loading matrix has (intercept, slope) x
        ## trait rows, so intercept-slope covariance is estimable. Unsupported
        ## augmented forms still hit the old guard below.
	        if (
	          identical(fn, "latent") &&
	            length(e) >= 2L &&
	            is.call(e[[2L]]) &&
	            identical(e[[2L]][[1L]], as.name("|")) &&
	            length(e[[2L]]) == 3L
	        ) {
	          bar <- e[[2L]]
	          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
	          if (
	            lhs_form$lhs_form %in%
	              c("wide_intercept_slope", "long_intercept_slope")
	          ) {
	            common_arg <- e[["common"]]
	            if (!is.null(common_arg)) {
	              if (!is.logical(common_arg) || length(common_arg) != 1L ||
	                  is.na(common_arg)) {
	                cli::cli_abort(c(
	                  "{.arg common} in {.fn latent} must be a literal {.code TRUE} or {.code FALSE}.",
	                  ">" = "Use {.code common = TRUE} only for intercept-only ordinary {.fn latent} terms."
	                ))
	              }
	              if (isTRUE(common_arg)) {
	                cli::cli_abort(c(
	                  "{.code common = TRUE} is not implemented for augmented ordinary {.fn latent} random-regression slopes.",
	                  "i" = "The augmented diagonal has separate intercept and slope entries for each trait.",
	                  ">" = "Use {.code latent(0 + trait | unit, d = K, common = TRUE)} for intercept-only scalar Psi, or omit {.arg common} for augmented reaction-norm fits."
	                ))
	              }
	            }
	            d_arg <- .named_or_positional_arg(e, "d", 3L, default = 1L)
	            unique_arg <- .gllvmTMB_resolve_latent_unique(e)
	            return(as.call(c(
	              list(as.name("rr"), bar),
	              list(
	                d = d_arg,
	                .latent_augmented = TRUE,
	                .latent_augmented_unique = unique_arg,
	                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              )
            )))
          }
          .assert_no_augmented_lhs(fn, e)
        }
        ## Design 56 Sec. 9.5a: augmented phylo_latent random regression.
        ## `phylo_latent` normally renames straight to `phylo_rr`, which reads
        ## ONLY the RHS species factor -- so an augmented intercept+slope bar
        ## (`1 + x | sp` or the long form `0 + trait + (0 + trait):x | sp`)
        ## would have its slope column SILENTLY DROPPED (the Sokal 2026-05-09
        ## anti-pattern). Instead we route it to a phylo_rr covstruct carrying
        ## the `.latent_slope` marker, which fit-multi.R drives through the
        ## dedicated block-diagonal reduced-rank latent-slope engine
        ## (use_phylo_latent_slope). Each LHS column gets its own
        ## Lambda_k Lambda_k^T (rank d); no intercept-slope correlation.
        if (
          identical(fn, "phylo_latent") &&
            length(e) >= 2L &&
            is.call(e[[2L]]) &&
            identical(e[[2L]][[1L]], as.name("|")) &&
            length(e[[2L]]) == 3L
        ) {
          bar <- e[[2L]]
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            species_arg <- bar[[3L]]
            d_arg <- .named_or_positional_arg(e, "d", 3L, default = 1L)
            extra_args <- list(
              .latent_slope = TRUE,
              lhs_form = lhs_form$lhs_form,
              slope_col = lhs_form$slope_col
            )
            ## Preserve a user-supplied tree / vcv / A / Ainv on the rewrite.
            for (a in c("tree", "vcv", "A", "Ainv")) {
              if (!is.null(e[[a]])) extra_args[[a]] <- e[[a]]
            }
            new_call <- as.call(c(
              list(as.name("phylo_rr"), species_arg),
              list(d = d_arg),
              extra_args
            ))
            return(new_call)
          }
        }
        ## Design 60 §3.4: augmented spatial_unique(1 + x | coords) random
        ## regression. `spatial_unique` normally renames straight to `spde`,
        ## which reads ONLY the coords RHS -- so an augmented intercept+slope
        ## bar (`1 + x | coords` or `0 + trait + (0 + trait):x | coords`) would
        ## have its slope column SILENTLY DROPPED. Instead route it to an `spde`
        ## covstruct carrying the `.spatial_unique_augmented` marker, which
        ## fit-multi.R drives through the now-integrated base SPDE slope engine
        ## (use_spde_slope): a SECOND SPDE field on the covariate sharing a 2x2
        ## cross-field covariance Sigma_field with the intercept field. The C++
        ## dimension asserts (src/gllvmTMB.cpp:925-938) are the fail-loud
        ## backstop. Both wide and long surfaces build the same 2-column
        ## Z_spde_aug (Design 55 §3 byte-identity).
        if (
          identical(fn, "spatial_unique") &&
            length(e) >= 2L &&
            is.call(e[[2L]]) &&
            identical(e[[2L]][[1L]], as.name("|")) &&
            length(e[[2L]]) == 3L
        ) {
          bar <- e[[2L]]
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            .gllvmTMB_warn_unique_family_deprecated(fn)
            extras <- .pass_through_extras(e, c("coords", "mesh"))
            new_call <- as.call(c(
              list(as.name("spde"), bar),
              list(
                .spatial_unique_augmented = TRUE,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              extras
            ))
            return(new_call)
          }
        }
        target <- switch(
          fn,
          latent = "rr",
          phylo_latent = "phylo_rr",
          spatial_unique = "spde",
          spatial = "spde"
        )
	        if (identical(fn, "spatial_unique")) {
	          .gllvmTMB_warn_unique_family_deprecated(fn)
	        }
	        new_call <- e
	        new_call[[1L]] <- as.name(target)
	        if (identical(fn, "latent")) {
	          unique_arg <- .gllvmTMB_resolve_latent_unique(e)

	          common_arg <- e[["common"]]
	          if (is.null(common_arg)) common_arg <- FALSE
	          if (!is.logical(common_arg) || length(common_arg) != 1L ||
	              is.na(common_arg)) {
	            cli::cli_abort(c(
	              "{.arg common} in {.fn latent} must be a literal {.code TRUE} or {.code FALSE}.",
	              ">" = "Use {.code latent(..., common = TRUE)} for one shared ordinary Psi variance across traits."
	            ))
	          }
	          new_call_names <- names(new_call)
	          if (!is.null(new_call_names)) {
	            drop_args <- new_call_names %in% c("unique", "residual", "common")
	            if (any(drop_args)) {
	              new_call <- new_call[!drop_args]
	            }
	          }

	          if (isFALSE(unique_arg) && isTRUE(common_arg)) {
	            cli::cli_abort(c(
	              "{.arg common} in {.fn latent} requires {.code unique = TRUE}.",
	              "i" = "{.code common = TRUE} ties the default diagonal Psi companion; {.code unique = FALSE} removes that companion.",
	              ">" = "Use {.code latent(..., common = TRUE)} or {.code latent(..., unique = FALSE)}, not both."
	            ))
	          }
	          if (isFALSE(unique_arg)) {
	            return(new_call)
	          }
	          psi_extras <- list(.latent_psi = TRUE)
	          if (isTRUE(common_arg)) {
	            psi_extras$common <- TRUE
	          }
	          psi_call <- as.call(c(list(as.name("diag"), e[[2L]]), psi_extras))
	          return(call("+", new_call, psi_call))
	        }
	        return(new_call)
	      }
      ## `unique(form, common = bool)` -> `diag(form, common = bool)`
      if (fn == "unique") {
        .gllvmTMB_warn_unique_family_deprecated(fn)
        ## Ordinary individual-level augmented unique random regression:
        ## unique(1 + x | unit) and the long form
        ## unique(0 + trait + (0 + trait):x | unit) route to a marked diag()
        ## term. fit-multi.R drives that marker through the B-tier augmented
        ## diagonal engine over the same (intercept, slope) x trait ordering
        ## used by latent(1 + x | unit, d = K).
        if (
          length(e) >= 2L &&
            is.call(e[[2L]]) &&
            identical(e[[2L]][[1L]], as.name("|")) &&
            length(e[[2L]]) == 3L
        ) {
          bar <- e[[2L]]
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            new_call <- e
            new_call[[1L]] <- as.name("diag")
            new_call[[".unique_augmented"]] <- TRUE
            new_call[["lhs_form"]] <- lhs_form$lhs_form
            new_call[["slope_col"]] <- lhs_form$slope_col
            return(new_call)
          }
        }
        ## Remaining augmented LHS forms are still unsupported.
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
      if (
        fn == "phylo" &&
          length(e) >= 2L &&
          is.call(e[[2L]]) &&
          identical(e[[2L]][[1L]], as.name("|"))
      ) {
        bar <- e[[2L]]
        lhs <- bar[[2L]]
        rhs <- bar[[3L]] # the species factor (bare name)
        ## Inspect named args.
        args_named <- as.list(e)[-c(1L, 2L)]
        nms <- names(args_named)
        if (is.null(nms)) {
          nms <- rep("", length(args_named))
        }
        get_arg <- function(name, default = NULL) {
          ix <- which(nms == name)
          if (length(ix) == 0L) {
            return(default)
          }
          args_named[[ix[1L]]]
        }
        mode_arg <- get_arg("mode", default = NULL)
        tree_arg <- get_arg("tree", default = NULL)
        vcv_arg <- get_arg("vcv", default = NULL)
        d_arg <- get_arg("d", default = NULL)

        ## Helper: extras to splice into the rewritten call (named args
        ## tree/vcv only -- mode/d are interpreted here, not forwarded).
        extras <- list()
        if (!is.null(tree_arg)) {
          extras$tree <- tree_arg
        }
        if (!is.null(vcv_arg)) {
          extras$vcv <- vcv_arg
        }

        ## Detect LHS shape.
        is_intercept_only <- (is.numeric(lhs) &&
          length(lhs) == 1L &&
          lhs == 1) ||
          (is.symbol(lhs) && identical(as.character(lhs), "1"))
        is_zero_plus_trait <- is.call(lhs) &&
          identical(lhs[[1L]], as.name("+")) &&
          length(lhs) == 3L &&
          is.numeric(lhs[[2L]]) &&
          lhs[[2L]] == 0 &&
          is.symbol(lhs[[3L]]) &&
          identical(as.character(lhs[[3L]]), "trait")

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
          if (is.null(mode_str)) {
            mode_str <- "scalar"
          }
          if (!identical(mode_str, "scalar")) {
            cli::cli_abort(c(
              "{.code mode = {.val {mode_str}}} is degenerate when LHS is {.code 1} (intercept-only).",
              "i" = "Use {.code 0 + trait} LHS for per-trait covariance modes."
            ))
          }
          ## Rewrite to phylo_scalar(rhs, tree = tree, vcv = vcv).
          new_call <- as.call(c(list(as.name("phylo_scalar"), rhs), extras))
          return(rewrite(new_call)) # recurse so phylo_scalar -> engine
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
          new_call <- as.call(c(
            list(as.name("phylo_latent"), rhs, d = d_use),
            extras
          ))
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
        .gllvmTMB_warn_unique_family_deprecated(fn)
        extras <- .pass_through_extras(e, c("tree", "vcv"))
        if (
          length(e) >= 2L &&
            is.call(e[[2L]]) &&
            identical(e[[2L]][[1L]], as.name("|")) &&
            length(e[[2L]]) == 3L
        ) {
          bar <- e[[2L]]
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          species_arg <- bar[[3L]]
          if (!is.name(species_arg)) {
            cli::cli_abort(c(
              "{.fn phylo_unique} RHS must be a single column name (the species factor).",
              "i" = "Got RHS: {.code {deparse(species_arg)}}.",
              ">" = "Use {.code phylo_unique(1 + x | species)} or {.code phylo_unique(0 + trait + (0 + trait):x | species)}."
            ))
          }
          if (identical(lhs_form$lhs_form, "intercept_only")) {
            new_call <- as.call(c(
              list(as.name("phylo_rr"), species_arg),
              list(.phylo_unique = TRUE),
              extras
            ))
            return(new_call)
          }
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            new_call <- as.call(c(
              list(as.name("phylo_slope"), bar),
              list(
                .phylo_unique_augmented = TRUE,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              extras
            ))
            return(new_call)
          }
          cli::cli_abort(c(
            "{.fn phylo_unique} augmented LHS form is not supported.",
            "i" = "You wrote {.code phylo_unique({deparse(bar)})}.",
            "x" = "Phase 56.3 accepts only {.code 1 + x | species} and {.code 0 + trait + (0 + trait):x | species}.",
            ">" = "Keep multi-covariate, slope-only, uncorrelated, and richer per-trait slope forms for a later design slice."
          ))
        }
        new_call <- as.call(c(
          list(as.name("phylo_rr"), e[[2L]]),
          list(.phylo_unique = TRUE),
          extras
        ))
        return(new_call)
      }
      ## `spatial_scalar(form)` -> `spde(form, .spatial_scalar = TRUE)`
      ## fit-multi.R ties log_tau_spde across traits via the map mechanism
      ## when it sees the marker.
      if (fn == "spatial_scalar") {
        extras <- .pass_through_extras(e, c("coords", "mesh"))
        new_call <- as.call(c(
          list(as.name("spde"), e[[2L]]),
          list(.spatial_scalar = TRUE),
          extras
        ))
        return(new_call)
      }
      ## `spatial_latent(form, d)` -> `spde(form, .spatial_latent = TRUE, d = d)`.
      ## fit-multi.R flips the cpp template's `spde_lv_k` switch to d and
      ## allocates Lambda_spde (T x K_S) plus K_S shared spatial fields.
      if (fn == "spatial_latent") {
        d_val <- .named_or_positional_arg(e, "d", 3L, default = 1L)
        unique_arg <- .named_or_positional_arg(
          e, "unique", 4L, default = FALSE
        )
        unique_val <- tryCatch(
          eval(unique_arg, envir = parent.frame()),
          error = function(err) unique_arg
        )
        if (!is.logical(unique_val) || length(unique_val) != 1L ||
            is.na(unique_val)) {
          cli::cli_abort(c(
            "{.arg unique} in {.fn spatial_latent} must be a literal {.code TRUE} or {.code FALSE}.",
            ">" = "Use {.code spatial_latent(..., unique = TRUE)} for the total spatial covariance {.code Lambda Lambda^T + Psi}, or omit it for the low-rank-only path."
          ))
        }
        extras <- .pass_through_extras(e, c("coords", "mesh"))
        ## Design 64 §3: augmented spatial_latent(1 + x | coords, d) random
        ## regression. `spatial_latent` normally renames to `spde` reading ONLY
        ## the coords RHS -- so an augmented intercept+slope bar would have its
        ## slope column SILENTLY DROPPED (the Sokal anti-pattern). Instead route
        ## it to an `spde` covstruct carrying the `.spatial_latent_augmented`
        ## marker, which fit-multi.R drives through the dedicated block-diagonal
        ## reduced-rank latent-slope engine (use_spde_latent_slope). Each LHS
        ## column gets its own Lambda_k Lambda_k^T (rank d); no intercept-slope
        ## correlation. Distinct from the intercept-only `.spatial_latent`.
        if (
          length(e) >= 2L &&
            is.call(e[[2L]]) &&
            identical(e[[2L]][[1L]], as.name("|")) &&
            length(e[[2L]]) == 3L
        ) {
          bar <- e[[2L]]
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            new_call <- as.call(c(
              list(as.name("spde"), bar),
              list(
                .spatial_latent_augmented = TRUE,
                d = d_val,
                .spatial_unique_diag = unique_val,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              extras
            ))
            return(new_call)
          }
        }
        new_call <- as.call(c(
          list(as.name("spde"), e[[2L]]),
          list(.spatial_latent = TRUE, d = d_val,
               .spatial_unique_diag = unique_val),
          extras
        ))
        return(new_call)
      }
      ## `indep(form, common = bool)` -> `diag(form, common = bool,
      ## .indep = TRUE)`
      ## Same engine path as `unique()` (the `diag` covstruct with no
      ## or optional `common = TRUE` flag). The `.indep` marker only changes
      ## the printed label and lets fit-multi.R fire the indep+latent
      ## over-parameterisation guard.
      if (fn == "indep") {
        ## Stage 2.5: fail-loud against augmented LHS.
        .assert_no_augmented_lhs(fn, e)
        extras <- list(.indep = TRUE)
        common_arg <- .named_or_positional_arg(
          e, "common", 3L, default = NULL
        )
        if (!is.null(common_arg)) {
          extras$common <- common_arg
        }
        new_call <- as.call(c(list(as.name("diag"), e[[2L]]), extras))
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
        if (
          !(is.call(bar) &&
            identical(bar[[1L]], as.name("|")) &&
            length(bar) == 3L)
        ) {
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
        ## Augmented intercept+slope LHS (`1 + x | species` or the long form
        ## `0 + trait + (0 + trait):x | species`). phylo_indep means the
        ## intercept-slope correlation is FIXED at 0, i.e. the same augmented
        ## b_phy_aug engine as phylo_unique() but with atanh_cor_b pinned to 0
        ## via the TMB map (fit-multi.R reads the `.indep` marker on the
        ## phylo_slope covstruct). No new C++ likelihood block.
        lhs_form <- .gllvmTMB_lhs_form(lhs_bar)
        if (
          lhs_form$lhs_form %in%
            c("wide_intercept_slope", "long_intercept_slope")
        ) {
          extras <- .pass_through_extras(e, c("tree", "vcv"))
          new_call <- as.call(c(
            list(as.name("phylo_slope"), bar),
            list(
              .phylo_unique_augmented = TRUE,
              .indep = TRUE,
              lhs_form = lhs_form$lhs_form,
              slope_col = lhs_form$slope_col
            ),
            extras
          ))
          return(new_call)
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
        new_call <- as.call(c(
          list(as.name("phylo_rr"), species_arg),
          list(.phylo_unique = TRUE, .indep = TRUE),
          extras
        ))
        return(new_call)
      }
      ## `spatial_indep(0 + trait | coords)` -> `spde(form, .spatial_indep = TRUE)`
      ## Same engine path as `spatial_unique()` (per-trait omega_spde with
      ## independent log_tau per trait). The `.spatial_indep` marker only
      ## changes the printed label and triggers the spatial_indep+spatial_latent
      ## over-parameterisation guard.
      if (fn == "spatial_indep") {
        extras <- .pass_through_extras(e, c("coords", "mesh"))
        ## Design 60 §3.5: augmented spatial_indep(1 + x | coords) is the
        ## DIAGONAL special case of the base SPDE slope engine -- the
        ## intercept-slope cross-field correlation rho is FIXED at 0. It uses
        ## the SAME use_spde_slope engine as spatial_unique() but with
        ## atanh_cor_spde_b pinned to 0 via the TMB map (fit-multi.R reads the
        ## `.spatial_indep_augmented` marker). No new C++ likelihood block.
        if (
          length(e) >= 2L &&
            is.call(e[[2L]]) &&
            identical(e[[2L]][[1L]], as.name("|")) &&
            length(e[[2L]]) == 3L
        ) {
          bar <- e[[2L]]
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            new_call <- as.call(c(
              list(as.name("spde"), bar),
              list(
                .spatial_unique_augmented = TRUE,
                .spatial_indep_augmented = TRUE,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              extras
            ))
            return(new_call)
          }
        }
        new_call <- as.call(c(
          list(as.name("spde"), e[[2L]]),
          list(.spatial_indep = TRUE),
          extras
        ))
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
        new_call <- as.call(c(
          list(as.name("rr"), e[[2L]]),
          list(d = as.name(".deferred_n_traits"), .dep = TRUE)
        ))
        return(new_call)
      }
      ## `phylo_dep(0 + trait | species)` -> `phylo_rr(species,
      ##                                     d = .deferred_n_traits, .dep = TRUE)`
      ## Same engine path as `phylo_latent(species, d = n_traits)` standalone:
      ## full-rank packed-triangular Lambda_phy on the phylogenetic correlation
      ## matrix, which is exactly the Cholesky factor of unstructured Sigma_phy.
      if (fn == "phylo_dep") {
        bar <- e[[2L]]
        if (
          !(is.call(bar) &&
            identical(bar[[1L]], as.name("|")) &&
            length(bar) == 3L)
        ) {
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
        ## Stage 3 (Design 56 Sec. 9.5c) + RE-03 multi-slope: the augmented
        ## intercept+slope LHS (`1 + x1 + ... + xs | species` wide, or
        ## `0 + trait + (0 + trait):x1 + ... | species` long, s >= 1) routes
        ## through the b_phy_aug engine with the full unstructured
        ## (1+s)T x (1+s)T covariance Sigma_b built from theta_dep_chol. The
        ## `.phylo_dep_augmented` marker (distinct from the phylo_unique
        ## `.phylo_unique_augmented` marker) tells fit-multi.R to expand
        ## n_lhs_cols to (1+s)T and free theta_dep_chol. No new C++ block (the
        ## C++ dep path is already dimension-general in `C = n_lhs_cols`). Uses
        ## the MULTI-slope classifier so s >= 2 is recognised on this path only;
        ## every other keyword keeps the single-slope `.gllvmTMB_lhs_form()`.
        lhs_form <- .gllvmTMB_lhs_form_multi(lhs_bar)
        if (
          lhs_form$lhs_form %in%
            c("wide_intercept_slope", "long_intercept_slope")
        ) {
          extras <- .pass_through_extras(e, c("tree", "vcv"))
          new_call <- as.call(c(
            list(as.name("phylo_slope"), bar),
            list(
              .phylo_dep_augmented = TRUE,
              lhs_form = lhs_form$lhs_form,
              slope_col = lhs_form$slope_col,
              slope_cols = lhs_form$slope_cols
            ),
            extras
          ))
          return(new_call)
        }
        ## Intercept-only `phylo_dep(0 + trait | species)`: the full
        ## unstructured cross-trait phylogenetic intercept covariance via the
        ## phylo_rr full-rank path (UNCHANGED).
        if (identical(lhs_form$lhs_form, "intercept_only")) {
          extras <- .pass_through_extras(e, c("tree", "vcv"))
          new_call <- as.call(c(
            list(as.name("phylo_rr"), species_arg),
            list(d = as.name(".deferred_n_traits"), .dep = TRUE),
            extras
          ))
          return(new_call)
        }
        cli::cli_abort(c(
          "{.fn phylo_dep} augmented LHS form is not supported.",
          "i" = "You wrote {.code phylo_dep({deparse(bar)})}.",
          "x" = "phylo_dep accepts {.code 0 + trait | species} (intercept-only), {.code 1 + x1 + ... + xs | species} (wide, s >= 1), and {.code 0 + trait + (0 + trait):x1 + ... | species} (long).",
          ">" = "Each slope term must be a plain covariate name; keep richer per-trait slope forms for a later design slice."
        ))
      }
      ## `spatial_dep(0 + trait | coords)` -> `spde(form, .spatial_latent = TRUE,
      ##                                            d = .deferred_n_traits, .dep = TRUE)`
      ## Same engine path as `spatial_latent(form, d = n_traits)` standalone:
      ## the K_S = T case of the spatial latent factor model, with the
      ## packed-triangular Lambda_spde at full rank acting as the Cholesky
      ## factor of unstructured Sigma_spatial.
      if (fn == "spatial_dep") {
        ## Design 64 §2: augmented spatial_dep(1 + x | coords) random regression.
        ## The augmented intercept+slope LHS (`1 + x | coords` wide or
        ## `0 + trait + (0 + trait):x | coords` long) routes through the
        ## use_spde_slope engine with the full unstructured 2T x 2T field
        ## covariance Sigma_field built from theta_spde_dep_chol. The
        ## `.spatial_dep_augmented` marker (distinct from the intercept-only
        ## `.spatial_latent` + `.dep` route below) tells fit-multi.R to expand
        ## n_lhs_cols_spde to 2T and free theta_spde_dep_chol. No new C++ block
        ## beyond the spatial_dep prior (it reuses omega_spde_aug + A_proj).
        if (
          length(e) >= 2L &&
            is.call(e[[2L]]) &&
            identical(e[[2L]][[1L]], as.name("|")) &&
            length(e[[2L]]) == 3L
        ) {
          bar <- e[[2L]]
          lhs_form <- .gllvmTMB_lhs_form(bar[[2L]])
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            extras <- .pass_through_extras(e, c("coords", "mesh"))
            new_call <- as.call(c(
              list(as.name("spde"), bar),
              list(
                .spatial_dep_augmented = TRUE,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              extras
            ))
            return(new_call)
          }
        }
        ## Stage 2.5: fail-loud against any OTHER augmented LHS (multi-covariate
        ## or richer per-trait slope forms). Intercept-only `0 + trait | coords`
        ## passes through to the spatial_latent(d = T) engine path below.
        .assert_no_augmented_lhs(fn, e)
        extras <- .pass_through_extras(e, c("coords", "mesh"))
        new_call <- as.call(c(
          list(as.name("spde"), e[[2L]]),
          list(
            .spatial_latent = TRUE,
            d = as.name(".deferred_n_traits"),
            .dep = TRUE
          ),
          extras
        ))
        return(new_call)
      }
      ## `meta_V(V = X)` (canonical) and `meta_known_V(V = X)`
      ## (deprecated alias) -> `meta(sampling_var = X)`.
      ## Back-compat: `meta_V(value, V = X)` still desugars the same way,
      ## but new examples should not mention the response column here.
      ## Both names desugar identically; see vision item 4 (2026-05-16
      ## rename) and validation-debt register MET-01.
      if (fn == "meta_V" || fn == "meta_known_V") {
        invisible(.meta_type(e, fn))
        V_expr <- .meta_V_expr(e, fn)
        return(as.call(c(list(as.name("meta")), list(sampling_var = V_expr))))
      }
      ## Recurse into subexpressions
      for (i in seq_along(e)[-1L]) {
        e[[i]] <- rewrite(e[[i]])
      }
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
##   diag      -> use indep() for standalone diagonal terms
##   phylo_rr  -> use phylo_latent()
##   phylo     -> use phylo_scalar()
##   spde      -> use spatial_unique()
##   spatial   -> use spatial_unique() (lifecycle::deprecate_warn at 0.1.2)
##   meta      -> use meta_V()
##   gr        -> use phylo_scalar() (or propto() power-user)
##   propto    -> internal; users should use phylo_scalar / phylo_latent
##   equalto   -> internal; users should use meta_V
##
## We do NOT warn on `propto` / `equalto` even though they're internal,
## because the brms-sugar layer rewrites phylo()/meta() to those before
## the parser sees them -- so they appear in every formula post-desugar.
scan_for_deprecated <- function(rhs) {
  deprecated_map <- list(
    rr = list(
      new = "latent",
      args = "0 + trait | g, d = K",
      see = "{.fn latent}"
    ),
    diag = list(
      new = "indep",
      args = "0 + trait | g",
      see = "{.code ?diag_re} / {.fn indep}",
      guidance = "Use ordinary latent(..., d = K) when you want the default shared + diagonal-Psi decomposition; explicit unique() remains compatibility syntax."
    ),
    phylo_rr = list(
      new = "phylo_latent",
      args = "species, d = K",
      see = "{.code ?phylo_latent}"
    ),
    phylo = list(
      new = "phylo_scalar",
      args = "species",
      see = "{.code ?phylo_scalar}"
    ),
    spde = list(
      new = "spatial_unique",
      args = "coords | trait",
      see = "{.code ?spatial_unique}"
    ),
    meta = list(
      new = "meta_V",
      args = "V = V",
      see = "{.code ?meta_V}"
    ),
    gr = list(
      new = "phylo_scalar",
      args = "species",
      see = "{.code ?phylo_scalar}"
    )
  )
  has_named_arg <- function(e, arg) {
    nms <- names(as.list(e))
    !is.null(nms) && arg %in% nms
  }
  is_bar_first_arg <- function(e) {
    length(e) >= 2L &&
      is.call(e[[2L]]) &&
      identical(e[[2L]][[1L]], as.name("|")) &&
      length(e[[2L]]) == 3L
  }
  is_intercept_only_bar_lhs <- function(e) {
    if (!is_bar_first_arg(e)) {
      return(FALSE)
    }
    lhs <- e[[2L]][[2L]]
    (is.numeric(lhs) && length(lhs) == 1L && lhs == 1) ||
      (is.symbol(lhs) && identical(as.character(lhs), "1"))
  }
  spatial_call_is_legacy_alias <- function(e) {
    if (!is_bar_first_arg(e)) {
      return(TRUE)
    }
    ## `spatial()` is now a documented mode-dispatch wrapper for bar
    ## calls with an intercept-only LHS, explicit mode, or explicit mesh.
    ## Only the older no-mode/no-mesh bar aliases should receive the
    ## spatial -> spatial_unique deprecation warning.
    !(is_intercept_only_bar_lhs(e) ||
        has_named_arg(e, "mode") ||
        has_named_arg(e, "mesh"))
  }
  walk <- function(e) {
    if (is.call(e)) {
      ## Only a bare-symbol head (e.g. `spatial`) names a keyword. For a
      ## namespace-qualified head such as `pkg::fn` the head `e[[1L]]` is
      ## itself a call, so `as.character()` would return a length-3 vector
      ## (`c("::", "pkg", "fn")`) and the `if (fn == ...)` checks below
      ## would error with "the condition has length > 1". Skip keyword
      ## matching for non-symbol heads; still recurse into the arguments.
      if (is.name(e[[1L]])) {
        fn <- as.character(e[[1L]])
        ## `spatial()` -> `spatial_unique()` is a fresh rename in 0.1.2;
        ## use lifecycle's deprecate_warn so it integrates with the
        ## standard tidyverse deprecation tooling and the `lifecycle`
        ## verbosity option.
        if (fn == "spatial") {
          if (!spatial_call_is_legacy_alias(e)) {
            for (i in seq_along(e)[-1L]) {
              walk(e[[i]])
            }
            return(invisible(NULL))
          }
          lifecycle::deprecate_warn(
            when = "0.1.2",
            what = "spatial()",
            with = "spatial_unique()",
            details = c(
              "i" = "spatial(coords | trait) is now an alias for spatial_unique(0 + trait | coords), the unique cell of the 4 x 5 keyword grid.",
              ">" = "Update existing code to spatial_unique() to keep the rank explicit."
            )
          )
        } else if (fn == "phylo" && is_bar_first_arg(e)) {
          for (i in seq_along(e)[-1L]) {
            walk(e[[i]])
          }
          return(invisible(NULL))
        } else if (fn %in% names(deprecated_map)) {
          d <- deprecated_map[[fn]]
          .gllvmTMB_warn_keyword_deprecated(
            fn,
            d$new,
            d$args,
            d$guidance,
            d$see
          )
        }
      }
      for (i in seq_along(e)[-1L]) {
        walk(e[[i]])
      }
    }
    invisible(NULL)
  }
  walk(rhs)
  invisible(NULL)
}


desugar_brms_sugar <- function(
  formula,
  trait_col = "trait",
  obs_col = "obs",
  grp_V_col = "grp_V"
) {
  ## ---- Pass 0: scan the original AST for deprecated keywords and emit
  ## one-shot soft warnings. Done before any rewriting so we see what the
  ## user actually typed.
  scan_for_deprecated(formula[[length(formula)]])

  ## ---- Pass 1: rewrite canonical aliases (latent / unique / phylo_latent
  ## / phylo_scalar / spatial / meta_V / meta_known_V) to engine-internal names.
  ## Done before the legacy brms desugaring below so e.g. phylo_scalar
  ## becomes phylo() which then becomes propto().
  formula <- rewrite_canonical_aliases(formula)

  walk <- function(e) {
    if (is.call(e)) {
      ## Only a bare-symbol head names a keyword. A namespace-qualified head
      ## such as `pkg::fn` is itself a call, so `as.character(e[[1L]])` would
      ## yield a length-3 vector and the `if (fn == ...)` checks below would
      ## error with "the condition has length > 1". Match keywords only for a
      ## symbol head; non-symbol heads fall through to the argument recursion.
      fn <- if (is.name(e[[1L]])) as.character(e[[1L]]) else ""
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
        if (is.null(nm)) {
          nm <- rep("", length(e))
        }
        vcv_idx <- which(nm %in% c("vcv", "cov"))
        tree_idx <- which(nm == "tree")
        if (
          length(vcv_idx) == 0L && length(tree_idx) == 0L && length(e) >= 3L
        ) {
          vcv_idx <- 3L
        } # positional fallback only when no named args
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
      for (i in seq_along(e)[-1L]) {
        e[[i]] <- walk(e[[i]])
      }
    }
    e
  }
  rhs <- formula[[length(formula)]]
  formula[[length(formula)]] <- walk(rhs)
  formula
}
