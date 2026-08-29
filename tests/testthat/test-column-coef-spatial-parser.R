test_that("spatial_coef has the locked rho-one public grammar", {
  skip_if_not_installed("fmesher")
  expect_true("spatial_coef" %in% getNamespaceExports("gllvmTMB"))
  helper <- getExportedValue("gllvmTMB", "spatial_coef")
  expect_identical(names(formals(helper)), c("formula", "mesh", "rho"))
  expect_identical(formals(helper)$rho, 1)

  fx <- .make_spatial_coef_fixture()
  column_mesh <- fx$mesh
  parse <- function(f) gllvmTMB:::.parse_column_coef_formula(
    f, "trait", names(fx$data), response_vars = "value"
  )
  spec <- parse(value ~ spatial_coef(1 + moisture | trait,
                                     mesh = column_mesh))
  expect_identical(spec$source, "spatial")
  expect_identical(spec$basis, c("(Intercept)", "moisture"))
  expect_identical(spec$rho_mode, "fixed")
  expect_identical(spec$rho, 1)
  expect_true(spec$correlated)

  explicit <- parse(value ~ spatial_coef(
    1 + moisture | trait, mesh = column_mesh, rho = 1
  ))
  expect_identical(explicit$source, spec$source)
  expect_identical(explicit$basis, spec$basis)
  expect_identical(explicit$rho_mode, spec$rho_mode)
  expect_identical(explicit$rho, spec$rho)
  expect_identical(explicit$correlated, spec$correlated)
})

test_that("spatial_coef requires one mesh and rejects unearned rho routes", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture()
  column_mesh <- fx$mesh
  parse <- function(f) gllvmTMB:::.parse_column_coef_formula(
    f, "trait", names(fx$data), response_vars = "value"
  )
  expect_error(
    parse(value ~ spatial_coef(0 + moisture | trait)),
    class = "gllvmTMB_column_coef_source_invalid"
  )
  expect_error(
    parse(value ~ spatial_coef(0 + moisture | trait,
                               mesh = column_mesh, unknown = 1)),
    "Invalid argument list"
  )
  for (rho in list(NULL, 0, 0.5, 0.999)) {
    expect_error(
      parse(value ~ spatial_coef(0 + moisture | trait,
                                 mesh = column_mesh, rho = rho)),
      class = "gllvmTMB_column_coef_rho_not_admitted"
    )
  }
  expect_error(
    parse(value ~ spatial_coef(0 + moisture | trait,
                               mesh = column_mesh, rho = 2)),
    class = "gllvmTMB_column_coef_invalid_syntax"
  )
})

test_that("spatial_coef remains Gaussian-only", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture(n_unit = 6L)
  fx$data$value <- stats::rpois(nrow(fx$data), 2)
  column_mesh <- fx$mesh
  expect_error(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 1 + spatial_coef(0 + moisture | trait, mesh = column_mesh),
    data = fx$data, trait = "trait", unit = "unit", family = stats::poisson(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  )), class = "gllvmTMB_column_coef_family_unsupported")
})

test_that("screen_gllvmTMB admits the public spatial coefficient grammar", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_fixture(n_unit = 8L)
  column_mesh <- fx$mesh
  expect_no_error(screen <- suppressMessages(gllvmTMB::screen_gllvmTMB(
    value ~ 1 + spatial_coef(1 + moisture | trait, mesh = column_mesh),
    data = fx$data, trait = "trait", unit = "unit",
    family = stats::gaussian()
  )))
  expect_s3_class(screen, "gllvmTMB_screen")
})
