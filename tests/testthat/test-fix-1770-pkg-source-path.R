## Regression guard for #1770.
##
## On main before this fix, source scans used test_path("..", "..", rel)
## and skip_if*() when that file was missing. R CMD check places sources
## at ../../00_pkg_src/gllvmTMB/<rel> (two levels up from testthat), so
## those scans skipped. This file fails against that main tree: the old
## skip strings are still in the scan files, and gllvmTMB_pkg_file_from()
## does not exist. It passes once the shared resolver covers the dev,
## two-level, and three-level roots and the scans error instead of skipping.

.fix1770_touch <- function(root, rel) {
  dest <- file.path(root, rel)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  writeLines("sentinel-1770", dest)
  dest
}

.fix1770_two_level <- function() {
  root <- tempfile("gllvmTMB-rcheck-two-")
  dir.create(file.path(root, "tests", "testthat"), recursive = TRUE)
  pkg <- file.path(root, "00_pkg_src", "gllvmTMB")
  rels <- c(
    "src/gllvmTMB.cpp",
    "src/gllvmTMB_cloglog.h",
    "R/fit-multi.R",
    "R/brms-sugar.R",
    "R/mspl.R",
    "R/enum.R",
    "R/methods-gllvmTMB.R",
    "man/latent.Rd",
    "vignettes/gllvmTMB.Rmd",
    "inst/tmb/gllvmTMB_va_r3.cpp",
    "DESCRIPTION"
  )
  for (rel in rels) .fix1770_touch(pkg, rel)
  list(root = root, testthat = file.path(root, "tests", "testthat"), rels = rels)
}

.fix1770_three_level <- function() {
  root <- tempfile("gllvmTMB-rcheck-three-")
  dir.create(file.path(root, "gllvmTMB", "tests", "testthat"), recursive = TRUE)
  rels <- c("src/gllvmTMB.cpp", "R/fit-multi.R", "man/latent.Rd")
  for (rel in rels) {
    .fix1770_touch(file.path(root, "00_pkg_src", "gllvmTMB"), rel)
  }
  list(
    root = root,
    testthat = file.path(root, "gllvmTMB", "tests", "testthat"),
    rels = rels
  )
}

test_that("two-level 00_pkg_src is invisible to the legacy ../../ lookup (#1770)", {
  planted <- .fix1770_two_level()
  on.exit(unlink(planted$root, recursive = TRUE), add = TRUE)
  for (rel in planted$rels) {
    legacy <- file.path(planted$testthat, "..", "..", rel)
    expect_false(file.exists(legacy), info = rel)
    three_only <- file.path(
      planted$testthat, "..", "..", "..", "00_pkg_src", "gllvmTMB", rel
    )
    expect_false(file.exists(three_only), info = rel)
    found <- gllvmTMB_pkg_file_from(planted$testthat, rel)
    expect_true(file.exists(found), info = rel)
    expect_identical(readLines(found, warn = FALSE), "sentinel-1770")
  }
})

test_that("three-level 00_pkg_src is found when tests sit in the installed package (#1770)", {
  planted <- .fix1770_three_level()
  on.exit(unlink(planted$root, recursive = TRUE), add = TRUE)
  for (rel in planted$rels) {
    legacy <- file.path(planted$testthat, "..", "..", rel)
    two_only <- file.path(
      planted$testthat, "..", "..", "00_pkg_src", "gllvmTMB", rel
    )
    expect_false(file.exists(legacy), info = rel)
    expect_false(file.exists(two_only), info = rel)
    found <- gllvmTMB_pkg_file_from(planted$testthat, rel)
    expect_true(file.exists(found), info = rel)
  }
})

test_that("dev checkout root stays the first hit (#1770)", {
  root <- tempfile("gllvmTMB-dev-")
  testthat_dir <- file.path(root, "tests", "testthat")
  dir.create(testthat_dir, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  .fix1770_touch(root, "src/gllvmTMB.cpp")
  ## A decoy two-level tree must not win while the dev root exists.
  .fix1770_touch(file.path(root, "00_pkg_src", "gllvmTMB"), "src/gllvmTMB.cpp")
  writeLines("dev-copy", file.path(root, "src", "gllvmTMB.cpp"))
  found <- gllvmTMB_pkg_file_from(testthat_dir, "src", "gllvmTMB.cpp")
  expect_identical(readLines(found, warn = FALSE), "dev-copy")
})

test_that("a missing package file errors instead of being skippable (#1770)", {
  planted <- .fix1770_two_level()
  on.exit(unlink(planted$root, recursive = TRUE), add = TRUE)
  expect_error(
    gllvmTMB_pkg_file_from(
      planted$testthat, "vignettes", "articles", "not-shipped-1770.Rmd"
    ),
    "not available",
    fixed = TRUE
  )
  expect_error(
    gllvmTMB_pkg_file("R", "no-such-file-1770.R"),
    "not available",
    fixed = TRUE
  )
})

test_that("live candidates list both 00_pkg_src depths for every scanned root (#1770)", {
  rels <- list(
    c("src", "gllvmTMB.cpp"),
    c("R", "fit-multi.R"),
    c("man", "latent.Rd"),
    c("vignettes", "gllvmTMB.Rmd"),
    c("inst", "tmb", "gllvmTMB_va_r3.cpp")
  )
  for (rel in rels) {
    parts <- as.list(rel)
    candidates <- do.call(gllvmTMB_pkg_file_candidates, parts)
    two <- do.call(
      testthat::test_path,
      c(list("..", "..", "00_pkg_src", "gllvmTMB"), parts)
    )
    three <- do.call(
      testthat::test_path,
      c(list("..", "..", "..", "00_pkg_src", "gllvmTMB"), parts)
    )
    expect_true(two %in% candidates, info = paste(rel, collapse = "/"))
    expect_true(three %in% candidates, info = paste(rel, collapse = "/"))
    expect_true(file.exists(do.call(gllvmTMB_pkg_file, parts)))
  }
})

test_that("source scans no longer skip when the package file is missing (#1770)", {
  ## These strings are the silent R CMD check skips on main. They have to
  ## stay gone: putting one back makes this test fail.
  banned <- c(
    "test-beta-response-support.R" =
      "skip_if_not(file.exists(src))",
    "test-zz-mspl-fenced-family-tapes.R" =
      "fit-multi.R not in this test context",
    "test-issue-1484-ordinal-floor-documented.R" =
      "src/gllvmTMB.cpp not available (installed package)",
    "test-mspl-no-console-output.R" =
      "package sources not available",
    "test-bfgs-compiled-objectives.R" =
      "production cloglog header unavailable",
    "test-g2n-compiled-cloglog-unit.R" =
      "production cloglog header unavailable",
    "test-g3-compiled-cloglog-unit.R" =
      "production cloglog header unavailable",
    "test-loading-unpack-contract.R" =
      "Repository-only source provenance scan is unavailable after installation",
    "test-issue-1407-sigma.R" =
      "package source not available",
    "test-control-field-surface.R" =
      "Repository source is unavailable after package installation",
    "test-latent-d-identifiable-range-doc.R" =
      "not a source checkout",
    "test-no-deprecated-recommendations.R" =
      "R/ not present",
    "test-julia-methods-rd-arguments.R" =
      "skip_if_not(file.exists",
    "test-profile-targets-transformation-docs.R" =
      "man/profile_targets.Rd missing",
    "test-tmbprofile-wrapper-return-docs.R" =
      "man/tmbprofile_wrapper.Rd missing",
    "test-rotate-compare-loadings.R" =
      "man/ not available",
    "test-mspl-nb2-fenced-tape.R" =
      "gllvmTMB.cpp source file is not available in this test context.",
    "test-mspl-W-onesided-oracles.R" =
      "gllvmTMB.cpp source file is not available in this test context.",
    "test-mspl-poisson-phase4-oracles.R" =
      "installed-package test context"
  )
  for (file in names(banned)) {
    txt <- paste(readLines(testthat::test_path(file), warn = FALSE), collapse = "\n")
    expect_false(grepl(banned[[file]], txt, fixed = TRUE), info = file)
  }
})
