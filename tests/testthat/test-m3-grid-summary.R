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

test_that("M3 helper tags fitted NB2 phi only on NB2 traits", {
  source_m3_grid()

  fit <- structure(
    list(
      data = data.frame(
        trait = factor(c("t1", "t2", "t3"), levels = c("t1", "t2", "t3"))
      ),
      trait_col = "trait",
      tmb_data = list(
        family_id_vec = c(5L, 0L, 5L),
        trait_id = c(0L, 1L, 2L)
      ),
      report = list(phi_nbinom2 = c(2, 4, 8))
    ),
    class = "gllvmTMB_multi"
  )

  expect_equal(m3_fitted_nbinom2_phi(fit, 3L), c(2, NA, 8))
})

test_that("M3 grid summary preserves fitted phi and link-residual diagnostics", {
  source_m3_grid()

  grid_df <- data.frame(
    cell = "nbinom2-d1",
    family = "nbinom2",
    d = 1L,
    target = "Sigma_unit_diag",
    ci_method = "bootstrap",
    rep = c(1L, 1L, 2L, 2L),
    trait_id = c(1L, 2L, 1L, 2L),
    fit_converged = TRUE,
    converged = TRUE,
    ci_available = TRUE,
    covered = c(TRUE, FALSE, TRUE, FALSE),
    miss_side = c(
      "covered",
      "truth_above_upper",
      "covered",
      "truth_above_upper"
    ),
    truth = c(2, 4, 2, 4),
    estimate = c(1, 2, 1, 2),
    truth_phi = 2,
    est_phi_nbinom2 = c(1, 4, 1, 4),
    est_link_residual = c(1, 3, 1, 3),
    n_boot_failed = 0L,
    n_boot = 2L,
    runtime_s = c(1, 1, 2, 2)
  )

  summary_df <- m3_summarise(grid_df)

  expect_equal(summary_df$median_est_truth_ratio, 0.5)
  expect_equal(summary_df$median_est_phi_truth_ratio, 1.25)
  expect_equal(summary_df$median_est_link_residual, 2)
  expect_equal(summary_df$median_link_residual_truth_ratio, 0.625)
})
