source_power_pilot_report <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- list(
    root = ".",
    package = file.path("..", ".."),
    workspace = workspace
  )
  roots <- unique(unlist(candidates, use.names = FALSE))
  roots <- roots[nzchar(roots)]
  roots <- roots[dir.exists(roots)]
  files <- lapply(roots, function(root) {
    file.path(
      root,
      "dev",
      c(
        "m3-grid.R",
        "m3-pilot-launch.R",
        "m3-pilot-report.R"
      )
    )
  })
  hit <- files[vapply(
    files,
    function(paths) all(file.exists(paths)),
    logical(1)
  )]
  testthat::skip_if(
    !length(hit),
    "dev power-pilot helpers are unavailable in this source-tarball context"
  )
  paths <- hit[[1]]
  source(paths[1], local = parent.frame())
  source(paths[2], local = parent.frame())
  source(paths[3], local = parent.frame())
}

fake_power_pilot_grid <- function() {
  data.frame(
    cell = "binomial_probit-d1-n50-sig0p2",
    family = "binomial",
    d = 1L,
    rep = c(1L, 1L, 2L, 2L),
    rep_seed = c(101L, 101L, 102L, 102L),
    trait_id = c(1L, 2L, 1L, 2L),
    target = "Sigma_unit_diag",
    ci_method = "bootstrap",
    fit_converged = TRUE,
    converged = TRUE,
    fit_convergence_code = c(0L, 0L, 1L, 1L),
    pd_hessian = c(TRUE, TRUE, FALSE, FALSE),
    sdreport_ok = c(TRUE, TRUE, FALSE, FALSE),
    ci_available = TRUE,
    covered = c(TRUE, TRUE, FALSE, TRUE),
    miss_side = c(
      "covered",
      "covered",
      "truth_above_upper",
      "covered"
    ),
    truth = c(1, 1, 2, 2),
    estimate = c(1, 1, 1, 2),
    ci_lo = c(0.2, 0.2, 0.2, 0.2),
    ci_hi = c(1.2, 1.2, 1.2, 2.2),
    n_boot_failed = c(1L, 1L, 0L, 0L),
    n_boot = 5L,
    runtime_s = c(1, 1, 2, 2),
    n_units = 50L,
    n_traits = 5L,
    lambda_scale = 0.5,
    stringsAsFactors = FALSE
  )
}

test_that("M3 harness simulates and fits true binomial-probit", {
  source_power_pilot_report()

  truth <- m3_sample_truth(
    "binomial_probit",
    d = 1L,
    seed = 42L,
    n_units = 30L,
    n_traits = 3L
  )
  sim <- m3_simulate_response(truth)

  expect_true(all(sim$row_family == "binomial_probit"))
  expect_true(all(truth$psi_effective == 0))
  expect_true(all(sim$data$value %in% c(0, 1)))

  one <- m3_run_cell(
    family = "binomial_probit",
    d = 1L,
    n_reps = 1L,
    seed_base = 42L,
    n_units = 30L,
    n_traits = 3L,
    lambda_scale = 0.4,
    targets = "Sigma_unit_diag",
    n_boot = 0L,
    se = FALSE
  )

  expect_equal(unique(one$family), "binomial_probit")
  expect_equal(unique(one$target), "Sigma_unit_diag")
  expect_equal(unique(one$n_boot), 0L)
})

test_that("power pilot report carries denominators, MCSEs, and evidence labels", {
  source_power_pilot_report()

  g <- fake_power_pilot_grid()

  row <- pilot_collect_cell(
    g,
    "binomial_probit-d1-n50-sig0p2",
    pilot_grid(),
    PILOT_GATE_94,
    PILOT_GATE_95
  )

  expect_equal(row$evidence_family, "binomial_probit")
  expect_equal(row$link_intended, "probit")
  expect_equal(row$link_harness, "probit")

  expect_equal(row$n_attempted_fits, 2L)
  expect_equal(row$n_converged_fits, 2L)
  expect_equal(row$n_optimizer_converged, 1L)
  expect_equal(row$n_pd_hessian, 1L)
  expect_equal(row$n_sdreport_ok, 1L)
  expect_equal(row$n_boot_attempted, 10L)
  expect_equal(row$n_boot_failed, 1L)
  expect_equal(row$coverage_eligible_n, 4L)
  expect_equal(row$zero_exclusion_n, 4L)

  expect_equal(row$coverage_primary, 0.75)
  expect_equal(row$coverage_mcse, sqrt(0.75 * 0.25 / 2))
  expect_equal(row$zero_exclusion_rate, 1)
  expect_equal(row$fit_failure_rate, 0)
  expect_equal(row$nonpd_rate, 0.5)
  expect_equal(row$conv_failure_rate, 0.5)
  expect_equal(row$boot_fail_rate, 0.1)
  expect_equal(row$boot_fail_mcse, sqrt(0.1 * 0.9 / 10))

  lines <- pilot_record_lines(row)
  expect_true(any(grepl("binomial_probit", lines, fixed = TRUE)))
  expect_true(any(grepl("cov_mcse", lines, fixed = TRUE)))
  expect_true(any(grepl("sdreport", lines, fixed = TRUE)))
})

test_that("power pilot report reads explicit immutable chunk aggregates", {
  source_power_pilot_report()

  results_dir <- tempfile("pilot-report-chunk-")
  aggregate_dir <- file.path(results_dir, PILOT_CHUNK_AGGREGATE_DIR)
  dir.create(aggregate_dir, recursive = TRUE)
  cell_id <- "binomial_probit-d1-n50-sig0p2"
  saveRDS(
    fake_power_pilot_grid(),
    file.path(aggregate_dir, paste0(cell_id, ".rds"))
  )

  rows <- pilot_collect_chunk_aggregates(results_dirs = results_dir)

  expect_equal(nrow(rows), 1L)
  expect_equal(rows$cell_id, cell_id)
  expect_equal(rows$evidence_family, "binomial_probit")
  expect_equal(rows$n_attempted_fits, 2L)
  expect_equal(rows$coverage_eligible_n, 4L)
  expect_equal(rows$coverage_primary, 0.75)
  expect_equal(rows$coverage_mcse, sqrt(0.75 * 0.25 / 2))
  expect_equal(rows$flag, "nonPD 50%; conv-fail 50%; boot-fail 10%")
})

test_that("power pilot report CLI emits issues from chunk aggregates", {
  source_power_pilot_report()

  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- unique(c(".", file.path("..", ".."), workspace))
  candidates <- candidates[nzchar(candidates) & dir.exists(candidates)]
  roots <- candidates[file.exists(file.path(
    candidates,
    "dev",
    "m3-pilot-report.R"
  ))]
  testthat::skip_if(!length(roots), "repo root is unavailable for CLI smoke")
  root <- normalizePath(roots[1], winslash = "/", mustWork = TRUE)

  results_dir <- tempfile("pilot-report-cli-")
  aggregate_dir <- file.path(results_dir, PILOT_CHUNK_AGGREGATE_DIR)
  dir.create(aggregate_dir, recursive = TRUE)
  cell_id <- "binomial_probit-d1-n50-sig0p2"
  saveRDS(
    fake_power_pilot_grid(),
    file.path(aggregate_dir, paste0(cell_id, ".rds"))
  )

  cmd <- file.path(R.home("bin"), "Rscript")
  old_wd <- setwd(root)
  on.exit(setwd(old_wd), add = TRUE)
  out <- system2(
    cmd,
    c(
      "--vanilla",
      file.path("dev", "m3-pilot-report.R"),
      "--emit-issues",
      "--chunk-aggregate",
      paste0("--results-dir=", results_dir)
    ),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_null(attr(out, "status"))
  expect_match(paste(out, collapse = "\n"), "nonPD 50%")
})
