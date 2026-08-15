spde_slope_gauge_nofit_v2_materializer_env <- function() {
  path <- testthat::test_path(
    "..",
    "..",
    "dev",
    "isdm-package-recovery",
    "materialize-paper1-spde-slope-gauge-nofit-v2-gate.R"
  )
  old_source <- Sys.getenv(
    "SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY",
    unset = NA_character_
  )
  old_path <- Sys.getenv(
    "SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH",
    unset = NA_character_
  )
  Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY = "1")
  Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH = path)
  on.exit(
    {
      if (is.na(old_source)) {
        Sys.unsetenv("SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY")
      } else {
        Sys.setenv(
          SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY = old_source
        )
      }
      if (is.na(old_path)) {
        Sys.unsetenv("SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH")
      } else {
        Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH = old_path)
      }
    },
    add = TRUE
  )
  env <- new.env(parent = globalenv())
  source(path, local = env)
  env
}

test_that("V2 materializer can be loaded without dispatching a child process", {
  materializer <- spde_slope_gauge_nofit_v2_materializer_env()
  expect_true(is.function(materializer$.spde_slope_gauge_nofit_v2_launch_child))
  expect_true(is.function(materializer$.spde_slope_gauge_nofit_v2_seal))
  expect_true(is.function(
    materializer$spde_slope_gauge_nofit_v2_materialize_gate
  ))
})

test_that("V2 child supervision retains process evidence but never infers a child", {
  materializer <- spde_slope_gauge_nofit_v2_materializer_env()
  stage <- tempfile("spde-slope-gauge-v2-materializer-")
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)

  failed <- materializer$.spde_slope_gauge_nofit_v2_launch_child(
    stage,
    parent_pid = 31001L,
    run_fun = function(...) {
      list(
        status = 17L,
        stdout = "",
        stderr = "factory failed",
        timed_out = FALSE,
        pid = 31002L
      )
    }
  )
  expect_null(failed$child)
  expect_false(failed$process$timed_out)
  expect_identical(failed$process$exit_status, 17L)
  expect_identical(failed$process$observed_child_pid, 31002L)
  expect_true(is.na(failed$process$child_pid))
  expect_true(is.na(failed$process$child_result_md5))

  timeout_stage <- tempfile("spde-slope-gauge-v2-materializer-")
  dir.create(timeout_stage)
  on.exit(unlink(timeout_stage, recursive = TRUE), add = TRUE)
  timed_out <- materializer$.spde_slope_gauge_nofit_v2_launch_child(
    timeout_stage,
    parent_pid = 31001L,
    run_fun = function(...) {
      list(
        status = NA_integer_,
        stdout = "",
        stderr = "elapsed time limit",
        timed_out = TRUE,
        pid = 31003L
      )
    }
  )
  expect_null(timed_out$child)
  expect_true(timed_out$process$timed_out)
  expect_true(is.na(timed_out$process$exit_status))
  expect_true(is.na(timed_out$process$child_result_md5))
  expect_identical(timed_out$process$observed_child_pid, 31003L)
  expect_true(file.exists(file.path(timeout_stage, "child-stdout.txt")))
  expect_true(file.exists(file.path(timeout_stage, "child-stderr.txt")))
})

test_that("V2 materializer atomic artifacts reject an existing target", {
  materializer <- spde_slope_gauge_nofit_v2_materializer_env()
  target <- tempfile("spde-slope-gauge-v2-existing-")
  saveRDS(list(existing = TRUE), target)
  on.exit(unlink(target), add = TRUE)
  expect_error(
    materializer$.spde_slope_gauge_nofit_v2_atomic_rds(
      list(value = 1L),
      target
    ),
    "fresh regular path"
  )
})

test_that("V2 materializer identifies retained post-launch staging evidence", {
  materializer <- spde_slope_gauge_nofit_v2_materializer_env()
  base <- tempfile("spde-slope-gauge-v2-base-")
  dir.create(base)
  base <- normalizePath(base, mustWork = TRUE)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-stale")
  dir.create(stage)
  stage <- normalizePath(stage, mustWork = TRUE)
  writeLines("retained child boundary", file.path(stage, ".parent-stage.rds"))
  expect_identical(
    materializer$.spde_slope_gauge_nofit_v2_stale_stages(base),
    stage
  )
  expect_length(
    materializer$.spde_slope_gauge_nofit_v2_stale_stages(tempfile()),
    0L
  )
})

test_that("V2 materializer treats an absent root or child output as non-symlink", {
  materializer <- spde_slope_gauge_nofit_v2_materializer_env()
  absent <- tempfile("spde-slope-gauge-v2-absent-")
  expect_false(file.exists(absent))
  expect_true(is.na(Sys.readlink(absent)))
  source_text <- paste(
    readLines(
      testthat::test_path(
        "..",
        "..",
        "dev",
        "isdm-package-recovery",
        "materialize-paper1-spde-slope-gauge-nofit-v2-gate.R"
      ),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(
    source_text,
    r"{!is\.na\(Sys\.readlink\(root\)\) && nzchar\(Sys\.readlink\(root\)\)}"
  )
  expect_match(
    source_text,
    r"{!is\.na\(Sys\.readlink\(output\)\) && nzchar\(Sys\.readlink\(output\)\)}"
  )
  expect_true(is.function(
    materializer$spde_slope_gauge_nofit_v2_materialize_gate
  ))
})

test_that("V2 forensic sealing promotes retained child bytes without relaunch", {
  materializer <- spde_slope_gauge_nofit_v2_materializer_env()
  base <- tempfile("spde-slope-gauge-v2-forensic-")
  dir.create(base)
  base <- normalizePath(base, mustWork = TRUE)
  root <- file.path(base, "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2")
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-forensic")
  dir.create(stage)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  token <- materializer$.spde_slope_gauge_nofit_v2_stage_token(stage, 31001L)
  saveRDS(token, file.path(stage, ".parent-stage.rds"))
  saveRDS(list(unvalidated = TRUE), file.path(stage, "child-result.rds"))
  materializer$.spde_slope_gauge_nofit_v2_atomic_text(
    "child stdout",
    file.path(stage, "child-stdout.txt")
  )
  materializer$.spde_slope_gauge_nofit_v2_atomic_text(
    "child stderr",
    file.path(stage, "child-stderr.txt")
  )
  sources <- materializer$.spde_slope_gauge_nofit_v2_sources()
  process <- list(
    schema = materializer$.spde_slope_gauge_nofit_v2_process_schema(),
    command = R.home("bin/Rscript"),
    arguments = c(
      "--vanilla",
      sources[["child_runner"]],
      "child",
      token$child_output,
      "31001"
    ),
    parent_pid = 31001L,
    child_pid = 31002L,
    observed_child_pid = 31002L,
    started_at = "2026-08-15 00:00:00 UTC",
    ended_at = "2026-08-15 00:00:01 UTC",
    elapsed_s = 1,
    deadline_s = 1800,
    timed_out = FALSE,
    exit_status = 0L,
    signal = NA_character_,
    stdout_md5 = unname(tools::md5sum(file.path(
      stage,
      "child-stdout.txt"
    ))[[1L]]),
    stderr_md5 = unname(tools::md5sum(file.path(
      stage,
      "child-stderr.txt"
    ))[[1L]]),
    child_result_md5 = NA_character_
  )
  verdict <- materializer$.spde_slope_gauge_nofit_v2_forensic_seal(
    stage,
    root,
    sources,
    commit = "synthetic-v2-commit",
    v1 = list(),
    v3 = list(),
    token = token,
    child_run = list(
      process = process,
      child = NULL,
      output = token$child_output
    ),
    seal_failure = "synthetic forced pre-seal error",
    validator = function(...) list(valid = TRUE),
    v1_locked = list(),
    v3_locked = list()
  )
  expect_true(verdict$valid)
  expect_true(dir.exists(root))
  expect_true(file.exists(file.path(root, "unvalidated-child-result.rds")))
  expect_false(file.exists(file.path(root, "child-result.rds")))
  expect_true(file.exists(file.path(root, ".attempt-started.claim")))
  receipt <- readRDS(file.path(root, "root-receipt.rds"))
  expect_identical(receipt$reason, "parent_seal_failure")
  expect_true(is.character(receipt$seal_failure))
  expect_true(is.na(receipt$child_result_md5))
})

test_that("V2 forensic sealing retains the parent error without child bytes", {
  materializer <- spde_slope_gauge_nofit_v2_materializer_env()
  base <- tempfile("spde-slope-gauge-v2-forensic-empty-")
  dir.create(base)
  base <- normalizePath(base, mustWork = TRUE)
  root <- file.path(base, "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2")
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-forensic")
  dir.create(stage)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  token <- materializer$.spde_slope_gauge_nofit_v2_stage_token(stage, 31003L)
  saveRDS(token, file.path(stage, ".parent-stage.rds"))
  sources <- materializer$.spde_slope_gauge_nofit_v2_sources()
  verdict <- materializer$.spde_slope_gauge_nofit_v2_forensic_seal(
    stage,
    root,
    sources,
    commit = "synthetic-v2-commit",
    v1 = list(),
    v3 = list(),
    token = token,
    child_run = list(process = NULL, child = NULL, output = token$child_output),
    seal_failure = "synthetic launcher retention failure",
    validator = function(...) list(valid = TRUE),
    v1_locked = list(),
    v3_locked = list()
  )
  expect_true(verdict$valid)
  receipt <- readRDS(file.path(root, "root-receipt.rds"))
  expect_identical(receipt$reason, "parent_seal_failure")
  expect_identical(receipt$seal_failure, "synthetic launcher retention failure")
  expect_true(is.na(receipt$child_result_md5))
  expect_true(is.na(receipt$unvalidated_child_md5))
  expect_false(file.exists(file.path(root, "unvalidated-child-result.rds")))

  # This is the post-rename path: both the receipt and manifest already exist
  # and must be replaced through the portable recovery sequence.
  verdict <- materializer$.spde_slope_gauge_nofit_v2_forensic_seal(
    root,
    root,
    sources,
    commit = "synthetic-v2-commit",
    v1 = list(),
    v3 = list(),
    token = token,
    child_run = list(process = NULL, child = NULL, output = token$child_output),
    seal_failure = "synthetic post-rename failure",
    validator = function(...) list(valid = TRUE),
    v1_locked = list(),
    v3_locked = list()
  )
  expect_true(verdict$valid)
  receipt <- readRDS(file.path(root, "root-receipt.rds"))
  expect_identical(receipt$seal_failure, "synthetic post-rename failure")
  expect_false(file.exists(file.path(root, "root-receipt.rds.replace-backup")))
  expect_false(file.exists(file.path(root, "file-manifest.csv.replace-backup")))
})

test_that("V2 forensic validation failure retains the post-launch stage", {
  materializer <- spde_slope_gauge_nofit_v2_materializer_env()
  base <- tempfile("spde-slope-gauge-v2-forensic-invalid-")
  dir.create(base)
  base <- normalizePath(base, mustWork = TRUE)
  root <- file.path(base, "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2")
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-invalid")
  dir.create(stage)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  token <- materializer$.spde_slope_gauge_nofit_v2_stage_token(stage, 31004L)
  saveRDS(token, file.path(stage, ".parent-stage.rds"))
  sources <- materializer$.spde_slope_gauge_nofit_v2_sources()
  expect_error(
    materializer$.spde_slope_gauge_nofit_v2_forensic_seal(
      stage,
      root,
      sources,
      commit = "synthetic-v2-commit",
      v1 = list(),
      v3 = list(),
      token = token,
      child_run = list(
        process = NULL,
        child = NULL,
        output = token$child_output
      ),
      seal_failure = "synthetic validator failure",
      validator = function(...) {
        list(valid = FALSE, reason = "synthetic invalid")
      },
      v1_locked = list(),
      v3_locked = list()
    ),
    "could not promote V2 forensic terminal"
  )
  expect_false(dir.exists(root))
  expect_true(dir.exists(stage))
  expect_true(file.exists(file.path(stage, "root-receipt.rds")))
  expect_identical(
    materializer$.spde_slope_gauge_nofit_v2_stale_stages(base),
    normalizePath(stage, mustWork = TRUE)
  )
})
