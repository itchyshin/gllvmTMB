## gllvm-style output methods for `gllvmTMB_multi` fits.
##
## These mirror the accessors / plot helpers users coming from the
## `gllvm` package expect: getLoadings(), getLV(), getResidualCov(),
## getResidualCor(), and ordiplot(). Wrappers around the existing
## extractors so the API surface matches the canonical GLLVM
## software while keeping our internals long-format.

#' Loadings matrix from a `gllvmTMB_multi` fit
#'
#' Wraps [extract_ordination()] for users coming from `gllvm::getLoadings()`.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param level `"B"` (global / between-site) or `"W"` (local / within-site).
#' @param rotate Optional `"varimax"` or `"promax"` post-hoc rotation.
#'   Default `"none"` returns the engine's native lower-triangular Λ.
#' @return An `n_traits × d` numeric matrix.
#' @seealso [extract_ordination()] for the canonical interface that
#'   returns scores and loadings together.
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' getLoadings(fit, level = "B", rotate = "varimax")
#' }
getLoadings <- function(fit,
                        level  = c("unit", "unit_obs", "B", "W"),
                        rotate = c("none", "varimax", "promax")) {
  level  <- match.arg(level)
  level  <- .normalise_level(level, arg_name = "level")
  rotate <- match.arg(rotate)
  ## Surface a one-shot rotation hint when the user accesses RAW Lambda
  ## (rotate = "none") on an unconstrained rr() fit with rank > 1. Sigma_B is
  ## still identifiable; Lambda alone is not.
  if (rotate == "none") {
    advisory <- isTRUE(fit$needs_rotation_advice[[level]])
    shown    <- isTRUE(attr(fit, ".rotation_hint_shown")[[level]])
    if (advisory && !shown) {
      cli::cli_inform(c(
        "i" = "{.code Lambda_{level}} is identified only up to rotation (d_{level} = {fit[[paste0('d_', level)]]}).",
        "*" = "Use {.code rotate = \"varimax\"} for a quick post-hoc rotation, or",
        "*" = "see {.fn suggest_lambda_constraint} for a default {.arg lambda_constraint} matrix to pass to a refit.",
        "*" = "{.fn extract_Sigma_{level}} is rotation-invariant and does not need this."
      ))
    }
  }
  ord <- extract_ordination(fit, level = level)
  if (is.null(ord)) return(NULL)
  if (rotate == "none") return(ord$loadings)
  rotate_loadings(fit, level, rotate)$Lambda
}

#' Latent-variable scores from a `gllvmTMB_multi` fit
#'
#' Wraps [extract_ordination()]'s `$scores` for users coming from
#' `gllvm::getLV()`.
#'
#' @inheritParams getLoadings
#' @return A matrix with one row per unit (level "B") or one row per
#'   within-unit observation (level "W"), and one column per latent factor.
#' @seealso [extract_ordination()] for the canonical interface.
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' getLV(fit, level = "B")
#' }
getLV <- function(fit,
                  level  = c("unit", "unit_obs", "B", "W"),
                  rotate = c("none", "varimax", "promax")) {
  level  <- match.arg(level)
  level  <- .normalise_level(level, arg_name = "level")
  rotate <- match.arg(rotate)
  ord <- extract_ordination(fit, level = level)
  if (is.null(ord)) return(NULL)
  if (rotate == "none") return(ord$scores)
  rotate_loadings(fit, level, rotate)$scores
}

#' Implied residual covariance / correlation matrix
#'
#' \eqn{\Sigma_X = \Lambda_X \Lambda_X^\top + \mathrm{diag}(s_X^2)} for
#' `level = "B"` or `"W"`. `getResidualCor` returns the corresponding
#' correlation matrix. Useful diagnostic when comparing the global vs
#' local trait covariance.
#'
#' @inheritParams getLoadings
#' @return An `n_traits × n_traits` matrix.
#' @seealso [extract_Sigma()] — the canonical unified API for
#'   between-/within-/phylogenetic Sigma at any tier.
#' @keywords internal
#' @export
getResidualCov <- function(fit, level = c("unit", "unit_obs", "B", "W")) {
  level <- match.arg(level)
  level <- .normalise_level(level, arg_name = "level")
  out <- if (level == "B") extract_Sigma_B(fit) else extract_Sigma_W(fit)
  if (is.null(out)) return(NULL)
  if (level == "B") out$Sigma_B else out$Sigma_W
}

#' @rdname getResidualCov
#' @keywords internal
#' @export
getResidualCor <- function(fit, level = c("unit", "unit_obs", "B", "W")) {
  level <- match.arg(level)
  level <- .normalise_level(level, arg_name = "level")
  out <- if (level == "B") extract_Sigma_B(fit) else extract_Sigma_W(fit)
  if (is.null(out)) return(NULL)
  if (level == "B") out$R_B else out$R_W
}


#' Two-axis ordination plot of a `gllvmTMB_multi` fit
#'
#' A simple base-R biplot of the latent scores, with optional trait
#' loadings overlaid. Mirrors `gllvm::ordiplot()` for users migrating
#' from that package.
#'
#' This is an S3 generic so that dispatch is robust to load order with
#' the `gllvm` package — `gllvm::ordiplot` is itself an S3 generic, and
#' if it is loaded after `gllvmTMB` it masks our function. With S3
#' methods registered, either generic correctly routes a multi-response
#' fit through `ordiplot.gllvmTMB_multi`.
#'
#' @param fit A `gllvmTMB` (single-response) or `gllvmTMB_multi` fit.
#' @param level `"unit"` / `"B"` (between-unit) or `"unit_obs"` / `"W"`
#'   (within-unit).
#' @param axes Length-2 integer vector picking which two latent axes
#'   to plot. Default `c(1, 2)`.
#' @param biplot Logical; if `TRUE`, overlay scaled trait loadings as
#'   arrows (default `TRUE`).
#' @param rotate Post-hoc rotation: `"none"` (default), `"varimax"`, or
#'   `"promax"`.
#' @param ... Passed to `plot()`.
#' @seealso [plot.gllvmTMB_multi()] for the canonical S3 plot interface.
#' @keywords internal
#' @export
#' @rawNamespace if (requireNamespace("gllvm", quietly = TRUE)) S3method(gllvm::ordiplot, gllvmTMB_multi)
ordiplot <- function(fit, ...) {
  UseMethod("ordiplot")
}

#' @rdname ordiplot
#' @keywords internal
#' @export
ordiplot.gllvmTMB_multi <- function(fit,
                                    level  = c("unit", "unit_obs", "B", "W"),
                                    axes   = c(1, 2),
                                    biplot = TRUE,
                                    rotate = c("none", "varimax", "promax"),
                                    ...) {
  level  <- match.arg(level)
  level  <- .normalise_level(level, arg_name = "level")
  rotate <- match.arg(rotate)
  if (length(axes) != 2L)
    cli::cli_abort("axes must be length 2.")

  scores   <- getLV(fit, level, rotate)
  loadings <- getLoadings(fit, level, rotate)
  if (is.null(scores) || ncol(scores) < max(axes))
    cli::cli_abort("Not enough latent axes for the requested {.code axes}.")

  rng <- function(x) range(x, na.rm = TRUE)
  xs <- scores[, axes[1L]]
  ys <- scores[, axes[2L]]

  graphics::plot(xs, ys,
       xlab = paste0("LV", axes[1L]),
       ylab = paste0("LV", axes[2L]),
       pch = 19, col = "grey40", asp = 1, ...)
  graphics::abline(h = 0, v = 0, lty = 2, col = "grey80")

  if (isTRUE(biplot) && !is.null(loadings) && ncol(loadings) >= max(axes)) {
    sc <- max(abs(rng(xs)), abs(rng(ys))) /
          max(abs(loadings[, axes]), 1e-9) * 0.7
    arrows_x <- loadings[, axes[1L]] * sc
    arrows_y <- loadings[, axes[2L]] * sc
    graphics::arrows(0, 0, arrows_x, arrows_y, length = 0.08,
                     col = "tomato", lwd = 1.5)
    graphics::text(arrows_x * 1.1, arrows_y * 1.1,
                   labels = rownames(loadings),
                   col = "tomato", cex = 0.85)
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
#' Gaussian residual.
#'
#' Mirrors `gllvm::VP()` / `gllvm::plotVP()`.
#'
#' @param fit A `gllvmTMB_multi` fit.
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
  if (fit$use$diag_B)
    comps$diag_B <- as.numeric(fit$report$sd_B)^2
  if (fit$use$rr_W) {
    LL_W <- fit$report$Lambda_W %*% t(fit$report$Lambda_W)
    comps$rr_W <- diag(LL_W)
  }
  if (fit$use$diag_W)
    comps$diag_W <- as.numeric(fit$report$sd_W)^2
  if (fit$use$diag_species)
    comps$diag_species <- as.numeric(fit$report$sd_q)^2
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
  ## Add Gaussian residual
  comps$residual <- rep(as.numeric(fit$report$sigma_eps)^2, fit$n_traits)

  M <- do.call(cbind, comps)
  rownames(M) <- levels(fit$data[[fit$trait_col]])
  M / rowSums(M)
}
