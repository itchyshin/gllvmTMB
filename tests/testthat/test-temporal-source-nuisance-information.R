test_that("temporal source nuisance-information oracle is derivative-aligned", {
  script <- testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-temporal-source-nuisance-information.R")
  expect_true(file.exists(script))
  source(script, local = environment())
  report <- .tsni_oracle()
  expect_lt(report$max_score_error, 2e-5)
  expect_lt(report$max_hessian_error, 2e-3)
  expect_equal(names(.tsni_truth_parameter()), .tsni_names())
})

test_that("temporal source mean contrast and nuisance Schur guards fail honestly", {
  script <- testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-temporal-source-nuisance-information.R")
  source(script, local = environment())
  decomposition <- .tsni_decomposition(16L)
  expect_lt(decomposition$max_reconstruction_error, 1e-12)
  expect_lt(decomposition$max_contrast_source, 1e-12)
  expect_gt(decomposition$temporal_mean_contrast_max, 1e-6)
  information <- .tsni_block_information(4L, n_series = 4L)
  expect_true(all(is.finite(.tsni_schur(information))))
  broken <- information
  broken[1L, 1L] <- -1
  expect_error(.tsni_schur(broken), "nuisance block is not positive definite")
})
