## Issue #1327: copy-pasteable get-started chunks must define objects they use later.

test_that("gllvmTMB.Rmd defines n_traits and Lambda_true outside hidden chunks", {
  rmd <- testthat::test_path("..", "..", "vignettes", "gllvmTMB.Rmd")
  testthat::skip_if_not(file.exists(rmd), "get-started vignette missing")

  lines <- readLines(rmd, warn = FALSE)
  chunk_starts <- grep("^```\\{r", lines)
  chunk_ends <- grep("^```\\s*$", lines)

  chunk_header <- function(start_line) lines[[start_line]]

  chunk_is_hidden <- function(start_line) {
    hdr <- chunk_header(start_line)
    grepl("include\\s*=\\s*FALSE", hdr, ignore.case = TRUE) ||
      grepl("echo\\s*=\\s*FALSE", hdr, ignore.case = TRUE)
  }

  chunk_body <- function(start_line) {
    close <- chunk_ends[chunk_ends > start_line][[1L]]
    lines[seq.int(start_line + 1L, close - 1L)]
  }

  def_pat <- "(n_traits|Lambda_true)\\s*<-"
  visible_has <- c(n_traits = FALSE, Lambda_true = FALSE)

  for (start in chunk_starts) {
    body <- chunk_body(start)
    defs_here <- grepl(def_pat, body)
    if (!any(defs_here)) next

    testthat::expect_false(
      chunk_is_hidden(start),
      info = sprintf(
        "Line %d: %s must not be assigned inside include=FALSE or echo=FALSE chunks",
        start,
        paste(unique(sub(".*(n_traits|Lambda_true).*", "\\1", body[defs_here])), collapse = ", ")
      )
    )

    if (!chunk_is_hidden(start)) {
      if (any(grepl("n_traits\\s*<-", body))) visible_has[["n_traits"]] <- TRUE
      if (any(grepl("Lambda_true\\s*<-", body))) visible_has[["Lambda_true"]] <- TRUE
    }
  }

  testthat::expect_true(all(visible_has), info = paste(names(visible_has)[!visible_has], "missing from visible chunks"))
})
