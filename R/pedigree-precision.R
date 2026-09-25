## Sparse pedigree precision (A^{-1}) built directly from a pedigree data frame
## -- no MCMCglmm dependency. Uses the standard Henderson (1976) / Quaas (1976)
## sparse inverse rules: for each individual i with Mendelian sampling variance
## d_i (a function of parental inbreeding), A^{-1} accumulates b_i = 1/d_i on the
## individual and +/-0.25/0.5 * b_i cross-terms with its parents. This gives the
## SAME sparse A^{-1} as MCMCglmm::inverseA(pedigree)$Ainv, with only `Matrix`.
## Replaces the MCMCglmm::inverseA call in pedigree_to_Ainv_sparse (this file's
## sibling R/animal-keyword.R).
##
## Fit-path inbreeding F is Meuwissen & Luo (1992): O(n * ancestors), no dense A.
## The dense tabular A (`.gllvm_pedigree_additive_relationship`) remains the
## oracle / export path only.
##
## PROVENANCE: pedigree standardisation, missing-parent normalisation,
## topological ordering, and the dense tabular relatedness oracle were ported
## from drmTMB (R/phylo-utils.R helpers) before #1322; both packages are GPL-3
## by Shinichi Nakagawa. Meuwissen-Luo F follows HSquared.jl
## `_meuwissen_luo_inbreeding` (MIT; src/pedigree.jl at
## eee5f7aa7640abafa6b2efd2b71a66182db77459) -- reimplemented in R; Julia source
## is not vendored; drmTMB #1424 is the twin, not a GPL source drop. Quaas
## assembly remains the existing gllvmTMB Henderson/Quaas loop. See
## inst/COPYRIGHTS.

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
#' Oracle / dense export only -- not on the fit-path for sparse A^{-1}.
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
        "x" = "Individual {.val {ped$id[[i]]}} has a parent that is not available before the offspring.",
        ">" = "Supply rows ordered ancestors-before-descendants so every parent appears before its offspring."
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

#' Meuwissen & Luo (1992) inbreeding for a topologically ordered pedigree.
#'
#' Accumulates the T-row of A = T D T' over ancestors, youngest first via a
#' max-heap on row indices: A_ii = sum_j L_ij^2 d_j, so F_i = A_ii - 1, with
#' d_j = 0.5 - 0.25 (F_sire(j) + F_dam(j)) and unknown-parent F_0 = -1.
#' One unknown parent => F_i = 0. Requires parents-before-offspring order.
#'
#' Walk follows HSquared.jl `_meuwissen_luo_inbreeding` (MIT pin in file header).
#' Reimplemented in R; Julia source is not vendored.
#'
#' @keywords internal
#' @noRd
.gllvm_pedigree_inbreeding_meuwissen_luo <- function(ped, object = "pedigree") {
  n <- nrow(ped)
  ids <- ped$id
  sire <- match(ped$sire, ids)
  dam <- match(ped$dam, ids)
  sire[is.na(sire)] <- 0L
  dam[is.na(dam)] <- 0L
  storage.mode(sire) <- "integer"
  storage.mode(dam) <- "integer"

  for (i in seq_len(n)) {
    s <- sire[[i]]
    d <- dam[[i]]
    if ((s != 0L && s >= i) || (d != 0L && d >= i)) {
      cli::cli_abort(c(
        "{.fn animal} pedigree {.field {object}} could not be ordered from ancestors to descendants.",
        "x" = "Individual {.val {ids[[i]]}} has a parent that is not available before the offspring.",
        ">" = "Supply rows ordered ancestors-before-descendants so every parent appears before its offspring."
      ))
    }
  }

  F <- numeric(n)
  L <- numeric(n)
  heap <- integer(64L)
  heap_n <- 0L

  heappush <- function(x) {
    heap_n <<- heap_n + 1L
    if (heap_n > length(heap)) {
      heap <<- c(heap, integer(length(heap)))
    }
    heap[[heap_n]] <<- x
    hi <- heap_n
    while (hi > 1L) {
      p <- hi %/% 2L
      if (heap[[p]] >= heap[[hi]]) {
        break
      }
      tmp <- heap[[p]]
      heap[[p]] <<- heap[[hi]]
      heap[[hi]] <<- tmp
      hi <- p
    }
  }

  heappop_max <- function() {
    top <- heap[[1L]]
    last <- heap[[heap_n]]
    heap_n <<- heap_n - 1L
    if (heap_n >= 1L) {
      heap[[1L]] <<- last
      hi <- 1L
      repeat {
        left <- 2L * hi
        right <- left + 1L
        m <- hi
        if (left <= heap_n && heap[[left]] > heap[[m]]) {
          m <- left
        }
        if (right <= heap_n && heap[[right]] > heap[[m]]) {
          m <- right
        }
        if (m == hi) {
          break
        }
        tmp <- heap[[hi]]
        heap[[hi]] <<- heap[[m]]
        heap[[m]] <<- tmp
        hi <- m
      }
    }
    top
  }

  for (i in seq_len(n)) {
    s <- sire[[i]]
    d <- dam[[i]]
    if (s == 0L || d == 0L) {
      F[[i]] <- 0
      next
    }
    L[[i]] <- 1
    heappush(i)
    fi <- 0
    while (heap_n > 0L) {
      j <- heappop_max()
      lj <- L[[j]]
      L[[j]] <- 0
      sj <- sire[[j]]
      fj_s <- if (sj == 0L) -1 else F[[sj]]
      dmj <- dam[[j]]
      fj_d <- if (dmj == 0L) -1 else F[[dmj]]
      fi <- fi + lj * lj * (0.5 - 0.25 * (fj_s + fj_d))
      if (sj != 0L) {
        if (L[[sj]] == 0) {
          heappush(sj)
        }
        L[[sj]] <- L[[sj]] + 0.5 * lj
      }
      if (dmj != 0L) {
        if (L[[dmj]] == 0) {
          heappush(dmj)
        }
        L[[dmj]] <- L[[dmj]] + 0.5 * lj
      }
    }
    F[[i]] <- fi - 1
  }
  F
}

#' Henderson/Quaas sparse A^{-1} from a topologically ordered pedigree and F.
#' @keywords internal
#' @noRd
.gllvm_pedigree_quaas_ainv <- function(ped, Finb, object = "pedigree") {
  ids <- ped$id
  n <- length(ids)
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

#' Sparse pedigree precision A^{-1} (Henderson/Quaas), MCMCglmm-free.
#'
#' Standardises + topologically orders the pedigree, derives inbreeding
#' coefficients F by Meuwissen & Luo (1992), then assembles the sparse inverse
#' A^{-1} via the Henderson/Quaas rules. Returns the same matrix as
#' \code{MCMCglmm::inverseA(pedigree)$Ainv} using only \pkg{Matrix}.
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
  Finb <- .gllvm_pedigree_inbreeding_meuwissen_luo(ped, object = object)
  .gllvm_pedigree_quaas_ainv(ped, Finb, object = object)
}

#' Dense-F oracle: diag(A)-1 then the same Quaas assembly (tests / identity).
#' @keywords internal
#' @noRd
.gllvm_pedigree_precision_dense_F <- function(pedigree, object = "pedigree") {
  ped <- .gllvm_standardize_pedigree(pedigree, object = object)
  ord <- .gllvm_pedigree_topological_order(ped, object = object)
  ped <- ped[ord, , drop = FALSE]
  A <- .gllvm_pedigree_additive_relationship(ped, object = object)
  .gllvm_pedigree_quaas_ainv(ped, diag(A) - 1, object = object)
}
