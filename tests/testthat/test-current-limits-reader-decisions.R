testthat::test_that("current limits begins with reader decisions", {
  testthat::skip_on_cran()

  root <- testthat::test_path("..", "..")
  page <- file.path(root, "vignettes", "articles", "current-limits.Rmd")
  testthat::skip_if_not(file.exists(page), "not a source checkout")

  ## This page is where a reader decides whether to use a model.  Keep the
  ## evidence boundaries, but make the first table answer that decision before
  ## it exposes the detailed technical record below.
  text <- paste(readLines(page, warn = FALSE), collapse = "\n")
  ## The first table ends before the specialist sections.
  opening <- paste(readLines(page, warn = FALSE)[1:107], collapse = "\n")

  testthat::expect_match(opening, "Choose a model within the evidence", fixed = TRUE)
  testthat::expect_match(
    opening,
    "A safer starting point within the tested conditions",
    fixed = TRUE
  )
  testthat::expect_match(opening, "Exploratory only", fixed = TRUE)
  testthat::expect_match(opening, "Do not use it for this purpose", fixed = TRUE)
  testthat::expect_match(opening, "Your model or question", fixed = TRUE)
  testthat::expect_false(grepl("Experimental/partial", text, fixed = TRUE))
  testthat::expect_false(grepl("Not recommended", text, fixed = TRUE))
})
