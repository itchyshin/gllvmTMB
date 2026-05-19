source_m3_grid <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(
    file.path("dev", "m3-grid.R"),
    file.path("..", "..", "dev", "m3-grid.R"),
    if (!is.na(workspace)) file.path(workspace, "dev", "m3-grid.R")
  )
  dev_file <- candidates[file.exists(candidates)][1]
  testthat::skip_if(
    is.na(dev_file),
    "dev/m3-grid.R is unavailable in this source-tarball context"
  )
  source(dev_file, local = parent.frame())
}

test_that("M3 grid summary counts failed replicates before coverage filtering", {
  source_m3_grid()

  grid_df <- data.frame(
    cell = "gaussian-d1",
    family = "gaussian",
    d = 1L,
    rep = c(1L, 1L, 2L, 3L, 3L),
    trait_id = c(1L, 2L, NA_integer_, 1L, 2L),
    covered_prof = c(TRUE, FALSE, NA, TRUE, TRUE),
    converged = c(TRUE, TRUE, FALSE, TRUE, TRUE),
    runtime_s = c(1, 1, 2, 3, 3)
  )

  summary_df <- m3_summarise(grid_df, gate = 0.70)

  expect_equal(summary_df$n_completed, 2L)
  expect_equal(summary_df$n_failed, 1L)
  expect_equal(summary_df$coverage_prof, 0.75)
  expect_true(summary_df$passes_94pct_prof)
  expect_equal(summary_df$mean_runtime_s, 2)
})

test_that("M3 grid summary handles cells with no converged coverage rows", {
  source_m3_grid()

  grid_df <- data.frame(
    cell = "nbinom2-d1",
    family = "nbinom2",
    d = 1L,
    rep = 1L,
    trait_id = NA_integer_,
    covered_prof = NA,
    converged = FALSE,
    runtime_s = 4
  )

  summary_df <- m3_summarise(grid_df)

  expect_equal(summary_df$n_completed, 0L)
  expect_equal(summary_df$n_failed, 1L)
  expect_true(is.na(summary_df$coverage_prof))
  expect_false(summary_df$passes_94pct_prof)
  expect_equal(summary_df$mean_runtime_s, 4)
})
