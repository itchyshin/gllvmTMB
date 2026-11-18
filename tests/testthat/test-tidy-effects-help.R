# Issue #1392 item 5: tidy help must name the `effects` argument.
#
# R CMD check runs tests from <pkg>.Rcheck/tests/testthat.  ../../man and
# ../../R are the check tree, not the source package, so those naive paths
# fail with "cannot open the connection".  The tarball copy lives at
# ../../00_pkg_src/gllvmTMB/ (same layout as test-isdm-developer-fit.R).

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

test_that("tidy.gllvmTMB_multi Rd value uses effects, not effect", {
  rd_path <- .pkg_source_file("man", "tidy.gllvmTMB_multi.Rd")
  expect_true(is.character(rd_path) && !is.na(rd_path) && file.exists(rd_path))
  rd <- paste(readLines(rd_path, warn = FALSE), collapse = "\n")
  expect_match(rd, "effects = \"fixed\"", fixed = TRUE)
  expect_match(rd, "effects = \"cutpoint\"", fixed = TRUE)
  expect_no_match(rd, "effect = \"fixed\"", fixed = TRUE)
  expect_no_match(rd, "effect = \"cutpoint\"", fixed = TRUE)
})

test_that("tidy.gllvmTMB_multi roxygen return uses effects, not effect", {
  r_path <- .pkg_source_file("R", "methods-gllvmTMB.R")
  expect_true(is.character(r_path) && !is.na(r_path) && file.exists(r_path))
  src <- paste(readLines(r_path, warn = FALSE), collapse = "\n")
  expect_match(src, "#' @return A data.frame. `effects = \"fixed\"`", fixed = TRUE)
  expect_match(src, "`effects = \"cutpoint\"` rows carry the", fixed = TRUE)
})
