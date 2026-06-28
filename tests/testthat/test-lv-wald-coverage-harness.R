source_lv_wald_coverage <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(
    file.path("dev", "lv-wald-coverage.R"),
    file.path("..", "..", "dev", "lv-wald-coverage.R"),
    if (!is.na(workspace)) file.path(workspace, "dev", "lv-wald-coverage.R")
  )
  dev_file <- candidates[file.exists(candidates)][1]
  testthat::skip_if(
    is.na(dev_file),
    "dev/lv-wald-coverage.R is unavailable in this source-tarball context"
  )
  source(dev_file, local = parent.frame())
}

test_that("LV Wald coverage grid assigns one seed per task", {
  source_lv_wald_coverage()

  plan <- lv_wald_coverage_grid(n_reps = 2L, seed_base = 20260628L)

  expect_equal(nrow(plan), 8L)
  expect_equal(plan$task_id, seq_len(nrow(plan)))
  expect_equal(length(unique(plan$rep_seed)), nrow(plan))
  expect_equal(as.integer(table(plan$cell_id)), rep(2L, 4L))
  expect_true(all(plan$rep %in% 1:2))
})

test_that("LV Wald coverage interval methods define normal and t criticals", {
  source_lv_wald_coverage()

  expect_equal(lv_wald_interval_methods(), c("wald_z", "wald_t_unit"))
  expect_equal(lv_wald_unit_t_df(n_units = 12L, d = 2L), 9L)

  z <- lv_wald_interval_critical(
    method = "wald_z",
    level = 0.95,
    n_units = 12L,
    d = 2L
  )
  t <- lv_wald_interval_critical(
    method = "wald_t_unit",
    level = 0.95,
    n_units = 12L,
    d = 2L
  )

  expect_equal(z$critical, stats::qnorm(0.975))
  expect_true(is.na(z$df))
  expect_equal(t$critical, stats::qt(0.975, df = 9L))
  expect_equal(t$df, 9L)
  expect_gt(t$critical, z$critical)
  expect_error(lv_wald_interval_methods("bogus"), "Unknown")
})

test_that("LV Wald coverage summary keeps failed-fit denominators", {
  source_lv_wald_coverage()

  base_rows <- data.frame(
    cell_id = "gaussian-d1-n72-t3",
    family = "gaussian",
    d = 1L,
    n_units = 72L,
    n_traits = 3L,
    predictor = "x",
    rep = 1:3,
    target = "B_lv",
    target_id = "B_lv[t1,x]",
    trait = "t1",
    truth = 0.50,
    estimate = c(0.50, 0.90, NA),
    std.error = c(0.05, 0.05, NA),
    uncertainty_status = "wald_sdreport_no_ci_validation",
    validation_row = "EXT-31; LV-01",
    level = 0.95,
    conf.low = c(0.40, 0.80, NA),
    conf.high = c(0.60, 1.00, NA),
    ci_available = c(TRUE, TRUE, FALSE),
    eligible = c(TRUE, TRUE, FALSE),
    covered = c(TRUE, FALSE, NA),
    error = c(0, 0.40, NA),
    runtime_s = c(1, 2, 3),
    extract_error = NA_character_,
    fit_error = c(NA, NA, "optimizer failed"),
    fit_convergence_code = c(0L, 0L, NA_integer_),
    fit_converged = c(TRUE, TRUE, FALSE),
    fit_message = NA_character_,
    fit_objective = c(10, 11, NA),
    max_gradient = c(0.01, 0.02, NA),
    pd_hessian = c(TRUE, TRUE, FALSE),
    sdreport_ok = c(TRUE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  rows <- rbind(
    transform(
      base_rows,
      interval_method = "wald_z",
      critical = stats::qnorm(0.975),
      critical_df = NA_real_,
      critical_df_source = "normal"
    ),
    transform(
      base_rows,
      interval_method = "wald_t_unit",
      critical = stats::qt(0.975, df = 70L),
      critical_df = 70,
      critical_df_source = "n_units_minus_d_minus_1",
      conf.low = c(0.40, 0.40, NA),
      conf.high = c(0.60, 1.00, NA),
      covered = c(TRUE, TRUE, NA)
    )
  )

  summary <- lv_wald_coverage_summarise(rows, production_n_reps = 3L)
  summary <- summary[order(summary$interval_method), , drop = FALSE]

  expect_equal(summary$interval_method, c("wald_t_unit", "wald_z"))
  expect_equal(summary$n_attempted, c(3L, 3L))
  expect_equal(summary$n_converged, c(2L, 2L))
  expect_equal(summary$n_pd_hessian, c(2L, 2L))
  expect_equal(summary$n_sdreport_ok, c(2L, 2L))
  expect_equal(summary$n_ci_available, c(2L, 2L))
  expect_equal(summary$n_eligible, c(2L, 2L))
  expect_equal(summary$coverage, c(1, 0.5))
  expect_equal(summary$coverage_mcse, c(0, sqrt(0.5 * 0.5 / 2)))
  expect_equal(summary$nominal_coverage_mcse, rep(sqrt(0.95 * 0.05 / 2), 2))
  expect_equal(summary$bias, c(0.2, 0.2))
  expect_equal(summary$rmse, rep(sqrt(mean(c(0, 0.4)^2)), 2))
  expect_equal(summary$fit_failure_rate, c(1 / 3, 1 / 3))
  expect_false(any(summary$passes_coverage_band))
})

test_that("LV Wald coverage smoke returns B_lv target rows", {
  skip_if_not(
    identical(Sys.getenv("GLLVMTMB_LV_WALD_SMOKE"), "true"),
    "LV Wald coverage fit smoke is opt-in"
  )
  source_lv_wald_coverage()

  rows <- lv_wald_coverage_run_cell(
    "gaussian-d1-n72-t3",
    n_reps = 1L,
    seed_base = 2L,
    verbose = FALSE
  )

  expect_equal(nrow(rows), 6L)
  expect_equal(unique(rows$target), "B_lv")
  expect_equal(sort(unique(rows$interval_method)), c("wald_t_unit", "wald_z"))
  expect_true(all(
    rows$critical[rows$interval_method == "wald_t_unit"] >
      rows$critical[rows$interval_method == "wald_z"]
  ))
  expect_equal(
    unique(rows$uncertainty_status),
    "wald_sdreport_no_ci_validation"
  )
  expect_true(all(is.finite(rows$truth)))
  expect_true(all(is.finite(rows$estimate)))
  expect_true(all(is.finite(rows$std.error)))
})
