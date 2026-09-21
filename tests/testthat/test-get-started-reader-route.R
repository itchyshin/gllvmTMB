testthat::test_that("get started opens with a complete runnable route", {
  testthat::skip_on_cran()

  root <- testthat::test_path("..", "..")
  page <- file.path(root, "vignettes", "gllvmTMB.Rmd")
  testthat::skip_if_not(file.exists(page), "not a source checkout")

  ## This page is a first-time reader's route into the package.  The first
  ## fit they see must be one they can run as written: the package loaded and
  ## the data read in front of them, no dead (eval = FALSE) sketch before it,
  ## and the first output named so they know what they are looking at.
  lines <- readLines(page, warn = FALSE)
  starts <- grep("^```\\{r", lines)
  fences <- which(lines == "```")
  chunks <- lapply(starts, function(s) {
    e <- fences[fences > s][1]
    list(header = lines[s], code = lines[s + seq_len(e - s - 1)])
  })
  header <- vapply(chunks, function(ch) ch$header, character(1))
  eval_false <- grepl("eval\\s*=\\s*FALSE", header)
  hidden <- grepl("include\\s*=\\s*FALSE", header) |
    grepl("echo\\s*=\\s*FALSE", header)
  shown <- !hidden & !eval_false
  has <- function(what) {
    vapply(chunks, function(ch) any(grepl(what, ch$code, fixed = TRUE)),
           logical(1))
  }

  ## A fit is an assignment from gllvmTMB(); check_gllvmTMB() is not a fit.
  is_fit <- vapply(chunks, function(ch) {
    any(grepl("<-\\s*gllvmTMB\\(", ch$code))
  }, logical(1))
  first_fit <- which(is_fit & !eval_false)[1]
  testthat::expect_true(
    length(first_fit) == 1 && !is.na(first_fit),
    info = "a runnable gllvmTMB() call exists"
  )
  if (is.na(first_fit)) return(invisible(NULL))
  before <- seq_len(first_fit - 1)

  ## (a) the first fit is on the page, not run behind the reader's back.
  testthat::expect_false(hidden[first_fit], info = "first fit is visible")
  ## (b) the package is loaded in front of the reader before the fit.
  testthat::expect_true(
    any(shown[before] & has("library(gllvmTMB)")[before]),
    info = "visible library(gllvmTMB) precedes the first fit"
  )
  ## (c) the data the fit uses are loaded in front of the reader.
  testthat::expect_true(
    any(shown[before] & has("readRDS(")[before]),
    info = "visible, evaluated readRDS() precedes the first fit"
  )
  ## (d) nothing the reader cannot run comes before the first fit.
  testthat::expect_false(
    any(eval_false[before]),
    info = "no non-runnable sketch precedes the first fit"
  )
  ## (e) the first output is named and read.
  testthat::expect_true(
    has("as.numeric(logLik(fit))")[first_fit],
    info = "first fit reads as.numeric(logLik(fit))"
  )
  ## (f) the limits page is pointed to before the reader is sent onward.
  limits_at <- grep("current-limits.html", lines, fixed = TRUE)[1]
  onward_at <- grep("^## Choose your next guide", lines)[1]
  testthat::expect_true(
    !is.na(limits_at) && !is.na(onward_at) && limits_at < onward_at,
    info = "current-limits link precedes the next-guide section"
  )
})
