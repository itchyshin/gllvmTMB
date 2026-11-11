## #1770: the latent-d teaching-article scan must skip (not error) when
## vignettes/articles/ is absent from the check tree. The main vignette
## gllvmTMB.Rmd is in the tarball and must still be scanned.
##
## These tests plant a two-level 00_pkg_src tarball layout and call the
## skip gate against that tree. They fail on the pre-fix scan: main used
## per-file skip_if_not(..., "not a source checkout"), and #1772's
## gllvmTMB_pkg_file() errors when the article is missing. The original
## expect_match checks in test-latent-d-identifiable-range-doc.R are
## unchanged and still run when the vignettes are present.

.fix1770_tarball_testthat <- function(with_articles) {
  root <- tempfile("gllvmTMB-rcheck-vignette-")
  testthat_dir <- file.path(root, "tests", "testthat")
  dir.create(testthat_dir, recursive = TRUE)
  vig <- file.path(root, "00_pkg_src", "gllvmTMB", "vignettes")
  dir.create(vig, recursive = TRUE)
  writeLines("# dummy main vignette", file.path(vig, "gllvmTMB.Rmd"))
  if (isTRUE(with_articles)) {
    art <- file.path(vig, "articles")
    dir.create(art, recursive = TRUE)
    writeLines("# dummy", file.path(art, "covariance-correlation.Rmd"))
    writeLines("# dummy", file.path(art, "model-selection-latent-rank.Rmd"))
  }
  list(root = root, testthat = testthat_dir)
}

test_that("teaching-vignette gate skips when pkgdown articles are absent (#1770)", {
  planted <- .fix1770_tarball_testthat(with_articles = FALSE)
  on.exit(unlink(planted$root, recursive = TRUE), add = TRUE)

  vigs <- c(
    "gllvmTMB.Rmd",
    file.path("articles", "covariance-correlation.Rmd"),
    file.path("articles", "model-selection-latent-rank.Rmd")
  )
  paths <- gllvmTMB_latent_d_teaching_vignette_paths_from(planted$testthat, vigs)
  expect_true(file.exists(paths[["gllvmTMB.Rmd"]]))
  expect_true(is.na(paths[[file.path("articles", "covariance-correlation.Rmd")]]))
  expect_true(is.na(paths[[file.path("articles", "model-selection-latent-rank.Rmd")]]))

  cnd <- expect_condition(
    gllvmTMB_skip_if_latent_d_teaching_vignettes_absent(planted$testthat),
    class = "skip"
  )
  expect_match(conditionMessage(cnd), "pkgdown article vignettes", fixed = TRUE)
  expect_false(grepl("not a source checkout", conditionMessage(cnd), fixed = TRUE))
})

test_that("teaching-vignette gate does not skip when all three sources exist (#1770)", {
  planted <- .fix1770_tarball_testthat(with_articles = TRUE)
  on.exit(unlink(planted$root, recursive = TRUE), add = TRUE)
  paths <- gllvmTMB_skip_if_latent_d_teaching_vignettes_absent(planted$testthat)
  expect_length(paths, 3L)
  expect_true(all(!is.na(paths)))
  expect_true(all(file.exists(unname(paths))))
})

test_that("main-vignette identifiable-range scan is not skipped when only articles are absent (#1770)", {
  planted <- .fix1770_tarball_testthat(with_articles = FALSE)
  on.exit(unlink(planted$root, recursive = TRUE), add = TRUE)

  v <- "gllvmTMB.Rmd"
  p <- gllvmTMB_vignette_source_path_from(planted$testthat, v)
  expect_false(is.na(p))
  writeLines(c("(T - d)^2 \\ge T + d", "d <= n_traits"), p)
  txt <- gsub("\\s+", " ", paste(readLines(p, warn = FALSE), collapse = " "))
  expect_match(txt, "(T - d)^2 \\ge T + d", fixed = TRUE, info = v)
  expect_match(txt, "d <= n_traits", fixed = TRUE, info = v)

  expect_condition(
    gllvmTMB_skip_if_latent_d_teaching_vignettes_absent(planted$testthat),
    class = "skip"
  )
})
