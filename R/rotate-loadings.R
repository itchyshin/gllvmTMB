## Rotation of the gllvmTMB loading matrix after fitting.
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

#' Rotate the loadings of a fitted multivariate model
#'
#' Applies a varimax or promax rotation to the loading matrix \eqn{\Lambda}
#' from a fit returned by [gllvmTMB()]. Use `level = "unit"` for the
#' between-unit reduced-rank component and `level = "unit_obs"` for the
#' within-unit component. The latent scores are rotated by the complementary
#' transform so the linear predictor, fitted log-likelihood, and implied
#' covariance are unchanged.
#'
#' Rotation is for interpretation of the loading columns, especially figures.
#' It does not make the axes uniquely "right"; it chooses a readable
#' orientation among mathematically equivalent orientations. For quantitative
#' interpretation, start from the model-implied `Sigma`, correlations,
#' communality, and uniqueness, then use rotated axes for labels and plots.
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()].
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Deprecated aliases `"B"` and `"W"` are still accepted with a warning.
#' @param method One of `"varimax"`, `"promax"`, or `"none"`.
#' @param order_axes Logical. When `TRUE` (default for rotated output),
#'   reorder rotated axes by decreasing shared variance
#'   `colSums(Lambda^2)`. Ignored when `method = "none"`.
#' @param sign_anchor One of `"auto"` or `"none"`. `"auto"` (default for
#'   rotated output) flips each rotated axis so its anchor trait has a
#'   positive loading. Ignored when `method = "none"`.
#' @param anchor_traits Optional character vector of trait names used for
#'   sign anchoring. Supply one trait per axis after ordering. Axes without a
#'   supplied anchor use the trait with the largest absolute loading.
#'
#' @return A list with rotated `Lambda` (n_traits × d), rotated
#'   `scores` (with rows = units or within-unit observations, columns = factors),
#'   and the rotation matrix `T` such that
#'   \eqn{\Lambda_{\text{rotated}} = \Lambda T}. The list also includes
#'   `axis_variance`, `axis_order`, `axis_sign`, and `anchor_traits`
#'   metadata after any ordering and sign anchoring.
#'
#' @details
#' A defensible plotting workflow is: fit the model, check convergence,
#' reconstruct covariance summaries, then rotate loadings for visual
#' interpretation. Rotate `level = "unit"` and `level = "unit_obs"` separately
#' because they represent different covariance structures. `method =
#' "varimax"` is the usual first choice for a simple loading pattern; use
#' `method = "promax"` only when correlated latent axes are intended.
#'
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
rotate_loadings <- function(
  fit,
  level = "unit",
  method = c("varimax", "promax", "none"),
  order_axes = TRUE,
  sign_anchor = c("auto", "none"),
  anchor_traits = NULL
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  method <- match.arg(method)
  sign_anchor <- match.arg(sign_anchor)
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }

  ord <- extract_ordination(fit, level = .canonical_level_name(level))
  if (is.null(ord)) {
    cli::cli_abort(
      "latent() not active at level {.val {level}}; nothing to rotate."
    )
  }
  Lambda <- ord$loadings
  Z <- ord$scores
  d <- ncol(Lambda)

  if (!is.null(anchor_traits)) {
    if (!is.character(anchor_traits)) {
      cli::cli_abort("{.arg anchor_traits} must be a character vector.")
    }
    if (length(anchor_traits) > d) {
      cli::cli_abort(
        "{.arg anchor_traits} must have at most one trait name per axis."
      )
    }
    bad_anchor <- setdiff(stats::na.omit(anchor_traits), rownames(Lambda))
    if (length(bad_anchor) > 0L) {
      cli::cli_abort(c(
        "{.arg anchor_traits} must be trait names in the loading matrix.",
        "x" = "Unknown trait{?s}: {.val {bad_anchor}}."
      ))
    }
  }

  if (method == "none") {
    return(list(
      Lambda = Lambda,
      scores = Z,
      T = diag(d),
      method = "none",
      axis_variance = colSums(Lambda^2),
      axis_order = seq_len(d),
      axis_sign = rep(1, d),
      anchor_traits = rep(NA_character_, d)
    ))
  }
  if (d == 1L) {
    T <- diag(1L)
    Lambda_rot <- Lambda
    Z_rot <- Z
  } else if (method == "varimax") {
    rt <- stats::varimax(Lambda, normalize = TRUE)
    T <- as.matrix(rt$rotmat) # orthogonal
    Lambda_rot <- Lambda %*% T
    Z_rot <- Z %*% T
  } else if (method == "promax") {
    rt <- stats::promax(Lambda)
    T <- as.matrix(rt$rotmat) # oblique
    Lambda_rot <- Lambda %*% T
    Z_rot <- Z %*% solve(t(T)) # complementary transform
  }

  axis_order <- seq_len(d)
  axis_sign <- rep(1, d)
  anchors_used <- rep(NA_character_, d)
  post_T <- diag(d)

  if (isTRUE(order_axes)) {
    axis_variance_pre <- colSums(Lambda_rot^2)
    axis_order <- order(axis_variance_pre, decreasing = TRUE)
    P_order <- diag(d)[, axis_order, drop = FALSE]
    Lambda_rot <- Lambda_rot %*% P_order
    Z_rot <- Z_rot %*% P_order
    post_T <- post_T %*% P_order
  }

  if (identical(sign_anchor, "auto")) {
    for (k in seq_len(d)) {
      anchor <- if (!is.null(anchor_traits) && length(anchor_traits) >= k) {
        anchor_traits[[k]]
      } else {
        NA_character_
      }
      if (is.na(anchor) || !nzchar(anchor)) {
        anchor_i <- which.max(abs(Lambda_rot[, k]))
        anchor <- rownames(Lambda_rot)[[anchor_i]]
      } else {
        anchor_i <- match(anchor, rownames(Lambda_rot))
      }
      anchors_used[[k]] <- anchor
      if (Lambda_rot[anchor_i, k] < 0) {
        axis_sign[[k]] <- -1
      }
    }
    P_sign <- diag(axis_sign, d)
    Lambda_rot <- Lambda_rot %*% P_sign
    Z_rot <- Z_rot %*% P_sign
    post_T <- post_T %*% P_sign
  }
  T <- T %*% post_T
  axis_names <- paste0("LV", seq_len(d))
  colnames(Lambda_rot) <- axis_names
  colnames(Z_rot) <- axis_names

  list(
    Lambda = Lambda_rot,
    scores = Z_rot,
    T = T,
    method = method,
    axis_variance = colSums(Lambda_rot^2),
    axis_order = axis_order,
    axis_sign = axis_sign,
    anchor_traits = anchors_used
  )
}


#' Extract a tidy rotated loading table
#'
#' Returns one row per trait and latent axis from a fitted [gllvmTMB()] model.
#' This is the report-ready companion to [rotate_loadings()] and to
#' `plot(type = "ordination")`: the same rotation, axis-ordering, sign-anchor,
#' and optional loading-standardization conventions are recorded in columns
#' instead of left inside a matrix.
#'
#' Scope: IN (EXT-28), fitted `latent()` components at `level = "unit"` or
#' `level = "unit_obs"` with raw or standardized point-estimate loadings.
#' PARTIAL: this table does not attach uncertainty intervals to loadings.
#' PLANNED: bootstrap or simulation-based uncertainty can be layered on top in
#' a later inference slice.
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()].
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Deprecated aliases `"B"` and `"W"` are still accepted with a warning.
#' @param method One of `"varimax"`, `"promax"`, or `"none"`; passed to
#'   [rotate_loadings()].
#' @param order_axes Logical. When `TRUE`, reorder rotated axes by decreasing
#'   raw shared variance before tabulation. Ignored when `method = "none"`.
#' @param sign_anchor One of `"auto"` or `"none"`. `"auto"` flips each rotated
#'   axis so its anchor trait has a positive loading. Ignored when
#'   `method = "none"`.
#' @param anchor_traits Optional character vector of trait names used for
#'   sign anchoring. Supply one trait per axis after ordering. Axes without a
#'   supplied anchor use the trait with the largest absolute loading.
#' @param loading_scale One of `"raw"` or `"standardized"`. `"raw"` returns
#'   the rotated loadings on the fitted response scale. `"standardized"`
#'   divides each trait loading by the square root of that trait's
#'   model-implied total variance, matching `plot(type = "ordination",
#'   standardize_loadings = TRUE)`.
#'
#' @return A data frame with columns `level`, `trait`, `axis`, `loading`,
#'   `abs_loading`, `axis_variance`, `axis_share`, `rotation`, `order_axes`,
#'   `sign_anchor`, `anchor_trait`, and `loading_scale`. `axis_variance` and
#'   `axis_share` are computed from the rotated raw loading matrix before any
#'   optional standardization; these are the quantities used to order axes.
#'
#' @seealso [rotate_loadings()], [extract_ordination()], [extract_Sigma()],
#'   [plot.gllvmTMB_multi()].
#' @export
#' @examples
#' \dontrun{
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
#' extract_rotated_loadings_table(
#'   fit,
#'   level = "unit",
#'   method = "varimax",
#'   loading_scale = "standardized"
#' )
#' }
extract_rotated_loadings_table <- function(
  fit,
  level = "unit",
  method = c("varimax", "promax", "none"),
  order_axes = TRUE,
  sign_anchor = c("auto", "none"),
  anchor_traits = NULL,
  loading_scale = c("raw", "standardized")
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  level_label <- .canonical_level_name(level)
  method <- match.arg(method)
  sign_anchor <- match.arg(sign_anchor)
  loading_scale <- match.arg(loading_scale)

  rotation_info <- rotate_loadings(
    fit,
    level = level_label,
    method = method,
    order_axes = order_axes,
    sign_anchor = sign_anchor,
    anchor_traits = anchor_traits
  )
  Lambda <- rotation_info$Lambda
  if (is.null(rownames(Lambda))) {
    rownames(Lambda) <- levels(fit$data[[fit$trait_col]])
  }

  if (identical(loading_scale, "standardized")) {
    Lambda <- .standardize_loadings_by_total_variance(
      fit,
      Lambda = Lambda,
      level = level_label
    )
  }

  trait_names <- rownames(Lambda)
  axis_names <- colnames(Lambda)
  if (is.null(axis_names) || any(!nzchar(axis_names))) {
    axis_names <- paste0("LV", seq_len(ncol(Lambda)))
  }
  axis_variance <- as.numeric(rotation_info$axis_variance)
  axis_total <- sum(axis_variance)
  axis_share <- if (is.finite(axis_total) && axis_total > 0) {
    axis_variance / axis_total
  } else {
    rep(NA_real_, length(axis_variance))
  }
  anchor_out <- rotation_info$anchor_traits
  if (length(anchor_out) != ncol(Lambda)) {
    anchor_out <- rep(NA_character_, ncol(Lambda))
  }

  out <- data.frame(
    level = rep(level_label, length(trait_names) * length(axis_names)),
    trait = rep(trait_names, times = length(axis_names)),
    axis = rep(axis_names, each = length(trait_names)),
    loading = as.numeric(Lambda),
    abs_loading = abs(as.numeric(Lambda)),
    axis_variance = rep(axis_variance, each = length(trait_names)),
    axis_share = rep(axis_share, each = length(trait_names)),
    rotation = rep(
      rotation_info$method,
      length(trait_names) * length(axis_names)
    ),
    order_axes = rep(
      !identical(rotation_info$method, "none") && isTRUE(order_axes),
      length(trait_names) * length(axis_names)
    ),
    sign_anchor = rep(
      if (identical(rotation_info$method, "none")) "none" else sign_anchor,
      length(trait_names) * length(axis_names)
    ),
    anchor_trait = rep(anchor_out, each = length(trait_names)),
    loading_scale = rep(
      loading_scale,
      length(trait_names) * length(axis_names)
    ),
    stringsAsFactors = FALSE
  )
  attr(out, "gllvmTMB_rotation") <- list(
    method = rotation_info$method,
    order_axes = !identical(rotation_info$method, "none") && isTRUE(order_axes),
    sign_anchor = if (identical(rotation_info$method, "none")) {
      "none"
    } else {
      sign_anchor
    },
    axis_order = rotation_info$axis_order,
    axis_sign = rotation_info$axis_sign,
    anchor_traits = rotation_info$anchor_traits,
    loading_scale = loading_scale
  )
  out
}

.standardize_loadings_by_total_variance <- function(fit, Lambda, level) {
  sigma_out <- suppressMessages(extract_Sigma(
    fit,
    level = level,
    part = "total",
    link_residual = "auto",
    .skip_warn = TRUE
  ))
  level_label <- .canonical_level_name(.normalise_level(
    level,
    arg_name = "level",
    .skip_warn = TRUE
  ))
  if (is.null(sigma_out)) {
    cli::cli_abort(
      "Cannot standardize loadings because Sigma is unavailable at level {.val {level_label}}."
    )
  }
  denom <- sqrt(diag(sigma_out$Sigma))
  if (any(!is.finite(denom) | denom <= 0)) {
    cli::cli_abort(
      "Cannot standardize loadings because at least one trait has non-positive total variance."
    )
  }
  sweep(Lambda, 1L, denom, "/")
}


#' Compare two loading matrices after Procrustes alignment
#'
#' When two latent-variable fits use the same traits, the loading matrices are
#' only identified up to rotation and sign. Procrustes alignment finds the
#' orthogonal transform that brings one matrix as close as possible to the
#' other, then reports the residual disagreement. This is mainly a validation
#' helper for comparing [gllvmTMB()] with another implementation.
#'
#' @param Lambda_a,Lambda_b Two `n_traits × d` loading matrices.
#' @return A list with the optimal rotation `R`, the rotated `Lambda_a_rot`,
#'   and the Frobenius distance after alignment.
#' @export
#' @examples
#' \dontrun{
#' fit_g <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'                   data = df, trait = "trait", unit = "site")
#' fit_t <- glmmTMB::glmmTMB(value ~ 0 + trait + rr(0 + trait | site, d = 2),
#'                          data = df, REML = FALSE)
#' L_g <- extract_ordination(fit_g, "unit")$loadings
#' L_t <- attr(glmmTMB::ranef(fit_t)$cond$site, "loadings")
#' compare_loadings(L_g, L_t)
#' }
compare_loadings <- function(Lambda_a, Lambda_b) {
  if (!is.matrix(Lambda_a) || !is.matrix(Lambda_b)) {
    cli::cli_abort("Lambda_a and Lambda_b must be matrices.")
  }
  if (!all(dim(Lambda_a) == dim(Lambda_b))) {
    cli::cli_abort("Lambda_a and Lambda_b must have the same dimensions.")
  }
  M <- crossprod(Lambda_b, Lambda_a)
  sv <- svd(M)
  R <- sv$v %*% t(sv$u)
  Lambda_a_rot <- Lambda_a %*% R
  list(
    R = R,
    Lambda_a_rot = Lambda_a_rot,
    frobenius = sqrt(sum((Lambda_a_rot - Lambda_b)^2)),
    cor_per_factor = vapply(
      seq_len(ncol(Lambda_a)),
      function(k) stats::cor(Lambda_a_rot[, k], Lambda_b[, k]),
      numeric(1)
    )
  )
}
