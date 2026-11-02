## Issue #1346, part E: the five extractor help pages that were still one
## \dontrun{} block must carry examples that `example()` and `R CMD check`
## actually execute. Code inside `\dontrun{}` is never run, so an example that
## drifts away from the function it documents goes unnoticed.
##
## Two guarantees per page:
##   1. static: the \examples section has no \dontrun{} block at all, and
##      does contain executable code;
##   2. dynamic: the code that tools::Rd2ex() extracts from the page
##      evaluates, printing included, without an error or a warning.

.ex1346e_topics <- c(
  "getLV", "getLoadings", "extract_loadings",
  "extract_proportions", "extract_residual_split"
)

## Parsed help pages of the package under test, keyed by topic file name.
## Under devtools::test() these are the source man/ pages; under R CMD check
## the tests run from <pkg>.Rcheck/tests, with no man/ directory alongside, so
## the installed package's Rd database is used.
.ex1346e_rd <- local({
  db <- NULL
  function(topic) {
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
    if (!topic %in% names(db)) {
      stop("no help page ", sQuote(topic), " in man/ or the installed package")
    }
    db[[topic]]
  }
})

## The top-level \examples sections of one parsed page.
.ex1346e_examples <- function(rd) {
  top <- vapply(rd, function(x) {
    tag <- attr(x, "Rd_tag")
    if (is.null(tag)) "" else tag
  }, character(1))
  rd[top == "\\examples"]
}

## Number of \dontrun{} blocks inside an Rd fragment.
.ex1346e_n_dontrun <- function(x) {
  n <- as.integer(identical(attr(x, "Rd_tag"), "\\dontrun"))
  if (is.list(x)) n <- n + sum(vapply(x, .ex1346e_n_dontrun, integer(1)))
  n
}

## TRUE when an Rd fragment holds a line of code, i.e. something other than
## white space or a comment.
.ex1346e_has_code <- function(x) {
  tag <- attr(x, "Rd_tag")
  if (identical(tag, "COMMENT")) {
    return(FALSE)
  }
  if (is.list(x)) {
    return(any(vapply(x, .ex1346e_has_code, logical(1))))
  }
  is.character(x) && any(grepl("^[[:space:]]*[^#[:space:]]", x))
}

for (topic in .ex1346e_topics) {
  local({
    topic <- topic

    test_that(sprintf("#1346e: ?%s examples contain no \\dontrun{}", topic), {
      examples <- .ex1346e_examples(.ex1346e_rd(topic))
      expect_length(examples, 1L)
      expect_identical(
        .ex1346e_n_dontrun(examples), 0L,
        label = sprintf("number of \\dontrun{} blocks in ?%s", topic)
      )
      expect_true(
        .ex1346e_has_code(examples),
        label = sprintf("?%s has example code", topic)
      )
    })

    test_that(sprintf("#1346e: ?%s examples run without error or warning", topic), {
      ## R CMD check runs these examples itself; this test re-runs them so a
      ## broken example also fails devtools::test(). Kept off CRAN to spare
      ## check time there.
      skip_on_cran()
      tf <- tempfile(fileext = ".R")
      on.exit(unlink(tf), add = TRUE)
      tools::Rd2ex(.ex1346e_rd(topic), out = tf, commentDontrun = TRUE)
      expect_true(file.exists(tf), label = sprintf("example code of ?%s", topic))
      exprs <- parse(tf, keep.source = FALSE)
      expect_gt(length(exprs), 0L,
                label = sprintf("expressions example(%s) executes", topic))

      ## Fire-on-use grammar notes and rlang's once-per-session warnings are
      ## switched on, so an example written in deprecated syntax fails. The
      ## package's own once-per-session tracker is restored afterwards.
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
      warns <- character()
      err <- tryCatch(
        withr::with_seed(1346L, withCallingHandlers(
          {
            utils::capture.output(suppressMessages({
              for (e in exprs) {
                res <- withVisible(eval(e, envir = env))
                if (res$visible) print(res$value)
              }
            }))
            NA_character_
          },
          warning = function(w) {
            warns <<- c(warns, conditionMessage(w))
            invokeRestart("muffleWarning")
          }
        )),
        error = function(e) conditionMessage(e)
      )
      expect_identical(err, NA_character_,
                       label = sprintf("error from example(%s)", topic))
      expect_identical(unique(warns), character(0),
                       label = sprintf("warnings from example(%s)", topic))
      ## Every example builds data or a fit, so an empty environment means
      ## the body did not run.
      expect_gt(length(ls(env)), 0L,
                label = sprintf("objects example(%s) creates", topic))
    })
  })
}
