test_that("spatial rho one rewrites literally to released spatial_slope", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture()
  column_mesh <- fx$mesh
  f <- value ~ 0 + trait +
    spatial_coef(0 + moisture + z || trait, mesh = column_mesh)
  spec <- gllvmTMB:::.parse_column_coef_formula(
    f, "trait", names(fx$data), response_vars = "value"
  )
  f[[3L]] <- gllvmTMB:::.column_coef_rewrite_spatial(f[[3L]], spec)
  expect_identical(
    f[[3L]],
    (value ~ 0 + trait +
       spatial_slope(moisture + z || trait, mesh = column_mesh))[[3L]]
  )
})

test_that("spatial rho one is the exact warning-free spatial_slope endpoint", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture(seed = 13302L)
  column_mesh <- fx$mesh
  pairs <- list(
    list(
      coef = value ~ 0 + trait + spatial_coef(
        0 + moisture + z | trait, mesh = column_mesh
      ),
      slope = value ~ 0 + trait + spatial_slope(
        moisture + z | trait, mesh = column_mesh
      )
    ),
    list(
      coef = value ~ 0 + trait + spatial_coef(
        0 + moisture + z || trait, mesh = column_mesh
      ),
      slope = value ~ 0 + trait + spatial_slope(
        moisture + z || trait, mesh = column_mesh
      )
    )
  )
  for (pair in pairs) {
    expect_no_warning(coef_fit <- .fit_spatial_coef(fx, pair$coef))
    expect_no_warning(slope_fit <- .fit_spatial_coef(fx, pair$slope))
    .expect_spatial_endpoint_identical(coef_fit, slope_fit)
    got <- gllvmTMB::extract_Sigma(coef_fit, level = "column_coef")
    expect_identical(got$source$type, "spatial")
    expect_identical(got$rho_status, "fixed")
    expect_identical(got$rho, 1)
    expect_equal(unname(got$K_rho),
                 unname(coef_fit$report$spatial_column_K), tolerance = 1e-12)
    expect_identical(dimnames(got$K_rho),
                     list(levels(fx$data$trait), levels(fx$data$trait)))
    expected_coordinates <- as.matrix(fx$locations[, c("east_km", "north_km")])
    rownames(expected_coordinates) <- fx$locations$trait
    expect_equal(got$source$coordinates, expected_coordinates)
    expect_identical(got$source$coordinate_columns,
                     c("east_km", "north_km"))
    expect_identical(got$source$normalization,
                     "exact_projected_unit_diagonal")
    expect_equal(got$source$K_column,
                 coef_fit$report$spatial_column_K, tolerance = 1e-12)
    expect_equal(got$source$practical_range,
                 sqrt(8) / got$source$kappa, tolerance = 1e-12)
  }
})
