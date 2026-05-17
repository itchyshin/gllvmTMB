## Animal-model keyword family for the gllvmTMB formula grammar.
##
## Per the drmTMB-team review (2026-05-17) and `docs/design/14-known-
## relatedness-keywords.md`: `animal_*` mirrors `phylo_*` exactly,
## with three input forms (pedigree, A, Ainv) replacing the
## phylo-equivalent (tree, vcv). Routes internally to the same
## canonical-rewrite path as `phylo_*` (no engine-side change; pure
## sugar).
##
## API parallel:
##
##   animal_scalar(id, pedigree, A, Ainv)   parallel to phylo_scalar(species, tree, vcv)
##   animal_unique(id, pedigree, A, Ainv)               phylo_unique
##   animal_indep(formula, pedigree, A, Ainv)           phylo_indep
##   animal_latent(id, d, pedigree, A, Ainv)            phylo_latent
##   animal_dep(formula, pedigree, A, Ainv)             phylo_dep
##   animal_slope(formula)                              phylo_slope
##
## Argument convention: **A** / **Ainv** for relatedness covariance /
## precision. **V** is reserved for `meta_known_V()` (meta-analytic
## sampling variance) and **must not** be used for relatedness.

#' Single-shared-variance animal-model random effect: `animal_scalar(id)`
#'
#' Canonical name for the single-scalar (per-trait) animal-model
#' random intercept. Each trait carries an independent length-`n_ids`
#' draw
#' \eqn{\mathbf p_t \sim \mathcal{N}(\mathbf{0}, \sigma^{2}_{\text{a}}\,\mathbf{A})}
#' where \eqn{\mathbf A} is the **additive genetic relatedness matrix**
#' (the pedigree-derived numerator-relationship matrix). The variance
#' \eqn{\sigma^{2}_{\text{a}}} is shared across traits.
#'
#' Mathematical parallel to [phylo_scalar()] — same engine path; the
#' only difference is that **A** is supplied via `pedigree =` (a
#' 3-column data frame: id, sire, dam), `A =` (dense \eqn{n \times n}
#' relatedness matrix), or `Ainv =` (sparse precision; densified
#' internally for v0.2.0 — sparse-Ainv direct engine path is a v0.3.0
#' follow-up).
#'
#' @param id Bare column name of the individual factor.
#' @param pedigree A 3-column data frame with columns `id`, `sire`,
#'   `dam` (unknown parents encoded as `NA`). Converted internally
#'   to **A** via Henderson's recursive formula. Only one of
#'   `pedigree`, `A`, or `Ainv` should be given.
#' @param A Dense relatedness matrix (\eqn{n \times n}); rownames /
#'   colnames must match levels of `id`.
#' @param Ainv Sparse precision matrix (inverse of A). Currently
#'   densified for v0.2.0; sparse engine path is a v0.3.0 follow-up.
#'
#' @return Used inside a [gllvmTMB()] formula. Returns `invisible(NULL)`
#'   when called outside a formula — the keyword is a syntactic marker
#'   that the parser rewrites internally to the canonical
#'   [phylo_scalar()] path (which is family-agnostic at the math level).
#'
#' @seealso [animal_unique()], [animal_indep()], [animal_latent()],
#'   [animal_dep()], [animal_slope()], [phylo_scalar()],
#'   [meta_known_V()] (sampling variance, distinct from relatedness).
#'
#' @export
animal_scalar <- function(id, pedigree = NULL, A = NULL, Ainv = NULL) {
  invisible(NULL)
}

#' Per-trait independent animal-model random intercepts: `animal_unique(id)`
#'
#' Canonical name for the **D independent** animal-model random
#' intercept on a shared relatedness matrix \eqn{\mathbf A}. Each
#' trait gets its own variance \eqn{\sigma^{2}_{\text{a},t}}; traits
#' share the same per-individual draws (rows of A act on each trait
#' independently). Mathematical parallel to [phylo_unique()].
#'
#' @inheritParams animal_scalar
#' @return See [animal_scalar()].
#' @seealso [animal_scalar()], [animal_indep()], [animal_latent()],
#'   [animal_dep()], [phylo_unique()].
#' @export
animal_unique <- function(id, pedigree = NULL, A = NULL, Ainv = NULL) {
  invisible(NULL)
}

#' Independent per-trait animal-model random intercepts: `animal_indep(0 + trait | id)`
#'
#' Per-trait animal-model random intercepts with no cross-trait
#' covariance. Engine-equivalent to [animal_unique()] but uses the
#' bar-form syntax; the `.indep` marker disambiguates printing.
#' Mathematical parallel to [phylo_indep()].
#'
#' @param formula An lme4-bar formula of the form `0 + trait | id`.
#' @param pedigree,A,Ainv See [animal_scalar()].
#' @return See [animal_scalar()].
#' @seealso [animal_unique()], [phylo_indep()].
#' @export
animal_indep <- function(formula, pedigree = NULL, A = NULL, Ainv = NULL) {
  invisible(NULL)
}

#' Reduced-rank animal-model latent factors: `animal_latent(id, d = K)`
#'
#' Reduced-rank decomposition of the additive-genetic covariance
#' matrix using \eqn{K} latent factors:
#' \eqn{\boldsymbol G \approx \boldsymbol\Lambda \boldsymbol\Lambda^\top}
#' with \eqn{\boldsymbol\Lambda} a \eqn{T \times K} loadings matrix
#' (\eqn{T} = number of traits, \eqn{K \le T}). The latent factors
#' themselves carry the \eqn{\mathbf A} structure across individuals.
#'
#' This is the canonical "factor-analytic G-matrix" model from
#' quantitative genetics (Kirkpatrick & Meyer 2004; Meyer 2009; the
#' WOMBAT method). Mathematical parallel to [phylo_latent()] — same
#' engine path with a pedigree-derived relatedness matrix instead of
#' phylogenetic VCV.
#'
#' @inheritParams animal_scalar
#' @param d Number of latent factors (\eqn{K \le T}). Default 1.
#' @return See [animal_scalar()].
#' @seealso [animal_scalar()], [animal_unique()], [phylo_latent()].
#' @export
animal_latent <- function(id, d = 1, pedigree = NULL, A = NULL,
                          Ainv = NULL) {
  invisible(NULL)
}

#' Full unstructured animal-model trait covariance: `animal_dep(0 + trait | id)`
#'
#' Full-rank unstructured \eqn{T \times T} additive-genetic covariance
#' matrix \eqn{\boldsymbol G}, parameterised as the Cholesky factor
#' of a rank-\eqn{T} \eqn{\boldsymbol\Lambda} (i.e. the
#' [animal_latent()] case with \eqn{K = T}). Mathematical parallel to
#' [phylo_dep()].
#'
#' @param formula An lme4-bar formula of the form `0 + trait | id`.
#' @param pedigree,A,Ainv See [animal_scalar()].
#' @return See [animal_scalar()].
#' @seealso [animal_latent()], [phylo_dep()].
#' @export
animal_dep <- function(formula, pedigree = NULL, A = NULL, Ainv = NULL) {
  invisible(NULL)
}

#' Animal-model random slope on a continuous covariate
#'
#' Adds a per-individual random slope on a continuous covariate `x`,
#' with individual-level slopes correlated according to the additive-
#' genetic relatedness matrix \eqn{\mathbf A}. Mathematically:
#' \deqn{\eta_{io} \;\mathrel{{+}{=}}\; \beta_{\text{a}}(i)\, x_{io}, \qquad
#'       \boldsymbol\beta_{\text{a}} \sim \mathcal{N}\bigl(\mathbf 0,\,
#'       \sigma^2_{\text{slope}}\,\mathbf A\bigr).}
#'
#' This is the canonical **quantitative-genetic random-regression**
#' (reaction-norm) model — heritable variation in the slope on an
#' environmental gradient. Mathematical parallel to [phylo_slope()];
#' the engine recycles the same \eqn{\mathbf A^{-1}} prepared by
#' [animal_scalar()] / [animal_latent()].
#'
#' @param formula An lme4-bar formula of the form `x | id`.
#' @return See [animal_scalar()].
#' @seealso [animal_scalar()], [animal_latent()], [phylo_slope()].
#' @export
animal_slope <- function(formula) {
  invisible(NULL)
}

# ---- Internal helper: pedigree -> A via Henderson (1976) ----------

#' Pedigree to additive-genetic relatedness matrix `A`
#'
#' Computes the dense numerator-relationship matrix \eqn{\mathbf A}
#' from a 3-column pedigree (`id`, `sire`, `dam`) using Henderson's
#' (1976) recursive formula:
#'
#' \itemize{
#'   \item \eqn{A_{ii} = 1 + F_i}, where \eqn{F_i} is the inbreeding
#'     coefficient of individual \eqn{i}.
#'   \item \eqn{A_{ij} = \tfrac{1}{2}(A_{i,\text{sire}(j)} + A_{i,\text{dam}(j)})}
#'     for \eqn{j} younger than \eqn{i} (pedigree is sorted oldest
#'     first).
#' }
#'
#' Founder individuals (both parents unknown) are assumed unrelated
#' and non-inbred: \eqn{A_{founder, founder} = 1}.
#'
#' Users typically don't call `pedigree_to_A()` directly — pass
#' `pedigree = ped` to an [animal_scalar()] / [animal_unique()] /
#' [animal_latent()] / [animal_indep()] / [animal_dep()] keyword in
#' the formula, and the keyword's parser handles the conversion
#' internally. This function is exported as a public helper for users
#' who want the matrix for their own diagnostics (e.g. inspection of
#' inbreeding coefficients or pre-computation for repeated fits).
#'
#' For very large pedigrees (\eqn{n > 5000}) the cubic-time cost of
#' Henderson recursion becomes noticeable; a sparse-`Ainv` direct
#' engine path is a v0.3.0 follow-up. For comparison against
#' established implementations, see `nadiv::makeAinv()` (sparse
#' \eqn{\mathbf A^{-1}}).
#'
#' @param pedigree A data frame with one row per individual and
#'   columns identifying the individual, sire, and dam. **Column
#'   names are resolved BY NAME** (MCMCglmm-style) using these
#'   synonyms:
#'   \itemize{
#'     \item Individual ID column: `id` or `animal`.
#'     \item Sire (father) column: `sire` or `father`.
#'     \item Dam (mother) column: `dam` or `mother`.
#'   }
#'   If none of the named synonyms is present, the function falls
#'   back to **positional** access — column 1 = id, column 2 =
#'   sire, column 3 = dam — with a soft note. Unknown parents
#'   encoded as `NA` or `0` (both treated as missing).
#' @return Dense numeric matrix \eqn{n \times n} with `rownames` /
#'   `colnames` equal to the individual IDs.
#' @seealso [animal_scalar()] and siblings.
#' @export
pedigree_to_A <- function(pedigree) {
  if (!is.data.frame(pedigree) || ncol(pedigree) < 3L) {
    cli::cli_abort(c(
      "{.arg pedigree} must be a data frame with at least 3 columns.",
      "i" = "Expected columns: {.field id}/{.field animal}, {.field sire}/{.field father}, {.field dam}/{.field mother}.",
      "i" = "Got: {.code {paste(names(pedigree), collapse = ', ')}}."
    ))
  }
  ## MCMCglmm-style by-name column lookup with synonyms.
  nm <- names(pedigree)
  pick <- function(syn) {
    hit <- which(tolower(nm) %in% tolower(syn))
    if (length(hit) >= 1L) return(hit[1L]) else return(NA_integer_)
  }
  id_col   <- pick(c("id", "animal"))
  sire_col <- pick(c("sire", "father"))
  dam_col  <- pick(c("dam", "mother"))
  if (anyNA(c(id_col, sire_col, dam_col))) {
    ## Fall back to positional access with a soft note.
    cli::cli_inform(c(
      "i" = "{.fn pedigree_to_A}: column names not recognised; using positional access (col 1 = id, col 2 = sire, col 3 = dam).",
      ">" = "Rename columns to {.field id}/{.field sire}/{.field dam} (MCMCglmm convention) for explicit by-name lookup."
    ))
    id_col   <- 1L
    sire_col <- 2L
    dam_col  <- 3L
  }
  ids   <- as.character(pedigree[[id_col]])
  sires <- as.character(pedigree[[sire_col]])
  dams  <- as.character(pedigree[[dam_col]])
  ## Normalise missing-parent encodings: NA or "0" or "" -> NA.
  sires[sires %in% c("0", "")] <- NA_character_
  dams[dams %in% c("0", "")]   <- NA_character_

  n <- length(ids)
  if (anyDuplicated(ids))
    cli::cli_abort("{.arg pedigree$id} has duplicate IDs; each row must be a unique individual.")

  ## Sort pedigree so that every parent appears before its offspring.
  ## A simple topological-ish sort: founders first, then descendants.
  ## (Assumes the user-supplied order is already valid OR can be made
  ## valid by a single founder-first pass; complex pedigrees may need
  ## external pre-sorting via e.g. nadiv::prepPed().)
  parent_idx <- function(x) match(x, ids)
  s_idx <- parent_idx(sires)
  d_idx <- parent_idx(dams)
  ## Detect forward-references (parent appearing AFTER offspring in
  ## the table) and error with a clear remediation message.
  for (i in seq_len(n)) {
    if (!is.na(s_idx[i]) && s_idx[i] > i)
      cli::cli_abort(c(
        "Pedigree is not in topological order at row {i} (id {.val {ids[i]}}).",
        "i" = "Sire {.val {sires[i]}} appears at row {.val {s_idx[i]}}, after offspring.",
        ">" = "Pre-sort the pedigree (e.g. via {.fn nadiv::prepPed}) so parents always precede offspring."
      ))
    if (!is.na(d_idx[i]) && d_idx[i] > i)
      cli::cli_abort(c(
        "Pedigree is not in topological order at row {i} (id {.val {ids[i]}}).",
        "i" = "Dam {.val {dams[i]}} appears at row {.val {d_idx[i]}}, after offspring.",
        ">" = "Pre-sort the pedigree (e.g. via {.fn nadiv::prepPed}) so parents always precede offspring."
      ))
  }

  A <- matrix(0, nrow = n, ncol = n,
              dimnames = list(ids, ids))

  for (i in seq_len(n)) {
    si <- s_idx[i]
    di <- d_idx[i]
    ## Diagonal A_ii = 1 + F_i where F_i = A_{sire,dam}/2 if both
    ## parents known and (sire != dam); otherwise 0.
    F_i <- 0
    if (!is.na(si) && !is.na(di) && si != di) {
      F_i <- A[si, di] / 2
    }
    A[i, i] <- 1 + F_i

    ## Off-diagonal: A_{j,i} = 0.5 (A_{j,s} + A_{j,d}) for j < i.
    if (i > 1L) {
      js <- seq_len(i - 1L)
      a_js <- if (is.na(si)) 0 else A[js, si]
      a_jd <- if (is.na(di)) 0 else A[js, di]
      vals <- 0.5 * (a_js + a_jd)
      A[js, i] <- vals
      A[i, js] <- vals
    }
  }

  A
}
