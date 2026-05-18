# R package plot helper contract

## Function organization

A maintainable plotting helper usually has these layers:

1. **Validation**: check required columns and argument values.
2. **Preparation**: create plotting columns such as labels, ordering variables, and `.has_interval`.
3. **Rendering**: build and return a ggplot object.
4. **Optional export**: separate `save_*()` function, never hidden inside the plot helper.

Example structure:

```r
plot_corpairs <- function(data, facet = NULL, interval = TRUE, base_size = 10) {
  check_plot_columns(data, c("parameter", "estimate"))
  plot_data <- prep_corpairs_data(data)
  render_corpairs_plot(plot_data, facet = facet, interval = interval, base_size = base_size)
}
```

This structure makes it easy to test data handling separately from rendering.

## Validation helper pattern

```r
check_plot_columns <- function(data, required) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(
      "Missing required column(s): ", paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(data)
}
```

Use the package's existing error style if it has one.

## Interval handling

For tables with `conf.low` and `conf.high`:

```r
plot_data$.has_interval <-
  "conf.low" %in% names(plot_data) &&
  "conf.high" %in% names(plot_data) &&
  is.finite(plot_data$conf.low) &
  is.finite(plot_data$conf.high)
```

Rows with `.has_interval == FALSE` must remain visible unless the user asks to hide them. Draw them as point or line estimates and document that intervals are drawn only where finite supported bounds are present.

## Roxygen template

```r
#' Plot model parameter estimates
#'
#' Draws a publication-oriented estimate plot with optional confidence intervals.
#' Rows with non-finite interval bounds remain visible as point estimates.
#'
#' @param data A data frame containing at least `parameter` and `estimate`.
#' @param facet Optional column name used to facet the plot.
#' @param interval Logical; draw intervals when finite `conf.low` and `conf.high`
#'   columns are present.
#' @param base_size Base font size passed to the package theme.
#' @return A ggplot2 plot object.
#' @examples
#' dat <- data.frame(
#'   parameter = c("a", "b"),
#'   estimate = c(0.2, -0.1),
#'   conf.low = c(0.05, NA),
#'   conf.high = c(0.35, NA)
#' )
#' plot_parameters(dat)
#' @export
```

## Test checklist

- Missing required column produces an informative error.
- Function returns `ggplot2::ggplot`.
- `length(p$layers)` matches expected geometry structure.
- Data rows in `ggplot2::ggplot_build(p)$data` reflect all estimates.
- Intervals are absent for non-finite bounds.
- Facets are not created when `facet = NULL`.
- Multiple parameters with different y scales use `free_y` or separate plots.

## Vignette guidance

- Use realistic but compact examples.
- Show both with-interval and no-interval cases.
- Use manuscript-sized export examples only in prose or as optional code chunks.
- Explain what the viewer should learn from the figure, not only how to call the function.
