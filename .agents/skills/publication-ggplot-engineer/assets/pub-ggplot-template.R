# Publication ggplot helper templates for R packages.
# Copy, adapt, and document inside the target package; do not import this file directly.

#' Publication theme for package figures
#'
#' @param base_size Base font size in points.
#' @param base_family Base font family.
#' @return A ggplot2 theme object.
theme_pkg_pub <- function(base_size = 10, base_family = "") {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.25, colour = "grey88"),
      axis.title = ggplot2::element_text(size = base_size),
      axis.text = ggplot2::element_text(size = base_size * 0.9),
      strip.text = ggplot2::element_text(size = base_size * 0.95, face = "bold"),
      legend.position = "right",
      legend.title = ggplot2::element_text(size = base_size * 0.9),
      legend.text = ggplot2::element_text(size = base_size * 0.85),
      plot.title = ggplot2::element_text(size = base_size * 1.1, face = "bold"),
      plot.subtitle = ggplot2::element_text(size = base_size),
      plot.caption = ggplot2::element_text(size = base_size * 0.8, hjust = 0),
      plot.margin = ggplot2::margin(6, 8, 6, 6)
    )
}

pkg_palette <- function() {
  c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#F0E442", "#000000")
}

has_finite_interval <- function(data, low = "conf.low", high = "conf.high") {
  low %in% names(data) && high %in% names(data) &&
    is.finite(data[[low]]) & is.finite(data[[high]])
}

#' Save a figure using manuscript-ready defaults
#'
#' @param plot A ggplot2 plot.
#' @param filename Output filename.
#' @param width,height Figure dimensions.
#' @param units Units for width and height.
#' @param dpi Raster resolution.
#' @param ... Additional arguments passed to [ggplot2::ggsave()].
#' @return Invisibly returns `filename`.
save_pub_figure <- function(plot, filename, width = 180, height = 120, units = "mm", dpi = 600, ...) {
  ggplot2::ggsave(
    filename = filename,
    plot = plot,
    width = width,
    height = height,
    units = units,
    dpi = dpi,
    bg = "white",
    ...
  )
  invisible(filename)
}
