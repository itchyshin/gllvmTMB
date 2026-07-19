test_that("O3 scalar gllvmTMB hook agrees with its joint Laplace objective", {
  skip_on_cran()
  source(test_path("helper-aghq-o3.R"))

  result <- o3_gllvm_unit_hook_self_test()
  expect_lt(abs(result$laplace_difference), 1e-6)
  expect_lt(
    abs(result$ladder$objective[result$ladder$nodes == 15L] -
          result$ladder$objective[result$ladder$nodes == 25L]),
    1e-4
  )
})
