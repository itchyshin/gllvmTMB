#' Build a cross-lineage relatedness kernel
#'
#' @description
#' `make_cross_kernel()` builds the block relatedness matrix for the C0
#' coevolution prototype. The IN scope (`KER-01`) is a correlation-scale
#' positive-semidefinite matrix
#' `K_star = rbind(cbind(A_H, C_HP), cbind(t(C_HP), A_P))`, where `A_H`
#' and `A_P` are within-lineage relatedness matrices and `C_HP` is the
#' cross-lineage bridge induced by the association matrix `W`. The PARTIAL
#' scope (`COE-01`) is the prototype path: use `K_star` through the
#' existing `phylo_latent(..., vcv = K_star) + phylo_unique(..., vcv =
#' K_star)` engine. The generic `kernel_*()` surface (`KER-02`) and
#' validated `extract_Gamma()` coevolution gate (`COE-02`) are now covered
#' separately; this helper only builds the input kernel.
#'
#' @param A_H,A_P Numeric square correlation matrices for the host and
#'   partner lineages. Both must be symmetric, positive semidefinite, and
#'   have unit diagonal.
#' @param W Numeric association matrix with `nrow(W) == nrow(A_H)` and
#'   `ncol(W) == nrow(A_P)`. If `W` has row or column names, they are
#'   aligned to `A_H` / `A_P` names before the kernel is built.
#' @param rho Scalar bridge strength in `[-1, 1]`. Larger absolute values
#'   put more covariance in the off-diagonal host-partner block.
#' @param eps Positive numerical floor used when taking symmetric square
#'   roots and scaling an all-zero or near-zero `W`.
#'
#' @return A numeric correlation matrix with the host block first and the
#'   partner block second.
#'
#' @examples
#' A_H <- matrix(c(
#'   1.0, 0.3, 0.1,
#'   0.3, 1.0, 0.2,
#'   0.1, 0.2, 1.0
#' ), 3, 3, byrow = TRUE)
#' A_P <- matrix(c(1.0, 0.25, 0.25, 1.0), 2, 2)
#' W <- matrix(c(1, 0, 0.5, 0, 1, 0.25), 3, 2, byrow = TRUE)
#' K_star <- make_cross_kernel(A_H, A_P, W, rho = 0.4)
#' min(eigen(K_star, symmetric = TRUE, only.values = TRUE)$values)
#'
#' @export
make_cross_kernel <- function(A_H, A_P, W, rho = 0.5, eps = 1e-8) {
  A_H <- .cross_kernel_as_matrix(A_H, "A_H")
  A_P <- .cross_kernel_as_matrix(A_P, "A_P")
  W <- .cross_kernel_as_matrix(W, "W", square = FALSE)

  if (!is.numeric(rho) || length(rho) != 1L || !is.finite(rho)) {
    cli::cli_abort("{.arg rho} must be one finite number.")
  }
  if (abs(rho) > 1) {
    cli::cli_abort(c(
      "{.arg rho} must lie in [-1, 1].",
      "i" = "The cross block is spectrally scaled, so |rho| <= 1 keeps the block kernel positive semidefinite."
    ))
  }
  if (!is.numeric(eps) || length(eps) != 1L || !is.finite(eps) || eps <= 0) {
    cli::cli_abort("{.arg eps} must be one positive finite number.")
  }

  .cross_kernel_check_correlation(A_H, "A_H", eps = eps)
  .cross_kernel_check_correlation(A_P, "A_P", eps = eps)

  n_H <- nrow(A_H)
  n_P <- nrow(A_P)
  if (nrow(W) != n_H || ncol(W) != n_P) {
    cli::cli_abort(c(
      "{.arg W} has incompatible dimensions.",
      "i" = "{.arg W} must be nrow(A_H) x nrow(A_P); got {nrow(W)} x {ncol(W)} for {n_H} x {n_P}."
    ))
  }

  h_names <- .cross_kernel_names(A_H, "A_H", "H")
  p_names <- .cross_kernel_names(A_P, "A_P", "P")
  if (anyDuplicated(c(h_names, p_names))) {
    cli::cli_abort(c(
      "Host and partner names must be unique after concatenation.",
      "i" = "Prefix one lineage before calling {.fn make_cross_kernel}."
    ))
  }
  W <- .cross_kernel_align_W(W, h_names, p_names)

  L_H <- .cross_kernel_symmetric_sqrt(A_H, eps = eps)
  L_P <- .cross_kernel_symmetric_sqrt(A_P, eps = eps)

  sv <- svd(W, nu = 0L, nv = 0L)$d
  spectral_norm <- if (length(sv)) sv[1L] else 0
  W_scaled <- W / max(spectral_norm, eps)
  C_HP <- rho * L_H %*% W_scaled %*% t(L_P)

  K <- rbind(
    cbind(A_H, C_HP),
    cbind(t(C_HP), A_P)
  )
  K <- (K + t(K)) / 2
  diag(K) <- 1
  dimnames(K) <- list(c(h_names, p_names), c(h_names, p_names))

  eig <- eigen(K, symmetric = TRUE, only.values = TRUE)$values
  min_eig <- min(eig)
  if (!is.finite(min_eig) || min_eig < -1e-6) {
    cli::cli_abort(c(
      "Cross-lineage kernel is not positive semidefinite.",
      "i" = "Minimum eigenvalue is {signif(min_eig, 4)}.",
      ">" = "Lower {.arg rho} or rescale {.arg W} before fitting."
    ))
  }

  K
}

.cross_kernel_as_matrix <- function(x, arg, square = TRUE) {
  if (inherits(x, "Matrix")) {
    x <- as.matrix(x)
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    cli::cli_abort("{.arg {arg}} must be a numeric matrix.")
  }
  if (anyNA(x) || any(!is.finite(x))) {
    cli::cli_abort("{.arg {arg}} must contain only finite, non-missing values.")
  }
  if (square && nrow(x) != ncol(x)) {
    cli::cli_abort("{.arg {arg}} must be square.")
  }
  storage.mode(x) <- "double"
  x
}

.cross_kernel_names <- function(A, arg, prefix) {
  rn <- rownames(A)
  cn <- colnames(A)
  if (!is.null(rn) && !is.null(cn) && !identical(rn, cn)) {
    cli::cli_abort("Row names and column names of {.arg {arg}} must match.")
  }
  if (is.null(rn)) {
    rn <- paste0(prefix, seq_len(nrow(A)))
  }
  rn
}

.cross_kernel_check_correlation <- function(A, arg, eps) {
  if (max(abs(A - t(A))) > sqrt(eps)) {
    cli::cli_abort("{.arg {arg}} must be symmetric.")
  }
  if (max(abs(diag(A) - 1)) > sqrt(eps)) {
    cli::cli_abort(c(
      "{.arg {arg}} must be correlation-scaled with unit diagonal.",
      "i" = "Scale the relatedness matrix before calling {.fn make_cross_kernel}."
    ))
  }
  eig <- eigen((A + t(A)) / 2, symmetric = TRUE, only.values = TRUE)$values
  min_eig <- min(eig)
  if (!is.finite(min_eig) || min_eig < -1e-6) {
    cli::cli_abort(c(
      "{.arg {arg}} must be positive semidefinite.",
      "i" = "Minimum eigenvalue is {signif(min_eig, 4)}."
    ))
  }
  invisible(TRUE)
}

.cross_kernel_symmetric_sqrt <- function(A, eps) {
  eig <- eigen((A + t(A)) / 2, symmetric = TRUE)
  vals <- pmax(eig$values, eps)
  sweep(eig$vectors, 2L, sqrt(vals), `*`) %*% t(eig$vectors)
}

.cross_kernel_align_W <- function(W, h_names, p_names) {
  if (!is.null(rownames(W))) {
    if (!all(h_names %in% rownames(W))) {
      cli::cli_abort("{.arg W} row names must cover row names of {.arg A_H}.")
    }
    W <- W[h_names, , drop = FALSE]
  }
  if (!is.null(colnames(W))) {
    if (!all(p_names %in% colnames(W))) {
      cli::cli_abort("{.arg W} column names must cover row names of {.arg A_P}.")
    }
    W <- W[, p_names, drop = FALSE]
  }
  W
}
