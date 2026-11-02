## Issue #1346, part D of 4: the help pages for fitting, diagnosing,
## loadings, confidence intervals and profiles must carry examples that
## `example()` and `R CMD check` actually execute. Code inside `\dontrun{}` is
## never run, so an example that drifts away from the function it documents
## (an undefined `dat`, an argument that no longer exists) goes unnoticed.
##
## Two guarantees per page:
##   1. static: the \examples section is not one \dontrun{} block, i.e. it has
##      executable code outside \dontrun{}; and any \dontrun{} block left on
##      the page says, in a comment, that it needs Julia or an external
##      resource, the only two reasons this package accepts for one;
##   2. dynamic: the code that tools::Rd2ex() extracts from the page, with
##      \donttest{} code included as `R CMD check --run-donttest` runs it,
##      has at least one executable expression and evaluates, printing
##      included, without an error or a warning.

.ex1346d_topics <- c(
  "gllvmTMB", "check_gllvmTMB", "gllvmTMB_diagnose",
  "gllvmTMB_check_consistency",
  "rotate_loadings", "extract_rotated_loadings_table", "compare_loadings",
  "loading_ci", "flag_unreliable_loadings", "loading_profile",
  "plot_loadings_confidence_eye",
  "suggest_lambda_constraint", "suggest_lambda_constraints",
  "confint.gllvmTMB_multi", "confint_inspect", "profile_targets",
  "slope_sd_ci", "ridge_path", "ordination_uncertainty"
)

## Parsed help pages of the package under test, keyed by topic file name, read
## once per test file. Under devtools::test() these are the source man/ pages;
## under R CMD check the tests run from <pkg>.Rcheck/tests, with no man/
## directory alongside, so the installed package's Rd database is used.
.ex1346d_rd_db <- local({
  db <- NULL
  function() {
    if (is.null(db)) {
      root <- tryCatch(
        testthat::test_path("..", ".."),
        error = function(e) NA_character_
      )
      if (!is.na(root) && file.exists(file.path(root, "DESCRIPTION")) &&
          dir.exists(file.path(root, "man"))) {
        db <<- tools::Rd_db(dir = root)
      } else {
        db <<- tools::Rd_db(package = "gllvmTMB")
      }
      names(db) <<- sub("\\.Rd$", "", basename(names(db)))
    }
    db
  }
})

.ex1346d_rd <- function(topic) {
  db <- .ex1346d_rd_db()
  if (!topic %in% names(db)) {
    stop("no help page ", sQuote(topic), " in man/ or the installed package")
  }
  db[[topic]]
}

## The top-level \examples sections of one parsed page.
.ex1346d_examples <- function(rd) {
  top <- vapply(rd, function(x) {
    tag <- attr(x, "Rd_tag")
    if (is.null(tag)) "" else tag
  }, character(1))
  rd[top == "\\examples"]
}

## TRUE when an Rd fragment holds code that example() executes: a line with
## something other than white space or a comment, outside \dontrun{}. Code
## inside \donttest{} counts, since example() and R CMD check --run-donttest
## run it.
.ex1346d_has_code <- function(x) {
  tag <- attr(x, "Rd_tag")
  if (identical(tag, "\\dontrun") || identical(tag, "COMMENT")) {
    return(FALSE)
  }
  if (is.list(x)) {
    return(any(vapply(x, .ex1346d_has_code, logical(1))))
  }
  is.character(x) && any(grepl("^[[:space:]]*[^#[:space:]]", x))
}

## The text of every \dontrun{} block inside an Rd fragment.
.ex1346d_dontrun_text <- function(x) {
  tag <- attr(x, "Rd_tag")
  if (identical(tag, "\\dontrun")) {
    return(paste(unlist(x), collapse = ""))
  }
  if (is.list(x)) {
    return(unlist(lapply(x, .ex1346d_dontrun_text), use.names = FALSE))
  }
  character()
}

## Extract one page's examples as R CMD check --run-donttest runs them
## (\dontrun commented out, \donttest kept).
.ex1346d_exprs <- function(rd) {
  tf <- tempfile(fileext = ".R")
  on.exit(unlink(tf), add = TRUE)
  tools::Rd2ex(rd, out = tf, commentDontrun = TRUE, commentDonttest = FALSE)
  if (file.exists(tf)) parse(tf, keep.source = FALSE) else expression()
}

## Suggested packages that an example only uses behind requireNamespace(). A
## page whose example is skipped that way would otherwise pass without having
## run, so the test skips it instead when such a package is missing.
.ex1346d_guarded_pkgs <- function(exprs) {
  code <- unlist(lapply(exprs, deparse), use.names = FALSE)
  hits <- regmatches(
    code, gregexpr('(?<=requireNamespace\\(")[^"]+', code, perl = TRUE)
  )
  unique(unlist(hits, use.names = FALSE))
}

## Evaluate the expressions the way R CMD check does: visible top-level values
## are printed, so a failing print method fails here too, and the developer's
## workspace is not visible (attached packages are). Returns the error message
## (NA if none) and any warnings raised.
##
## The package's fire-on-use grammar notes and rlang's once-per-session
## warnings are switched on, so an example written in deprecated syntax fails;
## the package's own once-per-session tracker is restored afterwards and
## rlang's "verbose" mode records nothing, so later tests in this process
## still see the first firing they assert. R CMD check remains the authority
## on whether an example uses only exported functions: under devtools::test()
## the package's internal functions are attached as well.
.ex1346d_run <- function(exprs) {
  seen <- gllvmTMB:::.gllvmTMB_deprecation_seen
  seen_before <- ls(seen, all.names = TRUE)
  on.exit(
    rm(list = setdiff(ls(seen, all.names = TRUE), seen_before), envir = seen),
    add = TRUE
  )
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = FALSE,
    rlib_warning_verbosity = "verbose",
    rlib_message_verbosity = "quiet",
    warn = 1
  )
  grDevices::pdf(NULL)
  dev <- grDevices::dev.cur()
  on.exit(
    if (dev %in% grDevices::dev.list()) grDevices::dev.off(dev),
    add = TRUE
  )
  env <- new.env(parent = parent.env(globalenv()))
  ## print() is called from `env`, so S3 dispatch also finds methods that the
  ## example itself defines, as it does for top-level auto-printing.
  run <- function() {
    for (e in exprs) {
      res <- withVisible(eval(e, envir = env))
      if (res$visible) {
        assign(".ex1346d_value", res$value, envir = env)
        eval(quote(print(.ex1346d_value)), envir = env)
      }
    }
  }
  warns <- character()
  err <- tryCatch(
    withr::with_seed(1346L, withCallingHandlers(
      {
        utils::capture.output(suppressMessages(run()))
        NA_character_
      },
      warning = function(w) {
        warns <<- c(warns, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )),
    error = function(e) conditionMessage(e)
  )
  list(error = err, warnings = unique(warns), objects = ls(env))
}

test_that("#1346d: every part-D topic has a help page with examples", {
  db <- .ex1346d_rd_db()
  expect_identical(setdiff(.ex1346d_topics, names(db)), character(0))
  n_sections <- vapply(
    .ex1346d_topics,
    function(topic) length(.ex1346d_examples(db[[topic]])),
    integer(1)
  )
  expect_identical(names(n_sections)[n_sections != 1L], character(0))
})

for (topic in .ex1346d_topics) {
  local({
    topic <- topic

    test_that(
      sprintf("#1346d: ?%s examples are not a single \\dontrun{} block", topic),
      {
        examples <- .ex1346d_examples(.ex1346d_rd(topic))
        expect_length(examples, 1L)
        expect_true(
          .ex1346d_has_code(examples),
          label = sprintf("?%s has example code outside \\dontrun{}", topic)
        )
        ## A \dontrun{} block is accepted only for Julia or an external
        ## resource, and must say which in a comment inside the block.
        dontrun <- .ex1346d_dontrun_text(examples)
        justified <- grepl("#[^\n]*(julia|external)", dontrun,
                           ignore.case = TRUE)
        expect_identical(
          dontrun[!justified], character(0),
          label = sprintf("?%s \\dontrun{} blocks without a Julia or external-resource reason", topic)
        )
      }
    )

    test_that(
      sprintf("#1346d: ?%s examples run without error or warning", topic),
      {
        ## R CMD check runs these examples itself; this test re-runs them so a
        ## broken example also fails devtools::test(). Kept off CRAN to spare
        ## check time there.
        skip_on_cran()
        exprs <- .ex1346d_exprs(.ex1346d_rd(topic))
        expect_gt(length(exprs), 0L,
                  label = sprintf("expressions example(%s) executes", topic))
        for (pkg in .ex1346d_guarded_pkgs(exprs)) skip_if_not_installed(pkg)
        res <- .ex1346d_run(exprs)
        expect_identical(res$error, NA_character_,
                         label = sprintf("error from example(%s)", topic))
        ## A warning means deprecated syntax, a fit that stops on a boundary
        ## or an example that no longer matches the code.
        expect_identical(res$warnings, character(0),
                         label = sprintf("warnings from example(%s)", topic))
        ## Every example builds data or a fit, so an empty environment means
        ## the body did not run.
        expect_gt(length(res$objects), 0L,
                  label = sprintf("objects example(%s) creates", topic))
      }
    )
  })
}
