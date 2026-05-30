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
  skip_if_not_heavy()
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
  skip_if_not_heavy()
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
  skip_if_not_heavy()
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
  skip_if_not_heavy()
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

test_that("M3 grid summary separates estimated and known phi modes", {
  skip_if_not_heavy()
  source_m3_grid()

  grid_df <- data.frame(
    cell = "nbinom2-d1",
    family = "nbinom2",
    d = 1L,
    target = "Sigma_unit_diag",
    ci_method = "bootstrap",
    fit_phi_mode = rep(c("estimated", "known"), each = 2L),
    rep = c(1L, 1L, 1L, 1L),
    trait_id = c(1L, 2L, 1L, 2L),
    fit_converged = TRUE,
    converged = TRUE,
    ci_available = TRUE,
    covered = TRUE,
    miss_side = "covered",
    truth = c(2, 4, 2, 4),
    estimate = c(1, 2, 1.5, 3),
    truth_phi = 2,
    est_phi_nbinom2 = c(1, 1, 2, 2),
    est_link_residual = c(3, 3, 2, 2),
    n_boot_failed = 0L,
    n_boot = 2L,
    runtime_s = 1
  )

  summary_df <- m3_summarise(grid_df)
  summary_df <- summary_df[order(summary_df$fit_phi_mode), ]

  expect_equal(summary_df$fit_phi_mode, c("estimated", "known"))
  expect_equal(summary_df$median_est_truth_ratio, c(0.5, 0.75))
  expect_equal(summary_df$median_est_phi_truth_ratio, c(0.5, 1))
})

test_that("M3 NB2 stress surface register expands fit-phi modes", {
  skip_if_not_heavy()
  source_m3_grid()

  surfaces <- m3_nb2_stress_surfaces()

  expect_equal(nrow(surfaces), 6L)
  expect_true(all(surfaces$family == "nbinom2"))
  expect_equal(sort(unique(surfaces$fit_phi_mode)), c("estimated", "known"))
  expect_true(all(surfaces$target == "Sigma_unit_diag"))
  expect_true(all(surfaces$ci_method == "none"))
  expect_true(all(surfaces$n_boot == 0L))
  expect_true(all(surfaces$run_stage == M3_STRESS_RUN_STAGE))
})

test_that("M3 stress register can include Gaussian and Poisson controls", {
  skip_if_not_heavy()
  source_m3_grid()

  surfaces <- m3_nb2_stress_surfaces(include_controls = TRUE)

  expect_true(any(surfaces$family == "gaussian"))
  expect_true(any(surfaces$family == "poisson"))
  expect_equal(
    unique(surfaces$fit_phi_mode[surfaces$family == "poisson"]),
    "estimated"
  )

  truth <- m3_sample_truth("poisson", d = 1L, seed = 1L)
  sim <- m3_simulate_response(truth)
  expect_true(all(sim$row_family == "poisson"))
  expect_true(all(sim$data$value >= 0))
})

test_that("M3 NB2 start probe configs are bounded and labelled", {
  skip_if_not_heavy()
  source_m3_grid()

  configs <- m3_nb2_start_probe_configs(include_optimizer_probe = FALSE)

  expect_equal(configs$probe_id[1], "current_res_bfgs_n3_j005")
  expect_true(all(c(
    "probe_id", "probe_label", "start_method_name", "optimizer",
    "n_init", "init_jitter"
  ) %in% names(configs)))
  expect_true(all(configs$optimizer == "optim"))
  expect_true(any(configs$n_init > configs$n_init[1]))
})

test_that("M3 point-only Sigma diagnostics are not coverage evidence", {
  skip_if_not_heavy()
  source_m3_grid()

  grid_df <- data.frame(
    surface_id = "nbinom2-d1-baseline-phi1-n60",
    scenario = "baseline_phi1_n60",
    run_stage = M3_STRESS_RUN_STAGE,
    cell = "nbinom2-d1",
    family = "nbinom2",
    d = 1L,
    target = "Sigma_unit_diag",
    ci_method = "none",
    fit_phi_mode = rep(c("estimated", "known"), each = 2L),
    rep = c(1L, 1L, 1L, 1L),
    trait_id = c(1L, 2L, 1L, 2L),
    fit_converged = TRUE,
    converged = TRUE,
    ci_available = FALSE,
    covered = NA,
    miss_side = "ci_unavailable",
    truth = c(2, 4, 2, 4),
    estimate = c(1, 2, 1.5, 3),
    truth_phi = 2,
    est_phi_nbinom2 = c(1, 1, 2, 2),
    est_link_residual = c(3, 3, 2, 2),
    n_boot_failed = 0L,
    n_boot = 0L,
    n_cores_boot = 1L,
    n_units = 60L,
    n_traits = 5L,
    lambda_scale = 1,
    psi_scale = 1,
    seed_base = 20260520L,
    runtime_s = 1
  )

  summary_df <- m3_summarise(grid_df)
  summary_df <- summary_df[order(summary_df$fit_phi_mode), ]

  expect_equal(summary_df$ci_method, c("none", "none"))
  expect_true(all(is.na(summary_df$coverage)))
  expect_true(all(is.na(summary_df$passes_94pct_prof)))
  expect_equal(summary_df$profile_gate_status, c("NOT_EVALUATED", "NOT_EVALUATED"))
  expect_equal(summary_df$pilot_status, c("POINT_ONLY", "POINT_ONLY"))
  expect_equal(summary_df$median_est_truth_ratio, c(0.5, 0.75))
})

test_that("M3 summaries keep start-probe rows separated", {
  skip_if_not_heavy()
  source_m3_grid()

  base <- data.frame(
    probe_id = rep(c("current_res_bfgs_n3_j005", "res_bfgs_n10_j020"), each = 4L),
    probe_label = rep(c("current", "more restarts"), each = 4L),
    probe_stage = M3_START_PROBE_STAGE,
    probe_start_method = rep(c("res", "res"), each = 4L),
    probe_optimizer = rep(c("optim", "optim"), each = 4L),
    probe_n_init = rep(c(3L, 10L), each = 4L),
    probe_init_jitter = rep(c(0.05, 0.2), each = 4L),
    surface_id = "nbinom2-d1-baseline-phi1-n60",
    scenario = "baseline_phi1_n60",
    run_stage = M3_START_PROBE_STAGE,
    cell = "nbinom2-d1",
    family = "nbinom2",
    d = 1L,
    target = "Sigma_unit_diag",
    ci_method = "none",
    fit_phi_mode = "estimated",
    rep = rep(c(1L, 1L, 1L, 1L), 2L),
    trait_id = rep(c(1L, 2L, 1L, 2L), 2L),
    fit_converged = TRUE,
    converged = TRUE,
    ci_available = FALSE,
    covered = NA,
    miss_side = "ci_unavailable",
    truth = rep(c(2, 4, 2, 4), 2L),
    estimate = c(1, 2, 1, 2, 1.5, 3, 1.5, 3),
    truth_phi = 2,
    est_phi_nbinom2 = c(1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5),
    est_link_residual = 2,
    n_boot_failed = 0L,
    n_boot = 0L,
    n_cores_boot = 1L,
    n_units = 60L,
    n_traits = 5L,
    lambda_scale = 1,
    psi_scale = 1,
    seed_base = 20260520L,
    restart_count = rep(c(3L, 10L), each = 4L),
    objective_spread = rep(c(0.1, 0.02), each = 4L),
    runtime_s = 1
  )

  summary_df <- m3_summarise(base)
  summary_df <- summary_df[order(summary_df$probe_id), ]

  expect_equal(nrow(summary_df), 2L)
  expect_equal(summary_df$probe_id, c("current_res_bfgs_n3_j005", "res_bfgs_n10_j020"))
  expect_equal(summary_df$pilot_status, c("POINT_ONLY", "POINT_ONLY"))
  expect_equal(summary_df$median_est_truth_ratio, c(0.5, 0.75))
  expect_equal(summary_df$median_restart_count, c(3, 10))
})

test_that("M3 diagnostic report data keeps trait ratios and failure ledger", {
  skip_if_not_heavy()
  source_m3_grid()

  grid_df <- data.frame(
    surface_id = "nbinom2-d1-baseline-phi1-n60",
    scenario = "baseline_phi1_n60",
    run_stage = M3_STRESS_RUN_STAGE,
    cell = "nbinom2-d1",
    family = "nbinom2",
    d = 1L,
    target = "Sigma_unit_diag",
    ci_method = "none",
    fit_phi_mode = rep(c("estimated", "known"), each = 2L),
    rep = c(1L, 1L, 1L, 1L),
    trait_id = c(1L, 2L, 1L, 2L),
    fit_converged = TRUE,
    converged = TRUE,
    ci_available = FALSE,
    covered = NA,
    miss_side = "ci_unavailable",
    truth = c(2, 4, 2, 4),
    estimate = c(1, 2, 1.5, 3),
    truth_phi = 2,
    est_phi_nbinom2 = c(1, 1, 2, 2),
    est_link_residual = c(3, 3, 2, 2),
    n_boot_failed = 0L,
    n_boot = 0L,
    n_cores_boot = 1L,
    n_units = 60L,
    n_traits = 5L,
    lambda_scale = 1,
    psi_scale = 1,
    seed_base = 20260520L,
    runtime_s = 1
  )

  report <- m3_diagnostic_report_data(grid_df)

  expect_s3_class(report, "m3_diagnostic_report")
  expect_true(all(c("header", "summary", "trait_ratios", "failure_ledger") %in% names(report)))
  expect_equal(sort(unique(report$trait_ratios$fit_phi_mode)), c("estimated", "known"))
  expect_equal(unique(report$failure_ledger$pilot_status), "POINT_ONLY")
  expect_true(all(report$summary$ci_method == "none"))
  expect_true(all(is.na(report$summary$passes_94pct_prof)))
  expect_equal(unique(report$summary$profile_gate_status), "NOT_EVALUATED")
  expect_true(all(is.na(report$trait_ratios$coverage)))
})

test_that("M3 source-map dashboard keeps point-only rows visually explicit", {
  skip_if_not_heavy()
  source_m3_grid()
  skip_if_not_installed("ggplot2")

  grid_df <- data.frame(
    surface_id = "nbinom2-d1-baseline-phi1-n60",
    scenario = "baseline_phi1_n60",
    run_stage = M3_STRESS_RUN_STAGE,
    cell = "nbinom2-d1",
    family = "nbinom2",
    d = 1L,
    target = "Sigma_unit_diag",
    ci_method = "none",
    fit_phi_mode = rep(c("estimated", "known"), each = 2L),
    rep = c(1L, 1L, 1L, 1L),
    trait_id = c(1L, 2L, 1L, 2L),
    fit_converged = TRUE,
    converged = TRUE,
    ci_available = FALSE,
    covered = NA,
    miss_side = "ci_unavailable",
    truth = c(2, 4, 2, 4),
    estimate = c(1, 2, 1.5, 3),
    truth_phi = 2,
    est_phi_nbinom2 = c(1, 1, 2, 2),
    est_link_residual = c(3, 3, 2, 2),
    n_boot_failed = 0L,
    n_boot = 0L,
    n_cores_boot = 1L,
    n_units = 60L,
    n_traits = 5L,
    lambda_scale = 1,
    psi_scale = 1,
    seed_base = 20260520L,
    runtime_s = 1
  )

  dashboard <- m3_source_map_dashboard_data(grid_df)
  expect_s3_class(dashboard, "m3_source_map_dashboard_data")
  expect_true(all(c("ratio_points", "failure_rates", "verdict_tiles") %in% names(dashboard)))
  expect_equal(unique(dashboard$verdict_tiles$pilot_status), "POINT_ONLY")
  expect_equal(
    unique(dashboard$failure_rates$denominator_label[
      dashboard$failure_rates$metric == "CI missing"
    ]),
    "point only"
  )

  ratios <- m3_plot_source_map_ratios(dashboard)
  ledger <- m3_plot_source_map_failure_ledger(dashboard)
  verdict <- m3_plot_source_map_verdict(dashboard)
  expect_s3_class(ratios, "ggplot")
  expect_s3_class(ledger, "ggplot")
  expect_s3_class(verdict, "ggplot")

  skip_if_not(capabilities("png"), "PNG device unavailable")
  png_path <- tempfile(fileext = ".png")
  expect_equal(m3_write_source_map_dashboard(grid_df, png_path), png_path)
  expect_true(file.exists(png_path))
  expect_gt(file.info(png_path)$size, 0)
})
