.temporal_dep_kernel_occasion_dev_path <- function(...) {
  testthat::test_path("..", "..", "dev", "temporal-program", ...)
}

test_that("the long-occasion dep-kernel qualification is frozen before fitting", {
  script <- .temporal_dep_kernel_occasion_dev_path("run-dep-kernel-occasion-qualification.R")
  skip_if_not(file.exists(script), "developer-only qualification runner is unavailable")
  source(script, local = environment())
  plan <- .temporal_dep_kernel_occasion_plan()
  expect_equal(nrow(plan), 9L)
  expect_setequal(plan$phi, c(-.4, 0, .6))
  expect_setequal(plan$seed, 2609371:2609373)
  expect_true(all(plan$n_series == 80L))
  expect_true(all(plan$n_time == 32L))
  expect_equal(.temporal_dep_kernel_occasion_prerun(),
    list(phi = .6, seed = 2609370L, n_series = 80L, n_time = 32L))
  expect_error(.temporal_dep_kernel_occasion_validate(.6, 2609221L), "disjoint")
  expect_error(.temporal_dep_kernel_occasion_validate(.5, 2609371L), "frozen persistence")
  source_text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_false(grepl("simulate\\.gllvmTMB", source_text))
  expect_match(source_text, "output must name a new result file")
  expect_match(source_text, "error_message = conditionMessage")
  parser <- getFromNamespace("parse_multi_formula", "gllvmTMB")
  expect_silent(parser(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "fixed_nonproportional_K")))
})
