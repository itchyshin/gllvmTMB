## Tests for plot.gllvmTMB_multi() — the ggplot2-based S3 dispatcher.
## Each test fits a small model with both rr() and diag() at both tiers
## (the recommended decomposition), calls plot(fit, type = "..."), and
## verifies the return is a ggplot whose data slot has the expected
## structure. We do NOT compare pixels; rendering is not tested.

skip_if_no_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

make_BW_fit_for_plot <- function(seed = 1) {
  set.seed(seed)
  Tn <- 4
  Lambda_B <- matrix(c(1.0, 0.5, -0.4, 0.3,
                       0.0, 0.8,  0.4, -0.2), Tn, 2)
  Lambda_W <- matrix(c(0.4, 0.2, -0.1, 0.3), Tn, 1)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 6, n_traits = Tn,
    mean_species_per_site = 4,
    Lambda_B = Lambda_B, S_B = c(0.20, 0.15, 0.10, 0.25),
    Lambda_W = Lambda_W, S_W = c(0.10, 0.08, 0.05, 0.12),
    beta = matrix(0, Tn, 2), seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site,         d = 2) + unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = s$data
  )))
}

test_that("plot(type = 'correlation') returns a ggplot with combined upper/lower triangle data", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "correlation"))
  expect_s3_class(p, "ggplot")
  expect_silent(print(p))
  ## n_traits^2 cells (diag + both triangles populated)
  expect_equal(nrow(p$data), fit$n_traits^2)
  expect_true(all(c("row", "col", "value") %in% names(p$data)))
  expect_true(all(p$data$value >= -1 & p$data$value <= 1))
})

test_that("plot(type = 'loadings') returns a faceted ggplot with both levels", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "loadings"))
  expect_s3_class(p, "ggplot")
  expect_silent(print(p))
  ## n_traits * (d_B + d_W) = 4 * (2 + 1) = 12 rows
  expect_equal(nrow(p$data), fit$n_traits * (fit$d_B + fit$d_W))
  expect_true(all(c("trait", "factor", "loading", "level", "pinned") %in%
                    names(p$data)))
  ## Single-level call works and shows just one level
  withr::local_options(gllvmTMB.warned_level_B = NULL)
  p_B <- NULL
  expect_warning(
    p_B <- suppressMessages(plot(fit, type = "loadings", level = "B")),
    "deprecated"
  )
  expect_s3_class(p_B, "ggplot")
  expect_equal(nrow(p_B$data), fit$n_traits * fit$d_B)

  p_unit <- expect_warning(
    suppressMessages(plot(fit, type = "loadings", level = "unit")),
    NA
  )
  expect_s3_class(p_unit, "ggplot")
  expect_equal(nrow(p_unit$data), fit$n_traits * fit$d_B)
})

test_that("plot(type = 'integration') returns a ggplot with three indices per trait", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "integration"))
  expect_s3_class(p, "ggplot")
  expect_silent(print(p))
  ## 3 indices x n_traits rows
  expect_equal(nrow(p$data), 3L * fit$n_traits)
  expect_setequal(as.character(unique(p$data$index)),
                  c("Repeatability", "Communality (B)", "Communality (W)"))
  ## Without boot, lower/upper should be all NA
  expect_true(all(is.na(p$data$lower)))
})

test_that("plot(type = 'variance') returns a stacked-bar ggplot summing to 1 per trait", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- suppressMessages(plot(fit, type = "variance"))
  expect_s3_class(p, "ggplot")
  expect_silent(print(p))
  expect_true(all(c("trait", "component", "proportion") %in% names(p$data)))
  ## Per-trait proportions sum to 1 (within numerical tolerance)
  totals <- as.numeric(tapply(p$data$proportion, p$data$trait, sum))
  expect_equal(totals, rep(1, fit$n_traits), tolerance = 1e-8)
})

test_that("plot(type = 'ordination') returns a ggplot for d = 2 (B level)", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  p <- expect_warning(
    suppressMessages(plot(fit, type = "ordination", level = "unit")),
    NA
  )
  expect_s3_class(p, "ggplot")
  expect_silent(print(p))
  ## ggplot()-with-data-in-layers: top-level p$data is empty waiver().
  ## Verify the layers see scores + loadings instead.
  layer_data_n <- vapply(p$layers, function(l) {
    d <- l$data
    if (inherits(d, "waiver") || is.null(d)) NA_integer_ else nrow(d)
  }, integer(1))
  expect_true(any(!is.na(layer_data_n)))
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
    p <- suppressMessages(plot(fit, type = "ordination", level = "W")),
    "deprecated"
  )
  expect_s3_class(p, "ggplot")
  expect_silent(print(p))
})

test_that("plot.gllvmTMB_multi errors on bad type and bad axes", {
  skip_if_no_ggplot2()
  fit <- make_BW_fit_for_plot()
  expect_error(plot(fit, type = "nonsense"), regexp = "should be one of")
  ## d_B = 2 here, ask for axis 5 -> error
  expect_error(
    suppressMessages(plot(fit, type = "ordination", level = "unit",
                          axes = c(1, 5))),
    regexp = "exceed"
  )
})
