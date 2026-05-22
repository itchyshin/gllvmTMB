skip_if_no_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

expect_gtmb_cov_plot_meta <- function(p, type, source) {
  meta <- attr(p, "gllvmTMB_meta")
  expect_type(meta, "list")
  expect_equal(meta$type, type)
  expect_equal(meta$source, source)
  invisible(meta)
}

gtmb_plot_geom_names <- function(p) {
  vapply(p$layers, function(layer) class(layer$geom)[1], character(1L))
}

make_bootstrap_correlation_plot_object <- function() {
  traits <- c("length", "mass", "wing")
  R_B <- matrix(
    c(
      1.00,
      0.45,
      -0.20,
      0.45,
      1.00,
      0.30,
      -0.20,
      0.30,
      1.00
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(traits, traits)
  )
  R_W <- matrix(
    c(
      1.00,
      -0.25,
      0.12,
      -0.25,
      1.00,
      -0.35,
      0.12,
      -0.35,
      1.00
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(traits, traits)
  )
  lower_B <- pmax(R_B - 0.12, -1)
  upper_B <- pmin(R_B + 0.12, 1)
  lower_W <- pmax(R_W - 0.10, -1)
  upper_W <- pmin(R_W + 0.10, 1)
  diag(lower_B) <- diag(upper_B) <- 1
  diag(lower_W) <- diag(upper_W) <- 1
  boot <- list(
    point_est = list(R_B = R_B, R_W = R_W),
    ci_lower = list(R_B = lower_B, R_W = lower_W),
    ci_upper = list(R_B = upper_B, R_W = upper_W),
    ci_method = "percentile",
    link_residual = "auto",
    conf = 0.95,
    n_boot = 25L,
    n_failed = 0L,
    level = c("B", "W"),
    what = "R",
    draws = NULL
  )
  class(boot) <- c("bootstrap_Sigma", "list")
  boot
}

test_that("plot_correlations returns an interval-aware forest plot", {
  skip_if_no_ggplot2()
  cors <- data.frame(
    tier = c("unit", "unit", "unit", "unit_obs", "unit_obs"),
    trait_i = c("length", "length", "mass", "length", "mass"),
    trait_j = c("mass", "wing", "wing", "mass", "wing"),
    correlation = c(0.42, -0.18, 0.33, 0.10, -0.28),
    lower = c(0.12, -0.45, 0.05, NA_real_, -0.53),
    upper = c(0.66, 0.12, 0.56, NA_real_, 0.02),
    method = c("fisher-z", "fisher-z", "fisher-z", "none", "fisher-z"),
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(cors)
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_forest",
    "extract_correlations"
  )
  expect_equal(meta$interval_status, "partial")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_s3_class(plot_data, "data.frame")
  expect_equal(nrow(plot_data), nrow(cors))
  expect_equal(sum(plot_data$.has_interval), 4L)
  expect_equal(sum(plot_data$.draw_interval), 4L)
  expect_equal(sum(plot_data$.has_uncertainty_display), 4L)
  expect_true("GeomSegment" %in% gtmb_plot_geom_names(p))
  expect_setequal(
    plot_data$.pair_label,
    c("length - mass", "length - wing", "mass - wing")
  )
  expect_true(all(plot_data$.estimate >= -1 & plot_data$.estimate <= 1))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_correlations accepts bootstrap_Sigma correlation summaries", {
  skip_if_no_ggplot2()
  boot <- make_bootstrap_correlation_plot_object()

  p <- plot_correlations(boot, style = "raindrop")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_raindrop",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "provided")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 6L)
  expect_setequal(plot_data$.facet, c("unit", "unit_obs"))
  expect_true(all(plot_data$.has_interval))
  expect_true(all(plot_data$.has_uncertainty_display))
  expect_match(p$labels$caption, "not posterior densities", fixed = TRUE)
  expect_no_match(p$labels$caption, "Open points", fixed = TRUE)
  expect_s3_class(attr(p, "gllvmTMB_raindrop_data"), "data.frame")
  expect_silent(ggplot2::ggplot_build(p))

  p_pair <- plot_correlations(boot, tier = "unit", pair = c("length", "mass"))
  expect_equal(nrow(attr(p_pair, "gllvmTMB_data")), 1L)
})

test_that("plot_correlations can render raindrop compatibility shapes", {
  skip_if_no_ggplot2()
  cors <- data.frame(
    tier = c("unit", "unit"),
    trait_i = c("length", "mass"),
    trait_j = c("mass", "wing"),
    correlation = c(0.42, -0.28),
    lower = c(0.12, -0.53),
    upper = c(0.66, 0.02),
    method = "fisher-z",
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(cors, style = "raindrop")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_raindrop",
    "extract_correlations"
  )
  expect_equal(meta$interval_status, "provided")
  rain <- attr(p, "gllvmTMB_raindrop_data")
  expect_s3_class(rain, "data.frame")
  expect_gt(nrow(rain), nrow(cors))
  expect_true(all(rain$.x > -1 & rain$.x < 1))
  expect_false("GeomSegment" %in% gtmb_plot_geom_names(p))
  expect_silent(ggplot2::ggplot_build(p))

  p_with_line <- plot_correlations(
    cors,
    style = "raindrop",
    show_intervals = TRUE
  )
  expect_true("GeomSegment" %in% gtmb_plot_geom_names(p_with_line))
})

test_that("plot_correlations marks rows without intervals as point-only", {
  skip_if_no_ggplot2()
  cors <- data.frame(
    tier = c("unit", "unit", "unit"),
    trait_i = c("length", "length", "mass"),
    trait_j = c("mass", "wing", "wing"),
    correlation = c(0.42, -0.18, 0.33),
    lower = c(0.12, -0.45, NA_real_),
    upper = c(0.66, 0.12, NA_real_),
    method = c("fisher-z", "fisher-z", "none"),
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(cors, style = "raindrop")

  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_raindrop",
    "extract_correlations"
  )
  expect_equal(meta$interval_status, "partial")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(sum(plot_data$.has_interval), 2L)
  expect_equal(sum(plot_data$.has_raindrop), 2L)
  expect_equal(sum(plot_data$.has_uncertainty_display), 2L)
  expect_equal(sum(gtmb_plot_geom_names(p) == "GeomPoint"), 2L)
  expect_match(p$labels$caption, "Open points", fixed = TRUE)
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_correlations validates required tidy columns", {
  skip_if_no_ggplot2()
  bad <- data.frame(
    tier = "unit",
    trait_i = "length",
    trait_j = "mass",
    correlation = 0.2
  )
  expect_error(
    plot_correlations(bad),
    regexp = "missing required column"
  )
})

test_that("plot_Sigma_table omits diagonal rows by default", {
  skip_if_no_ggplot2()
  sigma_rows <- data.frame(
    level = c("unit", "unit", "unit"),
    trait_i = c("length", "length", "mass"),
    trait_j = c("length", "mass", "mass"),
    estimate = c(0.80, 0.22, 0.50),
    lower = NA_real_,
    upper = NA_real_,
    matrix = "Sigma",
    component = "total",
    diagonal = c(TRUE, FALSE, TRUE),
    triangle = c("diagonal", "upper", "diagonal"),
    stringsAsFactors = FALSE
  )

  p <- plot_Sigma_table(sigma_rows)
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_table_forest",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "none")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 1L)
  expect_false(any(plot_data$diagonal))
  expect_false(any(plot_data$.draw_interval))
  expect_false(any(plot_data$.has_uncertainty_display))
  expect_silent(ggplot2::ggplot_build(p))

  p_diag <- plot_Sigma_table(sigma_rows, include_diagonal = TRUE)
  expect_equal(nrow(attr(p_diag, "gllvmTMB_data")), 3L)
})

test_that("plot_Sigma_table fitted-object default keeps each pair once", {
  entries_default <- eval(formals(plot_Sigma_table)$entries)
  expect_equal(entries_default[[1L]], "upper")
  expect_true("offdiag" %in% entries_default)
})

test_that("plot_Sigma_table handles correlation-scale table rows", {
  skip_if_no_ggplot2()
  corr_rows <- data.frame(
    level = c("unit", "unit_obs"),
    trait_i = c("length", "length"),
    trait_j = c("mass", "mass"),
    estimate = c(0.35, -0.12),
    lower = NA_real_,
    upper = NA_real_,
    matrix = "R",
    component = "total",
    diagonal = FALSE,
    triangle = "upper",
    scale = "correlation",
    stringsAsFactors = FALSE
  )

  p <- plot_Sigma_table(corr_rows)
  expect_s3_class(p, "ggplot")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 2L)
  expect_true(all(plot_data$.estimate >= -1 & plot_data$.estimate <= 1))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_Sigma_table marks rows without intervals as point-only", {
  skip_if_no_ggplot2()
  sigma_rows <- data.frame(
    level = "unit",
    trait_i = c("length", "mass", "length"),
    trait_j = c("mass", "wing", "wing"),
    estimate = c(0.22, -0.08, 0.15),
    lower = c(0.08, -0.18, NA_real_),
    upper = c(0.35, 0.02, NA_real_),
    matrix = "Sigma",
    component = "total",
    diagonal = FALSE,
    triangle = "upper",
    stringsAsFactors = FALSE
  )

  p <- plot_Sigma_table(sigma_rows, style = "raindrop")

  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_table_raindrop",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "partial")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(sum(plot_data$.has_interval), 2L)
  expect_equal(sum(plot_data$.has_raindrop), 2L)
  expect_equal(sum(plot_data$.has_uncertainty_display), 2L)
  expect_equal(sum(gtmb_plot_geom_names(p) == "GeomPoint"), 2L)
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_Sigma_table can render raindrops from finite table intervals", {
  skip_if_no_ggplot2()
  sigma_rows <- data.frame(
    level = "unit",
    trait_i = c("length", "mass"),
    trait_j = c("mass", "wing"),
    estimate = c(0.22, -0.08),
    lower = c(0.08, -0.18),
    upper = c(0.35, 0.02),
    matrix = "Sigma",
    component = "total",
    diagonal = FALSE,
    triangle = "upper",
    stringsAsFactors = FALSE
  )

  p <- plot_Sigma_table(sigma_rows, style = "raindrop")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_table_raindrop",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "provided")
  rain <- attr(p, "gllvmTMB_raindrop_data")
  expect_s3_class(rain, "data.frame")
  expect_gt(nrow(rain), nrow(sigma_rows))
  expect_true(all(is.finite(rain$.x)))
  expect_match(p$labels$caption, "not posterior densities", fixed = TRUE)
  expect_no_match(p$labels$caption, "Open points", fixed = TRUE)
  expect_false("GeomSegment" %in% gtmb_plot_geom_names(p))
  expect_silent(ggplot2::ggplot_build(p))

  p_with_line <- plot_Sigma_table(
    sigma_rows,
    style = "raindrop",
    show_intervals = TRUE
  )
  expect_true("GeomSegment" %in% gtmb_plot_geom_names(p_with_line))
})

test_that("plot_Sigma_table accepts bootstrap_Sigma objects", {
  skip_if_no_ggplot2()
  Sigma <- matrix(
    c(
      1.0,
      0.2,
      -0.1,
      0.2,
      0.8,
      0.3,
      -0.1,
      0.3,
      1.2
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(c("length", "mass", "wing"), c("length", "mass", "wing"))
  )
  boot <- list(
    point_est = list(Sigma_B = Sigma),
    ci_lower = list(Sigma_B = Sigma - 0.05),
    ci_upper = list(Sigma_B = Sigma + 0.05),
    ci_method = "percentile",
    link_residual = "auto",
    conf = 0.95,
    n_boot = 20L,
    n_failed = 0L,
    level = "B",
    what = "Sigma",
    draws = NULL
  )
  class(boot) <- c("bootstrap_Sigma", "list")

  p <- plot_Sigma_table(boot, level = "unit", entries = "upper")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_table_forest",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "provided")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 3L)
  expect_equal(unique(plot_data$interval_method), "bootstrap")
  expect_true(all(plot_data$.draw_interval))
  expect_silent(ggplot2::ggplot_build(p))
})
