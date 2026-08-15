spde_slope_gauge_nofit_v2_runner_env <- function() {
  old <- Sys.getenv(
    "SPDE_SLOPE_GAUGE_NOFIT_V2_SOURCE_ONLY",
    unset = NA_character_
  )
  old_path <- Sys.getenv(
    "SPDE_SLOPE_GAUGE_NOFIT_V2_RUNNER_PATH",
    unset = NA_character_
  )
  path <- testthat::test_path(
    "..",
    "..",
    "dev",
    "isdm-package-recovery",
    "run-paper1-spde-slope-gauge-nofit-v2.R"
  )
  Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_SOURCE_ONLY = "1")
  Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_RUNNER_PATH = path)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("SPDE_SLOPE_GAUGE_NOFIT_V2_SOURCE_ONLY")
      } else {
        Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_SOURCE_ONLY = old)
      }
      if (is.na(old_path)) {
        Sys.unsetenv("SPDE_SLOPE_GAUGE_NOFIT_V2_RUNNER_PATH")
      } else {
        Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_RUNNER_PATH = old_path)
      }
    },
    add = TRUE
  )
  env <- new.env(parent = baseenv())
  source(path, local = env)
  env
}

test_that("V2 runner preserves the declared early failure taxonomy", {
  runner <- spde_slope_gauge_nofit_v2_runner_env()
  expect_identical(
    runner$.spde_slope_gauge_nofit_v2_stage_reason("v1_forensic", "bad"),
    "v1_forensic_invalid"
  )
  expect_identical(
    runner$.spde_slope_gauge_nofit_v2_stage_reason("predecessor_bytes", "bad"),
    "predecessor_bytes_invalid"
  )
  expect_identical(
    runner$.spde_slope_gauge_nofit_v2_stage_reason("dll", "bad"),
    "dll_identity_failure"
  )
  expect_identical(
    runner$.spde_slope_gauge_nofit_v2_stage_reason(
      "callback",
      "elapsed time limit"
    ),
    "time_limit_exceeded"
  )
})

test_that("V2 runner source-only mode does not dispatch a child", {
  runner <- spde_slope_gauge_nofit_v2_runner_env()
  expect_true(is.function(runner$.spde_slope_gauge_nofit_v2_child_result))
  expect_true(is.function(runner$.spde_slope_gauge_nofit_v2_atomic_rds))
  expect_true(is.function(runner$.spde_slope_gauge_nofit_v2_runtime_dll))
})

test_that("V2 catch projection preserves only stage-reached timeout evidence", {
  runner <- spde_slope_gauge_nofit_v2_runner_env()
  v1 <- list(
    valid = TRUE,
    root = "/v1",
    commit = "v1-commit",
    receipt = list(v1 = TRUE),
    files = c("root-receipt.rds" = "11111111111111111111111111111111"),
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    terminal_reason = "child_evidence_invalid"
  )
  v3 <- list(
    valid = TRUE,
    root = "/v3",
    commit = "v3-commit",
    receipt = list(v3 = TRUE),
    state_md5 = "22222222222222222222222222222222"
  )
  dll <- list(
    path = "/sealed/gllvmTMB.so",
    md5 = "33333333333333333333333333333333"
  )
  callback_timeout <- runner$.spde_slope_gauge_nofit_v2_partial_failure(
    "time_limit_exceeded",
    "callback",
    "elapsed deadline",
    v1,
    v3,
    dll,
    1L,
    1L
  )
  expect_identical(callback_timeout$reason, "time_limit_exceeded")
  expect_identical(callback_timeout$stage, "callback")
  expect_identical(callback_timeout$dll, dll)
  expect_identical(callback_timeout$object, list(created = 1L, released = 1L))
  expect_true(is.list(callback_timeout$predecessor))

  failed_release <- runner$.spde_slope_gauge_nofit_v2_partial_failure(
    "time_limit_exceeded",
    "callback",
    "elapsed deadline",
    v1,
    v3,
    dll,
    1L,
    0L
  )
  expect_identical(failed_release$reason, "object_release_failure")
  expect_identical(failed_release$stage, "release")
  expect_identical(failed_release$object, list(created = 1L, released = 0L))

  early_timeout <- runner$.spde_slope_gauge_nofit_v2_partial_failure(
    "time_limit_exceeded",
    "dll",
    "elapsed deadline",
    v1,
    v3,
    dll,
    0L,
    0L
  )
  expect_null(early_timeout$predecessor)
  expect_null(early_timeout$dll)
  expect_identical(early_timeout$object, list(created = 0L, released = 0L))

  dll_failure <- runner$.spde_slope_gauge_nofit_v2_partial_failure(
    "dll_identity_failure",
    "dll",
    "active DLL mismatch",
    v1,
    v3,
    NULL,
    0L,
    0L
  )
  expect_true(is.list(dll_failure$predecessor))
  expect_null(dll_failure$dll)
  expect_identical(dll_failure$object, list(created = 0L, released = 0L))
})

test_that("V2 child output is restricted to a fresh token-bound staging path", {
  runner <- spde_slope_gauge_nofit_v2_runner_env()
  base <- runner$.spde_slope_gauge_nofit_v2_gate_base()
  if (!dir.exists(base)) {
    dir.create(base, recursive = TRUE)
  }
  stage <- tempfile(".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-", tmpdir = base)
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  stage <- normalizePath(stage)
  parent_pid <- 19701L
  output <- file.path(stage, "child-result.rds")
  token <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_PARENT_STAGE_V1",
    gate_base = normalizePath(base),
    stage = stage,
    parent_pid = parent_pid,
    child_output = output
  )
  saveRDS(token, file.path(stage, ".parent-stage.rds"))
  runner$.spde_slope_gauge_nofit_v2_atomic_rds(
    list(value = 1L),
    output,
    parent_pid
  )
  expect_identical(readRDS(output), list(value = 1L))

  stale <- tempfile(".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-", tmpdir = base)
  dir.create(stale)
  on.exit(unlink(stale, recursive = TRUE), add = TRUE)
  stale <- normalizePath(stale)
  stale_output <- file.path(stale, "child-result.rds")
  saveRDS(
    list(
      schema = token$schema,
      gate_base = normalizePath(base),
      stage = stale,
      parent_pid = parent_pid,
      child_output = stale_output
    ),
    file.path(stale, ".parent-stage.rds")
  )
  writeLines("stale", file.path(stale, "unexpected.txt"))
  message <- tryCatch(
    {
      runner$.spde_slope_gauge_nofit_v2_atomic_rds(
        list(value = 2L),
        stale_output,
        parent_pid
      )
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )
  expect_identical(message, "V2 child output path is invalid")

  symlink_stage <- tempfile(
    ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-",
    tmpdir = base
  )
  dir.create(symlink_stage)
  on.exit(unlink(symlink_stage, recursive = TRUE), add = TRUE)
  symlink_stage <- normalizePath(symlink_stage)
  symlink_output <- file.path(symlink_stage, "child-result.rds")
  saveRDS(
    list(
      schema = token$schema,
      gate_base = normalizePath(base),
      stage = symlink_stage,
      parent_pid = parent_pid,
      child_output = symlink_output
    ),
    file.path(symlink_stage, ".parent-stage.rds")
  )
  target <- tempfile("v2-child-target-")
  saveRDS(list(target = TRUE), target)
  on.exit(unlink(target), add = TRUE)
  if (!file.symlink(target, symlink_output)) {
    skip("symlinks are unavailable on this platform")
  }
  message <- tryCatch(
    {
      runner$.spde_slope_gauge_nofit_v2_atomic_rds(
        list(value = 3L),
        symlink_output,
        parent_pid
      )
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )
  expect_identical(message, "V2 child output path is invalid")
})
