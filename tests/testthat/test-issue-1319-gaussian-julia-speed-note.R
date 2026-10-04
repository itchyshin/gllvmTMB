test_that("?gllvmTMB documents Julia closed-form Gaussian speed path (#1319)", {
  path <- testthat::test_path("..", "..", "R", "gllvmTMB.R")
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(txt, "unstructured Gaussian", fixed = TRUE)
  expect_match(txt, "closed-form profile", fixed = TRUE)
  expect_match(txt, 'engine = "julia"', fixed = TRUE)
})
