test_that("O3 q = 2 coupled AGHQ is stable on the fixed gllvmTMB reference", {
  skip_on_cran()
  source(test_path("helper-aghq-o3.R"))

  result <- o3_q2_gllvm_unit_self_test()
  expect_lt(abs(result$laplace_difference), 1e-6)
  expect_lt(
    abs(result$ladder$objective[result$ladder$nodes == 7L] -
          result$ladder$objective[result$ladder$nodes == 9L]),
    1e-4
  )
  expect_lt(max(result$ladder$max_condition), 1e8)
})
