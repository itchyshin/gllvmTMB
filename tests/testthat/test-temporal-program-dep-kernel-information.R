test_that("dep-kernel information diagnostic is frozen and sourceable", {
  script <- testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-dep-kernel-information.R")
  expect_true(file.exists(script))
  source(script, local = environment())
  expect_equal(.temporal_dep_kernel_information_seeds(), 2609221:2609223)
  expect_equal(.temporal_dep_kernel_information_sizes(), c(80L, 160L))
  expect_error(.temporal_dep_kernel_information_validate(81L, 2609221L), "frozen diagnostic size")
  expect_error(.temporal_dep_kernel_information_validate(80L, 1L), "retained diagnostic seed")
  expect_match(paste(readLines(script, warn = FALSE), collapse = "\n"),
    "output must name a new result file")
})
