## Issue #1346, part B of 4: the keyword and family help pages must carry
## examples that `example()` and `R CMD check` actually execute. Code inside
## `\dontrun{}` is never run, so an example that drifts away from the code it
## documents (an undefined `dat`, continuous values passed to a binomial
## trait) goes unnoticed. Part B covers the animal_*, diagonal-term, traits(),
## spde, kernel, iSDM-source and family pages.
##
## Two guarantees per page:
##   1. its \examples section contains no \dontrun{} block. No example on
##      these pages needs Julia or an external resource, the only two reasons
##      that would justify one; and
##   2. the code that tools::Rd2ex() extracts from it, with \donttest{} code
##      included as `R CMD check --run-donttest` runs it, contains at least one
##      executable expression and evaluates without error.

.ex1346b_topics <- c(
  "animal_dep", "animal_indep", "animal_latent", "animal_scalar",
  "animal_slope", "animal_unique", "pedigree_to_Ainv_sparse",
  "diag_re", "traits", "spde", "kernel_latent", "isdm_sources", "families"
)

## Parsed help pages of the package under test, keyed by topic file name. Under
## devtools::test() these are the source man/ pages; under R CMD check the tests
## run from <pkg>.Rcheck/tests, with no man/ directory alongside, so the
## installed package's Rd database is used instead.
.ex1346b_rd_db <- function() {
  root <- tryCatch(
    testthat::test_path("..", ".."),
    error = function(e) NA_character_
  )
  if (!is.na(root) && file.exists(file.path(root, "DESCRIPTION")) &&
      dir.exists(file.path(root, "man"))) {
    db <- tools::Rd_db(dir = root)
  } else {
    db <- tools::Rd_db(package = "gllvmTMB")
  }
  names(db) <- sub("\\.Rd$", "", basename(names(db)))
  db
}

## Every Rd tag that occurs inside the \examples section of one parsed page.
.ex1346b_example_tags <- function(rd) {
  walk <- function(x) {
    tag <- attr(x, "Rd_tag")
    kids <- if (is.list(x)) unlist(lapply(x, walk), use.names = FALSE)
    c(tag, kids)
  }
  top <- vapply(rd, function(x) {
    tag <- attr(x, "Rd_tag")
    if (is.null(tag)) "" else tag
  }, character(1))
  unique(unlist(lapply(rd[top == "\\examples"], walk), use.names = FALSE))
}

## Extract one page's examples as R CMD check --run-donttest would run them
## (\dontrun commented out, \donttest kept) and evaluate them in a fresh
## environment. Returns the number of executable top-level expressions and the
## error message, if any.
.ex1346b_run_page <- function(rd) {
  tf <- tempfile(fileext = ".R")
  on.exit(unlink(tf), add = TRUE)
  tools::Rd2ex(rd, out = tf, commentDontrun = TRUE, commentDonttest = FALSE)
  exprs <- if (file.exists(tf)) parse(tf, keep.source = FALSE) else expression()
  err <- NA_character_
  if (length(exprs) > 0L) {
    env <- new.env(parent = globalenv())
    err <- tryCatch(
      withr::with_preserve_seed(suppressMessages(suppressWarnings(
        for (e in exprs) eval(e, envir = env)
      ))),
      error = function(e) conditionMessage(e)
    )
    if (!is.character(err)) err <- NA_character_
  }
  list(n_expr = length(exprs), error = err)
}

test_that("#1346b: keyword and family help pages keep no \\dontrun{} examples", {
  db <- .ex1346b_rd_db()
  expect_identical(setdiff(.ex1346b_topics, names(db)), character(0))

  tags <- lapply(db[.ex1346b_topics], .ex1346b_example_tags)
  has_examples <- vapply(tags, function(x) "\\examples" %in% x, logical(1))
  expect_identical(names(has_examples)[!has_examples], character(0))

  ## Pages whose examples sit (wholly or partly) inside \dontrun{}.
  dontrun <- vapply(tags, function(x) "\\dontrun" %in% x, logical(1))
  expect_identical(names(dontrun)[dontrun], character(0))
})

test_that("#1346b: keyword and family help examples execute without error", {
  ## R CMD check runs these examples itself; this test re-runs them so a broken
  ## example also fails devtools::test(). Kept off CRAN to spare test time.
  skip_on_cran()
  db <- .ex1346b_rd_db()
  runs <- lapply(db[.ex1346b_topics], .ex1346b_run_page)

  ## Pages on which example() runs nothing at all.
  n_expr <- vapply(runs, function(x) x$n_expr, integer(1))
  expect_identical(names(n_expr)[n_expr == 0L], character(0))

  ## Pages whose examples stop with an error: topic -> message.
  errors <- vapply(runs, function(x) x$error, character(1))
  expect_identical(errors[!is.na(errors)], setNames(character(0), character(0)))
})
