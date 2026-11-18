test_that("spatial coefficient meshes are label-aligned independently of row order", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture(seed = 13320L, n_unit = 18L)
  perm <- c(6L, 2L, 4L, 1L, 5L, 3L)
  permuted_mesh <- make_mesh(
    fx$locations[perm, ], c("east_km", "north_km"),
    mesh = fx$mesh$mesh, id_col = "trait"
  )
  column_mesh <- fx$mesh
  aligned <- .fit_spatial_coef(
    fx, value ~ 1 + spatial_coef(1 + moisture | trait, mesh = column_mesh)
  )
  column_mesh <- permuted_mesh
  permuted <- .fit_spatial_coef(
    fx, value ~ 1 + spatial_coef(1 + moisture | trait, mesh = column_mesh)
  )
  expect_equal(aligned$opt$objective, permuted$opt$objective, tolerance = 1e-9)
  expect_equal(aligned$opt$par, permuted$opt$par, tolerance = 1e-8)
  expect_equal(gllvmTMB::extract_Sigma(aligned, level = "column_coef"),
               gllvmTMB::extract_Sigma(permuted, level = "column_coef"),
               tolerance = 1e-8)
})

test_that("spatial coefficients inherit strict labelled-mesh validation", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture(seed = 13321L, n_unit = 8L)
  column_mesh <- make_mesh(
    fx$locations, c("east_km", "north_km"), mesh = fx$mesh$mesh
  )
  expect_error(
    .fit_spatial_coef(
      fx, value ~ 1 + spatial_coef(1 + moisture | trait, mesh = column_mesh)
    ),
    "labelled response-column mesh"
  )

  wrong <- fx$locations
  wrong$trait[[1L]] <- "extra"
  column_mesh <- make_mesh(
    wrong, c("east_km", "north_km"), mesh = fx$mesh$mesh,
    id_col = "trait"
  )
  expect_error(
    .fit_spatial_coef(
      fx, value ~ 1 + spatial_coef(1 + moisture | trait, mesh = column_mesh)
    ),
    "match the response-column levels exactly"
  )

  duplicate <- fx$locations
  duplicate[2L, c("east_km", "north_km")] <-
    duplicate[1L, c("east_km", "north_km")]
  column_mesh <- make_mesh(
    duplicate, c("east_km", "north_km"), mesh = fx$mesh$mesh,
    id_col = "trait"
  )
  expect_error(
    .fit_spatial_coef(
      fx, value ~ 1 + spatial_coef(1 + moisture | trait, mesh = column_mesh)
    ),
    "unique coordinate pair"
  )
})

test_that("spatial coefficients reject duplicate fixed space and accept missing responses", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture(seed = 13322L, n_unit = 12L)
  column_mesh <- fx$mesh
  expect_error(
    .fit_spatial_coef(
      fx, value ~ 0 + trait + spatial_coef(1 | trait, mesh = column_mesh)
    ),
    class = "gllvmTMB_column_coef_fixed_overlap"
  )

  fx$data$value[fx$data$trait == levels(fx$data$trait)[[2L]] &
                  fx$data$unit == levels(fx$data$unit)[[3L]]] <- NA_real_
  fit <- .fit_spatial_coef(
    fx, value ~ 1 + spatial_coef(1 + moisture | trait, mesh = column_mesh)
  )
  expect_identical(fit$opt$convergence, 0L)
  expect_true(all(is.finite(fit$opt$par)))
})

test_that("spatial coefficients cannot share a fit with observation-space spatial covariance", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture(seed = 13323L, n_unit = 8L)
  column_mesh <- fx$mesh
  expect_error(
    .fit_spatial_coef(
      fx,
      value ~ 1 + spatial_coef(1 + moisture | trait, mesh = column_mesh) +
        spatial_indep(0 + trait | unit, mesh = column_mesh)
    ),
    class = "gllvmTMB_spatial_column_slope_multiple_axes"
  )
})

test_that("spatial coefficients admit a rare fixed pathway level", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture(seed = 13324L, n_unit = 18L)
  column_data <- data.frame(
    trait = fx$locations$trait,
    pathway = factor(
      c("C3", "C3", "C3", "C4", "C4", "CAM"),
      levels = c("C3", "C4", "CAM")
    )
  )
  column_mesh <- fx$mesh
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + pathway + spatial_coef(
      0 + moisture | trait, mesh = column_mesh, rho = 1
    ),
    data = fx$data, column_data = column_data,
    trait = "trait", unit = "unit", family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  expect_identical(fit$opt$convergence, 0L)
  expect_true("pathwayCAM" %in% names(stats::coef(fit)))
  expect_identical(
    gllvmTMB::extract_Sigma(fit, level = "column_coef")$basis,
    "moisture"
  )
})
