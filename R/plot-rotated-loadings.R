## Report-ready loading-matrix plots for rotated Lambda tables.

.gtmb_rotated_loading_caption <- function(dat) {
  rotation <- unique(as.character(dat$rotation))
  rotation <- rotation[!is.na(rotation)]
  if (length(rotation) == 0L) {
    rotation <- "unknown"
  }
  rotation <- paste(rotation, collapse = ", ")

  loading_scale <- unique(as.character(dat$loading_scale))
  loading_scale <- loading_scale[!is.na(loading_scale)]
  if (length(loading_scale) == 0L) {
    loading_scale <- "unknown"
  }
  loading_scale <- paste(loading_scale, collapse = ", ")

  order_axes <- unique(dat$order_axes)
  order_axes <- order_axes[!is.na(order_axes)]
  ordered <- length(order_axes) > 0L && all(order_axes)

  sign_anchor <- unique(as.character(dat$sign_anchor))
  sign_anchor <- sign_anchor[!is.na(sign_anchor)]
  sign_anchor <- paste(sign_anchor, collapse = ", ")

  if (identical(rotation, "none")) {
    rotation_note <- paste(
      "Raw loading orientation is shown;",
      "loading signs and rotations are computational conventions."
    )
  } else {
    order_note <- if (ordered) {
      "ordered by shared variance"
    } else {
      "kept in rotated-axis order"
    }
    sign_note <- if (identical(sign_anchor, "auto")) {
      "sign-anchored for positive anchor loadings"
    } else {
      "not sign-anchored"
    }
    rotation_note <- paste0(
      "Axes use ",
      rotation,
      " rotation, ",
      order_note,
      ", and ",
      sign_note,
      "."
    )
  }

  scale_note <- paste0("Displayed loadings are ", loading_scale, ".")
  invariant_note <- paste(
    "Use Sigma, correlations, communality, and uniqueness as the",
    "rotation-invariant summaries."
  )
  point_note <- "Point-estimate loadings only; no loading intervals are shown."

  .gtmb_caption_lines(
    rotation_note,
    scale_note,
    invariant_note,
    point_note
  )
}

.gtmb_rotated_loadings_rotation_status <- function(dat) {
  rotation <- unique(as.character(dat$rotation))
  rotation <- rotation[!is.na(rotation)]
  if (length(rotation) == 0L || identical(rotation, "none")) {
    return("rotation_ambiguous_loadings")
  }
  order_axes <- unique(dat$order_axes)
  order_axes <- order_axes[!is.na(order_axes)]
  sign_anchor <- unique(as.character(dat$sign_anchor))
  sign_anchor <- sign_anchor[!is.na(sign_anchor)]
  paste0(
    paste(rotation, collapse = "_"),
    if (length(order_axes) > 0L && all(order_axes)) {
      "_ordered"
    } else {
      "_raw_order"
    },
    if (length(sign_anchor) > 0L && all(sign_anchor == "auto")) {
      "_sign_anchored"
    } else {
      "_unanchored"
    }
  )
}

.gtmb_rotated_loadings_trait_order <- function(dat, sort) {
  sort <- match.arg(sort, c("dominant", "abs_loading", "trait"))
  traits <- unique(as.character(dat$trait))
  if (identical(sort, "trait")) {
    return(traits)
  }

  axes <- unique(as.character(dat$axis))
  pieces <- lapply(traits, function(trait) {
    rows <- dat[as.character(dat$trait) == trait, , drop = FALSE]
    hit <- which.max(rows$abs_loading)
    data.frame(
      trait = trait,
      dominant_axis = match(as.character(rows$axis[[hit]]), axes),
      dominant_loading = rows$loading[[hit]],
      dominant_abs_loading = rows$abs_loading[[hit]],
      stringsAsFactors = FALSE
    )
  })
  summary <- do.call(rbind, pieces)
  if (identical(sort, "dominant")) {
    ord <- order(
      summary$dominant_axis,
      -summary$dominant_abs_loading,
      summary$trait
    )
  } else {
    ord <- order(-summary$dominant_abs_loading, summary$trait)
  }
  summary$trait[ord]
}

.gtmb_prepare_rotated_loadings_plot_data <- function(dat, sort, digits) {
  .gtmb_require_plot_columns(
    dat,
    c(
      "level",
      "trait",
      "axis",
      "loading",
      "abs_loading",
      "axis_share",
      "rotation",
      "order_axes",
      "sign_anchor",
      "anchor_trait",
      "loading_scale"
    )
  )
  if (nrow(dat) == 0L) {
    cli::cli_abort("No rotated loading rows to plot.")
  }

  dat$level <- as.character(dat$level)
  dat$trait <- as.character(dat$trait)
  dat$axis <- as.character(dat$axis)
  dat$loading <- as.numeric(dat$loading)
  dat$abs_loading <- abs(dat$loading)
  dat$axis_share <- as.numeric(dat$axis_share)
  dat$.level_label <- .gtmb_pretty_levels(dat$level)

  trait_order <- .gtmb_rotated_loadings_trait_order(dat, sort = sort)
  dat$.trait_label <- factor(dat$trait, levels = rev(trait_order))

  axis_order <- unique(dat$axis)
  one_level <- length(unique(dat$level)) == 1L
  axis_labels <- stats::setNames(axis_order, axis_order)
  if (one_level && "axis_share" %in% names(dat)) {
    axis_share <- stats::aggregate(
      dat$axis_share,
      list(axis = dat$axis),
      function(x) {
        finite <- x[is.finite(x)]
        if (length(finite) > 0L) {
          finite[[1L]]
        } else {
          NA_real_
        }
      }
    )
    names(axis_share) <- c("axis", "axis_share")
    for (i in seq_len(nrow(axis_share))) {
      share <- axis_share$axis_share[[i]]
      if (is.finite(share)) {
        axis_labels[[axis_share$axis[[i]]]] <- sprintf(
          "%s (%.0f%%)",
          axis_share$axis[[i]],
          100 * share
        )
      }
    }
  }
  dat$.axis_label <- factor(
    unname(axis_labels[dat$axis]),
    levels = unname(axis_labels[axis_order])
  )
  dat$.label <- formatC(dat$loading, digits = digits, format = "f")
  dat$.label_colour <- .gtmb_tile_label_colour(
    dat$loading,
    threshold = 0.62,
    relative = TRUE
  )
  dat
}

#' Plot a rotated loading matrix
#'
#' `plot_rotated_loadings()` turns the tidy rows from
#' [extract_rotated_loadings_table()] into a publication-oriented loading
#' matrix. It can also extract the table from a fitted [gllvmTMB()] model.
#' Rows are traits, columns are latent axes, and colour shows the signed
#' loading after the requested rotation, axis ordering, sign anchoring, and
#' loading scale.
#'
#' Scope boundary: IN, the helper plots point-estimate rotated loading rows
#' from [extract_rotated_loadings_table()] for fitted `latent()` components
#' (EXT-29; built on EXT-28). PARTIAL, the plot does not compute or display
#' loading uncertainty intervals and does not make rotated axes uniquely
#' biological. PLANNED, bootstrap- or simulation-aligned loading uncertainty
#' remains a later inference slice.
#'
#' @param x A fit returned by [gllvmTMB()] or a data frame returned by
#'   [extract_rotated_loadings_table()].
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit), passed
#'   to [extract_rotated_loadings_table()] when `x` is a fitted model.
#'   Deprecated aliases `"B"` and `"W"` are still accepted with a warning.
#' @param method One of `"varimax"`, `"promax"`, or `"none"`; passed to
#'   [extract_rotated_loadings_table()] for fitted-model calls.
#' @param order_axes Logical. When `TRUE`, reorder rotated axes by decreasing
#'   raw shared variance before plotting. Ignored when `method = "none"`.
#' @param sign_anchor One of `"auto"` or `"none"`. `"auto"` flips each rotated
#'   axis so its anchor trait has a positive loading. Ignored when
#'   `method = "none"`.
#' @param anchor_traits Optional character vector of trait names used for sign
#'   anchoring. Supply one trait per axis after ordering. Axes without a
#'   supplied anchor use the trait with the largest absolute loading.
#' @param loading_scale One of `"standardized"` or `"raw"` for fitted-model
#'   calls. The default `"standardized"` puts loadings on a correlation-like
#'   scale for figures. Ignored when `x` is already a data frame.
#' @param sort Trait ordering. `"dominant"` groups traits by the axis on which
#'   they have their largest absolute loading. `"abs_loading"` orders by each
#'   trait's largest absolute loading. `"trait"` preserves the incoming trait
#'   order.
#' @param show_values Logical or `NULL`. When `NULL`, numeric tile labels are
#'   shown for matrices with at most 80 cells.
#' @param digits Number of decimal places for tile labels.
#' @param limits Optional two-number colour-scale limits. When `NULL`, limits
#'   are symmetric around zero and based on the plotted loadings.
#' @param facet One of `"level"` or `"none"`. Data frames containing more than
#'   one covariance level are faceted by level by default.
#'
#' @return A `ggplot2` plot object with `gllvmTMB_meta` and `gllvmTMB_data`
#'   attributes.
#' @seealso [extract_rotated_loadings_table()], [rotate_loadings()],
#'   [plot.gllvmTMB_multi()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   rows <- data.frame(
#'     level = "unit",
#'     trait = rep(c("body", "wing", "bill"), times = 2),
#'     axis = rep(c("LV1", "LV2"), each = 3),
#'     loading = c(0.72, 0.61, -0.08, 0.05, -0.18, 0.66),
#'     abs_loading = abs(c(0.72, 0.61, -0.08, 0.05, -0.18, 0.66)),
#'     axis_variance = rep(c(1.1, 0.5), each = 3),
#'     axis_share = rep(c(0.69, 0.31), each = 3),
#'     rotation = "varimax",
#'     order_axes = TRUE,
#'     sign_anchor = "auto",
#'     anchor_trait = rep(c("body", "bill"), each = 3),
#'     loading_scale = "standardized"
#'   )
#'   plot_rotated_loadings(rows)
#' }
plot_rotated_loadings <- function(
  x,
  level = "unit",
  method = c("varimax", "promax", "none"),
  order_axes = TRUE,
  sign_anchor = c("auto", "none"),
  anchor_traits = NULL,
  loading_scale = c("standardized", "raw"),
  sort = c("dominant", "abs_loading", "trait"),
  show_values = NULL,
  digits = 2L,
  limits = NULL,
  facet = c("level", "none")
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Install ggplot2: {.code install.packages(\"ggplot2\")}.")
  }
  method <- match.arg(method)
  sign_anchor <- match.arg(sign_anchor)
  loading_scale <- match.arg(loading_scale)
  sort <- match.arg(sort)
  facet <- match.arg(facet)
  if (!is.null(show_values)) {
    if (
      !is.logical(show_values) ||
        length(show_values) != 1L ||
        is.na(show_values)
    ) {
      cli::cli_abort("{.arg show_values} must be TRUE, FALSE, or NULL.")
    }
  }
  if (
    !is.numeric(digits) ||
      length(digits) != 1L ||
      is.na(digits) ||
      digits < 0
  ) {
    cli::cli_abort("{.arg digits} must be a non-negative integer.")
  }
  digits <- as.integer(digits)
  if (!is.null(limits)) {
    if (
      !is.numeric(limits) ||
        length(limits) != 2L ||
        any(!is.finite(limits)) ||
        limits[[1L]] >= limits[[2L]]
    ) {
      cli::cli_abort(
        "{.arg limits} must be a finite numeric vector of length 2."
      )
    }
  }

  source_label <- "extract_rotated_loadings_table"
  if (inherits(x, "gllvmTMB_multi")) {
    dat <- extract_rotated_loadings_table(
      x,
      level = level,
      method = method,
      order_axes = order_axes,
      sign_anchor = sign_anchor,
      anchor_traits = anchor_traits,
      loading_scale = loading_scale
    )
  } else if (is.data.frame(x)) {
    dat <- x
    source_label <- "data"
  } else {
    cli::cli_abort(
      "{.arg x} must be a fit returned by {.fun gllvmTMB} or a data frame from {.fun extract_rotated_loadings_table}."
    )
  }

  dat <- .gtmb_prepare_rotated_loadings_plot_data(
    dat,
    sort = sort,
    digits = digits
  )
  show_values <- if (is.null(show_values)) {
    nrow(dat) <= 80L
  } else {
    isTRUE(show_values)
  }
  if (is.null(limits)) {
    limits <- .gtmb_symmetric_limits(dat$loading)
  }

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(
      x = .data$.axis_label,
      y = .data$.trait_label,
      fill = .data$loading
    )
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.45)

  if (show_values) {
    p <- p +
      ggplot2::geom_text(
        ggplot2::aes(label = .data$.label, colour = .data$.label_colour),
        size = 3
      ) +
      ggplot2::scale_colour_identity()
  }

  p <- p +
    .gtmb_scale_fill_diverging("Loading", limits = limits) +
    ggplot2::scale_x_discrete(expand = ggplot2::expansion(mult = 0.02)) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(mult = 0.02)) +
    ggplot2::labs(
      x = "Latent axis",
      y = NULL,
      title = "Rotated loading matrix",
      subtitle = "Rows are traits; columns are interpretable latent axes.",
      caption = .gtmb_rotated_loading_caption(dat)
    ) +
    .gtmb_theme_figure() +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(face = "bold"),
      legend.position = "right"
    )

  if (
    identical(facet, "level") &&
      length(unique(dat$.level_label)) > 1L
  ) {
    p <- p + ggplot2::facet_wrap(~.level_label, ncol = 1L)
  }

  .gtmb_plot_contract(
    p,
    type = "rotated_loadings",
    source = source_label,
    level = unique(dat$level),
    interval_status = "none",
    rotation_status = .gtmb_rotated_loadings_rotation_status(dat),
    data = dat
  )
}
