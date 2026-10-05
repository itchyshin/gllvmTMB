## Issue #1134: Design 123's paper-alignment table must not present the
## univariate-PMM or ordinal-phylo rows as unconditionally covered at T = 1.
##
## R CMD check runs tests from <pkg>.Rcheck/tests/testthat.  ../../docs is
## the check tree, not the source package, so the naive path misses the
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

testthat::test_that("Design 123 alignment rows honour the T = 1 scope boundary (#1134)", {
  path <- .pkg_source_file("docs", "design", "123-multinomial-structured-surface.md")
  testthat::skip_if_not(
    is.character(path) && !is.na(path) && file.exists(path),
    "Design 123 not found (not a source checkout)"
  )

  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  expect_true(any(grepl("T = 1 caveat", lines, fixed = TRUE)))
  expect_true(any(grepl("issue #1134", lines, fixed = TRUE)))

  uni_line <- grep("Univariate continuous PMM", lines, value = TRUE, fixed = TRUE)
  testthat::expect_length(uni_line, 1L)
  testthat::expect_false(grepl("\\| covered \\|", uni_line, perl = TRUE))
  testthat::expect_true(grepl("T >= 2", uni_line, fixed = TRUE))

  ord_phy_line <- grep(
    "Ordinal PGLMM with phylogenetic/relatedness source",
    lines,
    value = TRUE,
    fixed = TRUE
  )
  testthat::expect_length(ord_phy_line, 1L)
  testthat::expect_false(grepl("\\| covered \\|", ord_phy_line, perl = TRUE))
  testthat::expect_true(grepl("T >= 2 required", ord_phy_line, fixed = TRUE))
})
