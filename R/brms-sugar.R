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
##   * `latent(...)`        --- shared cross-trait covariance plus default Psi
##                              (Sigma = Lambda Lambda^T + Psi)
##   * `unique(...)`        --- standalone diagonal compatibility syntax, or
##                              explicit-Psi compatibility when paired
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
##   phylo_latent(species, d = K, unique = TRUE)  phylo_rr(species, d = K) +
##                                                auto phylo_unique companion
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
    ## Point the closing line at the actual replacement's help topic when the
    ## caller supplies one; fall back to the generic reduced-rank pointer only
    ## for the rr/diag keywords, where it is on-topic.
    see_line <- if (!is.null(see)) {
      sprintf("Aliases will be dropped at the next minor release. See {.code ?%s}.", see)
    } else {
      "Aliases will be dropped at the next minor release. See {.code ?diag_re} / {.fn latent}."
    }
    msg <- c(
      "!" = "Formula keyword {.fn {old}} is a deprecated alias; use {.fn {new_name}} for new code.",
      "i" = "{.code {new_name}({args})} =/=> {.code {old}({args})}",
      ">" = see_line
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
  ## Surfacing soft-deprecation. lifecycle::deprecate_soft() is SILENT for
  ## indirect (in-package) callers like this rewrite walk, so the user never
  ## sees it in a real fit. Use the package's own env-based one-shot tracker +
  ## cli_warn so the warning actually fires on use (maintainer 2026-06-20:
  ## loud fire-on-use for the unique() / *_unique() soft-deprecation).
  if (isTRUE(getOption("gllvmTMB.quiet_grammar_notes", FALSE))) {
    return(invisible(NULL))
  }
  key <- sprintf("unique-family-%s", fn)
  if (!isTRUE(.gllvmTMB_deprecation_seen[[key]])) {
    cli::cli_warn(c(
      "!" = "Formula keyword {.fn {fn}} is soft-deprecated as of gllvmTMB 0.2.0 (compatibility syntax).",
      "i" = "{.fn unique} / {.fn *_unique} are compatibility syntax while {.field Psi} moves into the latent-family grammar.",
      ">" = "For standalone diagonal tiers use {.fn indep} / {.fn *_indep}; ordinary {.fn latent} now carries {.field Psi} by default."
    ))
    .gllvmTMB_deprecation_seen[[key]] <- TRUE
  }
  invisible(NULL)
}

## One-shot fire-on-use notice for the scalar() / *_scalar() soft-deprecation.
## Design 79's covariance grid collapses to THREE modes {indep, dep, latent}: the
## one-shared-variance case is now the canonical `indep(..., common = TRUE)`, which
## routes to the same *_scalar engine. The `scalar()` / `*_scalar()` keywords stay
## live as compatibility syntax but warn once per session, mirroring the
## unique-family soft-deprecation (maintainer 2026-07-12: warn-once + rewrite).
.gllvmTMB_warn_scalar_family_deprecated <- function(fn) {
  if (isTRUE(getOption("gllvmTMB.quiet_grammar_notes", FALSE))) {
    return(invisible(NULL))
  }
  key <- sprintf("scalar-family-%s", fn)
  if (!isTRUE(.gllvmTMB_deprecation_seen[[key]])) {
    common_hint <- sub("_scalar$", "_indep", fn)
    if (identical(fn, "scalar")) common_hint <- "indep"
    cli::cli_warn(c(
      "!" = "Formula keyword {.fn {fn}} is soft-deprecated as of gllvmTMB 0.5.0 (compatibility syntax).",
      "i" = "The covariance grid now has three modes: {.fn indep}, {.fn dep}, {.fn latent}. The one-shared-variance case is {.code common = TRUE}.",
      ">" = "Use {.code {common_hint}(..., common = TRUE)}; it fits the same model."
    ))
    .gllvmTMB_deprecation_seen[[key]] <- TRUE
  }
  invisible(NULL)
}

## One-shot fire-on-use notice for the bare-latent() meaning change: ordinary
## latent() now carries the per-trait Psi by DEFAULT (was Lambda-only). This is a
## silent behavior change for existing analyses, flagged as the key hazard in the
## design doc (2026-06-12-latent-psi-fold-design.md §7); maintainer (2026-06-20)
## locked the loud fire-on-use option. Fires only when residual= was NOT passed.
.gllvmTMB_warn_latent_default_psi <- function() {
  if (isTRUE(getOption("gllvmTMB.quiet_grammar_notes", FALSE))) {
    return(invisible(NULL))
  }
  key <- "latent-default-psi"
  if (!isTRUE(.gllvmTMB_deprecation_seen[[key]])) {
    cli::cli_warn(c(
      "!" = "Ordinary {.fn latent} now includes a per-trait {.field Psi} by default (Sigma = Lambda Lambda^T + Psi).",
      "i" = "This changed in gllvmTMB 0.2.0; earlier {.fn latent} was loadings-only (Lambda Lambda^T).",
      ">" = "Pass {.code latent(..., unique = FALSE)} for the old rotation-invariant loadings-only fit."
    ))
    .gllvmTMB_deprecation_seen[[key]] <- TRUE
  }
  invisible(NULL)
}

## One-shot fire-on-use notice for the `residual` -> `unique` argument rename on
## ordinary latent(). The `residual =` argument shipped in 0.2.0 (#505) and was
## renamed to `unique =` (matches extract_Sigma(part = "unique")); `residual`
## still works as a soft-deprecated alias.
.gllvmTMB_warn_latent_residual_alias <- function() {
  if (isTRUE(getOption("gllvmTMB.quiet_grammar_notes", FALSE))) {
    return(invisible(NULL))
  }
  key <- "latent-residual-alias"
  if (!isTRUE(.gllvmTMB_deprecation_seen[[key]])) {
    cli::cli_warn(c(
      "!" = "The {.arg residual} argument of {.fn latent} was renamed to {.arg unique} in gllvmTMB 0.2.0.",
      "i" = "{.arg residual} is retained as a soft-deprecated alias and may be removed in a future release.",
      ">" = "Use {.code latent(..., unique = ...)} instead."
    ))
    .gllvmTMB_deprecation_seen[[key]] <- TRUE
  }
  invisible(NULL)
}

#' Phylogenetic random effect: lme4-bar mode-dispatch wrapper
#'
#' `phylo()` is a unified entry point for the package's four taught
#' phylogenetic modes (`phylo_scalar`, `phylo_indep`, `phylo_latent`,
#' `phylo_dep`). It accepts an lme4-bar formula on the
#' first argument and dispatches to the appropriate canonical keyword
#' based on the LHS shape and the optional `mode = ...` argument. The
#' four current keywords stay first-class -- `phylo()` is an additive
#' alias matching the lme4 / brms / drmTMB convention.
#'
#' @section Dispatch rules:
#' | Form                                            | Mode default | Rewrites to                                |
#' |-------------------------------------------------|--------------|--------------------------------------------|
#' | `phylo(1 \| species)`                           | `"scalar"`   | `phylo_scalar(species)`                    |
#' | `phylo(0 + trait \| species, mode = "indep")`   | (mandatory)  | `phylo_indep(0 + trait \| species)`        |
#' | `phylo(0 + trait \| species, mode = "latent", d = K)` | (mandatory) | `phylo_latent(species, d = K)`        |
#' | `phylo(0 + trait \| species, mode = "dep")`     | (mandatory)  | `phylo_dep(0 + trait \| species)`          |
#'
#' When the LHS expands to a single column (`1`, intercept-only), `mode`
#' is degenerate: it defaults silently to `"scalar"`, and explicit
#' `mode = "scalar"` is accepted (no warning). When the LHS is
#' `0 + trait`, `mode` is **mandatory** -- choosing between `"indep"` /
#' `"latent"` / `"dep"` is a meaningful decision (per-trait
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
#' @section Intercept-and-slope terms:
#' The unified `phylo()` wrapper is limited to intercept-only trait covariance.
#' For an intercept and one or more slopes, use an explicit structured mode
#' such as `phylo_indep()`, `phylo_latent()`, or `phylo_dep()`; unsupported LHS
#' forms fail with a message showing the accepted syntax.
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
#' @param mode One of `"scalar"` / `"indep"` / `"latent"` /
#'   `"dep"`. Optional when LHS is `1` (defaults silently to
#'   `"scalar"`). Mandatory when LHS is `0 + trait`.
#' @param d Latent rank for `mode = "latent"`. Default 1.
#' @param unique Logical; for `mode = "latent"`, `TRUE` includes the
#'   phylo-structured diagonal \eqn{\boldsymbol\Psi_{phy}} companion.
#'   The default `FALSE` preserves the loadings-only source-specific
#'   latent path.
#' @param A Tip-level relatedness matrix; alias of `vcv =`.
#' @param Ainv Sparse precision matrix (inverse of `A`).
#' @return A formula marker; never evaluated.
#' @seealso [phylo_scalar()], [phylo_indep()],
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
#' # Per-trait independent phylogenetic variances on shared A
#' fit_u <- gllvmTMB(value ~ 0 + trait +
#'                     phylo(0 + trait | species, mode = "indep", tree = tree),
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
phylo <- function(
  formula,
  tree = NULL,
  vcv = NULL,
  mode = NULL,
  d = 1,
  unique = FALSE,
  A = NULL,
  Ainv = NULL
) {
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
#' over tips + internal nodes natively (only \pkg{ape} + \pkg{Matrix}, **no
#' `MCMCglmm` dependency**) and evaluates the prior through the quadratic form
#' \eqn{g^\top \mathbf{A}_{\mathrm{phy}}^{-1} g}, exploiting tree-topology
#' sparsity. The construction is the deterministic Hadfield & Nakagawa (2010)
#' algorithm (*Journal of Evolutionary Biology* 23:494-508), adopted from that
#' method; see Hadfield (2010) *Journal of Statistical Software* 33(2):1-22 for
#' the MCMCglmm reference implementation used for numerical cross-checks. When the user supplies only `phylo_vcv` (the dense
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
#' Set `unique = FALSE` for the loadings-only subset.
#' For a scalar diagonal \eqn{\boldsymbol\Psi} companion shared across traits,
#' use `common = TRUE`; this replaces the older two-term spelling for
#' ordinary intercept-only latent terms.
#'
#' @param formula `0 + trait | g` style formula (LHS is the response
#'   factor, typically `0 + trait`; RHS is the grouping factor).
#' @param d Integer; number of latent factors.
#' @param unique Logical; `TRUE` (default) auto-includes the diagonal
#'   trait-specific \eqn{\boldsymbol\Psi} companion
#'   (\eqn{\boldsymbol\Sigma = \boldsymbol\Lambda\boldsymbol\Lambda^\top + \boldsymbol\Psi}).
#'   Set `FALSE` for the loadings-only / rotation-invariant subset. The former
#'   argument name `residual` is retained as a soft-deprecated alias.
#' @param common Logical; `FALSE` (default) estimates one diagonal
#'   \eqn{\boldsymbol\Psi} variance per trait. `TRUE` ties the default ordinary
#'   diagonal \eqn{\boldsymbol\Psi} companion to one shared variance across
#'   traits. Only applies when `unique = TRUE`.
#' @param lv One-sided formula for predictor-informed latent-score means.
#'   Runtime support is limited to ordinary unit-tier
#'   `latent(..., lv = ~ x)`, and only Gaussian and pure binomial
#'   (logit/probit/cloglog) fits are currently admitted (partial coverage,
#'   supported for the ordinary-latent case). Source-specific `*_latent(..., lv = ~ x)` forms are
#'   parsed and then fail loud (not yet fittable).
#' @return A formula marker; never evaluated.
#' @seealso [indep()], [phylo_latent()], [diag_re], [extract_Sigma()].
#' @examples
#' \dontrun{
#' # Long-format stacked traits: a 2-factor latent random effect at `site`.
#' # Ordinary latent() carries its diagonal Psi by default
#' # (Sigma = Lambda Lambda^T + diag(psi)).
#' df <- simulate_site_trait(
#'   n_sites = 30, n_species = 4, n_traits = 4,
#'   mean_species_per_site = 4, seed = 42
#' )$data
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'   data = df, unit = "site"
#' )
#' extract_Sigma(fit)
#' }
#' @export
latent <- function(formula, d = 1, unique = TRUE, common = FALSE, lv = NULL) {
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
#' `latent() + unique()` remains accepted compatibility syntax. Removal is a
#' later API-change decision while the parser and source-specific exports
#' remain live. The
#' paired legacy `unique(..., common = TRUE)`
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
#' * **`tree = phylo`** (recommended when the tree is available) -- the full
#'   `ape::phylo` object. The package constructs the sparse phylogenetic
#'   precision using its Hadfield--Nakagawa implementation.
#' * **`vcv = Cphy`** -- a tip-level `n_species x n_species` correlation
#'   matrix for analyses that begin from a supplied covariance matrix.
#'
#' These inputs encode the same tip-level covariance target when they are
#' constructed from the same tree and aligned identically. Numerical agreement
#' still depends on labels, scaling, and fitting health; the function does not
#' estimate or report ancestral states.
#'
#' See the
#' [phylogenetic covariance article](https://itchyshin.github.io/gllvmTMB/articles/phylogenetic-gllvm.html)
#' for the benchmark.
#'
#' @param species Unquoted column name for the species factor.
#' @param d Integer; number of phylogenetic latent factors.
#' @param unique Logical; `TRUE` auto-includes the
#'   phylo-structured diagonal trait-specific \eqn{\boldsymbol\Psi_{phy}}
#'   companion, folding the shared rank-K loadings and the diagonal
#'   companion into a single term (\eqn{\boldsymbol\Sigma_{phy} = \boldsymbol\Lambda
#'   \boldsymbol\Lambda^\top \otimes \mathbf{A} + \boldsymbol\Psi_{phy} \otimes
#'   \mathbf{A}}). The default `FALSE` preserves the loadings-only /
#'   rotation-invariant subset.
#' @param tree An `ape::phylo` object. **Canonical.** Use this if
#'   you have a tree.
#' @param vcv A tip-only phylogenetic correlation matrix
#'   (`n_species x n_species`). Legacy alias of `A =`.
#' @param A Tip-level relatedness matrix (`n_species x n_species`)
#'   -- alias of `vcv =`, aligned with the `animal_*` family's
#'   argument naming. Supply one of `tree`,
#'   `vcv`, or `A` / `Ainv`.
#' @param Ainv Precision matrix (inverse of `A`). Sparse inputs are preserved
#'   for the sparse precision route.
#' @return A formula marker; never evaluated.
#' @seealso [phylo_scalar()], [phylo_indep()],
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
  Ainv = NULL,
  unique = FALSE
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
#' ## Scope
#'
#' This helper supports:
#' * **One** continuous covariate `x` (a single column name).
#' * **One** shared slope variance \eqn{\sigma^2_{\text{slope}}}.
#' * **Slopes shared across traits** (same \eqn{\beta_{\text{phy}}}(i)
#'   for every trait of species \eqn{i}).
#'
#' For trait-specific intercept-and-slope covariance, use the corresponding
#' augmented `phylo_indep()`, `phylo_latent()`, or `phylo_dep()` syntax.
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
#' [phylo_indep()] (D independent variances) and [phylo_latent()]
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
#'   argument naming.
#' @param Ainv Sparse precision matrix (inverse of `A`).
#' @return A formula marker; never evaluated.
#' @seealso [phylo_latent()], [phylo_indep()],
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
#' tiers. Paired explicit-Psi use remains accepted; use
#' `phylo_latent(..., unique = TRUE)` when the folded latent term itself
#' should carry this diagonal companion.
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
#'   \item{**Paired with `phylo_latent(..., unique = FALSE)`** (compatibility)}{
#'     When written together with `phylo_latent(species, d = K, unique = FALSE)`, the
#'     two terms co-fit as **separate covariance components**:
#'     \deqn{\boldsymbol\Sigma_\text{phy} \;=\; \underbrace{\boldsymbol\Lambda_\text{phy}\boldsymbol\Lambda_\text{phy}^{\!\top}}_{\text{shared (rank K)}} \;+\; \underbrace{\boldsymbol\Psi_\text{phy}}_{\text{per-trait unique}}.}
#'     \eqn{\boldsymbol\Lambda_\text{phy}} is filled by the rank-K shared
#'     latent factors; \eqn{\boldsymbol\Psi_\text{phy}} carries
#'     the per-trait phylogenetic variances not absorbed by the K shared
#'     axes. `phylo_latent(species, d = K, unique = TRUE)` fits this same
#'     manuscript-aligned PGLLVM decomposition as a single term
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
#'   argument naming.
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
#' fields. Paired explicit-Psi use remains accepted; new decomposition
#' code can use [spatial_latent()] with `unique = TRUE`.
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
#' @param mesh An `fmesher` mesh object built via [make_mesh()]. It may be
#'   supplied here or through the top-level `mesh =` argument to [gllvmTMB()].
#'   The engine does not construct a mesh automatically from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_scalar()], [spatial_latent()], [spde()] (deprecated alias).
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 20, n_species = 4, mean_species_per_site = 4,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 4), seed = 1
#'   )
#'   mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.1)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_unique(0 + trait | site, mesh = mesh),
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
#' SPDE engine as [spatial_indep()], with the per-trait
#' `log_tau_spde` parameters tied via TMB's `map` mechanism so they
#' collapse to a single estimable scalar.
#'
#' Use this when domain knowledge (or parsimony) says all traits should
#' share the same amount of spatial structure. Compare to
#' [spatial_indep()] (D independent variances) and [spatial_latent()]
#' (K-dim factor decomposition).
#'
#' @section Formula orientation:
#' The canonical orientation is `0 + trait | coords` (parallel to
#' [latent()] / [indep()] and glmmTMB's spatial keywords). The
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
#' @param mesh An `fmesher` mesh object built via [make_mesh()]. It may be
#'   supplied here or through the top-level `mesh =` argument to [gllvmTMB()].
#'   The engine does not construct a mesh automatically from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_indep()], [spatial_latent()], [spde()] (deprecated alias).
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 20, n_species = 4, mean_species_per_site = 4,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 4), seed = 1
#'   )
#'   mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.1)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_scalar(0 + trait | site, mesh = mesh),
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
#' grid (alongside [spatial_scalar()] and [spatial_indep()]).
#'
#' Internally this rewrites to `spde(form, .spatial_latent = TRUE, d = K)`
#' and toggles the TMB template's `spde_lv_k` switch to K. With
#' `unique = TRUE`, the same SPDE tier also keeps the per-trait
#' `omega_spde` fields active, giving
#' \eqn{\boldsymbol\Sigma_{\mathrm{spa}} =
#' \boldsymbol\Lambda_{\mathrm{spa}}\boldsymbol\Lambda_{\mathrm{spa}}^\top +
#' \boldsymbol\Psi_{\mathrm{spa}}}. The default `unique = FALSE` preserves
#' the older low-rank-only path. The earlier two-term companion spelling
#' is accepted as compatibility syntax for the same total-covariance
#' decomposition.
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
#' [latent()] / [indep()] and glmmTMB's spatial keywords). The
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
#' @param mesh An `fmesher` mesh object built via [make_mesh()]. It may be
#'   supplied here or through the top-level `mesh =` argument to [gllvmTMB()].
#'   The engine does not construct a mesh automatically from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_indep()], [spatial_scalar()], [phylo_latent()].
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 30, n_species = 6, mean_species_per_site = 5,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 6), seed = 1
#'   )
#'   mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.1)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_latent(0 + trait | site, d = 2, mesh = mesh),
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
#' `spatial()` is a unified entry point for the package's four taught
#' spatial modes (`spatial_scalar`, `spatial_indep`, `spatial_latent`,
#' `spatial_dep`). It accepts an lme4-bar formula on
#' the first argument and dispatches to the appropriate canonical
#' keyword based on the LHS shape and the optional `mode = ...` argument.
#' The four current keywords stay first-class -- `spatial()` is an
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
#' | `spatial(0 + trait \| coords, mode = "indep")`       | (mandatory)  | `spatial_indep(0 + trait \| coords)`       |
#' | `spatial(0 + trait \| coords, mode = "latent", d = K)` | (mandatory) | `spatial_latent(0 + trait \| coords, d = K)` |
#' | `spatial(0 + trait \| coords, mode = "dep")`         | (mandatory)  | `spatial_dep(0 + trait \| coords)`         |
#'
#' When the LHS expands to a single column (`1`, intercept-only), `mode`
#' is degenerate: it defaults silently to `"scalar"`, and explicit
#' `mode = "scalar"` is accepted (no warning). When the LHS is
#' `0 + trait`, `mode` is **mandatory** -- choosing between `"indep"` /
#' `"latent"` / `"dep"` is a meaningful decision (per-trait
#' marginal vs reduced-rank decomposition vs full unstructured) and the
#' parser refuses to silently default.
#'
#' @section Backward compatibility:
#' Legacy bare-formula calls `spatial(0 + trait | coords)` and
#' `spatial(coords | trait)` (no `mode` argument) continue to work as
#' deprecated aliases for the per-trait diagonal spatial field (with an
#' additional orientation-flip lifecycle warning for the pre-0.1.4
#' orientation). The legacy form rewrites to `spde()` internally,
#' picking up the SPDE mesh from the top-level `mesh =` argument to
#' [gllvmTMB()].
#'
#' @section Intercept-and-slope terms:
#' The unified `spatial()` wrapper is limited to intercept-only trait
#' covariance. For an intercept and slope, use an explicit structured mode such
#' as `spatial_indep()`, `spatial_latent()`, or `spatial_dep()`; unsupported LHS
#' forms fail with a message showing the accepted syntax.
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
#'   for the per-trait diagonal spatial field.
#' @param mesh A `fmesher` mesh constructed via [make_mesh()]. **Canonical.**
#'   Required for the new dispatch path; optional for the legacy
#'   bare-formula form (where the mesh is passed at the top level of
#'   [gllvmTMB()]).
#' @param coords Optional, retained as a hint of which coordinate
#'   columns correspond to the spatial grouping. The mesh actually
#'   used is whatever is passed to the `mesh` argument of [gllvmTMB()]
#'   or this function.
#' @param mode One of `"scalar"` / `"indep"` / `"latent"` /
#'   `"dep"`. Optional when LHS is `1` (defaults silently to
#'   `"scalar"`). Mandatory when LHS is `0 + trait`.
#' @param d Latent rank for `mode = "latent"`. Default 1.
#' @param unique Logical; forwarded to [spatial_latent()] when
#'   `mode = "latent"`. The default `FALSE` keeps the low-rank-only path.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_scalar()], [spatial_indep()],
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
#' # Per-trait independent fields on a shared mesh
#' fit_u <- gllvmTMB(value ~ 0 + trait +
#'                     spatial(0 + trait | coords, mode = "indep",
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
spatial <- function(
  formula,
  mesh = NULL,
  coords = NULL,
  mode = NULL,
  d = 1,
  unique = FALSE
) {
  ## Marker function. Body unused -- never called at evaluation time.
  invisible(NULL)
}

#' Known-V meta-analytic random effect (deprecated alias): `meta_known_V(V = V)`
#'
#' Soft-deprecated alias for [meta_V()]. Both names desugar identically; new
#' code should use `meta_V(V = V)`. `meta_known_V()` remains available for
#' backward compatibility.
#'
#' @param V Known sampling variance or covariance marker. In current
#'   exact-additive fits, pass the actual matrix via the top-level
#'   `known_V =` argument to [gllvmTMB()]. Formula-level `V = V` names
#'   the marker and keeps the syntax aligned with `drmTMB::meta_V()`.
#' @param type Sampling-covariance mode. `"exact"` is implemented.
#'   `"proportional"` is not implemented and fails clearly in the formula
#'   parser rather than being treated as exact.
#' @return A formula marker; never evaluated.
#' @seealso [meta_V()] (canonical name; preferred for new code);
#'   [meta()] (older deprecated short alias); [block_V()];
#'   [gllvmTMB()].
#' @examples
#' \dontrun{
#' # Deprecated alias of meta_V(); both desugar identically.
#' # New code should use meta_V(V = V).
#' set.seed(131)
#' df <- expand.grid(
#'   site  = factor(seq_len(50)),
#'   trait = factor(paste0("t", 1:3))
#' )
#' df$value <- rnorm(nrow(df), sd = 0.5)
#' df$sampling_var <- runif(nrow(df), min = 0.02, max = 0.08)
#' V <- diag(df$sampling_var)
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1) +
#'     meta_known_V(V = V),
#'   data = df, trait = "trait", unit = "site", known_V = V
#' )
#' }
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
#' covariance). [meta_known_V()] is retained as a soft-deprecated alias; both
#' names desugar identically in the formula parser.
#'
#' Pass the matrix `V` via the top-level `known_V = V` argument to
#' [gllvmTMB()] when using the exact-additive (default) form. For
#' block-diagonal within-study correlation, build `V` via [block_V()].
#' `type = "proportional"` is not implemented and is deliberately rejected
#' rather than silently treated as exact.
#'
#' @param V Known sampling variance or covariance marker. In current
#'   exact-additive fits, pass the actual matrix via the top-level
#'   `known_V =` argument to [gllvmTMB()]. Formula-level `V = V` names
#'   the marker and keeps the syntax aligned with `drmTMB::meta_V()`.
#' @param type Sampling-covariance mode. `"exact"` is implemented.
#'   `"proportional"` is not implemented and fails clearly in the formula
#'   parser rather than being treated as exact.
#' @return A formula marker; never evaluated.
#' @seealso [meta_known_V()] (deprecated alias); [block_V()];
#'   [gllvmTMB()].
#' @examples
#' \dontrun{
#' # Two-stage meta-regression with a known per-row sampling-variance V.
#' set.seed(131)
#' df <- expand.grid(
#'   site  = factor(seq_len(50)),
#'   trait = factor(paste0("t", 1:3))
#' )
#' df$value <- rnorm(nrow(df), sd = 0.5)
#' df$sampling_var <- runif(nrow(df), min = 0.02, max = 0.08)
#' V <- diag(df$sampling_var)
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1) +
#'     meta_V(V = V, type = "exact"),
#'   data = df, trait = "trait", unit = "site", known_V = V
#' )
#' }
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
#' diagonal variance term, producing
#' \eqn{\boldsymbol\Sigma = \mathrm{diag}(\sigma^2_t)} with identity
#' off-diagonals.
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
#' decomposition.
#'
#' For a scalar marginal-only tier with one variance shared by all traits,
#' use `common = TRUE`. This is the non-deprecated standalone replacement for
#' the legacy scalar diagonal spelling when no `latent()` term is paired on the
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
#' @seealso [latent()], [phylo_indep()], [spatial_indep()],
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

#' One shared trait variance: `scalar(0 + trait | g)`
#'
#' Canonical no-prefix name for the **one-shared-variance** trait covariance:
#' a single variance \eqn{\sigma^2} shared by every trait with zero cross-trait
#' covariance, giving \eqn{\boldsymbol\Sigma_T = \sigma^2 \mathbf I_T}. It is the
#' most parsimonious mode in the covariance grid.
#'
#' `scalar()` desugars byte-identically to
#' `indep(0 + trait | g, common = TRUE)` -- the two spellings fit the same
#' model, tying all trait variances to one shared parameter. Use `scalar()`
#' when you want to commit explicitly to one shared trait-scale variance; use
#' `indep()` for a separate variance per trait, or `dep()` / `latent()` for
#' cross-trait covariance.
#'
#' The shared variance still couples grouping levels through the source
#' (identity for the no-prefix row). The source-specific `phylo_scalar()`,
#' `animal_scalar()`, and `spatial_scalar()` carry the same one-shared-variance
#' meaning on their respective relationship operators.
#'
#' @param formula `0 + trait | g` style formula (LHS is the trait factor,
#'   typically `0 + trait`; RHS is the grouping factor).
#' @return A formula marker; never evaluated.
#' @seealso [indep()], [dep()], [latent()], [phylo_scalar()], [extract_Sigma()].
#' @export
#' @examples
#' \dontrun{
#' # One shared trait variance across all traits (identity cross-trait):
#' fit <- gllvmTMB(value ~ 0 + trait + scalar(0 + trait | site),
#'                 data = df, trait = "trait", unit = "site")
#'
#' # Equivalent longhand:
#' fit <- gllvmTMB(value ~ 0 + trait + indep(0 + trait | site, common = TRUE),
#'                 data = df, trait = "trait", unit = "site")
#' }
scalar <- function(formula) {
  invisible(NULL)
}

#' Per-trait phylogenetic marginal variance: `phylo_indep(0 + trait | species)`
#'
#' Canonical name for **T per-trait phylogenetic variances coupled by
#' the phylo correlation matrix \eqn{\mathbf A}**; standalone =
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
#' (no cross-trait phylogenetic decomposition). Use
#' `phylo_latent(..., unique = TRUE)` for the paired
#' phylogenetic decomposition
#' \eqn{\boldsymbol\Sigma_{\text{phy}} = \boldsymbol\Lambda_{\text{phy}}\boldsymbol\Lambda_{\text{phy}}^\top + \boldsymbol\Psi_{\text{phy}}}.
#'
#' ## Mutual exclusion with `phylo_latent()`
#'
#' Combining `phylo_indep(0 + trait | species)` with
#' `phylo_latent(species, d = K)` is **over-parameterised** and the
#' parser raises a `cli::cli_abort()`.
#'
#' ## Intercept-and-slope form
#'
#' A single-covariate random regression uses
#' `phylo_indep(1 + x | species)` in wide syntax or
#' `phylo_indep(0 + trait + (0 + trait):x | species)` in explicit long syntax.
#' It estimates an intercept--slope block with their correlation fixed to zero.
#'
#' Pass the phylogeny via `tree = phylo` (canonical, sparse \eqn{\mathbf{A}^{-1}}) or
#' `vcv = Cphy` (`r lifecycle::badge("superseded")`, dense). See
#' [phylo_latent()] for the full discussion of the two paths.
#'
#' @param formula Intercept-only `0 + trait | species`, or the supported
#'   one-covariate intercept-and-slope form described above.
#' @param tree An `ape::phylo` object. **Canonical.**
#' @param vcv A tip-only phylogenetic correlation matrix
#'   (`n_species x n_species`). Legacy alias of `A =`.
#' @param A Tip-level relatedness matrix (`n_species x n_species`)
#'   -- alias of `vcv =`, aligned with the `animal_*` family's
#'   argument naming.
#' @param Ainv Sparse precision matrix (inverse of `A`).
#' @param common `FALSE` (default) for a separate phylogenetic variance per
#'   trait; `TRUE` ties all traits to one shared phylogenetic variance
#'   (intercept-only). `phylo_indep(0 + trait | species, common = TRUE)` is the
#'   canonical one-shared-variance spelling and fits the same model as the
#'   soft-deprecated `phylo_scalar(species)`.
#' @return A formula marker; never evaluated.
#' @seealso [phylo_latent()], [phylo_dep()], [indep()],
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
  Ainv = NULL,
  common = FALSE
) {
  invisible(NULL)
}

#' Per-trait spatial marginal field: `spatial_indep(0 + trait | coords)`
#'
#' Canonical name for **T per-trait spatial fields coupled by the SPDE
#' precision matrix \eqn{\mathbf Q}**; standalone =
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
#' and the parser raises a `cli::cli_abort()`.
#'
#' @param formula `0 + trait | coords` style formula (LHS is the trait
#'   factor `0 + trait`; RHS is the `coords` placeholder symbol that
#'   points at the [make_mesh()] coordinate columns).
#' @param coords Character; the column-name pair of spatial coordinates
#'   in `data` (e.g. `c("lon", "lat")`). Resolved by the parser when
#'   supplied as keyword argument; `NULL` when the orientation expresses
#'   the coordinates via the formula RHS.
#' @param mesh An `fmesher` mesh object built via [make_mesh()]. It may be
#'   supplied here or through the top-level `mesh =` argument to [gllvmTMB()].
#'   The engine does not construct a mesh automatically from `coords`.
#' @param common `FALSE` (default) for a separate spatial-field variance per
#'   trait; `TRUE` ties all traits to one shared spatial variance
#'   (intercept-only). `spatial_indep(0 + trait | coords, common = TRUE)` is the
#'   canonical one-shared-variance spelling and fits the same model as the
#'   soft-deprecated `spatial_scalar()`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_latent()], [indep()],
#'   [phylo_indep()], [extract_Sigma()].
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 20, n_species = 4, mean_species_per_site = 4,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 4), seed = 1
#'   )
#'   mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.1)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_indep(0 + trait | site, mesh = mesh),
#'     data  = sim$data,
#'     trait = "trait",
#'     unit  = "site"
#'   )
#' }
#' @export
spatial_indep <- function(formula, coords = NULL, mesh = NULL, common = FALSE) {
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
#' interpretation explicitly. This is a standard multivariate response
#' covariance model. Computational scope: tractable
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
#' @seealso [latent()], [indep()], [phylo_dep()],
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
#' cross-trait phylogenetic covariance fit. Use
#' `phylo_latent(..., unique = TRUE)` for the rank-reduced paired
#' phylogenetic decomposition. Use
#' `phylo_indep()` for the marginal-only per-trait variance fit.
#'
#' ## Mutual exclusion with `phylo_latent()` / `phylo_indep()`
#'
#' Combining `phylo_dep(0 + trait | species)` with `phylo_latent` is
#' **over-parameterised**; combining with
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
#'   argument naming.
#' @param Ainv Sparse precision matrix (inverse of `A`).
#' @return A formula marker; never evaluated.
#' @seealso [phylo_latent()], [phylo_indep()],
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
#' ## Mutual exclusion with `spatial_latent()` / `spatial_indep()`
#'
#' Combining `spatial_dep(0 + trait | coords)` with `spatial_latent` is
#' **over-parameterised**; combining with
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
#' @param mesh An `fmesher` mesh object built via [make_mesh()]. It may be
#'   supplied here or through the top-level `mesh =` argument to [gllvmTMB()].
#'   The engine does not construct a mesh automatically from `coords`.
#' @return A formula marker; never evaluated.
#' @seealso [spatial_latent()], [spatial_indep()],
#'   [dep()], [phylo_dep()], [extract_Sigma()].
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 30, n_species = 6, mean_species_per_site = 5,
#'     spatial_range = 0.4, sigma2_spa = rep(0.3, 6), seed = 1
#'   )
#'   mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.1)
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             spatial_dep(0 + trait | site, mesh = mesh),
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
## Reject duplicate slope covariates in an augmented multi-slope LHS -- each
## slope column creates its own random-effect block, so duplicates make the
## design rank deficient (fail loud before design expansion).
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
    info$lhs_form %in%
      c("wide_intercept_slope", "long_intercept_slope") &&
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
    return(list(
      lhs_form = "intercept_only",
      slope_col = NULL,
      slope_cols = NULL
    ))
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
  ## supported by the engine. Enclosing parens around the LHS (e.g.
  ## `indep((0 + trait) | site)`) are stripped first so they don't cause
  ## a false-positive augmented-LHS classification (#626).
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
    "x" = "This wrapper accepts only intercept-only {.code 0 + trait | g} or {.code 1 | g} forms.",
    ">" = "Use the source-specific {.fn *_indep}, {.fn *_latent}, or {.fn *_dep} keyword when you need a supported intercept-and-slope covariance."
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
          "`0 + trait | coords`, matching `latent()`, `indep()`, and ",
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
  ## HARD GUARD: source-specific `lv = ~ env` (predictor-informed latent means)
  ## is reserved for ordinary latent() only; it must fail loud on source
  ## keywords, never be silently dropped.
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
  .has_named_arg <- function(e, arg) {
    nm <- names(e)
    !is.null(nm) && any(nm == arg, na.rm = TRUE)
  }
  ## Read a literal `common = TRUE/FALSE` from a structured *_indep() call
  ## (Design 79 scalar-collapse). `common = TRUE` folds the per-trait indep
  ## variances to one shared variance, routing to the *_scalar engine. Named
  ## only (the source keywords carry positional tree/vcv/coords/mesh args).
  .read_common_flag <- function(e, fn) {
    common_arg <- e[["common"]]
    if (is.null(common_arg)) {
      return(FALSE)
    }
    if (
      !is.logical(common_arg) ||
        length(common_arg) != 1L ||
        is.na(common_arg)
    ) {
      cli::cli_abort(c(
        "{.arg common} in {.fn {fn}} must be a literal {.code TRUE} or {.code FALSE}.",
        ">" = "Use {.code {fn}(..., common = TRUE)} to tie all trait variances to one shared variance."
      ))
    }
    common_arg
  }
  .abort_unsupported_lv_keyword <- function(fn) {
    cli::cli_abort(c(
      "{.arg lv} is reserved for ordinary {.fn latent} only.",
      "x" = "{.fn {fn}} does not support predictor-informed latent-score means.",
      "i" = "Predictor-informed latent-score means are limited to ordinary unit-tier {.code latent(..., lv = ~ x)} with Gaussian or pure binomial logit/probit/cloglog responses.",
      ">" = "Remove {.arg lv} from {.fn {fn}}; predictor-informed latent scores are not implemented for this covariance source."
    ))
  }
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
        "i" = "{.code type = \"proportional\"} is not implemented; the supported route is exact additive known sampling covariance."
      ))
    }
    if (!type_expr %in% c("exact", "proportional")) {
      cli::cli_abort(c(
        "{.fn {fn}} does not recognise {.val {type_expr}} as a {.arg type}.",
        "i" = "{.arg type} must be one of {.val exact} or {.val proportional}.",
        ">" = "Use {.code {fn}(V = V, type = \"exact\")}."
      ))
    }
    type <- type_expr
    if (identical(type, "proportional")) {
      cli::cli_abort(c(
        "{.code {fn}(type = \"proportional\")} is not implemented.",
        "i" = "The supported route is exact additive known sampling covariance.",
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
      ## `||` uncorrelated intercept-slope coupling (Design 79 §3-4):
      ## `mode(1 + x || g)` == `mode(1|g) + mode(0+x|g)` -- intercept and slope
      ## get their own variances with NO intercept-slope covariance. In R the bar
      ## parses as `||(lhs, g)`. Intercept it before per-fn dispatch: flip the
      ## head to a single `|` so the existing branch runs unchanged, desugar, then
      ## tag the resulting covstruct `.uncorrelated = TRUE` (the engine applies the
      ## fully-diagonal block_size = 1 pin). Only cells whose uncorrelated engine
      ## exists are accepted; every other wrapper fails loud rather than silently
      ## fitting the CORRELATED model under a `||` the user wrote to drop it.
      if (
        length(fn) == 1L &&
          length(e) >= 2L &&
          is.call(e[[2L]]) &&
          identical(e[[2L]][[1L]], as.name("||"))
      ) {
        .uncorr_marked <- c("phylo_indep", "animal_indep",
                             "phylo_dep", "animal_dep",
                             "kernel_indep", "kernel_dep",
                             "spatial_indep", "spatial_dep")
        .uncorr_latent <- c("phylo_latent", "animal_latent", "spatial_latent")
        if (!fn %in% c(.uncorr_marked, .uncorr_latent)) {
          cli::cli_abort(c(
            "{.code ||} (uncorrelated intercept--slope) is not yet supported for {.fn {fn}}.",
            "i" = "The `||` coupling currently ships for {.fn phylo_indep}/{.fn animal_indep}, {.fn phylo_dep}/{.fn animal_dep}, and the source-tier {.fn phylo_latent}/{.fn animal_latent}/{.fn spatial_latent} random slopes; other modes/sources are on the way.",
            ">" = "Use a single {.code |} for the correlated form, or one of those keywords with {.code ||}."
          ))
        }
        bar <- e[[2L]]
        bar[[1L]] <- as.name("|")
        e_single <- e
        e_single[[2L]] <- bar
        desugared <- rewrite(e_single)
        if (fn %in% .uncorr_latent) {
          ## Source-tier latent slopes are ALREADY the uncorrelated form: each
          ## (intercept, slope) column block gets its own reduced-rank
          ## Lambda_k Lambda_k^T with NO intercept-slope covariance (Design 79
          ## §7.1). The `||` spelling routes to that same engine unchanged -- no
          ## marker needed. (`latent |` shared-factor correlation is deferred.)
          return(desugared)
        }
        ## indep/dep: tag the resulting slope covstruct (phylo_slope for the
        ## phylo/animal/kernel sources, spde for spatial) with `.uncorrelated`
        ## so the engine applies the fully-diagonal (indep) / parity (dep) pin.
        if (
          is.call(desugared) &&
            (identical(desugared[[1L]], as.name("phylo_slope")) ||
              identical(desugared[[1L]], as.name("spde")))
        ) {
          return(as.call(c(as.list(desugared), list(.uncorrelated = TRUE))))
        }
        cli::cli_abort(c(
          "{.code ||} on {.fn {fn}} did not resolve to a random-slope term.",
          "i" = "`||` requires an intercept-and-slope LHS, e.g. {.code {fn}(1 + x || g)}."
        ))
      }
      if (length(fn) == 1L && fn %in% .source_specific_lv_keywords) {
        .abort_source_specific_lv(e, fn)
      }
      if (
        !identical(fn, "latent") &&
          .has_named_arg(e, "lv") &&
          fn %in%
            c(
              "unique",
              "diag",
              "indep",
              "dep",
              "phylo",
              "gr",
              "phylo_scalar",
              "phylo_unique",
              "phylo_indep",
              "phylo_latent",
              "phylo_dep",
              "animal_scalar",
              "animal_unique",
              "animal_indep",
              "animal_latent",
              "animal_dep",
              "spatial",
              "spatial_scalar",
              "spatial_unique",
              "spatial_indep",
              "spatial_latent",
              "spatial_dep",
              "spde",
              "kernel_latent",
              "kernel_unique",
              "kernel_indep",
              "kernel_dep"
            )
      ) {
        .abort_unsupported_lv_keyword(fn)
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
        unique_arg <- get_arg("unique", default = NULL)

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
              "x" = "The unified {.fn spatial} wrapper accepts only intercept-only {.code 1 | site} or {.code 0 + trait | site} forms.",
              ">" = "For a supported intercept-and-slope covariance, use {.fn spatial_indep}, {.fn spatial_latent}, or {.fn spatial_dep}."
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
              "i" = "Choose {.val indep} (per-trait independent fields), {.val latent} (reduced-rank shared spatial factors; requires {.arg d}), or {.val dep} (full unstructured T x T)."
            ))
          }
          valid_modes <- c("diag", "indep", "latent", "dep")
          if (!mode_str %in% valid_modes) {
            cli::cli_abort(c(
              "{.code mode = {.val {mode_str}}} is not a recognised mode.",
              "i" = "Current modes for LHS = {.code 0 + trait} are {.val indep}, {.val latent}, and {.val dep}."
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
            latent_extras <- extras
            if (!is.null(unique_arg)) {
              latent_extras$unique <- unique_arg
            }
            new_call <- as.call(c(
              list(as.name("spatial_latent"), bar, d = d_use),
              latent_extras
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
          .gllvmTMB_warn_scalar_family_deprecated(fn)
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
              ">" = "For current syntax, use {.code animal_indep(1 + x | id, pedigree = ped)} when intercept--slope correlation is fixed to zero, or {.code animal_dep(1 + x | id, pedigree = ped)} for a full covariance."
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
        ##                                 + phylo_rr(id, .phylo_unique = TRUE,
        ##                                            .auto_unique = TRUE, vcv = A)
        ## by default. `unique = FALSE` preserves the older loadings-only route.
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
              ## Augmented animal_latent(1 + x | id) is loadings-only by default.
              ## `unique = TRUE` folds in the augmented intercept-slope companion,
              ## byte-identical to the explicit pair
              ##   animal_latent(1 + x | id) + animal_unique(1 + x | id).
              ## The companion is the same phylo_slope covstruct animal_unique()
              ## builds for the augmented form (Design 77, unique= complete arc).
              unique_arg <- e[["unique"]]
              if (is.null(unique_arg)) unique_arg <- FALSE
              if (
                !is.logical(unique_arg) ||
                  length(unique_arg) != 1L ||
                  is.na(unique_arg)
              ) {
                cli::cli_abort(c(
                  "{.arg unique} in {.fn animal_latent} must be a literal {.code TRUE} or {.code FALSE}.",
                  ">" = "Use {.code animal_latent(..., unique = FALSE)} for the loadings-only subset."
                ))
              }
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
              if (isFALSE(unique_arg)) {
                return(new_call)
              }
              ## unique = TRUE: fold in the augmented intercept-slope companion.
              psi_call <- as.call(c(
                list(as.name("phylo_slope"), arg),
                list(
                  .phylo_unique_augmented = TRUE,
                  lhs_form = lhs_form$lhs_form,
                  slope_col = lhs_form$slope_col
                ),
                list(vcv = vcv_expr)
              ))
              return(call("+", new_call, psi_call))
            }
          }
          new_call <- as.call(c(
            list(as.name("phylo_rr"), e[[2L]]),
            list(d = d_val),
            list(vcv = vcv_expr)
          ))
          unique_arg <- e[["unique"]]
          if (is.null(unique_arg)) {
            unique_arg <- FALSE
          }
          if (
            !is.logical(unique_arg) ||
              length(unique_arg) != 1L ||
              is.na(unique_arg)
          ) {
            cli::cli_abort(c(
              "{.arg unique} in {.fn animal_latent} must be a literal {.code TRUE} or {.code FALSE}.",
              ">" = "Use {.code animal_latent(..., unique = FALSE)} for the loadings-only subset."
            ))
          }
          if (isFALSE(unique_arg)) {
            return(new_call)
          }
          psi_call <- as.call(c(
            list(as.name("phylo_rr"), e[[2L]]),
            list(.phylo_unique = TRUE, .auto_unique = TRUE),
            list(vcv = vcv_expr)
          ))
          return(call("+", new_call, psi_call))
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
          ## `common = TRUE` (Design 79 scalar-collapse): tie the T per-trait
          ## additive-genetic variances to ONE shared variance -- byte-identical
          ## to the (soft-deprecated) `animal_scalar(id)` (`phylo(id, vcv = A)`).
          if (isTRUE(.read_common_flag(e, fn))) {
            if (
              lhs_form$lhs_form %in%
                c("wide_intercept_slope", "long_intercept_slope")
            ) {
              cli::cli_abort(c(
                "{.code animal_indep(..., common = TRUE)} is intercept-only.",
                ">" = "One shared variance across traits applies to {.code animal_indep(0 + trait | id, common = TRUE)}; the shared-variance random slope is not yet supported."
              ))
            }
            new_call <- call("phylo", species_arg)
            new_call[["vcv"]] <- vcv_expr
            return(new_call)
          }
          if (
            lhs_form$lhs_form %in%
              c("wide_intercept_slope", "long_intercept_slope")
          ) {
            new_call <- as.call(c(
              list(as.name("phylo_slope"), bar),
              list(
                ## Per-trait block-diagonal (Design 79/80): dep 2T-wide engine
                ## with cross-block Cholesky pinned -> T stacked univariate
                ## random regressions. Shares the phylo_slope engine; A via vcv.
                .phylo_dep_augmented = TRUE,
                .indep_blockdiag = TRUE,
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
          c("kernel_latent", "kernel_unique", "kernel_indep", "kernel_dep",
            "kernel_scalar")
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
        ## Random-slope bar handling (B1). Kernel keywords normally take a bare
        ## grouping column; a `1 + x | g` bar is a random slope. kernel_indep and
        ## kernel_dep route it to the SAME augmented phylo_slope engine as
        ## animal_indep / animal_dep, carrying `vcv = K` + the kernel metadata
        ## (dense-kernel = phylo with a supplied K; no new C++). Other kernel modes'
        ## slopes are not yet wired -> fail loud (previously a silent Sokal
        ## mis-parse into a garbled `lhs = 0 + (1 + x | g)`, `group = trait`).
        if (
          is.call(unit_arg) &&
            identical(unit_arg[[1L]], as.name("|")) &&
            length(unit_arg) == 3L
        ) {
          lhs_form <- .gllvmTMB_lhs_form(unit_arg[[2L]])
          is_slope <- lhs_form$lhs_form %in%
            c("wide_intercept_slope", "long_intercept_slope")
          if (is_slope && fn %in% c("kernel_indep", "kernel_dep")) {
            marks <- list(
              .phylo_dep_augmented = TRUE,
              lhs_form = lhs_form$lhs_form,
              slope_col = lhs_form$slope_col
            )
            if (fn == "kernel_indep") marks$.indep_blockdiag <- TRUE
            return(as.call(c(
              list(as.name("phylo_slope"), unit_arg),
              marks,
              list(
                vcv = K_expr,
                .kernel_name = name_expr,
                .kernel_mode = sub("^kernel_", "", fn)
              )
            )))
          }
          cli::cli_abort(c(
            "{.fn {fn}} does not support this random-slope bar yet.",
            "i" = "Kernel random slopes are wired for {.fn kernel_indep} and {.fn kernel_dep} ({.code 1 + x | g}); other kernel modes are on the way.",
            ">" = "Use {.fn kernel_indep}/{.fn kernel_dep} for kernel random slopes, or a bare grouping column for an intercept-only kernel term."
          ))
        }
        kernel_meta <- list(
          vcv = K_expr,
          .kernel_name = name_expr,
          .kernel_mode = sub("^kernel_", "", fn)
        )
        if (fn == "kernel_latent") {
          d_val <- .named_or_positional_arg(e, "d", 4L, default = 1L)
          unique_arg <- if ("unique" %in% nm) {
            e[[which(nm == "unique")]]
          } else {
            FALSE
          }
          if (
            !is.logical(unique_arg) ||
              length(unique_arg) != 1L ||
              is.na(unique_arg)
          ) {
            cli::cli_abort(c(
              "{.arg unique} in {.fn kernel_latent} must be a literal {.code TRUE} or {.code FALSE}.",
              ">" = "Use {.code kernel_latent(..., unique = FALSE)} for the loadings-only subset."
            ))
          }
          latent_call <- as.call(c(
            list(as.name("phylo_rr"), unit_arg),
            list(d = d_val),
            kernel_meta
          ))
          if (isFALSE(unique_arg)) {
            return(latent_call)
          }
          psi_kernel_meta <- kernel_meta
          psi_kernel_meta$.kernel_mode <- "unique"
          psi_call <- as.call(c(
            list(as.name("phylo_rr"), unit_arg),
            list(.phylo_unique = TRUE, .auto_unique = TRUE),
            psi_kernel_meta
          ))
          return(call("+", latent_call, psi_call))
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
          ## `common = TRUE` (Design 79 scalar-collapse): tie the T per-trait
          ## dense-kernel variances to ONE shared variance -- byte-identical to
          ## the (soft-deprecated) `kernel_scalar()`. Same diagonal phylo_rr
          ## path; `.kernel_mode = "scalar"` drives the single-level tie in
          ## fit-multi.R (the theta_rr_phy analogue of spatial_scalar's tie).
          if (isTRUE(.read_common_flag(e, fn))) {
            kernel_meta$.kernel_mode <- "scalar"
          }
          return(as.call(c(
            list(as.name("phylo_rr"), unit_arg),
            list(.phylo_unique = TRUE, .indep = TRUE),
            kernel_meta
          )))
        }
        if (fn == "kernel_scalar") {
          .gllvmTMB_warn_scalar_family_deprecated(fn)
          ## One shared variance x K: same diagonal phylo_rr engine path as
          ## kernel_indep, but `.kernel_mode = "scalar"` (carried in
          ## kernel_meta) tells fit-multi.R to tie the per-trait theta_rr_phy
          ## diagonal to a single shared level -- the dense-kernel analogue of
          ## spatial_scalar()'s log_tau_spde tie.
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
              if (
                !is.logical(common_arg) ||
                  length(common_arg) != 1L ||
                  is.na(common_arg)
              ) {
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
            d_arg <- e[["d"]]
            if (is.null(d_arg)) {
              d_arg <- 1L
            }
            ## #608: honour unique= (default TRUE) / residual= alias on the
            ## augmented ordinary latent form. unique = FALSE opts out of the
            ## per-trait unique-variance diagonal companion; the engine's
            ## diag_B_slope_is_default gate reads the marker below.
            aug_unique_supplied <- "unique" %in% names(e)
            aug_residual_supplied <- "residual" %in% names(e)
            if (aug_unique_supplied && aug_residual_supplied) {
              cli::cli_abort(c(
                "Supply only one of {.arg unique} and {.arg residual} to {.fn latent}.",
                "i" = "{.arg residual} is a soft-deprecated alias for {.arg unique}.",
                ">" = "Use {.code latent(..., unique = ...)}."
              ))
            }
            if (aug_residual_supplied) {
              .gllvmTMB_warn_latent_residual_alias()
              aug_unique_arg <- e[["residual"]]
            } else {
              aug_unique_arg <- e[["unique"]]
            }
            if (is.null(aug_unique_arg)) {
              aug_unique_arg <- TRUE
            }
            if (
              !is.logical(aug_unique_arg) ||
                length(aug_unique_arg) != 1L ||
                is.na(aug_unique_arg)
            ) {
              cli::cli_abort(c(
                "{.arg unique} in {.fn latent} must be a literal {.code TRUE} or {.code FALSE}.",
                ">" = "Use {.code latent(1 + x | g, d = K, unique = FALSE)} for the low-rank-only subset."
              ))
            }
            if (.has_named_arg(e, "lv")) {
              cli::cli_abort(c(
                "{.arg lv} cannot yet be combined with augmented ordinary {.fn latent} random-regression syntax.",
                "x" = "Predictor-informed latent-score means require an intercept-only ordinary latent block.",
                ">" = "Use {.code latent(0 + trait | unit, d = K, lv = ~ x)} without an augmented LHS."
              ))
            }
            return(as.call(c(
              list(as.name("rr"), bar),
              list(
                d = d_arg,
                .latent_augmented = TRUE,
                .latent_augmented_unique = aug_unique_arg,
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
            ## Augmented phylo_latent(1 + x | sp) is loadings-only by default.
            ## `unique = TRUE` folds in the augmented intercept-slope companion,
            ## byte-identical to the explicit pair
            ##   phylo_latent(1 + x | sp) + phylo_unique(1 + x | sp).
            ## The companion is the same phylo_slope covstruct phylo_unique()
            ## builds for the augmented form (Design 77, unique= complete arc).
            unique_arg <- e[["unique"]]
            if (is.null(unique_arg)) unique_arg <- FALSE
            if (
              !is.logical(unique_arg) ||
                length(unique_arg) != 1L ||
                is.na(unique_arg)
            ) {
              cli::cli_abort(c(
                "{.arg unique} in {.fn phylo_latent} must be a literal {.code TRUE} or {.code FALSE}.",
                ">" = "Use {.code phylo_latent(..., unique = FALSE)} for the loadings-only subset."
              ))
            }
            d_arg <- .named_or_positional_arg(e, "d", 3L, default = 1L)
            ## User-supplied tree / vcv / A / Ainv, shared by both folded pieces.
            src_extras <- list()
            for (a in c("tree", "vcv", "A", "Ainv")) {
              if (!is.null(e[[a]])) src_extras[[a]] <- e[[a]]
            }
            new_call <- as.call(c(
              list(as.name("phylo_rr"), species_arg),
              list(d = d_arg),
              list(
                .latent_slope = TRUE,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              src_extras
            ))
            if (isFALSE(unique_arg)) {
              return(new_call)
            }
            ## unique = TRUE: fold in the augmented intercept-slope companion.
            psi_call <- as.call(c(
              list(as.name("phylo_slope"), bar),
              list(
                .phylo_unique_augmented = TRUE,
                lhs_form = lhs_form$lhs_form,
                slope_col = lhs_form$slope_col
              ),
              src_extras
            ))
            return(call("+", new_call, psi_call))
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
        if (identical(fn, "phylo_latent")) {
          ## `phylo_latent(species, d)` renames straight to `phylo_rr`, whose
          ## own arg-matching downstream (parse_covstruct_call()) only maps
          ## unnamed positional args to a name for `rr` / `propto` / `equalto`,
          ## not `phylo_rr` -- so a positional `d` here would be silently
          ## dropped. Normalise it to a named `d =` before the rename.
          d_val <- .named_or_positional_arg(e, "d", 3L, default = 1L)
          new_call <- as.call(c(
            list(as.name(target), e[[2L]]),
            list(d = d_val),
            .pass_through_extras(e, c("unique", "tree", "vcv", "A", "Ainv"))
          ))
        }
        if (identical(fn, "latent")) {
          ## `unique =` is the canonical argument (matches
          ## extract_Sigma(part = "unique")). `residual =` is a soft-deprecated
          ## alias for the argument shipped in 0.2.0 (#505); it routes to `unique`.
          unique_supplied <- "unique" %in% names(e)
          residual_supplied <- "residual" %in% names(e)
          if (unique_supplied && residual_supplied) {
            cli::cli_abort(c(
              "Supply only one of {.arg unique} and {.arg residual} to {.fn latent}.",
              "i" = "{.arg residual} is a soft-deprecated alias for {.arg unique}.",
              ">" = "Use {.code latent(..., unique = ...)}."
            ))
          }
          if (residual_supplied) {
            .gllvmTMB_warn_latent_residual_alias()
            unique_arg <- e[["residual"]]
          } else {
            unique_arg <- e[["unique"]]
          }
          if (is.null(unique_arg)) {
            unique_arg <- TRUE
          }
          if (
            !is.logical(unique_arg) ||
              length(unique_arg) != 1L ||
              is.na(unique_arg)
          ) {
            cli::cli_abort(c(
              "{.arg unique} in {.fn latent} must be a literal {.code TRUE} or {.code FALSE}.",
              ">" = "Use {.code latent(..., unique = FALSE)} for the loadings-only subset."
            ))
          }

          common_arg <- e[["common"]]
          if (is.null(common_arg)) {
            common_arg <- FALSE
          }
          if (
            !is.logical(common_arg) ||
              length(common_arg) != 1L ||
              is.na(common_arg)
          ) {
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
          if (.has_named_arg(new_call, "lv")) {
            new_call[["lv_formula"]] <- new_call[["lv"]]
            new_call[["lv"]] <- NULL
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
          ## Bare latent() (neither unique= nor residual= given) now carries Psi
          ## by default: one-shot fire-on-use notice of the silent behavior change.
          if (!unique_supplied && !residual_supplied) {
            .gllvmTMB_warn_latent_default_psi()
          }
          psi_extras <- list(.auto_unique = TRUE)
          if (isTRUE(common_arg)) {
            psi_extras$common <- TRUE
          }
          psi_call <- as.call(c(list(as.name("diag"), e[[2L]]), psi_extras))
          return(call("+", new_call, psi_call))
        }
        ## Phylo latent-Psi fold: source-specific latent terms stay loadings-only
        ## by default; explicit unique=TRUE collapses the compatibility pair into
        ## a single phylo_latent(d=K, unique = TRUE). The auto-companion is the
        ## phylo-structured diagonal Psi_phy (x) A, i.e. phylo_rr(species,
        ## .phylo_unique = TRUE, .auto_unique = TRUE), NOT a plain diag. Augmented
        ## phylo_latent(1 + x | sp) is handled+returned earlier (.latent_slope), so
        ## this only sees the intercept-only form.
        if (identical(fn, "phylo_latent")) {
          unique_arg <- e[["unique"]]
          if (is.null(unique_arg)) {
            unique_arg <- FALSE
          }
          if (
            !is.logical(unique_arg) ||
              length(unique_arg) != 1L ||
              is.na(unique_arg)
          ) {
            cli::cli_abort(c(
              "{.arg unique} in {.fn phylo_latent} must be a literal {.code TRUE} or {.code FALSE}.",
              ">" = "Use {.code phylo_latent(..., unique = FALSE)} for the loadings-only subset."
            ))
          }
          new_call_names <- names(new_call)
          if (!is.null(new_call_names)) {
            drop_args <- new_call_names %in% "unique"
            if (any(drop_args)) new_call <- new_call[!drop_args]
          }
          if (isFALSE(unique_arg)) {
            return(new_call)
          }
          phy_psi_extras <- .pass_through_extras(e, c("tree", "vcv", "A", "Ainv"))
          psi_call <- as.call(c(
            list(as.name("phylo_rr"), e[[2L]]),
            list(.phylo_unique = TRUE, .auto_unique = TRUE),
            phy_psi_extras
          ))
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
        A_arg <- get_arg("A", default = NULL)
        Ainv_arg <- get_arg("Ainv", default = NULL)
        d_arg <- get_arg("d", default = NULL)
        unique_arg <- get_arg("unique", default = NULL)

        ## Helper: extras to splice into the rewritten call (named
        ## relatedness args only -- mode/d are interpreted here, not forwarded).
        extras <- list()
        if (!is.null(tree_arg)) {
          extras$tree <- tree_arg
        }
        if (!is.null(vcv_arg)) {
          extras$vcv <- vcv_arg
        }
        if (!is.null(A_arg)) {
          extras$A <- A_arg
        }
        if (!is.null(Ainv_arg)) {
          extras$Ainv <- Ainv_arg
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
            "x" = "The unified {.fn phylo} wrapper accepts only intercept-only {.code 1 | species} or {.code 0 + trait | species} forms.",
            ">" = "For a supported intercept-and-slope covariance, use {.fn phylo_indep}, {.fn phylo_latent}, or {.fn phylo_dep}."
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
            "i" = "Choose {.val indep} (per-trait independent variances on A), {.val latent} (reduced-rank cross-trait covariance; requires {.arg d}), or {.val dep} (full unstructured T x T covariance)."
          ))
        }
        valid_modes <- c("diag", "indep", "latent", "dep")
        if (!mode_str %in% valid_modes) {
          cli::cli_abort(c(
            "{.code mode = {.val {mode_str}}} is not a recognised mode.",
            "i" = "Current modes for LHS = {.code 0 + trait} are {.val indep}, {.val latent}, and {.val dep}."
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
          latent_extras <- extras
          if (!is.null(unique_arg)) {
            latent_extras$unique <- unique_arg
          }
          new_call <- as.call(c(
            list(as.name("phylo_latent"), rhs, d = d_use),
            latent_extras
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
        .gllvmTMB_warn_scalar_family_deprecated(fn)
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
        extras <- .pass_through_extras(e, c("tree", "vcv", "A", "Ainv"))
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
              ">" = "For new code, use {.code phylo_indep(1 + x | species)} when intercept--slope correlation is fixed to zero, or {.code phylo_dep(1 + x | species)} for a full covariance."
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
            "x" = "Accepted forms are {.code 1 + x | species} and {.code 0 + trait + (0 + trait):x | species}.",
            ">" = "Use one named slope covariate and keep the intercept in this compatibility form."
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
        .gllvmTMB_warn_scalar_family_deprecated(fn)
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
            if (isTRUE(unique_val)) {
              ## Augmented fold: spatial_latent(1 + x | coords, unique = TRUE)
              ## desugars to the loadings-only slope + the augmented
              ## spatial_unique companion -- both SPDE slope engines
              ## (use_spde_latent_slope + use_spde_slope) co-active, identifiable
              ## (recovers on the fold's own DGP), and byte-identical to the
              ## explicit pair (Design 77, unique= complete arc).
              loadings_call <- as.call(c(
                list(as.name("spde"), bar),
                list(
                  .spatial_latent_augmented = TRUE,
                  d = d_val,
                  .spatial_unique_diag = FALSE,
                  lhs_form = lhs_form$lhs_form,
                  slope_col = lhs_form$slope_col
                ),
                extras
              ))
              companion_call <- as.call(c(
                list(as.name("spde"), bar),
                list(
                  .spatial_unique_augmented = TRUE,
                  lhs_form = lhs_form$lhs_form,
                  slope_col = lhs_form$slope_col
                ),
                extras
              ))
              return(call("+", loadings_call, companion_call))
            }
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
          list(
            .spatial_latent = TRUE,
            d = d_val,
            .spatial_unique_diag = unique_val
          ),
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
      ## `scalar(form)` -> `diag(form, .indep = TRUE, common = TRUE)`
      ## The no-prefix one-shared-variance mode: byte-identical to
      ## `indep(form, common = TRUE)`, tying all trait variances to one shared
      ## parameter (fit-multi.R diag_B_common / diag_W_common). Intercept-only
      ## for now; an augmented `scalar(1 + x | g)` slope is a later slice, so we
      ## fail loud rather than silently drop or malform it.
      if (fn == "scalar") {
        .gllvmTMB_warn_scalar_family_deprecated(fn)
        .assert_no_augmented_lhs(fn, e)
        new_call <- as.call(c(
          list(as.name("diag"), e[[2L]]),
          list(.indep = TRUE, common = TRUE)
        ))
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
        ## `common = TRUE` (Design 79 scalar-collapse): tie the T per-trait
        ## phylogenetic variances to ONE shared variance -- byte-identical to the
        ## (soft-deprecated) `phylo_scalar(species)`, which renames to `phylo()`.
        if (isTRUE(.read_common_flag(e, fn))) {
          if (!.is_zero_plus_trait(lhs_bar)) {
            cli::cli_abort(c(
              "{.code phylo_indep(..., common = TRUE)} is intercept-only.",
              "i" = "Got LHS: {.code {deparse(lhs_bar)}}.",
              ">" = "One shared variance across traits applies to {.code phylo_indep(0 + trait | species, common = TRUE)}; the shared-variance random slope (former {.code scalar(1 + x | g)}) is not yet supported."
            ))
          }
          extras <- .pass_through_extras(e, c("tree", "vcv", "A", "Ainv"))
          new_call <- as.call(c(list(as.name("phylo"), species_arg), extras))
          return(new_call)
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
          extras <- .pass_through_extras(e, c("tree", "vcv", "A", "Ainv"))
          new_call <- as.call(c(
            list(as.name("phylo_slope"), bar),
            list(
              ## Per-trait block-diagonal (Design 79/80): the dep 2T-wide engine
              ## with the cross-block Cholesky entries pinned -> T independent
              ## (intercept, slope) 2x2 blocks = T stacked univariate random
              ## regressions, each with its own intercept-slope correlation.
              .phylo_dep_augmented = TRUE,
              .indep_blockdiag = TRUE,
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
        extras <- .pass_through_extras(e, c("tree", "vcv", "A", "Ainv"))
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
        ## `common = TRUE` (Design 79 scalar-collapse): tie the T per-trait
        ## spatial-field variances to ONE shared variance -- byte-identical to the
        ## (soft-deprecated) `spatial_scalar()` (`spde(form, .spatial_scalar =
        ## TRUE)`). Intercept-only; the shared-variance spatial slope is deferred.
        if (isTRUE(.read_common_flag(e, fn))) {
          if (
            length(e) >= 2L &&
              is.call(e[[2L]]) &&
              identical(e[[2L]][[1L]], as.name("|")) &&
              length(e[[2L]]) == 3L &&
              .gllvmTMB_lhs_form(e[[2L]][[2L]])$lhs_form %in%
                c("wide_intercept_slope", "long_intercept_slope")
          ) {
            cli::cli_abort(c(
              "{.code spatial_indep(..., common = TRUE)} is intercept-only.",
              ">" = "One shared variance across traits applies to {.code spatial_indep(0 + trait | coords, common = TRUE)}; the shared-variance spatial random slope is not yet supported."
            ))
          }
          new_call <- as.call(c(
            list(as.name("spde"), e[[2L]]),
            list(.spatial_scalar = TRUE),
            extras
          ))
          return(new_call)
        }
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
                ## Design 79/80 (B2): per-trait block-diagonal spatial slope,
                ## mirroring phylo_indep/animal_indep -- the spde dep 2T-wide
                ## engine (use_spde_dep_slope) with the cross-block Cholesky
                ## entries pinned (use_spde_indep_blockdiag), giving T independent
                ## (intercept, slope) spatial-field blocks with the intercept-slope
                ## correlation estimated per trait. Migrated off the former shared-
                ## field path; verified locally with fmesher (no INLA needed).
                .spatial_dep_augmented = TRUE,
                .indep_blockdiag = TRUE,
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
          extras <- .pass_through_extras(e, c("tree", "vcv", "A", "Ainv"))
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
          extras <- .pass_through_extras(e, c("tree", "vcv", "A", "Ainv"))
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
##   spde      -> use spatial_indep()
##   spatial   -> use spatial_indep() (lifecycle::deprecate_warn at 0.1.2)
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
    rr = list(new = "latent", args = "0 + trait | g, d = K"),
    diag = list(
      new = "indep",
      args = "0 + trait | g",
      guidance = "Use ordinary latent(..., d = K) for the default shared + diagonal-Psi decomposition, or indep(0 + trait | g) for a standalone diagonal."
    ),
    phylo_rr = list(new = "phylo_latent", args = "species, d = K", see = "phylo_latent"),
    phylo = list(new = "phylo_scalar", args = "species", see = "phylo_scalar"),
    spde = list(new = "spatial_indep", args = "coords | trait", see = "spatial_indep"),
    meta = list(new = "meta_V", args = "V = V", see = "meta_V"),
    gr = list(new = "phylo_scalar", args = "species", see = "phylo_scalar")
  )
  ## A bar as the first argument (e.g. `phylo(0 + trait | species, ...)`) marks
  ## the documented mode-dispatch calling convention, which is first-class and
  ## must NOT receive the legacy bare-`phylo(species)` alias deprecation.
  is_bar_first_arg <- function(e) {
    length(e) >= 2L &&
      is.call(e[[2L]]) &&
      identical(e[[2L]][[1L]], as.name("|")) &&
      length(e[[2L]]) == 3L
  }
  ## `spatial()` is a documented first-class mode-dispatch wrapper (the spatial
  ## parallel of `phylo()`): a scalar `spatial(1 | site)` and any bar-form call
  ## carrying an explicit `mode =` dispatch to a canonical `spatial_*()` keyword
  ## and must NOT receive the legacy `spatial() -> spatial_indep()` alias
  ## deprecation. Only a legacy bare form (`spatial(0 + trait | coords)` with no
  ## mode, or the old `spatial(coords | trait)` orientation) is the deprecated
  ## alias.
  spatial_is_firstclass <- function(e) {
    if (!is_bar_first_arg(e)) {
      return(FALSE)
    }
    lhs <- e[[2L]][[2L]]
    is_scalar <- identical(lhs, 1) || identical(lhs, 1L)
    has_mode <- "mode" %in% names(e)
    is_scalar || has_mode
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
        if (fn == "spatial" && !spatial_is_firstclass(e)) {
          lifecycle::deprecate_warn(
            when = "0.1.2",
            what = "spatial()",
            with = "spatial_indep()",
            details = c(
              "i" = "spatial(coords | trait) is now an alias for spatial_indep(0 + trait | coords).",
              ">" = "Update existing code to spatial_indep() to keep the rank explicit."
            )
          )
        } else if (fn == "spatial") {
          ## first-class mode-dispatch form (`spatial(1 | site)` or an explicit
          ## `mode =`): dispatched downstream, no deprecation here.
        } else if (fn == "phylo" && is_bar_first_arg(e)) {
          ## `phylo(0 + trait | species, mode = ..., d = ..., tree = ...)` is the
          ## documented first-class mode-dispatch form, NOT the legacy
          ## `phylo(species)` alias -- do not emit the deprecation here. The
          ## unconditional recursion below still walks its arguments.
        } else if (fn %in% names(deprecated_map)) {
          d <- deprecated_map[[fn]]
          .gllvmTMB_warn_keyword_deprecated(fn, d$new, d$args, d$guidance, d$see)
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
