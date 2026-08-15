spde_slope_gauge_tr_materializer_env <- function() {
  materializer <- testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery",
    "materialize-paper1-spde-slope-gauge-trust-region.R"
  )
  env <- new.env(parent = baseenv())
  old_source_only <- Sys.getenv("SPDE_SLOPE_GAUGE_TR_MATERIALIZER_SOURCE_ONLY", unset = NA_character_)
  old_path <- Sys.getenv("SPDE_SLOPE_GAUGE_TR_MATERIALIZER_PATH", unset = NA_character_)
  Sys.setenv(
    SPDE_SLOPE_GAUGE_TR_MATERIALIZER_SOURCE_ONLY = "1",
    SPDE_SLOPE_GAUGE_TR_MATERIALIZER_PATH = materializer
  )
  on.exit({
    if (is.na(old_source_only)) Sys.unsetenv("SPDE_SLOPE_GAUGE_TR_MATERIALIZER_SOURCE_ONLY") else {
      Sys.setenv(SPDE_SLOPE_GAUGE_TR_MATERIALIZER_SOURCE_ONLY = old_source_only)
    }
    if (is.na(old_path)) Sys.unsetenv("SPDE_SLOPE_GAUGE_TR_MATERIALIZER_PATH") else {
      Sys.setenv(SPDE_SLOPE_GAUGE_TR_MATERIALIZER_PATH = old_path)
    }
  }, add = TRUE)
  source(materializer, local = env)
  env$.spde_slope_gauge_tr_materializer_expected_dll <- function(locked) {
    list(
      path = normalizePath(materializer, mustWork = TRUE),
      md5 = unname(tools::md5sum(materializer))[[1L]]
    )
  }
  env
}

spde_slope_gauge_tr_materializer_predecessor <- function(env) {
  root <- tempfile("spde-slope-gauge-tr-materializer-predecessor-")
  dir.create(root)
  root <- normalizePath(root, mustWork = TRUE)
  files <- c(
    "all-attempt-ledger.rds", "attempt-started.rds", "file-manifest.csv",
    "root-receipt.rds", "session-info.rds", "time-estimate.md", "v2-materialized-state.rds"
  )
  order <- env$spde_slope_gauge_raw_order()
  state <- list(
    schema = "MSPDE_P1_S3_C360_R3_V3_MATERIALIZED_V2_STATE_V1",
    objective = as.double(0.5 * sum(stats::setNames(seq(-0.8, 0.8, length.out = 22L), order)^2)),
    theta = stats::setNames(seq(-0.8, 0.8, length.out = 22L), order),
    gradient = stats::setNames(seq(-0.8, 0.8, length.out = 22L), order),
    convergence = 0L,
    covariance = list(),
    start_provenance = list(),
    restart_history = data.frame(),
    warm_restart_provenance = list(),
    isdm_polish_provenance = list(),
    parameters = list(),
    map = list(),
    data = list(),
    random = c("s_B", "g_spde_slope"),
    block_labels = c(
      rep("b_fix", 12L), rep("theta_diag_B", 3L), "log_kappa_spde",
      rep("theta_rr_spde_slope", 6L)
    ),
    parameter_order = order
  )
  receipt <- list(
    schema = "MSPDE_P1_S3_C360_R3_V3_CLOSEOUT_PREFLIGHT_V1",
    source_gate = "fixture",
    root = root,
    commit = paste(rep("a", 40L), collapse = ""),
    consumed_v2 = list(),
    runner_md5 = paste(rep("1", 32L), collapse = ""),
    contract_md5 = paste(rep("2", 32L), collapse = ""),
    design_md5 = paste(rep("3", 32L), collapse = "")
  )
  saveRDS(list(), file.path(root, "all-attempt-ledger.rds"))
  saveRDS(list(), file.path(root, "attempt-started.rds"))
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  saveRDS(list(), file.path(root, "session-info.rds"))
  saveRDS(state, file.path(root, "v2-materialized-state.rds"))
  writeLines("fixture", file.path(root, "time-estimate.md"))
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(data.frame(
    path = declared,
    md5 = unname(tools::md5sum(file.path(root, declared))),
    stringsAsFactors = FALSE
  ), file.path(root, "file-manifest.csv"), row.names = FALSE, quote = TRUE)
  dir.create(file.path(root, ".attempt-started.claim"))
  locked <- list(
    root = root,
    commit = receipt$commit,
    files = stats::setNames(tools::md5sum(file.path(root, files)), files),
    directory = ".attempt-started.claim",
    receipt_schema = receipt$schema,
    state_schema = state$schema
  )
  list(root = root, locked = locked)
}

spde_slope_gauge_tr_materializer_packet <- function(env, predecessor) {
  root <- tempfile("spde-slope-gauge-tr-materializer-packet-")
  dir.create(root)
  root <- normalizePath(root, mustWork = TRUE)
  source_dir <- tempfile("spde-slope-gauge-tr-materializer-sources-")
  dir.create(source_dir)
  source_names <- c(
    "runner", "gauge_contract", "sign_contract", "trust_contract",
    "adapter", "smoke_contract", "design", "materializer", "historical_contract"
  )
  sources <- stats::setNames(file.path(source_dir, source_names), source_names)
  for (path in sources) writeLines(basename(path), path)
  copies <- c(
    "predecessor-v3-ledger.rds" = "all-attempt-ledger.rds",
    "predecessor-v3-marker.rds" = "attempt-started.rds",
    "predecessor-v3-receipt.rds" = "root-receipt.rds",
    "v3-materialized-state.rds" = "v2-materialized-state.rds"
  )
  saveRDS(env$spde_slope_gauge_trust_region_controls(), file.path(root, "control.rds"))
  for (name in names(copies)) {
    file.copy(file.path(predecessor$root, copies[[name]]), file.path(root, name))
  }
  writeLines("fixture materializer", file.path(root, "materializer.R"))
  saveRDS(list(session = "fixture"), file.path(root, "session-info.rds"))
  writeLines("fixture estimate", file.path(root, "time-estimate.md"))
  proof <- env$spde_slope_gauge_trust_region_validate_predecessor_bytes(
    predecessor$root, predecessor$locked
  )
  commit <- paste(rep("b", 40L), collapse = "")
  receipt <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PREFLIGHT_V1",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1",
    root = root,
    commit = commit,
    sources = stats::setNames(unname(tools::md5sum(sources)), names(sources)),
    predecessor = proof[c("root", "commit", "receipt", "state_md5")],
    dll = env$.spde_slope_gauge_tr_materializer_expected_dll(predecessor$locked),
    control_md5 = unname(tools::md5sum(file.path(root, "control.rds")))[[1L]],
    state_md5 = predecessor$locked$files[["v2-materialized-state.rds"]],
    session_info_md5 = unname(tools::md5sum(file.path(root, "session-info.rds")))[[1L]],
    time_estimate_md5 = unname(tools::md5sum(file.path(root, "time-estimate.md")))[[1L]]
  )
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    root, env$.spde_slope_gauge_tr_materializer_files()
  )
  list(root = root, source_dir = source_dir, sources = sources, commit = commit)
}

spde_slope_gauge_tr_materializer_rebind_packet_dll <- function(env, packet, dll) {
  receipt_path <- file.path(packet$root, "root-receipt.rds")
  receipt <- readRDS(receipt_path)
  receipt$dll <- dll
  saveRDS(receipt, receipt_path)
  unlink(file.path(packet$root, "file-manifest.csv"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_files()
  )
  invisible(receipt)
}

spde_slope_gauge_tr_materializer_process <- function(child, runner, mode, output, parent_pid = 101L) {
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PROCESS_V1",
    command = "/usr/bin/Rscript",
    arguments = c("--vanilla", runner, mode, output, as.character(parent_pid)),
    parent_pid = parent_pid,
    child_pid = child$child_pid,
    started_at = "2026-08-15 12:00:00 UTC",
    ended_at = "2026-08-15 12:00:01 UTC",
    elapsed_s = 1,
    deadline_s = 1800L,
    timed_out = FALSE,
    exit_status = 0L,
    signal = NA_character_,
    stdout_md5 = NA_character_,
    stderr_md5 = NA_character_,
    child_result_md5 = unname(tools::md5sum(output))[[1L]]
  )
}

spde_slope_gauge_tr_materializer_complete_worker <- function(env, receipt, state, dll, parent_pid) {
  adapter_path <- testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-trust-region-adapter.R"
  )
  source(adapter_path, local = env)
  raw_order <- env$spde_slope_gauge_raw_order()
  object <- list(
    par = state$theta,
    fn = function(x) as.double(0.5 * sum(x * x)),
    gr = function(x) stats::setNames(as.double(x), raw_order)
  )
  nofit <- env$spde_slope_gauge_validate_no_fit_state(
    state[c("theta", "objective", "gradient")],
    objective_fn = object$fn,
    gradient_fn = object$gr
  )
  nofit["gradient_callback"] <- list(list(
    supplied_names = raw_order,
    raw_values = as.double(nofit$raw_gradient),
    named_gradient = nofit$raw_gradient,
    mapping = list(
      supplied_names = NULL,
      object_order = state$block_labels,
      parameter_order = raw_order,
      block_labels = state$block_labels,
      raw_order = raw_order
    )
  ))
  adapter <- env$spde_slope_gauge_trust_region_callback_adapter(
    object, 1L, dll$path, dll$md5,
    function(object, raw_theta) {
      covariance <- diag(22L)
      dimnames(covariance) <- list(raw_order, raw_order)
      list(par.fixed = raw_theta, cov.fixed = covariance, pdHess = TRUE)
    }
  )
  trust_region <- env$spde_slope_gauge_trust_region(
    env$spde_slope_gauge_phi_from_theta(state$theta), adapter$evaluate, adapter$covariance
  )
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_CHILD_V1",
    parent_pid = parent_pid, child_pid = 103L,
    started_at = "2026-08-15 12:00:02 UTC", ended_at = "2026-08-15 12:00:03 UTC",
    elapsed_s = 1, predecessor = receipt$predecessor,
    state_md5 = receipt$state_md5, dll = dll,
    object = list(created = 1L, released = 1L), nofit = nofit,
    sign_orbit = list(valid = TRUE), trust_region = trust_region, audit = adapter$audit(),
    status = trust_region$status, reason = trust_region$reason,
    stage = "complete", completed_stage = "complete", error = NA_character_
  )
}

test_that("the materializer preflight validator accepts only the complete copied predecessor packet", {
  env <- spde_slope_gauge_tr_materializer_env()
  predecessor <- spde_slope_gauge_tr_materializer_predecessor(env)
  packet <- spde_slope_gauge_tr_materializer_packet(env, predecessor)
  on.exit(unlink(c(predecessor$root, packet$root, packet$source_dir), recursive = TRUE), add = TRUE)

  accepted <- env$spde_slope_gauge_trust_region_validate_preflight_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked
  )
  expect_identical(accepted, list(valid = TRUE, reason = "trust_region_preflight_valid"))

  receipt <- readRDS(file.path(packet$root, "root-receipt.rds"))
  receipt$dll$md5 <- paste(rep("0", 32L), collapse = "")
  saveRDS(receipt, file.path(packet$root, "root-receipt.rds"))
  unlink(file.path(packet$root, "file-manifest.csv"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_files()
  )
  dll_tamper <- env$spde_slope_gauge_trust_region_validate_preflight_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked
  )
  expect_identical(dll_tamper$reason, "preflight_receipt_or_predecessor_invalid")

  receipt <- readRDS(file.path(packet$root, "root-receipt.rds"))
  receipt$sources[["runner"]] <- paste(rep("0", 32L), collapse = "")
  saveRDS(receipt, file.path(packet$root, "root-receipt.rds"))
  unlink(file.path(packet$root, "file-manifest.csv"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_files()
  )
  source_tamper <- env$spde_slope_gauge_trust_region_validate_preflight_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked
  )
  expect_identical(source_tamper$reason, "preflight_receipt_or_predecessor_invalid")

  writeLines("extra", file.path(packet$root, "extra.txt"))
  extra_file <- env$spde_slope_gauge_trust_region_validate_preflight_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked
  )
  expect_identical(extra_file$reason, "preflight_packet_bytes_invalid")
})

test_that("materializer artifact writers retain fresh-target and manifest semantics", {
  env <- spde_slope_gauge_tr_materializer_env()
  root <- tempfile("spde-slope-gauge-tr-materializer-atomic-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  path <- file.path(root, "artifact.rds")

  expect_identical(env$.spde_slope_gauge_tr_materializer_atomic_rds(list(ok = TRUE), path), path)
  expect_error(
    env$.spde_slope_gauge_tr_materializer_atomic_rds(list(ok = TRUE), path),
    "artifact target is not fresh"
  )
})

test_that("the parent supervisor records a clean isolated child exit", {
  skip_if_not_installed("processx")
  env <- spde_slope_gauge_tr_materializer_env()
  rscript <- file.path(R.home("bin"), "Rscript")

  captured <- capture.output(
    finished <- env$.spde_slope_gauge_tr_materializer_launch_child(
      rscript, c("--vanilla", "-e", "cat('child-ok')"), deadline_s = 2L
    ), type = "message"
  )
  expect_length(captured, 0L)
  expect_identical(finished$exit_status, 0L)
  expect_false(finished$timed_out)
  expect_identical(finished$error, NA_character_)
  expect_match(finished$stdout, "child-ok", fixed = TRUE)
  expect_true(is.finite(finished$elapsed_s))

  timed <- env$.spde_slope_gauge_tr_materializer_launch_child(
    rscript, c("--vanilla", "-e", "Sys.sleep(3)"), deadline_s = 1L
  )
  expect_true(timed$timed_out)
  expect_identical(timed$exit_status, NA_integer_)
  expect_identical(timed$error, "parent child deadline exceeded")
  expect_true(is.finite(timed$elapsed_s))
})

test_that("terminal packets retain the preflight bindings and select their exact fallback inventory", {
  env <- spde_slope_gauge_tr_materializer_env()
  predecessor <- spde_slope_gauge_tr_materializer_predecessor(env)
  packet <- spde_slope_gauge_tr_materializer_packet(env, predecessor)
  on.exit(unlink(c(predecessor$root, packet$root, packet$source_dir), recursive = TRUE), add = TRUE)

  receipt <- readRDS(file.path(packet$root, "root-receipt.rds"))
  marker <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ATTEMPT_STARTED_V1",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1",
    root = packet$root,
    commit = packet$commit,
    parent_pid = 101L,
    receipt_md5 = unname(tools::md5sum(file.path(packet$root, "root-receipt.rds")))[[1L]],
    started_at = "2026-08-15 12:00:00 UTC"
  )
  dll_path <- tempfile("spde-slope-gauge-tr-terminal-dll-")
  writeLines("fixture DLL", dll_path)
  on.exit(unlink(dll_path), add = TRUE)
  expected_dll <- list(
    path = normalizePath(dll_path, mustWork = TRUE),
    md5 = unname(tools::md5sum(dll_path))[[1L]]
  )
  child <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_V3_LIVE_CHILD_V1",
    parent_pid = 101L,
    child_pid = 102L,
    started_at = "2026-08-15 12:00:00 UTC",
    ended_at = "2026-08-15 12:00:01 UTC",
    elapsed_s = 1,
    status = "GAUGE_TRUST_REGION_V3_LIVE_VALID",
    reason = "closeout_recomputed",
    predecessor = receipt$predecessor,
    dll = expected_dll,
    error = NA_character_
  )
  ledger <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ALL_ATTEMPT_V1",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1",
    root = packet$root,
    commit = packet$commit,
    terminal = TRUE,
    receipt = receipt,
    marker = marker,
    worker = NULL,
    v3_live_child = child,
    processes = list(v3_live = NULL, worker = NULL),
    predecessor = receipt$predecessor,
    controls = readRDS(file.path(packet$root, "control.rds")),
    trust_region = NULL,
    checks = c(predecessor = TRUE, infrastructure = FALSE, numerical = FALSE, terminal_evidence = FALSE),
    status = "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD",
    reason = "parent_unwind",
    error = "synthetic parent unwind before the worker launch",
    timing = list(total_s = 1)
  )
  saveRDS(marker, file.path(packet$root, "attempt-started.rds"))
  saveRDS(child, file.path(packet$root, "v3-live-child.rds"))
  ledger$processes$v3_live <- spde_slope_gauge_tr_materializer_process(
    child, packet$sources[["runner"]], "v3-live-child",
    file.path(packet$root, "v3-live-child.rds")
  )
  dir.create(file.path(packet$root, ".attempt-started.claim"))
  saveRDS(ledger, file.path(packet$root, "all-attempt-ledger.rds"))
  unlink(file.path(packet$root, "file-manifest.csv"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_terminal_files(ledger)
  )

  expect_true(env$.spde_slope_gauge_tr_materializer_marker_ok(
    marker, receipt, packet$root, packet$commit
  ))
  expect_true(env$spde_slope_gauge_trust_region_v3_live_child_ok(
    child, receipt$predecessor, expected_dll
  ))

  accepted <- env$spde_slope_gauge_trust_region_validate_terminal_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )
  expect_identical(accepted, list(valid = TRUE, reason = "terminal_infrastructure_fallback_valid"))

  reason_tamper <- readRDS(file.path(packet$root, "all-attempt-ledger.rds"))
  reason_tamper$reason <- "worker_process_no_result"
  saveRDS(reason_tamper, file.path(packet$root, "all-attempt-ledger.rds"))
  unlink(file.path(packet$root, "file-manifest.csv"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_terminal_files(reason_tamper)
  )
  reason_rejected <- env$spde_slope_gauge_trust_region_validate_terminal_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )
  expect_identical(reason_rejected$reason, "terminal_worker_projection_invalid")

  saveRDS(ledger, file.path(packet$root, "all-attempt-ledger.rds"))
  unlink(file.path(packet$root, "file-manifest.csv"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_terminal_files(ledger)
  )

  process_tamper <- readRDS(file.path(packet$root, "all-attempt-ledger.rds"))
  process_tamper$processes$v3_live$arguments[[3L]] <- "worker-child"
  saveRDS(process_tamper, file.path(packet$root, "all-attempt-ledger.rds"))
  unlink(file.path(packet$root, "file-manifest.csv"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_terminal_files(process_tamper)
  )
  process_rejected <- env$spde_slope_gauge_trust_region_validate_terminal_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )
  expect_identical(process_rejected$reason, "terminal_v3_child_projection_invalid")

  saveRDS(ledger, file.path(packet$root, "all-attempt-ledger.rds"))
  unlink(file.path(packet$root, "file-manifest.csv"))
  env$.spde_slope_gauge_tr_materializer_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_terminal_files(ledger)
  )

  saveRDS(list(stale = TRUE), file.path(packet$root, "worker-result.rds"))
  rejected <- env$spde_slope_gauge_trust_region_validate_terminal_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )
  expect_identical(rejected$reason, "terminal_packet_bytes_invalid")
})

test_that("the production terminal projection preserves a typed fallback when no worker receipt exists", {
  env <- spde_slope_gauge_tr_materializer_env()
  receipt <- list(predecessor = list(root = "/sealed/v3"))
  ledger <- env$spde_slope_gauge_trust_region_terminal_from_worker(
    root = "/sealed/gauge", commit = paste(rep("a", 40L), collapse = ""),
    receipt = receipt, marker = NULL, v3_live_child = NULL,
    controls = env$spde_slope_gauge_trust_region_controls(), timing = list(total_s = 1)
  )

  expect_identical(names(ledger), env$spde_slope_gauge_trust_region_terminal_fields())
  expect_null(ledger$worker)
  expect_null(ledger$v3_live_child)
  expect_identical(ledger$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")
  expect_true(env$spde_slope_gauge_trust_region_validate_terminal_ledger(ledger)$valid)
})

test_that("the supervised child launcher rejects malformed inputs before it can start a process", {
  env <- spde_slope_gauge_tr_materializer_env()
  expect_error(
    env$.spde_slope_gauge_tr_materializer_launch_child("", character(), 1800L),
    "isolated child launch inputs are invalid"
  )
  expect_error(
    env$.spde_slope_gauge_tr_materializer_launch_child("Rscript", character(), 0L),
    "isolated child launch inputs are invalid"
  )
})

test_that("a timed-out worker with no child result retains a typed process receipt", {
  env <- spde_slope_gauge_tr_materializer_env()
  launch <- list(
    exit_status = NA_integer_, child_pid = 102L, timed_out = TRUE,
    error = "parent child deadline exceeded", started_at = "2026-08-15 12:00:00 UTC",
    ended_at = "2026-08-15 12:30:00 UTC", elapsed_s = 1800
  )
  arguments <- c("--vanilla", "/sealed/runner.R", "worker-child", "/stage/worker-result.rds", "101")
  process <- env$.spde_slope_gauge_tr_materializer_no_result_process(
    launch, "/usr/bin/Rscript", arguments, 101L
  )
  expect_true(env$.spde_slope_gauge_tr_materializer_process_no_result_ok(
    process, "/sealed/runner.R", "worker-child", "worker-result.rds", 101L
  ))
  process$error <- NA_character_
  expect_false(env$.spde_slope_gauge_tr_materializer_process_no_result_ok(
    process, "/sealed/runner.R", "worker-child", "worker-result.rds", 101L
  ))
})

test_that("a parent-authenticated sibling stage is the only destination given to a child launcher", {
  env <- spde_slope_gauge_tr_materializer_env()
  parent <- env$.spde_slope_gauge_tr_materializer_parent_stage(tempdir(), 101L)
  on.exit(unlink(parent$stage, recursive = TRUE), add = TRUE)
  observed <- NULL
  fake_launch <- function(command, arguments, deadline_s) {
    observed <<- list(command = command, arguments = arguments, deadline_s = deadline_s)
    saveRDS(list(schema = "synthetic-child"), arguments[[4L]])
    list(
      exit_status = 0L, child_pid = 102L, timed_out = FALSE,
      stdout = "", stderr = "", error = NA_character_,
      started_at = "2026-08-15 12:00:00 UTC", ended_at = "2026-08-15 12:00:01 UTC",
      elapsed_s = 1
    )
  }
  launched <- env$.spde_slope_gauge_tr_materializer_run_staged_child(
    parent$token, "/sealed/runner.R", "v3-live-child", fake_launch
  )

  expect_identical(list.files(parent$stage, all.files = TRUE, no.. = TRUE),
    c(".parent-stage.rds", "v3-live-child.rds"))
  expect_identical(launched$output, parent$token$v3_live_output)
  expect_identical(observed$arguments,
    c("--vanilla", "/sealed/runner.R", "v3-live-child", parent$token$v3_live_output, "101"))
  expect_identical(observed$deadline_s, 1800L)
  expect_identical(launched$child, list(schema = "synthetic-child"))

  launched$child$child_pid <- 102L
  success <- env$.spde_slope_gauge_tr_materializer_success_process(
    launched$launch, launched$command, launched$arguments, 101L,
    launched$child, launched$output
  )
  expect_true(env$spde_slope_gauge_trust_region_validate_process_receipt(
    success, launched$command, launched$arguments, 101L, 102L
  ))
})

test_that("the production parent seals a no-result worker fallback without starting TMB", {
  env <- spde_slope_gauge_tr_materializer_env()
  predecessor <- spde_slope_gauge_tr_materializer_predecessor(env)
  packet <- spde_slope_gauge_tr_materializer_packet(env, predecessor)
  on.exit(unlink(c(predecessor$root, packet$root, packet$source_dir), recursive = TRUE), add = TRUE)
  dll_path <- tempfile("spde-slope-gauge-tr-smoke-dll-")
  writeLines("fixture DLL", dll_path)
  on.exit(unlink(dll_path), add = TRUE)
  expected_dll <- list(
    path = normalizePath(dll_path, mustWork = TRUE),
    md5 = unname(tools::md5sum(dll_path))[[1L]]
  )
  receipt <- readRDS(file.path(packet$root, "root-receipt.rds"))
  original_preflight <- env$spde_slope_gauge_trust_region_validate_preflight_packet
  env$.spde_slope_gauge_tr_materializer_root <- function() packet$root
  env$.spde_slope_gauge_tr_materializer_sources <- function() packet$sources
  env$.spde_slope_gauge_tr_materializer_commit <- function() packet$commit
  env$spde_slope_gauge_trust_region_locked_predecessor <- function() predecessor$locked
  env$.spde_slope_gauge_tr_materializer_expected_dll <- function(locked) expected_dll
  env$spde_slope_gauge_trust_region_validate_preflight_packet <- function(...) {
    spde_slope_gauge_tr_materializer_rebind_packet_dll(env, packet, expected_dll)
    original_preflight(
      packet$root, packet$sources, packet$commit, expected_root = packet$root,
      locked = predecessor$locked
    )
  }
  fake_launch <- function(command, arguments, deadline_s) {
    if (identical(arguments[[3L]], "v3-live-child")) {
      child <- list(
        schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_V3_LIVE_CHILD_V1",
        parent_pid = as.integer(arguments[[5L]]), child_pid = 102L,
        started_at = "2026-08-15 12:00:00 UTC", ended_at = "2026-08-15 12:00:01 UTC",
        elapsed_s = 1, status = "GAUGE_TRUST_REGION_V3_LIVE_VALID",
        reason = "closeout_recomputed", predecessor = receipt$predecessor,
        dll = expected_dll, error = NA_character_
      )
      saveRDS(child, arguments[[4L]])
      return(list(
        exit_status = 0L, child_pid = 102L, timed_out = FALSE,
        stdout = "", stderr = "", error = NA_character_,
        started_at = "2026-08-15 12:00:00 UTC", ended_at = "2026-08-15 12:00:01 UTC",
        elapsed_s = 1
      ))
    }
    list(
      exit_status = 1L, child_pid = 103L, timed_out = FALSE,
      stdout = "", stderr = "worker exited without a receipt", error = "worker exited without a receipt",
      started_at = "2026-08-15 12:00:02 UTC", ended_at = "2026-08-15 12:00:03 UTC",
      elapsed_s = 1
    )
  }

  sealed <- tryCatch(
    env$spde_slope_gauge_trust_region_smoke(fake_launch),
    error = function(e) e
  )
  expect_false(inherits(sealed, "error"))
  ledger <- readRDS(file.path(packet$root, "all-attempt-ledger.rds"))
  expect_true(env$spde_slope_gauge_trust_region_v3_live_child_ok(
    ledger$v3_live_child, receipt$predecessor, expected_dll
  ))
  expect_true(env$.spde_slope_gauge_tr_materializer_process_for_child_ok(
    ledger$processes$v3_live, ledger$v3_live_child, packet$sources[["runner"]], "v3-live-child",
    file.path(packet$root, "v3-live-child.rds"), ledger$marker$parent_pid
  ))
  expect_identical(sealed, list(valid = TRUE, reason = "trust_region_terminal_sealed"))
  expect_identical(ledger$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")
  expect_identical(ledger$reason, "worker_process_no_result")
  expect_null(ledger$worker)
  expect_true(env$.spde_slope_gauge_tr_materializer_process_no_result_ok(
    ledger$processes$worker, packet$sources[["runner"]], "worker-child", "worker-result.rds",
    ledger$marker$parent_pid
  ))
  terminal <- env$spde_slope_gauge_trust_region_validate_terminal_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )
  expect_identical(terminal, list(valid = TRUE, reason = "terminal_infrastructure_fallback_valid"))
})

test_that("the production parent retains a valid partial worker prefix without starting TMB", {
  env <- spde_slope_gauge_tr_materializer_env()
  predecessor <- spde_slope_gauge_tr_materializer_predecessor(env)
  packet <- spde_slope_gauge_tr_materializer_packet(env, predecessor)
  on.exit(unlink(c(predecessor$root, packet$root, packet$source_dir), recursive = TRUE), add = TRUE)
  dll_path <- tempfile("spde-slope-gauge-tr-partial-dll-")
  writeLines("fixture DLL", dll_path)
  on.exit(unlink(dll_path), add = TRUE)
  expected_dll <- list(
    path = normalizePath(dll_path, mustWork = TRUE),
    md5 = unname(tools::md5sum(dll_path))[[1L]]
  )
  receipt <- readRDS(file.path(packet$root, "root-receipt.rds"))
  original_preflight <- env$spde_slope_gauge_trust_region_validate_preflight_packet
  env$.spde_slope_gauge_tr_materializer_root <- function() packet$root
  env$.spde_slope_gauge_tr_materializer_sources <- function() packet$sources
  env$.spde_slope_gauge_tr_materializer_commit <- function() packet$commit
  env$spde_slope_gauge_trust_region_locked_predecessor <- function() predecessor$locked
  env$.spde_slope_gauge_tr_materializer_expected_dll <- function(locked) expected_dll
  env$spde_slope_gauge_trust_region_validate_preflight_packet <- function(...) {
    spde_slope_gauge_tr_materializer_rebind_packet_dll(env, packet, expected_dll)
    original_preflight(
      packet$root, packet$sources, packet$commit, expected_root = packet$root,
      locked = predecessor$locked
    )
  }
  fake_launch <- function(command, arguments, deadline_s) {
    parent_pid <- as.integer(arguments[[5L]])
    if (identical(arguments[[3L]], "v3-live-child")) {
      child <- list(
        schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_V3_LIVE_CHILD_V1",
        parent_pid = parent_pid, child_pid = 102L,
        started_at = "2026-08-15 12:00:00 UTC", ended_at = "2026-08-15 12:00:01 UTC",
        elapsed_s = 1, status = "GAUGE_TRUST_REGION_V3_LIVE_VALID",
        reason = "closeout_recomputed", predecessor = receipt$predecessor,
        dll = expected_dll, error = NA_character_
      )
      saveRDS(child, arguments[[4L]])
      return(list(
        exit_status = 0L, child_pid = 102L, timed_out = FALSE,
        stdout = "", stderr = "", error = NA_character_,
        started_at = "2026-08-15 12:00:00 UTC", ended_at = "2026-08-15 12:00:01 UTC",
        elapsed_s = 1
      ))
    }
    worker <- list(
      schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_CHILD_V1",
      parent_pid = parent_pid, child_pid = 103L,
      started_at = "2026-08-15 12:00:02 UTC", ended_at = "2026-08-15 12:00:03 UTC",
      elapsed_s = 1, predecessor = receipt$predecessor, state_md5 = receipt$state_md5,
      dll = expected_dll, object = list(created = 1L, released = 1L), nofit = NULL, sign_orbit = NULL,
      trust_region = NULL, audit = NULL, status = "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD",
      reason = "fresh_object_unavailable", stage = "factory", completed_stage = "factory",
      error = "synthetic factory failure"
    )
    saveRDS(worker, arguments[[4L]])
    list(
      exit_status = 0L, child_pid = 103L, timed_out = FALSE,
      stdout = "", stderr = "", error = NA_character_,
      started_at = "2026-08-15 12:00:02 UTC", ended_at = "2026-08-15 12:00:03 UTC",
      elapsed_s = 1
    )
  }

  sealed <- env$spde_slope_gauge_trust_region_smoke(fake_launch)
  ledger <- readRDS(file.path(packet$root, "all-attempt-ledger.rds"))
  expect_identical(sealed, list(valid = TRUE, reason = "trust_region_terminal_sealed"))
  expect_identical(ledger$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")
  expect_identical(ledger$reason, "fresh_object_unavailable")
  expect_true(env$spde_slope_gauge_trust_region_worker_ok(ledger$worker, receipt$predecessor))
  expect_true(env$.spde_slope_gauge_tr_materializer_process_for_child_ok(
    ledger$processes$worker, ledger$worker, packet$sources[["runner"]], "worker-child",
    file.path(packet$root, "worker-result.rds"), ledger$marker$parent_pid
  ))
  terminal <- env$spde_slope_gauge_trust_region_validate_terminal_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )
  expect_identical(terminal, list(valid = TRUE, reason = "terminal_partial_worker_evidence_valid"))
})

test_that("the disk terminal validator rejects a complete no-fit trace that is not the copied V3 state", {
  env <- spde_slope_gauge_tr_materializer_env()
  predecessor <- spde_slope_gauge_tr_materializer_predecessor(env)
  packet <- spde_slope_gauge_tr_materializer_packet(env, predecessor)
  on.exit(unlink(c(predecessor$root, packet$root, packet$source_dir), recursive = TRUE), add = TRUE)
  dll_path <- tempfile("spde-slope-gauge-tr-state-binding-dll-")
  writeLines("fixture DLL", dll_path)
  on.exit(unlink(dll_path), add = TRUE)
  expected_dll <- list(
    path = normalizePath(dll_path, mustWork = TRUE),
    md5 = unname(tools::md5sum(dll_path))[[1L]]
  )
  receipt <- readRDS(file.path(packet$root, "root-receipt.rds"))
  state <- readRDS(file.path(packet$root, "v3-materialized-state.rds"))
  original_preflight <- env$spde_slope_gauge_trust_region_validate_preflight_packet
  env$.spde_slope_gauge_tr_materializer_root <- function() packet$root
  env$.spde_slope_gauge_tr_materializer_sources <- function() packet$sources
  env$.spde_slope_gauge_tr_materializer_commit <- function() packet$commit
  env$spde_slope_gauge_trust_region_locked_predecessor <- function() predecessor$locked
  env$.spde_slope_gauge_tr_materializer_expected_dll <- function(locked) expected_dll
  env$spde_slope_gauge_trust_region_validate_preflight_packet <- function(...) {
    spde_slope_gauge_tr_materializer_rebind_packet_dll(env, packet, expected_dll)
    original_preflight(packet$root, packet$sources, packet$commit,
      expected_root = packet$root, locked = predecessor$locked)
  }
  fake_launch <- function(command, arguments, deadline_s) {
    parent_pid <- as.integer(arguments[[5L]])
    if (identical(arguments[[3L]], "v3-live-child")) {
      child <- list(
        schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_V3_LIVE_CHILD_V1",
        parent_pid = parent_pid, child_pid = 102L,
        started_at = "2026-08-15 12:00:00 UTC", ended_at = "2026-08-15 12:00:01 UTC",
        elapsed_s = 1, status = "GAUGE_TRUST_REGION_V3_LIVE_VALID",
        reason = "closeout_recomputed", predecessor = receipt$predecessor,
        dll = expected_dll, error = NA_character_
      )
      saveRDS(child, arguments[[4L]])
      return(list(exit_status = 0L, child_pid = 102L, timed_out = FALSE,
        stdout = "", stderr = "", error = NA_character_,
        started_at = "2026-08-15 12:00:00 UTC", ended_at = "2026-08-15 12:00:01 UTC", elapsed_s = 1))
    }
    worker <- spde_slope_gauge_tr_materializer_complete_worker(
      env, receipt, state, expected_dll, parent_pid
    )
    saveRDS(worker, arguments[[4L]])
    list(exit_status = 0L, child_pid = 103L, timed_out = FALSE,
      stdout = "", stderr = "", error = NA_character_,
      started_at = "2026-08-15 12:00:02 UTC", ended_at = "2026-08-15 12:00:03 UTC", elapsed_s = 1)
  }
  sealed <- env$spde_slope_gauge_trust_region_smoke(fake_launch)
  expect_identical(sealed, list(valid = TRUE, reason = "trust_region_terminal_sealed"))
  expect_true(env$spde_slope_gauge_trust_region_validate_terminal_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )$valid)

  altered_state <- state
  altered_state$theta[[1L]] <- altered_state$theta[[1L]] + 0.2
  altered_state$gradient <- altered_state$theta
  altered_state$objective <- as.double(0.5 * sum(altered_state$theta * altered_state$theta))
  marker <- readRDS(file.path(packet$root, "attempt-started.rds"))
  child <- readRDS(file.path(packet$root, "v3-live-child.rds"))
  altered_worker <- spde_slope_gauge_tr_materializer_complete_worker(
    env, receipt, altered_state, expected_dll, marker$parent_pid
  )
  worker_path <- file.path(packet$root, "worker-result.rds")
  saveRDS(altered_worker, worker_path)
  ledger <- readRDS(file.path(packet$root, "all-attempt-ledger.rds"))
  ledger$worker <- altered_worker
  ledger$trust_region <- altered_worker$trust_region
  ledger$status <- altered_worker$status
  ledger$reason <- altered_worker$reason
  ledger$error <- NA_character_
  ledger$checks <- stats::setNames(c(TRUE, TRUE,
    identical(altered_worker$status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION"), FALSE),
    env$spde_slope_gauge_trust_region_checks())
  ledger$processes$worker$child_result_md5 <- unname(tools::md5sum(worker_path))[[1L]]
  saveRDS(ledger, file.path(packet$root, "all-attempt-ledger.rds"))
  expect_true(env$spde_slope_gauge_no_fit_evidence_ok(altered_worker$nofit))
  expect_true(env$spde_slope_gauge_trust_region_worker_ok(altered_worker, receipt$predecessor))
  expect_true(env$.spde_slope_gauge_tr_materializer_process_for_child_ok(
    ledger$processes$worker, altered_worker, packet$sources[["runner"]], "worker-child",
    worker_path, marker$parent_pid
  ))
  env$.spde_slope_gauge_tr_materializer_replace_manifest(
    packet$root, env$.spde_slope_gauge_tr_materializer_terminal_files(ledger)
  )
  rejected <- env$spde_slope_gauge_trust_region_validate_terminal_packet(
    packet$root, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )
  expect_identical(rejected, list(valid = FALSE, reason = "terminal_no_fit_state_binding_invalid"))
})

test_that("the production sealer replaces the preflight manifest only after the terminal ledger is atomic", {
  env <- spde_slope_gauge_tr_materializer_env()
  predecessor <- spde_slope_gauge_tr_materializer_predecessor(env)
  packet <- spde_slope_gauge_tr_materializer_packet(env, predecessor)
  on.exit(unlink(c(predecessor$root, packet$root, packet$source_dir), recursive = TRUE), add = TRUE)

  receipt <- readRDS(file.path(packet$root, "root-receipt.rds"))
  marker <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ATTEMPT_STARTED_V1",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1", root = packet$root,
    commit = packet$commit, parent_pid = 101L,
    receipt_md5 = unname(tools::md5sum(file.path(packet$root, "root-receipt.rds")))[[1L]],
    started_at = "2026-08-15 12:00:00 UTC"
  )
  dll_path <- tempfile("spde-slope-gauge-tr-seal-dll-")
  writeLines("fixture DLL", dll_path)
  on.exit(unlink(dll_path), add = TRUE)
  expected_dll <- list(
    path = normalizePath(dll_path, mustWork = TRUE),
    md5 = unname(tools::md5sum(dll_path))[[1L]]
  )
  child <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_V3_LIVE_CHILD_V1",
    parent_pid = 101L, child_pid = 102L,
    started_at = "2026-08-15 12:00:00 UTC", ended_at = "2026-08-15 12:00:01 UTC",
    elapsed_s = 1, status = "GAUGE_TRUST_REGION_V3_LIVE_VALID",
    reason = "closeout_recomputed", predecessor = receipt$predecessor,
    dll = expected_dll, error = NA_character_
  )
  dir.create(file.path(packet$root, ".attempt-started.claim"))
  saveRDS(marker, file.path(packet$root, "attempt-started.rds"))
  saveRDS(child, file.path(packet$root, "v3-live-child.rds"))
  processes <- list(
    v3_live = spde_slope_gauge_tr_materializer_process(
      child, packet$sources[["runner"]], "v3-live-child",
      file.path(packet$root, "v3-live-child.rds")
    ),
    worker = NULL
  )
  ledger <- env$spde_slope_gauge_trust_region_terminal_from_worker(
    packet$root, packet$commit, receipt, marker, child,
    readRDS(file.path(packet$root, "control.rds")), list(total_s = 1), processes = processes,
    fallback_reason = "parent_unwind", fallback_error = "synthetic parent unwind"
  )

  sealed <- env$spde_slope_gauge_trust_region_seal_terminal(
    packet$root, ledger, packet$sources, packet$commit, expected_root = packet$root,
    locked = predecessor$locked, expected_dll = expected_dll
  )
  expect_identical(sealed, list(valid = TRUE, reason = "terminal_infrastructure_fallback_valid"))
  expect_error(
    env$spde_slope_gauge_trust_region_seal_terminal(
      packet$root, ledger, packet$sources, packet$commit, expected_root = packet$root,
      locked = predecessor$locked, expected_dll = expected_dll
    ),
    "terminal ledger target is not fresh"
  )
})
