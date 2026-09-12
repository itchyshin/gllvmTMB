.temporal_dep_kernel_160_dev_path <- function(...) {
  testthat::test_path("..", "..", "dev", "temporal-program", ...)
}

.skip_if_temporal_dep_kernel_160_dev_files_unavailable <- function(...) {
  path <- .temporal_dep_kernel_160_dev_path(...)
  skip_if_not(
    file.exists(path),
    "developer-only temporal qualification evidence is unavailable in an installed-package test layout"
  )
  path
}

test_that("the disjoint 160-series dep-kernel qualification plan is fixed", {
  script <- .skip_if_temporal_dep_kernel_160_dev_files_unavailable(
    "run-dep-kernel-160-qualification.R"
  )
  source(script, local = environment())
  plan <- .temporal_dep_kernel_160_plan()
  expect_equal(nrow(plan), 9L)
  expect_setequal(plan$phi, c(-.4, 0, .6))
  expect_setequal(plan$seed, 2609341:2609343)
  expect_true(all(plan$n_series == 160L))
  expect_error(.temporal_dep_kernel_160_validate(.6, 2609221L), "disjoint")
  expect_error(.temporal_dep_kernel_160_validate(.5, 2609341L), "frozen persistence")
  expect_equal(.temporal_dep_kernel_160_prerun(), list(phi = .6, seed = 2609340L, n_series = 160L))
  source_text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_false(grepl("simulate\\.gllvmTMB", source_text))
  expect_false(grepl("gllvmTMB::temporal_dep", source_text, fixed = TRUE))
  expect_false(grepl("gllvmTMB::kernel_indep", source_text, fixed = TRUE))
  expect_match(source_text, "getFromNamespace\\(\"temporal_dep\"")
  expect_match(source_text, "output must name a new result file")
  expect_match(source_text, "error_message = conditionMessage")
  parser <- getFromNamespace("parse_multi_formula", "gllvmTMB")
  expect_silent(parser(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "fixed_nonproportional_K")))
})

test_that("the 160-series qualification launcher preserves the compute boundary", {
  launcher <- .skip_if_temporal_dep_kernel_160_dev_files_unavailable(
    "remote", "dep-kernel-160-qualification-totoro.sh"
  )
  expect_equal(system2("bash", c("-n", launcher)), 0L)
  source_text <- paste(readLines(launcher, warn = FALSE), collapse = "\n")
  expect_match(source_text, "TEMPORAL_DEP_KERNEL_160_TOTORO_APPROVED=YES")
  expect_match(source_text, "WORKERS=9")
  expect_match(source_text, "2609341")
  expect_match(source_text, "pre-run")
  expect_match(source_text, "git@github.com:itchyshin/gllvmTMB.git")
  expect_match(source_text, "git fetch --no-tags origin")
  expect_match(source_text, "--untracked-files=no")
})

test_that("the retained 160-series qualification failure is complete and immutable", {
  script <- .skip_if_temporal_dep_kernel_160_dev_files_unavailable(
    "run-dep-kernel-160-qualification.R"
  )
  source(script, local = environment())
  receipts <- .temporal_dep_kernel_160_dev_path("results", "qualification-160-20260912")
  skip_if_not(dir.exists(receipts), "retained Totoro qualification receipts are unavailable")
  paths <- sort(list.files(receipts, pattern = "[.]rds$", full.names = TRUE))
  expect_length(paths, 9L)
  records <- lapply(paths, readRDS)
  result <- do.call(rbind, lapply(records, `[[`, "result"))
  expect_setequal(paste(result$phi, result$seed, sep = ":"),
    as.vector(outer(c(-.4, 0, .6), 2609341:2609343, paste, sep = ":")))
  expect_true(all(result$terminal == "success"))
  expect_true(all(result$convergence == 0L))
  expect_true(all(result$pass_2_accepted))
  expect_true(all(result$hessian_status == "error"))
  verdict <- .temporal_dep_kernel_160_summarise(result)
  expect_false(all(verdict$summary$passes))
  expect_equal(verdict$summary$strict_successes[verdict$summary$phi == 0], 0L)
  expect_gt(verdict$summary$median_kernel_3_relative_error[verdict$summary$phi == .6], .35)
})
