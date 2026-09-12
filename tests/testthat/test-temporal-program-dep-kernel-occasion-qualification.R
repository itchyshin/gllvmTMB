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
  exact <- data.frame(beta_1 = c(.2, .2), beta_2 = c(-.3, -.3),
    beta_3 = c(.1, .1))
  expect_equal(.temporal_dep_kernel_occasion_fixed_effect_error(exact,
    c(.2, -.3, .1)), c(0, 0))
  output <- tempfile("temporal-dep-kernel-occasion-")
  lock <- .temporal_dep_kernel_occasion_reserve_output(output)
  on.exit(unlink(lock, recursive = TRUE, force = TRUE), add = TRUE)
  expect_error(.temporal_dep_kernel_occasion_reserve_output(output), "reserved")
  unlink(lock, recursive = TRUE, force = TRUE)
  file.create(output)
  expect_error(.temporal_dep_kernel_occasion_reserve_output(output), "new result")
  cleanup_output <- tempfile("temporal-dep-kernel-occasion-cleanup-")
  expect_error(.temporal_dep_kernel_occasion_with_reservation(cleanup_output,
    stop("deliberate pre-fit failure")), "deliberate pre-fit failure")
  expect_false(dir.exists(paste0(cleanup_output, ".lock")))
  source_text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_false(grepl("simulate\\.gllvmTMB", source_text))
  expect_match(source_text, "output must name a new result file")
  expect_match(source_text, "error_message = conditionMessage")
  expect_match(source_text, "CELL_ERROR_RETAINED")
  expect_false(grepl("CELL_PASS", source_text, fixed = TRUE))
  parser <- getFromNamespace("parse_multi_formula", "gllvmTMB")
  expect_silent(parser(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "fixed_nonproportional_K")))
})
