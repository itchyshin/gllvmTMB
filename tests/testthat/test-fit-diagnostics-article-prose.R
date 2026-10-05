## R CMD check runs tests from <pkg>.Rcheck/tests/testthat.  ../../vignettes
## is the check tree, not the source package, so the naive path misses the
## file.  The tarball copy lives at ../../00_pkg_src/gllvmTMB/ (same layout
## as test-isdm-developer-fit.R).

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

test_that("fit-diagnostics article does not claim all six health rows pass", {
  rmd_path <- .pkg_source_file("vignettes", "articles", "fit-diagnostics.Rmd")
  skip_if_not(is.character(rmd_path) && !is.na(rmd_path) && file.exists(rmd_path))
  text <- paste(readLines(rmd_path, warn = FALSE), collapse = "\n")
  expect_false(grepl("These six displayed rows pass", text, fixed = TRUE))
  expect_match(text, "pd_hessian.*warn", ignore.case = TRUE)
})
