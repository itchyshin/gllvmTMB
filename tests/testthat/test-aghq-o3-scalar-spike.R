test_that("O3 scalar AGHQ ladder is stable and matches external quadrature", {
  testthat::skip_on_cran()
  source(testthat::test_path("..", "..", "dev", "aghq-o3-scalar-spike.R"))

  result <- o3_scalar_self_test()
  expect_true(all(result$ladder$convergence == 0L))
  expect_lt(
    abs(result$ladder$sd[result$ladder$nodes == 15L] -
          result$ladder$sd[result$ladder$nodes == 25L]),
    1e-4
  )
  expect_identical(result$cox_reid$estimator, "aghq_cox_reid")
  expect_true(is.finite(result$cox_reid$objective))
})
