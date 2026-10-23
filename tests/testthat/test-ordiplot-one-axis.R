# Real base graphics with controlled extraction isolates plotting from fitting.
one_axis_ordiplot <- function(scores, loadings) {
  method <- getS3method("ordiplot", "gllvmTMB_multi")
  env <- new.env(parent = environment(method))
  env$getLV <- function(...) scores
  env$getLoadings <- function(...) loadings
  environment(method) <- env
  method
}

test_that("one-axis ordiplot preserves scores and loadings on a real device", {
  scores <- matrix(c(-1, 0.3, 1), ncol = 1, dimnames = list(NULL, "LV1"))
  loadings <- matrix(c(-0.4, 0.7), ncol = 1,
                     dimnames = list(c("a", "b"), "LV1"))
  draw <- one_axis_ordiplot(scores, loadings)
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit({ grDevices::dev.off(); unlink(path) }, add = TRUE)
  out <- withVisible(draw(list()))
  expect_false(out$visible)
  expect_identical(out$value, list(scores = scores, loadings = loadings))
  expect_no_error(draw(list(), axes = 1L, biplot = FALSE))
  expect_error(draw(list(), axes = c(1, 2)), "Not enough latent axes")
  expect_error(draw(list(), axes = 2L), "Not enough latent axes")
  expect_error(draw(list(), ellipse = TRUE),
               class = "gllvmTMB_ordiplot_ellipse_one_axis_unsupported")
  grDevices::dev.off()
  on.exit(unlink(path))
  expect_gt(file.info(path)$size, 0)
})

test_that("ordiplot rejects malformed axes before extracting or drawing", {
  draw <- one_axis_ordiplot(matrix(1:3, ncol = 1), NULL)
  for (axes in list(integer(), c(1, 2, 3), NA_real_, Inf, 0, -1,
                    1.5, c(1, 1), "1", TRUE)) {
    expect_error(draw(list(), axes = axes), "distinct positive integer")
  }
})

test_that("two-axis ordiplot retains its default and permits a single axis", {
  scores <- matrix(c(-1, 0.2, 1, 0.5, -0.3, 0.8), ncol = 2)
  loadings <- matrix(c(-0.4, 0.7, 0.1, -0.2), ncol = 2,
                     dimnames = list(c("a", "b"), NULL))
  draw <- one_axis_ordiplot(scores, loadings)
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit({ grDevices::dev.off(); unlink(path) }, add = TRUE)
  expect_identical(draw(list()), list(scores = scores, loadings = loadings))
  expect_no_error(draw(list(), axes = c(2L, 1L)))
  expect_no_error(draw(list(), axes = 2L))
})
