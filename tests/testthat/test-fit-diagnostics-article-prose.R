test_that("fit-diagnostics article does not claim all six health rows pass", {
  rmd_path <- testthat::test_path("../../vignettes/articles/fit-diagnostics.Rmd")
  skip_if_not(file.exists(rmd_path))
  text <- paste(readLines(rmd_path, warn = FALSE), collapse = "\n")
  expect_false(grepl("These six displayed rows pass", text, fixed = TRUE))
  expect_match(text, "pd_hessian.*warn", ignore.case = TRUE)
})
