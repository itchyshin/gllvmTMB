## Two-stage meta-regression utilities.
##
## The legacy two-stage workflow (`fit_trait_stage1`, `fit_site_meta`)
## was deprecated in 0.1.x and dropped in 0.2.0; users should call
## `gllvmTMB()` directly with `phylo_scalar(species)` /
## `phylo_latent(species, d = K)` for stage-1 phylogenetic fits, then
## stage-2 multivariate fits with `meta_known_V(V = V)`.
##
## What remains here is `block_V()`, the small helper that builds a
## block-diagonal sampling-variance matrix to feed `meta_known_V()`.

#' Build a block-diagonal sampling-variance matrix V
#'
#' Constructs a block-diagonal `n x n` matrix V suitable for the
#' [meta_known_V()] / `equalto()` covstruct in [gllvmTMB()], where
#' rows belonging to the same `study_id` are correlated and rows
#' from different studies are independent. Each block is a compound-
#' symmetric covariance matrix
#' \eqn{\mathbf{V}_s = \mathbf{D}_s^{1/2} \mathbf{R}_s \mathbf{D}_s^{1/2}}
#' with \eqn{\mathbf{D}_s = \mathrm{diag}(\sigma^2_{s1}, \ldots)} the
#' per-row sampling variances within study \eqn{s} and \eqn{\mathbf{R}_s}
#' the within-study correlation matrix (1 on the diagonal,
#' `rho_within` on the off-diagonal).
#'
#' Use this when you have multiple effect sizes per study (multiple
#' outcomes, multiple traits per individual, etc.) and the within-study
#' sampling errors share a common cause. The independent-rows / single-
#' effect-per-study case is `block_V(..., rho_within = 0)`, which
#' equals `diag(sampling_var)`.
#'
#' @param study_id A factor (or coercible to one) identifying which
#'   study each row belongs to. Rows with the same `study_id` form a
#'   block in V.
#' @param sampling_var Numeric vector of per-row sampling variances,
#'   length `length(study_id)`.
#' @param rho_within Either a single numeric in (-1, 1) used for every
#'   study's off-diagonals, or a named numeric vector with one entry
#'   per `study_id` level (allowing study-specific within-study
#'   correlations). Default 0.5 - a common ad-hoc choice in ecology
#'   meta-analyses when the true rho is unknown but plausibly moderate.
#'
#' @return A symmetric positive-definite `n x n` matrix.
#'
#' @seealso [meta_known_V()] for the canonical keyword that consumes
#'   the matrix produced here.
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   study = factor(rep(paste0("s", 1:3), each = 2)),
#'   var   = c(0.04, 0.05, 0.06, 0.04, 0.05, 0.07)
#' )
#' V <- block_V(df$study, df$var, rho_within = 0.5)
#' round(V, 3)
#' @export
block_V <- function(study_id, sampling_var, rho_within = 0.5) {
  if (!is.factor(study_id)) study_id <- factor(study_id)
  n <- length(study_id)
  if (length(sampling_var) != n)
    cli::cli_abort("length(sampling_var) must equal length(study_id) (got {length(sampling_var)} vs {n}).")
  if (any(sampling_var < 0))
    cli::cli_abort("All sampling_var entries must be non-negative.")

  if (length(rho_within) == 1L && is.null(names(rho_within))) {
    ## Unnamed scalar - broadcast to every study
    rho_vec <- stats::setNames(rep(rho_within, nlevels(study_id)),
                               levels(study_id))
  } else {
    if (is.null(names(rho_within)))
      cli::cli_abort("If {.arg rho_within} is a vector, it must be named with study levels.")
    miss <- setdiff(levels(study_id), names(rho_within))
    if (length(miss) > 0)
      cli::cli_abort("Missing rho_within entries for studies: {.val {miss}}.")
    rho_vec <- rho_within[levels(study_id)]
  }
  if (any(rho_vec <= -1) || any(rho_vec >= 1))
    cli::cli_abort("All rho_within entries must lie strictly in (-1, 1).")

  V <- matrix(0, nrow = n, ncol = n)
  sd_vec <- sqrt(sampling_var)
  for (s in levels(study_id)) {
    idx <- which(study_id == s)
    rho <- rho_vec[[s]]
    if (length(idx) == 1L) {
      V[idx, idx] <- sampling_var[idx]
    } else {
      Rs <- matrix(rho, length(idx), length(idx))
      diag(Rs) <- 1
      Vs <- diag(sd_vec[idx]) %*% Rs %*% diag(sd_vec[idx])
      V[idx, idx] <- Vs
    }
  }
  V
}
