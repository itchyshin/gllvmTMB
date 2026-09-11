test_that("independent dependent-kernel curvature diagnostic uses the additive DGP", {
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-dep-kernel-curvature.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  source(script, local = TRUE)

  fixture <- .temporal_dep_kernel_curvature_fixture(seed = 2609221L, n_series = 4L, n_time = 4L)
  duplicate <- .temporal_dep_kernel_curvature_fixture(seed = 2609221L, n_series = 4L, n_time = 4L)
  expect_identical(fixture$data, duplicate$data)
  expect_identical(fixture$K, duplicate$K)
  theta <- .temporal_dep_kernel_curvature_coordinates(fixture)
  report <- .temporal_dep_kernel_curvature_summary(theta, fixture)

  expect_identical(names(theta), c(paste0("log_kernel_variance_", 1:3),
    "theta_temporal_time", paste0("theta_temporal_rr_", 1:6)))
  expect_equal(dim(report$observed_information), c(length(theta), length(theta)))
  expect_equal(report$observed_information, t(report$observed_information), tolerance = 1e-10)
  expect_true(all(is.finite(report$gradient)))
  expect_true(all(is.finite(report$covariance_eigenvalues)))
  expect_true(is.finite(report$covariance_condition) && report$covariance_condition > 1)
  expect_true(is.finite(report$information_condition) && report$information_condition > 1)
  expect_true(is.finite(report$expected_information_condition) && report$expected_information_condition > 1)
  expect_true(all(is.finite(report$standardized_parameter_correlation)))
  expect_gt(report$wrong_product_nll_difference, 1e-3)
  expect_false(grepl("simulate\\s*\\(", paste(readLines(script, warn = FALSE), collapse = "\n")))
})

test_that("curvature report retains each small direct-DGP seed without an intervention claim", {
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-dep-kernel-curvature.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  source(script, local = TRUE)
  report <- temporal_dep_kernel_curvature_diagnostic(seeds = 2609221:2609223,
    n_series = 4L, n_time = 4L)
  expect_identical(report$seed, 2609221:2609223)
  expect_true(all(report$phi == .6))
  expect_true(all(report$n_observation == 4L * 4L * 2L * 3L))
  expect_true(all(is.finite(report$nll)))
  expect_true(all(report$wrong_product_nll_difference > 1e-3))
  expect_true(all(is.finite(report$max_abs_gradient)))
})
