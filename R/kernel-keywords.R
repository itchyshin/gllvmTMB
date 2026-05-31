#' Generic dense-kernel covariance keywords
#'
#' @description
#' `kernel_latent()` and `kernel_unique()` fit a named random-effect tier
#' with a user-supplied between-unit covariance matrix `K`. The IN scope
#' (`KER-02`) for this C1 dense-kernel slice is the phylo-equivalent path:
#' `kernel_latent(unit, K = A, d = q)` plus `kernel_unique(unit, K = A)`
#' must match `phylo_latent(unit, vcv = A, d = q)` plus
#' `phylo_unique(unit, vcv = A)` to less than `1e-6` for log likelihood
#' and extracted `Sigma`. The PARTIAL scope (`COE-02`) is coevolution:
#' users can pass a `K_star` from [make_cross_kernel()], but validated
#' coevolution recovery and `extract_Gamma()` remain planned C2 work.
#'
#' @param unit Unquoted grouping column whose levels align with `rownames(K)`.
#' @param K Numeric dense positive-semidefinite covariance/correlation matrix.
#'   In C1 this routes through the existing phylo-equivalent dense `vcv`
#'   path.
#' @param d Integer latent rank for `kernel_latent()`.
#' @param name Character scalar used as the extractor level, e.g.
#'   `extract_Sigma(fit, level = "cross")`.
#'
#' @return A formula marker; never evaluated as a regular R function.
#'
#' @examples
#' \dontrun{
#' A <- diag(5)
#' dat <- data.frame(
#'   unit = factor(rep(paste0("u", 1:5), each = 2), levels = paste0("u", 1:5)),
#'   obs = factor(seq_len(10)),
#'   y1 = rnorm(10),
#'   y2 = rnorm(10)
#' )
#' rownames(A) <- colnames(A) <- levels(dat$unit)
#' fit <- gllvmTMB(
#'   traits(y1, y2) ~
#'     1 + kernel_latent(unit, K = A, d = 1, name = "known") +
#'     kernel_unique(unit, K = A, name = "known"),
#'   data = dat,
#'   unit = "obs",
#'   cluster = "unit",
#'   family = gaussian()
#' )
#' extract_Sigma(fit, level = "known")
#' }
#'
#' @export
kernel_latent <- function(unit, K, d = 1, name = "kernel") {
  invisible(NULL)
}

#' @rdname kernel_latent
#' @export
kernel_unique <- function(unit, K, name = "kernel") {
  invisible(NULL)
}

#' @rdname kernel_latent
#' @export
kernel_indep <- function(unit, K, name = "kernel") {
  invisible(NULL)
}

#' @rdname kernel_latent
#' @export
kernel_dep <- function(unit, K, name = "kernel") {
  invisible(NULL)
}
