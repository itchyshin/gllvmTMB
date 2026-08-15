spde_slope_gauge_nofit_materializer_env <- function() {
  path <- testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "materialize-paper1-spde-slope-gauge-nofit-gate.R"
  )
  lines <- readLines(path, warn = FALSE)
  start <- grep("^\\.spde_slope_gauge_nofit_materializer_atomic_rds <-", lines)[[1L]]
  end <- grep("^if \\(length\\(args\\)", lines)[[1L]] - 1L
  env <- new.env(parent = baseenv())
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-contract.R"
  ), local = env)
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-nofit-contract.R"
  ), local = env)
  env$script_dir <- tempfile("spde-slope-gauge-materializer-script-")
  dir.create(env$script_dir)
  env$script_path <- file.path(env$script_dir, "materializer.R")
  eval(parse(text = lines[start:end]), envir = env)
  env
}

test_that("the no-fit materializer is a parent-side lifecycle adapter, not an estimator", {
  path <- testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "materialize-paper1-spde-slope-gauge-nofit-gate.R"
  )
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_silent(parse(path))
  expect_match(text, "run-paper1-spde-slope-gauge-nofit.R", fixed = TRUE)
  expect_match(text, "spde_slope_gauge_nofit_validate_gate_root", fixed = TRUE)
  expect_match(text, "file.rename(stage, root)", fixed = TRUE)
  expect_match(text, "requireNamespace(\"processx\"", fixed = TRUE)
  expect_match(text, "timeout = 1800 * 1000", fixed = TRUE)
  expect_false(grepl("TMB::MakeADFun|stats::optim|nlminb|dyn.unload|gllvmTMB\\(", text))
  child <- regexpr("run_fun <- processx::run", text, fixed = TRUE)[[1L]]
  seal <- regexpr("file.rename\\(stage, root\\)", text)[[1L]]
  validate <- regexpr("spde_slope_gauge_nofit_validate_gate_root\\(root, sources, commit", text)[[1L]]
  expect_gt(child, 0L)
  expect_gt(seal, child)
  expect_gt(validate, seal)
})

test_that("the parent materializer retains only a tokenized staging child and writes artifacts atomically", {
  materializer <- spde_slope_gauge_nofit_materializer_env()
  base <- tempfile("spde-slope-gauge-materializer-base-")
  dir.create(base)
  on.exit(unlink(c(base, materializer$script_dir), recursive = TRUE), add = TRUE)
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-test")
  dir.create(stage)
  token <- materializer$.spde_slope_gauge_nofit_materializer_stage_token(stage, 101L)
  expect_identical(token$gate_base, normalizePath(base))
  expect_identical(token$stage, normalizePath(stage))
  expect_identical(token$child_output, file.path(normalizePath(stage), "child-result.rds"))
  output <- file.path(stage, "artifact.rds")
  expect_silent(materializer$.spde_slope_gauge_nofit_materializer_atomic_rds(list(ok = TRUE), output))
  expect_identical(readRDS(output), list(ok = TRUE))
  expect_error(materializer$.spde_slope_gauge_nofit_materializer_atomic_rds(list(ok = FALSE), output),
    "fresh regular path")
})

test_that("the supervised child seam retains observed timeout/no-result process evidence", {
  materializer <- spde_slope_gauge_nofit_materializer_env()
  base <- tempfile("spde-slope-gauge-materializer-child-")
  dir.create(base)
  on.exit(unlink(c(base, materializer$script_dir), recursive = TRUE), add = TRUE)
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-child")
  dir.create(stage)
  fake_run <- function(command, arguments, timeout, error_on_status, echo) {
    expect_identical(timeout, 1800 * 1000)
    expect_identical(arguments[[1L]], "--vanilla")
    list(status = NA_integer_, stdout = "", stderr = "deadline exceeded", timed_out = TRUE)
  }
  observed <- materializer$.spde_slope_gauge_nofit_materializer_child(stage, 101L, fake_run)
  expect_null(observed$child)
  expect_true(observed$process$timed_out)
  expect_true(is.na(observed$process$exit_status))
  expect_true(is.na(observed$process$child_pid))
  expect_true(is.na(observed$process$child_result_md5))
  expect_false(file.exists(file.path(stage, ".child-stdout.txt")))
  expect_false(file.exists(file.path(stage, ".child-stderr.txt")))

  corrupt_stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-corrupt")
  dir.create(corrupt_stage)
  corrupt_run <- function(command, arguments, timeout, error_on_status, echo) {
    writeLines("not an RDS", arguments[[4L]])
    list(status = 0L, stdout = "", stderr = "", timed_out = FALSE)
  }
  corrupt <- materializer$.spde_slope_gauge_nofit_materializer_child(corrupt_stage, 101L, corrupt_run)
  expect_null(corrupt$child)
  expect_identical(corrupt$process$exit_status, 0L)
  expect_false(corrupt$process$timed_out)
  expect_false(file.exists(corrupt$output))
})

test_that("a corrupt zero-exit child is scrubbed before the real sealing path selects the no-result inventory", {
  materializer <- spde_slope_gauge_nofit_materializer_env()
  base <- tempfile("spde-slope-gauge-materializer-corrupt-seal-")
  dir.create(base)
  on.exit(unlink(c(base, materializer$script_dir), recursive = TRUE), add = TRUE)
  source_names <- c("child_runner", "pure_contract", "nofit_contract", "historical_contract",
    "design", "materializer")
  sources <- file.path(base, paste0(source_names, ".R"))
  names(sources) <- source_names
  for (path in sources) writeLines(basename(path), path)
  assign("spde_slope_gauge_nofit_validate_gate_root", function(...) {
    list(valid = TRUE, reason = "synthetic_gate_valid")
  }, envir = materializer)
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-corrupt")
  root <- file.path(base, "sealed-corrupt")
  dir.create(stage)
  token <- materializer$.spde_slope_gauge_nofit_materializer_stage_token(stage, 101L)
  saveRDS(token, file.path(stage, ".parent-stage.rds"))
  corrupt_run <- function(command, arguments, timeout, error_on_status, echo) {
    writeLines("not an RDS", arguments[[4L]])
    list(status = 0L, stdout = "", stderr = "", timed_out = FALSE)
  }
  child_run <- materializer$.spde_slope_gauge_nofit_materializer_child(stage, 101L, corrupt_run)
  expect_null(child_run$child)
  expect_false(file.exists(child_run$output))
  sealed_output <- capture.output(verdict <- materializer$.spde_slope_gauge_nofit_materializer_seal(
    stage, root, sources, "synthetic-commit", list(receipt = list(), state_md5 = "x", state = list()),
    token, child_run
  ))
  expect_true(isTRUE(verdict$valid))
  expect_identical(sealed_output, "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD")
  expect_false(file.exists(file.path(root, "no-fit-result.rds")))
  expect_identical(readRDS(file.path(root, "root-receipt.rds"))$reason,
    "child_process_no_result")
})

test_that("the production sealing path retains a reporting malformed child and a non-reporting child distinctly", {
  materializer <- spde_slope_gauge_nofit_materializer_env()
  base <- tempfile("spde-slope-gauge-materializer-seal-")
  dir.create(base)
  on.exit(unlink(c(base, materializer$script_dir), recursive = TRUE), add = TRUE)
  source_names <- c("child_runner", "pure_contract", "nofit_contract", "historical_contract",
    "design", "materializer")
  sources <- file.path(base, paste0(source_names, ".R"))
  names(sources) <- source_names
  for (path in sources) writeLines(basename(path), path)
  assign("spde_slope_gauge_nofit_validate_gate_root", function(...) {
    list(valid = TRUE, reason = "synthetic_gate_valid")
  }, envir = materializer)
  process <- list(schema = "synthetic-process")
  predecessor <- list(receipt = list(), state_md5 = "synthetic-state", state = list())
  seal_once <- function(suffix, child, write_child = FALSE) {
    stage <- file.path(base, paste0(".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-", suffix))
    root <- file.path(base, paste0("root-", suffix))
    dir.create(stage)
    token <- materializer$.spde_slope_gauge_nofit_materializer_stage_token(stage, 101L)
    saveRDS(token, file.path(stage, ".parent-stage.rds"))
    output <- file.path(stage, "child-result.rds")
    if (write_child) saveRDS(child, output)
    materializer$.spde_slope_gauge_nofit_materializer_seal(
      stage, root, sources, "synthetic-commit", predecessor, token,
      list(process = process, child = child, output = output)
    )
    root
  }
  no_result <- seal_once("no-result", NULL)
  expect_true(dir.exists(no_result))
  expect_false(file.exists(file.path(no_result, "no-fit-result.rds")))
  expect_true(file.exists(file.path(no_result, "child-receipt.rds")))
  expect_false(file.exists(file.path(no_result, ".parent-stage.rds")))
  malformed <- seal_once("malformed", list(unreadable = TRUE), write_child = TRUE)
  expect_true(file.exists(file.path(malformed, "no-fit-result.rds")))
  expect_identical(readRDS(file.path(malformed, "root-receipt.rds"))$reason,
    "child_evidence_invalid")
})

test_that("the production sealing path refuses a mutated parent-stage token before it writes a root", {
  materializer <- spde_slope_gauge_nofit_materializer_env()
  base <- tempfile("spde-slope-gauge-materializer-token-")
  dir.create(base)
  on.exit(unlink(c(base, materializer$script_dir), recursive = TRUE), add = TRUE)
  stage <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-token")
  root <- file.path(base, "sealed-root")
  dir.create(stage)
  token <- materializer$.spde_slope_gauge_nofit_materializer_stage_token(stage, 101L)
  bad <- token
  bad$child_output <- file.path(stage, "wrong.rds")
  saveRDS(bad, file.path(stage, ".parent-stage.rds"))
  sources <- stats::setNames(file.path(base, paste0(1:6, ".R")), c(
    "child_runner", "pure_contract", "nofit_contract", "historical_contract", "design", "materializer"
  ))
  for (path in sources) writeLines(basename(path), path)
  expect_error(materializer$.spde_slope_gauge_nofit_materializer_seal(
    stage, root, sources, "synthetic-commit", list(receipt = list(), state_md5 = "x", state = list()),
    token, list(process = list(), child = NULL, output = file.path(stage, "child-result.rds"))
  ), "parent stage token")
  expect_false(dir.exists(root))
})
