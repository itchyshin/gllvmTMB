## #1319: ?gllvmTMB must name the Julia closed-form Gaussian speed path.
##
## R CMD check runs tests from <pkg>.Rcheck/tests/testthat.  ../../R is the
## check tree, not the source package, so the naive path fails with
## "cannot open the connection".  The tarball copy lives at
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

test_that("?gllvmTMB documents Julia closed-form Gaussian speed path (#1319)", {
  path <- .pkg_source_file("R", "gllvmTMB.R")
  expect_true(is.character(path) && !is.na(path) && file.exists(path))
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(txt, "unstructured Gaussian", fixed = TRUE)
  expect_match(txt, "closed-form profile", fixed = TRUE)
  expect_match(txt, 'engine = "julia"', fixed = TRUE)
})
