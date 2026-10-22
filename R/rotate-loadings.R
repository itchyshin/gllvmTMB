## Rotation of the gllvmTMB loading matrix after fitting.
##
## The lifted glmmTMB rr() machinery enforces a lower-triangular Lambda.
## Its diagonal is free-SIGNED (not pinned positive at fit time), so the raw
## loadings still carry sign / rotation indeterminacy; extract_ordination()
## returns them un-canonicalized by default (unlike GLLVM.jl, which pins a
## sign convention). Resolve it on demand with rotate_loadings(sign_anchor =
## "auto"). Separately, the columns of Lambda are not the most "interpretable"
## factors in any factor-analysis sense. After fitting, users typically want a
## varimax (or promax) rotation to produce factors with simple structure.
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
#' set.seed(1)
#' # Simulate six traits, each measured twice on 100 units (e.g. sites).
#' # Traits 2-3 share one latent axis, traits 4-6 share a second axis,
#' # and trait_1 loads on both.
#' Lambda <- cbind(c(0.7, 1.0, 0.9, 0.0, 0.0, 0.0),
#'                 c(0.7, 0.0, 0.0, 1.0, 0.9, 0.8))
#' sim <- simulate_unit_trait(n_units = 100, n_obs_per_unit = 2,
#'                            n_traits = 6, Lambda_B = Lambda,
#'                            psi_B = 0.4, sigma2_eps = 0.3)
#' # Two latent axes plus a trait-specific variance (unique = TRUE).
#' fit <- gllvmTMB(value ~ 0 + trait +
#'                   latent(0 + trait | unit, d = 2, unique = TRUE),
#'                 data = sim$data, trait = "trait", unit = "unit")
#'
#' # Raw loadings: to pin down the axes, the fit fixes trait_1's loading
#' # on axis 2 at zero, so the other traits are spread over both axes.
#' raw <- extract_ordination(fit, "unit")
#' round(raw$loadings, 2)
#'
#' # Varimax rotation: traits 4-6 now load on one axis and traits 2-3 on
#' # the other, with trait_1 shared between them.
#' rot <- rotate_loadings(fit, level = "unit", method = "varimax")
#' round(rot$Lambda, 2)
#'
#' # Rotation only turns the axes. The scores turn with them, so each
#' # unit's latent contribution (scores times loadings) is unchanged.
#' head(round(rot$scores, 2))
#' all.equal(rot$scores %*% t(rot$Lambda),
#'           raw$scores %*% t(raw$loadings))
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
    .gllvmTMB_abort_not_multi_fit(fit)
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
#' Scope: covered for fitted `latent()` components at `level = "unit"` or
#' `level = "unit_obs"` with raw or standardized point-estimate loadings.
#' This table does not attach uncertainty intervals to loadings. Bootstrap
#' or simulation-based uncertainty is not yet implemented and remains
#' possible future work for a later inference slice.
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
#' set.seed(1)
#' # Simulate six traits, each measured twice on 100 units (e.g. sites).
#' # Traits 2-3 share one latent axis, traits 4-6 share a second axis,
#' # and trait_1 loads on both.
#' Lambda <- cbind(c(0.7, 1.0, 0.9, 0.0, 0.0, 0.0),
#'                 c(0.7, 0.0, 0.0, 1.0, 0.9, 0.8))
#' sim <- simulate_unit_trait(n_units = 100, n_obs_per_unit = 2,
#'                            n_traits = 6, Lambda_B = Lambda,
#'                            psi_B = 0.4, sigma2_eps = 0.3)
#' fit <- gllvmTMB(value ~ 0 + trait +
#'                   latent(0 + trait | unit, d = 2, unique = TRUE),
#'                 data = sim$data, trait = "trait", unit = "unit")
#'
#' # One row per trait and axis after varimax rotation. axis_share is the
#' # share of the shared (latent) variance carried by each axis.
#' tab <- extract_rotated_loadings_table(fit, level = "unit")
#' print(tab[, c("trait", "axis", "loading", "axis_share", "anchor_trait")],
#'       digits = 2)
#'
#' # Standardized loadings divide by each trait's total between-unit
#' # standard deviation, so traits on different scales are comparable.
#' std <- extract_rotated_loadings_table(fit, level = "unit",
#'                                       loading_scale = "standardized")
#' # The tidy layout makes filtering easy: the strong loadings per axis.
#' print(std[std$abs_loading > 0.5, c("axis", "trait", "loading")],
#'       digits = 2)
#' # Or reshape it back to a trait-by-axis grid.
#' round(xtabs(loading ~ trait + axis, data = std), 2)
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
#' set.seed(1)
#' # Simulate six traits, each measured twice on 100 units, from known
#' # loadings: traits 2-3 share one axis, traits 4-6 a second, and
#' # trait_1 loads on both.
#' Lambda_true <- cbind(c(0.7, 1.0, 0.9, 0.0, 0.0, 0.0),
#'                      c(0.7, 0.0, 0.0, 1.0, 0.9, 0.8))
#' sim <- simulate_unit_trait(n_units = 100, n_obs_per_unit = 2,
#'                            n_traits = 6, Lambda_B = Lambda_true,
#'                            psi_B = 0.4, sigma2_eps = 0.3)
#' fit <- gllvmTMB(value ~ 0 + trait +
#'                   latent(0 + trait | unit, d = 2, unique = TRUE),
#'                 data = sim$data, trait = "trait", unit = "unit")
#' L_hat <- extract_ordination(fit, "unit")$loadings
#'
#' # The fitted axes may be rotated or sign-flipped relative to the true
#' # ones, so compare_loadings() first rotates the fitted loadings to
#' # match the truth as closely as possible, then measures the gap.
#' cmp <- compare_loadings(L_hat, Lambda_true)
#' # Fitted loadings after alignment; compare them with Lambda_true.
#' round(cmp$Lambda_a_rot, 2)
#' # Overall distance after alignment, and per-axis correlation.
#' round(cmp$frobenius, 3)
#' round(cmp$cor_per_factor, 3)
#'
#' # Raw and varimax-rotated loadings from one fit differ only by a
#' # rotation, so once aligned they match exactly (distance 0).
#' L_rot <- rotate_loadings(fit, level = "unit")$Lambda
#' round(compare_loadings(L_rot, L_hat)$frobenius, 6)
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
