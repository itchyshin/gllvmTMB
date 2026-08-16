test_that("G2n local pre-run validates frozen inputs without fitting", {
  isdm_dev_path()  # skips when dev/ did not ship in the built package
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

test_that("G2n post-run provenance finalizer has no fit or optimizer route", {
  isdm_dev_path()  # skips when dev/ did not ship in the built package
  pkg <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE)
  script <- file.path(pkg, "dev", "isdm-package-recovery",
                      "finalize-g2n-local-prerun-provenance.R")
  text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_false(grepl("\\.gll_isdm_fit|nlminb\\(|MakeADFun\\(|gllvmTMB\\(", text))
  expect_true(grepl("G2N_LOCAL_PRERUN_FINAL_PROVENANCE_CLOSURE_V3", text,
                    fixed = TRUE))
  expect_true(grepl("manifest_excludes", text, fixed = TRUE))
})
