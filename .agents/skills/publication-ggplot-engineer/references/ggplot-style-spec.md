# ggplot style specification for publication R package figures

## Package theme

A good package theme should be explicit and small enough to understand. It should not over-style every plot, but it should remove accidental defaults.

Recommended ingredients:

```r
theme_pkg_pub <- function(base_size = 10, base_family = "") {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(linewidth = 0.25),
      panel.grid.major.y = ggplot2::element_blank(),
      axis.title = ggplot2::element_text(size = base_size),
      axis.text = ggplot2::element_text(size = base_size * 0.9),
      strip.text = ggplot2::element_text(size = base_size * 0.95, face = "bold"),
      legend.title = ggplot2::element_text(size = base_size * 0.9),
      legend.text = ggplot2::element_text(size = base_size * 0.85),
      plot.title = ggplot2::element_text(size = base_size * 1.1, face = "bold"),
      plot.subtitle = ggplot2::element_text(size = base_size),
      plot.caption = ggplot2::element_text(size = base_size * 0.8, hjust = 0),
      plot.margin = ggplot2::margin(6, 8, 6, 6)
    )
}
```

Adapt gridline orientation to the plot. Forest plots usually need vertical x-gridlines and no y-gridlines; time series may need subtle y-gridlines.

## Color palettes

Prefer a short, stable, colorblind-safe palette for categorical groups. A common Okabe-Ito-inspired palette is:

```r
pkg_palette <- c(
  "#0072B2", # blue
  "#D55E00", # vermillion
  "#009E73", # green
  "#CC79A7", # purple
  "#E69F00", # orange
  "#56B4E9", # sky blue
  "#F0E442", # yellow
  "#000000"  # black
)
```

Use with `scale_colour_manual(values = pkg_palette)` and `scale_fill_manual(values = pkg_palette)` when groups are stable. For continuous scales, use perceptually ordered palettes such as viridis if the dependency policy allows it, or a simple single-hue gradient.

## Labels

Convert raw column names and parameter names into readable labels.

- `estimate` -> `Estimate`
- `conf.low` / `conf.high` -> describe interval type in caption or docs.
- `rho12` -> `Correlation` or a package-specific mathematical label.
- `sigma` -> `sigma` or `Scale parameter` depending on audience.
- Long random-effect labels should be wrapped or simplified.

Use `scales::label_number()` when `scales` is already a dependency. Otherwise, keep formatting simple with base R.

## Forest plots

Recommended structure:

```r
plot_df$.has_interval <- is.finite(plot_df$conf.low) & is.finite(plot_df$conf.high)

ggplot2::ggplot(plot_df, ggplot2::aes(x = estimate, y = label)) +
  ggplot2::geom_vline(xintercept = 0, linewidth = 0.35, linetype = "dashed", colour = "grey55") +
  ggplot2::geom_segment(
    data = plot_df[plot_df$.has_interval, , drop = FALSE],
    ggplot2::aes(x = conf.low, xend = conf.high, yend = label),
    linewidth = 0.6,
    lineend = "round"
  ) +
  ggplot2::geom_point(size = 2) +
  ggplot2::coord_cartesian(xlim = c(-1, 1), clip = "off") +
  ggplot2::labs(x = "Correlation estimate", y = NULL) +
  theme_pkg_pub()
```

Do not use the same forest template blindly for non-correlation effects where `[-1, 1]` is not the domain.

## Prediction curves

Recommended structure:

```r
has_interval <- all(c("conf.low", "conf.high") %in% names(pred))
finite_interval <- has_interval && any(is.finite(pred$conf.low) & is.finite(pred$conf.high))

p <- ggplot2::ggplot(pred, ggplot2::aes(x = x, y = estimate))
if (finite_interval) {
  p <- p + ggplot2::geom_ribbon(
    data = pred[is.finite(pred$conf.low) & is.finite(pred$conf.high), , drop = FALSE],
    ggplot2::aes(ymin = conf.low, ymax = conf.high),
    alpha = 0.18,
    linewidth = 0
  )
}
p +
  ggplot2::geom_line(linewidth = 0.7) +
  ggplot2::labs(x = "Predictor", y = "Estimate") +
  theme_pkg_pub()
```

If grouping is present, map both color and fill to the same variable and keep alpha low enough that ribbons do not dominate.

## Facets

- Use `facet_wrap()` for multiple parameters or groups of the same kind.
- Use `scales = "free_y"` when y-units differ.
- Do not facet if each panel has one point and the comparison would be clearer on a shared axis.
- Prefer meaningful strip labels over raw variable values.

## Export helper

Consider an explicit export helper, not hidden saving inside plot functions:

```r
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
}
```

Use vector formats such as PDF/SVG for line art where accepted.
