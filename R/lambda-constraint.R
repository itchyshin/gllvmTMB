## Galamm-style confirmatory loadings via the existing TMB packed-vector
## parameterisation.
##
## In the engine, theta_rr_B is packed as
##    theta_rr_B[0:rank-1]              = lam_diag (diagonal entries)
##    theta_rr_B[rank : rank + nl - 1]  = lam_lower (strict lower triangle,
##                                                   filled column-wise)
## with `nl = rank * n_traits - rank * (rank + 1) / 2` lower-triangle
## entries. The C++ kernel then writes the upper triangle as zero, the
## diagonal as `lam_diag(j)`, and the strict lower triangle as
## `lam_lower(j*p - (j+1)*j/2 + i - 1 - j)` (column-major fill).
##
## To "pin" a Lambda entry to a user-specified value v, we set the
## corresponding theta_rr_B entry to v and mark it via a TMB `map` so
## the optimiser leaves it alone. Upper-triangle pins are ignored
## (those entries are zero by construction). All other entries remain
## free, so the rest of the lower-triangular Cholesky structure is
## preserved.
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
  ## Lower triangle: theta_rr[rank + j*p - (j+1)*j/2 + i - 1 - j]
  ## NB: R parses `(j + 1L) * j %/% 2L` as `(j + 1L) * (j %/% 2L)` because
  ## %/% binds tighter than *. Use explicit parens or split via a tmp.
  triangular <- ((j + 1L) * j) %/% 2L
  rank + (j * p - triangular + i - 1L - j) + 1L
}

#' Build a TMB map + init pair from a Lambda constraint matrix
#'
#' @param constraint An `n_traits × rank` matrix; `NA` = free, numeric
#'   = pin to that value. Upper-triangle entries are silently ignored.
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
  for (i in seq_len(n_traits)) {
    for (j in seq_len(rank)) {
      if (j > i) next
      v <- constraint[i, j]
      if (!is.na(v)) {
        idx <- lambda_packed_index(i - 1L, j - 1L, n_traits, rank)
        if (!is.na(idx)) {
          map[idx]  <- NA
          init[idx] <- v
        }
      }
    }
  }
  list(map = factor(map), init = init)
}
