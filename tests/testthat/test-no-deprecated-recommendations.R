## User-facing messages are a reader surface: a hint that tells someone to reach
## for a soft-deprecated feature is the same defect as an article teaching it.
## This scans string literals only -- parse() discards comments, so an internal
## code comment mentioning the deprecated mechanism is correctly ignored.

r_dir <- testthat::test_path("..", "..", "R")

string_literals <- function(path) {
  expr <- tryCatch(parse(path), error = function(e) NULL)
  if (is.null(expr)) return(character())
  out <- character()
  walk <- function(x) {
    if (is.expression(x)) {
      for (e in as.list(x)) walk(e)
      return(invisible(NULL))
    }
    if (is.character(x)) {
      out <<- c(out, x)
      return(invisible(NULL))
    }
    if (is.call(x)) {
      parts <- as.list(x)
      ## Missing-argument slots are the empty symbol, which errors when forced.
      for (i in seq_along(parts)) try(walk(parts[[i]]), silent = TRUE)
    }
    invisible(NULL)
  }
  walk(expr)
  out
}

test_that("no user-facing message recommends the soft-deprecated residual start", {
  testthat::skip_if_not(dir.exists(r_dir), "R/ not present")

  offenders <- character()
  for (f in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
    lits <- string_literals(f)
    hits <- grep("residual start", lits, ignore.case = TRUE, value = TRUE)
    ## A message that names the deprecation is fine -- it is the recommendation
    ## that is the defect.
    hits <- hits[!grepl("deprecat", hits, ignore.case = TRUE)]
    if (length(hits)) {
      offenders <- c(offenders, sprintf("%s: %s", basename(f), substr(hits, 1, 60)))
    }
  }
  expect_equal(offenders, character())
})

test_that("no user-facing message recommends a numeric aghq_ridge over loading_ridge", {
  testthat::skip_if_not(dir.exists(r_dir), "R/ not present")

  ## `loading_ridge` is the integration-neutral spelling for a runaway-loading
  ## fix (#gapclose task d); `aghq_ridge = <number>` recommendations should
  ## have moved to it. `aghq_ridge = "auto"` and `aghq_ridge = Inf` are left
  ## alone -- those are AGHQ-specific ladder/likelihood-comparison meanings
  ## that `loading_ridge` does not carry.
  offenders <- character()
  for (f in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
    lits <- string_literals(f)
    hits <- grep("aghq_ridge\\s*=\\s*[0-9]", lits, value = TRUE)
    if (length(hits)) {
      offenders <- c(offenders, sprintf("%s: %s", basename(f), substr(hits, 1, 60)))
    }
  }
  expect_equal(offenders, character())
})

## Keyword help pages are a reader surface too (#1560): the description lines
## must not teach the `d = T` shorthand, say `gr(cov =)` is unused, or call the
## soft-deprecated scalar keywords "Canonical".
test_that("keyword help pages carry no stale recommendations (#1560)", {
  man_dir <- testthat::test_path("..", "..", "man")
  testthat::skip_if_not(dir.exists(man_dir), "man/ not present")
  rd_text <- function(topic) {
    path <- file.path(man_dir, paste0(topic, ".Rd"))
    testthat::skip_if_not(file.exists(path), paste(topic, "Rd not present"))
    txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
    ## Description lines only: @examples are owned by the #1346 example lane.
    sub("[\\\\]examples[{].*", "", txt)
  }

  ## `d = T` is not a valid argument value; say what it means.
  for (topic in c("dep", "phylo_dep", "spatial_dep")) {
    expect_false(grepl("d = T\\b", rd_text(topic)), info = topic)
  }
  expect_match(rd_text("dep"), "d = n_traits, unique = FALSE", fixed = TRUE)

  ## gr(cov =) is consumed when no top-level phylo_vcv is supplied.
  gr_rd <- rd_text("gr")
  expect_false(grepl("not\\} used by the engine|\\bignored by the engine",
                     gr_rd))
  expect_match(gr_rd, "phylo_vcv", fixed = TRUE)
  expect_match(gr_rd, "ignored", fixed = TRUE)

  ## Soft-deprecated scalar keywords are not "Canonical".
  for (topic in c("scalar", "phylo_scalar")) {
    txt <- rd_text(topic)
    expect_false(grepl("Canonical (no-prefix )?name", txt), info = topic)
    expect_match(txt, "soft-deprecated", ignore.case = TRUE, info = topic)
    expect_match(txt, "common = TRUE", fixed = TRUE, info = topic)
  }
})
