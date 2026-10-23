## GUARD: every path-like token cited in the validation-debt register's
## "evidence" column must exist in the repository.
##
## docs/design/35-validation-debt-register.md is a large set of markdown
## tables; each row's evidence column cites test files, articles, or dev-log
## files as the proof for a `covered` / `partial` status. A citation that
## silently rots (the file is renamed, cut, or was never committed) leaves a
## claim nobody can verify. This test parses every table in the register,
## finds the evidence column by header name (tables in this file use
## slightly different header wording), extracts path-like tokens from it, and
## checks each one exists relative to the package root.
##
## Only the EVIDENCE column is checked. Free-text "Notes" prose is not
## scanned -- a Notes sentence explaining that some other path does NOT exist
## (as several rows now do, deliberately) would otherwise trip this guard on
## its own honesty note.

testthat::test_that("validation-debt register evidence-column paths exist", {
  root <- testthat::test_path("..", "..")
  register <- file.path(root, "docs", "design", "35-validation-debt-register.md")
  testthat::skip_if_not(file.exists(register), "register file not found (not a source checkout)")

  lines <- readLines(register, warn = FALSE, encoding = "UTF-8")

  ## Split a "| a | b | c |" row into trimmed cells, dropping the empty
  ## leading/trailing elements produced by the boundary "|" characters.
  split_row <- function(line) {
    cells <- strsplit(line, "\\|", perl = TRUE)[[1]]
    cells <- trimws(cells)
    if (length(cells) >= 1L && identical(cells[1], "")) cells <- cells[-1]
    if (length(cells) >= 1L && identical(cells[length(cells)], "")) {
      cells <- cells[-length(cells)]
    }
    cells
  }

  evidence_header_names <- c("test evidence", "evidence", "evidence and remaining debt")
  ## A trailing brace group (e.g. "...adjudication.{csv,dcf,md}") is a shell-
  ## style shorthand for several sibling files sharing one base name; capture
  ## it so it can be expanded below instead of being treated as one bad path.
  path_pattern <- paste0(
    "(?:tests/testthat|vignettes|docs|dev)/[A-Za-z0-9_.\\-]+",
    "(?:/[A-Za-z0-9_.\\-]+)*(?:\\{[^}]*\\})?"
  )

  evidence_col <- NA_integer_
  offenders <- character(0)
  n_rows_checked <- 0L

  for (line in lines) {
    if (!grepl("^\\s*\\|", line)) {
      evidence_col <- NA_integer_ ## left whatever table we were in
      next
    }
    cells <- split_row(line)
    if (length(cells) == 0L) next

    ## Table separator row, e.g. "----|----|----" or ":---|---:".
    if (all(grepl("^:?-+:?$", cells))) next

    header_names <- tolower(cells)
    if ("id" %in% header_names) {
      candidate <- which(header_names %in% evidence_header_names)
      evidence_col <- if (length(candidate) == 1L) candidate else NA_integer_
      next
    }

    if (is.na(evidence_col) || evidence_col > length(cells)) next

    n_rows_checked <- n_rows_checked + 1L
    evidence_text <- cells[evidence_col]

    m <- gregexpr(path_pattern, evidence_text, perl = TRUE)
    tokens <- regmatches(evidence_text, m)[[1]]
    for (tok in tokens) {
      if (grepl("\\{[^}]*\\}$", tok)) {
        ## Expand "base.{a,b,c}" into base.a, base.b, base.c.
        base <- sub("\\{[^}]*\\}$", "", tok)
        alts <- strsplit(sub(".*\\{([^}]*)\\}$", "\\1", tok), ",")[[1]]
        candidates <- paste0(base, trimws(alts))
      } else {
        candidates <- tok
      }
      for (cand in candidates) {
        ## Strip trailing sentence punctuation a bare regex match can pick up
        ## (a path immediately followed by "." / "," / ";" / ")" with no space).
        tok_clean <- sub("[.,;:)]+$", "", cand)
        full <- file.path(root, tok_clean)
        if (!file.exists(full) && !dir.exists(full)) {
          offenders <- c(offenders, sprintf("`%s` (id %s)", tok_clean, cells[1]))
        }
      }
    }
  }

  testthat::expect_gt(
    n_rows_checked, 0L,
    label = "register rows found by the table parser"
  )

  testthat::expect_true(
    length(offenders) == 0L,
    info = paste0(
      "The validation-debt register's evidence column cites ", length(offenders),
      " path(s) that do not exist in this checkout:\n",
      paste(unique(offenders), collapse = "\n")
    )
  )
})
