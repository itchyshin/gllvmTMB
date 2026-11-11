## #1772: the latent-d teaching-vignette scan must skip (not error) when
## vignettes/articles/ is absent from the check tree.

test_that("latent-d teaching vignette resolver finds sources in a checkout (#1772)", {
  p <- gllvmTMB_vignette_source_path(
    file.path("articles", "covariance-correlation.Rmd")
  )
  skip_if_not(
    !is.na(p) && file.exists(p),
    "covariance-correlation.Rmd not in this checkout"
  )
  expect_true(grepl("covariance-correlation\\.Rmd$", p))
})

test_that("latent-d teaching vignettes gate skips when article sources are absent (#1772)", {
  withr::local_dir(withr::local_tempdir())
  check_root <- "pkg.Rcheck"
  testthat_dir <- file.path(check_root, "tests", "testthat")
  dir.create(testthat_dir, recursive = TRUE)
  vignette_dir <- file.path(check_root, "vignettes")
  dir.create(vignette_dir, recursive = TRUE)
  writeLines("# dummy", file.path(vignette_dir, "gllvmTMB.Rmd"))
  withr::local_dir(testthat_dir)
  paths <- gllvmTMB_latent_d_teaching_vignette_paths(
    c(
      "gllvmTMB.Rmd",
      file.path("articles", "covariance-correlation.Rmd")
    )
  )
  expect_identical(paths[["gllvmTMB.Rmd"]], file.path("..", "..", "vignettes", "gllvmTMB.Rmd"))
  expect_true(is.na(paths[[file.path("articles", "covariance-correlation.Rmd")]]))
  expect_condition(
    gllvmTMB_skip_if_latent_d_teaching_vignettes_absent(),
    class = "skip"
  )
})
