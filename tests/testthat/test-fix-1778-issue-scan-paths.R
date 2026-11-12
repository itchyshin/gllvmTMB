## Regression guard for #1778.
##
## On main, test-issue-1327-get-started-visible-objects.R and
## test-issue-1328-first-fit-messages.R read README.md and
## vignettes/gllvmTMB.Rmd via test_path("..", "..", ...) and skip when
## that path is missing. Under R CMD check the sources live in
## ../../00_pkg_src/gllvmTMB/, so those scans skip silently (#1770 class).

.fix1778_plant_two_level <- function() {
  root <- tempfile("gllvmTMB-rcheck-1778-")
  testthat_dir <- file.path(root, "tests", "testthat")
  dir.create(testthat_dir, recursive = TRUE)
  pkg <- file.path(root, "00_pkg_src", "gllvmTMB")
  rels <- c("README.md", "vignettes/gllvmTMB.Rmd")
  for (rel in rels) {
    dest <- file.path(pkg, rel)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    writeLines(paste0("sentinel-1778-", basename(rel)), dest)
  }
  list(root = root, testthat = testthat_dir)
}

test_that("README and get-started vignette resolve under two-level 00_pkg_src (#1778)", {
  planted <- .fix1778_plant_two_level()
  on.exit(unlink(planted$root, recursive = TRUE), add = TRUE)

  rels <- list(
    c("README.md"),
    c("vignettes", "gllvmTMB.Rmd")
  )
  for (parts in rels) {
    legacy <- do.call(file.path, c(list(planted$testthat, "..", ".."), parts))
    expect_false(file.exists(legacy), info = paste(parts, collapse = "/"))
    found <- do.call(gllvmTMB_pkg_file_from, c(list(planted$testthat), parts))
    expect_true(file.exists(found), info = paste(parts, collapse = "/"))
    expect_match(readLines(found, warn = FALSE, n = 1L), "sentinel-1778")
  }
})

test_that("live #1327/#1328 scans resolve package sources in this context (#1778)", {
  expect_true(file.exists(gllvmTMB_pkg_file("vignettes", "gllvmTMB.Rmd")))
  expect_true(file.exists(gllvmTMB_pkg_file("README.md")))
})

test_that("#1327/#1328 scans no longer skip on a missing dev-tree path (#1778)", {
  banned <- c(
    "test-issue-1327-get-started-visible-objects.R" =
      "skip_if_not(file.exists(rmd)",
    "test-issue-1328-first-fit-messages.R" =
      "skip_if_not(file.exists"
  )
  for (file in names(banned)) {
    txt <- paste(readLines(testthat::test_path(file), warn = FALSE), collapse = "\n")
    expect_false(grepl(banned[[file]], txt, fixed = TRUE), info = file)
  }
})
