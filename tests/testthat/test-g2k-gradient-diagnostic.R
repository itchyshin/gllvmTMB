test_that("G2k gradient diagnostic remains a read-only all-attempt extractor", {
  path <- test_path("..", "..", "dev", "isdm-package-recovery",
                    "run-g2k-gradient-diagnostic.R")
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_match(code, "G2K_GRADIENT_DIAGNOSTIC_V1", fixed = TRUE)
  expect_match(code, "n_requested, 150L", fixed = TRUE)
  expect_match(code, "raw_gradient", fixed = TRUE)
  expect_match(code, "scaled_gradient", fixed = TRUE)
  expect_match(code, "hessian_condition", fixed = TRUE)
  expect_match(code, "n_weak_lower_profiles", fixed = TRUE)
  expect_match(code, "failure-decomposition.csv", fixed = TRUE)
  expect_match(code, "polish-decomposition.csv", fixed = TRUE)
  expect_false(grepl("nlminb\\(|gllvmTMB\\(|\\.gll_isdm_fit\\(|TMB::MakeADFun", code))
})
