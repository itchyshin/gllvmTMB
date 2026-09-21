## The first fit a reader meets on a teaching page must be one they can run
## as written: the package loaded and the data read in front of them, no dead
## (eval = FALSE) sketch and no hidden loader before it, and the first output
## named so they know what they are looking at.  The Get started page and the
## five articles below share one checker; each page gets its own test_that so
## a failure names the page.

## Split a page into its code chunks, in order, with the header flags the
## checks below need.
reader_route_chunks <- function(page) {
  lines <- readLines(page, warn = FALSE)
  starts <- grep("^```\\{r", lines)
  fences <- which(lines == "```")
  chunks <- lapply(starts, function(s) {
    e <- fences[fences > s][1]
    list(header = lines[s], code = lines[s + seq_len(e - s - 1)])
  })
  header <- vapply(chunks, function(ch) ch$header, character(1))
  eval_false <- grepl("eval\\s*=\\s*F(ALSE)?\\b", header)
  hidden <- grepl("include\\s*=\\s*FALSE", header) |
    grepl("echo\\s*=\\s*FALSE", header)
  has <- function(what, fixed = TRUE) {
    vapply(chunks, function(ch) any(grepl(what, ch$code, fixed = fixed)),
           logical(1))
  }
  list(
    lines = lines, chunks = chunks, header = header,
    eval_false = eval_false, hidden = hidden,
    shown = !hidden & !eval_false, has = has
  )
}

## A fit is an assignment from gllvmTMB(); check_gllvmTMB() is not a fit.  A
## chunk that calls a helper defined in an EARLIER chunk whose body calls
## gllvmTMB() is a fit too (one level of indirection): the model-selection
## page fits its candidates through lapply(candidate_d, fit_candidate, ...),
## and a checker that only saw the literal call would audit the wrong chunk.
reader_route_is_fit <- function(pg) {
  direct <- vapply(pg$chunks, function(ch) {
    any(grepl("<-\\s*gllvmTMB\\(", ch$code))
  }, logical(1))
  calls_engine <- vapply(pg$chunks, function(ch) {
    any(grepl("(^|[^A-Za-z0-9_.])gllvmTMB\\(", ch$code))
  }, logical(1))
  helper_names <- lapply(seq_along(pg$chunks), function(i) {
    if (!calls_engine[i]) return(character(0))
    regmatches(
      pg$chunks[[i]]$code,
      regexpr("^[A-Za-z._][A-Za-z0-9._]*(?=\\s*<-\\s*function\\b)",
              pg$chunks[[i]]$code, perl = TRUE)
    )
  })
  via_helper <- vapply(seq_along(pg$chunks), function(i) {
    earlier <- unique(unlist(helper_names[seq_len(i - 1)]))
    if (!length(earlier) || length(helper_names[[i]])) return(FALSE)
    pat <- paste0("(^|[^A-Za-z0-9_.])(", paste(earlier, collapse = "|"),
                  ")(?=[^A-Za-z0-9_.]|$)")
    any(grepl(pat, pg$chunks[[i]]$code, perl = TRUE))
  }, logical(1))
  direct | via_helper
}

## One row per page.  `data_call` is the visible call that puts the fit's
## data in front of the reader, allowed in any visible chunk up to and
## including the fit (pitfalls simulates its data inside the fit chunk).
## `first_output` is the line that reads the first result, in the fit chunk
## or the visible chunk right after it.  `next_guide` says whether the page
## has a "Choose your next guide" section that the limits link must precede.
reader_route_pages <- list(
  list(
    path = file.path("vignettes", "gllvmTMB.Rmd"),
    data_call = "readRDS(",
    first_output = "as.numeric(logLik(fit))",
    next_guide = TRUE
  ),
  list(
    path = file.path("vignettes", "articles", "morphometrics.Rmd"),
    data_call = "readRDS(",
    first_output = "as.numeric(logLik(fit))",
    next_guide = FALSE
  ),
  list(
    path = file.path("vignettes", "articles", "pitfalls.Rmd"),
    data_call = "simulate_site_trait(",
    first_output = "diag_Sigma_hat",
    next_guide = FALSE
  ),
  list(
    path = file.path("vignettes", "articles",
                     "random-regression-reaction-norms.Rmd"),
    data_call = "readRDS(",
    first_output = "logLik(fit_long)",
    next_guide = FALSE
  ),
  list(
    path = file.path("vignettes", "articles",
                     "model-selection-latent-rank.Rmd"),
    data_call = "readRDS(",
    first_output = "rank_table_display",
    next_guide = FALSE
  ),
  list(
    path = file.path("vignettes", "articles", "covariance-correlation.Rmd"),
    data_call = "readRDS(",
    first_output = "logLik(fit_B)",
    next_guide = FALSE
  )
)

for (spec in reader_route_pages) {
  testthat::test_that(paste(spec$path, "opens with a complete runnable route"), {
    testthat::skip_on_cran()

    root <- testthat::test_path("..", "..")
    page <- file.path(root, spec$path)
    testthat::skip_if_not(file.exists(page), "not a source checkout")

    pg <- reader_route_chunks(page)
    is_fit <- reader_route_is_fit(pg)
    first_fit <- which(is_fit & !pg$eval_false)[1]
    testthat::expect_true(
      length(first_fit) == 1 && !is.na(first_fit),
      info = paste(spec$path, ": a runnable gllvmTMB() call exists")
    )
    if (is.na(first_fit)) return(invisible(NULL))
    before <- seq_len(first_fit - 1)
    upto <- seq_len(first_fit)
    shown <- pg$shown
    has <- pg$has

    ## (a) the first fit is on the page, not run behind the reader's back.
    testthat::expect_false(
      pg$hidden[first_fit],
      info = paste(spec$path, ": first fit is visible")
    )
    ## (b) the package is loaded in front of the reader before the fit.
    testthat::expect_true(
      any(shown[before] & has("library(gllvmTMB)")[before]),
      info = paste(spec$path, ": visible library(gllvmTMB) precedes the first fit")
    )
    ## (c) the data the fit uses are put in front of the reader.
    testthat::expect_true(
      any(shown[upto] & has(spec$data_call)[upto]),
      info = paste0(spec$path, ": visible, evaluated ", spec$data_call,
                    ") reaches the first fit")
    )
    ## (d) nothing the reader cannot run comes before the first fit.
    testthat::expect_false(
      any(pg$eval_false[before]),
      info = paste(spec$path, ": no non-runnable sketch precedes the first fit")
    )
    ## (e) the first output is named and read, in the fit chunk or the visible
    ##     chunk right after it.
    after <- if (first_fit < length(pg$chunks)) first_fit + 1L else integer(0)
    read_at <- c(first_fit, after)
    testthat::expect_true(
      any(shown[read_at] & has(spec$first_output)[read_at]),
      info = paste0(spec$path, ": first fit reads ", spec$first_output)
    )
    ## (f) the limits page is pointed to before the reader is sent onward.
    ##     Only Get started carries a next-guide section; on the articles the
    ##     check is that the section is indeed absent, so the row's flag
    ##     cannot silently skip a page that later gains one.
    onward_at <- grep("^## Choose your next guide", pg$lines)[1]
    if (isTRUE(spec$next_guide)) {
      limits_at <- grep("current-limits.html", pg$lines, fixed = TRUE)[1]
      testthat::expect_true(
        !is.na(limits_at) && !is.na(onward_at) && limits_at < onward_at,
        info = paste(spec$path,
                     ": current-limits link precedes the next-guide section")
      )
    } else {
      testthat::expect_true(
        is.na(onward_at),
        info = paste(spec$path,
                     ": has no next-guide section, so (f) is not checked here")
      )
    }
    ## (g) no data are loaded behind the reader's back before the first fit:
    ##     the visible route must not depend on a hidden loader.
    testthat::expect_false(
      any(pg$hidden[before] & has("readRDS(")[before]),
      info = paste(spec$path, ": no hidden readRDS() precedes the first fit")
    )
    ## (h) no fit-shaped sketch appears before the package is even shown
    ##     loaded (a sketch that uses data and a package the reader has not
    ##     yet met).
    lib_at <- which(shown & has("library(gllvmTMB)"))[1]
    sketch_fit <- pg$eval_false & has("gllvmTMB(")
    testthat::expect_false(
      !is.na(lib_at) && any(sketch_fit[seq_len(lib_at - 1)]),
      info = paste(spec$path,
                   ": no eval = FALSE gllvmTMB() sketch precedes library(gllvmTMB)")
    )
  })
}
