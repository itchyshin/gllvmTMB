test_that("G2i recovery pre-run validates its frozen fixture without fitting", {
  pkg <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE)
  script <- file.path(pkg, "dev", "isdm-package-recovery", "run-g2i-recovery-prerun.R")
  skip_if_not(file.exists(script), "private G2i recovery pre-run runner is unavailable")
  output <- tempfile("g2i-prerun-validate-")
  result <- system2(
    file.path(R.home("bin"), "Rscript"),
    shQuote(c("--vanilla", script, "--mode=validate", paste0("--output=", output),
      paste0("--pkg=", pkg))), stdout = TRUE, stderr = TRUE
  )
  expect_true(is.null(attr(result, "status")) || identical(attr(result, "status"), 0L))
  expect_true(any(grepl("G2I recovery pre-run validation PASS", result, fixed = TRUE)))
  expect_false(dir.exists(output))
})
