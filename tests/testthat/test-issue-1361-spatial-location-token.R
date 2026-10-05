## Issue #1361: spatial_latent() articles must not use the ignored `| location` token.
##
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

test_that("structured-source-strength.Rmd avoids spatial_latent |location syntax", {
  rmd <- .pkg_source_file(
    "vignettes", "articles", "structured-source-strength.Rmd"
  )
  testthat::skip_if_not(
    is.character(rmd) && !is.na(rmd) && file.exists(rmd),
    "article missing"
  )

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
    rmd <- .pkg_source_file("vignettes", "articles", nm)
    testthat::skip_if_not(
      is.character(rmd) && !is.na(rmd) && file.exists(rmd),
      paste("missing", nm)
    )
    text <- paste(readLines(rmd, warn = FALSE), collapse = "\n")
    testthat::expect_match(
      text,
      psi_note,
      info = paste0(nm, " should explain the once-per-session Psi warning")
    )
  }
})
