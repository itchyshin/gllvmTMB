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

gtmb_confidence_eye_point_params <- function(p) {
  point_layers <- which(gtmb_plot_geom_names(p) == "GeomPoint")
  point_layers <- point_layers[vapply(
    p$layers[point_layers],
    function(layer) identical(layer$aes_params$fill, "white"),
    logical(1L)
  )]
  expect_gt(length(point_layers), 0L)
  p$layers[[point_layers[[1L]]]]$aes_params
}

gtmb_has_bottom_axis_line <- function(p) {
  axis_line <- p$theme$axis.line.x.bottom
  inherits(axis_line, "element_line") &&
    !is.null(axis_line$colour) &&
    !identical(axis_line$colour, NA)
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

make_plot_julia_sigma_fit <- function() {
  traits <- c("length", "mass", "wing")
  units <- paste0("site", 1:4)
  loadings <- matrix(
    c(
      0.60,
      0.20,
      -0.10,
      0.45,
      0.30,
      -0.25
    ),
    nrow = length(traits),
    byrow = TRUE
  )
  sigma <- loadings %*% t(loadings)
  scores <- matrix(
    seq(-0.3, 0.4, length.out = length(units) * ncol(loadings)),
    nrow = length(units),
    dimnames = list(units, paste0("LV", seq_len(ncol(loadings))))
  )
  fit <- structure(
    list(
      family = "poisson",
      model = "poisson_rr",
      d = ncol(loadings),
      n_traits = length(traits),
      n_units = length(units),
      trait_names = traits,
      unit_names = units,
      alpha = seq(0.1, 0.3, length.out = length(traits)),
      loadings = loadings,
      scores = scores,
      Sigma = sigma,
      correlation = stats::cov2cor(sigma),
      loglik = -12,
      aic = 42,
      bic = 45,
      df = 8L,
      nobs = length(traits) * length(units),
      converged = TRUE,
      message = "converged"
    ),
    class = c("gllvmTMB_julia", "list")
  )
  fit <- .gllvm_julia_normalise_result(fit)
  fit$engine <- "julia"
  fit
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

  p <- plot_correlations(boot, style = "eye")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_confidence_eye",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "provided")
  expect_match(meta$notes, "n_boot = 25", fixed = TRUE)
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 6L)
  expect_setequal(plot_data$.facet, c("unit", "unit_obs"))
  expect_true(all(plot_data$.has_interval))
  expect_true(all(plot_data$.has_uncertainty_display))
  expect_match(p$labels$caption, "not posterior densities", fixed = TRUE)
  expect_no_match(p$labels$caption, "Open points", fixed = TRUE)
  expect_s3_class(attr(p, "gllvmTMB_confidence_eye_data"), "data.frame")
  expect_silent(ggplot2::ggplot_build(p))

  p_pair <- plot_correlations(boot, tier = "unit", pair = c("length", "mass"))
  expect_equal(nrow(attr(p_pair, "gllvmTMB_data")), 1L)
})

test_that("plot_correlations can render confidence-eye compatibility shapes", {
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

  p <- plot_correlations(cors, style = "eye")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_confidence_eye",
    "extract_correlations"
  )
  expect_equal(meta$interval_status, "provided")
  eye <- attr(p, "gllvmTMB_confidence_eye_data")
  expect_s3_class(eye, "data.frame")
  expect_gt(nrow(eye), nrow(cors))
  expect_true(all(eye$.x > -1 & eye$.x < 1))
  expect_false("GeomSegment" %in% gtmb_plot_geom_names(p))
  expect_false("GeomLine" %in% gtmb_plot_geom_names(p))
  expect_true(gtmb_has_bottom_axis_line(p))
  eye_point <- gtmb_confidence_eye_point_params(p)
  expect_equal(eye_point$shape, 21)
  expect_equal(eye_point$fill, "white")
  expect_gte(eye_point$size, 3)
  expect_gte(eye_point$stroke, 1)
  expect_gt(eye_point$alpha, 0.9)
  expect_silent(ggplot2::ggplot_build(p))

  p_with_line <- plot_correlations(
    cors,
    style = "eye",
    show_intervals = TRUE
  )
  expect_true("GeomSegment" %in% gtmb_plot_geom_names(p_with_line))

  p_alias <- plot_correlations(cors, style = "raindrop")
  expect_gtmb_cov_plot_meta(
    p_alias,
    "correlations_confidence_eye",
    "extract_correlations"
  )
  expect_s3_class(attr(p_alias, "gllvmTMB_raindrop_data"), "data.frame")
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

  p <- plot_correlations(cors, style = "eye")

  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_confidence_eye",
    "extract_correlations"
  )
  expect_equal(meta$interval_status, "partial")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(sum(plot_data$.has_interval), 2L)
  expect_equal(sum(plot_data$.has_confidence_eye), 2L)
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
  expect_error(
    plot_correlations(list()),
    regexp = "fit returned by .*gllvmTMB"
  )
})

test_that("plot_correlations renders tidy rows as a heatmap matrix", {
  skip_if_no_ggplot2()
  cors <- data.frame(
    tier = "unit",
    trait_i = c("length", "length", "mass"),
    trait_j = c("mass", "wing", "wing"),
    correlation = c(0.42, -0.18, 0.33),
    lower = c(0.12, -0.45, NA_real_),
    upper = c(0.66, 0.12, NA_real_),
    method = c("fisher-z", "fisher-z", "none"),
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(
    cors,
    style = "heatmap",
    triangle = "lower",
    label_type = "estimate_ci"
  )

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_heatmap",
    "extract_correlations"
  )
  expect_equal(meta$interval_status, "partial")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 6L)
  expect_true(all(plot_data$.triangle %in% c("lower", "diagonal")))
  expect_true(all(plot_data$.row_index >= plot_data$.col_index))
  expect_true(any(grepl("\\[0.12, 0.66\\]", plot_data$.label)))
  expect_true("GeomTile" %in% gtmb_plot_geom_names(p))
  expect_true("GeomText" %in% gtmb_plot_geom_names(p))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_correlations can use the full matrix for estimates and intervals", {
  skip_if_no_ggplot2()
  cors <- data.frame(
    tier = "unit",
    trait_i = c("length", "length", "mass"),
    trait_j = c("mass", "wing", "wing"),
    correlation = c(0.42, -0.18, 0.33),
    lower = c(0.12, -0.45, 0.05),
    upper = c(0.66, 0.12, 0.56),
    method = "fisher-z",
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(
    cors,
    style = "heatmap",
    triangle = "lower",
    matrix_layout = "estimate_ci"
  )

  expect_s3_class(p, "ggplot")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(unique(plot_data$.matrix_layout), "estimate_ci")
  expect_setequal(plot_data$.triangle, c("upper", "lower", "diagonal"))
  expect_true(all(
    plot_data$.label_type[plot_data$.triangle == "upper"] == "estimate"
  ))
  expect_true(all(
    plot_data$.label_type[plot_data$.triangle == "lower"] == "ci"
  ))
  expect_true(any(grepl("\\[0.12, 0.66\\]", plot_data$.label)))
  expect_match(p$labels$subtitle, "Upper triangle: estimates", fixed = TRUE)
  expect_match(p$labels$caption, "Upper labels show estimates", fixed = TRUE)
  expect_silent(ggplot2::ggplot_build(p))

  p_no_labels <- plot_correlations(
    cors,
    style = "heatmap",
    matrix_layout = "estimate_ci",
    label = FALSE
  )
  expect_false("GeomText" %in% gtmb_plot_geom_names(p_no_labels))
  expect_no_match(p_no_labels$labels$caption, "labels show", fixed = TRUE)
})

test_that("plot_correlations can combine two covariance levels in one matrix", {
  skip_if_no_ggplot2()
  cors <- data.frame(
    tier = rep(c("unit", "unit_obs"), each = 3L),
    trait_i = rep(c("length", "length", "mass"), 2L),
    trait_j = rep(c("mass", "wing", "wing"), 2L),
    correlation = c(0.42, -0.18, 0.33, 0.10, -0.12, 0.28),
    lower = c(0.12, -0.45, 0.05, -0.15, -0.34, 0.04),
    upper = c(0.66, 0.12, 0.56, 0.30, 0.12, 0.48),
    method = "fisher-z",
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(
    cors,
    style = "heatmap",
    matrix_layout = "levels"
  )

  expect_s3_class(p, "ggplot")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(unique(plot_data$.matrix_layout), "levels")
  expect_equal(unique(as.character(plot_data$.facet)), "All rows")
  expect_setequal(plot_data$.display_level, c("unit", "unit_obs", "diagonal"))
  expect_true(all(
    plot_data$.display_level[plot_data$.triangle == "upper"] == "unit"
  ))
  expect_true(all(
    plot_data$.display_level[plot_data$.triangle == "lower"] == "unit_obs"
  ))
  expect_false(inherits(p$facet, "FacetWrap"))
  expect_match(p$labels$subtitle, "Upper triangle: unit", fixed = TRUE)
  expect_match(p$labels$caption, "lower triangle shows unit_obs", fixed = TRUE)
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_correlations renders ellipse matrix views", {
  skip_if_no_ggplot2()
  cors <- data.frame(
    tier = "unit",
    trait_i = c("length", "length", "mass"),
    trait_j = c("mass", "wing", "wing"),
    correlation = c(0.42, -0.18, 0.33),
    lower = c(0.12, -0.45, 0.05),
    upper = c(0.66, 0.12, 0.56),
    method = "fisher-z",
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(
    cors,
    style = "oval",
    triangle = "upper",
    include_diagonal = FALSE,
    label_type = "ci"
  )

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "correlations_ellipse",
    "extract_correlations"
  )
  expect_equal(meta$interval_status, "provided")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 3L)
  expect_true(all(plot_data$.triangle == "upper"))
  expect_false(any(plot_data$.diagonal))
  expect_true(any(plot_data$.significant))
  expect_s3_class(attr(p, "gllvmTMB_ellipse_data"), "data.frame")
  expect_true("GeomPolygon" %in% gtmb_plot_geom_names(p))
  expect_true("GeomText" %in% gtmb_plot_geom_names(p))
  expect_silent(ggplot2::ggplot_build(p))

  multi <- rbind(
    cors,
    transform(cors, tier = "unit_obs", correlation = correlation / 2)
  )
  p_faceted <- plot_correlations(
    multi,
    style = "ellipse",
    triangle = "upper",
    include_diagonal = FALSE,
    label = FALSE
  )
  ellipse_data <- attr(p_faceted, "gllvmTMB_ellipse_data")
  expect_setequal(as.character(ellipse_data$.facet), c("unit", "unit_obs"))
  expect_true(inherits(p_faceted$facet, "FacetWrap"))
  expect_silent(ggplot2::ggplot_build(p_faceted))
})

test_that("plot_correlations validates matrix-specific options", {
  skip_if_no_ggplot2()
  cors <- data.frame(
    tier = c("unit", "unit_obs"),
    trait_i = "length",
    trait_j = "mass",
    correlation = c(0.42, 0.10),
    lower = c(0.12, NA_real_),
    upper = c(0.66, NA_real_),
    method = c("fisher-z", "none"),
    stringsAsFactors = FALSE
  )

  expect_error(
    plot_correlations(cors, style = "heatmap", facet = "none"),
    regexp = "multiple levels"
  )
  expect_error(
    plot_correlations(
      cors[1L, , drop = FALSE],
      style = "heatmap",
      label_digits = -1
    ),
    regexp = "label_digits"
  )
  expect_error(
    plot_correlations(
      cors[1L, , drop = FALSE],
      style = "heatmap",
      matrix_layout = "levels"
    ),
    regexp = "exactly two correlation levels"
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

  p <- plot_Sigma_table(sigma_rows, style = "eye")

  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_table_confidence_eye",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "partial")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(sum(plot_data$.has_interval), 2L)
  expect_equal(sum(plot_data$.has_confidence_eye), 2L)
  expect_equal(sum(plot_data$.has_uncertainty_display), 2L)
  expect_equal(sum(gtmb_plot_geom_names(p) == "GeomPoint"), 2L)
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_Sigma_table can render confidence eyes from finite table intervals", {
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

  p <- plot_Sigma_table(sigma_rows, style = "eye")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_table_confidence_eye",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "provided")
  eye <- attr(p, "gllvmTMB_confidence_eye_data")
  expect_s3_class(eye, "data.frame")
  expect_gt(nrow(eye), nrow(sigma_rows))
  expect_true(all(is.finite(eye$.x)))
  expect_match(p$labels$caption, "not posterior densities", fixed = TRUE)
  expect_no_match(p$labels$caption, "Open points", fixed = TRUE)
  expect_false("GeomSegment" %in% gtmb_plot_geom_names(p))
  expect_false("GeomLine" %in% gtmb_plot_geom_names(p))
  expect_true(gtmb_has_bottom_axis_line(p))
  eye_point <- gtmb_confidence_eye_point_params(p)
  expect_equal(eye_point$shape, 21)
  expect_equal(eye_point$fill, "white")
  expect_gte(eye_point$size, 3)
  expect_gte(eye_point$stroke, 1)
  expect_gt(eye_point$alpha, 0.9)
  expect_silent(ggplot2::ggplot_build(p))

  p_with_line <- plot_Sigma_table(
    sigma_rows,
    style = "eye",
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
    level = "unit",
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
  expect_match(meta$notes, "n_boot = 20", fixed = TRUE)
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 3L)
  expect_equal(unique(plot_data$interval_method), "bootstrap")
  expect_true(all(plot_data$.draw_interval))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("Sigma plot helpers accept Julia bridge point rows", {
  skip_if_no_ggplot2()
  fit <- make_plot_julia_sigma_fit()

  p_table <- plot_Sigma_table(
    fit,
    measure = "correlation",
    entries = "upper",
    link_residual = "none"
  )
  expect_s3_class(p_table, "ggplot")
  meta_table <- expect_gtmb_cov_plot_meta(
    p_table,
    "sigma_table_forest",
    "extract_Sigma_table"
  )
  expect_equal(meta_table$interval_status, "none")
  table_data <- attr(p_table, "gllvmTMB_data")
  expect_equal(nrow(table_data), choose(fit$n_traits, 2L))
  expect_equal(unique(table_data$validation_row), "Julia-bridge covariance/ordination extractor (partial)")
  expect_equal(unique(table_data$interval_status), "none")
  expect_false(any(table_data$.has_uncertainty_display))
  expect_silent(ggplot2::ggplot_build(p_table))

  p_heatmap <- plot_Sigma_heatmap(
    fit,
    measure = "correlation",
    entries = "all",
    link_residual = "none"
  )
  expect_s3_class(p_heatmap, "ggplot")
  meta_heatmap <- expect_gtmb_cov_plot_meta(
    p_heatmap,
    "sigma_heatmap",
    "extract_Sigma_table"
  )
  expect_equal(meta_heatmap$interval_status, "not_displayed")
  heatmap_data <- attr(p_heatmap, "gllvmTMB_data")
  expect_equal(nrow(heatmap_data), fit$n_traits^2)
  expect_equal(unique(heatmap_data$validation_row), "Julia-bridge covariance/ordination extractor (partial)")
  expect_silent(ggplot2::ggplot_build(p_heatmap))
})

test_that("plot_Sigma_comparison accepts Julia bridge point rows", {
  skip_if_no_ggplot2()
  fit <- make_plot_julia_sigma_fit()
  truth <- stats::cov2cor(fit$Sigma)
  dimnames(truth) <- list(fit$trait_names, fit$trait_names)
  truth["length", "mass"] <- truth["mass", "length"] <-
    truth["length", "mass"] - 0.02

  p <- plot_Sigma_comparison(
    fit,
    truth = truth,
    measure = "correlation",
    entries = "upper",
    link_residual = "none"
  )

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_comparison_difference",
    "compare_Sigma_table"
  )
  expect_equal(meta$interval_status, "not_applicable")
  expect_equal(meta$comparison_status, "compared")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), choose(fit$n_traits, 2L))
  expect_equal(unique(plot_data$validation_row), "Julia-bridge covariance/ordination extractor (partial)")
  expect_equal(unique(plot_data$interval_status), "none")
  expect_equal(plot_data$.error, plot_data$estimate - plot_data$truth)
  expect_true(all(plot_data$.can_compare))
  expect_true("GeomSegment" %in% gtmb_plot_geom_names(p))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_Sigma_heatmap renders Sigma-table rows as matrix cells", {
  skip_if_no_ggplot2()
  corr_rows <- data.frame(
    level = rep(c("Core model", "Adjusted model"), each = 4L),
    trait_i = rep(c("length", "length", "mass", "mass"), 2L),
    trait_j = rep(c("length", "mass", "length", "mass"), 2L),
    i = rep(c(1L, 1L, 2L, 2L), 2L),
    j = rep(c(1L, 2L, 1L, 2L), 2L),
    estimate = c(1 + 1e-12, 0.35, 0.35, 1, 1, 0.28, 0.28, 1),
    matrix = "R",
    component = "total",
    diagonal = rep(c(TRUE, FALSE, FALSE, TRUE), 2L),
    triangle = rep(c("diagonal", "upper", "lower", "diagonal"), 2L),
    scale = "correlation",
    stringsAsFactors = FALSE
  )

  p <- plot_Sigma_heatmap(
    corr_rows,
    title = "Core vs adjusted correlations",
    subtitle = "Point estimates by model.",
    caption = "No interval bars in this heatmap."
  )

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_heatmap",
    "extract_Sigma_table"
  )
  expect_equal(meta$interval_status, "not_displayed")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), nrow(corr_rows))
  expect_setequal(plot_data$.facet, c("Core model", "Adjusted model"))
  expect_equal(levels(plot_data$.facet), c("Core model", "Adjusted model"))
  expect_lte(max(plot_data$.fill_estimate), 1)
  expect_equal(levels(plot_data$.trait_x), c("length", "mass"))
  expect_equal(levels(plot_data$.trait_y), c("mass", "length"))
  expect_true("GeomTile" %in% gtmb_plot_geom_names(p))
  expect_true("GeomText" %in% gtmb_plot_geom_names(p))
  expect_true(inherits(p$facet, "FacetWrap"))
  expect_equal(p$labels$title, "Core vs adjusted correlations")
  expect_equal(p$labels$subtitle, "Point estimates by model.")
  expect_equal(p$labels$caption, "No interval bars in this heatmap.")
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_Sigma_heatmap can omit diagonals and labels", {
  skip_if_no_ggplot2()
  sigma_rows <- data.frame(
    level = "unit",
    trait_i = c("length", "length", "mass"),
    trait_j = c("length", "mass", "mass"),
    estimate = c(0.80, 0.22, 0.50),
    matrix = "Sigma",
    component = "total",
    diagonal = c(TRUE, FALSE, TRUE),
    triangle = c("diagonal", "upper", "diagonal"),
    stringsAsFactors = FALSE
  )

  p <- plot_Sigma_heatmap(
    sigma_rows,
    include_diagonal = FALSE,
    label = FALSE
  )

  expect_s3_class(p, "ggplot")
  expect_equal(nrow(attr(p, "gllvmTMB_data")), 1L)
  expect_false(any(attr(p, "gllvmTMB_data")$diagonal))
  expect_true("GeomTile" %in% gtmb_plot_geom_names(p))
  expect_false("GeomText" %in% gtmb_plot_geom_names(p))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_Sigma_heatmap validates required tidy columns", {
  skip_if_no_ggplot2()
  bad <- data.frame(
    level = "unit",
    trait_i = "length",
    estimate = 0.2
  )
  expect_error(
    plot_Sigma_heatmap(bad),
    regexp = "missing required column"
  )
  expect_error(
    plot_Sigma_heatmap(transform(bad, trait_j = "mass"), label_digits = -1),
    regexp = "label_digits"
  )
  expect_error(
    plot_Sigma_heatmap(transform(bad, trait_j = "mass"), title = NA_character_),
    regexp = "title"
  )
  expect_error(
    plot_Sigma_table(list()),
    regexp = "fit returned by .*gllvmTMB"
  )
  expect_error(
    plot_Sigma_heatmap(list()),
    regexp = "fit returned by .*gllvmTMB"
  )
})

test_that("plot_Sigma_comparison plots row-wise truth errors", {
  skip_if_no_ggplot2()
  rows <- data.frame(
    level = "unit",
    trait_i = c("length", "length", "mass"),
    trait_j = c("mass", "wing", "wing"),
    estimate = c(0.62, -0.10, 0.28),
    lower = NA_real_,
    upper = NA_real_,
    matrix = "R",
    component = "total",
    diagonal = FALSE,
    triangle = "upper",
    scale = "correlation",
    stringsAsFactors = FALSE
  )
  truth <- matrix(
    c(
      1,
      0.60,
      -0.05,
      0.60,
      1,
      0.20,
      -0.05,
      0.20,
      1
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(c("length", "mass", "wing"), c("length", "mass", "wing"))
  )

  p <- plot_Sigma_comparison(rows, truth, measure = "correlation")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_comparison_difference",
    "compare_Sigma_table"
  )
  expect_equal(meta$interval_status, "not_applicable")
  expect_equal(meta$comparison_status, "compared")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(nrow(plot_data), 3L)
  expect_equal(plot_data$.error, plot_data$estimate - plot_data$truth)
  expect_true(all(plot_data$.can_compare))
  expect_true("GeomSegment" %in% gtmb_plot_geom_names(p))
  expect_match(p$labels$caption, "not confidence intervals", fixed = TRUE)
  expect_silent(ggplot2::ggplot_build(p))

  diag_rows <- transform(
    rows[1L, ],
    trait_j = trait_i,
    estimate = 0.72,
    truth = 0.70,
    error = 0.02,
    abs_error = 0.02,
    comparison_status = "compared",
    matrix = "Sigma",
    diagonal = TRUE,
    scale = "covariance"
  )
  p_diag <- plot_Sigma_comparison(
    diag_rows,
    measure = "covariance",
    include_diagonal = TRUE
  )
  expect_equal(p_diag$labels$title, "Sigma error by entry")
})

test_that("plot_Sigma_comparison can plot precomputed scatter comparisons", {
  skip_if_no_ggplot2()
  rows <- data.frame(
    level = "unit",
    trait_i = c("length", "length"),
    trait_j = c("mass", "wing"),
    estimate = c(0.62, -0.10),
    truth = c(0.60, -0.05),
    error = c(0.02, -0.05),
    abs_error = c(0.02, 0.05),
    comparison_status = "compared",
    matrix = "R",
    diagonal = FALSE,
    scale = "correlation",
    stringsAsFactors = FALSE
  )

  p <- plot_Sigma_comparison(rows, style = "scatter", measure = "correlation")

  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_cov_plot_meta(
    p,
    "sigma_comparison_scatter",
    "compare_Sigma_table"
  )
  expect_equal(meta$comparison_status, "compared")
  expect_equal(nrow(attr(p, "gllvmTMB_data")), 2L)
  expect_equal(p$labels$title, "Correlation estimates vs truth")
  expect_equal(p$labels$subtitle, "One-to-one = exact; segments = error.")
  expect_equal(p$labels$caption, "Segments are errors, not CIs.")
  expect_true("GeomAbline" %in% gtmb_plot_geom_names(p))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_Sigma_comparison facets named comparisons", {
  skip_if_no_ggplot2()
  rows_a <- data.frame(
    level = "unit",
    trait_i = c("length", "length"),
    trait_j = c("mass", "wing"),
    estimate = c(0.70, -0.16),
    truth = c(0.60, -0.05),
    error = c(0.10, -0.11),
    abs_error = c(0.10, 0.11),
    comparison_status = "compared",
    comparison = "Model A",
    matrix = "R",
    diagonal = FALSE,
    scale = "correlation",
    stringsAsFactors = FALSE
  )
  rows_b <- rows_a
  rows_b$estimate <- c(0.62, -0.08)
  rows_b$error <- rows_b$estimate - rows_b$truth
  rows_b$abs_error <- abs(rows_b$error)
  rows_b$comparison <- "Model B"
  rows <- rbind(rows_a, rows_b)

  p <- plot_Sigma_comparison(
    rows,
    measure = "correlation",
    facet = "comparison",
    sort = "trait"
  )

  expect_s3_class(p, "ggplot")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_setequal(plot_data$.facet, c("Model A", "Model B"))
  expect_gt(
    min(plot_data$.y[plot_data$.facet == "Model A"]),
    max(plot_data$.y[plot_data$.facet == "Model B"])
  )
  expect_true(inherits(p$facet, "FacetWrap"))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_Sigma_comparison validates comparison inputs", {
  skip_if_no_ggplot2()
  bad <- data.frame(
    trait_i = "length",
    trait_j = "mass",
    estimate = 0.2
  )
  expect_error(
    plot_Sigma_comparison(bad),
    regexp = "missing required column"
  )
})
