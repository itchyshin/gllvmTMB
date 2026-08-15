test_that("G2o postmortem validates retained roots without fitting", {
  pkg <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE)
  script <- file.path(pkg, "dev", "isdm-package-recovery", "run-g2o-postmortem.R")
  g2n <- "/private/tmp/gllvmtmb-isdm-g2n-local-prerun/dev/isdm-package-recovery/results/g2n-local-prerun-20260812-0630"
  g2k <- "/private/tmp/gllvmtmb-isdm-g2k-gradient-diagnostic/dev/isdm-package-recovery/results/g2k-gradient-diagnostic-20260812-007"
  skip_if_not(dir.exists(g2n) && dir.exists(g2k), "private G2o evidence roots unavailable")
  output <- tempfile("g2o-validate-")
  result <- system2(file.path(R.home("bin"), "Rscript"), c(
    "--vanilla", script, "--mode=validate", paste0("--g2n-root=", g2n),
    paste0("--g2k-root=", g2k), paste0("--output=", output)
  ), stdout = TRUE, stderr = TRUE)
  expect_true(is.null(attr(result, "status")) || identical(attr(result, "status"), 0L))
  expect_true(any(grepl("G2O postmortem validation PASS", result, fixed = TRUE)))
  expect_false(dir.exists(output))
})

test_that("G2o postmortem contains no fit, profile, or optimizer call", {
  script <- isdm_dev_path("run-g2o-postmortem.R")
  text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_false(grepl("\\.gll_isdm_fit|nlminb\\(|MakeADFun\\(|gllvmTMB\\(|profile_theta", text))
  expect_true(grepl("covariance-scaled scores are not optimizer candidates", text,
                    fixed = TRUE))
})
