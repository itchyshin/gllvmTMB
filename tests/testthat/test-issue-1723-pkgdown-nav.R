## Issue #1723: pkgdown navbar titles must match the reader-facing scan
## in test-reader-facing-no-register-codes.R (plain-language titles with em dashes).

test_that("_pkgdown.yml navbar keeps the validation-oracles nav title (#1723)", {
  skip_on_cran()
  config <- gllvmTMB_pkg_file("_pkgdown.yml")
  text <- paste(readLines(config, warn = FALSE), collapse = "\n")
  expect_match(
    text,
    "How gllvmTMB is checked — and what those checks miss",
    fixed = TRUE
  )
})

test_that("_pkgdown.yml navbar keeps the random-slopes evidence nav title (#1723)", {
  skip_on_cran()
  config <- gllvmTMB_pkg_file("_pkgdown.yml")
  text <- paste(readLines(config, warn = FALSE), collapse = "\n")
  expect_match(
    text,
    "Structured random slopes for non-Gaussian traits — current evidence and limits",
    fixed = TRUE
  )
})