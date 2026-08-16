test_that("G2c three-visit fixture contract validates without fitting", {
  pkg_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE)
  script <- file.path(pkg_root, "dev", "isdm-package-recovery", "run-g2c-replicated-pa-recovery.R")
  skip_if_not(file.exists(script), "developer-only recovery harness is unavailable")
  out <- tempfile("g2c-validate-")
  result <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", script, "--mode=validate", paste0("--output=", out), paste0("--pkg=", pkg_root)),
    stdout = TRUE, stderr = TRUE
  )
  expect_true(is.null(attr(result, "status")) || identical(attr(result, "status"), 0L))
  expect_true(any(grepl("G2c fixture/event contract validation PASS", result, fixed = TRUE)))
  expect_false(dir.exists(out))
})
