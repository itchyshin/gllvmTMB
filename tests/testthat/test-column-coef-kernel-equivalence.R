test_that("kernel rho one rewrites exactly to released kernel_slope", {
  fx <- .make_kernel_coef_fixture()
  f <- value ~ 0 + trait +
    kernel_coef(0 + x + z || trait, K = fx$K, name = "env", rho = 1)
  spec <- gllvmTMB:::.parse_column_coef_formula(
    f, "trait", names(fx$long), response_vars = "value"
  )
  f[[3L]] <- gllvmTMB:::.column_coef_rewrite_kernel(f[[3L]], spec)
  expect_identical(
    f[[3L]],
    (value ~ 0 + trait +
       kernel_slope(x + z || trait, K = fx$K, name = "env"))[[3L]]
  )
})

test_that("kernel rho one is exactly raw-K kernel_slope for both bars", {
  fx <- .make_kernel_coef_fixture(seed = 13242L)
  pairs <- list(
    list(coef = value ~ 0 + trait +
           kernel_coef(0 + x + z | trait, K = fx$K, name = "env", rho = 1),
         slope = value ~ 0 + trait +
           kernel_slope(x + z | trait, K = fx$K, name = "env")),
    list(coef = value ~ 0 + trait +
           kernel_coef(0 + x + z || trait, K = fx$K, name = "env", rho = 1),
         slope = value ~ 0 + trait +
           kernel_slope(x + z || trait, K = fx$K, name = "env"))
  )
  for (pair in pairs) {
    expect_no_warning(coef_fit <- .fit_kernel_coef(fx, pair$coef))
    expect_no_warning(slope_fit <- .fit_kernel_coef(fx, pair$slope))
    .expect_kernel_route_identical(coef_fit, slope_fit)
    got <- gllvmTMB::extract_Sigma(coef_fit, level = "column_coef")
    expect_equal(got$K_rho, fx$K, tolerance = 1e-12)
    expect_identical(got$source$name, "env")
    expect_identical(got$source$scale, "as_supplied")
  }
})

test_that("identity kernel coefficient endpoint is ordinary IID", {
  fx <- .make_kernel_coef_fixture(seed = 13243L, n_traits = 4L)
  I <- diag(4); dimnames(I) <- list(fx$traits, fx$traits)
  kfit <- .fit_kernel_coef(fx, value ~ 0 + trait +
    kernel_coef(0 + x | trait, K = I, rho = 1))
  ifit <- .fit_kernel_coef(fx, value ~ 0 + trait +
    column_coef(0 + x | trait))
  expect_identical(kfit$opt$objective, ifit$opt$objective)
  expect_identical(kfit$opt$par, ifit$opt$par)
})
