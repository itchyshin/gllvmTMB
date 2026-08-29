test_that("kernel_coef has the locked public signature and parser intent", {
  expect_true("kernel_coef" %in% getNamespaceExports("gllvmTMB"))
  helper <- getExportedValue("gllvmTMB", "kernel_coef")
  expect_identical(names(formals(helper)), c("formula", "K", "name", "rho"))
  expect_identical(formals(helper)$name, "kernel")
  expect_null(formals(helper)$rho)

  fx <- .make_kernel_coef_fixture()
  parse <- function(f) gllvmTMB:::.parse_column_coef_formula(
    f, "trait", names(fx$long), response_vars = "value"
  )
  fixed <- parse(value ~ kernel_coef(1 + x | trait, K = fx$K,
                                     name = "environment", rho = 0.4))
  estimated <- parse(value ~ kernel_coef(0 + x || trait, K = fx$K))
  expect_identical(fixed$source, "kernel")
  expect_identical(fixed$basis, c("(Intercept)", "x"))
  expect_identical(fixed$rho_mode, "fixed")
  expect_identical(fixed$rho, 0.4)
  expect_identical(estimated$rho_mode, "estimated")
  expect_false(estimated$correlated)
})

test_that("kernel_coef enforces formal arguments and dense labelled K", {
  fx <- .make_kernel_coef_fixture(n_traits = 3L)
  parse <- function(f) gllvmTMB:::.parse_column_coef_formula(
    f, "trait", names(fx$long), response_vars = "value"
  )
  expect_error(parse(value ~ kernel_coef(0 + x | trait)),
               class = "gllvmTMB_column_coef_source_invalid")
  expect_error(parse(value ~ kernel_coef(0 + x | trait, K = fx$K,
                                         unknown = 1)), "Invalid argument list")
  expect_error(parse(value ~ kernel_coef(0 + x | trait, K = fx$K,
                                         name = "")),
               class = "gllvmTMB_column_coef_source_invalid")
  expect_error(parse(value ~ kernel_coef(0 + x | trait, K = fx$K, rho = 2)),
               class = "gllvmTMB_column_coef_invalid_syntax")

  bad <- unname(fx$K)
  expect_error(.fit_kernel_coef(
    fx, value ~ 1 + kernel_coef(0 + x | trait, K = bad, rho = 1)
  ), class = "gllvmTMB_column_slope_kernel_invalid")
  skip_if_not_installed("Matrix")
  sparse <- Matrix::Matrix(fx$K, sparse = TRUE)
  expect_error(.fit_kernel_coef(
    fx, value ~ 1 + kernel_coef(0 + x | trait, K = sparse, rho = 1)
  ), class = "gllvmTMB_column_slope_kernel_invalid")
})

test_that("kernel_coef remains Gaussian-only", {
  fx <- .make_kernel_coef_fixture(n_traits = 3L)
  fx$long$value <- stats::rpois(nrow(fx$long), 2)
  expect_error(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 1 + kernel_coef(0 + x | trait, K = fx$K, rho = 1),
    data = fx$long, trait = "trait", unit = "unit", family = stats::poisson(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  )), class = "gllvmTMB_column_coef_family_unsupported")
})
