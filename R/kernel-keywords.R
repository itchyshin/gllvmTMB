#' Generic dense-kernel covariance keywords
#'
#' @description
#' `kernel_latent()` and `kernel_unique()` fit named random-effect tiers
#' with user-supplied between-unit covariance matrices `K`. The IN scope
#' (`KER-02`) for one named dense-kernel tier is the phylo-equivalent path:
#' `kernel_latent(unit, K = A, d = q)` plus `kernel_unique(unit, K = A)`
#' must match `phylo_latent(unit, vcv = A, d = q)` plus
#' `phylo_unique(unit, vcv = A)` to less than `1e-6` for log likelihood
#' and extracted `Sigma`. The first multi-kernel scope (`KER-03`) accepts
#' two or more fixed named `kernel_latent()` tiers over the same grouping
#' levels, each with its own `K`, loading matrix, and latent field. This
#' Paper 2 first wave is latent-only: paired `kernel_unique()` Psi is deferred
#' because explicit residual/Psi structure is a poor default for non-Gaussian
#' and cross-family coevolution models. `kernel_dep()` remains single-tier
#' only in this first wave.
#'
#' The cross-lineage coevolution scope remains evidence-gated. IN (`COE-02`):
#' users can pass one `K_star` from [make_cross_kernel()] and extract the
#' host-partner shared covariance block with [extract_Gamma()]. PARTIAL
#' (`COE-03`): fixed two-component named-kernel fits are available for
#' component-specific `Gamma_shape` extraction, but explicit Psi, kernel-
#' separation recovery, `rho` estimation/profiling, and interval calibration
#' remain future gates. The broader `*_unique()` teaching/API surface is kept
#' for compatibility now and should be redesigned/deprecated after this arc.
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
