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
#' familiar with `gllvm::getLoadings()`. The canonical snake_case spelling in
#' this package is [extract_loadings()], which forwards here.
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

#' Extract the trait loading matrix
#'
#' Returns the trait loading matrix from a fit returned by [gllvmTMB()]. This is
#' the canonical snake_case accessor in the `extract_*()` family; [getLoadings()]
#' is an accepted compatibility spelling for readers coming from `gllvm`. Both
#' return the same matrix.
#'
#' @inheritParams getLoadings
#' @return An `n_traits x d` numeric matrix.
#' @seealso [extract_ordination()] for scores and loadings together;
#'   [getLoadings()] for the `gllvm`-style spelling.
#' @export
#' @examples
#' \dontrun{
#' extract_loadings(fit, level = "unit", rotate = "varimax")
#' }
extract_loadings <- function(
  fit,
  level = "unit",
  rotate = c("none", "varimax", "promax")
) {
  rotate <- match.arg(rotate)
  getLoadings(fit, level = level, rotate = rotate)
}

#' Extract latent-variable scores from a fitted multivariate model
#'
#' Returns latent scores from a fit returned by [gllvmTMB()]. This is a small
#' compatibility wrapper around [extract_ordination()] for readers familiar
#' with `gllvm::getLV()`.
#'
#' @inheritParams getLoadings
#' @param se Logical; if `TRUE`, also return uncertainty for every latent score:
#'   a frequentist standard error for an ordinary Laplace fit, or a variational
#'   posterior SD for a `gllvmTMB_va` fit. Default `FALSE`, which preserves the
#'   original behaviour (a bare matrix). See the Score uncertainty section.
#' @return When `se = FALSE` (default): a matrix with one row per unit
#'   (`level = "unit"`) or one row per within-unit observation
#'   (`level = "unit_obs"`), and one column per latent factor. When
#'   `se = TRUE`: a list with `scores` (that same matrix) and `se` (a matrix
#'   of identical shape and dimnames holding the score uncertainty described
#'   below).
#'
#' @section Score uncertainty:
#' For an ordinary Laplace fit, `se = TRUE` reads the marginal standard error
#' of every unit-level (or
#' within-unit) latent-score random effect -- `z_B` at `level = "unit"`,
#' `z_W` at `level = "unit_obs"` -- from the fit's TMB `sdreport()`
#' (`sqrt(sd_report$diag.cov.random)`), and reshapes it with the identical
#' `matrix(..., nrow = d, ncol = n)` then transpose convention that
#' [extract_ordination()] uses for the point estimates, so `scores[i, k]`
#' and `se[i, k]` always refer to the same (unit, axis) cell. This value is
#' mathematically equivalent to inverting the fit's full joint precision
#' matrix (`TMB::sdreport(getJointPrecision = TRUE)`) and reading the
#' diagonal of the same block; the two routes were verified to agree to
#' machine precision during development. Requirements:
#' \itemize{
#'   \item The fit must carry a valid `sdreport()`
#'     (`gllvmTMBcontrol(se = TRUE)`, the default) with a positive-definite
#'     Hessian; otherwise `se = TRUE` raises an error (no `sdreport`) or a
#'     warning with `NA` standard errors (non-positive-definite Hessian).
#'   \item `rotate` must be `"none"`: rotating scores changes their
#'     covariance, which is not currently propagated, so `se = TRUE` together
#'     with `rotate != "none"` raises an error rather than silently pairing
#'     rotated scores with un-rotated standard errors.
#'   \item Predictor-informed `latent(..., lv = ~ x)` fits at `level =
#'     "unit"` are not yet supported (the score mean's own uncertainty is
#'     not yet propagated) and raise an error.
#'   \item `engine = "julia"` bridge fits are not yet supported and raise an
#'     error.
#' }
#'
#' For loading-ridge fits, score SDs require matching retained
#' penalised-curvature metadata. They are local posterior approximations
#' conditional on the ridge scale. Older or mismatched reports raise a warning
#' and return `NA` SDs, while preserving the score point estimates.
#'
#' For a `gllvmTMB_va` (variational) fit, `se` is instead the per-unit
#' **variational posterior SD** read from the fit's own variational
#' distribution at its optimum -- not a Wald standard error, and not
#' calibrated (the returned matrix carries a
#' `"uncertainty_basis"` and `"calibrated"` attribute making this explicit in
#' the object itself, not only here -- though those attributes are silently
#' dropped by `se[i, ]`, `head(se)` and `as.data.frame(se)`).
#'
#' Two independent gates restrict it. **By tier**, an explicitly requested
#' `"jj"` (Jaakkola-Jordan) fit is refused pending its own measurement.
#' **By mechanism**, any fit whose per-unit SD turns out to be
#' constant across units is refused outright: the array would carry one row
#' per unit while containing no per-unit information. That degeneracy is
#' provable under `"ac"` (Albert-Chib) and was *measured* on a Gaussian fit
#' (coefficient of variation 1.6e-15) which the tier gate alone did not
#' catch.
#'
#' @seealso [extract_ordination()] for scores and loadings together.
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' getLV(fit, level = "unit")
#' getLV(fit, level = "unit", se = TRUE)
#' }
getLV <- function(
  fit,
  level = "unit",
  rotate = c("none", "varimax", "promax"),
  se = FALSE
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  rotate <- match.arg(rotate)
  if (isTRUE(se) && inherits(fit, "gllvmTMB_multi")) {
    .gllvmTMB_require_unweighted_inference(fit, "getLV(se = TRUE)")
  }
  if (inherits(fit, "gllvmTMB_julia") && rotate != "none") {
    cli::cli_abort(
      "engine = 'julia': rotated latent scores are not routed yet; use {.code rotate = \"none\"} or engine = 'tmb'."
    )
  }
  if (isTRUE(se) && inherits(fit, "gllvmTMB_julia")) {
    cli::cli_abort(c(
      "engine = 'julia': {.code se = TRUE} is not available for bridge fits.",
      "i" = "Bridge fits do not carry a native TMB {.fn sdreport}; use {.code se = FALSE} for point estimates."
    ), class = "gllvmTMB_getLV_se_julia_unsupported")
  }
  if (isTRUE(se)) {
    .gllvmTMB_mspl_assert_inference(fit, "getLV(se = TRUE)")
  }
  if (isTRUE(se) && rotate != "none") {
    cli::cli_abort(c(
      "{.code se = TRUE} is not supported together with {.code rotate != \"none\"}.",
      "i" = "Rotating scores changes their covariance, which {.fn getLV} does not currently propagate.",
      ">" = "Request {.code rotate = \"none\", se = TRUE} for standard errors, or {.code rotate = \"varimax\"}/{.code \"promax\"} with {.code se = FALSE} for rotated point estimates."
    ), class = "gllvmTMB_getLV_se_rotated_unsupported")
  }
  ord <- extract_ordination(fit, level = .canonical_level_name(level))
  if (is.null(ord)) {
    return(NULL)
  }
  if (!isTRUE(se)) {
    if (rotate == "none") {
      scores <- ord$scores
      if (isTRUE(fit$temporal$active)) {
        attr(scores, "temporal_index") <- ord$row_index
      }
      return(scores)
    }
    scores <- rotate_loadings(fit, .canonical_level_name(level), rotate)$scores
    if (isTRUE(fit$temporal$active)) {
      attr(scores, "temporal_index") <- ord$row_index
    }
    return(scores)
  }
  se_mat <- if (inherits(fit, "gllvmTMB_va")) {
    .va_getLV_se(fit, scores = ord$scores)
  } else {
    .getLV_se(fit, level = level, scores = ord$scores)
  }
  out <- list(scores = ord$scores, se = se_mat)
  if (isTRUE(fit$temporal$active)) {
    attr(out$scores, "temporal_index") <- ord$row_index
    out$temporal_index <- ord$row_index
  }
  out
}

#' Standard error of every unit-level (or within-unit) latent score
#'
#' Internal helper for `getLV(..., se = TRUE)`. Reads the marginal SE of
#' the `z_B` / `z_W` random-effect block from `fit$sd_report` and reshapes
#' it with the same `matrix(nrow = d, ncol = n)` then transpose convention
#' [extract_ordination()] uses for the point estimates, so a misordered
#' reshape here would silently pair the wrong SE with the wrong (unit,
#' axis) score cell. The returned standard-error matrix has the same
#' dimensions and dimnames as the point estimates.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param level Canonical `"B"` or `"W"` (already normalised by the caller).
#' @param scores The `ord$scores` matrix, used only for its `dimnames`.
#' @return A numeric matrix, same shape and dimnames as `scores`.
#' @keywords internal
#' @noRd
.getLV_se <- function(fit, level, scores) {
  if (level == "B" && isTRUE(fit$use$lv_B)) {
    cli::cli_abort(c(
      "{.code se = TRUE} is not yet supported for predictor-informed {.code latent(..., lv = ~ x)} fits.",
      "i" = "The unit-level score mean depends on the fitted {.field alpha_lv_B} coefficients, whose uncertainty is not yet propagated into the score standard error.",
      ">" = "Use {.code se = FALSE} for point estimates."
    ), class = "gllvmTMB_getLV_se_lv_predictor_unsupported")
  }
  sd_rep <- fit$sd_report
  if (is.null(sd_rep)) {
    cli::cli_abort(c(
      "{.code se = TRUE} requires the fit's TMB {.fn sdreport}.",
      "i" = "This fit has no {.field sd_report} ({.code gllvmTMBcontrol(se = FALSE)}, or {.fn sdreport} failed at fitting time).",
      ">" = "Refit with {.code control = gllvmTMBcontrol(se = TRUE)} (the default)."
    ), class = "gllvmTMB_getLV_se_no_sdreport")
  }
  if (isTRUE(fit$aghq$penalised) && !.lv_loading_ridge_curvature_matches(fit)) {
    cli::cli_warn(c(
      "Loading-ridge score uncertainty is withheld because its penalised-curvature provenance is missing or mismatched.",
      "i" = "Returning {.code NA} score standard deviations; point estimates remain available.",
      ">" = "Refit with the current package to retain matching penalised-Hessian metadata."
    ), class = "gllvmTMB_getLV_se_loading_ridge_unverified")
    return(matrix(NA_real_, nrow(scores), ncol(scores), dimnames = dimnames(scores)))
  }
  z_name <- if (level == "B") "z_B" else "z_W"
  d <- if (level == "B") fit$d_B else fit$d_W
  n <- if (level == "B") fit$n_sites else fit$n_site_species
  par_names <- names(sd_rep$par.random)
  idx <- which(par_names == z_name)
  if (length(idx) != d * n) {
    cli::cli_abort(c(
      "Could not locate the {.field {z_name}} random-effect block in {.code sd_report$par.random}.",
      "i" = "Expected {d * n} entries (d = {d}, n = {n}); found {length(idx)}.",
      "i" = "This usually means the fit's {.field sd_report} is stale relative to its {.field tmb_obj}; refit and retry."
    ), class = "gllvmTMB_getLV_se_block_mismatch")
  }
  if (!isTRUE(sd_rep$pdHess)) {
    cli::cli_warn(c(
      "Fit's Hessian is not positive-definite at the optimum.",
      "i" = "Returning {.code NA} standard errors -- Wald inference is unavailable for this fit."
    ))
    se_vec <- rep(NA_real_, d * n)
  } else {
    ## pmax(., 0) guards against floating-point noise producing a
    ## microscopically negative variance for an entry that is truly ~0.
    se_vec <- sqrt(pmax(sd_rep$diag.cov.random[idx], 0))
  }
  se_mat <- t(matrix(se_vec, nrow = d, ncol = n))
  dimnames(se_mat) <- dimnames(scores)
  se_mat
}

#' Extract implied trait covariance or correlation
#'
#' Returns the implied trait covariance at `level = "unit"` or
#' `level = "unit_obs"`. For a reduced-rank plus unique tier this is
#' \eqn{\Sigma_X = \Lambda_X \Lambda_X^\top + \Psi_X}. `getResidualCor()`
#' returns the corresponding correlation matrix. The canonical snake_case
#' spellings in this package are [extract_residual_cov()] and
#' [extract_residual_cor()], which forward here.
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
  out <- .extract_Sigma_legacy_payload(
    fit,
    level = if (level == "B") "unit" else "unit_obs"
  )
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
  out <- .extract_Sigma_legacy_payload(
    fit,
    level = if (level == "B") "unit" else "unit_obs"
  )
  if (is.null(out)) {
    return(NULL)
  }
  if (level == "B") out$R_B else out$R_W
}

#' Implied trait covariance or correlation
#'
#' Canonical snake_case accessors in the `extract_*()` family for the implied
#' trait covariance and correlation at `level = "unit"` or `"unit_obs"`.
#' [getResidualCov()] and [getResidualCor()] are accepted gllvm-compatibility
#' spellings; each pair returns the same matrix.
#'
#' @inheritParams getLoadings
#' @return An `n_traits x n_traits` matrix.
#' @seealso [extract_Sigma()] for the unified Sigma API;
#'   [getResidualCov()] for the `gllvm`-style spellings.
#' @export
extract_residual_cov <- function(fit, level = "unit") {
  getResidualCov(fit, level = level)
}

#' @rdname extract_residual_cov
#' @export
extract_residual_cor <- function(fit, level = "unit") {
  getResidualCor(fit, level = level)
}


#' Draw a one- or two-axis ordination plot for a fitted multivariate model
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
#' @param axes Integer vector selecting one or two distinct latent axes.
#'   When omitted, uses axis 1 for a one-axis fit and `c(1, 2)` otherwise.
#'   A one-axis plot places scores and loading arrows along a horizontal
#'   baseline; its vertical position has no latent-variable meaning.
#' @param biplot Logical; if `TRUE`, overlay scaled trait loadings as
#'   arrows (default `TRUE`).
#' @param rotate Rotation after fitting: `"none"` (default), `"varimax"`, or
#'   `"promax"`.
#' @param ellipse Logical; if `TRUE`, draw an asymptotic-normal score
#'   -uncertainty ellipse around every site, from [ordination_uncertainty()].
#'   Only supported for two-axis plots with `rotate = "none"` (the default) -- see
#'   [ordination_uncertainty()]'s Rotation section for why. The ellipse
#'   level is unmeasured for coverage; it is a standard Wald construction,
#'   not a certified interval.
#' @param ellipse_level Nominal confidence level for the `ellipse` outline
#'   (default `0.95`). Only used when `ellipse = TRUE`.
#' @param ... Passed to `plot()`.
#' @return Invisibly, a list with the plotted `scores` matrix and the
#'   corresponding `loadings` matrix. The function is primarily called for its
#'   plotting side effect.
#' @seealso [plot.gllvmTMB_multi()] for the available `type` choices;
#'   [ordination_uncertainty()] for the covariance `ellipse = TRUE` draws.
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
  ellipse = FALSE,
  ellipse_level = 0.95,
  ...
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  canonical_level <- .canonical_level_name(level)
  rotate <- match.arg(rotate)
  axes_supplied <- !missing(axes)
  if (axes_supplied && (
    !is.numeric(axes) || !length(axes) %in% 1:2 || anyNA(axes) ||
    any(!is.finite(axes)) || any(axes < 1 | axes != trunc(axes)) ||
    anyDuplicated(axes)
  )) {
    cli::cli_abort("axes must be length 1 or length 2, with distinct positive integer indices.")
  }
  if (isTRUE(ellipse) && rotate != "none") {
    cli::cli_abort(c(
      "{.code ellipse = TRUE} is not supported together with {.code rotate != \"none\"}.",
      "i" = "Rotating scores changes their covariance, which {.fn ordination_uncertainty} does not propagate.",
      ">" = "Request {.code rotate = \"none\", ellipse = TRUE} for uncertainty ellipses."
    ), class = "gllvmTMB_ordiplot_ellipse_rotated_unsupported")
  }

  scores <- getLV(fit, canonical_level, rotate)
  loadings <- getLoadings(fit, canonical_level, rotate)
  if (!axes_supplied) axes <- if (!is.null(scores) && ncol(scores) == 1L) 1L else c(1L, 2L)
  if (is.null(scores) || ncol(scores) < max(axes)) {
    cli::cli_abort("Not enough latent axes for the requested {.code axes}.")
  }

  one_axis <- length(axes) == 1L
  if (isTRUE(ellipse) && one_axis) {
    cli::cli_abort(
      c(
        "ellipse = TRUE requires two latent axes; one-axis uncertainty intervals are not supported by ordiplot().",
        ">" = "Use {.code ellipse = FALSE} for a one-axis plot."
      ),
      class = "gllvmTMB_ordiplot_ellipse_one_axis_unsupported"
    )
  }
  rng <- function(x) range(x, na.rm = TRUE)
  xs <- scores[, axes[1L]]
  ys <- if (one_axis) rep(0, nrow(scores)) else scores[, axes[2L]]

  plot_args <- utils::modifyList(
    list(
      x = xs,
      y = ys,
      xlab = paste0("LV", axes[1L]),
      ylab = if (one_axis) "" else paste0("LV", axes[2L]),
      pch = 19,
      col = "grey40",
      asp = if (one_axis) NA else 1,
      yaxt = if (one_axis) "n" else "s"
    ),
    list(...)
  )
  do.call(graphics::plot, plot_args)
  graphics::abline(h = 0, v = 0, lty = 2, col = "grey80")

  if (isTRUE(ellipse)) {
    unc <- ordination_uncertainty(fit, canonical_level)
    if (is.null(unc)) {
      cli::cli_abort(c(
        "{.fn ordination_uncertainty} returned {.code NULL} for {.code level = \"{canonical_level}\"}.",
        ">" = "Request {.code ellipse = FALSE}, or fit a {.fn latent} term at this level."
      ), class = "gllvmTMB_ordiplot_ellipse_no_uncertainty")
    }
    for (s in seq_len(nrow(scores))) {
      mu <- c(xs[s], ys[s])
      Sigma2 <- unc$cov[axes, axes, s]
      if (anyNA(Sigma2)) next
      poly <- .gllvmTMB_ellipse_xy(mu, Sigma2, conf = ellipse_level)
      graphics::lines(poly[, "x"], poly[, "y"], col = "grey40", lwd = 1)
    }
  }

  if (isTRUE(biplot) && !is.null(loadings) && ncol(loadings) >= max(axes)) {
    sc <- max(abs(rng(xs)), abs(rng(ys))) /
      max(abs(loadings[, axes]), 1e-9) *
      0.7
    arrows_x <- loadings[, axes[1L]] * sc
    arrows_y <- if (one_axis) rep(0, nrow(loadings)) else loadings[, axes[2L]] * sc
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
#' Decomposes each trait's variance on the linear-predictor scale into
#' contributions from the active random-effect components of the model and
#' the Gaussian or lognormal observation residual. Column names follow the
#' fitted report blocks: `rr_B`, `diag_B`, `rr_W`, `diag_W`, `diag_species`,
#' `diag_cluster2`, `phylo_rr`, `phylo_diag`, `propto`, one `kernel_<name>`
#' column per term of a fit with several named `kernel_*()` terms, one
#' `re_int_<group>` column per `(1 | group)` random intercept, and `residual`.
#'
#' A `(1 | group)` intercept is a single draw per group level added to every
#' trait, so its column carries the same variance in every row. A `tree =`
#' input is rescaled to unit root-to-tip height, so phylogenetic columns are
#' variances per species. A `vcv =`, `A =`, pedigree or kernel `K =` matrix
#' is used as supplied: when its diagonal is not 1, the column holds the
#' loading variance rather than the per-level variance, and the shares
#' change with the matrix's scale (rescale it to a unit diagonal first, for
#' example with `ape::vcv(tree, corr = TRUE)`).
#'
#' `residual` is the observation variance \eqn{\sigma^2_\varepsilon} of
#' Gaussian and lognormal traits (on the log scale for lognormal). When a
#' diagonal term has one row per observation (an `indep()` term at the
#' observation level, or the default `latent()` Psi when each unit has one
#' observation per trait), the package does not estimate
#' \eqn{\sigma_\varepsilon}: it fixes it at 1/1000 of the standard deviation
#' of all responses pooled on the raw scale. That fixed value is still part
#' of the fitted variance, so it is counted. It is negligible when the traits
#' share a scale, but not when trait scales differ widely or when lognormal
#' responses are large. Non-Gaussian link-implicit residual shares are
#' handled by [extract_proportions()], not by `VP()`.
#'
#' Some active components are not partitioned: random-slope terms (their
#' variance, intercept included, changes with the covariate value),
#' response-column slopes and coefficients (likewise), the known sampling
#' variance of `meta_V()` (it differs by observation), spatial fields (their
#' variance is on the SPDE parameter scale) and temporal states
#' ([extract_temporal()] reports their per-trait variances). `VP()` leaves
#' each of them out, names them in a warning of class
#' `gllvmTMB_vp_component_omitted`, and records them in the
#' `"omitted_components"` attribute of the result. The shares are then
#' proportions of the included components only.
#'
#' `VP()` serves the same purpose as `gllvm::VP()` / `gllvm::plotVP()`, but
#' partitions random-effect and residual variance. Fixed effects, including
#' the predictor part of `latent(..., lv = ~ x)`, are not partitioned.
#'
#'
#' Structured trait-intercept rho fits are excluded; use `extract_Sigma()` and
#' its `source_strength` metadata.
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()].
#' @return An `n_traits × n_components` matrix of variance shares; each row
#'   sums to 1 over the included components (a row whose total is not positive
#'   is `NA`). Columns are only the components active in the fit. When a
#'   component was left out, the `"omitted_components"` attribute names it.
#'
#' @seealso [extract_proportions()] for the canonical per-trait
#'   variance-share decomposition (`shared_unit`, `unique_unit_obs`, phy
#'   tiers, link-residual, etc.).
#' @keywords internal
#' @export
VP <- function(fit) {
  .structured_rho_source_allocation_assert(fit, "VP")
  if (inherits(fit, "gllvmTMB_julia")) {
    .gllvmTMB_abort_not_multi_fit(fit)
  }
  trait_names <- levels(fit$data[[fit$trait_col]])
  Tn <- length(trait_names)
  if (Tn == 0L) {
    .gllvmTMB_abort_not_multi_fit(fit)
  }
  comps <- list()
  omitted <- character(0)
  ## Keep a component only when it is one finite variance per trait. An active
  ## component whose report slot has any other shape is named, not dropped.
  add_comp <- function(name, v, label = name) {
    v <- as.numeric(v)
    if (length(v) != Tn || anyNA(v)) {
      omitted <<- c(omitted, stats::setNames(label, ""))
    } else {
      comps[[name]] <<- v
    }
    invisible(NULL)
  }
  loading_var <- function(L) {
    if (is.null(L)) NULL else rowSums(as.matrix(L)^2)
  }

  if (isTRUE(fit$use$rr_B)) {
    add_comp("rr_B", loading_var(fit$report$Lambda_B))
  }
  if (isTRUE(fit$use$diag_B)) {
    add_comp("diag_B", as.numeric(fit$report$sd_B)^2)
  }
  if (isTRUE(fit$use$rr_W)) {
    add_comp("rr_W", loading_var(fit$report$Lambda_W))
  }
  if (isTRUE(fit$use$diag_W)) {
    add_comp("diag_W", as.numeric(fit$report$sd_W)^2)
  }
  if (isTRUE(fit$use$diag_species)) {
    add_comp("diag_species", as.numeric(fit$report$sd_q)^2)
  }
  if (isTRUE(fit$use$diag_cluster2)) {
    add_comp("diag_cluster2", as.numeric(fit$report$sd_c2)^2)
  }
  if (isTRUE(fit$use$phylo_rr)) {
    add_comp("phylo_rr", loading_var(fit$report$Lambda_phy))
  }
  if (isTRUE(fit$use$phylo_diag)) {
    add_comp("phylo_diag", as.numeric(fit$report$sd_phy_diag)^2)
  }
  if (isTRUE(fit$use$propto)) {
    ## Approximate per-trait phylogenetic variance contribution: lambda_phy
    lam <- fit$report$lam_phy %||% exp(unname(fit$opt$par["loglambda_phy"]))
    add_comp("propto", rep(as.numeric(lam)[1L], Tn))
  }
  ## Two or more named kernel_*() terms share one multi-kernel block; each
  ## tier's loadings are Lambda_kernel[, 1:rank, index], counted like the
  ## single-kernel phylo_rr column.
  for (k in .variance_share_kernel_tiers(fit)) {
    Lk <- fit$report$Lambda_kernel
    v <- NULL
    if (length(dim(Lk)) == 3L && k$index <= dim(Lk)[3L]) {
      v <- loading_var(matrix(
        Lk[, seq_len(min(k$rank, dim(Lk)[2L])), k$index, drop = FALSE],
        nrow = dim(Lk)[1L]
      ))
    }
    add_comp(paste0("kernel_", k$name), v, label = k$label)
  }
  if (isTRUE(fit$use$re_int)) {
    ## One sigma per `(1 | group)` term, in formula order. The intercept has
    ## no trait index, so each trait receives the same variance (#1395).
    sig <- exp(as.numeric(fit$report$log_sigma_re_int %||% numeric(0)))
    groups <- as.character(fit$re_int$groups %||% character(0))
    if (!length(sig) || length(groups) != length(sig)) {
      omitted <- c(omitted, stats::setNames("(1 | group) random intercepts", ""))
    } else {
      cols <- make.unique(paste0("re_int_", groups), sep = "_")
      for (k in seq_along(sig)) {
        add_comp(cols[k], rep(sig[k]^2, Tn),
                 label = sprintf("(1 | %s)", groups[k]))
      }
    }
  }
  ## Add only the observation-scale residual represented by sigma_eps. For
  ## non-Gaussian families the sigma_eps slot is not the canonical
  ## latent-scale residual; extract_proportions() is the family-aware
  ## variance-share helper.
  residual_var <- .variance_share_residual_per_trait(fit)
  if (anyNA(residual_var) || any(residual_var > 0)) {
    add_comp("residual", residual_var)
  }

  omitted <- c(
    omitted,
    .variance_share_active_tiers(fit, handled = c("re_int", "propto", "kernel"))
  )
  .variance_share_warn_omitted(
    omitted,
    caller = "VP",
    class = "gllvmTMB_vp_component_omitted"
  )

  if (length(comps) == 0L) {
    M <- matrix(
      numeric(0),
      nrow = Tn,
      ncol = 0L,
      dimnames = list(trait_names, character(0))
    )
  } else {
    M <- do.call(cbind, comps)
    rownames(M) <- trait_names
    M <- .safe_variance_proportion_matrix(M)
  }
  if (length(omitted)) {
    attr(M, "omitted_components") <- unname(omitted)
  }
  M
}

## ---- Helpers shared by VP() and extract_proportions() ---------------------

## Per-trait slot of the observation residual sigma_eps: 0 = the trait does
## not use it, 1 = the Gaussian slot, 2 = the lognormal slot of a fit that has
## both families (the engine then carries two sigma_eps values). A trait's
## family is the modal family of its rows. A fit with no family metadata
## gives 0 for every trait, so no residual is invented. A sigma_eps fixed by
## the engine (a per-row diagonal term is present) still enters the
## likelihood, so it keeps its slot.
.variance_share_residual_slots <- function(fit) {
  trait_names <- levels(fit$data[[fit$trait_col]])
  Tn <- length(trait_names)
  out <- stats::setNames(integer(Tn), trait_names)
  fids <- fit$tmb_data$family_id_vec
  if (is.null(fids)) {
    return(out)
  }
  fids <- as.integer(fids)
  tids <- as.integer(fit$tmb_data$trait_id %||% (seq_along(fids) - 1L)) + 1L
  has_split <- all(c(0L, 3L) %in% fids)
  for (t in seq_len(Tn)) {
    fams_t <- fids[tids == t]
    fams_t <- fams_t[!is.na(fams_t)]
    if (!length(fams_t)) next
    fams_uniq <- unique(fams_t)
    fid <- fams_uniq[which.max(tabulate(match(fams_t, fams_uniq)))]
    if (identical(fid, 0L)) {
      out[t] <- 1L
    } else if (identical(fid, 3L)) {
      out[t] <- if (has_split) 2L else 1L
    }
  }
  out
}

## Per-trait observation residual variance sigma_eps^2 for Gaussian and
## lognormal traits, 0 elsewhere. `sigma_eps` overrides the fitted value (the
## Wald interval path passes `report(par)$sigma_eps`).
.variance_share_residual_per_trait <- function(fit, sigma_eps = NULL) {
  slots <- .variance_share_residual_slots(fit)
  out <- stats::setNames(numeric(length(slots)), names(slots))
  if (!any(slots > 0L)) {
    return(out)
  }
  if (is.null(sigma_eps)) {
    sigma_eps <- fit$report$sigma_eps
    if (is.null(sigma_eps)) {
      par <- fit$opt$par %||% numeric(0)
      sigma_eps <- exp(unname(par[names(par) == "log_sigma_eps"]))
    }
  }
  sigma_eps <- as.numeric(sigma_eps)
  if (!length(sigma_eps)) {
    return(out)
  }
  on <- slots > 0L
  out[on] <- sigma_eps[pmin(slots[on], length(sigma_eps))]^2
  out
}

## Tiers of the multi-kernel block (two or more named kernel_*() terms), as a
## list of list(name, index, rank, label). A single named kernel rides the
## phylo_rr slot and is not listed here.
.variance_share_kernel_tiers <- function(fit) {
  kl <- fit$kernel_levels
  if (!is.data.frame(kl) ||
      !all(c("name", "internal_level", "index") %in% names(kl))) {
    return(list())
  }
  kl <- kl[kl$internal_level == "kernel", , drop = FALSE]
  lapply(seq_len(nrow(kl)), function(j) {
    list(
      name = as.character(kl$name[j]),
      index = as.integer(kl$index[j]),
      rank = as.integer(kl$rank[j] %||% 1L),
      label = sprintf("kernel_*() term '%s'", kl$name[j])
    )
  })
}

## Active components the variance-share helpers do not turn into a per-trait
## column. Returns reader-facing labels named by an internal key; `handled`
## drops the keys a caller does compute (VP() handles "re_int", "propto" and
## "kernel"; extract_proportions() handles none of them).
.variance_share_active_tiers <- function(fit, handled = character(0)) {
  use <- fit$use %||% list()
  on <- function(flag) isTRUE(use[[flag]])
  any_on <- function(flags) any(vapply(flags, on, logical(1)))
  td <- fit$tmb_data %||% list()
  td_on <- function(flag) isTRUE(as.logical(td[[flag]])[1L])
  out <- character(0)
  add <- function(key, label) {
    out <<- c(out, stats::setNames(label, rep(key, length(label))))
  }

  if (on("re_int")) {
    groups <- as.character(fit$re_int$groups %||% "group")
    add("re_int", sprintf("(1 | %s)", groups))
  }
  if (on("propto")) {
    add("propto", "common-variance phylogenetic or pedigree term (phylo_indep(common = TRUE))")
  }
  kernel_tiers <- .variance_share_kernel_tiers(fit)
  if (length(kernel_tiers)) {
    add("kernel", vapply(kernel_tiers, `[[`, character(1), "label"))
  }
  if (on("spde")) {
    add("spatial", "spatial_*() field")
  }
  ## A response-column slope or coefficient term (slope(), phylo_slope(),
  ## kernel_slope(), spatial_slope(), *_coef()) runs on the augmented
  ## phylo / SPDE slope engine, so it also raises those engines' flags.
  ## Name it once.
  column_term <- any_on(c("phylo_column_slope", "response_column_coef",
                          "spatial_column_slope"))
  if (column_term) {
    add("column_slope", "response-column slope or coefficient term")
  }
  if (on("spde_latent_slope") ||
      (!column_term && any_on(c("spde_slope", "spde_dep_slope")))) {
    add("spatial_slope", "spatial random intercepts and slopes")
  }
  if (any_on(c("rr_B_slope", "diag_B_slope"))) {
    add("unit_slope", "unit-level random intercepts and slopes")
  }
  if (on("phylo_latent_slope") ||
      (!column_term &&
         (any_on(c("phylo_dep_slope", "phylo_indep_slope")) ||
            td_on("use_phylo_slope_correlated")))) {
    add("phylo_slope", "phylogenetic or pedigree random intercepts and slopes")
  } else if (!column_term && td_on("use_phylo_slope")) {
    ## Legacy phylo_slope(x | species) / animal_slope(x | id): one slope per
    ## level shared across traits, with no random intercept.
    add("phylo_slope_only", "phylogenetic or pedigree random slope")
  }
  if (isTRUE(fit$temporal$active)) {
    add("temporal", "temporal_*() state")
  }
  if (on("equalto")) {
    add("meta_V", "meta_V() known sampling variance")
  }
  out[!names(out) %in% handled]
}

## Warn about omitted components. `omitted` is named by the keys of
## .variance_share_active_tiers() ("" for a component whose report slot had
## the wrong shape); the keys pick the next-step hints.
.variance_share_warn_omitted <- function(omitted, caller, class) {
  if (!length(omitted)) {
    return(invisible(NULL))
  }
  keys <- names(omitted) %||% rep("", length(omitted))
  omitted <- unname(omitted)
  n_omitted <- length(omitted)
  msg <- c(
    "{.fn {caller}} does not partition {n_omitted} active variance component{?s}: {omitted}.",
    "!" = "Each share is a proportion of the included components only, so it overstates that component's share of the total variance."
  )
  hints <- c(
    vp = "{.fn VP} does count {.code (1 | group)} random intercepts, common-variance phylogenetic terms and multi-kernel terms.",
    spatial = "A spatial field's variance is on the SPDE parameter scale, and these shares do not convert it to a per-trait variance.",
    slope = "A random-slope term's variance, intercept included, changes with the covariate value; {.fn extract_Sigma} reports its intercept-slope covariance (level {.code \"unit_slope\"}, {.code \"phy\"}, {.code \"phy_slope\"} or {.code \"spatial\"}).",
    slope_only = "A random slope's variance changes with the covariate value, so it has no single per-trait share.",
    column = "A response-column slope's variance changes with the covariate values; {.code extract_Sigma(fit, level = \"column_slope\")} reports its covariance across the slope columns.",
    temporal = "{.fn extract_temporal} reports the temporal loadings and per-trait variances; these shares do not add them yet.",
    meta_V = "The known sampling variances are the {.code V} given to {.fn meta_V}; they differ by observation."
  )
  use_hint <- c(
    vp = any(keys %in% c("re_int", "propto", "kernel")),
    spatial = "spatial" %in% keys,
    slope = any(keys %in% c("spatial_slope", "unit_slope", "phylo_slope")),
    slope_only = "phylo_slope_only" %in% keys,
    column = "column_slope" %in% keys,
    temporal = "temporal" %in% keys,
    meta_V = "meta_V" %in% keys
  )
  for (h in names(hints)[use_hint]) {
    msg <- c(msg, if (identical(h, "vp")) c(">" = hints[[h]]) else c("i" = hints[[h]]))
  }
  cli::cli_warn(msg, class = c(class, "gllvmTMB_variance_component_omitted"))
}
