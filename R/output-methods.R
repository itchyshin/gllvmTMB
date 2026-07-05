## gllvm-style output methods for multivariate gllvmTMB fits.
##
## These mirror the accessors / plot helpers users coming from the
## `gllvm` package expect: getLoadings(), getLV(), getResidualCov(),
## getResidualCor(), and ordiplot(). Wrappers around the existing
## extractors so the API surface matches the canonical GLLVM
## software while keeping our internals long-format.

#' Extract the loading matrix from a fitted multivariate model
#'
#' Returns the trait loading matrix from a fit returned by [gllvmTMB()]. This
#' is a small compatibility wrapper around [extract_ordination()] for readers
#' familiar with `gllvm::getLoadings()`.
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()]. Admitted
#'   `engine = "julia"` bridge fits expose raw unit-tier loadings and scores;
#'   rotated ordinations remain gated for Julia bridge fits.
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Deprecated aliases `"B"` and `"W"` are still accepted with a warning.
#' @param rotate Optional `"varimax"` or `"promax"` rotation after fitting.
#'   Default `"none"` returns the engine's native lower-triangular Lambda.
#'   For Julia bridge fits only `"none"` is currently routed.
#' @return An `n_traits × d` numeric matrix.
#' @seealso [extract_ordination()] for the row-and-column interface that
#'   returns scores and loadings together.
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' getLoadings(fit, level = "unit", rotate = "varimax")
#' }
getLoadings <- function(
  fit,
  level = "unit",
  rotate = c("none", "varimax", "promax")
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  rotate <- match.arg(rotate)
  if (inherits(fit, "gllvmTMB_julia") && rotate != "none") {
    cli::cli_abort(
      "engine = 'julia': rotated loadings are not routed yet; use {.code rotate = \"none\"} or engine = 'tmb'."
    )
  }
  ## Surface a one-shot rotation hint when the user accesses RAW Lambda
  ## (rotate = "none") on an unconstrained rr() fit with rank > 1. Sigma_B is
  ## still identifiable; Lambda alone is not.
  if (rotate == "none") {
    advisory <- isTRUE(fit$needs_rotation_advice[[level]])
    shown <- isTRUE(attr(fit, ".rotation_hint_shown")[[level]])
    if (advisory && !shown) {
      cli::cli_inform(c(
        "i" = "{.code Lambda_{level}} is identified only up to rotation (d_{level} = {fit[[paste0('d_', level)]]}).",
        "*" = "Use {.code rotate = \"varimax\"} for a quick rotation after fitting, or",
        "*" = "see {.fn suggest_lambda_constraint} for a default {.arg lambda_constraint} matrix to pass to a refit.",
        "*" = "{.fn extract_Sigma_{level}} is rotation-invariant and does not need this."
      ))
    }
  }
  ord <- extract_ordination(fit, level = .canonical_level_name(level))
  if (is.null(ord)) {
    return(NULL)
  }
  if (rotate == "none") {
    return(ord$loadings)
  }
  rotate_loadings(fit, .canonical_level_name(level), rotate)$Lambda
}

#' Extract latent-variable scores from a fitted multivariate model
#'
#' Returns latent scores from a fit returned by [gllvmTMB()]. This is a small
#' compatibility wrapper around [extract_ordination()] for readers familiar
#' with `gllvm::getLV()`.
#'
#' @inheritParams getLoadings
#' @return A matrix with one row per unit (`level = "unit"`) or one row per
#'   within-unit observation (`level = "unit_obs"`), and one column per
#'   latent factor.
#' @seealso [extract_ordination()] for scores and loadings together.
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' getLV(fit, level = "unit")
#' }
getLV <- function(
  fit,
  level = "unit",
  rotate = c("none", "varimax", "promax")
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  rotate <- match.arg(rotate)
  if (inherits(fit, "gllvmTMB_julia") && rotate != "none") {
    cli::cli_abort(
      "engine = 'julia': rotated latent scores are not routed yet; use {.code rotate = \"none\"} or engine = 'tmb'."
    )
  }
  ord <- extract_ordination(fit, level = .canonical_level_name(level))
  if (is.null(ord)) {
    return(NULL)
  }
  if (rotate == "none") {
    return(ord$scores)
  }
  rotate_loadings(fit, .canonical_level_name(level), rotate)$scores
}

#' Extract implied trait covariance or correlation
#'
#' Returns the implied trait covariance at `level = "unit"` or
#' `level = "unit_obs"`. For a reduced-rank plus unique tier this is
#' \eqn{\Sigma_X = \Lambda_X \Lambda_X^\top + \Psi_X}. `getResidualCor()`
#' returns the corresponding correlation matrix.
#'
#' @inheritParams getLoadings
#' @return An `n_traits × n_traits` matrix.
#' @seealso [extract_Sigma()] — the canonical unified API for
#'   between-/within-/phylogenetic Sigma at any tier.
#' @keywords internal
#' @export
getResidualCov <- function(fit, level = "unit") {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  out <- if (level == "B") extract_Sigma_B(fit) else extract_Sigma_W(fit)
  if (is.null(out)) {
    return(NULL)
  }
  if (level == "B") out$Sigma_B else out$Sigma_W
}

#' @rdname getResidualCov
#' @keywords internal
#' @export
getResidualCor <- function(fit, level = "unit") {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  out <- if (level == "B") extract_Sigma_B(fit) else extract_Sigma_W(fit)
  if (is.null(out)) {
    return(NULL)
  }
  if (level == "B") out$R_B else out$R_W
}


#' Draw a two-axis ordination plot for a fitted multivariate model
#'
#' Draws a simple base-R biplot of latent scores, with optional trait loadings
#' overlaid, for a fit returned by [gllvmTMB()]. This method is a compatibility
#' surface for users familiar with `gllvm::ordiplot()`; the package's richer
#' ggplot-based model plots are available through `plot(fit, type = ...)`.
#'
#' This is an S3 generic so that dispatch is robust to load order with
#' the `gllvm` package — `gllvm::ordiplot` is itself an S3 generic, and
#' if it is loaded after `gllvmTMB` it masks our function. With S3
#' methods registered, either generic correctly routes a multi-response
#' fit through the gllvmTMB ordination method.
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()].
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Deprecated aliases `"B"` and `"W"` are still accepted with a warning.
#' @param axes Length-2 integer vector picking which two latent axes
#'   to plot. Default `c(1, 2)`.
#' @param biplot Logical; if `TRUE`, overlay scaled trait loadings as
#'   arrows (default `TRUE`).
#' @param rotate Rotation after fitting: `"none"` (default), `"varimax"`, or
#'   `"promax"`.
#' @param ... Passed to `plot()`.
#' @seealso [plot.gllvmTMB_multi()] for the available `type` choices.
#' @keywords internal
#' @export
#' @rawNamespace if (requireNamespace("gllvm", quietly = TRUE)) S3method(gllvm::ordiplot, gllvmTMB_multi)
ordiplot <- function(fit, ...) {
  UseMethod("ordiplot")
}

#' @rdname ordiplot
#' @keywords internal
#' @export
ordiplot.gllvmTMB_multi <- function(
  fit,
  level = "unit",
  axes = c(1, 2),
  biplot = TRUE,
  rotate = c("none", "varimax", "promax"),
  ...
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  canonical_level <- .canonical_level_name(level)
  rotate <- match.arg(rotate)
  if (length(axes) != 2L) {
    cli::cli_abort("axes must be length 2.")
  }

  scores <- getLV(fit, canonical_level, rotate)
  loadings <- getLoadings(fit, canonical_level, rotate)
  if (is.null(scores) || ncol(scores) < max(axes)) {
    cli::cli_abort("Not enough latent axes for the requested {.code axes}.")
  }

  rng <- function(x) range(x, na.rm = TRUE)
  xs <- scores[, axes[1L]]
  ys <- scores[, axes[2L]]

  graphics::plot(
    xs,
    ys,
    xlab = paste0("LV", axes[1L]),
    ylab = paste0("LV", axes[2L]),
    pch = 19,
    col = "grey40",
    asp = 1,
    ...
  )
  graphics::abline(h = 0, v = 0, lty = 2, col = "grey80")

  if (isTRUE(biplot) && !is.null(loadings) && ncol(loadings) >= max(axes)) {
    sc <- max(abs(rng(xs)), abs(rng(ys))) /
      max(abs(loadings[, axes]), 1e-9) *
      0.7
    arrows_x <- loadings[, axes[1L]] * sc
    arrows_y <- loadings[, axes[2L]] * sc
    graphics::arrows(
      0,
      0,
      arrows_x,
      arrows_y,
      length = 0.08,
      col = "tomato",
      lwd = 1.5
    )
    graphics::text(
      arrows_x * 1.1,
      arrows_y * 1.1,
      labels = rownames(loadings),
      col = "tomato",
      cex = 0.85
    )
  }
  invisible(list(scores = scores, loadings = loadings))
}


#' Variance partition by source
#'
#' Decomposes the marginal trait variance into contributions from each
#' active component of the model: between-unit shared (`latent_B`),
#' between-unit unique (`unique_B`), within-unit shared (`latent_W`),
#' within-unit unique (`unique_W`), phylogenetic (`phylo_scalar` /
#' `phylo_latent`), non-phylogenetic species, spatial (`spatial`), and
#' Gaussian/lognormal observation residual where present. Non-Gaussian
#' link-implicit residual shares are handled by [extract_proportions()].
#'
#' Mirrors `gllvm::VP()` / `gllvm::plotVP()`.
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()].
#' @return An `n_traits × n_components` matrix of variance shares (rows
#'   sum to 1). Columns are only those active in `fit$use`.
#'
#' @seealso [extract_proportions()] for the canonical per-trait
#'   variance-share decomposition with explicit B / W / phy / link-residual
#'   columns.
#' @keywords internal
#' @export
VP <- function(fit) {
  comps <- list()
  if (fit$use$rr_B) {
    LL_B <- fit$report$Lambda_B %*% t(fit$report$Lambda_B)
    comps$rr_B <- diag(LL_B)
  }
  if (fit$use$diag_B) {
    comps$diag_B <- as.numeric(fit$report$sd_B)^2
  }
  if (fit$use$rr_W) {
    LL_W <- fit$report$Lambda_W %*% t(fit$report$Lambda_W)
    comps$rr_W <- diag(LL_W)
  }
  if (fit$use$diag_W) {
    comps$diag_W <- as.numeric(fit$report$sd_W)^2
  }
  if (fit$use$diag_species) {
    comps$diag_species <- as.numeric(fit$report$sd_q)^2
  }
  if (isTRUE(fit$use$phylo_rr)) {
    LL_phy <- fit$report$Lambda_phy %*% t(fit$report$Lambda_phy)
    comps$phylo_rr <- diag(LL_phy)
  }
  if (isTRUE(fit$use$phylo_diag)) {
    comps$phylo_diag <- as.numeric(fit$report$sd_phy_diag)^2
  }
  if (fit$use$propto) {
    ## Approximate per-trait phylogenetic variance contribution: lambda_phy
    lam <- exp(unname(fit$opt$par["loglambda_phy"]))
    comps$propto <- rep(lam, fit$n_traits)
  }
  ## Add only the legacy observation-scale residual represented by sigma_eps.
  ## For non-Gaussian families, the legacy sigma_eps component is not the
  ## canonical latent-scale residual; extract_proportions() is the
  ## family-aware variance-share helper.
  residual_var <- .vp_residual_per_trait(fit)
  if (any(residual_var > 0)) {
    comps$residual <- residual_var
  }

  if (length(comps) == 0L) {
    trait_names <- levels(fit$data[[fit$trait_col]])
    return(matrix(
      numeric(0),
      nrow = fit$n_traits,
      ncol = 0L,
      dimnames = list(trait_names, character(0))
    ))
  }

  M <- do.call(cbind, comps)
  rownames(M) <- levels(fit$data[[fit$trait_col]])
  M / rowSums(M)
}

.vp_residual_per_trait <- function(fit) {
  trait_names <- levels(fit$data[[fit$trait_col]])
  Tn <- length(trait_names)
  out <- numeric(Tn)
  names(out) <- trait_names

  sigma_eps <- as.numeric(fit$report$sigma_eps %||% numeric(0))
  if (!length(sigma_eps) || !is.finite(sigma_eps[1L]) || sigma_eps[1L] <= 0) {
    return(out)
  }

  fids <- fit$tmb_data$family_id_vec %||% rep(0L, Tn)
  tids <- fit$tmb_data$trait_id %||% (seq_along(fids) - 1L)
  tids_obs <- as.integer(tids) + 1L

  for (t in seq_len(Tn)) {
    rows_t <- which(tids_obs == t)
    if (!length(rows_t)) next
    fams_t <- fids[rows_t]
    fams_t <- fams_t[is.finite(fams_t)]
    if (!length(fams_t)) next
    fams_uniq <- unique(as.integer(fams_t))
    tab <- tabulate(match(as.integer(fams_t), fams_uniq))
    fid <- fams_uniq[which.max(tab)]
    if (fid %in% c(0L, 3L)) {
      out[t] <- sigma_eps[1L]^2
    }
  }
  out
}
