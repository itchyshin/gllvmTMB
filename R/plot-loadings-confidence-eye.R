## Confidence Eye plot for per-species loadings with uncertainty bands.
## Closest published precedent is the site-score uncertainty plot in
## Hoegh & Roberts 2020 (doi:10.1002/ece3.5752), which targets *site*
## scores not species loadings. Their UncertainOrd package is the
## closest neighbour. For species loadings specifically I am not aware
## of an ecology-side precedent — this plot fills the gap.
##
## The Confidence Eye contract (from the project's figure-quality
## doctrine):
##   * pale CI region (geom_rect / geom_linerange with thick alpha)
##   * hollow point estimate (geom_point, shape = 21, fill = "white")
##   * sort options so unreliable entries are visually grouped
##
## ggplot2 is the only viz dependency; no patchwork / cowplot /
## gridExtra needed because we use facet_wrap.

#' Confidence Eye plot for per-species loading uncertainty
#'
#' A bar-and-whisker visualisation of the entries of `Lambda` with
#' point estimates and Wald (or other-method) confidence intervals from
#' [loading_ci()]. Default rendering uses the "Confidence Eye" contract:
#' a pale CI region (`geom_linerange`) and a hollow point estimate
#' (`geom_point`, shape = 21, fill white) so the visual weight rests on
#' the uncertainty rather than the point.
#'
#' The closest published precedent for an uncertainty-aware per-species
#' loading display in JSDM is the site-score uncertainty plot of Hoegh
#' & Roberts (2020, doi:10.1002/ece3.5752), but that targets site
#' scores rather than species loadings. To my knowledge no equivalent
#' plot of per-species Lambda uncertainty exists in the ML/TMB JSDM
#' lineage (gllvm, sjSDM, ecoCopula).
#'
#' @param fit A multivariate `gllvmTMB()` fit, OR a data frame already
#'   produced by [loading_ci()] / [flag_unreliable_loadings()].
#' @param level,method,conf_level Forwarded to [loading_ci()] when
#'   `fit` is a fit object. Ignored when `fit` is already a
#'   `loading_ci()` data frame.
#' @param null_region Optional length-2 numeric drawn as a shaded
#'   "biologically negligible" band so the reader can tell at a glance
#'   which CIs sit outside it. If supplied, also colours points by
#'   reliability via [flag_unreliable_loadings()]. Default `NULL`
#'   (no band drawn).
#' @param sort_by Character, one of `"trait_order"` (the order of the
#'   `trait` factor, the default) or `"magnitude"`. Note `"magnitude"`
#'   applies a single **global** trait ordering keyed by each trait's
#'   largest absolute loading across axes; the shared discrete x-axis
#'   cannot reorder traits within individual facets.
#' @param ylim Optional length-2 numeric vector clipping the y-axis
#'   via `coord_cartesian()`. Useful when one degenerate loading
#'   estimate would otherwise blow out the scale and crush the rest.
#'   Default `NULL` (no clipping).
#'
#' @return A `ggplot` object.
#'
#' @seealso [loading_ci()], [flag_unreliable_loadings()].
#'
#' @examples
#' \dontrun{
#' plot_loadings_confidence_eye(fit, level = "unit",
#'                              null_region = c(-0.1, 0.1))
#' }
#'
#' @export
plot_loadings_confidence_eye <- function(fit,
                                         level       = c("unit", "unit_obs"),
                                         method      = "wald",
                                         conf_level  = 0.95,
                                         null_region = NULL,
                                         sort_by     = c("trait_order", "magnitude"),
                                         ylim        = NULL) {

  if (!requireNamespace("ggplot2", quietly = TRUE))
    cli::cli_abort("{.pkg ggplot2} is required for {.fn plot_loadings_confidence_eye}.")

  sort_by <- match.arg(sort_by)

  if (!is.null(null_region) &&
      (!is.numeric(null_region) || length(null_region) != 2L ||
       any(!is.finite(null_region))))
    cli::cli_abort(
      "{.arg null_region} must be a length-2 finite numeric vector, e.g. {.code c(-0.1, 0.1)}."
    )

  if (is.data.frame(fit)) {
    needed <- c("trait", "axis", "estimate", "se", "lower", "upper", "pinned")
    if (!all(needed %in% names(fit)))
      cli::cli_abort(
        "Data-frame input must have columns {.code {needed}} (output of {.fn loading_ci})."
      )
    df <- fit
  } else {
    df <- if (!is.null(null_region)) {
      flag_unreliable_loadings(fit, null_region = null_region,
                               level = level, method = method,
                               conf_level = conf_level)
    } else {
      loading_ci(fit, level = level, method = method, conf_level = conf_level)
    }
  }

  ## When we received a data frame as input but null_region is specified,
  ## annotate reliability post-hoc.
  if (!is.null(null_region) && is.null(df$unreliable))
    df <- flag_unreliable_loadings(df, null_region = null_region)

  ## ---- CI-availability gate: refuse to draw eyes when no bounds ----
  ## The fallback ("Hessian non-PD; CIs unavailable. Hollow points only.")
  ## must trigger ONLY when no usable CI is in the input — not whenever
  ## the underlying fit was non-PD. The profile path (`loading_ci(method
  ## = "profile")`) bypasses the pdHess gate and produces valid CIs even
  ## on a non-PD fit, but still labels them `pd_hessian = FALSE` to
  ## reflect the fit's status faithfully. Gating on `pd_hessian` alone
  ## therefore mis-classifies profile CIs as unavailable. Drive the
  ## decision from the data instead: if any non-pinned row has a finite
  ## (lower, upper) pair, draw eyes.
  free_rows <- !df$pinned
  has_any_ci <- any(
    is.finite(df$lower[free_rows]) & is.finite(df$upper[free_rows])
  )
  pd_failure <- !has_any_ci

  ## Sorting per facet
  if (sort_by == "magnitude") {
    df <- df[order(df$axis, -abs(df$estimate)), ]
    df$trait <- factor(df$trait,
                       levels = unique(df$trait[order(-abs(df$estimate))]))
  }

  ## Colour: pinned (grey), CI overlaps null (red), CI excludes null
  ## (green), or "estimated" (blue) when no null_region was supplied.
  ##
  ## NOTE: the earlier draft used `isTRUE(df$unreliable)` /
  ## `is.null(df$unreliable)` inside the ifelse chain — both are
  ## scalar-only checks; on a vector `isTRUE(...)` is always FALSE and
  ## the whole chain fell through to "CI excludes null" so everything
  ## non-pinned rendered the same green colour. Vectorised replacement:
  has_unreliable <- "unreliable" %in% names(df) &&
                    !is.null(df$unreliable) &&
                    length(df$unreliable) == nrow(df)
  rel <- rep("estimated", nrow(df))
  if (has_unreliable) {
    rel[df$unreliable %in% TRUE]  <- "CI overlaps null"
    rel[df$unreliable %in% FALSE] <- "CI excludes null"
  }
  rel[df$pinned] <- "pinned"     # pinned wins last so NA unreliable on
                                 # pinned rows is classified correctly
  df$.reliability <- factor(
    rel,
    levels = c("pinned", "CI overlaps null", "CI excludes null", "estimated")
  )

  fill_pal <- c(
    "pinned"           = "grey50",
    "CI overlaps null" = "#d6604d",
    "CI excludes null" = "#1b7837",
    "estimated"        = "#377eb8"
  )

  ## ---- Eye polygons (lens shapes), grouped by axis facet ----
  ## Skip entirely when the fit's Hessian was non-PD; the CIs are NA
  ## and any polygon would be a fabrication.
  ## A data-frame input may carry a character `trait` (data.frame defaults to
  ## stringsAsFactors = FALSE); coerce to a factor so as.integer() gives real
  ## x-positions and the axis gets labels (#600).
  if (!is.factor(df$trait)) df$trait <- factor(df$trait)
  df$.x_pos <- as.integer(df$trait)
  eye_df <- NULL
  if (!pd_failure) {
    ## Build the polygon coordinates inside each axis facet separately so
    ## the x_pos integer encoding is panel-local (matches ggplot's
    ## facet-wise discrete x scale).
    eye_list <- lapply(split(df, df$axis), function(d_axis) {
      poly <- .eye_polygon_df(d_axis, x_pos = d_axis$.x_pos, width_max = 0.70)
      if (nrow(poly) == 0L) return(NULL)
      ## Attach reliability + axis labels to each polygon row so colour
      ## and facet aesthetics resolve.
      poly$.reliability <- d_axis$.reliability[poly$.id]
      poly$axis         <- d_axis$axis[poly$.id]
      poly$.gid         <- paste(as.character(poly$axis), poly$.id, sep = ".")
      poly
    })
    eye_df <- do.call(rbind, eye_list[!vapply(eye_list, is.null, logical(1))])
  }

  g <- ggplot2::ggplot(df, ggplot2::aes(x = .data$.x_pos, y = .data$estimate))

  if (!is.null(null_region))
    ## Single-row data so exactly ONE band is drawn; inheriting `df` drew one
    ## rectangle per row and stacked alpha to near-opaque (#601).
    g <- g + ggplot2::geom_rect(
      data = data.frame(.x = 1),
      xmin = -Inf, xmax = Inf,
      ymin = null_region[1], ymax = null_region[2],
      fill = "grey85", alpha = 0.25, colour = NA,
      inherit.aes = FALSE
    )

  g <- g + ggplot2::geom_hline(yintercept = 0, linewidth = 0.3,
                               colour = "grey40")

  ## Eyes only when we have a PD Hessian
  if (!is.null(eye_df) && nrow(eye_df) > 0L)
    g <- g + ggplot2::geom_polygon(
      data = eye_df,
      mapping = ggplot2::aes(x = .data$x, y = .data$y,
                             group = .data$.gid,
                             fill  = .data$.reliability),
      colour = NA, alpha = 0.35, inherit.aes = FALSE
    )

  g <- g +
    ggplot2::geom_point(
      ggplot2::aes(colour = .data$.reliability),
      shape = 21, fill = "white", size = 2, stroke = 0.9
    ) +
    ## Show the legend via colour (geom_point) so it remains visible
    ## even when no polygons are drawn (pd_failure case). Drop the
    ## fill legend (geom_polygon) to avoid duplicate keys.
    ggplot2::scale_fill_manual(values = fill_pal, name = NULL,
                               drop = FALSE, guide = "none") +
    ggplot2::scale_colour_manual(values = fill_pal, name = NULL,
                                 drop = FALSE) +
    ggplot2::scale_x_continuous(
      breaks = seq_len(nlevels(df$trait)),
      labels = levels(df$trait)
    ) +
    ggplot2::facet_wrap(~ .data$axis, scales = "free_x") +
    (if (!is.null(ylim) && length(ylim) == 2L)
       ggplot2::coord_cartesian(ylim = ylim)
     else ggplot2::coord_cartesian()) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x      = ggplot2::element_text(angle = 60, hjust = 1, size = 7),
      panel.grid.minor = ggplot2::element_blank()
    ) +
    ggplot2::labs(
      x = NULL, y = expression(hat(Lambda)),
      title = "Loading estimates with confidence eyes",
      subtitle = if (pd_failure)
        "Hessian non-PD; CIs unavailable (`?loading_ci`). Hollow points only."
      else if (!is.null(null_region))
        sprintf("Eye: pale lens = %.0f%% CI; hollow point = estimate. Band (%.2f, %.2f) = biologically negligible.",
                100 * conf_level, null_region[1], null_region[2])
      else NULL
    )

  g
}
