## Galamm-style confirmatory loadings via the existing TMB packed-vector
## parameterisation.
##
## In the engine, theta_rr_B is packed as
##    theta_rr_B[0:rank-1]              = lam_diag (diagonal entries)
##    theta_rr_B[rank : rank + nl - 1]  = lam_lower (strict lower triangle,
##                                                   filled column-wise)
## with `nl = rank * n_traits - rank * (rank + 1) / 2` lower-triangle
## entries. The C++ kernel writes the upper triangle as zero, reads the
## diagonal first, and then reads the strict lower triangle column-by-column.
##
## To "pin" a Lambda entry to a user-specified value v, we set the
## corresponding theta_rr_B entry to v and mark it via a TMB `map` so
## the optimiser leaves it alone. Upper-triangle zeros are already
## satisfied (those entries are zero by construction) and are skipped.
## A non-zero upper-triangle pin cannot be placed in the packed
## theta and is an error (#1418). All other entries remain free, so
## the rest of the lower-triangular Cholesky structure is preserved.
##
## This covers the galamm-style "fix the leading loading of each factor
## to 1" pattern (`lambda_constraint = list(B = diag(1, n_traits, d))`)
## and the "freeze a particular trait at zero on a particular factor"
## pattern (which sets an off-diagonal lower-triangle entry to 0).
## Patterns that require non-zero entries in the upper triangle (free
## confirmatory factor analysis with reflective indicators) are NOT
## supported by this lightweight path; a future stage may add a full
## PARAMETER_MATRIX(Lambda) entry point for that case.

#' Translate a (i, j) Lambda position into the packed-theta index
#' @keywords internal
#' @noRd
lambda_packed_index <- function(i, j, p, rank) {
  if (j > i) return(NA_integer_)
  if (i == j) return(j + 1L)         # 1-based for R
  cursor <- rank + 1L                # first strict-lower coordinate in R
  for (column in 0:(rank - 1L)) {
    if (column >= p - 1L) next
    for (row in seq.int(column + 1L, p - 1L)) {
      if (row == i && column == j) return(cursor)
      cursor <- cursor + 1L
    }
  }
  cli::cli_abort("Internal loading coordinate is outside the packed triangle.")
}

#' Build a TMB map + init pair from a Lambda constraint matrix
#'
#' @param constraint An `n_traits × rank` matrix; `NA` = free, numeric
#'   = pin to that value. Upper-triangle zeros are skipped (already
#'   structural zeros). A non-zero upper-triangle pin is an error.
#' @param n_traits Number of trait rows of Lambda.
#' @param rank Number of factors (columns of Lambda).
#' @param theta_init Current init vector for the packed theta.
#' @return A list with `map` (a factor — `NA` at fixed entries) and
#'   `init` (the modified init vector with fixed entries set to the
#'   user values).
#' @keywords internal
#' @noRd
## Cross-block strictly-lower `theta_dep_chol` indices for a BLOCK-DIAGONAL
## augmented covariance (per-trait indep slope). The dep Cholesky packs L
## (C x C lower-triangular) as: the C diagonal entries first, then the
## strictly-lower entries in column-major order (src/gllvmTMB.cpp:1224-1237).
## The 2T augmented columns are grouped by trait in runs of
## `block_size = 1 + n_slopes`, so pinning the cross-block strictly-lower
## entries to 0 makes L block-lower-triangular and Sigma_b = L L^T
## block-diagonal -- T independent (intercept, slope) blocks, i.e. T stacked
## univariate random regressions (Design 79/80). Returns the 1-based indices
## into `theta_dep_chol` to pin (map off + init 0).
dep_chol_crossblock_pins <- function(C, block_size) {
  blk <- (seq_len(C) - 1L) %/% block_size
  pins <- integer(0)
  idx <- C                              # diagonal entries occupy indices 1..C
  for (j in seq_len(C)) {
    if (j < C) {
      for (i in (j + 1L):C) {
        idx <- idx + 1L                 # theta index of L(i, j), column-major
        if (blk[i] != blk[j]) pins <- c(pins, idx)
      }
    }
  }
  pins
}

## Strictly-lower `theta_dep_chol` indices for the `dep(1 + x || g)` UNCORRELATED
## coupling: Sigma_b = Sigma_int (T x T) (+) Sigma_slope (T x T) -- full cross-trait
## covariance among intercepts and (separately) among slopes, but intercept _|_
## slope everywhere. With the single-slope interleaved 2T ordering
## (int_1, slope_1, int_2, slope_2, ...), intercepts occupy the ODD positions and
## slopes the EVEN positions. Sigma_b[i, j] = 0 exactly when i and j have
## DIFFERENT parity, which holds iff L is parity-structured: pin every
## strictly-lower L(i, j) with parity(i) != parity(j). Diagonal entries (same
## position, always same parity) are never pinned. Free-param count is
## T(T + 1) = two T x T Cholesky blocks. Same column-major packing as
## dep_chol_crossblock_pins(). Single-slope only (block_size = 2). Design 79 §4.
dep_chol_parity_pins <- function(C) {
  pins <- integer(0)
  idx <- C                              # diagonal entries occupy indices 1..C
  for (j in seq_len(C)) {
    if (j < C) {
      for (i in (j + 1L):C) {
        idx <- idx + 1L                 # theta index of L(i, j), column-major
        if ((i %% 2L) != (j %% 2L)) pins <- c(pins, idx)
      }
    }
  }
  pins
}

lambda_packed_map <- function(constraint, n_traits, rank, theta_init) {
  if (!is.matrix(constraint))
    cli::cli_abort("lambda_constraint entries must be matrices.")
  if (nrow(constraint) != n_traits || ncol(constraint) != rank)
    cli::cli_abort(c(
      "lambda_constraint matrix has wrong dimensions.",
      "i" = "expected {n_traits}x{rank}, got {nrow(constraint)}x{ncol(constraint)}."
    ))
  map <- seq_along(theta_init)
  init <- theta_init
  unsupported_i <- integer(0)
  unsupported_j <- integer(0)
  unsupported_v <- numeric(0)
  for (i in seq_len(n_traits)) {
    for (j in seq_len(rank)) {
      v <- constraint[i, j]
      if (is.na(v)) next
      if (j > i) {
        ## Structural zero: a requested 0 is already satisfied.
        ## Any other pin has no packed-theta slot (#1418).
        if (!isTRUE(all.equal(as.numeric(v), 0))) {
          unsupported_i <- c(unsupported_i, i)
          unsupported_j <- c(unsupported_j, j)
          unsupported_v <- c(unsupported_v, as.numeric(v))
        }
        next
      }
      idx <- lambda_packed_index(i - 1L, j - 1L, n_traits, rank)
      if (!is.na(idx)) {
        map[idx]  <- NA
        init[idx] <- v
      }
    }
  }
  if (length(unsupported_i) > 0L) {
    rn <- rownames(constraint)
    row_lab <- if (!is.null(rn) && nzchar(rn[unsupported_i[1]])) {
      rn[unsupported_i[1]]
    } else {
      as.character(unsupported_i[1])
    }
    cn <- colnames(constraint)
    col_lab <- if (!is.null(cn) && nzchar(cn[unsupported_j[1]])) {
      cn[unsupported_j[1]]
    } else {
      paste0("axis ", unsupported_j[1])
    }
    extra <- if (length(unsupported_i) > 1L) {
      c("i" = "{length(unsupported_i) - 1L} additional non-zero upper-triangle pin{?s} {?was/were} also requested.")
    } else {
      character()
    }
    cli::cli_abort(c(
      "lambda_constraint pin at ({.val {row_lab}}, {.val {col_lab}}) = {.val {unsupported_v[1]}} lies in the strict upper triangle.",
      "x" = "The engine's lower-triangular loading parameterisation has no packed slot for Lambda[i, j] when j > i, so this pin cannot be applied.",
      extra,
      "i" = "Pins of 0 in the upper triangle are already structural zeros and are accepted.",
      ">" = "Move the pin onto or below the diagonal (row index >= axis index), or omit it."
    ))
  }
  list(map = factor(map), init = init)
}
