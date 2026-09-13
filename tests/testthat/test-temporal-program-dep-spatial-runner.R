test_that("the corrected dependent-spatial runner refuses unsafe campaign starts", {
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "run-dep-spatial-recovery.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  root <- normalizePath(file.path(dirname(script), "..", ".."), mustWork = TRUE)
  old_wd <- setwd(root)
  on.exit(setwd(old_wd), add = TRUE)
  rscript <- file.path(R.home("bin"), "Rscript")

  legacy <- suppressWarnings(system2(rscript, c("--vanilla", script), stdout = TRUE, stderr = TRUE))
  expect_equal(attr(legacy, "status"), 1L)
  expect_match(paste(legacy, collapse = "\n"), "legacy dependent-spatial campaign is frozen")

  missing_index <- suppressWarnings(system2(rscript, c("--vanilla", script),
    env = "DEP_SPATIAL_CAMPAIGN=corrected-scale-20260911", stdout = TRUE, stderr = TRUE)
  )
  expect_equal(attr(missing_index, "status"), 1L)
  expect_match(paste(missing_index, collapse = "\n"), "requires DEP_SPATIAL_ONE")

})
