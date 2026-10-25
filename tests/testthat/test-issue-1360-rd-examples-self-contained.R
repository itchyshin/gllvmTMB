# Issue #1360: help-page examples that sit in \dontrun{} must still define
# every object they use. Before this change seven pages called `fit`, `df`
# or `tree` without creating them, so pasting the example failed with
# "object 'fit' not found" (or the misleading "data is not a data frame",
# because `df` resolves to stats::df). Each page below is checked two ways:
#
#   1. static: the example never passes the bare name `df` as data;
#   2. dynamic: tools::Rd2ex() with \dontrun{} UN-commented evaluates
#      without error in a fresh environment.

pages_1360 <- c(
  "extract_Omega", "extract_loadings", "extract_phylo_signal",
  "extract_proportions", "extract_residual_split", "getLV", "getLoadings"
)

rd_page_1360 <- function(page) {
  rd_file <- file.path(testthat::test_path("..", "..", "man"),
                       paste0(page, ".Rd"))
  if (file.exists(rd_file)) {
    return(tools::parse_Rd(rd_file))
  }
  db <- tools::Rd_db("gllvmTMB")
  key <- paste0(page, ".Rd")
  if (!key %in% names(db)) {
    stop("no Rd page ", sQuote(page), " in man/ or the installed package")
  }
  db[[key]]
}

rd_example_file_1360 <- function(rd) {
  ex_file <- tempfile(fileext = ".R")
  tools::Rd2ex(rd, out = ex_file, commentDontrun = FALSE)
  ex_file
}

for (page in pages_1360) {
  local({
    page <- page

    test_that(paste0("?", page, " example does not pass the bare name df as data (#1360)"), {
      ex_file <- rd_example_file_1360(rd_page_1360(page))
      withr::defer(unlink(ex_file))
      expect_true(file.exists(ex_file))
      code <- readLines(ex_file, warn = FALSE)
      expect_false(any(grepl("data\\s*=\\s*df\\b", code)))
    })

    test_that(paste0("?", page, " example is self-contained (#1360)"), {
      skip_on_cran()
      skip_if_not_installed("ape")
      ex_file <- rd_example_file_1360(rd_page_1360(page))
      withr::defer(unlink(ex_file))
      exprs <- parse(file = ex_file, keep.source = FALSE)
      expect_gt(length(exprs), 0L)
      env <- new.env(parent = globalenv())
      withr::local_seed(1360L)
      withr::local_options(lifecycle_verbosity = "quiet")
      grDevices::pdf(NULL)
      withr::defer(grDevices::dev.off())
      expect_no_error(
        suppressMessages(suppressWarnings(
          for (expr in exprs) eval(expr, envir = env)
        ))
      )
    })
  })
}
