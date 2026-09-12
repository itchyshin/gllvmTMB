test_that("the disjoint 160-series dep-kernel qualification plan is fixed", {
  script <- testthat::test_path("..", "..", "dev", "temporal-program",
    "run-dep-kernel-160-qualification.R")
  if (!file.exists(script)) {
    expect_true(file.exists(script))
    return(invisible())
  }
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
  expect_match(source_text, "output must name a new result file")
})

test_that("the 160-series qualification launcher preserves the compute boundary", {
  launcher <- testthat::test_path("..", "..", "dev", "temporal-program", "remote",
    "dep-kernel-160-qualification-totoro.sh")
  expect_true(file.exists(launcher))
  expect_equal(system2("bash", c("-n", launcher)), 0L)
  source_text <- paste(readLines(launcher, warn = FALSE), collapse = "\n")
  expect_match(source_text, "TEMPORAL_DEP_KERNEL_160_TOTORO_APPROVED=YES")
  expect_match(source_text, "WORKERS=9")
  expect_match(source_text, "2609341")
  expect_match(source_text, "pre-run")
})
