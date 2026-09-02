## User-facing messages are a reader surface: a hint that tells someone to reach
## for a soft-deprecated feature is the same defect as an article teaching it.
## This scans string literals only -- parse() discards comments, so an internal
## code comment mentioning the deprecated mechanism is correctly ignored.

r_dir <- testthat::test_path("..", "..", "R")

string_literals <- function(path) {
  expr <- tryCatch(parse(path), error = function(e) NULL)
  if (is.null(expr)) return(character())
  out <- character()
  walk <- function(x) {
    if (is.expression(x)) {
      for (e in as.list(x)) walk(e)
      return(invisible(NULL))
    }
    if (is.character(x)) {
      out <<- c(out, x)
      return(invisible(NULL))
    }
    if (is.call(x)) {
      parts <- as.list(x)
      ## Missing-argument slots are the empty symbol, which errors when forced.
      for (i in seq_along(parts)) try(walk(parts[[i]]), silent = TRUE)
    }
    invisible(NULL)
  }
  walk(expr)
  out
}

test_that("no user-facing message recommends the soft-deprecated residual start", {
  testthat::skip_if_not(dir.exists(r_dir), "R/ not present")

  offenders <- character()
  for (f in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
    lits <- string_literals(f)
    hits <- grep("residual start", lits, ignore.case = TRUE, value = TRUE)
    ## A message that names the deprecation is fine -- it is the recommendation
    ## that is the defect.
    hits <- hits[!grepl("deprecat", hits, ignore.case = TRUE)]
    if (length(hits)) {
      offenders <- c(offenders, sprintf("%s: %s", basename(f), substr(hits, 1, 60)))
    }
  }
  expect_equal(offenders, character())
})

test_that("no user-facing message recommends a numeric aghq_ridge over loading_ridge", {
  testthat::skip_if_not(dir.exists(r_dir), "R/ not present")

  ## `loading_ridge` is the integration-neutral spelling for a runaway-loading
  ## fix (#gapclose task d); `aghq_ridge = <number>` recommendations should
  ## have moved to it. `aghq_ridge = "auto"` and `aghq_ridge = Inf` are left
  ## alone -- those are AGHQ-specific ladder/likelihood-comparison meanings
  ## that `loading_ridge` does not carry.
  offenders <- character()
  for (f in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
    lits <- string_literals(f)
    hits <- grep("aghq_ridge\\s*=\\s*[0-9]", lits, value = TRUE)
    if (length(hits)) {
      offenders <- c(offenders, sprintf("%s: %s", basename(f), substr(hits, 1, 60)))
    }
  }
  expect_equal(offenders, character())
})
