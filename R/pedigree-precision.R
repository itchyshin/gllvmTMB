## Sparse pedigree precision (A^{-1}) built directly from a pedigree data frame
## -- no MCMCglmm dependency. Uses the standard Henderson (1976) / Quaas (1976)
## sparse inverse rules: for each individual i with Mendelian sampling variance
## d_i (a function of parental inbreeding), A^{-1} accumulates b_i = 1/d_i on the
## individual and +/-0.25/0.5 * b_i cross-terms with its parents. This gives the
## SAME sparse A^{-1} as MCMCglmm::inverseA(pedigree)$Ainv, with only `Matrix`.
## Replaces the MCMCglmm::inverseA call in pedigree_to_Ainv_sparse (this file's
## sibling R/animal-keyword.R).
##
## PROVENANCE: the pedigree standardisation, missing-parent normalisation,
## topological (ancestors-before-descendants) ordering, and the dense additive
## relationship (tabular) method used here for the inbreeding coefficients F are
## ported from drmTMB (R/phylo-utils.R: drm_standardize_pedigree,
## drm_normalize_pedigree_parent, drm_pedigree_topological_order,
## drm_pedigree_additive_relationship), the univariate sister package, which
## never depended on MCMCglmm. See inst/COPYRIGHTS. The sparse A^{-1} assembly on
## top of F is the standard Henderson/Quaas construction (also what MCMCglmm
## implements); gllvmTMB assembles it directly so the SPARSE engine path stays
## genuinely sparse.

#' @keywords internal
#' @noRd
.gllvm_normalize_pedigree_parent <- function(parent) {
  parent[is.na(parent) | !nzchar(parent) | parent == "0"] <- NA_character_
  parent
}

#' @keywords internal
#' @noRd
.gllvm_standardize_pedigree <- function(pedigree, object = "pedigree") {
  if (!is.data.frame(pedigree)) {
    cli::cli_abort(c(
      "{.fn animal} pedigree {.field {object}} must be a data frame.",
      "x" = "Use columns {.field id}, {.field dam}, and {.field sire}; unknown parents can be {.code NA}, {.val \"\"}, or {.val \"0\"}."
    ))
  }
  required <- c("id", "dam", "sire")
  missing <- setdiff(required, names(pedigree))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "{.fn animal} pedigree {.field {object}} must contain {.field id}, {.field dam}, and {.field sire} columns.",
      "x" = "Missing column{?s}: {.field {missing}}."
    ))
  }
  ped <- data.frame(
    id = as.character(pedigree$id),
    dam = as.character(pedigree$dam),
    sire = as.character(pedigree$sire),
    stringsAsFactors = FALSE
  )
  ped$dam <- .gllvm_normalize_pedigree_parent(ped$dam)
  ped$sire <- .gllvm_normalize_pedigree_parent(ped$sire)

  if (nrow(ped) < 2L) {
    cli::cli_abort(
      "{.fn animal} pedigree {.field {object}} must contain at least two individuals."
    )
  }
  if (anyNA(ped$id) || any(!nzchar(ped$id))) {
    cli::cli_abort(
      "{.fn animal} pedigree {.field {object}} {.field id} values must be non-missing labels."
    )
  }
  if (anyDuplicated(ped$id)) {
    duplicate <- ped$id[duplicated(ped$id)][[1L]]
    cli::cli_abort(c(
      "{.fn animal} pedigree {.field {object}} {.field id} values must be unique.",
      "x" = "Duplicated id: {.val {duplicate}}."
    ))
  }
  parents <- unique(stats::na.omit(c(ped$dam, ped$sire)))
  missing_parents <- setdiff(parents, ped$id)
  if (length(missing_parents) > 0L) {
    cli::cli_abort(c(
      "{.fn animal} pedigree {.field {object}} parents must appear in the {.field id} column.",
      "x" = "Missing parent id{?s}: {.val {missing_parents}}."
    ))
  }
  ped
}

#' @keywords internal
#' @noRd
.gllvm_pedigree_topological_order <- function(ped, object = "pedigree") {
  unresolved <- seq_len(nrow(ped))
  resolved_ids <- character()
  out <- integer()
  while (length(unresolved) > 0L) {
    ready <- unresolved[
      (is.na(ped$dam[unresolved]) | ped$dam[unresolved] %in% resolved_ids) &
        (is.na(ped$sire[unresolved]) | ped$sire[unresolved] %in% resolved_ids)
    ]
    if (length(ready) == 0L) {
      stuck <- ped$id[unresolved]
      cli::cli_abort(c(
        "{.fn animal} pedigree {.field {object}} must not contain parent-offspring cycles.",
        "x" = "Could not resolve individual{?s}: {.val {stuck}}."
      ))
    }
    out <- c(out, ready)
    resolved_ids <- c(resolved_ids, ped$id[ready])
    unresolved <- setdiff(unresolved, ready)
  }
  out
}

#' Dense additive relationship matrix (tabular method), ancestors-first ordered.
#' Only used here to extract inbreeding coefficients F = diag(A) - 1.
#' @keywords internal
#' @noRd
.gllvm_pedigree_additive_relationship <- function(ped, object = "pedigree") {
  n <- nrow(ped)
  A <- matrix(0, nrow = n, ncol = n)
  rownames(A) <- colnames(A) <- ped$id
  dam_index <- match(ped$dam, ped$id)
  sire_index <- match(ped$sire, ped$id)
  for (i in seq_len(n)) {
    parents <- c(dam_index[[i]], sire_index[[i]])
    parents <- parents[!is.na(parents)]
    if (length(parents) > 0L && any(parents >= i)) {
      cli::cli_abort(c(
        "{.fn animal} pedigree {.field {object}} could not be ordered from ancestors to descendants.",
        "x" = "Individual {.val {ped$id[[i]]}} has a parent that is not available before the offspring."
      ))
    }
    if (i > 1L) {
      for (j in seq_len(i - 1L)) {
        dam_relatedness <- if (is.na(dam_index[[i]])) 0 else A[dam_index[[i]], j]
        sire_relatedness <- if (is.na(sire_index[[i]])) 0 else A[sire_index[[i]], j]
        A[i, j] <- A[j, i] <- 0.5 * (dam_relatedness + sire_relatedness)
      }
    }
    A[i, i] <- if (is.na(dam_index[[i]]) || is.na(sire_index[[i]])) {
      1
    } else {
      1 + 0.5 * A[dam_index[[i]], sire_index[[i]]]
    }
  }
  A
}

#' Sparse pedigree precision A^{-1} (Henderson/Quaas), MCMCglmm-free.
#'
#' Standardises + topologically orders the pedigree, derives inbreeding
#' coefficients F from the dense additive relationship (tabular) matrix, then
#' assembles the sparse inverse A^{-1} directly via the Henderson/Quaas rules.
#' Returns the same matrix as \code{MCMCglmm::inverseA(pedigree)$Ainv} using only
#' \pkg{Matrix} (see Hadfield 2010; the algorithm is Henderson 1976 / Quaas 1976).
#'
#' @param pedigree Standardised pedigree data frame (columns `id`, `dam`, `sire`;
#'   unknown parents `NA`/`""`/`"0"`).
#' @param object Label used in error messages.
#' @return A symmetric sparse `dgCMatrix` `A^{-1}` with `id` dimnames.
#' @keywords internal
#' @noRd
.gllvm_pedigree_precision <- function(pedigree, object = "pedigree") {
  ped <- .gllvm_standardize_pedigree(pedigree, object = object)
  ord <- .gllvm_pedigree_topological_order(ped, object = object)
  ped <- ped[ord, , drop = FALSE]
  ids <- ped$id
  n <- length(ids)

  ## Inbreeding coefficients from the dense tabular A (ancestors-first).
  A <- .gllvm_pedigree_additive_relationship(ped, object = object)
  Finb <- diag(A) - 1

  sire <- match(ped$sire, ids)
  dam <- match(ped$dam, ids)

  ## Preallocate triplets: each individual contributes at most 9 entries.
  cap <- 9L * n
  ri <- integer(cap)
  ci <- integer(cap)
  vx <- numeric(cap)
  k <- 0L
  push <- function(r, c, v) {
    k <<- k + 1L
    ri[k] <<- r
    ci[k] <<- c
    vx[k] <<- v
  }
  for (i in seq_len(n)) {
    s <- sire[[i]]
    d <- dam[[i]]
    has_s <- !is.na(s)
    has_d <- !is.na(d)
    d_i <- if (has_s && has_d) {
      0.5 - 0.25 * (Finb[[s]] + Finb[[d]])
    } else if (has_s) {
      0.75 - 0.25 * Finb[[s]]
    } else if (has_d) {
      0.75 - 0.25 * Finb[[d]]
    } else {
      1
    }
    b <- 1 / d_i
    push(i, i, b)
    if (has_s) {
      push(i, s, -0.5 * b); push(s, i, -0.5 * b); push(s, s, 0.25 * b)
    }
    if (has_d) {
      push(i, d, -0.5 * b); push(d, i, -0.5 * b); push(d, d, 0.25 * b)
    }
    if (has_s && has_d) {
      push(s, d, 0.25 * b); push(d, s, 0.25 * b)
    }
  }

  ## sparseMatrix sums duplicated (i, j) entries -> the accumulated A^{-1}.
  Ainv <- Matrix::sparseMatrix(
    i = ri[seq_len(k)], j = ci[seq_len(k)], x = vx[seq_len(k)],
    dims = c(n, n), dimnames = list(ids, ids)
  )
  Matrix::drop0(Ainv)
}
