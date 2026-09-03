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
#' machine precision during development (see
#' `dev/getlv-score-se-RESULTS.md`). Requirements:
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
      return(ord$scores)
    }
    return(rotate_loadings(fit, .canonical_level_name(level), rotate)$scores)
  }
  se_mat <- if (inherits(fit, "gllvmTMB_va")) {
    .va_getLV_se(fit, scores = ord$scores)
  } else {
    .getLV_se(fit, level = level, scores = ord$scores)
  }
  list(scores = ord$scores, se = se_mat)
}

#' Standard error of every unit-level (or within-unit) latent score
#'
#' Internal helper for `getLV(..., se = TRUE)`. Reads the marginal SE of
#' the `z_B` / `z_W` random-effect block from `fit$sd_report` and reshapes
#' it with the same `matrix(nrow = d, ncol = n)` then transpose convention
#' [extract_ordination()] uses for the point estimates, so a misordered
#' reshape here would silently pair the wrong SE with the wrong (unit,
#' axis) score cell -- see `dev/getlv-score-se-RESULTS.md` for the
#' verification this guards against.
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
#' @param ellipse Logical; if `TRUE`, draw an asymptotic-normal score
#'   -uncertainty ellipse around every site, from [ordination_uncertainty()].
#'   Only supported with `rotate = "none"` (the default) -- see
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
  if (length(axes) != 2L) {
    cli::cli_abort("axes must be length 2.")
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
#'
#' Structured trait-intercept rho fits are excluded; use `extract_Sigma()` and
#' its `source_strength` metadata.
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
  .structured_rho_source_allocation_assert(fit, "VP")
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

  sigma_eps <- .gllvmTMB_sigma_eps_vector(fit)
  if (!length(sigma_eps)) {
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
      out[t] <- .gllvmTMB_sigma_eps_for_family(fit, fid)^2
    }
  }
  out
}
