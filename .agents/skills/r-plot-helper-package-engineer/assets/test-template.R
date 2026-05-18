# Test scaffolding for R package plotting helpers. Adapt to the package's conventions.

test_that("plot helper returns a ggplot object", {
  dat <- data.frame(
    parameter = c("alpha", "beta"),
    estimate = c(0.2, -0.1),
    conf.low = c(0.05, NA),
    conf.high = c(0.35, NA)
  )

  p <- plot_parameters(dat)
  expect_s3_class(p, "ggplot")
})

test_that("plot helper retains rows without finite intervals", {
  dat <- data.frame(
    parameter = c("with interval", "without interval"),
    estimate = c(0.2, -0.1),
    conf.low = c(0.05, NA),
    conf.high = c(0.35, NA)
  )

  p <- plot_parameters(dat)
  built <- ggplot2::ggplot_build(p)
  point_rows <- built$data[[length(built$data)]]
  expect_gte(nrow(point_rows), 2)
})

test_that("plot helper validates required columns", {
  dat <- data.frame(parameter = "alpha")
  expect_error(plot_parameters(dat), "estimate")
})

# Optional visual snapshot:
# test_that("plot helper visual output is stable", {
#   skip_if_not_installed("vdiffr")
#   dat <- data.frame(
#     parameter = c("alpha", "beta"),
#     estimate = c(0.2, -0.1),
#     conf.low = c(0.05, -0.25),
#     conf.high = c(0.35, 0.05)
#   )
#   vdiffr::expect_doppelganger("plot-parameters", plot_parameters(dat))
# })
