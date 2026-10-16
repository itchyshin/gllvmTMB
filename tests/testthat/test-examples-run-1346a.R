# Issue #1346, part A: the help-page examples for the formula keywords
# documented in R/brms-sugar.R must run.
#
# Before this slice every one of these pages wrapped its whole \examples
# section in \dontrun{}, so example(<topic>) ran nothing and R CMD check never
# executed a line of it. Two checks per page:
#
#   1. static: the \examples section is not a single \dontrun{} block, i.e. it
#      contains code outside \dontrun{} (cheap, no fitting);
#   2. dynamic: the code example() would run -- tools::Rd2ex() with \dontrun
#      commented out and \donttest kept -- parses to at least one expression
#      and evaluates without error.
#
# The Rd source is read from man/ when the tests run from a source tree
# (devtools::test()) and from the installed package's Rd database otherwise
# (R CMD check), so both routes test the pages a user actually gets.

pages_1346a <- c(
  "dep", "gr", "indep", "kernel_slope", "latent", "meta", "meta_V",
  "meta_known_V", "phylo", "phylo_dep", "phylo_indep", "phylo_latent",
  "phylo_rr", "phylo_scalar", "phylo_slope", "phylo_unique", "scalar",
  "slope", "spatial", "spatial_dep", "spatial_indep", "spatial_latent",
  "spatial_scalar", "spatial_unique"
)

rd_page_1346a <- function(page) {
  man_dir <- testthat::test_path("..", "..", "man")
  rd_file <- file.path(man_dir, paste0(page, ".Rd"))
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

# TRUE when an Rd fragment holds code that example() would execute: any
# non-blank R code outside \dontrun{} (code inside \donttest{} counts, since
# example() and R CMD check --run-donttest run it).
rd_has_runnable_code_1346a <- function(x) {
  tag <- attr(x, "Rd_tag")
  if (identical(tag, "\\dontrun") || identical(tag, "COMMENT")) {
    return(FALSE)
  }
  if (is.list(x)) {
    return(any(vapply(x, rd_has_runnable_code_1346a, logical(1))))
  }
  is.character(x) && any(grepl("[^[:space:]]", sub("#.*$", "", x)))
}

rd_examples_1346a <- function(rd) {
  tags <- vapply(rd, function(x) {
    tag <- attr(x, "Rd_tag")
    if (is.null(tag)) "" else tag
  }, character(1))
  rd[tags == "\\examples"]
}

# The code example() runs, as parsed expressions.
rd_example_exprs_1346a <- function(rd) {
  ex_file <- tempfile(fileext = ".R")
  on.exit(unlink(ex_file), add = TRUE)
  tools::Rd2ex(rd, out = ex_file, commentDontrun = TRUE,
               commentDonttest = FALSE)
  if (!file.exists(ex_file)) {
    return(expression())
  }
  parse(file = ex_file, keep.source = FALSE)
}

for (page in pages_1346a) {
  local({
    page <- page

    test_that(paste0("?", page, " examples are not a single \\dontrun block (#1346)"), {
      examples <- rd_examples_1346a(rd_page_1346a(page))
      expect_length(examples, 1L)
      expect_true(
        rd_has_runnable_code_1346a(examples[[1L]]),
        label = paste0("?", page, " has example code outside \\dontrun{}")
      )
    })

    test_that(paste0("?", page, " examples run (#1346)"), {
      skip_on_cran()
      exprs <- rd_example_exprs_1346a(rd_page_1346a(page))
      expect_gt(length(exprs), 0L,
                label = paste0("expressions example(", page, ") executes"))
      env <- new.env(parent = globalenv())
      withr::local_seed(1346L)
      # Pages for deprecated aliases demonstrate them on purpose.
      withr::local_options(lifecycle_verbosity = "quiet")
      grDevices::pdf(NULL)
      withr::defer(grDevices::dev.off())
      expect_no_error(
        for (expr in exprs) eval(expr, envir = env)
      )
    })
  })
}
