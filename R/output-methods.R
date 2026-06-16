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
#' @param fit A fitted multivariate model returned by [gllvmTMB()].
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Deprecated aliases `"B"` and `"W"` are still accepted with a warning.
#' @param rotate Optional `"varimax"` or `"promax"` rotation after fitting.
#'   Default `"none"` returns the engine's native lower-triangular Λ.
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
#' For Julia-engine bridge fits the payload carries a single shared loading
#' block \eqn{\Lambda}, so `level = "unit"` returns the implied between-trait
#' covariance \eqn{\Sigma_B = \Lambda \Lambda^\top} (a point quantity). At
#' `level = "unit_obs"` only Gaussian bridge fits carry a residual scale
#' (\eqn{\sigma_\epsilon^2 I}); other families error because the within-unit
#' residual covariance is not defined on the bridge payload.
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
  if (inherits(fit, "gllvmTMB_julia")) {
    out <- .gllvm_julia_residual_sigma(fit, level)
    if (is.null(out)) {
      return(NULL)
    }
    return(out$Sigma)
  }
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
  if (inherits(fit, "gllvmTMB_julia")) {
    out <- .gllvm_julia_residual_sigma(fit, level)
    if (is.null(out)) {
      return(NULL)
    }
    return(out$R)
  }
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
#' @rawNamespace if (requireNamespace("gllvm", quietly = TRUE)) S3method(gllvm::ordiplot, gllvmTMB_julia)
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
  rotate <- match.arg(rotate)
  if (length(axes) != 2L) {
    cli::cli_abort("axes must be length 2.")
  }

  level_label <- .canonical_level_name(level)
  scores <- getLV(fit, level_label, rotate)
  loadings <- getLoadings(fit, level_label, rotate)
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

#' @rdname ordiplot
#' @keywords internal
#' @export
ordiplot.gllvmTMB_julia <- ordiplot.gllvmTMB_multi


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
  ## Add Gaussian residual
  comps$residual <- rep(as.numeric(fit$report$sigma_eps)^2, fit$n_traits)

  M <- do.call(cbind, comps)
  rownames(M) <- levels(fit$data[[fit$trait_col]])
  M / rowSums(M)
}

#' Per-trait response families of a fitted multivariate model
#'
#' Returns the response family of every trait in a fit returned by
#' [gllvmTMB()]. For a mixed-family fit (built by passing a named or
#' selector-driven `family` list) the returned vector reports the family
#' assigned to each trait; for a single-family fit every trait shares the
#' one family. This complements [stats::family()] (singular), which returns
#' the one `family` object retained on the fit.
#'
#' This is a pure accessor: it reads fields already stored on the fit
#' (`family_selector` / the per-row family ids) and does not refit. The
#' name `trait_families` is used rather than `families` because the latter
#' help topic is already taken by the family constructors (see
#' [Families][gllvmTMB::Families]).
#'
#' @param object A fitted multivariate model returned by [gllvmTMB()].
#' @param ... Currently unused; present for S3 generic compatibility.
#' @return A named character vector of length `n_traits`, one canonical
#'   family name per trait, named by the trait levels in trait-factor order.
#' @seealso [stats::family()] for the single retained family object;
#'   the per-trait family is also shown by `print()` for mixed-family fits.
#' @export
#' @examples
#' \dontrun{
#' # Mixed-family fit (one trait gaussian, one poisson, ...):
#' trait_families(fit)
#' #>      trait_1      trait_2      trait_3
#' #>   "gaussian"   "binomial"    "poisson"
#' }
trait_families <- function(object, ...) {
  UseMethod("trait_families")
}

#' @rdname trait_families
#' @export
trait_families.gllvmTMB_multi <- function(object, ...) {
  n_traits <- as.integer(object$n_traits %||% 0L)
  trait_names <- levels(object$data[[object$trait_col]])
  ## Primary path: a stored family_selector marks a mixed-family fit, so
  ## report the per-trait family resolved from the stored per-row ids.
  if (!is.null(object$family_selector)) {
    return(.per_trait_family(object))
  }
  ## Fallback: single / uniform family — every trait shares object$family.
  fam <- object$family$family %||% NA_character_
  out <- rep(as.character(fam)[1L], n_traits)
  names(out) <- trait_names
  out
}
