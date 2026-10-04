## Issue #1134: Design 123's paper-alignment table must not present the
## univariate-PMM or ordinal-phylo rows as unconditionally covered at T = 1.

testthat::test_that("Design 123 alignment rows honour the T = 1 scope boundary (#1134)", {
  root <- testthat::test_path("..", "..")
  path <- file.path(root, "docs", "design", "123-multinomial-structured-surface.md")
  testthat::skip_if_not(file.exists(path), "Design 123 not found (not a source checkout)")

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
