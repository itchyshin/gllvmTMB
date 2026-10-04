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

psi_note <- "one-time warning.*per-trait Psi by default"

test_that("articles note the expected once-per-session latent() Psi warning", {
  articles <- c(
    "convergence-start-values.Rmd",
    "pre-fit-response-screening.Rmd",
    "pitfalls.Rmd"
  )
  for (nm in articles) {
    rmd <- testthat::test_path("..", "..", "vignettes", "articles", nm)
    testthat::skip_if_not(file.exists(rmd), paste("missing", nm))
    text <- paste(readLines(rmd, warn = FALSE), collapse = "\n")
    testthat::expect_match(
      text,
      psi_note,
      info = paste0(nm, " should explain the once-per-session Psi warning")
    )
  }
})
