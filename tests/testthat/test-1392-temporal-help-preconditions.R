## #1392 item 3: temporal_* help must name the parser preconditions.
## Reads the generated Rd (and its roxygen source) so a later document()
## cannot drop the Requirements wording without failing this file.

test_that("temporal_* Rd names the parser preconditions from R/temporal.R", {
  rd_path <- test_path("..", "..", "man", "temporal_latent.Rd")
  src_path <- test_path("..", "..", "R", "temporal.R")
  expect_true(file.exists(rd_path))
  expect_true(file.exists(src_path))

  rd <- paste(readLines(rd_path, warn = FALSE), collapse = "\n")
  src <- paste(readLines(src_path, warn = FALSE), collapse = "\n")
  collapse <- function(x) gsub("[[:space:]]+", " ", x)

  expect_match(rd, "\\\\section\\{Requirements\\}")
  expect_match(src, "@section Requirements:")

  for (text in list(collapse(rd), collapse(src))) {
    expect_match(text, "complete Gaussian")
    expect_match(text, "0 \\+ trait")
    expect_match(text, "at least three traits")
    expect_match(text, "three strictly ordered occasions")
    expect_match(text, "finite numeric")
    expect_match(text, "integer-valued")
  }
})
