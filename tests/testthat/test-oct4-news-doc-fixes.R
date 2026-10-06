## Pin the Oct4 NEWS / Rd wording fixes (#1382, #1422, #1423, #1427, #1428).
## These tickets had no test file; a silent revert would put the old wrong
## sentences back. Each test reads the file that changed and asserts the
## wording now in the tree.
##
## R CMD check runs tests from <pkg>.Rcheck/tests/testthat.  ../../man and
## ../../R are the check tree, not the source package, so those naive paths
## fail with "cannot open the connection".  The tarball copy lives at
## ../../00_pkg_src/gllvmTMB/ (same layout as test-isdm-developer-fit.R).

.pkg_source_file <- function(...) {
  rel <- do.call(file.path, list(...))
  candidates <- c(
    testthat::test_path("..", "..", rel),
    testthat::test_path("..", "..", "00_pkg_src", "gllvmTMB", rel),
    testthat::test_path("..", "..", "..", "00_pkg_src", "gllvmTMB", rel)
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    return(NA_character_)
  }
  found[[1L]]
}

.oct4_read <- function(...) {
  path <- .pkg_source_file(...)
  testthat::skip_if_not(
    is.character(path) && !is.na(path) && file.exists(path),
    paste("missing", file.path(...))
  )
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

test_that("#1382 ?bootstrap_Sigma says a too-small n_boot triggers a warning and the fit still runs", {
  rd <- .oct4_read("man", "bootstrap_Sigma.Rd")
  r <- .oct4_read("R", "bootstrap-sigma.R")
  expect_match(rd, "trigger\na warning:", perl = TRUE)
  expect_match(rd, "The fit still runs.", fixed = TRUE)
  expect_match(r, "trigger\n#'   a warning:", perl = TRUE)
  expect_match(r, "The fit still runs.", fixed = TRUE)
  expect_false(grepl("are refused:", rd, fixed = TRUE))
  expect_false(grepl("are refused:", r, fixed = TRUE))
})

test_that("#1422 NEWS uses suggest_lambda_constraint(convention = ...) and extractor nsim = 500", {
  news <- .oct4_read("NEWS.md")
  expect_match(
    news,
    "suggest_lambda_constraint(convention = \"wald_retention\")",
    fixed = TRUE
  )
  expect_match(
    news,
    "suggest_lambda_constraint(convention = \"varimax_threshold\")",
    fixed = TRUE
  )
  expect_match(news, "still default to **`nsim = 500`** unless you pass", fixed = TRUE)
  expect_false(grepl(
    "suggest_lambda_constraint(method = \"wald_retention\")",
    news,
    fixed = TRUE
  ))
  expect_false(grepl(
    "every bootstrap interval in the package now uses one replicate count",
    news,
    fixed = TRUE
  ))
})

test_that("#1423 no predict(scale/poly/ns) sentence landed; pin the bootstrap default-scope NEWS hunk", {
  ## #1423 is a predict(newdata) engine ticket. origin/main...HEAD on this
  ## branch only touches NEWS.md, R/bootstrap-sigma.R, and
  ## man/bootstrap_Sigma.Rd. The remaining checkable hunk from that commit
  ## is the rewritten bootstrap default-scope sentence.
  news <- .oct4_read("NEWS.md")
  expect_match(
    news,
    "That is the only exported function whose bootstrap argument default changed.",
    fixed = TRUE
  )
  expect_match(
    news,
    "`bootstrap_Sigma()` default `n_boot` is now 999, raised from 200.",
    fixed = TRUE
  )
})

test_that("#1427 NEWS 0.2.0 records the latent() Psi default and the soft-deprecations", {
  news <- .oct4_read("NEWS.md")
  section <- sub(".*\n# gllvmTMB 0.2.0\n", "", news)
  expect_true(nzchar(section))
  expect_match(
    section,
    "**Ordinary `latent()` now includes a per-trait `Psi` by default**",
    fixed = TRUE
  )
  expect_match(
    section,
    "**The `residual` argument on `latent()` was renamed to `unique`.**",
    fixed = TRUE
  )
  expect_match(
    section,
    "**`unique()` and source-specific `*_unique()` are soft-deprecated**",
    fixed = TRUE
  )
  expect_match(section, "**`gllvmTMB_wide()` is soft-deprecated.**", fixed = TRUE)
  expect_match(
    section,
    "**`meta_known_V()` is a deprecated alias of `meta_V()`.**",
    fixed = TRUE
  )
})

test_that("#1428 NEWS and ?bootstrap_Sigma say n_boot below the floor warns, not refuses", {
  news <- .oct4_read("NEWS.md")
  rd <- .oct4_read("man", "bootstrap_Sigma.Rd")
  r <- .oct4_read("R", "bootstrap-sigma.R")
  expect_match(
    news,
    "`bootstrap_Sigma()` **warns** when `n_boot` is below the arithmetic floor or",
    fixed = TRUE
  )
  expect_match(rd, "Below the arithmetic floor the \\emph{arithmetic ceiling} binds", fixed = TRUE)
  expect_match(r, "Below the arithmetic floor the *arithmetic ceiling* binds", fixed = TRUE)
  expect_false(grepl("refuses an `n_boot`", news, fixed = TRUE))
  expect_false(grepl("refusal threshold", rd, fixed = TRUE))
  expect_false(grepl("refusal threshold", r, fixed = TRUE))
})
