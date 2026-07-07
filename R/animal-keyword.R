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
##   animal_latent(id, d, unique, pedigree, A, Ainv)    phylo_latent
##   animal_dep(formula, pedigree, A, Ainv)             phylo_dep
##   animal_slope(formula)                              phylo_slope
##
## Argument convention: **A** / **Ainv** for relatedness covariance /
## precision. **V** is reserved for `meta_V()` (meta-analytic
## sampling variance; `meta_known_V()` is the deprecated alias) and
## **must not** be used for relatedness.

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
#' Mathematical parallel to [phylo_scalar()] -- same engine path; the
#' only difference is that **A** is supplied via `pedigree =` (a
#' 3-column data frame: id, sire, dam), `A =` (dense \eqn{n \times n}
#' relatedness matrix), or `Ainv =` (sparse precision; densified
#' internally for v0.2.0 -- sparse-Ainv direct engine path is a v0.3.0
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
#'   when called outside a formula -- the keyword is a syntactic marker
#'   that the parser rewrites internally to the canonical
#'   [phylo_scalar()] path (which is family-agnostic at the math level).
#'
#' @seealso [animal_unique()], [animal_indep()], [animal_latent()],
#'   [animal_dep()], [animal_slope()], [phylo_scalar()],
#'   [meta_V()] (sampling variance, distinct from relatedness).
#'
#' @examples
#' \dontrun{
#' # Pedigree-derived additive-genetic relatedness; single shared
#' # variance across traits. Grounded in test-animal-keyword.R (ANI-01).
#' ped <- data.frame(
#'   id   = paste0("i", 1:12),
#'   sire = c(rep(NA, 4), rep(c("i1", "i2"), length.out = 8)),
#'   dam  = c(rep(NA, 4), rep(c("i3", "i4"), length.out = 8))
#' )
#' A <- pedigree_to_A(ped)
#' yvec <- as.numeric(MASS::mvrnorm(
#'   1, mu = rep(0, 2 * 12),
#'   Sigma = kronecker(diag(2), A) * 0.5 + diag(2 * 12) * 0.5
#' ))
#' df <- data.frame(
#'   species = factor(rep(ped$id, each = 2), levels = ped$id),
#'   trait   = factor(rep(c("t1", "t2"), times = 12), levels = c("t1", "t2")),
#'   value   = yvec
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + animal_scalar(species, pedigree = ped),
#'   data = df, family = gaussian()
#' )
#' }
#'
#' @export
animal_scalar <- function(id, pedigree = NULL, A = NULL, Ainv = NULL) {
  invisible(NULL)
}

#' Per-trait independent animal-model random intercepts: `animal_unique(id)`
#'
#' `r lifecycle::badge("deprecated")`
#'
#' `animal_unique()` is soft-deprecated as compatibility syntax in gllvmTMB
#' 0.2.0. Use [animal_indep()] for standalone marginal diagonal animal-model
#' terms. Paired explicit-Psi use remains accepted; use
#' `animal_latent(..., unique = TRUE)` when the folded latent term itself
#' should carry this diagonal companion.
#'
#' Canonical name for the **D independent** animal-model random
#' intercept on a shared relatedness matrix \eqn{\mathbf A}. Each
#' trait gets its own variance \eqn{\sigma^{2}_{\text{a},t}}; traits
#' share the same per-individual draws (rows of A act on each trait
#' independently). Mathematical parallel to [phylo_unique()].
#'
#' @section Correlated intercept + slope reaction norm:
#' Used with an intercept+slope bar,
#' `animal_unique(1 + x | id, pedigree = ped)` fits a **correlated**
#' additive-genetic random-regression (reaction norm)
#' \eqn{\mathrm{vec}(\mathbf B) \sim N(0, \Sigma_b \otimes \mathbf A)},
#' where \eqn{\Sigma_b} is a \eqn{2 \times 2} (intercept, slope)
#' covariance with a **free** intercept-slope correlation. This routes
#' through the same augmented engine as [phylo_unique()] with a
#' `1 + x | sp` bar; no separate likelihood. For the diagonal
#' (\eqn{\rho = 0}) special case use [animal_indep()] with the same
#' `1 + x | id` bar. Recover \eqn{\Sigma_b} with
#' `extract_Sigma(fit, level = "phy")`.
#'
#' @inheritParams animal_scalar
#' @return See [animal_scalar()].
#' @seealso [animal_scalar()], [animal_indep()], [animal_latent()],
#'   [animal_dep()], [phylo_unique()].
#' @examples
#' \dontrun{
#' # Per-trait independent additive-genetic variances on a shared A.
#' # Grounded in test-animal-keyword.R (ANI-02).
#' ped <- data.frame(
#'   id   = paste0("i", 1:12),
#'   sire = c(rep(NA, 4), rep(c("i1", "i2"), length.out = 8)),
#'   dam  = c(rep(NA, 4), rep(c("i3", "i4"), length.out = 8))
#' )
#' A <- pedigree_to_A(ped)
#' yvec <- as.numeric(MASS::mvrnorm(
#'   1, mu = rep(0, 2 * 12),
#'   Sigma = kronecker(diag(2), A) * 0.5 + diag(2 * 12) * 0.5
#' ))
#' df <- data.frame(
#'   species = factor(rep(ped$id, each = 2), levels = ped$id),
#'   trait   = factor(rep(c("t1", "t2"), times = 12), levels = c("t1", "t2")),
#'   value   = yvec
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + animal_unique(species, pedigree = ped),
#'   data = df, family = gaussian()
#' )
#' }
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
#' @examples
#' \dontrun{
#' # Independent per-trait animal-model intercepts via the bar form,
#' # passing the dense relatedness matrix A directly.
#' # Grounded in test-animal-keyword.R (ANI-03).
#' ped <- data.frame(
#'   id   = paste0("i", 1:12),
#'   sire = c(rep(NA, 4), rep(c("i1", "i2"), length.out = 8)),
#'   dam  = c(rep(NA, 4), rep(c("i3", "i4"), length.out = 8))
#' )
#' A <- pedigree_to_A(ped)
#' yvec <- as.numeric(MASS::mvrnorm(
#'   1, mu = rep(0, 2 * 12),
#'   Sigma = kronecker(diag(2), A) * 0.5 + diag(2 * 12) * 0.5
#' ))
#' df <- data.frame(
#'   species = factor(rep(ped$id, each = 2), levels = ped$id),
#'   trait   = factor(rep(c("t1", "t2"), times = 12), levels = c("t1", "t2")),
#'   value   = yvec
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + animal_indep(0 + trait | species, A = A),
#'   data = df, family = gaussian()
#' )
#' }
#' @export
animal_indep <- function(formula, pedigree = NULL, A = NULL, Ainv = NULL) {
  invisible(NULL)
}

#' Reduced-rank animal-model latent factors: `animal_latent(id, d = K)`
#'
#' Reduced-rank decomposition of the additive-genetic covariance
#' matrix using \eqn{K} latent factors. Set `unique = TRUE` to add a
#' per-trait diagonal \eqn{\boldsymbol\Psi} companion:
#' \eqn{\boldsymbol G =
#' \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi}
#' with \eqn{\boldsymbol\Lambda} a \eqn{T \times K} loadings matrix
#' (\eqn{T} = number of traits, \eqn{K \le T}). The latent factors
#' and diagonal companion both carry the same \eqn{\mathbf A} structure
#' across individuals.
#'
#' This is the canonical "factor-analytic G-matrix" model from
#' quantitative genetics (Kirkpatrick & Meyer 2004; Meyer 2009; the
#' WOMBAT method). Mathematical parallel to [phylo_latent()] -- same
#' engine path with a pedigree-derived relatedness matrix instead of
#' phylogenetic VCV.
#'
#' @inheritParams animal_scalar
#' @param d Number of latent factors (\eqn{K \le T}). Default 1.
#' @param unique Logical; when `TRUE`, include the per-trait diagonal
#'   additive-genetic \eqn{\boldsymbol\Psi} companion. The default `FALSE`
#'   preserves the loadings-only subset.
#' @return See [animal_scalar()].
#' @seealso [animal_scalar()], [animal_unique()], [phylo_latent()].
#' @examples
#' \dontrun{
#' # Factor-analytic G-matrix (d latent factors plus diagonal Psi).
#' # Grounded in test-animal-keyword.R (ANI-05).
#' ped <- data.frame(
#'   id   = paste0("i", 1:12),
#'   sire = c(rep(NA, 4), rep(c("i1", "i2"), length.out = 8)),
#'   dam  = c(rep(NA, 4), rep(c("i3", "i4"), length.out = 8))
#' )
#' A <- pedigree_to_A(ped)
#' yvec <- as.numeric(MASS::mvrnorm(
#'   1, mu = rep(0, 2 * 12),
#'   Sigma = kronecker(diag(2), A) * 0.5 + diag(2 * 12) * 0.5
#' ))
#' df <- data.frame(
#'   species = factor(rep(ped$id, each = 2), levels = ped$id),
#'   trait   = factor(rep(c("t1", "t2"), times = 12), levels = c("t1", "t2")),
#'   value   = yvec
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + animal_latent(species, d = 1, pedigree = ped,
#'                                    unique = TRUE),
#'   data = df, family = gaussian()
#' )
#' }
#' @export
animal_latent <- function(
  id,
  d = 1,
  pedigree = NULL,
  A = NULL,
  Ainv = NULL,
  unique = FALSE
) {
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
#' @examples
#' \dontrun{
#' # Full unstructured additive-genetic trait covariance (rank = n_traits).
#' # Grounded in test-animal-keyword.R (ANI-04).
#' ped <- data.frame(
#'   id   = paste0("i", 1:12),
#'   sire = c(rep(NA, 4), rep(c("i1", "i2"), length.out = 8)),
#'   dam  = c(rep(NA, 4), rep(c("i3", "i4"), length.out = 8))
#' )
#' A <- pedigree_to_A(ped)
#' yvec <- as.numeric(MASS::mvrnorm(
#'   1, mu = rep(0, 2 * 12),
#'   Sigma = kronecker(diag(2), A) * 0.5 + diag(2 * 12) * 0.5
#' ))
#' df <- data.frame(
#'   species = factor(rep(ped$id, each = 2), levels = ped$id),
#'   trait   = factor(rep(c("t1", "t2"), times = 12), levels = c("t1", "t2")),
#'   value   = yvec
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + animal_dep(0 + trait | species, A = A),
#'   data = df, family = gaussian()
#' )
#' }
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
#' (reaction-norm) model -- heritable variation in the slope on an
#' environmental gradient. Mathematical parallel to [phylo_slope()];
#' the engine recycles the same \eqn{\mathbf A^{-1}} prepared by
#' [animal_scalar()] / [animal_latent()].
#'
#' @param formula An lme4-bar formula of the form `x | id`.
#' @return See [animal_scalar()].
#' @seealso [animal_scalar()], [animal_latent()], [phylo_slope()].
#' @examples
#' \dontrun{
#' # Additive-genetic random regression: one heritable slope variance on a
#' # continuous covariate x, slopes correlated by the relatedness matrix A.
#' # Grounded in test-animal-slope-recovery.R (ANI-06).
#' ped <- data.frame(
#'   id   = paste0("i", 1:12),
#'   sire = c(rep(NA, 4), rep(c("i1", "i2"), length.out = 8)),
#'   dam  = c(rep(NA, 4), rep(c("i3", "i4"), length.out = 8))
#' )
#' A <- pedigree_to_A(ped)
#' df <- expand.grid(
#'   species = factor(rownames(A), levels = rownames(A)),
#'   trait   = factor(c("t1", "t2", "t3")),
#'   rep     = 1:5
#' )
#' df$x <- rnorm(nrow(df))
#' df$value <- rnorm(nrow(df))
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + animal_slope(x | species, A = A),
#'   data = df, unit = "species", cluster = "species"
#' )
#' }
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
#' Users typically don't call `pedigree_to_A()` directly -- pass
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
#'   back to **positional** access -- column 1 = id, column 2 =
#'   sire, column 3 = dam -- with a soft note. Unknown parents
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
  id_col <- pick(c("id", "animal"))
  sire_col <- pick(c("sire", "father"))
  dam_col <- pick(c("dam", "mother"))
  if (anyNA(c(id_col, sire_col, dam_col))) {
    ## Fall back to positional access with a soft note.
    cli::cli_inform(c(
      "i" = "{.fn pedigree_to_A}: column names not recognised; using positional access (col 1 = id, col 2 = sire, col 3 = dam).",
      ">" = "Rename columns to {.field id}/{.field sire}/{.field dam} (MCMCglmm convention) for explicit by-name lookup."
    ))
    id_col <- 1L
    sire_col <- 2L
    dam_col <- 3L
  }
  ids <- as.character(pedigree[[id_col]])
  sires <- as.character(pedigree[[sire_col]])
  dams <- as.character(pedigree[[dam_col]])
  ## Normalise missing-parent encodings: NA or "0" or "" -> NA.
  sires[sires %in% c("0", "")] <- NA_character_
  dams[dams %in% c("0", "")] <- NA_character_

  n <- length(ids)
  if (anyDuplicated(ids)) {
    cli::cli_abort(
      "{.arg pedigree$id} has duplicate IDs; each row must be a unique individual."
    )
  }

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
    if (!is.na(s_idx[i]) && s_idx[i] > i) {
      cli::cli_abort(c(
        "Pedigree is not in topological order at row {i} (id {.val {ids[i]}}).",
        "i" = "Sire {.val {sires[i]}} appears at row {.val {s_idx[i]}}, after offspring.",
        ">" = "Pre-sort the pedigree (e.g. via {.fn nadiv::prepPed}) so parents always precede offspring."
      ))
    }
    if (!is.na(d_idx[i]) && d_idx[i] > i) {
      cli::cli_abort(c(
        "Pedigree is not in topological order at row {i} (id {.val {ids[i]}}).",
        "i" = "Dam {.val {dams[i]}} appears at row {.val {d_idx[i]}}, after offspring.",
        ">" = "Pre-sort the pedigree (e.g. via {.fn nadiv::prepPed}) so parents always precede offspring."
      ))
    }
  }

  ## Parents that are referenced but absent from the id column are treated
  ## as unrelated founders; warn rather than doing so silently (a missing
  ## parent row is often a typo or an incomplete pedigree).
  missing_sire <- !is.na(sires) & is.na(s_idx)
  missing_dam <- !is.na(dams) & is.na(d_idx)
  if (any(missing_sire) || any(missing_dam)) {
    bad <- unique(c(sires[missing_sire], dams[missing_dam]))
    cli::cli_warn(c(
      "Some parents are referenced but absent from the {.field id} column; treating them as unrelated founders.",
      "i" = "Missing parent id{?s}: {.val {bad}}.",
      ">" = "Add a row for each such parent (with its own parents or {.code NA}) if it is a known individual."
    ))
  }

  A <- matrix(0, nrow = n, ncol = n, dimnames = list(ids, ids))

  for (i in seq_len(n)) {
    si <- s_idx[i]
    di <- d_idx[i]
    ## Diagonal A_ii = 1 + F_i where F_i = A_{sire,dam}/2 if both
    ## parents are known. This includes selfing (sire == dam), where
    ## F_i = A_{p,p}/2; unknown-parent individuals get F_i = 0.
    F_i <- 0
    if (!is.na(si) && !is.na(di)) {
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


#' Sparse pedigree inverse-A via Henderson-Quaas (MCMCglmm-free)
#'
#' Builds the sparse precision matrix \eqn{\mathbf A^{-1}} for an animal-
#' model pedigree using only \pkg{Matrix} -- **no `MCMCglmm` dependency**.
#' The returned \eqn{\mathbf A^{-1}} is genuinely sparse (typical density
#' \eqn{O(1/n)}), so the TMB fit is \eqn{O(n)} rather than \eqn{O(n^3)} --
#' this is the canonical fast path for wild pedigrees with
#' \eqn{n_{\text{individuals}} > 500}. The construction is the standard
#' Henderson (1976) / Quaas (1976) sparse inverse: inbreeding coefficients
#' \eqn{F} are derived from the dense tabular relatedness matrix, then
#' \eqn{\mathbf A^{-1}} is assembled directly from the per-individual
#' Mendelian sampling variances. It reproduces
#' `MCMCglmm::inverseA(pedigree)$Ainv` exactly. (The current inbreeding
#' step forms the dense \eqn{n \times n} \eqn{\mathbf A}, an \eqn{O(n^2)}
#' one-time cost; a Meuwissen-Luo \eqn{O(n)} inbreeding recursion is a
#' future optimisation for very large pedigrees.)
#'
#' Usage pattern (sparse pre-CRAN; auto-routing follow-on PR):
#'
#' ```r
#' Ainv <- pedigree_to_Ainv_sparse(ped)
#' fit  <- gllvmTMB(value ~ 0 + trait +
#'                    animal_scalar(id, Ainv = Ainv),
#'                  data = df, unit = "id", cluster = "id")
#' ```
#'
#' The pedigree follows the conventional **(id, sire, dam)** column
#' order, OR named columns matching `id`/`animal`, `sire`/`father`,
#' `dam`/`mother` for by-name lookup. Unknown parents are encoded as
#' `NA` or `0`. Founders (both parents unknown) are treated as unrelated.
#'
#' @param pedigree A 3-column data frame: `id` (or `animal`),
#'   `sire` (or `father`), `dam` (or `mother`).
#' @return A sparse `dgCMatrix` of dimension `n_individuals` x
#'   `n_individuals` with rownames and colnames equal to the
#'   individual IDs. Sparse storage; typical density is
#'   \eqn{O(1/n)}.
#' @seealso [pedigree_to_A()] for the dense companion;
#'   [animal_scalar()] and siblings for the keyword family.
#' @references
#' Henderson, C. R. (1976). A simple method for computing the inverse
#' of a numerator relationship matrix used in prediction of breeding
#' values. *Biometrics* 32: 69-83.
#'
#' Quaas, R. L. (1976). Computing the diagonal elements and inverse of a
#' large numerator relationship matrix. *Biometrics* 32: 949-953.
#'
#' Hadfield, J. D. (2010). MCMC methods for multi-response generalised
#' linear mixed models: the MCMCglmm R package. *Journal of Statistical
#' Software* 33: 1-22. (The `MCMCglmm::inverseA()` reference
#' implementation this builder is validated against.)
#' @export
#' @examples
#' \dontrun{
#' ped <- data.frame(
#'   id   = paste0("i", 1:6),
#'   sire = c(NA, NA, "i1", "i1", "i3", "i3"),
#'   dam  = c(NA, NA, "i2", "i2", "i4", "i4")
#' )
#' Ainv <- pedigree_to_Ainv_sparse(ped)
#' class(Ainv)  # "dgCMatrix"
#' dim(Ainv)    # 6 x 6
#' }
pedigree_to_Ainv_sparse <- function(pedigree) {
  if (!is.data.frame(pedigree) || ncol(pedigree) < 3L) {
    cli::cli_abort(c(
      "{.arg pedigree} must be a data frame with at least 3 columns.",
      "i" = "Expected columns: {.field id}/{.field animal}, {.field sire}/{.field father}, {.field dam}/{.field mother}.",
      "i" = "Got: {.code {paste(names(pedigree), collapse = ', ')}}."
    ))
  }
  ## MCMCglmm-style by-name lookup (same convention as pedigree_to_A).
  ## Falls back to positional access if names are unrecognised.
  nm <- names(pedigree)
  pick <- function(syn) {
    hit <- which(tolower(nm) %in% tolower(syn))
    if (length(hit) >= 1L) hit[1L] else NA_integer_
  }
  id_col <- pick(c("id", "animal"))
  sire_col <- pick(c("sire", "father"))
  dam_col <- pick(c("dam", "mother"))
  if (anyNA(c(id_col, sire_col, dam_col))) {
    cli::cli_inform(c(
      "i" = "{.fn pedigree_to_Ainv_sparse}: column names not recognised; using positional access (col 1 = id, col 2 = sire, col 3 = dam).",
      ">" = "Rename columns to {.field id}/{.field sire}/{.field dam} (MCMCglmm convention) for explicit by-name lookup."
    ))
    id_col <- 1L
    sire_col <- 2L
    dam_col <- 3L
  }
  ## Build standardised data frame in MCMCglmm's (animal, sire, dam) order.
  ped_std <- data.frame(
    animal = as.character(pedigree[[id_col]]),
    sire = as.character(pedigree[[sire_col]]),
    dam = as.character(pedigree[[dam_col]]),
    stringsAsFactors = FALSE
  )
  ## Normalise missing-parent encodings.
  ped_std$sire[ped_std$sire %in% c("0", "")] <- NA_character_
  ped_std$dam[ped_std$dam %in% c("0", "")] <- NA_character_

  ## MCMCglmm-free sparse A^{-1} (Henderson/Quaas). Returns a dgCMatrix with
  ## id row/colnames so the fit-multi.R sparse engine's `Ainv[levs, levs]`
  ## by-name subset works. See R/pedigree-precision.R.
  .gllvm_pedigree_precision(data.frame(
    id = ped_std$animal, dam = ped_std$dam, sire = ped_std$sire,
    stringsAsFactors = FALSE
  ))
}


## Internal helper for the brms-sugar `Ainv =` resolver
## (Design 47 follow-on, 2026-05-18). Sparse Ainv input is passed
## through unchanged so the sparse-Ainv engine path in
## `R/fit-multi.R` picks it up; dense Ainv input is inverted to
## dense A for the legacy dense path (preserves backward
## compatibility with the M2.8b `Ainv =` API).
#' @keywords internal
#' @noRd
.gllvmTMB_maybe_keep_sparse_ainv <- function(x) {
  if (inherits(x, "sparseMatrix")) x else solve(as.matrix(x))
}
