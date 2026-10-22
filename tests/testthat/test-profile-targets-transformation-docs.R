test_that("profile_targets Rd transformation vocab matches the registry", {
  rd_path <- testthat::test_path("../../man/profile_targets.Rd")
  skip_if_not(file.exists(rd_path), "man/profile_targets.Rd missing (run devtools::document())")
  rd <- paste(readLines(rd_path, warn = FALSE), collapse = "\n")
  expect_match(rd, "Currently emitted: \\\\code\\{linear_predictor\\}")
  expect_match(rd, "Reserved \\(allowed, not currently returned\\): \\\\code\\{logit\\}")
  expect_false(grepl(
    "One of \\\\code\\{linear_predictor\\}, \\\\code\\{exp\\},\\n\\\\code\\{logit\\}",
    rd
  ))
})
