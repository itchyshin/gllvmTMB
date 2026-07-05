## Profile-likelihood machinery for individual entries of the loading
## matrix Lambda. Self-contained worker + tidy data.frame return so
## the result can be fed both into `loading_ci(method = "profile")`
## (which inverts the LR curve to get CIs) and into the `plot()`
## S3 method (which visualises the U-shape).
##
## Design borrows drmTMB's `R/profile.R` pattern (specifically
## `drm_profile_curve()` + `plot.profile.drmTMB()`):
##   * Curve data is a long data.frame with one row per (entry, grid
##     point), columns: trait, axis, profile_value, objective,
##     delta_deviance, estimate, ...
##   * The data.frame inherits class `profile_loadings` so dispatch to
##     `plot()` picks up the LR-curve drawing.
##   * Inverting the curve to CI bounds uses bracket-then-bisect via
##     `stats::uniroot()` on the deviance threshold; if the bracket
##     doesn't span the chisq crit value, the bound is reported NA.
##
## Stage 1 of the multi-stage profile-CI framework. Stages 2-3 will
## unify this with `confint.gllvmTMB_multi()` and extend to ICC /
## variance partitions. See `~/.claude/memory/MEMORY.md` "Profile-CI
## unified framework" task group for the staged plan.

#' Profile-likelihood curve(s) for entries of the loading matrix
#'
#' For each requested entry `(i, k)` of `Lambda_<level>`, refit the
#' model with that entry pinned to a grid of values and return the
#' resulting log-likelihood curve. The output is a long data.frame
#' with class `profile_loadings`; pass it to [plot()] to visualise the
#' classic LR U-shape, or to [loading_ci()] (via `method = "profile"`)
#' to invert the curve and get CIs that do NOT depend on the fit's
#' Hessian being positive-definite.
#'
#' This is **expensive**: each entry requires `n_grid` partial refits,
#' so a 20-species 2-factor fit at default `n_grid = 11` is ~440 fits.
#' For binary probit at the scale of this article's fixture, expect
#' minutes. Use `entries` to restrict to a subset when iterating.
#'
#' @param fit A confirmatory `gllvmTMB()` multi-trait fit.
#' @param level Which loading matrix: `"unit"` (default) or
#'   `"unit_obs"`. Legacy `"B"`/`"W"` accepted with deprecation.
#' @param entries Optional matrix or data.frame of `(i, k)` index
#'   pairs specifying which Lambda entries to profile. Default `NULL`
#'   profiles every entry that is NOT pinned (i.e. every free entry
#'   the data informs). Pinned entries are skipped.
#' @param n_grid Integer; number of grid points per entry. Default 11.
#' @param grid_extent Numeric; total grid width as a multiple of a
#'   robust scale estimate of the loading (default 6 — i.e. estimate
#'   ± 3 scale units on each side). At pdHess-OK fits the scale is
#'   the Wald SE; otherwise a heuristic based on `|Lambda|/2 + 0.5`.
#' @param conf_level Confidence level for the eventual CI inversion;
#'   stored on the output for downstream consumers.
#'
#' @return A data.frame of class `profile_loadings` with columns:
#'   `trait`, `axis`, `i`, `k`, `profile_value`, `objective`
#'   (the negative log-likelihood evaluated at that value),
#'   `delta_deviance` (= 2 * (objective - min(objective))),
#'   `estimate`, `conf_level`. Pinned entries do not appear in the
#'   output.
#'
#' @seealso [loading_ci()] for the inverted-CI version,
#'   [plot.profile_loadings()] for the U-shape visualisation.
#'
#' @examples
#' \dontrun{
#' pf <- loading_profile(fit, level = "unit")
#' plot(pf)                              # all entries faceted
#' loading_ci(fit, method = "profile")   # inverts pf internally
#' }
#'
#' @export
loading_profile <- function(fit,
                            level       = c("unit", "unit_obs"),
                            entries     = NULL,
                            n_grid      = 11L,
                            grid_extent = 6,
                            conf_level  = 0.95) {

  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("{.code fit} must be a multi-trait {.fun gllvmTMB} fit.")
  level <- match.arg(level)
  internal_level <- .normalise_level(level, arg_name = "level")
  lam_name <- paste0("Lambda_", internal_level)
  if (is.null(fit$report[[lam_name]]))
    cli::cli_abort("Fit has no {.code {lam_name}} to profile.")
  Lambda <- as.matrix(fit$report[[lam_name]])
  n_traits <- nrow(Lambda)
  K        <- ncol(Lambda)

  ## Trait/axis names (same fallback chain as loading_ci)
  axis_names  <- colnames(Lambda); if (is.null(axis_names))
    axis_names  <- paste0("LV", seq_len(K))
  trait_names <- rownames(Lambda)
  if (is.null(trait_names))
    trait_names <- rownames(fit$lambda_constraint[[internal_level]])
  if (is.null(trait_names) && !is.null(fit$trait_col) &&
      !is.null(fit$data) && !is.null(fit$data[[fit$trait_col]]))
    trait_names <- levels(fit$data[[fit$trait_col]])
  if (is.null(trait_names))
    trait_names <- paste0("trait_", seq_len(n_traits))

  ## Identify pinned entries (those have nothing to profile)
  M_user <- fit$lambda_constraint[[internal_level]]
  is_pinned <- if (is.null(M_user))
    matrix(FALSE, n_traits, K) else !is.na(M_user)

  ## Engine pins the strict-upper-triangle of the first d rows
  for (i in seq_len(min(n_traits, K)))
    for (j in seq_len(K))
      if (j > i) is_pinned[i, j] <- TRUE

  ## Resolve which entries to profile
  if (is.null(entries)) {
    free_idx <- which(!is_pinned, arr.ind = TRUE)
  } else {
    if (!is.matrix(entries) && !is.data.frame(entries))
      cli::cli_abort("{.arg entries} must be a 2-column matrix or data.frame of (i, k).")
    free_idx <- as.matrix(entries[, 1:2, drop = FALSE])
    storage.mode(free_idx) <- "integer"
  }
  if (nrow(free_idx) == 0L)
    cli::cli_abort("No free entries to profile.")

  ## Per-entry scale for grid: Wald SE if available, else heuristic
  ## proportional to |estimate|. The heuristic is generous (so the
  ## grid usually brackets the LR crit on both sides).
  pd_ok <- isTRUE(fit$sd_report$pdHess)
  if (pd_ok) {
    se_info  <- .lambda_se_at_mle(fit, internal_level)
    se_mat   <- se_info$se_lambda
  } else {
    se_mat <- abs(Lambda) / 2 + 0.5
  }

  ll_full <- as.numeric(stats::logLik(fit))
  full_formula <- .reconstruct_multi_formula(fit)
  arg_canon <- if (internal_level == "B") "unit" else "unit_obs"

  ## Forward the same auxiliary structure the bootstrap paths forward, so each
  ## profile refit is the SAME model as the original fit (phylo correlation,
  ## SPDE mesh, species grouping) rather than a mis-specified one (#594).
  aux <- list(
    phylo_vcv  = fit$phylo_vcv,
    phylo_tree = fit$phylo_tree,
    mesh       = fit$mesh
  )
  aux <- aux[!vapply(aux, is.null, logical(1))]
  ## One worker: refit with one entry pinned at value c, return -logLik.
  obj_at <- function(i, k, c) {
    M_test <- matrix(NA_real_, n_traits, K)
    if (!is.null(M_user)) {                # preserve other user pins
      M_test <- M_user
      M_test[i, k] <- c
    } else {
      M_test[i, k] <- c
    }
    lc_test <- stats::setNames(list(M_test), arg_canon)
    ## Preserve pins at the OTHER tier so its loadings are not re-estimated up
    ## to an unidentified rotation (#613). fit$lambda_constraint is keyed by the
    ## internal B/W name; translate to the public unit/unit_obs key.
    other_internal <- if (internal_level == "B") "W" else "B"
    if (!is.null(fit$lambda_constraint[[other_internal]])) {
      other_canon <- if (other_internal == "B") "unit" else "unit_obs"
      lc_test[[other_canon]] <- fit$lambda_constraint[[other_internal]]
    }
    fit_test <- try(
      do.call(gllvmTMB, c(list(
        formula = full_formula, data = fit$data,
        family  = fit$family_input,
        trait   = fit$trait_col, unit = fit$unit_col,
        species = fit$species_col,
        lambda_constraint = lc_test, silent = TRUE
      ), aux)),
      silent = TRUE
    )
    if (inherits(fit_test, "try-error") ||
        isTRUE(fit_test$opt$convergence != 0L))
      return(NA_real_)
    -as.numeric(stats::logLik(fit_test))    # NEGATIVE logLik (objective)
  }

  ## Build curve for each entry
  out_list <- vector("list", nrow(free_idx))
  for (r in seq_len(nrow(free_idx))) {
    i <- free_idx[r, 1L]; k <- free_idx[r, 2L]
    est <- Lambda[i, k]
    sc  <- se_mat[i, k]
    grid_lo <- est - grid_extent / 2 * sc
    grid_hi <- est + grid_extent / 2 * sc
    pv  <- seq(grid_lo, grid_hi, length.out = n_grid)
    obj <- vapply(pv, function(c) obj_at(i, k, c), numeric(1))
    out_list[[r]] <- data.frame(
      trait          = trait_names[i],
      axis           = axis_names[k],
      i              = i,
      k              = k,
      profile_value  = pv,
      objective      = obj,
      delta_deviance = 2 * (obj - min(obj, na.rm = TRUE)),
      estimate       = est,
      conf_level     = conf_level,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, out_list)
  out$trait <- factor(out$trait, levels = trait_names)
  out$axis  <- factor(out$axis,  levels = axis_names)
  class(out) <- c("profile_loadings", class(out))
  attr(out, "lam_name")   <- lam_name
  attr(out, "n_grid")     <- n_grid
  attr(out, "conf_level") <- conf_level
  out
}


#' Invert a `profile_loadings` curve to CI bounds
#'
#' Per-entry, find the parameter values where the delta-deviance
#' crosses the chisq critical value `qchisq(conf_level, df = 1)`.
#' Uses linear interpolation between the two grid points straddling
#' the threshold; if no grid point on a side exceeds the threshold,
#' the bound is `NA` (grid too narrow — re-call with larger
#' `grid_extent`).
#'
#' @param x A `profile_loadings` data.frame from `loading_profile()`.
#'
#' @return A data.frame with columns `trait`, `axis`, `estimate`,
#'   `lower`, `upper`, `ci_status` (= `"profile"` on success or
#'   `"interval_unavailable"` if the grid didn't bracket).
#'
#' @keywords internal
#' @noRd
.invert_profile_loadings <- function(x) {
  if (!inherits(x, "profile_loadings"))
    cli::cli_abort("{.code x} must be a {.cls profile_loadings} object.")
  conf_level <- attr(x, "conf_level") %||% unique(x$conf_level)
  cutoff <- stats::qchisq(conf_level, df = 1L)

  ## Per-entry interpolation
  key <- paste(x$i, x$k, sep = ":")
  splits <- split(x, key)
  out <- lapply(splits, function(d) {
    d <- d[order(d$profile_value), ]
    est <- d$estimate[1L]                # original Lambda value
    pv  <- d$profile_value
    dv  <- d$delta_deviance
    ## Use the PROFILE MINIMUM as the reference point for splitting
    ## the curve into left/right halves. Critical detail: the original
    ## fit's Lambda estimate is the maximum of the JOINT likelihood; on
    ## the per-entry profile (where nuisance parameters re-optimize),
    ## the minimum can lie elsewhere. Splitting at the original estimate
    ## then produces wrong bounds (e.g. lower > estimate). Splitting at
    ## the profile minimum gives the correct CI.
    min_idx <- which.min(d$objective)
    if (length(min_idx) == 0L || !is.finite(d$objective[min_idx]))
      return(data.frame(
        trait = d$trait[1L], axis = d$axis[1L],
        i = d$i[1L], k = d$k[1L],
        estimate = est, lower = NA_real_, upper = NA_real_,
        ci_status = "interval_unavailable_no_minimum",
        stringsAsFactors = FALSE
      ))
    profile_mle <- pv[min_idx]
    left  <- which(pv < profile_mle & dv > cutoff)
    right <- which(pv > profile_mle & dv > cutoff)
    lower <- if (length(left) > 0L) {
      ## Interpolate between the rightmost left-out point and its successor
      lo <- max(left)
      if (lo + 1L > length(pv)) NA_real_ else {
        x0 <- pv[lo]; x1 <- pv[lo + 1L]
        y0 <- dv[lo]; y1 <- dv[lo + 1L]
        if (!is.finite(y0) || !is.finite(y1) || y1 - y0 == 0)
          NA_real_
        else x0 + (cutoff - y0) * (x1 - x0) / (y1 - y0)
      }
    } else NA_real_
    upper <- if (length(right) > 0L) {
      hi <- min(right)
      if (hi - 1L < 1L) NA_real_ else {
        x0 <- pv[hi - 1L]; x1 <- pv[hi]
        y0 <- dv[hi - 1L]; y1 <- dv[hi]
        if (!is.finite(y0) || !is.finite(y1) || y1 - y0 == 0)
          NA_real_
        else x0 + (cutoff - y0) * (x1 - x0) / (y1 - y0)
      }
    } else NA_real_
    data.frame(
      trait     = d$trait[1L],
      axis      = d$axis[1L],
      i         = d$i[1L],
      k         = d$k[1L],
      estimate  = est,
      lower     = lower,
      upper     = upper,
      ci_status = if (is.finite(lower) && is.finite(upper)) "profile"
                  else "interval_unavailable",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}


#' Plot a profile_loadings object (LR U-shape per entry)
#'
#' S3 method dispatched from `plot()`. Draws the delta-deviance curve
#' per entry, the chisq cutoff as a dotted horizontal line, the MLE
#' as a grey vertical line, and (optionally) the inverted CI bounds
#' as dashed verticals.
#'
#' Design borrowed from drmTMB's `plot.profile.drmTMB()`.
#'
#' @param x A `profile_loadings` data.frame from `loading_profile()`.
#' @param interval Logical; draw inverted CI bounds (default `TRUE`).
#' @param ... Reserved for future options.
#'
#' @return A `ggplot` object.
#'
#' @export
plot.profile_loadings <- function(x, interval = TRUE, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE))
    cli::cli_abort("{.pkg ggplot2} is required for {.fn plot.profile_loadings}.")
  conf_level <- attr(x, "conf_level") %||% unique(x$conf_level)
  cutoff <- stats::qchisq(conf_level, df = 1L)
  estimates <- unique(x[, c("trait", "axis", "i", "k", "estimate"), drop = FALSE])
  estimates$.facet <- paste(estimates$trait, estimates$axis, sep = " | ")
  x$.facet <- paste(x$trait, x$axis, sep = " | ")

  g <- ggplot2::ggplot(x, ggplot2::aes(x = .data$profile_value,
                                       y = .data$delta_deviance)) +
    ggplot2::geom_hline(yintercept = cutoff, linetype = "dotted",
                        colour = "grey55", linewidth = 0.35) +
    ggplot2::geom_vline(
      data = estimates,
      mapping = ggplot2::aes(xintercept = .data$estimate),
      inherit.aes = FALSE,
      linewidth = 0.35, colour = "grey30"
    )

  if (isTRUE(interval)) {
    bounds <- .invert_profile_loadings(x)
    bounds$.facet <- paste(bounds$trait, bounds$axis, sep = " | ")
    keep <- is.finite(bounds$lower) | is.finite(bounds$upper)
    if (any(keep))
      g <- g +
        ggplot2::geom_vline(
          data = bounds[keep & is.finite(bounds$lower), , drop = FALSE],
          mapping = ggplot2::aes(xintercept = .data$lower),
          inherit.aes = FALSE,
          linetype = "dashed", linewidth = 0.3, colour = "grey45"
        ) +
        ggplot2::geom_vline(
          data = bounds[keep & is.finite(bounds$upper), , drop = FALSE],
          mapping = ggplot2::aes(xintercept = .data$upper),
          inherit.aes = FALSE,
          linetype = "dashed", linewidth = 0.3, colour = "grey45"
        )
  }

  g <- g +
    ggplot2::geom_line(linewidth = 0.8, colour = "#0072B2", na.rm = TRUE) +
    ggplot2::geom_point(size = 1.8, shape = 21, fill = "white",
                        colour = "#0072B2", stroke = 0.6, na.rm = TRUE) +
    ggplot2::facet_wrap(~ .data$.facet, scales = "free_x") +
    ggplot2::theme_minimal() +
    ggplot2::theme(strip.text = ggplot2::element_text(size = 7),
                   panel.grid.minor = ggplot2::element_blank()) +
    ggplot2::labs(
      x = expression(Lambda[i*k]),
      y = expression(Delta * "deviance"),
      title = "Profile-likelihood curves for Lambda entries",
      subtitle = sprintf(
        "Dotted: chisq cutoff at %.2f for level %.2f. Solid grey: MLE. Dashed grey: inverted CI bounds.",
        cutoff, conf_level)
    )
  g
}


## `%||%` is defined once at package scope in R/fit-multi.R (#699 removed the
## duplicate definition that used to live here).
