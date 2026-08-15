test_that("private MSPL constrained-inversion calibration contract is frozen", {
  runner <- testthat::test_path(
    "..", "..", "inst", "sim", "lane-b-uncertainty",
    "run-mspl-constrained-inversion-calibration.R"
  )
  expect_true(file.exists(runner))
  output <- system2("Rscript", c("--vanilla", runner, "validate"), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))

  root <- tempfile("mspl-constrained-inversion-manifest-")
  output <- system2("Rscript", c("--vanilla", runner, "manifest", "--root", root,
    "--campaign-id", "local-contract", "--source-sha", "abc123"), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))
  manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  expect_identical(nrow(manifest), 12L)
  expect_true(all(manifest$n_outer == 1000L))
  expect_true(all(manifest$bootstrap_reps == 499L))
  expect_true(all(manifest$outer_per_shard == 1L))
  expect_true(all(manifest$minimum_usable_bootstrap == 499L))
  expect_identical(nrow(utils::read.delim(file.path(root, "array-map.tsv"))), 12000L)
})
