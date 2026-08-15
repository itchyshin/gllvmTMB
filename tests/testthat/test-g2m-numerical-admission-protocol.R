test_that("G2m protocol validator is a design-only no-fit gate", {
  path <- isdm_dev_path("run-g2m-numerical-admission-validation.R")
  lines <- readLines(path, warn = FALSE)
  code <- paste(lines, collapse = "\n")

  expect_match(code, "G2M numerical-admission protocol validation PASS", fixed = TRUE)
  expect_match(code, "A. Raw pass / polish ineligible", fixed = TRUE)
  expect_match(code, "C. Non-boundary residual", fixed = TRUE)
  expect_match(code, "`NOT_REQUIRED`", fixed = TRUE)
  expect_match(code, "`NO_CANDIDATE`", fixed = TRUE)
  executable <- paste(lines[!grepl("expect_false", lines, fixed = TRUE)], collapse = "\n")
  expect_false(grepl("nlminb\\(|TMB::MakeADFun\\(|\\.gll_isdm_fit\\(|gllvmTMB\\(", executable))
})
