## Tests for plot.gllvmTMB_multi() — the ggplot2-based S3 dispatcher.
## Each test fits a small model with both rr() and diag() at both tiers
## (the recommended decomposition), calls plot(fit, type = "..."), and
## verifies the return is a ggplot whose data slot has the expected
## structure. We do NOT compare pixels; rendering is not tested.

skip_if_no_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

expect_gtmb_plot_meta <- function(p, type, source) {
  meta <- attr(p, "gllvmTMB_meta")
  expect_type(meta, "list")
  expect_named(
    meta,
    c("type", "source", "level", "interval_status", "rotation_status", "notes")
  )
  expect_equal(meta$type, type)
  expect_equal(meta$source, source)
  invisible(meta)
}

make_BW_fit_for_plot <- function(seed = 1) {
  set.seed(seed)
  Tn <- 4
  Lambda_B <- matrix(c(1.0, 0.5, -0.4, 0.3, 0.0, 0.8, 0.4, -0.2), Tn, 2)
  Lambda_W <- matrix(c(0.4, 0.2, -0.1, 0.3), Tn, 1)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 30,
    n_species = 6,
    n_traits = Tn,
    mean_species_per_site = 4,
    Lambda_B = Lambda_B,
    psi_B = c(0.20, 0.15, 0.10, 0.25),
    Lambda_W = Lambda_W,
    psi_W = c(0.10, 0.08, 0.05, 0.12),
    beta = matrix(0, Tn, 2),
    seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 2) +
      unique(0 + trait | site) +
      latent(0 + trait | site_species, d = 1) +
      unique(0 + trait | site_species),
    data = s$data
  )))
}

make_fake_ordination_fit <- function(
  d = 3L,
  n_units = 18L,
  n_traits = 5L,
  seed = 99L
) {
  set.seed(seed)
  traits <- paste0("T", seq_len(n_traits))
  units <- paste0("unit", seq_len(n_units))
  scores <- matrix(rnorm(n_units * d), nrow = n_units, ncol = d)
  Lambda <- matrix(rnorm(n_traits * d, sd = 0.45), nrow = n_traits, ncol = d)
  rownames(Lambda) <- traits
  colnames(Lambda) <- paste0("LV", seq_len(d))
  structure(
    list(
      data = data.frame(
        trait = factor(rep(traits, each = n_units), levels = traits),
        unit = factor(rep(units, times = n_traits), levels = units)
      ),
      trait_col = "trait",
      unit_col = "unit",
      use = list(rr_B = TRUE, rr_W = FALSE),
      d_B = d,
      d_W = 0L,
      n_sites = n_units,
      report = list(Lambda_B = Lambda),
      tmb_obj = list(
        env = list(
          last.par.best = stats::setNames(
            as.vector(t(scores)),
            rep("z_B", n_units * d)
          )
        )
      )
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("plot(type = 'correlation') returns a ggplot with combined upper/lower triangle data", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "correlation"))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "correlation", "extract_Sigma_table")
  expect_equal(meta$level, c("unit", "unit_obs"))
  expect_equal(meta$rotation_status, "rotation_invariant")
  expect_silent(print(p))
  ## n_traits^2 cells (diag + both triangles populated)
  expect_equal(nrow(p$data), fit$n_traits^2)
  expect_true(all(
    c(
      "trait_i",
      "trait_j",
      "row",
      "col",
      "estimate",
      "value",
      "level",
      "triangle",
      "interval_method",
      "interval_status",
      "scale"
    ) %in%
      names(p$data)
  ))
  expect_true(all(p$data$value >= -1 & p$data$value <= 1))
  expect_true(all(p$data$estimate >= -1 & p$data$estimate <= 1))
  expect_setequal(
    as.character(unique(p$data$triangle)),
    c("upper", "lower", "diagonal")
  )
  expect_setequal(
    as.character(unique(p$data$level)),
    c("unit", "unit_obs", "diagonal")
  )
  expect_identical(attr(p, "gllvmTMB_data"), p$data)
})

test_that("plot(type = 'correlation_ellipse') returns Figure-3-style ellipse data", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "correlation_ellipse"))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "correlation_ellipse", "extract_Sigma_table")
  expect_equal(meta$level, c("unit", "unit_obs"))
  plot_data <- attr(p, "gllvmTMB_data")
  expect_s3_class(plot_data, "data.frame")
  expect_true(all(
    c(
      "x",
      "y",
      "group",
      "trait_i",
      "trait_j",
      "estimate",
      "level",
      "triangle",
      "significant",
      "border_colour"
    ) %in%
      names(plot_data)
  ))
  expect_false(any(plot_data$triangle == "diagonal"))
  expect_true(all(plot_data$estimate >= -1 & plot_data$estimate <= 1))
  expect_silent(print(p))
})

test_that("correlation plots can use bootstrap_Sigma correlation intervals", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  traits <- levels(fit$data[[fit$trait_col]])
  R_B <- diag(length(traits))
  R_W <- diag(length(traits))
  dimnames(R_B) <- dimnames(R_W) <- list(traits, traits)
  R_B[1L, 2L] <- R_B[2L, 1L] <- 0.55
  R_B[1L, 3L] <- R_B[3L, 1L] <- 0.20
  R_B[2L, 4L] <- R_B[4L, 2L] <- -0.35
  R_W[2L, 1L] <- R_W[1L, 2L] <- -0.50
  R_W[3L, 1L] <- R_W[1L, 3L] <- 0.30
  R_W[4L, 2L] <- R_W[2L, 4L] <- 0.15

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

  p_heat <- suppressMessages(plot(fit, type = "correlation", boot = boot))
  meta_heat <- expect_gtmb_plot_meta(
    p_heat,
    "correlation",
    "extract_Sigma_table"
  )
  expect_equal(meta_heat$interval_status, "provided")
  expect_true(any(is.finite(p_heat$data$lower)))

  p_ell <- suppressMessages(plot(
    fit,
    type = "correlation_ellipse",
    boot = boot
  ))
  meta_ell <- expect_gtmb_plot_meta(
    p_ell,
    "correlation_ellipse",
    "extract_Sigma_table"
  )
  plot_data <- attr(p_ell, "gllvmTMB_data")
  expect_equal(meta_ell$interval_status, "provided")
  expect_true(any(plot_data$significant))
  expect_true(any(
    plot_data$border_colour == gllvmTMB:::.gtmb_plot_palette[["ink"]]
  ))
  expect_silent(print(p_ell))
})

test_that("plot(type = 'loadings') returns a faceted ggplot with both levels", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "loadings"))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "loadings", "getLoadings")
  expect_equal(meta$level, c("unit", "unit_obs"))
  expect_equal(meta$rotation_status, "rotation_ambiguous_loadings")
  expect_identical(attr(p, "gllvmTMB_data"), p$data)
  expect_silent(print(p))
  ## n_traits * (d_B + d_W) = 4 * (2 + 1) = 12 rows
  expect_equal(nrow(p$data), fit$n_traits * (fit$d_B + fit$d_W))
  expect_true(all(
    c("trait", "factor", "loading", "level", "pinned") %in%
      names(p$data)
  ))
  ## Single-level call works and shows just one level
  withr::local_options(gllvmTMB.warned_level_B = NULL)
  p_B <- NULL
  expect_warning(
    p_B <- suppressMessages(plot(fit, type = "loadings", level = "B")),
    "deprecated"
  )
  expect_s3_class(p_B, "ggplot")
  meta_B <- expect_gtmb_plot_meta(p_B, "loadings", "getLoadings")
  expect_equal(meta_B$level, "unit")
  expect_equal(nrow(p_B$data), fit$n_traits * fit$d_B)

  p_unit <- expect_warning(
    suppressMessages(plot(fit, type = "loadings", level = "unit")),
    NA
  )
  expect_s3_class(p_unit, "ggplot")
  meta_unit <- expect_gtmb_plot_meta(p_unit, "loadings", "getLoadings")
  expect_equal(meta_unit$level, "unit")
  expect_equal(nrow(p_unit$data), fit$n_traits * fit$d_B)
})

test_that("plot(type = 'integration') returns a ggplot with three indices per trait", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "integration"))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(
    p,
    "integration",
    "extract_ICC_site + extract_communality"
  )
  expect_equal(meta$level, c("unit", "unit_obs"))
  expect_equal(meta$interval_status, "none")
  expect_identical(attr(p, "gllvmTMB_data"), p$data)
  expect_silent(print(p))
  ## 3 indices x n_traits rows
  expect_equal(nrow(p$data), 3L * fit$n_traits)
  expect_setequal(
    as.character(unique(p$data$index)),
    c("Repeatability", "Communality (B)", "Communality (W)")
  )
  ## Without boot, lower/upper should be all NA
  expect_true(all(is.na(p$data$lower)))
})

test_that("plot(type = 'integration') accepts a bootstrap_Sigma object directly", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  traits <- levels(fit$data[[fit$trait_col]])
  rep <- stats::setNames(c(0.42, 0.51, 0.34, 0.61), traits)
  c2_B <- stats::setNames(c(0.62, 0.48, 0.35, 0.72), traits)
  c2_W <- stats::setNames(c(0.24, 0.30, 0.18, 0.41), traits)
  boot <- list(
    point_est = list(
      ICC_site = rep,
      communality_B = c2_B,
      communality_W = c2_W
    ),
    ci_lower = list(
      ICC_site = pmax(0, rep - 0.07),
      communality_B = pmax(0, c2_B - 0.08),
      communality_W = pmax(0, c2_W - 0.06)
    ),
    ci_upper = list(
      ICC_site = pmin(1, rep + 0.08),
      communality_B = pmin(1, c2_B + 0.09),
      communality_W = pmin(1, c2_W + 0.07)
    ),
    ci_method = "percentile",
    link_residual = "auto",
    conf = 0.95,
    n_boot = 25L,
    n_failed = 0L,
    level = c("B", "W"),
    what = c("ICC", "communality"),
    draws = NULL
  )
  class(boot) <- c("bootstrap_Sigma", "list")

  p <- suppressMessages(plot(fit, type = "integration", boot = boot))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(
    p,
    "integration",
    "extract_ICC_site + extract_communality"
  )
  expect_equal(meta$interval_status, "provided")
  expect_equal(nrow(p$data), 3L * fit$n_traits)
  expect_true(all(p$data$interval_status == "provided"))
  expect_true(all(is.finite(p$data$lower)))
  expect_true(all(is.finite(p$data$upper)))
  expect_silent(print(p))
})

test_that("plot(type = 'communality') returns stacked shared/unique bars", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "communality"))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "communality", "extract_communality")
  expect_equal(meta$level, c("unit", "unit_obs"))
  expect_equal(meta$interval_status, "none")
  expect_identical(attr(p, "gllvmTMB_data"), p$data)
  expect_true(all(
    c(
      "trait",
      "level",
      "component",
      "proportion",
      "communality",
      "lower",
      "upper",
      "has_interval",
      "interval_method",
      "interval_status"
    ) %in%
      names(p$data)
  ))
  expect_setequal(
    as.character(unique(p$data$component)),
    c("Shared latent (c^2)", "Trait-specific uniqueness")
  )
  totals <- stats::aggregate(
    proportion ~ trait + level,
    data = p$data,
    FUN = sum
  )
  expect_equal(totals$proportion, rep(1, nrow(totals)), tolerance = 1e-8)
  expect_silent(print(p))
})

test_that("plot(type = 'communality') can overlay bootstrap_Sigma intervals", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  traits <- levels(fit$data[[fit$trait_col]])
  c2_B <- stats::setNames(c(0.62, 0.48, 0.35, 0.72), traits)
  c2_W <- stats::setNames(c(0.24, 0.30, 0.18, 0.41), traits)
  boot <- list(
    point_est = list(communality_B = c2_B, communality_W = c2_W),
    ci_lower = list(
      communality_B = pmax(0, c2_B - 0.08),
      communality_W = pmax(0, c2_W - 0.06)
    ),
    ci_upper = list(
      communality_B = pmin(1, c2_B + 0.09),
      communality_W = pmin(1, c2_W + 0.07)
    ),
    ci_method = "percentile",
    link_residual = "auto",
    conf = 0.95,
    n_boot = 25L,
    n_failed = 0L,
    level = c("B", "W"),
    what = "communality",
    draws = NULL
  )
  class(boot) <- c("bootstrap_Sigma", "list")

  p <- suppressMessages(plot(fit, type = "communality", boot = boot))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "communality", "extract_communality")
  expect_equal(meta$interval_status, "provided")
  expect_true(any(p$data$has_interval))
  expect_true(all(p$data$interval_status == "provided"))
  expect_true(all(is.finite(p$data$lower)))
  expect_true(all(is.finite(p$data$upper)))
  expect_silent(print(p))
})

test_that("plot(type = 'variance') returns a stacked-bar ggplot summing to 1 per trait", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "variance"))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "variance", "extract_proportions")
  expect_equal(meta$level, c("unit", "unit_obs"))
  expect_identical(attr(p, "gllvmTMB_data"), p$data)
  expect_silent(print(p))
  expect_true(all(c("trait", "component", "proportion") %in% names(p$data)))
  ## Per-trait proportions sum to 1 (within numerical tolerance)
  totals <- as.numeric(tapply(p$data$proportion, p$data$trait, sum))
  expect_equal(totals, rep(1, fit$n_traits), tolerance = 1e-8)
})

test_that("plot(type = 'ordination') returns a ggplot for d = 2 (B level)", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p_default <- suppressMessages(plot(fit, type = "ordination"))
  expect_s3_class(p_default, "ggplot")
  meta_default <- expect_gtmb_plot_meta(
    p_default,
    "ordination",
    "rotate_loadings"
  )
  expect_equal(meta_default$level, "unit")
  expect_equal(meta_default$rotation_status, "varimax_ordered_sign_anchored")
  expect_match(
    p_default$labels$caption,
    "Use Sigma and correlation summaries",
    fixed = TRUE
  )

  p <- expect_warning(
    suppressMessages(plot(
      fit,
      type = "ordination",
      level = "unit",
      rotation = "none"
    )),
    NA
  )
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "ordination", "extract_ordination")
  expect_equal(meta$level, "unit")
  expect_equal(meta$rotation_status, "rotation_ambiguous_loadings")
  expect_match(
    p$labels$caption,
    "raw fitted orientation",
    fixed = TRUE
  )
  expect_match(
    p$labels$caption,
    "Use Sigma and correlation summaries",
    fixed = TRUE
  )
  plot_data <- attr(p, "gllvmTMB_data")
  expect_named(plot_data, c("scores", "loadings", "rotation"))
  expect_equal(plot_data$rotation$method, "none")
  expect_s3_class(plot_data$scores, "data.frame")
  expect_s3_class(plot_data$loadings, "data.frame")
  expect_true(all(
    c("label_x", "label_y", "label_hjust", "label_vjust") %in%
      names(plot_data$loadings)
  ))
  expect_true(all(is.finite(plot_data$loadings$label_x)))
  expect_true(all(is.finite(plot_data$loadings$label_y)))
  expect_true(all(plot_data$loadings$label_hjust >= 0))
  expect_true(all(plot_data$loadings$label_hjust <= 1))
  expect_silent(print(p))
  ## ggplot()-with-data-in-layers: top-level p$data is empty waiver().
  ## Verify the layers see scores + loadings instead.
  layer_data_n <- vapply(
    p$layers,
    function(l) {
      d <- l$data
      if (inherits(d, "waiver") || is.null(d)) NA_integer_ else nrow(d)
    },
    integer(1)
  )
  expect_true(any(!is.na(layer_data_n)))
})

test_that("plot(type = 'ordination') returns a static 3D pair grid for d = 3", {
  skip_if_no_ggplot2()
  fit <- make_fake_ordination_fit(d = 3L)
  p <- suppressMessages(plot(
    fit,
    type = "ordination",
    level = "unit",
    rotation = "none"
  ))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "ordination", "extract_ordination")
  expect_equal(meta$level, "unit")
  expect_equal(meta$rotation_status, "rotation_ambiguous_loadings")
  expect_match(meta$notes, "static pair grid")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_named(plot_data, c("scores", "loadings", "rotation"))
  expect_equal(plot_data$rotation$method, "none")
  expect_setequal(
    as.character(unique(plot_data$scores$pair)),
    c("LV1 vs LV2", "LV1 vs LV3", "LV2 vs LV3")
  )
  expect_equal(nrow(plot_data$scores), 3L * fit$n_sites)
  expect_equal(nrow(plot_data$loadings), 3L * length(levels(fit$data$trait)))
  expect_true(all(
    c("label_x", "label_y", "label_hjust", "label_vjust") %in%
      names(plot_data$loadings)
  ))
  expect_silent(print(p))
})

test_that("plot(type = 'ordination') can use two selected axes from d > 3", {
  skip_if_no_ggplot2()
  fit <- make_fake_ordination_fit(d = 4L)
  p <- suppressMessages(plot(
    fit,
    type = "ordination",
    level = "unit",
    axes = c(2, 4),
    rotation = "none"
  ))
  expect_s3_class(p, "ggplot")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_named(plot_data, c("scores", "loadings", "rotation"))
  expect_equal(plot_data$rotation$method, "none")
  expect_equal(nrow(plot_data$scores), fit$n_sites)
  expect_equal(nrow(plot_data$loadings), length(levels(fit$data$trait)))
  expect_true(all(
    c("loading_x", "loading_y", "display_scale") %in%
      names(plot_data$loadings)
  ))
  expect_silent(print(p))
})

test_that("canonical level names do not warn when wrappers call extractors", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()

  expect_warning(suppressMessages(getLoadings(fit, level = "unit")), NA)
  expect_warning(suppressMessages(getLV(fit, level = "unit")), NA)
  expect_warning(
    suppressMessages(rotate_loadings(fit, level = "unit", method = "varimax")),
    NA
  )
})

test_that("plot(type = 'ordination', level = 'W') gives 1D lollipop when d_W = 1", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  ## d_W = 1 in this fit
  expect_equal(fit$d_W, 1L)
  withr::local_options(gllvmTMB.warned_level_W = NULL)
  p <- NULL
  expect_warning(
    p <- suppressMessages(plot(
      fit,
      type = "ordination",
      level = "W",
      rotation = "none"
    )),
    "deprecated"
  )
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "ordination", "extract_ordination")
  expect_equal(meta$level, "unit_obs")
  expect_named(attr(p, "gllvmTMB_data"), c("scores", "loadings", "rotation"))
  expect_silent(print(p))
})

test_that("plot(type = 'ordination') can use rotated plot-ready axes", {
  skip_if_no_ggplot2()
  fit <- make_fake_ordination_fit(d = 3L)
  p <- suppressMessages(plot(
    fit,
    type = "ordination",
    level = "unit",
    rotation = "varimax"
  ))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "ordination", "rotate_loadings")
  expect_equal(meta$rotation_status, "varimax_ordered_sign_anchored")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_named(plot_data, c("scores", "loadings", "rotation"))
  expect_equal(plot_data$rotation$method, "varimax")
  expect_true(all(diff(plot_data$rotation$axis_variance) <= 1e-8))
  expect_equal(
    nrow(plot_data$loadings),
    3L * length(levels(fit$data$trait))
  )
  expect_silent(print(p))
})

test_that("plot(type = 'ordination') can standardize loading arrows", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(
    fit,
    type = "ordination",
    level = "unit",
    standardize_loadings = TRUE
  ))
  expect_s3_class(p, "ggplot")
  meta <- expect_gtmb_plot_meta(p, "ordination", "rotate_loadings")
  expect_equal(meta$rotation_status, "varimax_ordered_sign_anchored")
  plot_data <- attr(p, "gllvmTMB_data")
  expect_equal(plot_data$rotation$loading_scale, "standardized")
  expect_true(all(is.finite(plot_data$loadings$loading_x)))
  expect_true(all(is.finite(plot_data$loadings$loading_y)))
  expect_silent(print(p))
})

test_that("plot.gllvmTMB_multi errors on bad type and bad axes", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  expect_error(plot(fit, type = "nonsense"), regexp = "should be one of")
  ## d_B = 2 here, ask for axis 5 -> error
  expect_error(
    suppressMessages(plot(
      fit,
      type = "ordination",
      level = "unit",
      axes = c(1, 5)
    )),
    regexp = "exceed"
  )
})
