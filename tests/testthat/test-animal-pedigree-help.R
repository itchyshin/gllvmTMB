## Issue #1392 item 4: animal_* pedigree help must describe the
## sparse A^{-1} route used by `.animal_resolve_vcv_call()`, not a
## dense-A conversion. Reads the roxygen source (the inherited
## @param lives on animal_scalar).

.animal_keyword_src <- function() {
  dir <- tryCatch(testthat::test_path(), error = function(e) NA_character_)
  if (is.na(dir) || !nzchar(dir) || !dir.exists(dir)) {
    return(NULL)
  }
  dir <- normalizePath(dir, mustWork = FALSE)
  for (i in seq_len(8L)) {
    candidate <- file.path(dir, "R", "animal-keyword.R")
    if (file.exists(file.path(dir, "DESCRIPTION")) && file.exists(candidate)) {
      return(candidate)
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      break
    }
    dir <- parent
  }
  NULL
}

.animal_scalar_roxygen <- function(path) {
  lines <- readLines(path, warn = FALSE)
  start <- grep("Single-shared-variance animal-model", lines, fixed = TRUE)[1L]
  end <- grep("^animal_scalar <- function", lines)[1L]
  testthat::expect_true(is.finite(start) && is.finite(end) && end > start)
  paste(lines[start:end], collapse = "\n")
}

test_that("animal_scalar pedigree help matches sparse Ainv routing", {
  path <- .animal_keyword_src()
  testthat::skip_if(is.null(path), "R/animal-keyword.R is not in this checkout")
  block <- .animal_scalar_roxygen(path)

  expect_match(block, "sparse inverse relationship matrix", fixed = TRUE)
  expect_match(block, "pedigree_to_Ainv_sparse", fixed = TRUE)
  expect_match(block, "Must be passed by name", fixed = TRUE)
  expect_match(block, "wins, then `A`, then `Ainv`", fixed = TRUE)
  expect_match(block, "`id`/`animal`", fixed = TRUE)
  expect_match(block, "`sire`/`father`", fixed = TRUE)
  expect_match(block, "`dam`/`mother`", fixed = TRUE)
  expect_match(block, 'Unknown parents may be `NA`, `""`, or `"0"`', fixed = TRUE)

  expect_false(grepl(
    "Converted internally\\s+to \\*\\*A\\*\\* via Henderson",
    block
  ))
  expect_false(grepl(
    "Only one of\\s+`pedigree`, `A`, or `Ainv` should be given",
    block
  ))
})
