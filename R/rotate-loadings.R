## Post-hoc rotation of the gllvmTMB loading matrix.
##
## The lifted glmmTMB rr() machinery enforces lower-triangular Lambda
## with a free-positive diagonal. That removes rotation and sign
## indeterminacy at the cost of interpretability — the columns of
## Lambda are not the most "interpretable" factors in any factor-
## analysis sense. After fitting, users typically want a varimax (or
## promax) rotation to produce factors with simple structure.
##
## `gllvm` exposes `getLoadings()` so users can rotate manually;
## `galamm` supports confirmatory specification but no rotation;
## `glmmTMB` exposes neither. gllvmTMB now provides both.

#' Rotate the loadings of a fitted `gllvmTMB_multi` model
#'
#' Applies a post-hoc rotation (e.g. varimax) to the loading matrix
#' \eqn{\Lambda} of either the between-unit (`level = "unit"`) or
#' within-unit (`level = "unit_obs"`) reduced-rank component. The latent scores are
#' rotated by the inverse transform so the linear predictor (and the
#' fitted log-likelihood) is unchanged; only the *parameterisation*
#' changes.
#'
#' Useful when the lower-triangular constraint inherited from the
#' glmmTMB-style lower-triangular constraint produces hard-to-interpret factors;
#' a varimax rotation almost always yields cleaner trait-loading
#' patterns.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Legacy aliases `"B"` and `"W"` are accepted with a deprecation warning.
#' @param method One of `"varimax"`, `"promax"`, or `"none"`.
#'
#' @return A list with rotated `Lambda` (n_traits × d), rotated
#'   `scores` (with rows = units or within-unit observations, columns = factors),
#'   and the rotation matrix `T` such that
#'   \eqn{\Lambda_{\text{rotated}} = \Lambda T}.
#'
#' @details
#' The rotation is applied to \eqn{\Lambda} on the *left* and to the
#' latent scores on the *right* using the inverse transform, so
#' \eqn{\Lambda_{\text{rot}} \mathbf{z}_{\text{rot}} = \Lambda \mathbf{z}}
#' is unchanged. For varimax, `T` is orthogonal so the rotation
#' preserves the implied covariance \eqn{\Lambda \Lambda^\top}; for
#' promax, `T` is oblique and the columns of \eqn{\Lambda_{\text{rot}}}
#' are no longer orthogonal.
#'
#' @export
#' @examples
#' \dontrun{
#' set.seed(1)
#' sim <- simulate_site_trait(
#'   n_sites = 60, n_species = 12, n_traits = 4,
#'   Lambda_B = matrix(c(1.0, 0.7, -0.3, 0.5,
#'                       0.3, -0.5, 0.8, 0.2),
#'                     nrow = 4, ncol = 2),
#'   psi_B = c(0.3, 0.3, 0.3, 0.3),
#'   seed = 1
#' )
#' fit <- gllvmTMB(value ~ 0 + trait +
#'                         latent(0 + trait | site, d = 2) +
#'                         unique(0 + trait | site),
#'                 data  = sim$data,
#'                 trait = "trait",
#'                 unit  = "site")
#' raw <- extract_ordination(fit, "unit")
#' rot <- rotate_loadings(fit, level = "unit", method = "varimax")
#' # raw$loadings - lower-triangular (hard to read)
#' # rot$Lambda  - varimax-rotated (typically simpler structure)
#' }
rotate_loadings <- function(fit,
                            level  = c("unit", "unit_obs", "B", "W"),
                            method = c("varimax", "promax", "none")) {
  level  <- match.arg(level)
  level  <- .normalise_level(level, arg_name = "level")
  method <- match.arg(method)
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Pass a gllvmTMB_multi fit.")

  ord <- extract_ordination(fit, level = .canonical_level_name(level))
  if (is.null(ord))
    cli::cli_abort("latent() not active at level {.val {level}}; nothing to rotate.")
  Lambda <- ord$loadings
  Z      <- ord$scores

  if (method == "none") {
    return(list(Lambda = Lambda, scores = Z, T = diag(ncol(Lambda)),
                method = "none"))
  }
  if (method == "varimax") {
    rt <- stats::varimax(Lambda, normalize = TRUE)
    T  <- as.matrix(rt$rotmat)        # orthogonal
    Lambda_rot <- Lambda %*% T
    Z_rot      <- Z      %*% T
  } else if (method == "promax") {
    rt <- stats::promax(Lambda)
    T  <- as.matrix(rt$rotmat)        # oblique
    Lambda_rot <- Lambda %*% T
    Z_rot      <- Z      %*% solve(t(T))   # complementary transform
  }
  list(
    Lambda = Lambda_rot,
    scores = Z_rot,
    T      = T,
    method = method
  )
}


#' Compare two loading matrices (Procrustes alignment)
#'
#' When fitting two models with latent() on the same dataset (e.g. a
#' gllvmTMB fit and a glmmTMB or gllvm fit) the loadings are only
#' identified up to rotation/sign. Procrustes alignment finds the
#' orthogonal transform that brings one as close to the other as
#' possible, then reports the residual disagreement. Useful as a
#' diagnostic when validating against another package.
#'
#' @param Lambda_a,Lambda_b Two `n_traits × d` loading matrices.
#' @return A list with the optimal rotation `R`, the rotated `Lambda_a_rot`,
#'   and the Frobenius distance after alignment.
#' @export
#' @examples
#' \dontrun{
#' fit_g <- gllvmTMB(value ~ 0 + trait + latent(0+trait|site, d=2),
#'                   data = df, trait = "trait", unit = "site")
#' fit_t <- glmmTMB::glmmTMB(value ~ 0 + trait + rr(0+trait|site, d=2),
#'                          data = df, REML = FALSE)
#' L_g <- extract_ordination(fit_g, "B")$loadings
#' L_t <- attr(glmmTMB::ranef(fit_t)$cond$site, "loadings")
#' compare_loadings(L_g, L_t)
#' }
compare_loadings <- function(Lambda_a, Lambda_b) {
  if (!is.matrix(Lambda_a) || !is.matrix(Lambda_b))
    cli::cli_abort("Lambda_a and Lambda_b must be matrices.")
  if (!all(dim(Lambda_a) == dim(Lambda_b)))
    cli::cli_abort("Lambda_a and Lambda_b must have the same dimensions.")
  M <- crossprod(Lambda_b, Lambda_a)
  sv <- svd(M)
  R <- sv$v %*% t(sv$u)
  Lambda_a_rot <- Lambda_a %*% R
  list(
    R              = R,
    Lambda_a_rot   = Lambda_a_rot,
    frobenius      = sqrt(sum((Lambda_a_rot - Lambda_b)^2)),
    cor_per_factor = vapply(seq_len(ncol(Lambda_a)),
                            function(k) stats::cor(Lambda_a_rot[, k],
                                                   Lambda_b[, k]),
                            numeric(1))
  )
}
