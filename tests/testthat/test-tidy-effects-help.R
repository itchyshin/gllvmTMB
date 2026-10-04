# Issue #1392 item 5: tidy help must name the `effects` argument.

test_that("tidy.gllvmTMB_multi Rd value uses effects, not effect", {
  rd_path <- testthat::test_path("..", "..", "man", "tidy.gllvmTMB_multi.Rd")
  rd <- paste(readLines(rd_path, warn = FALSE), collapse = "\n")
  expect_match(rd, "effects = \"fixed\"", fixed = TRUE)
  expect_match(rd, "effects = \"cutpoint\"", fixed = TRUE)
  expect_no_match(rd, "effect = \"fixed\"", fixed = TRUE)
  expect_no_match(rd, "effect = \"cutpoint\"", fixed = TRUE)
})

test_that("tidy.gllvmTMB_multi roxygen return uses effects, not effect", {
  r_path <- testthat::test_path("..", "..", "R", "methods-gllvmTMB.R")
  src <- paste(readLines(r_path, warn = FALSE), collapse = "\n")
  expect_match(src, "#' @return A data.frame. `effects = \"fixed\"`", fixed = TRUE)
  expect_match(src, "`effects = \"cutpoint\"` rows carry the", fixed = TRUE)
})
