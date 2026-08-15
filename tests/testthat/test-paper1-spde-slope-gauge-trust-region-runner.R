spde_slope_gauge_tr_runner_env <- function() {
  runner <- testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "run-paper1-spde-slope-gauge-trust-region.R"
  )
  env <- new.env(parent = baseenv())
  old_source_only <- Sys.getenv("SPDE_SLOPE_GAUGE_TR_SOURCE_ONLY", unset = NA_character_)
  old_runner <- Sys.getenv("SPDE_SLOPE_GAUGE_TR_RUNNER_PATH", unset = NA_character_)
  Sys.setenv(SPDE_SLOPE_GAUGE_TR_SOURCE_ONLY = "1", SPDE_SLOPE_GAUGE_TR_RUNNER_PATH = runner)
  on.exit({
    if (is.na(old_source_only)) Sys.unsetenv("SPDE_SLOPE_GAUGE_TR_SOURCE_ONLY") else {
      Sys.setenv(SPDE_SLOPE_GAUGE_TR_SOURCE_ONLY = old_source_only)
    }
    if (is.na(old_runner)) Sys.unsetenv("SPDE_SLOPE_GAUGE_TR_RUNNER_PATH") else {
      Sys.setenv(SPDE_SLOPE_GAUGE_TR_RUNNER_PATH = old_runner)
    }
  }, add = TRUE)
  source(runner, local = env)
  env
}

spde_slope_gauge_tr_stage_token <- function(stage, parent_pid = 101L) {
  stage <- normalizePath(stage, mustWork = TRUE)
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PARENT_STAGE_V1",
    gate_base = dirname(stage),
    stage = stage,
    parent_pid = parent_pid,
    v3_live_output = file.path(stage, "v3-live-child.rds"),
    worker_output = file.path(stage, "worker-result.rds")
  )
}

test_that("the V3 validation child writer accepts only its fresh parent stage", {
  runner <- spde_slope_gauge_tr_runner_env()
  base <- tempfile("spde-slope-gauge-tr-stage-base-")
  dir.create(base)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1-fixture")
  dir.create(stage)
  token <- spde_slope_gauge_tr_stage_token(stage)
  saveRDS(token, file.path(stage, ".parent-stage.rds"))

  output <- file.path(stage, "v3-live-child.rds")
  expect_identical(runner$.spde_slope_gauge_tr_runner_atomic_rds(list(ok = TRUE), output, 101L), output)
  expect_true(file.exists(output))
  expect_error(
    runner$.spde_slope_gauge_tr_runner_atomic_rds(list(ok = TRUE), output, 101L),
    "output path or stage token is invalid"
  )

  stale <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1-stale")
  dir.create(stale)
  stale_token <- spde_slope_gauge_tr_stage_token(stale)
  saveRDS(stale_token, file.path(stale, ".parent-stage.rds"))
  writeLines("stale", file.path(stale, "extra.txt"))
  expect_error(
    runner$.spde_slope_gauge_tr_runner_atomic_rds(
      list(ok = TRUE), file.path(stale, "v3-live-child.rds"), 101L
    ),
    "output path or stage token is invalid"
  )
})

test_that("the worker writer requires the retained V3 receipt before it writes", {
  runner <- spde_slope_gauge_tr_runner_env()
  base <- tempfile("spde-slope-gauge-tr-worker-base-")
  dir.create(base)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1-fixture")
  dir.create(stage)
  token <- spde_slope_gauge_tr_stage_token(stage)
  saveRDS(token, file.path(stage, ".parent-stage.rds"))
  output <- token$worker_output
  expect_error(
    runner$.spde_slope_gauge_tr_runner_atomic_worker_rds(list(ok = TRUE), output, 101L),
    "worker output path or stage token is invalid"
  )
  saveRDS(list(schema = "v3"), file.path(stage, "v3-live-child.rds"))
  expect_identical(
    runner$.spde_slope_gauge_tr_runner_atomic_worker_rds(list(ok = TRUE), output, 101L),
    output
  )
  expect_true(file.exists(output))
})

test_that("the worker has one factory seam and no outer-optimizer or DLL-unload path", {
  runner_env <- spde_slope_gauge_tr_runner_env()
  expect_true(exists("spde_slope_gauge_validate_sign_orbit", envir = runner_env, inherits = FALSE))
  runner <- paste(readLines(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "run-paper1-spde-slope-gauge-trust-region.R"
  ), warn = FALSE), collapse = "\n")
  expect_equal(sum(gregexpr("TMB::MakeADFun", runner, fixed = TRUE)[[1L]] > 0L), 1L)
  expect_false(grepl("dyn.unload", runner, fixed = TRUE))
  expect_false(grepl("stats::optim", runner, fixed = TRUE))
  expect_false(grepl("nlminb", runner, fixed = TRUE))
  expect_match(runner, "spde-slope-gauge-trust-region-adapter.R", fixed = TRUE)
  expect_match(runner, "spde-slope-gauge-sign-contract.R", fixed = TRUE)
  expect_match(runner, "spde_slope_gauge_validate_sign_orbit", fixed = TRUE)
})
