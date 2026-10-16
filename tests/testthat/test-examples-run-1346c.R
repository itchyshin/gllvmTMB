# Issue #1346, part C: the help-page examples for the extractor functions
# (extract_Sigma*, correlations, repeatability, communality, ordination,
# latent scores, cutpoints, the cross-covariance helpers, the two-Psi
# cross-checks, getREsd(), coef()/vcov() and standard_errors()) must run.
#
# Before this slice every one of these pages wrapped its whole \examples
# section in \dontrun{}, so example(<topic>) ran nothing and R CMD check never
# executed a line of it. Three checks per page:
#
#   1. static: the \examples section has code outside both \dontrun{} and
#      \donttest{}, i.e. the page carries a small example that always runs
#      (cheap, no fitting);
#   2. dynamic: that always-run code -- tools::Rd2ex() with \dontrun and
#      \donttest commented out, as a plain R CMD check runs it -- parses to at
#      least one expression and evaluates without error and without warnings;
#   3. dynamic, heavy tests only: the code example() runs interactively and
#      R CMD check --as-cran runs (\donttest kept) evaluates without error.
#      A \donttest part may warn on purpose (e.g. bootstrap_Sigma() warns that
#      a small n_boot gives noisy bounds), so warnings are not asserted there.
#
# The Rd source is read from man/ when the tests run from a source tree
# (devtools::test()) and from the installed package's Rd database otherwise
# (R CMD check), so both routes test the pages a user actually gets.
# getLV() / getLoadings() live in R/output-methods.R, which another lane owns,
# so ?getLV is not in this list.

pages_1346c <- c(
  "compare_dep_vs_two_psi", "compare_indep_vs_two_psi",
  "extract_Gamma", "extract_Sigma", "extract_Sigma_table",
  "extract_coevolution_modules", "extract_communality",
  "extract_correlations", "extract_cross_correlations",
  "extract_cutpoints", "extract_latent_scores", "extract_ordination",
  "extract_repeatability", "getREsd", "gllvmTMB_multi-vcov",
  "predict_cross_covariance", "standard_errors"
)

rd_page_1346c <- function(page) {
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

# TRUE when an Rd fragment holds code that always runs: any non-blank R code
# outside \dontrun{} and \donttest{}.
rd_has_always_run_code_1346c <- function(x) {
  tag <- attr(x, "Rd_tag")
  if (identical(tag, "\\dontrun") || identical(tag, "\\donttest") ||
      identical(tag, "COMMENT")) {
    return(FALSE)
  }
  if (is.list(x)) {
    return(any(vapply(x, rd_has_always_run_code_1346c, logical(1))))
  }
  is.character(x) && any(grepl("[^[:space:]]", sub("#.*$", "", x)))
}

rd_examples_1346c <- function(rd) {
  tags <- vapply(rd, function(x) {
    tag <- attr(x, "Rd_tag")
    if (is.null(tag)) "" else tag
  }, character(1))
  rd[tags == "\\examples"]
}

# The example code as parsed expressions: with \donttest commented out (what a
# plain R CMD check runs) or kept (what example() and --as-cran run).
rd_example_exprs_1346c <- function(rd, donttest = FALSE) {
  ex_file <- tempfile(fileext = ".R")
  on.exit(unlink(ex_file), add = TRUE)
  tools::Rd2ex(rd, out = ex_file, commentDontrun = TRUE,
               commentDonttest = !donttest)
  if (!file.exists(ex_file)) {
    return(expression())
  }
  parse(file = ex_file, keep.source = FALSE)
}

# Skip, rather than pass vacuously, when an example is guarded by
# requireNamespace() and that package is missing.
skip_if_example_needs_1346c <- function(exprs) {
  code <- unlist(lapply(exprs, deparse))
  needs <- regmatches(
    code, gregexpr('(?<=requireNamespace\\(")[^"]+', code, perl = TRUE)
  )
  for (pkg in unique(unlist(needs))) skip_if_not_installed(pkg)
}

for (page in pages_1346c) {
  local({
    page <- page

    test_that(paste0("?", page, " examples are not a single \\dontrun block (#1346)"), {
      examples <- rd_examples_1346c(rd_page_1346c(page))
      expect_length(examples, 1L)
      expect_true(
        rd_has_always_run_code_1346c(examples[[1L]]),
        label = paste0("?", page, " has example code outside \\dontrun{} and \\donttest{}")
      )
    })

    test_that(paste0("?", page, " examples run (#1346)"), {
      skip_on_cran()
      exprs <- rd_example_exprs_1346c(rd_page_1346c(page))
      expect_gt(length(exprs), 0L,
                label = paste0("expressions example(", page, ") always runs"))
      skip_if_example_needs_1346c(exprs)
      env <- new.env(parent = globalenv())
      withr::local_seed(1346L)
      grDevices::pdf(NULL)
      withr::defer(grDevices::dev.off())
      warned <- character()
      expect_no_error(
        withCallingHandlers(
          for (expr in exprs) eval(expr, envir = env),
          warning = function(w) {
            warned <<- c(warned, conditionMessage(w))
            invokeRestart("muffleWarning")
          }
        )
      )
      # A help example should run cleanly: a warning means deprecated syntax,
      # a non-converged fit, or an example that no longer matches the code.
      expect_identical(warned, character(),
                       label = paste0("warnings from example(", page, ")"))
      # Every example builds data and a fit, so an empty environment means
      # the body did not run.
      expect_gt(length(ls(env)), 0L,
                label = paste0("objects example(", page, ") creates"))
    })

    test_that(paste0("?", page, " examples run with \\donttest code (#1346)"), {
      skip_on_cran()
      skip_if_not_heavy()
      exprs <- rd_example_exprs_1346c(rd_page_1346c(page), donttest = TRUE)
      expect_gt(length(exprs), 0L,
                label = paste0("expressions example(", page, ") runs"))
      skip_if_example_needs_1346c(exprs)
      env <- new.env(parent = globalenv())
      withr::local_seed(1346L)
      grDevices::pdf(NULL)
      withr::defer(grDevices::dev.off())
      expect_no_error(suppressWarnings(
        for (expr in exprs) eval(expr, envir = env)
      ))
    })
  })
}
