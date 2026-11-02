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

# Repo-wide static guard (#1360). The issue listed 42 pages; the check above
# runs only seven of them. This one reads EVERY help page's examples, with
# \dontrun{} and \donttest{} un-commented, and lists each symbol the example
# uses as a value without assigning it. A symbol passes only if the package
# namespace (and so base R) can find it; `df` and `data` always fail, because
# they resolve to stats::df / utils::data and turn a missing data set into
# "data is not a data frame". Arguments of with()/within()/subset()/
# transform() are skipped: they name data columns, not objects. At commit
# 8010cfd this flags all 42 pages the issue lists.

strip_nse_1360 <- function(e) {
  if (!is.call(e)) return(e)
  if (is.name(e[[1]]) &&
      as.character(e[[1]]) %in% c("with", "within", "subset", "transform") &&
      length(e) > 2L) {
    e <- e[1:2]
  }
  for (i in seq_along(e)[-1L]) {
    if (!is.null(e[[i]]) && !identical(e[[i]], quote(expr = ))) {
      e[[i]] <- strip_nse_1360(e[[i]])
    }
  }
  e
}

undefined_example_objects_1360 <- function(rd) {
  ex_file <- tempfile(fileext = ".R")
  on.exit(unlink(ex_file))
  tools::Rd2ex(rd, out = ex_file, commentDontrun = FALSE,
               commentDonttest = FALSE)
  if (!file.exists(ex_file)) return(character())
  exprs <- lapply(parse(file = ex_file, keep.source = FALSE), strip_nse_1360)
  body_fun <- eval(call("function", NULL,
                        as.call(c(as.name("{"), exprs))))
  ns <- asNamespace("gllvmTMB")
  environment(body_fun) <- ns
  vars <- codetools::findGlobals(body_fun, merge = FALSE)$variables
  vars[vars %in% c("df", "data") |
         !vapply(vars, exists, logical(1), envir = ns)]
}

all_rd_pages_1360 <- function() {
  man_dir <- testthat::test_path("..", "..", "man")
  if (dir.exists(man_dir)) {
    files <- list.files(man_dir, pattern = "\\.Rd$", full.names = TRUE)
    return(stats::setNames(lapply(files, tools::parse_Rd), basename(files)))
  }
  tools::Rd_db("gllvmTMB")
}

test_that("the undefined-object check flags fit, dat and the df trap (#1360)", {
  skip_if_not_installed("codetools")
  rd_file <- tempfile(fileext = ".Rd")
  withr::defer(unlink(rd_file))
  writeLines(c(
    "\\name{x}", "\\alias{x}", "\\title{x}", "\\description{x}",
    "\\examples{", "\\dontrun{",
    "ok <- simulate_site_trait(n_sites = 5, n_species = 2, n_traits = 2)",
    "m <- gllvmTMB(value ~ 0 + trait, data = df, trait = \"trait\")",
    "summary(fit); nrow(dat); nrow(ok$data); pi",
    "with(ok$data, mean(value))",
    "}", "}"
  ), rd_file)
  expect_setequal(undefined_example_objects_1360(tools::parse_Rd(rd_file)),
                  c("df", "fit", "dat"))
})

test_that("no help-page example uses an object it never defines (#1360)", {
  skip_if_not_installed("codetools")
  pages <- all_rd_pages_1360()
  expect_gt(length(pages), 100L)
  undefined <- Filter(length, lapply(pages, undefined_example_objects_1360))
  report <- vapply(names(undefined), function(p) {
    paste0(p, ": ", paste(undefined[[p]], collapse = ", "))
  }, character(1))
  expect(length(undefined) == 0L,
         paste(c("Help-page examples use objects they never define:",
                 report), collapse = "\n"))
})
