## ggplot2-based S3 plot method for `gllvmTMB_multi` fits.
##
## Lifted in spirit from gllvm2lev::plot.gllvm2lev() but re-implemented
## around gllvmTMB's extractor API: extract_Sigma(), extract_proportions(),
## extract_communality(), extract_ICC_site(), extract_ordination(),
## getLoadings(). One dispatcher, seven plot types.

#' Plot a fitted multivariate gllvmTMB model
#'
#' Produces a variety of `ggplot2` visualisations for a stacked-trait
#' multivariate GLLVM. Dispatches on `type` to one of seven panels:
#'
#' \describe{
#'   \item{`"correlation"`}{Combined heatmap of trait correlations.
#'     Upper triangle = between-unit correlations (`level = "unit"`),
#'     lower triangle = within-unit correlations (`level = "unit_obs"`),
#'     diagonal = 1. Falls back to whichever level is present if the
#'     other tier is absent. Optional `boot` intervals are carried in the
#'     plot data when supplied.}
#'   \item{`"correlation_ellipse"`}{Ellipse matrix of trait correlations.
#'     Ellipse direction and eccentricity encode the sign and strength of
#'     the correlation. This is the Figure-3-style alternative to the tile
#'     heatmap. Optional `boot` intervals mark correlations whose interval
#'     does not cross zero with black borders and stars.}
#'   \item{`"loadings"`}{Tile heatmap of `Lambda_B` (and `Lambda_W` if
#'     present), faceted by level. Rows = traits, columns = factors.
#'     Pinned cells (from `lambda_constraint`) are drawn with a heavy
#'     outline.}
#'   \item{`"integration"`}{Dot-and-whisker plot of repeatability (ICC),
#'     between-tier communality and within-tier communality per trait,
#'     sorted by repeatability. Optional whiskers from a `boot` object
#'     (skipped if `boot = NULL`).}
#'   \item{`"communality"`}{Figure-3-style stacked bars of per-trait
#'     communality (`c^2`, shared latent proportion) and uniqueness
#'     (`1 - c^2`) for the available latent tiers. Optional `boot`
#'     intervals are drawn on the `c^2` boundary when supplied.}
#'   \item{`"variance"`}{Stacked-bar variance partition per trait, using
#'     `extract_proportions(format = "long")`. One bar per trait,
#'     stacks summing to 1.}
#'   \item{`"ordination"`}{Dimension-aware latent-score ordination.
#'     1D fits (`d = 1`) get a horizontal score strip with trait loading
#'     lollipops; 2D fits get a standard biplot; 3D fits get a static
#'     pair-grid biplot for the three axis pairs. For `d > 3`, pick two
#'     or three axes via `axes`.}
#' }
#'
#' @param x A fit returned by [gllvmTMB()].
#' @param type One of `"correlation"`, `"correlation_ellipse"`, `"loadings"`,
#'   `"integration"`, `"communality"`, `"variance"`, `"ordination"`.
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Legacy aliases `"B"` and `"W"` are accepted with a deprecation warning.
#'   Used by `"loadings"` (which level to plot; the default
#'   `c("unit", "unit_obs")` means "both available levels, faceted
#'   side-by-side"; pass a length-1 string to plot one tier) and
#'   `"ordination"` (single level required; omitted `level` defaults to
#'   `"unit"`). Ignored for `"correlation"` (which always shows both if
#'   available), `"integration"`, and `"variance"`.
#'
#'   *Note*: the default `level = c("unit", "unit_obs")` is intentionally a
#'   length-2 vector, not the usual `match.arg` shortcut. The dispatcher
#'   does **not** call `match.arg(level)` itself; each helper inspects
#'   `level` and decides whether to plot one tier or both. If you copy
#'   one of these helpers into your own code, mirror that pattern rather
#'   than reflexively calling `match.arg(level)` (which would silently
#'   collapse the default to `"unit"` and drop the `unit_obs` panel).
#' @param boot Optional bootstrap object. This can be either a
#'   `bootstrap_Sigma()` result or a list with elements `repeatability`,
#'   `communality_B`, `communality_W`, each a data frame with columns
#'   `trait`, `lower`, `upper`. A `bootstrap_Sigma()` object can add
#'   correlation intervals to `"correlation"` / `"correlation_ellipse"`,
#'   whiskers to `"integration"`, and `c^2` boundary intervals to
#'   `"communality"`. Default `NULL` skips interval overlays.
#' @param axes Length-2 or length-3 integer vector for `"ordination"` when
#'   `d >= 2`. Length 2 draws a single biplot. Length 3 draws a static
#'   pair-grid of the three axis pairs. For `d = 3`, the default
#'   `c(1, 2)` is promoted to `c(1, 2, 3)` so all three axes are visible.
#'   Ignored when `d = 1`.
#' @param rotation One of `"varimax"`, `"none"`, or `"promax"` for
#'   `"ordination"` plots. The default `"varimax"` uses rotated,
#'   shared-variance-ordered, sign-anchored axes for interpretation.
#'   Use `"none"` to show the raw computational orientation. Rotation
#'   makes the biplot easier to label; use `Sigma`, correlations,
#'   communality, and uniqueness as the primary quantitative summaries.
#' @param order_axes Logical. For rotated `"ordination"` plots, reorder
#'   latent axes by decreasing shared variance after rotation. Default
#'   `TRUE`. Ignored when `rotation = "none"`.
#' @param sign_anchor One of `"auto"` or `"none"`. For rotated
#'   `"ordination"` plots, `"auto"` flips each axis so its anchor trait has
#'   a positive loading. Default `"auto"`. Ignored when `rotation = "none"`.
#' @param anchor_traits Optional character vector of trait names used for
#'   sign anchoring in rotated `"ordination"` plots. Supply one trait per
#'   axis after any `order_axes` step. Missing axes fall back to the trait
#'   with the largest absolute loading. Ignored when `rotation = "none"`.
#' @param standardize_loadings Logical. For `"ordination"` plots, divide
#'   each trait loading by the square root of that trait's model-implied total
#'   variance before drawing arrows. This puts arrows on a correlation-like
#'   scale for mixed-scale traits. It changes the displayed arrow scale, not
#'   the model's communality or variance decomposition. Default `FALSE`.
#' @param ... Currently unused.
#' @return A `ggplot` object with a `gllvmTMB_meta` attribute describing
#'   the plot type, source extractor, covariance level, interval status, and
#'   rotation status. Metadata also carries extractor notes when a plotted
#'   summary has an important caveat. Plots also carry a `gllvmTMB_data`
#'   attribute with the prepared plotting data; ordination stores separate
#'   `scores` and `loadings` tables.
#' @method plot gllvmTMB_multi
#' @export
plot.gllvmTMB_multi <- function(
  x,
  type = c(
    "correlation",
    "correlation_ellipse",
    "loadings",
    "integration",
    "communality",
    "variance",
    "ordination"
  ),
  level = c("unit", "unit_obs"),
  boot = NULL,
  axes = c(1L, 2L),
  rotation = c("varimax", "none", "promax"),
  order_axes = TRUE,
  sign_anchor = c("auto", "none"),
  anchor_traits = NULL,
  standardize_loadings = FALSE,
  ...
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Install ggplot2: {.code install.packages(\"ggplot2\")}.")
  }
  type <- match.arg(type)
  rotation <- match.arg(rotation)
  sign_anchor <- match.arg(sign_anchor)
  level_missing <- missing(level)
  ## level intentionally not match.arg'd up-front: each helper decides
  ## whether to require a single value or accept "both/NULL".
  ## Boundary normalisation per element when present, then de-duplicate
  ## so a user passing legacy + canonical (`c("unit", "B")`) collapses
  ## to a single internal slot (`c("B")`) rather than fooling the
  ## length-based "both tiers" guards in `.plot_loadings_gtmb` /
  ## `.plot_ordination_gtmb`. Regression: PR #60 R-CMD-check #95
  ## (test-plot-gllvmTMB.R:47) failed with `match.arg(level, c("B","W"))`
  ## "'arg' must be of length 1" because the prior length-4 default
  ## `c("unit", "unit_obs", "B", "W")` normalised to `c("B","W","B","W")`,
  ## skipped the length-2 guard, then hit match.arg.
  if (is.character(level) && length(level) > 0L) {
    level <- vapply(level, .normalise_level, character(1L), arg_name = "level")
    level <- unique(level)
  }
  switch(
    type,
    correlation = .plot_correlation_gtmb(x, boot = boot),
    correlation_ellipse = .plot_correlation_ellipse_gtmb(x, boot = boot),
    loadings = .plot_loadings_gtmb(x, level),
    integration = .plot_integration_gtmb(x, boot = boot),
    communality = .plot_communality_gtmb(x, boot = boot),
    variance = .plot_variance_gtmb(x),
    ordination = .plot_ordination_gtmb(
      x,
      if (level_missing) "B" else level,
      axes = axes,
      rotation = rotation,
      order_axes = order_axes,
      sign_anchor = sign_anchor,
      anchor_traits = anchor_traits,
      standardize_loadings = standardize_loadings
    )
  )
}


# ---- helpers --------------------------------------------------------------

.gtmb_trait_names <- function(fit) {
  levels(fit$data[[fit$trait_col]])
}

.gtmb_plot_contract <- function(
  p,
  type,
  source,
  level = NULL,
  interval_status = "none",
  rotation_status = "rotation_invariant",
  data = NULL,
  notes = character(0)
) {
  notes <- unique(as.character(notes[!is.na(notes)]))
  attr(p, "gllvmTMB_meta") <- list(
    type = type,
    source = source,
    level = level,
    interval_status = interval_status,
    rotation_status = rotation_status,
    notes = notes
  )
  if (!is.null(data)) {
    attr(p, "gllvmTMB_data") <- data
  }
  p
}

.gtmb_canonical_levels <- function(level) {
  vapply(level, .canonical_level_name, character(1L), USE.NAMES = FALSE)
}

.gtmb_plot_palette <- c(
  blue = "#0072B2",
  sky = "#56B4E9",
  green = "#009E73",
  orange = "#E69F00",
  vermillion = "#D55E00",
  purple = "#CC79A7",
  ink = "#2B2B2B",
  grey = "#6B6B6B",
  pale_grey = "#F4F4F4",
  grid = "#D9D9D9"
)

.gtmb_theme_figure <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(
        face = "bold",
        colour = .gtmb_plot_palette[["ink"]]
      ),
      plot.subtitle = ggplot2::element_text(
        colour = .gtmb_plot_palette[["grey"]],
        margin = ggplot2::margin(b = 6)
      ),
      plot.caption = ggplot2::element_text(
        colour = .gtmb_plot_palette[["grey"]],
        hjust = 0
      ),
      axis.title = ggplot2::element_text(colour = .gtmb_plot_palette[["ink"]]),
      axis.text = ggplot2::element_text(colour = .gtmb_plot_palette[["ink"]]),
      strip.text = ggplot2::element_text(
        face = "bold",
        colour = .gtmb_plot_palette[["ink"]]
      ),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold")
    )
}

.gtmb_scale_fill_diverging <- function(name, limits = NULL) {
  ggplot2::scale_fill_gradient2(
    low = .gtmb_plot_palette[["blue"]],
    mid = "#F7F7F7",
    high = .gtmb_plot_palette[["vermillion"]],
    midpoint = 0,
    limits = limits,
    na.value = .gtmb_plot_palette[["pale_grey"]],
    name = name
  )
}

.gtmb_symmetric_limits <- function(x) {
  lim <- max(abs(x), na.rm = TRUE)
  if (!is.finite(lim) || lim == 0) {
    return(NULL)
  }
  c(-lim, lim)
}

.gtmb_arrow_label_positions <- function(
  dat,
  x_col = "x",
  y_col = "y",
  group_col = NULL
) {
  x <- dat[[x_col]]
  y <- dat[[y_col]]
  span <- max(abs(c(x, y)), na.rm = TRUE)
  span <- if (is.finite(span) && span > 0) span else 1
  pad <- 0.045 * span
  radius <- sqrt(x^2 + y^2)
  ux <- ifelse(is.finite(radius) & radius > 0, x / radius, 0)
  uy <- ifelse(is.finite(radius) & radius > 0, y / radius, 1)
  dat$label_x <- x + pad * ux
  dat$label_y <- y + pad * uy
  dat$label_hjust <- ifelse(ux > 0.2, 0, ifelse(ux < -0.2, 1, 0.5))
  dat$label_vjust <- ifelse(uy > 0.2, 0, ifelse(uy < -0.2, 1, 0.5))
  groups <- if (is.null(group_col)) {
    rep("all", nrow(dat))
  } else {
    as.character(dat[[group_col]])
  }
  for (group in unique(groups)) {
    rows <- which(groups == group)
    angle_bin <- round(atan2(uy[rows], ux[rows]) / (pi / 8))
    for (bin in unique(angle_bin)) {
      idx <- rows[which(angle_bin == bin)]
      if (length(idx) < 2L) {
        next
      }
      idx <- idx[order(radius[idx], decreasing = TRUE)]
      offsets <- (seq_along(idx) - mean(seq_along(idx))) * pad * 1.4
      dat$label_x[idx] <- dat$label_x[idx] + offsets * -uy[idx]
      dat$label_y[idx] <- dat$label_y[idx] + offsets * ux[idx]
    }
    for (pass in seq_len(3L)) {
      if (length(rows) < 2L) {
        next
      }
      for (i in seq_len(length(rows) - 1L)) {
        for (j in seq.int(i + 1L, length(rows))) {
          row_i <- rows[[i]]
          row_j <- rows[[j]]
          close_x <- abs(dat$label_x[[row_i]] - dat$label_x[[row_j]]) <
            0.24 * span
          close_y <- abs(dat$label_y[[row_i]] - dat$label_y[[row_j]]) <
            0.16 * span
          if (!isTRUE(close_x && close_y)) {
            next
          }
          move <- 0.5 *
            (0.16 * span - abs(dat$label_y[[row_i]] - dat$label_y[[row_j]])) +
            0.015 * span
          if (dat$label_y[[row_i]] <= dat$label_y[[row_j]]) {
            dat$label_y[[row_i]] <- dat$label_y[[row_i]] - move
            dat$label_y[[row_j]] <- dat$label_y[[row_j]] + move
          } else {
            dat$label_y[[row_i]] <- dat$label_y[[row_i]] + move
            dat$label_y[[row_j]] <- dat$label_y[[row_j]] - move
          }
        }
      }
    }
  }
  dat
}

.gtmb_ordination_rotation_status <- function(
  rotation,
  order_axes,
  sign_anchor
) {
  if (identical(rotation, "none")) {
    return("rotation_ambiguous_loadings")
  }
  paste0(
    rotation,
    if (isTRUE(order_axes)) "_ordered" else "_raw_order",
    if (identical(sign_anchor, "auto")) "_sign_anchored" else "_unanchored"
  )
}

.gtmb_ordination_rotation_caption <- function(
  rotation,
  order_axes,
  sign_anchor,
  anchor_traits,
  rotation_info
) {
  invariant_note <- "Use Sigma and correlation summaries for rotation-invariant interpretation."
  if (identical(rotation, "none")) {
    return(paste(
      "Axes and signs use the raw fitted orientation.",
      invariant_note
    ))
  }

  order_note <- if (isTRUE(order_axes)) {
    "ordered by shared variance"
  } else {
    "kept in rotated-axis order"
  }

  sign_note <- if (identical(sign_anchor, "auto")) {
    anchors_supplied <- !is.null(anchor_traits) &&
      length(stats::na.omit(anchor_traits)) > 0L
    if (isTRUE(anchors_supplied)) {
      anchors <- stats::na.omit(rotation_info$anchor_traits)
      anchors <- anchors[nzchar(anchors)]
      anchors <- unique(anchors)
      paste0(
        "sign-anchored to supplied trait",
        if (length(anchors) == 1L) "" else "s",
        ": ",
        paste(anchors, collapse = ", ")
      )
    } else {
      "sign-anchored so the largest loading on each axis is positive"
    }
  } else {
    "not sign-anchored, so axis signs remain arbitrary"
  }

  paste(
    paste0(
      "Axes use ",
      rotation,
      " rotation, ",
      order_note,
      ", and ",
      sign_note,
      "."
    ),
    invariant_note
  )
}

.gtmb_caption_lines <- function(..., width = 86) {
  parts <- unlist(list(...), use.names = FALSE)
  parts <- parts[!is.na(parts) & nzchar(parts)]
  wrapped <- lapply(parts, function(x) {
    paste(strwrap(x, width = width), collapse = "\n")
  })
  paste(unlist(wrapped, use.names = FALSE), collapse = "\n")
}

.gtmb_tile_label_colour <- function(x, threshold = 0.65, relative = FALSE) {
  out <- rep(.gtmb_plot_palette[["ink"]], length(x))
  finite <- is.finite(x)
  if (!any(finite)) {
    return(out)
  }
  cutoff <- threshold
  if (isTRUE(relative)) {
    lim <- max(abs(x[finite]), na.rm = TRUE)
    if (!is.finite(lim) || lim == 0) {
      return(out)
    }
    cutoff <- threshold * lim
  }
  out[finite & abs(x) >= cutoff] <- "white"
  out
}

.gtmb_interval_status <- function(status) {
  status <- unique(as.character(status[!is.na(status)]))
  if (length(status) == 0L || identical(status, "none")) {
    return("none")
  }
  if (all(status == "provided")) {
    return("provided")
  }
  if ("provided" %in% status) {
    return("partial")
  }
  paste(status, collapse = ";")
}


# ---- correlation heatmap --------------------------------------------------

.correlation_merge_bootstrap_intervals <- function(tab, boot, level) {
  if (is.null(tab) || is.null(boot)) {
    return(tab)
  }
  if (!inherits(boot, "bootstrap_Sigma")) {
    return(tab)
  }
  boot_tab <- tryCatch(
    suppressMessages(extract_Sigma_table(
      boot,
      level = .canonical_level_name(level),
      measure = "correlation",
      entries = "all"
    )),
    error = function(e) NULL
  )
  if (is.null(boot_tab) || nrow(boot_tab) == 0L) {
    tab$interval_method <- "missing"
    tab$interval_status <- "missing"
    return(tab)
  }
  key <- paste(tab$trait_i, tab$trait_j, tab$level, sep = "\r")
  boot_key <- paste(
    boot_tab$trait_i,
    boot_tab$trait_j,
    boot_tab$level,
    sep = "\r"
  )
  hit <- match(key, boot_key)
  has_hit <- !is.na(hit)
  tab$lower[has_hit] <- boot_tab$lower[hit[has_hit]]
  tab$upper[has_hit] <- boot_tab$upper[hit[has_hit]]
  tab$interval_method[has_hit] <- boot_tab$interval_method[hit[has_hit]]
  tab$interval_status <- ifelse(
    has_hit,
    boot_tab$interval_status[hit],
    "missing"
  )
  tab$interval_method[!has_hit] <- "missing"
  tab
}

.correlation_plot_data_gtmb <- function(fit, boot = NULL) {
  tn <- .gtmb_trait_names(fit)

  tab_B <- if (isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B)) {
    suppressMessages(extract_Sigma_table(
      fit,
      level = "unit",
      measure = "correlation",
      entries = "all"
    ))
  } else {
    NULL
  }
  tab_W <- if (isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W)) {
    suppressMessages(extract_Sigma_table(
      fit,
      level = "unit_obs",
      measure = "correlation",
      entries = "all"
    ))
  } else {
    NULL
  }
  tab_B <- .correlation_merge_bootstrap_intervals(tab_B, boot, "B")
  tab_W <- .correlation_merge_bootstrap_intervals(tab_W, boot, "W")
  notes <- unique(c(
    attr(tab_B, "notes") %||% character(0),
    attr(tab_W, "notes") %||% character(0)
  ))

  if (is.null(tab_B) && is.null(tab_W)) {
    cli::cli_abort(
      "No correlation matrix available -- neither B nor W tier has rr/diag."
    )
  }

  upper <- if (!is.null(tab_B)) {
    tab_B[tab_B$triangle == "upper", , drop = FALSE]
  } else {
    tab_W[tab_W$triangle == "upper", , drop = FALSE]
  }
  lower <- if (!is.null(tab_W)) {
    tab_W[tab_W$triangle == "lower", , drop = FALSE]
  } else {
    tab_B[tab_B$triangle == "lower", , drop = FALSE]
  }
  diag_tab <- if (!is.null(tab_B)) {
    tab_B[tab_B$triangle == "diagonal", , drop = FALSE]
  } else {
    tab_W[tab_W$triangle == "diagonal", , drop = FALSE]
  }
  diag_tab$level <- "diagonal"
  diag_tab$estimate <- 1

  out <- rbind(upper, lower, diag_tab)
  out$row <- factor(tn[out$i], levels = rev(tn))
  out$col <- factor(tn[out$j], levels = tn)
  out$value <- out$estimate
  out$display_value <- ifelse(
    out$triangle == "diagonal",
    NA_real_,
    out$estimate
  )
  out$label <- ifelse(
    out$triangle == "diagonal",
    "",
    sprintf("%.2f", out$estimate)
  )
  out$level <- factor(out$level, levels = c("unit", "unit_obs", "diagonal"))
  out$triangle <- factor(out$triangle, levels = c("upper", "lower", "diagonal"))
  attr(out, "notes") <- notes
  out
}

.plot_correlation_gtmb <- function(fit, boot = NULL) {
  dat <- .correlation_plot_data_gtmb(fit, boot = boot)
  notes <- attr(dat, "notes") %||% character(0)
  dat$label_colour <- .gtmb_tile_label_colour(dat$display_value)
  levels_available <- intersect(
    c("unit", "unit_obs"),
    unique(as.character(dat$level))
  )

  subtitle <- if (all(c("unit", "unit_obs") %in% levels_available)) {
    "Upper triangle: between-unit  |  Lower triangle: within-unit"
  } else if (identical(levels_available, "unit")) {
    "Between-unit only"
  } else {
    "Within-unit only"
  }

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(x = .data$col, y = .data$row, fill = .data$display_value)
  ) +
    ggplot2::geom_tile(
      ggplot2::aes(colour = .data$level),
      linewidth = 0.65
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$label),
      colour = dat$label_colour,
      size = 3
    ) +
    .gtmb_scale_fill_diverging("rho", limits = c(-1, 1)) +
    ggplot2::scale_colour_manual(
      values = c(
        unit = .gtmb_plot_palette[["blue"]],
        unit_obs = .gtmb_plot_palette[["orange"]],
        diagonal = .gtmb_plot_palette[["grid"]]
      ),
      breaks = c("unit", "unit_obs", "diagonal"),
      labels = c("Between-unit", "Within-unit", "Diagonal"),
      name = "Tier"
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      title = "Trait correlation matrix",
      subtitle = subtitle,
      caption = paste(
        "Cells show total correlations from extract_Sigma_table();",
        "diagonal cells are muted because self-correlation is fixed at 1."
      )
    ) +
    .gtmb_theme_figure() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))

  .gtmb_plot_contract(
    p,
    type = "correlation",
    source = "extract_Sigma_table",
    level = levels_available,
    interval_status = .gtmb_interval_status(dat$interval_status),
    data = dat,
    notes = notes
  )
}

.correlation_ellipse_plot_data_gtmb <- function(fit, boot = NULL, n = 80L) {
  cells <- .correlation_plot_data_gtmb(fit, boot = boot)
  notes <- attr(cells, "notes") %||% character(0)
  cells <- cells[
    !is.na(cells$display_value) &
      cells$triangle != "diagonal",
    ,
    drop = FALSE
  ]
  if (nrow(cells) == 0L) {
    cli::cli_abort(
      "No off-diagonal correlations available for an ellipse plot."
    )
  }

  theta <- seq(0, 2 * pi, length.out = n)
  out <- vector("list", nrow(cells))
  for (i in seq_len(nrow(cells))) {
    rho <- cells$estimate[i]
    a <- 0.45 * sqrt(1 + abs(rho))
    b <- 0.45 * sqrt(1 - abs(rho))
    phi <- if (rho >= 0) pi / 4 else -pi / 4
    x0 <- as.numeric(cells$col[i])
    y0 <- as.numeric(cells$row[i])
    x <- x0 + a * cos(theta) * cos(phi) - b * sin(theta) * sin(phi)
    y <- y0 + a * cos(theta) * sin(phi) + b * sin(theta) * cos(phi)
    significant <- all(c("lower", "upper") %in% names(cells)) &&
      is.finite(cells$lower[i]) &&
      is.finite(cells$upper[i]) &&
      cells$lower[i] * cells$upper[i] > 0
    out[[i]] <- data.frame(
      group = i,
      trait_i = cells$trait_i[i],
      trait_j = cells$trait_j[i],
      x = x,
      y = y,
      cell_x = x0,
      cell_y = y0,
      estimate = rho,
      value = rho,
      level = cells$level[i],
      triangle = cells$triangle[i],
      interval_method = cells$interval_method[i],
      interval_status = cells$interval_status[i],
      significant = significant,
      border_colour = if (significant) {
        .gtmb_plot_palette[["ink"]]
      } else {
        "#BDBDBD"
      },
      stringsAsFactors = FALSE
    )
  }
  ell <- do.call(rbind, out)
  attr(ell, "notes") <- notes
  ell
}

.plot_correlation_ellipse_gtmb <- function(fit, boot = NULL) {
  ell <- .correlation_ellipse_plot_data_gtmb(fit, boot = boot)
  notes <- attr(ell, "notes") %||% character(0)
  tn <- .gtmb_trait_names(fit)
  y_labels <- rev(tn)
  levels_available <- intersect(
    c("unit", "unit_obs"),
    unique(as.character(ell$level))
  )

  subtitle <- if (all(c("unit", "unit_obs") %in% levels_available)) {
    "Upper triangle: between-unit  |  Lower triangle: within-unit"
  } else if (identical(levels_available, "unit")) {
    "Between-unit only"
  } else {
    "Within-unit only"
  }

  star_dat <- unique(ell[
    ell$significant,
    c("group", "cell_x", "cell_y"),
    drop = FALSE
  ])
  caption <- if (any(ell$significant)) {
    paste(
      "Ellipse shape shows correlation sign and strength.",
      "Black border/star means the interval excludes zero.",
      sep = "\n"
    )
  } else if (any(ell$interval_status == "provided")) {
    paste(
      "Ellipse shape shows correlation sign and strength.",
      "Supplied intervals cross zero for displayed correlations.",
      sep = "\n"
    )
  } else {
    paste(
      "Ellipse shape shows correlation sign and strength.",
      "Add interval summaries for black borders/stars.",
      sep = "\n"
    )
  }

  p <- ggplot2::ggplot(
    ell,
    ggplot2::aes(
      x = .data$x,
      y = .data$y,
      group = .data$group,
      fill = .data$estimate
    )
  ) +
    ggplot2::geom_polygon(
      ggplot2::aes(colour = .data$border_colour),
      linewidth = 0.6
    ) +
    ggplot2::scale_colour_identity(guide = "none") +
    .gtmb_scale_fill_diverging("rho", limits = c(-1, 1)) +
    ggplot2::scale_x_continuous(
      breaks = seq_along(tn),
      labels = tn,
      expand = ggplot2::expansion(mult = 0.04)
    ) +
    ggplot2::scale_y_continuous(
      breaks = seq_along(tn),
      labels = y_labels,
      expand = ggplot2::expansion(mult = 0.04)
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      title = "Trait correlations (ellipses)",
      subtitle = subtitle,
      caption = caption
    ) +
    .gtmb_theme_figure() +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(colour = "#EAEAEA"),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )

  if (nrow(star_dat) > 0L) {
    p <- p +
      ggplot2::geom_text(
        data = star_dat,
        ggplot2::aes(x = .data$cell_x, y = .data$cell_y, label = "*"),
        inherit.aes = FALSE,
        fontface = "bold",
        size = 4
      )
  }

  .gtmb_plot_contract(
    p,
    type = "correlation_ellipse",
    source = "extract_Sigma_table",
    level = levels_available,
    interval_status = .gtmb_interval_status(ell$interval_status),
    data = ell,
    notes = notes
  )
}


# ---- loadings heatmap -----------------------------------------------------

.plot_loadings_gtmb <- function(fit, level) {
  ## level: NULL or the default-vector c("B","W") -> both available levels;
  ## a length-1 "B" or "W" -> single level.
  if (
    missing(level) ||
      is.null(level) ||
      (length(level) == 2L && setequal(level, c("B", "W")))
  ) {
    levels_to_plot <- character(0)
    if (isTRUE(fit$use$rr_B)) {
      levels_to_plot <- c(levels_to_plot, "B")
    }
    if (isTRUE(fit$use$rr_W)) levels_to_plot <- c(levels_to_plot, "W")
  } else {
    level <- match.arg(level, c("B", "W"))
    levels_to_plot <- level
  }
  if (length(levels_to_plot) == 0L) {
    cli::cli_abort("No latent() loadings to plot at the requested level(s).")
  }

  tn <- .gtmb_trait_names(fit)
  rows <- list()
  for (lv in levels_to_plot) {
    L <- suppressMessages(getLoadings(
      fit,
      level = .canonical_level_name(lv),
      rotate = "none"
    ))
    if (is.null(L)) {
      next
    }
    if (is.null(rownames(L))) {
      rownames(L) <- tn
    }
    constraint <- fit$lambda_constraint[[lv]]
    for (j in seq_len(ncol(L))) {
      pinned <- if (!is.null(constraint)) {
        !is.na(constraint[, j])
      } else {
        rep(FALSE, nrow(L))
      }
      rows[[length(rows) + 1L]] <- data.frame(
        trait = rownames(L),
        factor = paste0("LV", j),
        loading = L[, j],
        level = paste0("Level ", .canonical_level_name(lv)),
        pinned = pinned,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) {
    cli::cli_abort("No loadings to plot.")
  }

  dat <- do.call(rbind, rows)
  dat$trait <- factor(dat$trait, levels = rev(tn))
  dat$label <- sprintf("%.2f", dat$loading)
  dat$label_colour <- .gtmb_tile_label_colour(
    dat$loading,
    threshold = 0.65,
    relative = TRUE
  )
  show_tile_labels <- nrow(dat) <= 60L

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(x = .data$factor, y = .data$trait, fill = .data$loading)
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.6)

  if (show_tile_labels) {
    p <- p +
      ggplot2::geom_text(
        ggplot2::aes(label = .data$label),
        colour = dat$label_colour,
        size = 3
      )
  }

  ## Heavy outline on pinned cells
  if (any(dat$pinned)) {
    p <- p +
      ggplot2::geom_tile(
        data = dat[dat$pinned, , drop = FALSE],
        colour = "black",
        fill = NA,
        linewidth = 1
      ) +
      ggplot2::geom_point(
        data = dat[dat$pinned, , drop = FALSE],
        ggplot2::aes(
          x = .data$factor,
          y = .data$trait,
          shape = "Fixed loading"
        ),
        inherit.aes = FALSE,
        colour = "black",
        size = 2.5,
        stroke = 0.8
      ) +
      ggplot2::scale_shape_manual(
        values = c("Fixed loading" = 4),
        name = "Constraint"
      )
  }

  p <- p +
    .gtmb_scale_fill_diverging(
      "Loading",
      limits = .gtmb_symmetric_limits(dat$loading)
    ) +
    ggplot2::facet_wrap(~level) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      x = "Latent factor",
      y = NULL,
      title = "Factor loadings (Lambda)",
      caption = paste(
        "Loadings depend on rotation and sign.",
        "Use implied Sigma/correlations for rotation-invariant interpretation."
      )
    ) +
    .gtmb_theme_figure()

  .gtmb_plot_contract(
    p,
    type = "loadings",
    source = "getLoadings",
    level = .gtmb_canonical_levels(levels_to_plot),
    rotation_status = "rotation_ambiguous_loadings",
    data = dat
  )
}


# ---- integration indices --------------------------------------------------

.plot_integration_gtmb <- function(fit, boot = NULL) {
  tn <- .gtmb_trait_names(fit)
  rep <- suppressMessages(extract_ICC_site(fit))
  com_B <- suppressMessages(extract_communality(fit, level = "unit"))
  com_W <- suppressMessages(extract_communality(fit, level = "unit_obs"))

  if (is.null(rep) && is.null(com_B) && is.null(com_W)) {
    cli::cli_abort("No integration indices computable from this fit.")
  }

  pull_ci <- function(boot, name, traits) {
    if (is.null(boot)) {
      data.frame(
        trait = traits,
        lower = rep(NA_real_, length(traits)),
        upper = rep(NA_real_, length(traits)),
        stringsAsFactors = FALSE
      )
    } else {
      ci <- NULL
      if (inherits(boot, "bootstrap_Sigma")) {
        ci <- switch(
          name,
          repeatability = tryCatch(
            suppressMessages(extract_repeatability(boot)),
            error = function(e) NULL
          ),
          communality_B = tryCatch(
            suppressMessages(extract_communality(
              boot,
              level = "unit",
              ci = TRUE
            )),
            error = function(e) NULL
          ),
          communality_W = tryCatch(
            suppressMessages(extract_communality(
              boot,
              level = "unit_obs",
              ci = TRUE
            )),
            error = function(e) NULL
          )
        )
      } else {
        ci <- boot[[name]]
      }
      if (is.null(ci)) {
        return(data.frame(
          trait = traits,
          lower = rep(NA_real_, length(traits)),
          upper = rep(NA_real_, length(traits)),
          stringsAsFactors = FALSE
        ))
      }
      ci[match(traits, ci$trait), c("trait", "lower", "upper"), drop = FALSE]
    }
  }

  rows <- list()
  if (!is.null(rep)) {
    ci <- pull_ci(boot, "repeatability", tn)
    rows[[length(rows) + 1L]] <- data.frame(
      trait = tn,
      index = "Repeatability",
      estimate = unname(rep[tn]),
      lower = ci$lower,
      upper = ci$upper,
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(com_B)) {
    ci <- pull_ci(boot, "communality_B", tn)
    rows[[length(rows) + 1L]] <- data.frame(
      trait = tn,
      index = "Communality (B)",
      estimate = unname(com_B[tn]),
      lower = ci$lower,
      upper = ci$upper,
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(com_W)) {
    ci <- pull_ci(boot, "communality_W", tn)
    rows[[length(rows) + 1L]] <- data.frame(
      trait = tn,
      index = "Communality (W)",
      estimate = unname(com_W[tn]),
      lower = ci$lower,
      upper = ci$upper,
      stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$has_interval <- is.finite(dat$lower) & is.finite(dat$upper)
  dat$interval_method <- ifelse(dat$has_interval, "bootstrap", "none")
  dat$interval_status <- ifelse(
    dat$has_interval,
    "provided",
    if (is.null(boot)) "none" else "missing"
  )

  ## Order by repeatability descending if available, else by name
  if (!is.null(rep)) {
    trait_order <- names(sort(rep, decreasing = TRUE))
  } else {
    trait_order <- tn
  }
  dat$trait <- factor(dat$trait, levels = rev(trait_order))
  dat$index <- factor(
    dat$index,
    levels = c("Repeatability", "Communality (B)", "Communality (W)")
  )

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(
      x = .data$estimate,
      y = .data$trait,
      colour = .data$index,
      shape = .data$index
    )
  ) +
    ggplot2::geom_point(
      size = 3,
      position = ggplot2::position_dodge(width = 0.5)
    )

  if (any(dat$has_interval)) {
    p <- p +
      ggplot2::geom_errorbar(
        data = dat[dat$has_interval, , drop = FALSE],
        ggplot2::aes(xmin = .data$lower, xmax = .data$upper),
        orientation = "y",
        width = 0.2,
        position = ggplot2::position_dodge(width = 0.5)
      )
  }
  if (any(dat$interval_status == "missing")) {
    p <- p +
      ggplot2::geom_point(
        data = dat[dat$interval_status == "missing", , drop = FALSE],
        ggplot2::aes(x = .data$estimate, y = .data$trait),
        inherit.aes = FALSE,
        shape = 1,
        colour = .gtmb_plot_palette[["ink"]],
        size = 4,
        stroke = 0.8,
        position = ggplot2::position_dodge(width = 0.5)
      )
  }

  p <- p +
    ggplot2::scale_colour_manual(
      values = c(
        "Repeatability" = .gtmb_plot_palette[["blue"]],
        "Communality (B)" = .gtmb_plot_palette[["green"]],
        "Communality (W)" = .gtmb_plot_palette[["orange"]]
      )
    ) +
    ggplot2::scale_shape_manual(
      values = c(
        "Repeatability" = 16,
        "Communality (B)" = 17,
        "Communality (W)" = 15
      )
    ) +
    ggplot2::scale_x_continuous(limits = c(0, 1)) +
    ggplot2::labs(
      x = "Estimate",
      y = NULL,
      colour = NULL,
      shape = NULL,
      title = "Integration indices by trait",
      caption = if (
        any(dat$has_interval) && any(dat$interval_status == "missing")
      ) {
        "Whiskers show supplied bootstrap intervals; open rings mark requested intervals that were missing."
      } else if (any(dat$has_interval)) {
        "Whiskers show supplied bootstrap intervals."
      } else {
        "Point estimates only; no intervals supplied."
      }
    ) +
    .gtmb_theme_figure()

  .gtmb_plot_contract(
    p,
    type = "integration",
    source = "extract_ICC_site + extract_communality",
    level = c("unit", "unit_obs"),
    interval_status = .gtmb_interval_status(dat$interval_status),
    data = dat
  )
}


# ---- communality / uniqueness --------------------------------------------

.communality_ci_from_boot <- function(boot, level, traits) {
  empty <- function(status) {
    data.frame(
      trait = traits,
      lower = rep(NA_real_, length(traits)),
      upper = rep(NA_real_, length(traits)),
      interval_status = status,
      stringsAsFactors = FALSE
    )
  }
  if (is.null(boot)) {
    return(empty("none"))
  }

  if (inherits(boot, "bootstrap_Sigma")) {
    ci <- tryCatch(
      suppressMessages(extract_communality(
        boot,
        level = .canonical_level_name(level),
        ci = TRUE
      )),
      error = function(e) NULL
    )
  } else {
    ci <- boot[[paste0("communality_", level)]]
  }
  if (is.null(ci)) {
    return(empty("missing"))
  }
  ci <- ci[match(traits, ci$trait), , drop = FALSE]
  lower <- if ("lower" %in% names(ci)) {
    ci$lower
  } else {
    rep(NA_real_, length(traits))
  }
  upper <- if ("upper" %in% names(ci)) {
    ci$upper
  } else {
    rep(NA_real_, length(traits))
  }
  has_interval <- is.finite(lower) & is.finite(upper)
  data.frame(
    trait = traits,
    lower = lower,
    upper = upper,
    interval_status = ifelse(has_interval, "provided", "missing"),
    stringsAsFactors = FALSE
  )
}

.communality_plot_data_gtmb <- function(fit, boot = NULL) {
  tn <- .gtmb_trait_names(fit)
  rows <- list()
  if (isTRUE(fit$use$rr_B)) {
    c2 <- suppressMessages(extract_communality(fit, level = "unit"))
    if (!is.null(c2)) {
      ci <- .communality_ci_from_boot(boot, "B", tn)
      rows[[length(rows) + 1L]] <- data.frame(
        trait = tn,
        level = "unit",
        communality = unname(c2[tn]),
        lower = ci$lower,
        upper = ci$upper,
        interval_status = ci$interval_status,
        stringsAsFactors = FALSE
      )
    }
  }
  if (isTRUE(fit$use$rr_W)) {
    c2 <- suppressMessages(extract_communality(fit, level = "unit_obs"))
    if (!is.null(c2)) {
      ci <- .communality_ci_from_boot(boot, "W", tn)
      rows[[length(rows) + 1L]] <- data.frame(
        trait = tn,
        level = "unit_obs",
        communality = unname(c2[tn]),
        lower = ci$lower,
        upper = ci$upper,
        interval_status = ci$interval_status,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) {
    cli::cli_abort("No communality is available -- fit a latent() term first.")
  }

  dat <- do.call(rbind, rows)
  dat$uniqueness <- pmax(0, 1 - dat$communality)
  dat$has_interval <- is.finite(dat$lower) & is.finite(dat$upper)
  dat$interval_method <- ifelse(dat$has_interval, "bootstrap", "none")
  dat$trait <- factor(dat$trait, levels = rev(tn))
  dat$level <- factor(dat$level, levels = c("unit", "unit_obs"))

  shared <- data.frame(
    trait = dat$trait,
    level = dat$level,
    component = "Shared latent (c^2)",
    proportion = dat$communality,
    communality = dat$communality,
    lower = dat$lower,
    upper = dat$upper,
    has_interval = dat$has_interval,
    interval_method = dat$interval_method,
    interval_status = dat$interval_status,
    stringsAsFactors = FALSE
  )
  unique <- data.frame(
    trait = dat$trait,
    level = dat$level,
    component = "Trait-specific uniqueness",
    proportion = dat$uniqueness,
    communality = dat$communality,
    lower = ifelse(dat$has_interval, pmax(0, 1 - dat$upper), NA_real_),
    upper = ifelse(dat$has_interval, pmin(1, 1 - dat$lower), NA_real_),
    has_interval = dat$has_interval,
    interval_method = dat$interval_method,
    interval_status = dat$interval_status,
    stringsAsFactors = FALSE
  )
  out <- rbind(shared, unique)
  out$component <- factor(
    out$component,
    levels = c("Shared latent (c^2)", "Trait-specific uniqueness")
  )
  out
}

.plot_communality_gtmb <- function(fit, boot = NULL) {
  dat <- .communality_plot_data_gtmb(fit, boot = boot)
  levels_available <- as.character(unique(dat$level))
  ci_dat <- dat[dat$component == "Shared latent (c^2)", , drop = FALSE]
  ci_dat <- ci_dat[!duplicated(ci_dat[c("trait", "level")]), , drop = FALSE]

  pal <- c(
    "Shared latent (c^2)" = .gtmb_plot_palette[["green"]],
    "Trait-specific uniqueness" = "#D0D0D0"
  )

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(x = .data$proportion, y = .data$trait, fill = .data$component)
  ) +
    ggplot2::geom_col(
      position = "stack",
      colour = "white",
      linewidth = 0.25,
      width = 0.72
    )

  if (any(ci_dat$has_interval)) {
    p <- p +
      ggplot2::geom_errorbar(
        data = ci_dat[ci_dat$has_interval, , drop = FALSE],
        ggplot2::aes(
          xmin = .data$lower,
          xmax = .data$upper,
          y = .data$trait
        ),
        inherit.aes = FALSE,
        orientation = "y",
        width = 0.18,
        linewidth = 0.45,
        colour = .gtmb_plot_palette[["ink"]]
      ) +
      ggplot2::geom_point(
        data = ci_dat[ci_dat$has_interval, , drop = FALSE],
        ggplot2::aes(x = .data$communality, y = .data$trait),
        inherit.aes = FALSE,
        size = 1.8,
        colour = .gtmb_plot_palette[["ink"]]
      )
  }
  if (any(ci_dat$interval_status == "missing")) {
    p <- p +
      ggplot2::geom_point(
        data = ci_dat[ci_dat$interval_status == "missing", , drop = FALSE],
        ggplot2::aes(x = .data$communality, y = .data$trait),
        inherit.aes = FALSE,
        shape = 1,
        size = 2.8,
        stroke = 0.75,
        colour = .gtmb_plot_palette[["ink"]]
      )
  }

  caption <- if (any(ci_dat$has_interval)) {
    paste(
      "Bars partition each trait into c^2 and 1 - c^2.",
      "Black points and whiskers show supplied bootstrap intervals for c^2.",
      "Read communality with rank and convergence diagnostics.",
      sep = "\n"
    )
  } else if (any(ci_dat$interval_status == "missing")) {
    paste(
      "Bars partition each trait into c^2 and 1 - c^2.",
      "Open rings mark requested bootstrap intervals that were missing.",
      "Read communality with rank and convergence diagnostics.",
      sep = "\n"
    )
  } else {
    paste(
      "Shared latent bars show c^2; grey bars show 1 - c^2.",
      "Read communality with rank and convergence diagnostics.",
      sep = "\n"
    )
  }

  p <- p +
    ggplot2::scale_fill_manual(values = pal, name = NULL) +
    ggplot2::scale_x_continuous(
      limits = c(0, 1.001),
      labels = function(x) paste0(round(100 * x), "%"),
      expand = ggplot2::expansion(mult = c(0, 0.02))
    ) +
    ggplot2::facet_wrap(~level) +
    ggplot2::labs(
      x = "Proportion of trait variance",
      y = NULL,
      title = "Communality and uniqueness by trait",
      caption = caption
    ) +
    .gtmb_theme_figure() +
    ggplot2::theme(panel.spacing.x = grid::unit(18, "pt"))

  .gtmb_plot_contract(
    p,
    type = "communality",
    source = "extract_communality",
    level = levels_available,
    interval_status = .gtmb_interval_status(ci_dat$interval_status),
    data = dat
  )
}


# ---- variance partition ---------------------------------------------------

.plot_variance_gtmb <- function(fit) {
  dat <- suppressMessages(extract_proportions(fit, format = "long"))
  ## extract_proportions already returns trait + component as factors,
  ## variance + proportion numeric.

  component_labels <- c(
    shared_phy = "Shared phylogenetic",
    shared_unit = "Shared between-unit",
    unique_unit = "Unique between-unit",
    shared_unit_obs = "Shared within-unit",
    unique_unit_obs = "Unique within-unit",
    link_residual = "Link residual"
  )
  dat$component_label <- unname(component_labels[as.character(dat$component)])
  dat$component_label[is.na(dat$component_label)] <- as.character(
    dat$component[is.na(dat$component_label)]
  )
  component_levels <- c(
    unname(component_labels[component_labels %in% dat$component_label]),
    setdiff(unique(dat$component_label), unname(component_labels))
  )
  dat$component_label <- factor(
    dat$component_label,
    levels = component_levels
  )

  ## Stable colourblind-friendly component palette.
  pal <- c(
    "Shared phylogenetic" = .gtmb_plot_palette[["purple"]],
    "Shared between-unit" = .gtmb_plot_palette[["blue"]],
    "Unique between-unit" = .gtmb_plot_palette[["sky"]],
    "Shared within-unit" = .gtmb_plot_palette[["vermillion"]],
    "Unique within-unit" = .gtmb_plot_palette[["orange"]],
    "Link residual" = "#BDBDBD"
  )
  ## Drop entries the data does not contain (so the legend is tight)
  pal <- pal[intersect(names(pal), levels(dat$component_label))]

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(
      x = .data$proportion,
      y = .data$trait,
      fill = .data$component_label
    )
  ) +
    ggplot2::geom_col(
      position = "stack",
      colour = "white",
      linewidth = 0.25,
      width = 0.72
    ) +
    ggplot2::scale_fill_manual(values = pal, name = "Component") +
    ggplot2::scale_x_continuous(
      limits = c(0, 1.001),
      expand = ggplot2::expansion(mult = c(0, 0.02))
    ) +
    ggplot2::labs(
      x = "Proportion of variance",
      y = NULL,
      title = "Variance decomposition by trait",
      caption = paste(
        "Point decomposition from extract_proportions();",
        "shared/unique splits should be interpreted with diagnostics."
      )
    ) +
    .gtmb_theme_figure()

  .gtmb_plot_contract(
    p,
    type = "variance",
    source = "extract_proportions",
    level = c("unit", "unit_obs"),
    data = dat
  )
}


# ---- ordination biplot ----------------------------------------------------

.plot_ordination_gtmb <- function(
  fit,
  level,
  axes = c(1L, 2L),
  rotation = c("varimax", "none", "promax"),
  order_axes = TRUE,
  sign_anchor = c("auto", "none"),
  anchor_traits = NULL,
  standardize_loadings = FALSE
) {
  rotation <- match.arg(rotation)
  sign_anchor <- match.arg(sign_anchor)
  ## The dispatcher supplies "B" when the user omits level; an explicit
  ## ordination request with multiple levels is still ambiguous.
  if (missing(level) || is.null(level) || length(level) != 1L) {
    cli::cli_abort(
      "Specify a single {.arg level} for ordination: {.val unit} or {.val unit_obs}."
    )
  }
  if (!level %in% c("B", "W")) {
    cli::cli_abort("{.arg level} must be {.val unit} or {.val unit_obs}.")
  }
  level_label <- .canonical_level_name(level)

  rotation_info <- NULL
  ord_source <- "extract_ordination"
  rotation_status <- "rotation_ambiguous_loadings"
  if (rotation == "none") {
    ord <- suppressMessages(extract_ordination(
      fit,
      level = level_label
    ))
    if (is.null(ord)) {
      cli::cli_abort(
        "No {.code latent()} term at level {.val {level_label}}; nothing to plot."
      )
    }
    L <- ord$loadings
    Sc <- ord$scores
  } else {
    rotation_info <- suppressMessages(rotate_loadings(
      fit,
      level = level_label,
      method = rotation,
      order_axes = order_axes,
      sign_anchor = sign_anchor,
      anchor_traits = anchor_traits
    ))
    L <- rotation_info$Lambda
    Sc <- rotation_info$scores
    ord_source <- "rotate_loadings"
    rotation_status <- .gtmb_ordination_rotation_status(
      rotation,
      order_axes = order_axes,
      sign_anchor = sign_anchor
    )
  }
  if (is.null(rownames(L))) {
    rownames(L) <- .gtmb_trait_names(fit)
  }
  loading_scale <- "raw"
  if (isTRUE(standardize_loadings)) {
    L <- .standardize_loadings_by_total_variance(
      fit,
      Lambda = L,
      level = level_label
    )
    loading_scale <- "standardized"
  }
  d <- ncol(L)
  rotation_caption <- .gtmb_ordination_rotation_caption(
    rotation,
    order_axes = order_axes,
    sign_anchor = sign_anchor,
    anchor_traits = anchor_traits,
    rotation_info = rotation_info
  )
  rotation_data <- if (is.null(rotation_info)) {
    list(
      method = "none",
      order_axes = FALSE,
      sign_anchor = "none"
    )
  } else {
    list(
      method = rotation_info$method,
      order_axes = isTRUE(order_axes),
      sign_anchor = sign_anchor,
      axis_variance = rotation_info$axis_variance,
      axis_order = rotation_info$axis_order,
      axis_sign = rotation_info$axis_sign,
      anchor_traits = rotation_info$anchor_traits,
      loading_scale = loading_scale
    )
  }
  if (is.null(rotation_info)) {
    rotation_data$loading_scale <- loading_scale
  }

  if (d == 1L) {
    ## 1D lollipop along x-axis, traits on x, points at y = 0.
    dat_l <- data.frame(
      trait = rownames(L),
      loading = L[, 1L],
      display_scale = 1,
      stringsAsFactors = FALSE
    )
    dat_s <- data.frame(
      x = Sc[, 1L],
      y = 0,
      stringsAsFactors = FALSE
    )
    p <- ggplot2::ggplot() +
      ggplot2::geom_hline(
        yintercept = 0,
        colour = .gtmb_plot_palette[["grid"]]
      ) +
      ggplot2::geom_point(
        data = dat_s,
        ggplot2::aes(x = .data$x, y = .data$y),
        colour = .gtmb_plot_palette[["grey"]],
        alpha = 0.45
      ) +
      ggplot2::geom_segment(
        data = dat_l,
        ggplot2::aes(
          x = .data$loading,
          xend = .data$loading,
          y = 0,
          yend = 0.5 * sign(.data$loading) + ifelse(.data$loading == 0, 0.3, 0)
        ),
        colour = .gtmb_plot_palette[["vermillion"]],
        linewidth = 0.7
      ) +
      ggplot2::geom_point(
        data = dat_l,
        ggplot2::aes(
          x = .data$loading,
          y = 0.5 * sign(.data$loading) + ifelse(.data$loading == 0, 0.3, 0)
        ),
        colour = .gtmb_plot_palette[["vermillion"]],
        size = 2.3
      ) +
      ggplot2::geom_text(
        data = dat_l,
        ggplot2::aes(
          x = .data$loading,
          y = 0.5 * sign(.data$loading) + ifelse(.data$loading == 0, 0.3, 0),
          label = .data$trait
        ),
        colour = .gtmb_plot_palette[["vermillion"]],
        vjust = -0.5,
        size = 3.5
      ) +
      ggplot2::labs(
        x = "LV1",
        y = NULL,
        title = paste0("Level ", level_label, ": 1D ordination"),
        caption = .gtmb_caption_lines(
          if (loading_scale == "standardized") {
            "Trait positions show standardized loadings on LV1."
          } else {
            "Trait positions show raw loadings on LV1."
          },
          rotation_caption
        )
      ) +
      .gtmb_theme_figure() +
      ggplot2::theme(
        axis.text.y = ggplot2::element_blank(),
        axis.ticks.y = ggplot2::element_blank()
      )
    return(.gtmb_plot_contract(
      p,
      type = "ordination",
      source = ord_source,
      level = level_label,
      rotation_status = rotation_status,
      data = list(scores = dat_s, loadings = dat_l, rotation = rotation_data)
    ))
  }

  ## d >= 2: 2D biplot or 3-axis pair-grid.
  axes <- as.integer(axes)
  if (d == 3L && identical(axes, c(1L, 2L))) {
    axes <- 1:3
  }
  if (!length(axes) %in% c(2L, 3L)) {
    cli::cli_abort("{.arg axes} must be length 2 or length 3.")
  }
  if (anyDuplicated(axes)) {
    cli::cli_abort("{.arg axes} must contain unique axis numbers.")
  }
  if (min(axes) < 1L) {
    cli::cli_abort("{.arg axes} must contain positive axis numbers.")
  }
  if (max(axes) > d) {
    cli::cli_abort(
      "Requested {.arg axes = c({paste(axes, collapse = ', ')})} exceed d_{level_label} = {d}."
    )
  }

  if (length(axes) == 3L) {
    axis_pairs <- utils::combn(axes, 2L)
    selected_scores <- Sc[, axes, drop = FALSE]
    span <- max(abs(selected_scores), na.rm = TRUE)
    loading_max <- max(abs(L[, axes, drop = FALSE]), 1e-9)
    sc <- 0.7 * span / loading_max

    score_rows <- vector("list", ncol(axis_pairs))
    loading_rows <- vector("list", ncol(axis_pairs))
    for (j in seq_len(ncol(axis_pairs))) {
      a1 <- axis_pairs[1L, j]
      a2 <- axis_pairs[2L, j]
      pair_label <- paste0("LV", a1, " vs LV", a2)
      score_rows[[j]] <- data.frame(
        row_id = rownames(Sc) %||% seq_len(nrow(Sc)),
        x = Sc[, a1],
        y = Sc[, a2],
        axis_x = paste0("LV", a1),
        axis_y = paste0("LV", a2),
        pair = pair_label,
        stringsAsFactors = FALSE
      )
      loading_rows[[j]] <- data.frame(
        trait = rownames(L),
        loading_x = L[, a1],
        loading_y = L[, a2],
        x = L[, a1] * sc,
        y = L[, a2] * sc,
        axis_x = paste0("LV", a1),
        axis_y = paste0("LV", a2),
        pair = pair_label,
        display_scale = sc,
        stringsAsFactors = FALSE
      )
    }
    dat_s <- do.call(rbind, score_rows)
    dat_l <- do.call(rbind, loading_rows)
    dat_l <- .gtmb_arrow_label_positions(dat_l, group_col = "pair")
    dat_s$pair <- factor(dat_s$pair, levels = unique(dat_s$pair))
    dat_l$pair <- factor(dat_l$pair, levels = levels(dat_s$pair))

    p <- ggplot2::ggplot() +
      ggplot2::geom_hline(
        yintercept = 0,
        colour = .gtmb_plot_palette[["grid"]],
        linetype = "dashed"
      ) +
      ggplot2::geom_vline(
        xintercept = 0,
        colour = .gtmb_plot_palette[["grid"]],
        linetype = "dashed"
      ) +
      ggplot2::geom_point(
        data = dat_s,
        ggplot2::aes(x = .data$x, y = .data$y),
        colour = .gtmb_plot_palette[["grey"]],
        alpha = 0.35,
        size = 1.4
      ) +
      ggplot2::geom_segment(
        data = dat_l,
        ggplot2::aes(x = 0, y = 0, xend = .data$x, yend = .data$y),
        arrow = ggplot2::arrow(length = ggplot2::unit(0.18, "cm")),
        colour = .gtmb_plot_palette[["vermillion"]],
        linewidth = 0.65
      ) +
      ggplot2::geom_text(
        data = dat_l,
        ggplot2::aes(
          x = .data$label_x,
          y = .data$label_y,
          label = .data$trait,
          hjust = .data$label_hjust,
          vjust = .data$label_vjust
        ),
        colour = .gtmb_plot_palette[["vermillion"]],
        size = 3.2
      ) +
      ggplot2::coord_equal() +
      ggplot2::facet_wrap(~pair, nrow = 1L) +
      ggplot2::labs(
        x = "Latent score / display-scaled loading",
        y = "Latent score / display-scaled loading",
        title = paste0("Level ", level_label, ": 3D ordination pair grid"),
        caption = .gtmb_caption_lines(
          "Each panel shows one pair of latent axes from the same 3D ordination.",
          "Grey points are latent scores; arrows are display-scaled trait loadings.",
          if (loading_scale == "standardized") {
            "Trait arrows use standardized loadings."
          } else {
            "Trait arrows use raw loadings."
          },
          rotation_caption
        )
      ) +
      .gtmb_theme_figure()

    return(.gtmb_plot_contract(
      p,
      type = "ordination",
      source = ord_source,
      level = level_label,
      rotation_status = rotation_status,
      data = list(scores = dat_s, loadings = dat_l, rotation = rotation_data),
      notes = "3D ordination is shown as a static pair grid, not a perspective 3D rendering."
    ))
  }

  a1 <- axes[1L]
  a2 <- axes[2L]

  dat_s <- data.frame(
    x = Sc[, a1],
    y = Sc[, a2],
    stringsAsFactors = FALSE
  )
  ## Scale loadings to the score range so arrows are visible alongside points.
  span <- max(abs(c(dat_s$x, dat_s$y)), na.rm = TRUE)
  loading_max <- max(abs(L[, c(a1, a2)]), 1e-9)
  sc <- 0.7 * span / loading_max
  dat_l <- data.frame(
    trait = rownames(L),
    loading_x = L[, a1],
    loading_y = L[, a2],
    x = L[, a1] * sc,
    y = L[, a2] * sc,
    display_scale = sc,
    stringsAsFactors = FALSE
  )
  dat_l <- .gtmb_arrow_label_positions(dat_l)

  p <- ggplot2::ggplot() +
    ggplot2::geom_hline(
      yintercept = 0,
      colour = .gtmb_plot_palette[["grid"]],
      linetype = "dashed"
    ) +
    ggplot2::geom_vline(
      xintercept = 0,
      colour = .gtmb_plot_palette[["grid"]],
      linetype = "dashed"
    ) +
    ggplot2::geom_point(
      data = dat_s,
      ggplot2::aes(x = .data$x, y = .data$y),
      colour = .gtmb_plot_palette[["grey"]],
      alpha = 0.45
    ) +
    ggplot2::geom_segment(
      data = dat_l,
      ggplot2::aes(x = 0, y = 0, xend = .data$x, yend = .data$y),
      arrow = ggplot2::arrow(length = ggplot2::unit(0.2, "cm")),
      colour = .gtmb_plot_palette[["vermillion"]],
      linewidth = 0.7
    ) +
    ggplot2::geom_text(
      data = dat_l,
      ggplot2::aes(
        x = .data$label_x,
        y = .data$label_y,
        label = .data$trait,
        hjust = .data$label_hjust,
        vjust = .data$label_vjust
      ),
      colour = .gtmb_plot_palette[["vermillion"]],
      size = 3.5
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      x = paste0("LV", a1),
      y = paste0("LV", a2),
      title = paste0("Level ", level_label, ": ordination biplot"),
      caption = .gtmb_caption_lines(
        "Grey points are latent scores; arrows are display-scaled trait loadings.",
        if (loading_scale == "standardized") {
          "Trait arrows use standardized loadings."
        } else {
          "Trait arrows use raw loadings."
        },
        rotation_caption
      )
    ) +
    .gtmb_theme_figure()

  .gtmb_plot_contract(
    p,
    type = "ordination",
    source = ord_source,
    level = level_label,
    rotation_status = rotation_status,
    data = list(scores = dat_s, loadings = dat_l, rotation = rotation_data)
  )
}
