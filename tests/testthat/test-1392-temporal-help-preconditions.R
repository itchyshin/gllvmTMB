## #1392 item 3: temporal_* help must name the parser preconditions.
## Reads the generated Rd (and its roxygen source) so a later document()
## cannot drop the Requirements wording without failing this file.
##
## R CMD check runs tests from <pkg>.Rcheck/tests/testthat.  ../../man and
## ../../R are the check tree, not the source package, so those naive paths
## fail with "cannot open the connection".  The tarball copy lives at
## ../../00_pkg_src/gllvmTMB/ (same layout as test-isdm-developer-fit.R).

.pkg_source_file <- function(...) {
  rel <- do.call(file.path, list(...))
  candidates <- c(
    testthat::test_path("..", "..", rel),
    testthat::test_path("..", "..", "00_pkg_src", "gllvmTMB", rel),
    testthat::test_path("..", "..", "..", "00_pkg_src", "gllvmTMB", rel)
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    return(NA_character_)
  }
  found[[1L]]
}

test_that("temporal_* Rd names the parser preconditions from R/temporal.R", {
  rd_path <- .pkg_source_file("man", "temporal_latent.Rd")
  src_path <- .pkg_source_file("R", "temporal.R")
  expect_true(is.character(rd_path) && !is.na(rd_path) && file.exists(rd_path))
  expect_true(is.character(src_path) && !is.na(src_path) && file.exists(src_path))

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
