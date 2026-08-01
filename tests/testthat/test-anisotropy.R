fake_spatial_fit <- function(
  kappa = 2,
  family = gaussian(),
  use = list(spde = TRUE)
) {
  structure(
    list(
      report = list(kappa = kappa),
      family = family,
      use = use,
      mesh = list(xy_cols = c("east_km", "north_km"))
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
}

test_that("isotropic range data matches the fitted kappa contract", {
  result <- plot_anisotropy(fake_spatial_fit(kappa = 4), return_data = TRUE)

  expect_s3_class(result, "data.frame")
  expect_named(
    result,
    c(
      "x",
      "y",
      "theta",
      "range",
      "kappa",
      "axis_x",
      "axis_y",
      "anisotropy_estimated",
      "model_assumption"
    )
  )
  expect_equal(nrow(result), 361L)
  expect_equal(unique(result$range), sqrt(8) / 4)
  expect_equal(max(sqrt(result$x^2 + result$y^2)), sqrt(8) / 4)
  expect_true(all(!result$anisotropy_estimated))
  expect_equal(unique(result$model_assumption), "isotropic (H = I)")
  expect_equal(unique(result$axis_x), "east_km")
  expect_equal(unique(result$axis_y), "north_km")
})

test_that("latent-slope range falls back to the retained fitted TMB parameter", {
  fit <- fake_spatial_fit(
    kappa = NULL,
    use = list(spde = FALSE, spde_latent_slope = TRUE)
  )
  fit$opt <- list(par = c(log_kappa_spde = log(5)))
  fit$tmb_obj <- list(
    env = list(
      parList = function(par) list(log_kappa_spde = unname(par[[1L]]))
    )
  )

  result <- plot_anisotropy(fit, return_data = TRUE)
  expect_equal(unique(result$kappa), 5)
  expect_equal(unique(result$range), sqrt(8) / 5)
})

test_that("isotropic range plotting supports ggplot and base graphics", {
  skip_if_not_installed("ggplot2")
  fit <- fake_spatial_fit()

  expect_s3_class(plot_anisotropy(fit), "ggplot")

  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  base_result <- plot_anisotropy2(fit)
  expect_equal(base_result$range, sqrt(8) / 2)
  expect_equal(base_result$H, diag(2))
  expect_false(base_result$anisotropy_estimated)
})

test_that("isotropic range plotting rejects unsupported fit states", {
  expect_error(
    plot_anisotropy(structure(list(), class = "gllvmTMB")),
    "gllvmTMB_multi"
  )
  expect_error(
    plot_anisotropy(fake_spatial_fit(use = list(spde = FALSE))),
    "does not contain"
  )
  expect_error(
    plot_anisotropy(fake_spatial_fit(
      family = structure(list(delta = TRUE), class = "family")
    )),
    "delta spatial"
  )
  spatiotemporal <- fake_spatial_fit()
  spatiotemporal$use$spatiotemporal <- TRUE
  expect_error(plot_anisotropy(spatiotemporal), "spatiotemporal")
  expect_error(
    plot_anisotropy(fake_spatial_fit(kappa = NA_real_)),
    "positive spatial kappa"
  )
  expect_error(
    plot_anisotropy(fake_spatial_fit(), return_data = NA),
    "return_data"
  )
  expect_error(plot_anisotropy2(fake_spatial_fit(), model = 2), "must be 1")
})
