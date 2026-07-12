## Publication-ready forest plots for tidy covariance/correlation tables.
## These helpers sit above extract_correlations() and extract_Sigma_table()
## so articles can plot report-ready rows without matrix indexing.

.gtmb_require_plot_columns <- function(data, required, data_arg = "x") {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "{.arg {data_arg}} is missing required column{?s}: {.field {missing}}.",
      "i" = "Pass the output of {.fun extract_correlations} or {.fun extract_Sigma_table}, or supply a data frame with the same columns."
    ))
  }
}

.gtmb_pretty_levels <- function(level) {
  level <- as.character(level)
  vapply(
    level,
    function(x) {
      .canonical_level_name(.normalise_level(x, .skip_warn = TRUE))
    },
    character(1L),
    USE.NAMES = FALSE
  )
}

.gtmb_pair_label <- function(trait_i, trait_j, diagonal = FALSE) {
  diagonal <- rep_len(diagonal, length(trait_i))
  out <- paste0(trait_i, " - ", trait_j)
  out[diagonal] <- paste0(trait_i[diagonal], " variance")
  out
}

.gtmb_correlations_from_bootstrap <- function(boot, tier, pair = NULL) {
  rows <- extract_Sigma_table(
    boot,
    level = tier,
    measure = "correlation",
    entries = "upper"
  )
  if (nrow(rows) == 0L) {
    return(data.frame(
      tier = character(0),
      trait_i = character(0),
      trait_j = character(0),
      correlation = numeric(0),
      lower = numeric(0),
      upper = numeric(0),
      method = character(0),
      stringsAsFactors = FALSE
    ))
  }
  if (!is.null(pair)) {
    if (!is.character(pair) || length(pair) != 2L) {
      cli::cli_abort("{.arg pair} must be a character vector of length 2.")
    }
    keep <- (rows$trait_i == pair[[1L]] & rows$trait_j == pair[[2L]]) |
      (rows$trait_i == pair[[2L]] & rows$trait_j == pair[[1L]])
    rows <- rows[keep, , drop = FALSE]
  }
  out <- data.frame(
    tier = rows$level,
    trait_i = rows$trait_i,
    trait_j = rows$trait_j,
    correlation = rows$estimate,
    lower = rows$lower,
    upper = rows$upper,
    method = rows$interval_method,
    stringsAsFactors = FALSE
  )
  attr(out, "notes") <- attr(rows, "notes") %||% character(0)
  attr(out, "bootstrap") <- attr(rows, "bootstrap")
  out
}

.gtmb_plot_sign <- function(x) {
  out <- rep("zero", length(x))
  out[x < 0] <- "negative"
  out[x > 0] <- "positive"
  factor(out, levels = c("negative", "zero", "positive"))
}

.gtmb_interval_state <- function(has_interval) {
  if (!any(has_interval)) {
    return("none")
  }
  if (all(has_interval)) {
    return("provided")
  }
  "partial"
}

.gtmb_uncertainty_caption <- function(has_uncertainty_display, style, missing) {
  if (!all(has_uncertainty_display)) {
    return(missing)
  }
  if (identical(style, "eye")) {
    return(
      "Confidence eyes reconstruct compatibility from finite interval bounds; they are not posterior densities."
    )
  }
  "Finite interval bounds are shown for all plotted rows."
}

.gtmb_resolve_interval_line <- function(show_intervals, style) {
  if (is.null(show_intervals)) {
    return(identical(style, "interval"))
  }
  if (
    !is.logical(show_intervals) ||
      length(show_intervals) != 1L ||
      is.na(show_intervals)
  ) {
    cli::cli_abort(
      "{.arg show_intervals} must be {.code TRUE}, {.code FALSE}, or {.code NULL}."
    )
  }
  isTRUE(show_intervals)
}

.gtmb_validate_interval_level <- function(level, arg = "eye_level") {
  if (
    !is.numeric(level) ||
      length(level) != 1L ||
      !is.finite(level) ||
      level <= 0 ||
      level >= 1
  ) {
    cli::cli_abort("{.arg {arg}} must be a single number between 0 and 1.")
  }
  level
}

.gtmb_normalise_uncertainty_style <- function(style) {
  style <- match.arg(style, c("interval", "eye", "raindrop"))
  if (identical(style, "raindrop")) {
    return("eye")
  }
  style
}

.gtmb_resolve_eye_level <- function(eye_level, raindrop_level = NULL) {
  if (!is.null(raindrop_level)) {
    return(.gtmb_validate_interval_level(
      raindrop_level,
      arg = "raindrop_level"
    ))
  }
  .gtmb_validate_interval_level(eye_level, arg = "eye_level")
}

.gtmb_order_pair_plot_rows <- function(dat, sort) {
  sort <- match.arg(sort, c("estimate", "magnitude", "trait", "level"))
  if (identical(sort, "estimate")) {
    order(dat$.facet, dat$.estimate, dat$.pair_label)
  } else if (identical(sort, "magnitude")) {
    order(dat$.facet, abs(dat$.estimate), dat$.pair_label)
  } else if (identical(sort, "level")) {
    order(dat$.facet, dat$.pair_label)
  } else {
    order(dat$.facet, dat$.pair_label)
  }
}

.gtmb_prepare_pair_plot_rows <- function(dat, sort, facet) {
  if (identical(facet, "none")) {
    multi_level <- length(unique(dat$.facet)) > 1L
    if (multi_level) {
      dat$.pair_label <- paste(dat$.pair_label, dat$.facet, sep = " | ")
    }
    dat$.facet <- "All rows"
  }
  ord <- .gtmb_order_pair_plot_rows(dat, sort)
  dat <- dat[ord, , drop = FALSE]
  dat$.row_key <- paste0(seq_len(nrow(dat)), "__", dat$.pair_label)
  dat$.y <- rev(seq_len(nrow(dat)))
  attr(dat, "row_labels") <- stats::setNames(
    dat$.pair_label,
    as.character(dat$.y)
  )
  dat
}

.gtmb_order_comparison_rows <- function(dat, sort) {
  sort <- match.arg(
    sort,
    c("abs_error", "error", "estimate", "truth", "trait", "level")
  )
  if (identical(sort, "abs_error")) {
    order(dat$.facet, dat$.abs_error, dat$.pair_label)
  } else if (identical(sort, "error")) {
    order(dat$.facet, dat$.error, dat$.pair_label)
  } else if (identical(sort, "estimate")) {
    order(dat$.facet, dat$.estimate, dat$.pair_label)
  } else if (identical(sort, "truth")) {
    order(dat$.facet, dat$.truth, dat$.pair_label)
  } else if (identical(sort, "level")) {
    order(dat$.facet, dat$.pair_label)
  } else {
    order(dat$.facet, dat$.pair_label)
  }
}

.gtmb_prepare_comparison_plot_rows <- function(dat, sort, facet) {
  if (identical(facet, "none")) {
    multi_level <- length(unique(dat$.facet)) > 1L
    if (multi_level) {
      dat$.pair_label <- paste(dat$.pair_label, dat$.facet, sep = " | ")
    }
    dat$.facet <- "All rows"
  }
  ord <- .gtmb_order_comparison_rows(dat, sort)
  dat <- dat[ord, , drop = FALSE]
  dat$.row_key <- paste0(seq_len(nrow(dat)), "__", dat$.pair_label)
  dat$.y <- rev(seq_len(nrow(dat)))
  attr(dat, "row_labels") <- stats::setNames(
    dat$.pair_label,
    as.character(dat$.y)
  )
  dat
}

.gtmb_heatmap_trait_levels <- function(dat) {
  trait <- c(as.character(dat$trait_i), as.character(dat$trait_j))
  if (all(c("i", "j") %in% names(dat))) {
    idx <- c(dat$i, dat$j)
    ord <- order(idx, trait)
    return(unique(trait[ord]))
  }
  unique(trait)
}

.gtmb_heatmap_label_colour <- function(x, is_correlation) {
  finite <- is.finite(x)
  if (!any(finite)) {
    return(rep("dark", length(x)))
  }
  limit <- if (is_correlation) {
    1
  } else {
    max(abs(x[finite]), na.rm = TRUE)
  }
  if (!is.finite(limit) || limit <= 0) {
    limit <- 1
  }
  ifelse(abs(x) / limit >= 0.55, "light", "dark")
}

.gtmb_plot_label_colour <- function(x, is_correlation) {
  key <- .gtmb_heatmap_label_colour(x, is_correlation = is_correlation)
  ifelse(
    key == "light",
    "white",
    .gtmb_plot_palette[["ink"]]
  )
}

.gtmb_validate_plot_labels <- function(label, label_digits) {
  if (!is.logical(label) || length(label) != 1L || is.na(label)) {
    cli::cli_abort("{.arg label} must be {.code TRUE} or {.code FALSE}.")
  }
  if (
    !is.numeric(label_digits) ||
      length(label_digits) != 1L ||
      is.na(label_digits) ||
      label_digits < 0 ||
      label_digits != floor(label_digits)
  ) {
    cli::cli_abort("{.arg label_digits} must be a non-negative whole number.")
  }
  invisible(TRUE)
}

.gtmb_validate_optional_text <- function(x, arg) {
  if (
    !is.null(x) &&
      (!is.character(x) || length(x) != 1L || is.na(x))
  ) {
    cli::cli_abort(
      "{.arg {arg}} must be {.code NULL} or a scalar character string."
    )
  }
  invisible(TRUE)
}

.gtmb_format_correlation_matrix_label <- function(dat, label_type, digits) {
  allowed <- c("estimate", "ci", "estimate_ci", "none")
  label_type <- as.character(label_type)
  if (length(label_type) == 1L) {
    label_type <- rep(label_type, nrow(dat))
  }
  if (length(label_type) != nrow(dat) || any(!label_type %in% allowed)) {
    cli::cli_abort(
      "{.arg label_type} must be one of {.val estimate}, {.val ci}, {.val estimate_ci}, or {.val none}."
    )
  }
  estimate <- ifelse(
    is.finite(dat$.estimate),
    sprintf(paste0("%.", digits, "f"), dat$.estimate),
    ""
  )
  estimate[dat$.diagonal] <- "1"
  ci <- ifelse(
    dat$.has_interval,
    paste0(
      "[",
      sprintf(paste0("%.", digits, "f"), dat$.lower),
      ", ",
      sprintf(paste0("%.", digits, "f"), dat$.upper),
      "]"
    ),
    ""
  )
  out <- rep("", nrow(dat))
  out[label_type == "estimate"] <- estimate[label_type == "estimate"]
  out[label_type == "ci"] <- ci[label_type == "ci"]
  estimate_ci <- label_type == "estimate_ci"
  out[estimate_ci] <- ifelse(
    nzchar(ci[estimate_ci]),
    paste(estimate[estimate_ci], ci[estimate_ci], sep = "\n"),
    estimate[estimate_ci]
  )
  out
}

.gtmb_orient_correlation_rows <- function(dat, trait_index, target) {
  row_trait <- as.character(dat$trait_i)
  col_trait <- as.character(dat$trait_j)
  row_index <- unname(trait_index[row_trait])
  col_index <- unname(trait_index[col_trait])
  flip <- if (identical(target, "upper")) {
    row_index > col_index
  } else {
    row_index < col_index
  }
  tmp <- row_trait[flip]
  row_trait[flip] <- col_trait[flip]
  col_trait[flip] <- tmp
  row_index <- unname(trait_index[row_trait])
  col_index <- unname(trait_index[col_trait])
  dat$.row_trait <- row_trait
  dat$.col_trait <- col_trait
  dat$.row_index <- row_index
  dat$.col_index <- col_index
  dat$.diagonal <- row_index == col_index
  dat$.triangle <- ifelse(
    row_index == col_index,
    "diagonal",
    ifelse(row_index < col_index, "upper", "lower")
  )
  dat
}

.gtmb_prepare_correlation_matrix_rows <- function(
  dat,
  triangle,
  include_diagonal,
  facet,
  label_type,
  label_digits,
  matrix_layout
) {
  triangle <- match.arg(triangle, c("full", "lower", "upper"))
  matrix_layout <- match.arg(
    matrix_layout,
    c("by_level", "estimate_ci", "levels")
  )
  if (
    !is.logical(include_diagonal) ||
      length(include_diagonal) != 1L ||
      is.na(include_diagonal)
  ) {
    cli::cli_abort(
      "{.arg include_diagonal} must be {.code TRUE} or {.code FALSE}."
    )
  }
  label_type <- match.arg(
    label_type,
    c("auto", "estimate", "ci", "estimate_ci", "none")
  )

  dat$tier <- as.character(dat$tier)
  dat$trait_i <- as.character(dat$trait_i)
  dat$trait_j <- as.character(dat$trait_j)
  dat$method <- as.character(dat$method)
  dat$.estimate <- dat$correlation
  dat$.lower <- dat$lower
  dat$.upper <- dat$upper
  dat$.has_interval <- is.finite(dat$.lower) & is.finite(dat$.upper)
  dat$.significant <- dat$.has_interval & dat$.lower * dat$.upper > 0
  dat$.facet <- .gtmb_pretty_levels(dat$tier)
  facet_levels <- unique(dat$.facet)
  if (identical(matrix_layout, "levels")) {
    level_priority <- c("unit", "unit_obs", "phy", "spatial")
    facet_levels <- unique(c(
      intersect(level_priority, facet_levels),
      setdiff(facet_levels, level_priority)
    ))
    if (length(facet_levels) != 2L) {
      cli::cli_abort(c(
        "{.code matrix_layout = \"levels\"} needs exactly two correlation levels.",
        "i" = "Use {.code matrix_layout = \"by_level\"} for one level or more than two levels."
      ))
    }
  }
  if (identical(facet, "none") && !identical(matrix_layout, "levels")) {
    if (length(facet_levels) > 1L) {
      cli::cli_abort(c(
        "{.code facet = \"none\"} is not available for matrix-style correlation plots with multiple levels.",
        "i" = "Use {.code facet = \"level\"} or filter to one level first."
      ))
    }
    dat$.facet <- "All rows"
    facet_levels <- "All rows"
  }
  dat$.facet <- factor(dat$.facet, levels = facet_levels)

  trait_levels <- unique(c(
    as.character(dat$trait_i),
    as.character(dat$trait_j)
  ))
  trait_index <- stats::setNames(seq_along(trait_levels), trait_levels)
  if (identical(matrix_layout, "levels")) {
    upper_dat <- dat[
      as.character(dat$.facet) == facet_levels[[1L]],
      ,
      drop = FALSE
    ]
    lower_dat <- dat[
      as.character(dat$.facet) == facet_levels[[2L]],
      ,
      drop = FALSE
    ]
    upper <- .gtmb_orient_correlation_rows(upper_dat, trait_index, "upper")
    lower <- .gtmb_orient_correlation_rows(lower_dat, trait_index, "lower")
    upper$.display_level <- facet_levels[[1L]]
    lower$.display_level <- facet_levels[[2L]]
    upper$.facet <- lower$.facet <- factor("All rows")
    cells <- rbind(upper, lower)
    triangle <- "full"
  } else {
    if (identical(matrix_layout, "estimate_ci")) {
      triangle <- "full"
    }
    upper <- .gtmb_orient_correlation_rows(dat, trait_index, "upper")
    lower <- .gtmb_orient_correlation_rows(dat, trait_index, "lower")
    upper$.display_level <- as.character(upper$.facet)
    lower$.display_level <- as.character(lower$.facet)
    cells <- if (identical(triangle, "full")) {
      rbind(upper, lower)
    } else if (identical(triangle, "upper")) {
      upper
    } else {
      lower
    }
  }

  if (isTRUE(include_diagonal)) {
    diag_facets <- if (identical(matrix_layout, "levels")) {
      "All rows"
    } else {
      levels(dat$.facet)
    }
    diag_rows <- lapply(diag_facets, function(facet_level) {
      out <- dat[rep(1L, length(trait_levels)), , drop = FALSE]
      out[] <- NA
      out$tier <- facet_level
      out$trait_i <- trait_levels
      out$trait_j <- trait_levels
      out$correlation <- 1
      out$lower <- NA_real_
      out$upper <- NA_real_
      out$method <- "fixed"
      out$.estimate <- 1
      out$.lower <- NA_real_
      out$.upper <- NA_real_
      out$.has_interval <- FALSE
      out$.significant <- FALSE
      out$.facet <- if (identical(matrix_layout, "levels")) {
        factor("All rows")
      } else {
        factor(facet_level, levels = levels(dat$.facet))
      }
      out$.display_level <- "diagonal"
      out$.row_trait <- trait_levels
      out$.col_trait <- trait_levels
      out$.row_index <- seq_along(trait_levels)
      out$.col_index <- seq_along(trait_levels)
      out$.diagonal <- TRUE
      out$.triangle <- "diagonal"
      out
    })
    cells <- rbind(cells, do.call(rbind, diag_rows))
  }

  cells <- cells[
    !duplicated(paste(
      cells$.facet,
      cells$.row_trait,
      cells$.col_trait,
      sep = "\r"
    )),
    ,
    drop = FALSE
  ]
  if (nrow(cells) == 0L) {
    cli::cli_abort("No correlation matrix cells to plot.")
  }
  cells$.triangle <- factor(
    cells$.triangle,
    levels = c("upper", "lower", "diagonal")
  )
  cells$.trait_x <- factor(cells$.col_trait, levels = trait_levels)
  cells$.trait_y <- factor(cells$.row_trait, levels = rev(trait_levels))
  cells$.x_num <- match(cells$.col_trait, trait_levels)
  cells$.y_num <- match(cells$.row_trait, rev(trait_levels))
  ## Clamp to the scale's [-1, 1] limits (like plot_Sigma_heatmap) so a
  ## correlation of e.g. 1.0000002 from a rounding/cov2cor artifact renders as
  ## the extreme colour, not the pale-grey `na.value` used for missing cells (#650).
  cells$.fill_estimate <- ifelse(
    cells$.diagonal, NA_real_, pmax(pmin(cells$.estimate, 1), -1)
  )
  cell_label_type <- if (identical(label_type, "auto")) {
    if (identical(matrix_layout, "estimate_ci")) {
      ifelse(cells$.triangle == "lower", "ci", "estimate")
    } else {
      "estimate"
    }
  } else {
    label_type
  }
  cells$.label <- .gtmb_format_correlation_matrix_label(
    cells,
    label_type = cell_label_type,
    digits = label_digits
  )
  cells$.label_colour <- .gtmb_plot_label_colour(
    cells$.fill_estimate,
    is_correlation = TRUE
  )
  cells$.label_colour[cells$.diagonal] <- .gtmb_plot_palette[["grey"]]
  cells$.cell_border <- ifelse(
    cells$.significant,
    .gtmb_plot_palette[["ink"]],
    "white"
  )
  cells$.cell_id <- seq_len(nrow(cells))
  cells$.matrix_layout <- matrix_layout
  cells$.label_type <- cell_label_type
  attr(cells, "trait_levels") <- trait_levels
  attr(cells, "matrix_layout") <- matrix_layout
  attr(cells, "triangle") <- triangle
  attr(cells, "layout_levels") <- if (identical(matrix_layout, "levels")) {
    facet_levels
  } else {
    NULL
  }
  cells
}

.gtmb_correlation_matrix_caption <- function(
  dat,
  style,
  label,
  label_type,
  matrix_layout,
  caption
) {
  if (!is.null(caption)) {
    return(caption)
  }
  labels_shown <- isTRUE(label) && !identical(label_type, "none")
  label_note <- if (!labels_shown) {
    ""
  } else if (identical(matrix_layout, "estimate_ci")) {
    "Upper labels show estimates; lower labels show supplied interval bounds when finite."
  } else if (identical(label_type, "ci")) {
    "Cell labels show supplied interval bounds when finite."
  } else if (identical(label_type, "estimate_ci")) {
    "Cell labels show estimates and supplied interval bounds when finite."
  } else {
    ""
  }
  marker_note <- if (any(dat$.significant)) {
    if (identical(style, "ellipse")) {
      "Black cell outlines/stars mark supplied intervals that exclude zero."
    } else {
      "Black cell outlines mark supplied intervals that exclude zero."
    }
  } else if (any(dat$.has_interval)) {
    "Supplied intervals are available in gllvmTMB_data; displayed intervals cross zero."
  } else {
    "No finite interval bounds were supplied for the plotted correlations."
  }
  shape_note <- if (identical(style, "ellipse")) {
    "Ellipse shape shows the sign and strength of the point estimate."
  } else {
    "Cell fill shows the point estimate."
  }
  layout_note <- ""
  if (identical(matrix_layout, "levels")) {
    levels <- attr(dat, "layout_levels") %||% character(0)
    if (length(levels) == 2L) {
      layout_note <- paste0(
        "Upper triangle shows ",
        levels[[1L]],
        "; lower triangle shows ",
        levels[[2L]],
        "."
      )
    }
  }
  .gtmb_caption_lines(
    shape_note,
    layout_note,
    label_note,
    marker_note,
    "Matrix-style views are summaries, not posterior density displays."
  )
}

.gtmb_correlation_ellipse_polygons <- function(dat, n = 80L) {
  rows <- dat[!dat$.diagonal & is.finite(dat$.estimate), , drop = FALSE]
  if (nrow(rows) == 0L) {
    return(dat[0L, , drop = FALSE])
  }
  theta <- seq(0, 2 * pi, length.out = n)
  pieces <- vector("list", nrow(rows))
  for (i in seq_len(nrow(rows))) {
    rho <- max(min(rows$.estimate[i], 1), -1)
    a <- 0.45 * sqrt(1 + abs(rho))
    b <- 0.45 * sqrt(1 - abs(rho))
    phi <- if (rho >= 0) pi / 4 else -pi / 4
    x0 <- rows$.x_num[i]
    y0 <- rows$.y_num[i]
    pieces[[i]] <- data.frame(
      .cell_id = rows$.cell_id[i],
      .facet = rows$.facet[i],
      .x = x0 + a * cos(theta) * cos(phi) - b * sin(theta) * sin(phi),
      .y = y0 + a * cos(theta) * sin(phi) + b * sin(theta) * cos(phi),
      .estimate = rho,  # already clamped to [-1, 1]; used for the fill scale (#650)
      .cell_border = rows$.cell_border[i],
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, pieces)
}

.gtmb_plot_correlation_matrix <- function(
  dat,
  style,
  triangle,
  include_diagonal,
  facet,
  label,
  label_type,
  label_digits,
  matrix_layout,
  title,
  subtitle,
  caption,
  source_label,
  notes
) {
  .gtmb_validate_plot_labels(label, label_digits)
  .gtmb_validate_optional_text(title, "title")
  .gtmb_validate_optional_text(subtitle, "subtitle")
  .gtmb_validate_optional_text(caption, "caption")
  label_type <- match.arg(
    label_type,
    c("auto", "estimate", "ci", "estimate_ci", "none")
  )
  matrix_layout <- match.arg(
    matrix_layout,
    c("by_level", "estimate_ci", "levels")
  )
  dat <- .gtmb_prepare_correlation_matrix_rows(
    dat,
    triangle = triangle,
    include_diagonal = include_diagonal,
    facet = facet,
    label_type = label_type,
    label_digits = label_digits,
    matrix_layout = matrix_layout
  )
  trait_levels <- attr(dat, "trait_levels")
  triangle <- attr(dat, "triangle") %||% triangle
  type <- if (identical(style, "ellipse")) {
    "correlations_ellipse"
  } else {
    "correlations_heatmap"
  }
  interval_status <- .gtmb_interval_state(dat$.has_interval)
  caption <- .gtmb_correlation_matrix_caption(
    dat,
    style = style,
    label = label,
    label_type = label_type,
    matrix_layout = matrix_layout,
    caption = caption
  )
  subtitle <- subtitle %||%
    {
      if (identical(matrix_layout, "levels")) {
        levels <- attr(dat, "layout_levels") %||% character(0)
        paste0(
          "Upper triangle: ",
          levels[[1L]],
          "  |  Lower triangle: ",
          levels[[2L]],
          "."
        )
      } else if (identical(matrix_layout, "estimate_ci")) {
        "Upper triangle: estimates  |  Lower triangle: interval bounds."
      } else {
        paste0(
          "Showing ",
          triangle,
          " triangle",
          if (isTRUE(include_diagonal)) {
            " with diagonal."
          } else {
            " without diagonal."
          }
        )
      }
    }

  if (identical(style, "heatmap")) {
    p <- ggplot2::ggplot(
      dat,
      ggplot2::aes(
        x = .data$.trait_x,
        y = .data$.trait_y,
        fill = .data$.fill_estimate
      )
    ) +
      ggplot2::geom_tile(
        ggplot2::aes(colour = .data$.cell_border),
        linewidth = 0.55
      ) +
      ggplot2::scale_colour_identity(guide = "none") +
      .gtmb_scale_fill_diverging("Correlation", limits = c(-1, 1)) +
      ggplot2::coord_equal() +
      ggplot2::labs(
        x = NULL,
        y = NULL,
        title = title %||% "Trait correlation matrix",
        subtitle = subtitle,
        caption = caption
      ) +
      .gtmb_theme_figure() +
      ggplot2::theme(
        panel.grid = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
        legend.position = "right"
      )
    if (isTRUE(label) && !identical(label_type, "none")) {
      p <- p +
        ggplot2::geom_text(
          ggplot2::aes(label = .data$.label, colour = .data$.label_colour),
          lineheight = 0.92,
          size = if (identical(label_type, "estimate_ci")) 2.45 else 3.0,
          show.legend = FALSE
        )
    }
  } else {
    ell <- .gtmb_correlation_ellipse_polygons(dat)
    star_dat <- dat[dat$.significant & !dat$.diagonal, , drop = FALSE]
    p <- ggplot2::ggplot() +
      ggplot2::geom_tile(
        data = dat,
        ggplot2::aes(x = .data$.x_num, y = .data$.y_num),
        fill = "#FBFBFB",
        colour = "white",
        linewidth = 0.55
      )
    if (nrow(ell) > 0L) {
      p <- p +
        ggplot2::geom_polygon(
          data = ell,
          ggplot2::aes(
            x = .data$.x,
            y = .data$.y,
            group = .data$.cell_id,
            fill = .data$.estimate,
            colour = .data$.cell_border
          ),
          linewidth = 0.55
        )
    }
    if (isTRUE(label) && !identical(label_type, "none")) {
      p <- p +
        ggplot2::geom_text(
          data = dat,
          ggplot2::aes(
            x = .data$.x_num,
            y = .data$.y_num,
            label = .data$.label,
            colour = .data$.label_colour
          ),
          lineheight = 0.92,
          size = if (identical(label_type, "estimate_ci")) 2.35 else 2.85,
          show.legend = FALSE
        )
    }
    if (nrow(star_dat) > 0L) {
      p <- p +
        ggplot2::geom_text(
          data = star_dat,
          ggplot2::aes(x = .data$.x_num, y = .data$.y_num, label = "*"),
          inherit.aes = FALSE,
          fontface = "bold",
          size = 4.0,
          nudge_y = 0.30
        )
    }
    p <- p +
      ggplot2::scale_colour_identity(guide = "none") +
      .gtmb_scale_fill_diverging("Correlation", limits = c(-1, 1)) +
      ggplot2::scale_x_continuous(
        breaks = seq_along(trait_levels),
        labels = trait_levels,
        expand = ggplot2::expansion(mult = 0.04)
      ) +
      ggplot2::scale_y_continuous(
        breaks = seq_along(trait_levels),
        labels = rev(trait_levels),
        expand = ggplot2::expansion(mult = 0.04)
      ) +
      ggplot2::coord_equal() +
      ggplot2::labs(
        x = NULL,
        y = NULL,
        title = title %||% "Trait correlations (ellipses)",
        subtitle = subtitle,
        caption = caption
      ) +
      .gtmb_theme_figure() +
      ggplot2::theme(
        panel.grid.major = ggplot2::element_line(colour = "#EAEAEA"),
        panel.grid.minor = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
        legend.position = "right"
      )
  }

  if (!identical(facet, "none") && length(unique(dat$.facet)) > 1L) {
    p <- p + ggplot2::facet_wrap(stats::as.formula("~.facet"))
  }

  p <- .gtmb_plot_contract(
    p,
    type = type,
    source = source_label,
    level = unique(as.character(dat$.facet)),
    interval_status = interval_status,
    data = dat,
    notes = notes
  )
  if (identical(style, "ellipse")) {
    attr(p, "gllvmTMB_ellipse_data") <- .gtmb_correlation_ellipse_polygons(dat)
  }
  p
}

.gtmb_add_pair_facets <- function(p, dat, facet) {
  label_lookup <- attr(dat, "row_labels") %||% character(0)
  label_fun <- function(x) {
    out <- unname(label_lookup[as.character(x)])
    out[is.na(out)] <- x[is.na(out)]
    out
  }
  p <- p +
    ggplot2::scale_y_continuous(
      breaks = sort(unique(dat$.y)),
      labels = label_fun,
      expand = ggplot2::expansion(add = c(0.55, 0.55))
    ) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      axis.line.x.bottom = ggplot2::element_line(
        colour = .gtmb_plot_palette[["grid"]],
        linewidth = 0.45
      ),
      legend.position = "none"
    )
  if (!identical(facet, "none") && length(unique(dat$.facet)) > 1L) {
    facet_args <- list(
      facets = stats::as.formula("~.facet"),
      ncol = 1L,
      scales = "free_y"
    )
    if ("space" %in% names(formals(ggplot2::facet_wrap))) {
      facet_args$space <- "free_y"
    }
    p <- p + do.call(ggplot2::facet_wrap, facet_args)
  }
  p
}

.gtmb_confidence_eye_data <- function(
  dat,
  transform = c("identity", "correlation"),
  level = 0.95,
  width = 0.26,
  n = 200L
) {
  transform <- match.arg(transform)
  level <- .gtmb_validate_interval_level(level)
  rows <- dat[dat$.has_interval, , drop = FALSE]
  if (nrow(rows) == 0L) {
    return(dat[0L, , drop = FALSE])
  }
  cutoff <- 0.5 * stats::qchisq(level, df = 1)
  z_cutoff <- stats::qnorm(1 - (1 - level) / 2)
  pieces <- vector("list", nrow(rows))
  for (i in seq_len(nrow(rows))) {
    estimate <- rows$.estimate[i]
    lower <- rows$.lower[i]
    upper <- rows$.upper[i]
    if (
      !all(is.finite(c(estimate, lower, upper))) ||
        lower >= upper
    ) {
      next
    }

    if (identical(transform, "correlation")) {
      if (any(abs(c(estimate, lower, upper)) >= 1)) {
        next
      }
      centre <- atanh(estimate)
      lower_t <- atanh(lower)
      upper_t <- atanh(upper)
      theta_to_value <- tanh
    } else {
      centre <- estimate
      lower_t <- lower
      upper_t <- upper
      theta_to_value <- identity
    }

    se <- (upper_t - lower_t) / (2 * z_cutoff)
    if (!is.finite(se) || se <= 0) {
      next
    }
    theta <- seq(
      centre - sqrt(2 * cutoff) * se,
      centre + sqrt(2 * cutoff) * se,
      length.out = n
    )
    compatibility <- cutoff - 0.5 * ((theta - centre) / se)^2
    height <- pmax(compatibility, 0) / cutoff * width
    pieces[[i]] <- data.frame(
      .x = theta_to_value(theta),
      .y = rows$.y[i],
      .ymin = rows$.y[i] - height,
      .ymax = rows$.y[i] + height,
      .row_key = rows$.row_key[i],
      .pair_label = rows$.pair_label[i],
      .facet = rows$.facet[i],
      .sign = rows$.sign[i],
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, pieces[!vapply(pieces, is.null, logical(1L))])
  if (is.null(out)) {
    out <- dat[0L, , drop = FALSE]
  }
  out
}

#' Plot pairwise trait correlations with intervals
#'
#' `plot_correlations()` turns the tidy rows returned by
#' [extract_correlations()] into a horizontal forest plot, confidence-eye plot,
#' heatmap, or ellipse matrix. Forest and confidence-eye styles keep point
#' estimates visible as open points when interval bounds are missing, and draw
#' interval information only for rows with finite lower and upper bounds.
#' Matrix styles show the same tidy rows without requiring users to reconstruct
#' or hand-index a correlation matrix.
#' For fitted-object calls, open points can often be investigated by trying
#' `method = "bootstrap"` or another interval method supported by
#' [extract_correlations()].
#'
#' Julia bridge (`engine = "julia"`) fits currently fail with an explicit gate
#' because this helper depends on interval-bearing [extract_correlations()]
#' rows. Use [plot_Sigma_table()] or [plot_Sigma_heatmap()] for point-only
#' Julia bridge correlation displays.
#'
#' Scope boundary: IN, the helper plots tidy cross-trait correlation rows from
#' [extract_correlations()], extracts those rows from a fit returned by
#' [gllvmTMB()] (this is covered by the package's extractor-contract
#' validation tests), or converts `bootstrap_Sigma()` correlation summaries to
#' the same plotting schema (also covered by those tests). Matrix heatmaps and
#' ellipse/oval displays, including upper-estimate/lower-CI and two-level
#' upper/lower layouts, are point-estimate summaries with optional numeric
#' interval labels (covered separately).
#' PARTIAL, the plot does not compute new intervals; it displays whatever
#' interval method the input rows already contain. PLANNED, matrix-style visual
#' comparisons against known truth remain article code rather than part of this
#' helper.
#'
#' @param x Either a fit returned by [gllvmTMB()], a `bootstrap_Sigma` object with
#'   `R_B` / `R_W` summaries, or a data frame returned by
#'   [extract_correlations()]. Data frames must contain `tier`, `trait_i`,
#'   `trait_j`, `correlation`, `lower`, `upper`, and `method`.
#' @param tier,pair,level,method,n_eff,nsim,seed,link_residual Passed to
#'   [extract_correlations()] when `x` is a fitted model. Ignored when `x` is
#'   already a data frame.
#' @param facet One of `"level"` (default) or `"none"`. Facetting by level
#'   keeps repeated trait pairs readable when several tiers are present.
#' @param sort Row ordering: `"estimate"` (default), `"magnitude"`, `"trait"`,
#'   or `"level"`.
#' @param show_intervals Logical or `NULL`. If `NULL` (default), finite
#'   `lower`/`upper` bounds are drawn as horizontal intervals for
#'   `style = "interval"` and omitted for `style = "eye"`. Set `TRUE` to
#'   overlay interval lines on confidence eyes. Rows without finite bounds remain
#'   visible as points.
#' @param style One of `"interval"` (default), `"eye"`, `"raindrop"`,
#'   `"heatmap"`, `"ellipse"`, or `"oval"`.
#'   `"eye"` draws a confidence eye: a pale frequentist compatibility shape
#'   reconstructed from the estimate and finite interval bounds, plus a hollow,
#'   sign-coloured estimate circle. Correlation rows use Fisher's z scale. The
#'   shape is not a posterior density. `"heatmap"` draws a trait-by-trait matrix
#'   with colour showing the point estimate. `"ellipse"`/`"oval"` draws
#'   correlation ellipses in matrix cells; ellipse tilt and width encode sign
#'   and strength. `"raindrop"` is accepted as a compatibility alias for
#'   `"eye"`, and `"oval"` as an alias for `"ellipse"`.
#' @param eye_level Confidence level represented by the supplied interval
#'   bounds when `style = "eye"`. Defaults to `level`, so fitted-object calls
#'   stay aligned with [extract_correlations()].
#' @param raindrop_level Compatibility alias for `eye_level`.
#' @param triangle Matrix triangle to show for `style = "heatmap"` or
#'   `style = "ellipse"` when `matrix_layout = "by_level"`:
#'   `"full"` (default), `"lower"`, or `"upper"`.
#' @param include_diagonal Logical. Include muted diagonal self-correlation
#'   cells in matrix styles?
#' @param label Logical. Print cell labels in matrix styles?
#' @param label_type For matrix styles, one of `"auto"` (default),
#'   `"estimate"`, `"ci"`, `"estimate_ci"`, or `"none"`. With
#'   `matrix_layout = "estimate_ci"`, `"auto"` prints point estimates in the
#'   upper triangle and interval bounds in the lower triangle. Interval labels
#'   are printed only where finite `lower` and `upper` bounds are supplied.
#' @param label_digits Non-negative whole number of decimal places for matrix
#'   cell labels.
#' @param matrix_layout Matrix-cell layout for heatmap and ellipse styles.
#'   `"by_level"` facets levels and uses `triangle` directly. `"estimate_ci"`
#'   uses the full matrix for each level: upper triangle labels point estimates
#'   and lower triangle labels supplied interval bounds. `"levels"` combines
#'   exactly two levels into one full matrix: upper triangle shows the first
#'   level and lower triangle shows the second level.
#' @param title,subtitle,caption Optional scalar character labels for matrix
#'   styles. `NULL` keeps publication-safe defaults.
#'
#' @return A `ggplot2` plot object with `gllvmTMB_meta` and `gllvmTMB_data`
#'   attributes.
#' @seealso [extract_correlations()], [plot_Sigma_table()],
#'   [plot.gllvmTMB_multi()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   cors <- data.frame(
#'     tier = c("unit", "unit", "unit_obs"),
#'     trait_i = c("length", "length", "length"),
#'     trait_j = c("mass", "wing", "mass"),
#'     correlation = c(0.42, -0.18, 0.10),
#'     lower = c(0.12, -0.45, NA),
#'     upper = c(0.66, 0.12, NA),
#'     method = c("fisher-z", "fisher-z", "none")
#'   )
#'   plot_correlations(cors)
#'   plot_correlations(cors, style = "heatmap", matrix_layout = "estimate_ci")
#' }
plot_correlations <- function(
  x,
  tier = "all",
  pair = NULL,
  level = 0.95,
  method = c("none", "fisher-z", "profile", "wald", "bootstrap"),
  n_eff = NULL,
  nsim = 500L,
  seed = NULL,
  link_residual = c("auto", "none"),
  facet = c("level", "none"),
  sort = c("estimate", "magnitude", "trait", "level"),
  show_intervals = NULL,
  style = c("interval", "eye", "raindrop", "heatmap", "ellipse", "oval"),
  eye_level = level,
  raindrop_level = NULL,
  triangle = c("full", "lower", "upper"),
  include_diagonal = TRUE,
  label = TRUE,
  label_type = c("auto", "estimate", "ci", "estimate_ci", "none"),
  label_digits = 2,
  matrix_layout = c("by_level", "estimate_ci", "levels"),
  title = NULL,
  subtitle = NULL,
  caption = NULL
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Install ggplot2: {.code install.packages(\"ggplot2\")}.")
  }
  facet <- match.arg(facet)
  sort <- match.arg(sort)
  style <- match.arg(style)
  if (identical(style, "raindrop")) {
    style <- "eye"
  }
  if (identical(style, "oval")) {
    style <- "ellipse"
  }
  matrix_style <- style %in% c("heatmap", "ellipse")
  eye_level <- if (identical(style, "eye")) {
    .gtmb_resolve_eye_level(eye_level, raindrop_level)
  } else {
    NULL
  }
  draw_interval_line <- if (isTRUE(matrix_style)) {
    FALSE
  } else {
    .gtmb_resolve_interval_line(show_intervals, style)
  }
  link_residual <- match.arg(link_residual)
  method <- match.arg(method)

  source_label <- "extract_correlations"
  if (inherits(x, "gllvmTMB_multi")) {
    dat <- extract_correlations(
      x,
      tier = tier,
      pair = pair,
      level = level,
      method = method,
      n_eff = n_eff,
      nsim = nsim,
      seed = seed,
      link_residual = link_residual
    )
  } else if (inherits(x, "bootstrap_Sigma")) {
    dat <- .gtmb_correlations_from_bootstrap(x, tier = tier, pair = pair)
    source_label <- "extract_Sigma_table"
  } else if (inherits(x, "gllvmTMB_julia")) {
    cli::cli_abort(.gllvm_julia_gate_message(
      "GJL-GATE-CORRELATION-INTERVALS",
      "engine = 'julia': plot_correlations() depends on interval-bearing ",
      "extract_correlations() rows, which are not routed yet. Use ",
      "plot_Sigma_table(x, measure = \"correlation\") or ",
      "plot_Sigma_heatmap(x, measure = \"correlation\") for point-only ",
      "Julia bridge displays."
    ))
  } else if (is.data.frame(x)) {
    dat <- x
  } else {
    cli::cli_abort(
      "{.arg x} must be a fit returned by {.fun gllvmTMB}, a {.cls bootstrap_Sigma} object, or a data frame from {.fun extract_correlations}."
    )
  }

  .gtmb_require_plot_columns(
    dat,
    c("tier", "trait_i", "trait_j", "correlation", "lower", "upper", "method")
  )
  if (nrow(dat) == 0L) {
    cli::cli_abort("No correlation rows to plot.")
  }
  plot_notes <- attr(dat, "notes") %||% character(0)

  if (isTRUE(matrix_style)) {
    return(.gtmb_plot_correlation_matrix(
      dat,
      style = style,
      triangle = triangle,
      include_diagonal = include_diagonal,
      facet = facet,
      label = label,
      label_type = label_type,
      label_digits = label_digits,
      matrix_layout = matrix_layout,
      title = title,
      subtitle = subtitle,
      caption = caption,
      source_label = source_label,
      notes = plot_notes
    ))
  }

  dat$.estimate <- dat$correlation
  dat$.lower <- dat$lower
  dat$.upper <- dat$upper
  dat$.has_interval <- is.finite(dat$.lower) & is.finite(dat$.upper)
  dat$.draw_interval <- draw_interval_line & dat$.has_interval
  dat$.facet <- .gtmb_pretty_levels(dat$tier)
  dat$.pair_label <- .gtmb_pair_label(dat$trait_i, dat$trait_j)
  dat$.sign <- .gtmb_plot_sign(dat$.estimate)
  dat <- .gtmb_prepare_pair_plot_rows(dat, sort = sort, facet = facet)
  confidence_eye <- if (identical(style, "eye")) {
    .gtmb_confidence_eye_data(
      dat,
      transform = "correlation",
      level = eye_level
    )
  } else {
    dat[0L, , drop = FALSE]
  }
  dat$.has_confidence_eye <- FALSE
  if (identical(style, "eye")) {
    dat$.has_confidence_eye <- dat$.row_key %in% unique(confidence_eye$.row_key)
  }
  visible_interval <- if (identical(style, "eye")) {
    dat$.has_confidence_eye
  } else {
    dat$.draw_interval
  }
  dat$.has_uncertainty_display <- visible_interval
  missing_caption <- if (identical(style, "eye")) {
    "Open points have no finite interval bounds; confidence eyes are not posterior densities."
  } else {
    "Open points have no finite interval bounds; try bootstrap intervals when supported."
  }
  caption <- .gtmb_uncertainty_caption(
    dat$.has_uncertainty_display,
    style = style,
    missing = missing_caption
  )

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(x = .data$.estimate, y = .data$.y)
  ) +
    ggplot2::geom_vline(
      xintercept = 0,
      colour = .gtmb_plot_palette[["grid"]],
      linewidth = 0.55
    )
  if (identical(style, "eye") && nrow(confidence_eye) > 0L) {
    p <- p +
      ggplot2::geom_ribbon(
        data = confidence_eye,
        ggplot2::aes(
          x = .data$.x,
          ymin = .data$.ymin,
          ymax = .data$.ymax,
          fill = .data$.sign,
          group = .data$.row_key
        ),
        inherit.aes = FALSE,
        alpha = 0.14,
        colour = NA
      ) +
      ggplot2::scale_colour_manual(
        values = c(
          negative = .gtmb_plot_palette[["blue"]],
          zero = .gtmb_plot_palette[["pale_grey"]],
          positive = .gtmb_plot_palette[["vermillion"]]
        )
      )
  }
  if (any(dat$.draw_interval)) {
    p <- p +
      ggplot2::geom_segment(
        data = dat[dat$.draw_interval, , drop = FALSE],
        ggplot2::aes(
          x = .data$.lower,
          xend = .data$.upper,
          y = .data$.y,
          yend = .data$.y
        ),
        inherit.aes = FALSE,
        colour = .gtmb_plot_palette[["grey"]],
        linewidth = if (identical(style, "eye")) 0.45 else 0.85,
        lineend = "round"
      )
  }
  if (any(dat$.has_uncertainty_display)) {
    if (identical(style, "eye")) {
      p <- p +
        ggplot2::geom_point(
          data = dat[dat$.has_uncertainty_display, , drop = FALSE],
          ggplot2::aes(colour = .data$.sign),
          shape = 21,
          size = 3,
          stroke = 1.05,
          fill = "white",
          alpha = 0.98
        )
    } else {
      p <- p +
        ggplot2::geom_point(
          data = dat[dat$.has_uncertainty_display, , drop = FALSE],
          ggplot2::aes(fill = .data$.sign),
          shape = 21,
          size = 2.6,
          stroke = 0.45,
          colour = .gtmb_plot_palette[["ink"]]
        )
    }
  }
  if (any(!dat$.has_uncertainty_display)) {
    p <- p +
      ggplot2::geom_point(
        data = dat[!dat$.has_uncertainty_display, , drop = FALSE],
        shape = 21,
        size = 2.6,
        stroke = 0.8,
        fill = "white",
        colour = .gtmb_plot_palette[["grey"]]
      )
  }
  if (any(dat$.has_uncertainty_display) || nrow(confidence_eye) > 0L) {
    p <- p +
      ggplot2::scale_fill_manual(
        values = c(
          negative = .gtmb_plot_palette[["blue"]],
          zero = .gtmb_plot_palette[["pale_grey"]],
          positive = .gtmb_plot_palette[["vermillion"]]
        )
      )
  }
  p <- p +
    ggplot2::scale_x_continuous(breaks = seq(-1, 1, by = 0.5)) +
    ggplot2::coord_cartesian(xlim = c(-1, 1)) +
    ggplot2::labs(
      x = "Correlation",
      y = NULL,
      title = "Pairwise trait correlations",
      subtitle = if (identical(style, "eye")) {
        "Confidence eyes show compatibility from finite intervals; hollow circles mark estimates."
      } else {
        "Points are estimates; horizontal segments show finite interval bounds."
      },
      caption = caption
    ) +
    .gtmb_theme_figure()
  p <- .gtmb_add_pair_facets(p, dat, facet = facet)

  p <- .gtmb_plot_contract(
    p,
    type = if (identical(style, "eye")) {
      "correlations_confidence_eye"
    } else {
      "correlations_forest"
    },
    source = source_label,
    level = unique(dat$.facet),
    interval_status = .gtmb_interval_state(visible_interval),
    data = dat,
    notes = plot_notes
  )
  if (identical(style, "eye")) {
    attr(p, "gllvmTMB_confidence_eye_data") <- confidence_eye
    attr(p, "gllvmTMB_raindrop_data") <- confidence_eye
  }
  p
}

#' Plot Sigma-table estimates against a known truth matrix
#'
#' `plot_Sigma_comparison()` turns [compare_Sigma_table()] rows into a
#' row-labelled comparison plot. The default `style = "difference"` shows
#' `estimate - truth` for each covariance or correlation row; `style =
#' "scatter"` shows estimate versus truth with a one-to-one reference line.
#' Segments in these plots are comparison residuals, not confidence intervals.
#'
#' Scope boundary: IN, the helper plots [compare_Sigma_table()] rows or builds
#' them from a fitted model / Sigma table plus one supplied truth matrix
#' (covered by the package's comparison-table validation tests, which build on
#' the underlying Sigma-table extraction tests). PARTIAL, it is a visual
#' comparison helper only: it does not run simulations, compute intervals, or
#' validate calibration.
#' PLANNED, article-specific simulation summaries and richer calibration plots
#' remain future work.
#'
#' @param x A fit returned by [gllvmTMB()], an admitted `engine = "julia"`
#'   bridge fit, a data frame returned by [extract_Sigma_table()], or a data
#'   frame already returned by [compare_Sigma_table()].
#' @param truth Square numeric covariance or correlation matrix passed to
#'   [compare_Sigma_table()]. May be omitted only when `x` already contains
#'   `truth`, `error`, `abs_error`, and `comparison_status` columns.
#' @param level,part,measure,entries,link_residual Passed to
#'   [compare_Sigma_table()] when `truth` is supplied.
#' @param include_diagonal Logical. Include diagonal rows if they are present?
#'   The default is `FALSE` because variances are usually on a different scale
#'   from pairwise covariance/correlation rows.
#' @param facet One of `"level"` (default), `"comparison"`, or `"none"`.
#'   Use `"comparison"` when precomputed rows contain a `comparison` column,
#'   for example to compare two model specifications against the same truth.
#' @param sort Row ordering for `style = "difference"`: `"abs_error"`
#'   (default), `"error"`, `"estimate"`, `"truth"`, `"trait"`, or `"level"`.
#' @param style One of `"difference"` (default) or `"scatter"`.
#'
#' @return A `ggplot2` plot object with `gllvmTMB_meta` and `gllvmTMB_data`
#'   attributes.
#' @seealso [compare_Sigma_table()], [plot_Sigma_table()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   rows <- data.frame(
#'     level = "unit",
#'     trait_i = c("length", "length", "mass"),
#'     trait_j = c("mass", "wing", "wing"),
#'     estimate = c(0.62, -0.10, 0.28),
#'     lower = NA_real_,
#'     upper = NA_real_,
#'     matrix = "R",
#'     component = "total",
#'     diagonal = FALSE,
#'     triangle = "upper",
#'     scale = "correlation"
#'   )
#'   truth_R <- matrix(
#'     c(1, 0.60, -0.05, 0.60, 1, 0.20, -0.05, 0.20, 1),
#'     3,
#'     byrow = TRUE,
#'     dimnames = list(
#'       c("length", "mass", "wing"),
#'       c("length", "mass", "wing")
#'     )
#'   )
#'   plot_Sigma_comparison(rows, truth_R, measure = "correlation")
#' }
plot_Sigma_comparison <- function(
  x,
  truth,
  level = "unit",
  part = c("total", "shared", "unique"),
  measure = c("covariance", "correlation"),
  entries = c("upper", "unique", "all", "offdiag", "lower", "diag"),
  link_residual = c("auto", "none"),
  include_diagonal = FALSE,
  facet = c("level", "comparison", "none"),
  sort = c("abs_error", "error", "estimate", "truth", "trait", "level"),
  style = c("difference", "scatter")
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Install ggplot2: {.code install.packages(\"ggplot2\")}.")
  }
  part <- match.arg(part)
  measure <- match.arg(measure)
  entries <- match.arg(entries)
  link_residual <- match.arg(link_residual)
  facet <- match.arg(facet)
  sort <- match.arg(sort)
  style <- match.arg(style)

  if (missing(truth)) {
    if (!is.data.frame(x)) {
      cli::cli_abort(
        "{.arg truth} is required unless {.arg x} is already a data frame from {.fun compare_Sigma_table}."
      )
    }
    dat <- x
  } else {
    dat <- compare_Sigma_table(
      x,
      truth = truth,
      level = level,
      part = part,
      measure = measure,
      entries = entries,
      link_residual = link_residual
    )
  }

  .gtmb_require_plot_columns(
    dat,
    c(
      "trait_i",
      "trait_j",
      "estimate",
      "truth",
      "error",
      "abs_error",
      "comparison_status"
    )
  )
  if (!"level" %in% names(dat)) {
    dat$level <- level[[1L]]
  }
  if (!"diagonal" %in% names(dat)) {
    dat$diagonal <- as.character(dat$trait_i) == as.character(dat$trait_j)
  }
  if (!"matrix" %in% names(dat)) {
    dat$matrix <- if (identical(measure, "correlation")) "R" else "Sigma"
  }
  if (!isTRUE(include_diagonal)) {
    dat <- dat[!(dat$diagonal %in% TRUE), , drop = FALSE]
  }
  if (nrow(dat) == 0L) {
    cli::cli_abort(c(
      "No Sigma comparison rows to plot.",
      "i" = "If you passed only diagonal rows, set {.code include_diagonal = TRUE}."
    ))
  }

  plot_notes <- attr(dat, "notes") %||% character(0)
  dat$.estimate <- dat$estimate
  dat$.truth <- dat$truth
  dat$.error <- dat$error
  dat$.abs_error <- dat$abs_error
  dat$.can_compare <- is.finite(dat$.estimate) &
    is.finite(dat$.truth) &
    is.finite(dat$.error)
  if (!any(dat$.can_compare)) {
    cli::cli_abort(
      "No finite comparison rows to plot; check {.field estimate} and {.field truth}."
    )
  }
  if (identical(facet, "comparison")) {
    .gtmb_require_plot_columns(dat, "comparison")
    dat$.facet <- as.character(dat$comparison)
  } else {
    dat$.facet <- .gtmb_pretty_levels(dat$level)
  }
  dat$.pair_label <- .gtmb_pair_label(
    dat$trait_i,
    dat$trait_j,
    diagonal = dat$diagonal
  )
  error_for_sign <- dat$.error
  error_for_sign[!is.finite(error_for_sign)] <- 0
  dat$.error_sign <- .gtmb_plot_sign(error_for_sign)
  dat <- .gtmb_prepare_comparison_plot_rows(dat, sort = sort, facet = facet)
  draw <- dat[dat$.can_compare, , drop = FALSE]

  is_correlation <- any(dat$matrix == "R", na.rm = TRUE)
  if ("scale" %in% names(dat)) {
    is_correlation <- is_correlation ||
      any(dat$scale == "correlation", na.rm = TRUE)
  }
  x_lab <- if (is_correlation) {
    "Estimate - truth (correlation)"
  } else {
    "Estimate - truth"
  }
  title <- if (any(dat$diagonal %in% TRUE, na.rm = TRUE)) {
    if (is_correlation) "Correlation error by entry" else "Sigma error by entry"
  } else if (is_correlation) {
    "Correlation error by trait pair"
  } else {
    "Sigma error by trait pair"
  }
  caption <- if (all(dat$.can_compare)) {
    "Segments show estimate - truth; not confidence intervals."
  } else {
    "Rows with non-finite estimate or truth are retained in plot metadata but not drawn."
  }
  type <- if (identical(style, "scatter")) {
    "sigma_comparison_scatter"
  } else {
    "sigma_comparison_difference"
  }

  if (identical(style, "scatter")) {
    p <- ggplot2::ggplot(
      draw,
      ggplot2::aes(x = .data$.truth, y = .data$.estimate)
    ) +
      ggplot2::geom_abline(
        intercept = 0,
        slope = 1,
        colour = .gtmb_plot_palette[["grid"]],
        linewidth = 0.65
      ) +
      ggplot2::geom_segment(
        ggplot2::aes(
          xend = .data$.truth,
          y = .data$.truth,
          yend = .data$.estimate,
          colour = .data$.error_sign
        ),
        linewidth = 0.65,
        alpha = 0.85
      ) +
      ggplot2::geom_point(
        ggplot2::aes(fill = .data$.error_sign),
        shape = 21,
        size = 2.8,
        stroke = 0.5,
        colour = .gtmb_plot_palette[["ink"]]
      ) +
      ggplot2::labs(
        x = if (is_correlation) "Truth (correlation)" else "Truth",
        y = if (is_correlation) "Estimate (correlation)" else "Estimate",
        title = if (is_correlation) {
          "Correlation estimates vs truth"
        } else {
          "Sigma estimates vs truth"
        },
        subtitle = "One-to-one = exact; segments = error.",
        caption = if (all(dat$.can_compare)) {
          "Segments are errors, not CIs."
        } else {
          caption
        }
      )
    if (!identical(facet, "none") && length(unique(draw$.facet)) > 1L) {
      p <- p + ggplot2::facet_wrap(stats::as.formula("~.facet"))
    }
    if (is_correlation) {
      p <- p +
        ggplot2::scale_x_continuous(breaks = seq(-1, 1, by = 0.5)) +
        ggplot2::scale_y_continuous(breaks = seq(-1, 1, by = 0.5)) +
        ggplot2::coord_equal(xlim = c(-1, 1), ylim = c(-1, 1))
    } else {
      p <- p + ggplot2::coord_equal()
    }
  } else {
    p <- ggplot2::ggplot(
      dat,
      ggplot2::aes(x = .data$.error, y = .data$.y)
    ) +
      ggplot2::geom_vline(
        xintercept = 0,
        colour = .gtmb_plot_palette[["grid"]],
        linewidth = 0.6
      ) +
      ggplot2::geom_segment(
        data = draw,
        ggplot2::aes(
          x = 0,
          xend = .data$.error,
          y = .data$.y,
          yend = .data$.y,
          colour = .data$.error_sign
        ),
        inherit.aes = FALSE,
        linewidth = 0.85,
        lineend = "round"
      ) +
      ggplot2::geom_point(
        data = draw,
        ggplot2::aes(fill = .data$.error_sign),
        shape = 21,
        size = 2.8,
        stroke = 0.5,
        colour = .gtmb_plot_palette[["ink"]]
      ) +
      ggplot2::labs(
        x = x_lab,
        y = NULL,
        title = title,
        subtitle = "Points show estimate minus supplied truth for each row.",
        caption = caption
      )
    p <- .gtmb_add_pair_facets(p, dat, facet = facet)
  }
  p <- p +
    ggplot2::scale_colour_manual(
      values = c(
        negative = .gtmb_plot_palette[["blue"]],
        zero = .gtmb_plot_palette[["grey"]],
        positive = .gtmb_plot_palette[["vermillion"]]
      ),
      name = "Error sign"
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        negative = .gtmb_plot_palette[["blue"]],
        zero = .gtmb_plot_palette[["pale_grey"]],
        positive = .gtmb_plot_palette[["vermillion"]]
      ),
      name = "Error sign"
    ) +
    ggplot2::guides(colour = "none") +
    .gtmb_theme_figure()

  p <- .gtmb_plot_contract(
    p,
    type = type,
    source = "compare_Sigma_table",
    level = unique(dat$.facet),
    interval_status = "not_applicable",
    data = dat,
    notes = plot_notes
  )
  meta <- attr(p, "gllvmTMB_meta")
  meta$comparison_status <- if (all(dat$.can_compare)) {
    "compared"
  } else {
    "partial"
  }
  attr(p, "gllvmTMB_meta") <- meta
  p
}

#' Plot report-ready Sigma table rows
#'
#' `plot_Sigma_table()` turns rows from [extract_Sigma_table()] into a
#' forest-style covariance or correlation plot. It is designed for reports and
#' articles that need to show selected covariance entries without indexing the
#' `Sigma` matrix by hand. Rows without finite interval bounds are drawn as
#' open points. To display Sigma uncertainty, pass interval-bearing rows, for
#' example from a bootstrap workflow; [extract_Sigma_table()] itself currently
#' leaves interval columns as placeholders.
#'
#' Scope boundary: IN, the helper plots point-estimate rows from
#' [extract_Sigma_table()] or extracts those rows from a fit returned by
#' [gllvmTMB()] or an admitted `engine = "julia"` bridge fit (covered by the
#' package's extractor-contract validation tests, including the Julia-bridge
#' fit path). PARTIAL, interval columns are displayed when present and
#' finite, but this helper does not compute Sigma intervals. PLANNED,
#' uncertainty propagation for arbitrary Sigma entries belongs in
#' bootstrap/profile infrastructure.
#'
#' @param x A fit returned by [gllvmTMB()], an admitted `engine = "julia"`
#'   bridge fit, a `bootstrap_Sigma` object, or a data frame returned by
#'   [extract_Sigma_table()]. Data frames must contain `level`, `trait_i`,
#'   `trait_j`, `estimate`, `lower`, `upper`, `matrix`, `component`,
#'   `diagonal`, and `triangle`.
#' @param level,part,measure,entries,link_residual Passed to
#'   [extract_Sigma_table()] when `x` is a fitted model. The plotting default
#'   `entries = "upper"` shows each pairwise covariance/correlation once; pass
#'   `entries = "diag"` for variances or `entries = "unique"` for the diagonal
#'   plus upper triangle.
#' @param include_diagonal Logical. Include diagonal rows if they are present
#'   in `x`? The default is `FALSE` because covariance diagonals are variances
#'   and are usually on a different interpretive scale than pairwise
#'   covariances.
#' @param facet One of `"level"` (default) or `"none"`.
#' @param sort Row ordering: `"estimate"` (default), `"magnitude"`, `"trait"`,
#'   or `"level"`.
#' @param show_intervals Logical or `NULL`. If `NULL` (default), finite
#'   `lower`/`upper` bounds are drawn as horizontal intervals for
#'   `style = "interval"` and omitted for `style = "eye"`. Set `TRUE` to
#'   overlay interval lines on confidence eyes. Rows without finite bounds remain
#'   visible as points.
#' @param style One of `"interval"` (default), `"eye"`, or `"raindrop"`.
#'   `"eye"` draws a confidence eye: a pale frequentist compatibility shape
#'   reconstructed from the estimate and finite interval bounds, plus a hollow,
#'   sign-coloured estimate circle. Correlation rows use Fisher's z scale and
#'   covariance rows use the displayed estimate scale. The shape is not a
#'   posterior density. `"raindrop"` is accepted as a compatibility alias.
#' @param eye_level Confidence level represented by the supplied interval
#'   bounds when `style = "eye"`. Default `0.95`.
#' @param raindrop_level Compatibility alias for `eye_level`.
#'
#' @return A `ggplot2` plot object with `gllvmTMB_meta` and `gllvmTMB_data`
#'   attributes.
#' @seealso [extract_Sigma_table()], [plot_correlations()],
#'   [plot.gllvmTMB_multi()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   sigma_rows <- data.frame(
#'     level = "unit",
#'     trait_i = c("length", "length", "mass"),
#'     trait_j = c("mass", "wing", "wing"),
#'     estimate = c(0.22, -0.08, 0.15),
#'     lower = NA_real_,
#'     upper = NA_real_,
#'     matrix = "Sigma",
#'     component = "total",
#'     diagonal = FALSE,
#'     triangle = "upper"
#'   )
#'   plot_Sigma_table(sigma_rows)
#' }
plot_Sigma_table <- function(
  x,
  level = "unit",
  part = c("total", "shared", "unique"),
  measure = c("covariance", "correlation"),
  entries = c("upper", "unique", "all", "offdiag", "lower", "diag"),
  link_residual = c("auto", "none"),
  include_diagonal = FALSE,
  facet = c("level", "none"),
  sort = c("estimate", "magnitude", "trait", "level"),
  show_intervals = NULL,
  style = c("interval", "eye", "raindrop"),
  eye_level = 0.95,
  raindrop_level = NULL
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Install ggplot2: {.code install.packages(\"ggplot2\")}.")
  }
  part <- match.arg(part)
  measure <- match.arg(measure)
  entries <- match.arg(entries)
  link_residual <- match.arg(link_residual)
  facet <- match.arg(facet)
  sort <- match.arg(sort)
  style <- .gtmb_normalise_uncertainty_style(style)
  eye_level <- .gtmb_resolve_eye_level(eye_level, raindrop_level)
  draw_interval_line <- .gtmb_resolve_interval_line(show_intervals, style)

  if (
    inherits(x, "gllvmTMB_multi") ||
      inherits(x, "gllvmTMB_julia") ||
      inherits(x, "bootstrap_Sigma")
  ) {
    dat <- extract_Sigma_table(
      x,
      level = level,
      part = part,
      measure = measure,
      entries = entries,
      link_residual = link_residual
    )
  } else if (is.data.frame(x)) {
    dat <- x
  } else {
    cli::cli_abort(
      "{.arg x} must be a fit returned by {.fun gllvmTMB}, an admitted {.cls gllvmTMB_julia} bridge fit, a {.cls bootstrap_Sigma} object, or a data frame from {.fun extract_Sigma_table}."
    )
  }

  .gtmb_require_plot_columns(
    dat,
    c(
      "level",
      "trait_i",
      "trait_j",
      "estimate",
      "lower",
      "upper",
      "matrix",
      "component",
      "diagonal",
      "triangle"
    )
  )
  if (!isTRUE(include_diagonal)) {
    dat <- dat[!(dat$diagonal %in% TRUE), , drop = FALSE]
  }
  if (nrow(dat) == 0L) {
    cli::cli_abort(c(
      "No Sigma table rows to plot.",
      "i" = "If you passed only diagonal rows, set {.code include_diagonal = TRUE}."
    ))
  }
  plot_notes <- attr(dat, "notes") %||% character(0)

  dat$.estimate <- dat$estimate
  dat$.lower <- dat$lower
  dat$.upper <- dat$upper
  dat$.has_interval <- is.finite(dat$.lower) & is.finite(dat$.upper)
  dat$.draw_interval <- draw_interval_line & dat$.has_interval
  dat$.facet <- .gtmb_pretty_levels(dat$level)
  dat$.pair_label <- .gtmb_pair_label(
    dat$trait_i,
    dat$trait_j,
    diagonal = dat$diagonal
  )
  dat$.sign <- .gtmb_plot_sign(dat$.estimate)
  dat <- .gtmb_prepare_pair_plot_rows(dat, sort = sort, facet = facet)

  is_correlation <- any(dat$matrix == "R", na.rm = TRUE)
  if ("scale" %in% names(dat)) {
    is_correlation <- is_correlation ||
      any(dat$scale == "correlation", na.rm = TRUE)
  }
  x_lab <- if (is_correlation) {
    "Correlation"
  } else if (any(dat$diagonal %in% TRUE, na.rm = TRUE)) {
    "Covariance / variance estimate"
  } else {
    "Covariance estimate"
  }
  title <- if (is_correlation) {
    "Sigma-derived trait correlations"
  } else {
    "Selected Sigma entries"
  }
  confidence_eye <- if (identical(style, "eye")) {
    .gtmb_confidence_eye_data(
      dat,
      transform = if (is_correlation) "correlation" else "identity",
      level = eye_level
    )
  } else {
    dat[0L, , drop = FALSE]
  }
  dat$.has_confidence_eye <- FALSE
  if (identical(style, "eye")) {
    dat$.has_confidence_eye <- dat$.row_key %in% unique(confidence_eye$.row_key)
  }
  visible_interval <- if (identical(style, "eye")) {
    dat$.has_confidence_eye
  } else {
    dat$.draw_interval
  }
  dat$.has_uncertainty_display <- visible_interval
  missing_caption <- if (identical(style, "eye")) {
    "Open points have no finite interval bounds; confidence eyes are not posterior densities."
  } else {
    "Open points have no finite interval bounds; use bootstrap-derived rows when needed."
  }
  caption <- .gtmb_uncertainty_caption(
    dat$.has_uncertainty_display,
    style = style,
    missing = missing_caption
  )

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(x = .data$.estimate, y = .data$.y)
  ) +
    ggplot2::geom_vline(
      xintercept = 0,
      colour = .gtmb_plot_palette[["grid"]],
      linewidth = 0.55
    )
  if (identical(style, "eye") && nrow(confidence_eye) > 0L) {
    p <- p +
      ggplot2::geom_ribbon(
        data = confidence_eye,
        ggplot2::aes(
          x = .data$.x,
          ymin = .data$.ymin,
          ymax = .data$.ymax,
          fill = .data$.sign,
          group = .data$.row_key
        ),
        inherit.aes = FALSE,
        alpha = 0.14,
        colour = NA
      ) +
      ggplot2::scale_colour_manual(
        values = c(
          negative = .gtmb_plot_palette[["blue"]],
          zero = .gtmb_plot_palette[["pale_grey"]],
          positive = .gtmb_plot_palette[["vermillion"]]
        )
      )
  }
  if (any(dat$.draw_interval)) {
    p <- p +
      ggplot2::geom_segment(
        data = dat[dat$.draw_interval, , drop = FALSE],
        ggplot2::aes(
          x = .data$.lower,
          xend = .data$.upper,
          y = .data$.y,
          yend = .data$.y
        ),
        inherit.aes = FALSE,
        colour = .gtmb_plot_palette[["grey"]],
        linewidth = if (identical(style, "eye")) 0.45 else 0.85,
        lineend = "round"
      )
  }
  if (any(dat$.has_uncertainty_display)) {
    if (identical(style, "eye")) {
      p <- p +
        ggplot2::geom_point(
          data = dat[dat$.has_uncertainty_display, , drop = FALSE],
          ggplot2::aes(colour = .data$.sign),
          shape = 21,
          size = 3,
          stroke = 1.05,
          fill = "white",
          alpha = 0.98
        )
    } else {
      p <- p +
        ggplot2::geom_point(
          data = dat[dat$.has_uncertainty_display, , drop = FALSE],
          ggplot2::aes(fill = .data$.sign),
          shape = 21,
          size = 2.6,
          stroke = 0.45,
          colour = .gtmb_plot_palette[["ink"]]
        )
    }
  }
  if (any(!dat$.has_uncertainty_display)) {
    p <- p +
      ggplot2::geom_point(
        data = dat[!dat$.has_uncertainty_display, , drop = FALSE],
        shape = 21,
        size = 2.6,
        stroke = 0.8,
        fill = "white",
        colour = .gtmb_plot_palette[["grey"]]
      )
  }
  if (any(dat$.has_uncertainty_display) || nrow(confidence_eye) > 0L) {
    p <- p +
      ggplot2::scale_fill_manual(
        values = c(
          negative = .gtmb_plot_palette[["blue"]],
          zero = .gtmb_plot_palette[["pale_grey"]],
          positive = .gtmb_plot_palette[["vermillion"]]
        )
      )
  }
  p <- p +
    ggplot2::labs(
      x = x_lab,
      y = NULL,
      title = title,
      subtitle = if (identical(style, "eye")) {
        "Confidence eyes use finite bounds as compatibility displays; hollow circles mark estimates."
      } else {
        "Rows come from extract_Sigma_table(); finite bounds are drawn as intervals."
      },
      caption = caption
    ) +
    .gtmb_theme_figure()
  if (is_correlation) {
    p <- p +
      ggplot2::scale_x_continuous(breaks = seq(-1, 1, by = 0.5)) +
      ggplot2::coord_cartesian(xlim = c(-1, 1))
  }
  p <- .gtmb_add_pair_facets(p, dat, facet = facet)

  p <- .gtmb_plot_contract(
    p,
    type = if (identical(style, "eye")) {
      "sigma_table_confidence_eye"
    } else {
      "sigma_table_forest"
    },
    source = "extract_Sigma_table",
    level = unique(dat$.facet),
    interval_status = .gtmb_interval_state(visible_interval),
    data = dat,
    notes = plot_notes
  )
  if (identical(style, "eye")) {
    attr(p, "gllvmTMB_confidence_eye_data") <- confidence_eye
    attr(p, "gllvmTMB_raindrop_data") <- confidence_eye
  }
  p
}

#' Plot Sigma-table rows as a trait-by-trait heatmap
#'
#' `plot_Sigma_heatmap()` turns rows from [extract_Sigma_table()] into a
#' matrix-style heatmap. It is designed for articles that need to show the
#' block structure of a covariance or correlation matrix without manually
#' extracting `Sigma`, calling `cov2cor()`, or rebuilding `geom_tile()` layers.
#' Heatmap cells are point estimates only; interval columns, when present, stay
#' available in the returned plot data but are not displayed.
#'
#' Scope boundary: IN, the helper plots point-estimate heatmaps from
#' [extract_Sigma_table()] rows or extracts those rows from a fit returned by
#' [gllvmTMB()], an admitted `engine = "julia"` bridge fit, or from a
#' `bootstrap_Sigma` object (covered by the package's heatmap validation
#' tests, which build on the underlying extractor-contract and Julia-bridge
#' fit tests). PARTIAL, it does not display interval bounds or compare fitted values to
#' known truth. Use [plot_Sigma_table()] for interval forests or confidence
#' eyes, and [plot_Sigma_comparison()] for estimate-vs-truth displays. PLANNED,
#' vdiffr snapshots and richer multi-model layout helpers remain future figure
#' work.
#'
#' @param x A fit returned by [gllvmTMB()], an admitted `engine = "julia"`
#'   bridge fit, a `bootstrap_Sigma` object, or a data frame returned by
#'   [extract_Sigma_table()]. Data frames must contain `level`, `trait_i`,
#'   `trait_j`, `estimate`, `matrix`, `component`, `diagonal`, and `triangle`;
#'   `i` and `j` columns are used for trait ordering when present.
#' @param level,part,measure,entries,link_residual Passed to
#'   [extract_Sigma_table()] when `x` is a fitted model. The plotting default
#'   `entries = "all"` shows the full matrix.
#' @param include_diagonal Logical. Include diagonal rows when present?
#' @param facet One of `"level"` (default) or `"none"`.
#' @param label Logical. Print numeric estimates inside cells?
#' @param label_digits Number of decimal places for cell labels.
#' @param title,subtitle,caption Optional scalar character labels. `NULL`
#'   keeps the helper's publication-safe defaults.
#'
#' @return A `ggplot2` plot object with `gllvmTMB_meta` and `gllvmTMB_data`
#'   attributes.
#' @seealso [extract_Sigma_table()], [plot_Sigma_table()],
#'   [plot_Sigma_comparison()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   rows <- data.frame(
#'     level = "unit",
#'     trait_i = rep(c("length", "mass"), each = 2),
#'     trait_j = rep(c("length", "mass"), 2),
#'     estimate = c(1, 0.35, 0.35, 1),
#'     matrix = "R",
#'     component = "total",
#'     diagonal = c(TRUE, FALSE, FALSE, TRUE),
#'     triangle = c("diagonal", "lower", "upper", "diagonal")
#'   )
#'   plot_Sigma_heatmap(rows)
#' }
plot_Sigma_heatmap <- function(
  x,
  level = "unit",
  part = c("total", "shared", "unique"),
  measure = c("correlation", "covariance"),
  entries = c("all", "unique", "upper", "lower", "offdiag", "diag"),
  link_residual = c("auto", "none"),
  include_diagonal = TRUE,
  facet = c("level", "none"),
  label = TRUE,
  label_digits = 2,
  title = NULL,
  subtitle = NULL,
  caption = NULL
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Install ggplot2: {.code install.packages(\"ggplot2\")}.")
  }
  part <- match.arg(part)
  measure <- match.arg(measure)
  entries <- match.arg(entries)
  link_residual <- match.arg(link_residual)
  facet <- match.arg(facet)
  if (
    !is.logical(include_diagonal) ||
      length(include_diagonal) != 1L ||
      is.na(include_diagonal)
  ) {
    cli::cli_abort(
      "{.arg include_diagonal} must be {.code TRUE} or {.code FALSE}."
    )
  }
  if (!is.logical(label) || length(label) != 1L || is.na(label)) {
    cli::cli_abort("{.arg label} must be {.code TRUE} or {.code FALSE}.")
  }
  if (
    !is.numeric(label_digits) ||
      length(label_digits) != 1L ||
      is.na(label_digits) ||
      label_digits < 0 ||
      label_digits != floor(label_digits)
  ) {
    cli::cli_abort("{.arg label_digits} must be a non-negative whole number.")
  }
  .gtmb_validate_optional_text <- function(x, arg) {
    if (
      !is.null(x) &&
        (!is.character(x) || length(x) != 1L || is.na(x))
    ) {
      cli::cli_abort(
        "{.arg {arg}} must be {.code NULL} or a scalar character string."
      )
    }
  }
  .gtmb_validate_optional_text(title, "title")
  .gtmb_validate_optional_text(subtitle, "subtitle")
  .gtmb_validate_optional_text(caption, "caption")

  if (
    inherits(x, "gllvmTMB_multi") ||
      inherits(x, "gllvmTMB_julia") ||
      inherits(x, "bootstrap_Sigma")
  ) {
    dat <- extract_Sigma_table(
      x,
      level = level,
      part = part,
      measure = measure,
      entries = entries,
      link_residual = link_residual
    )
  } else if (is.data.frame(x)) {
    dat <- x
  } else {
    cli::cli_abort(
      "{.arg x} must be a fit returned by {.fun gllvmTMB}, an admitted {.cls gllvmTMB_julia} bridge fit, a {.cls bootstrap_Sigma} object, or a data frame from {.fun extract_Sigma_table}."
    )
  }

  .gtmb_require_plot_columns(
    dat,
    c(
      "level",
      "trait_i",
      "trait_j",
      "estimate",
      "matrix",
      "component",
      "diagonal",
      "triangle"
    )
  )
  if (!isTRUE(include_diagonal)) {
    dat <- dat[!(dat$diagonal %in% TRUE), , drop = FALSE]
  }
  if (nrow(dat) == 0L) {
    cli::cli_abort(c(
      "No Sigma table rows to plot.",
      "i" = "If you passed only diagonal rows, set {.code include_diagonal = TRUE}."
    ))
  }
  plot_notes <- attr(dat, "notes") %||% character(0)

  dat$.estimate <- dat$estimate
  pretty_levels <- .gtmb_pretty_levels(dat$level)
  dat$.facet <- factor(pretty_levels, levels = unique(pretty_levels))
  if (identical(facet, "none")) {
    dat$.facet <- factor("All rows")
  }
  trait_levels <- .gtmb_heatmap_trait_levels(dat)
  dat$.trait_x <- factor(as.character(dat$trait_j), levels = trait_levels)
  dat$.trait_y <- factor(as.character(dat$trait_i), levels = rev(trait_levels))

  is_correlation <- any(dat$matrix == "R", na.rm = TRUE)
  if ("scale" %in% names(dat)) {
    is_correlation <- is_correlation ||
      any(dat$scale == "correlation", na.rm = TRUE)
  }
  fill_name <- if (is_correlation) "Correlation" else "Estimate"
  fill_limits <- if (is_correlation) {
    c(-1, 1)
  } else {
    finite_est <- dat$.estimate[is.finite(dat$.estimate)]
    max_abs <- if (length(finite_est) > 0L) {
      max(abs(finite_est), na.rm = TRUE)
    } else {
      1
    }
    if (!is.finite(max_abs) || max_abs <= 0) {
      max_abs <- 1
    }
    c(-max_abs, max_abs)
  }
  dat$.fill_estimate <- if (is_correlation) {
    pmax(pmin(dat$.estimate, 1), -1)
  } else {
    dat$.estimate
  }
  dat$.label <- ifelse(
    is.finite(dat$.estimate),
    sprintf(paste0("%.", label_digits, "f"), dat$.estimate),
    ""
  )
  dat$.label_colour <- .gtmb_heatmap_label_colour(
    dat$.fill_estimate,
    is_correlation = is_correlation
  )

  p <- ggplot2::ggplot(
    dat,
    ggplot2::aes(
      x = .data$.trait_x,
      y = .data$.trait_y,
      fill = .data$.fill_estimate
    )
  ) +
    ggplot2::geom_tile(
      colour = "white",
      linewidth = 0.45
    )
  if (isTRUE(label)) {
    p <- p +
      ggplot2::geom_text(
        ggplot2::aes(label = .data$.label, colour = .data$.label_colour),
        size = 3.0,
        show.legend = FALSE
      ) +
      ggplot2::scale_colour_manual(
        values = c(dark = .gtmb_plot_palette[["ink"]], light = "white")
      )
  }
  p <- p +
    .gtmb_scale_fill_diverging(fill_name, limits = fill_limits) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      title = title %||%
        if (is_correlation) {
          "Sigma-derived trait correlations"
        } else {
          "Sigma entries by trait"
        },
      subtitle = subtitle %||%
        "Cells are point estimates from extract_Sigma_table().",
      caption = caption %||%
        "Heatmaps do not display uncertainty intervals."
    ) +
    .gtmb_theme_figure() +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      legend.position = "right"
    )
  if (!identical(facet, "none") && length(unique(dat$.facet)) > 1L) {
    p <- p + ggplot2::facet_wrap(stats::as.formula("~.facet"))
  }

  .gtmb_plot_contract(
    p,
    type = "sigma_heatmap",
    source = "extract_Sigma_table",
    level = unique(as.character(dat$.facet)),
    interval_status = "not_displayed",
    data = dat,
    notes = plot_notes
  )
}
