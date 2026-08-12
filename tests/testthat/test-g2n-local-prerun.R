test_that("G2n local pre-run validates frozen inputs without fitting", {
  pkg <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE)
  script <- file.path(pkg, "dev", "isdm-package-recovery", "run-g2n-local-prerun.R")
  output <- tempfile("g2n-prerun-validate-")
  result <- system2(file.path(R.home("bin"), "Rscript"), c(
    "--vanilla", script, "--mode=validate", paste0("--output=", output),
    paste0("--pkg=", pkg)
  ), stdout = TRUE, stderr = TRUE)
  expect_true(is.null(attr(result, "status")) || identical(attr(result, "status"), 0L))
  expect_true(any(grepl("G2N local pre-run validation PASS", result, fixed = TRUE)))
  expect_false(dir.exists(output))
})
