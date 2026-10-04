## Issue #1361: spatial_latent() articles must not use the ignored `| location` token.

test_that("structured-source-strength.Rmd avoids spatial_latent |location syntax", {
  rmd <- testthat::test_path(
    "..", "..", "vignettes", "articles", "structured-source-strength.Rmd"
  )
  testthat::skip_if_not(file.exists(rmd), "article missing")

  text <- paste(readLines(rmd, warn = FALSE), collapse = "\n")
  testthat::expect_no_match(
    text,
    "spatial_latent\\([^\\n]*\\|location",
    info = "Use `| coords` (recommended) instead of `| location`, which the parser ignores"
  )
})
