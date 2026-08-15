## Filesystem and terminal-shape contract for PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1.
##
## This file reads and validates artifacts only.  It neither constructs TMB
## objects nor writes a result root.

.spde_slope_gauge_tr_smoke_md5 <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && grepl("^[[:xdigit:]]{32}$", x)
}

.spde_slope_gauge_tr_smoke_regular_file <- function(path) {
  info <- suppressWarnings(file.info(path))
  is.character(path) && length(path) == 1L && !is.na(path) && file.exists(path) &&
    !isTRUE(info$isdir[[1L]]) && identical(Sys.readlink(path), "")
}

.spde_slope_gauge_tr_smoke_empty_directory <- function(path) {
  is.character(path) && length(path) == 1L && !is.na(path) && dir.exists(path) &&
    identical(Sys.readlink(path), "") && identical(list.files(path, all.files = TRUE, no.. = TRUE), character())
}

.spde_slope_gauge_tr_smoke_optional_md5 <- function(x) {
  is.character(x) && length(x) == 1L && (is.na(x) || .spde_slope_gauge_tr_smoke_md5(x))
}

spde_slope_gauge_trust_region_locked_predecessor <- function() {
  list(
    root = paste0(
      "/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/",
      "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3"
    ),
    commit = "a6255290810269510bba87951ea2dee365861e21",
    files = c(
      "all-attempt-ledger.rds" = "a9f19416c126a9f2054092835cdb8aaa",
      "attempt-started.rds" = "8b5421d35a4b50d46b690eee0c2b3cb2",
      "file-manifest.csv" = "32f93c4de1988dad08ac01f12e30a674",
      "root-receipt.rds" = "1940354271459b695e3ed2af70f1ca9c",
      "session-info.rds" = "817aea4f16c4ddc7d844bb7af342024e",
      "time-estimate.md" = "e0a79bbfdb48668328d5f0224e6bd40f",
      "v2-materialized-state.rds" = "e3b17636c9f5fa0e9e555a307c923724"
    ),
    directory = ".attempt-started.claim",
    receipt_schema = "MSPDE_P1_S3_C360_R3_V3_CLOSEOUT_PREFLIGHT_V1",
    state_schema = "MSPDE_P1_S3_C360_R3_V3_MATERIALIZED_V2_STATE_V1",
    historical_contract_path = paste0(
      "/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/",
      "dev/isdm-package-recovery/matched-spde-smoke-contract.R"
    ),
    historical_contract_md5 = "8b1b58aa72406ed5a2de74f93239a1d0"
  )
}

.spde_slope_gauge_tr_state_ok <- function(state, schema) {
  fields <- c(
    "schema", "objective", "theta", "gradient", "convergence", "covariance",
    "start_provenance", "restart_history", "warm_restart_provenance",
    "isdm_polish_provenance", "parameters", "map", "data", "random",
    "block_labels", "parameter_order"
  )
  order <- spde_slope_gauge_raw_order()
  is.list(state) && identical(names(state), fields) && identical(state$schema, schema) &&
    is.double(state$objective) && length(state$objective) == 1L && is.finite(state$objective) &&
    is.double(state$theta) && identical(names(state$theta), order) &&
    length(state$theta) == length(order) && all(is.finite(state$theta)) &&
    is.double(state$gradient) && identical(names(state$gradient), order) &&
    length(state$gradient) == length(order) && all(is.finite(state$gradient)) &&
    is.integer(state$convergence) && length(state$convergence) == 1L &&
    is.list(state$covariance) && is.list(state$start_provenance) &&
    is.data.frame(state$restart_history) && is.list(state$warm_restart_provenance) &&
    is.list(state$isdm_polish_provenance) && is.list(state$parameters) &&
    is.list(state$map) && is.list(state$data) &&
    identical(state$random, c("s_B", "g_spde_slope")) &&
    is.character(state$block_labels) && length(state$block_labels) == length(order) &&
    identical(state$parameter_order, order)
}

spde_slope_gauge_trust_region_validate_predecessor_bytes <- function(
  root = spde_slope_gauge_trust_region_locked_predecessor()$root,
  locked = spde_slope_gauge_trust_region_locked_predecessor()
) {
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  expected_root <- tryCatch(normalizePath(locked$root, mustWork = TRUE), error = function(e) NA_character_)
  if (!is.character(normal_root) || length(normal_root) != 1L || is.na(normal_root) ||
      is.na(expected_root) || !identical(normal_root, expected_root)) {
    return(list(valid = FALSE, reason = "predecessor_root_invalid"))
  }
  files <- names(locked$files)
  directory <- locked$directory
  paths <- file.path(normal_root, files)
  manifest_path <- file.path(normal_root, "file-manifest.csv")
  manifest <- if (.spde_slope_gauge_tr_smoke_regular_file(manifest_path)) {
    tryCatch(utils::read.csv(manifest_path, stringsAsFactors = FALSE), error = function(e) NULL)
  } else {
    NULL
  }
  declared <- setdiff(files, "file-manifest.csv")
  packet_ok <- identical(
    sort(list.files(normal_root, all.files = TRUE, no.. = TRUE, recursive = FALSE)),
    sort(c(files, directory))
  ) && all(vapply(paths, .spde_slope_gauge_tr_smoke_regular_file, logical(1L))) &&
    .spde_slope_gauge_tr_smoke_empty_directory(file.path(normal_root, directory)) &&
    identical(unname(tools::md5sum(paths)), unname(locked$files)) &&
    is.data.frame(manifest) && identical(names(manifest), c("path", "md5")) &&
    identical(as.character(manifest$path), declared) &&
    identical(as.character(manifest$md5), unname(locked$files[declared]))
  if (!packet_ok) return(list(valid = FALSE, reason = "predecessor_packet_bytes_invalid"))
  receipt <- tryCatch(readRDS(file.path(normal_root, "root-receipt.rds")), error = function(e) NULL)
  state <- tryCatch(readRDS(file.path(normal_root, "v2-materialized-state.rds")), error = function(e) NULL)
  receipt_ok <- is.list(receipt) && identical(
    names(receipt),
    c("schema", "source_gate", "root", "commit", "consumed_v2", "runner_md5", "contract_md5", "design_md5")
  ) && identical(receipt$schema, locked$receipt_schema) &&
    identical(receipt$root, normal_root) && identical(receipt$commit, locked$commit) &&
    all(vapply(receipt[c("runner_md5", "contract_md5", "design_md5")],
      .spde_slope_gauge_tr_smoke_md5, logical(1L)))
  state_ok <- .spde_slope_gauge_tr_state_ok(state, locked$state_schema)
  list(
    valid = receipt_ok && state_ok,
    reason = if (receipt_ok && state_ok) "predecessor_bytes_valid" else "predecessor_receipt_or_state_invalid",
    root = normal_root,
    commit = locked$commit,
    receipt = receipt,
    state = state,
    state_md5 = unname(locked$files[["v2-materialized-state.rds"]])
  )
}

spde_slope_gauge_trust_region_validate_process_receipt <- function(
  process,
  command,
  arguments,
  parent_pid,
  child_pid
) {
  fields <- c(
    "schema", "command", "arguments", "parent_pid", "child_pid", "started_at", "ended_at",
    "elapsed_s", "deadline_s", "timed_out", "exit_status", "signal", "stdout_md5",
    "stderr_md5", "child_result_md5"
  )
  scalar_pid <- function(x) is.integer(x) && length(x) == 1L && !is.na(x) && x > 0L
  scalar_time <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  exit_ok <- function(x) is.integer(x) && length(x) == 1L && (is.na(x) || x >= 0L)
  signal_ok <- function(x) is.character(x) && length(x) == 1L && (is.na(x) || nzchar(x))
  .spde_slope_gauge_tr_smoke_exact_names(process, fields) &&
    identical(process$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PROCESS_V1") &&
    identical(process$command, command) && identical(process$arguments, arguments) &&
    scalar_pid(process$parent_pid) && scalar_pid(process$child_pid) &&
    identical(process$parent_pid, parent_pid) && identical(process$child_pid, child_pid) &&
    !identical(process$parent_pid, process$child_pid) && scalar_time(process$started_at) &&
    scalar_time(process$ended_at) && is.double(process$elapsed_s) && length(process$elapsed_s) == 1L &&
    is.finite(process$elapsed_s) && process$elapsed_s >= 0 && is.integer(process$deadline_s) &&
    identical(process$deadline_s, 1800L) && is.logical(process$timed_out) &&
    length(process$timed_out) == 1L && !is.na(process$timed_out) && exit_ok(process$exit_status) &&
    signal_ok(process$signal) && .spde_slope_gauge_tr_smoke_optional_md5(process$stdout_md5) &&
    .spde_slope_gauge_tr_smoke_optional_md5(process$stderr_md5) &&
    .spde_slope_gauge_tr_smoke_optional_md5(process$child_result_md5) &&
    if (isTRUE(process$timed_out)) {
      is.na(process$exit_status) && is.na(process$child_result_md5)
    } else {
      !is.na(process$exit_status) && is.na(process$signal)
    }
}

spde_slope_gauge_trust_region_terminal_fields <- function() {
  c(
    "schema", "gate", "root", "commit", "terminal", "receipt", "marker", "worker",
    "v3_live_child", "processes", "predecessor", "controls", "trust_region", "checks",
    "status", "reason", "error", "timing"
  )
}

spde_slope_gauge_trust_region_checks <- function() {
  c("predecessor", "infrastructure", "numerical", "terminal_evidence")
}

spde_slope_gauge_trust_region_result_statuses <- function() {
  c(
    "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION",
    "GAUGE_TRUST_REGION_CURVATURE_VALIDATION_HOLD",
    "GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE",
    "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"
  )
}

spde_slope_gauge_trust_region_terminal_evidence_hold <- function() {
  "GAUGE_TRUST_REGION_TERMINAL_EVIDENCE_HOLD"
}

spde_slope_gauge_trust_region_worker_fields <- function() {
  c(
    "schema", "parent_pid", "child_pid", "started_at", "ended_at", "elapsed_s",
    "predecessor", "state_md5", "dll", "object", "nofit", "sign_orbit", "trust_region",
    "audit", "status", "reason", "stage", "completed_stage", "error"
  )
}

spde_slope_gauge_trust_region_v3_live_child_ok <- function(child, predecessor, expected_dll) {
  fields <- c(
    "schema", "parent_pid", "child_pid", "started_at", "ended_at", "elapsed_s",
    "status", "reason", "predecessor", "dll", "error"
  )
  .spde_slope_gauge_tr_smoke_exact_names(child, fields) &&
    identical(child$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_V3_LIVE_CHILD_V1") &&
    .spde_slope_gauge_tr_smoke_pid(child$parent_pid) &&
    .spde_slope_gauge_tr_smoke_pid(child$child_pid) &&
    !identical(child$parent_pid, child$child_pid) &&
    is.character(child$started_at) && length(child$started_at) == 1L && nzchar(child$started_at) &&
    is.character(child$ended_at) && length(child$ended_at) == 1L && nzchar(child$ended_at) &&
    is.double(child$elapsed_s) && length(child$elapsed_s) == 1L &&
    is.finite(child$elapsed_s) && child$elapsed_s >= 0 &&
    identical(child$status, "GAUGE_TRUST_REGION_V3_LIVE_VALID") &&
    identical(child$reason, "closeout_recomputed") &&
    identical(child$predecessor, predecessor) && identical(child$dll, expected_dll) &&
    .spde_slope_gauge_tr_smoke_regular_file(expected_dll$path) &&
    identical(unname(tools::md5sum(expected_dll$path))[[1L]], expected_dll$md5) &&
    identical(child$error, NA_character_)
}

.spde_slope_gauge_tr_smoke_pid <- function(x) {
  is.integer(x) && length(x) == 1L && !is.na(x) && x > 0L
}

.spde_slope_gauge_tr_smoke_worker_dll <- function(x) {
  .spde_slope_gauge_tr_smoke_exact_names(x, c("path", "md5")) &&
    is.character(x$path) && length(x$path) == 1L && !is.na(x$path) && nzchar(x$path) &&
    .spde_slope_gauge_tr_smoke_md5(x$md5)
}

.spde_slope_gauge_tr_smoke_missing_md5 <- function(x) {
  is.character(x) && length(x) == 1L && is.na(x)
}

.spde_slope_gauge_tr_smoke_worker_object <- function(x, created, released) {
  .spde_slope_gauge_tr_smoke_exact_names(x, c("created", "released")) &&
    is.integer(x$created) && length(x$created) == 1L && identical(x$created, created) &&
    is.integer(x$released) && length(x$released) == 1L && identical(x$released, released)
}

spde_slope_gauge_trust_region_worker_ok <- function(worker, predecessor) {
  if (!.spde_slope_gauge_tr_smoke_exact_names(
    worker, spde_slope_gauge_trust_region_worker_fields()
  ) || !identical(worker$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_CHILD_V1") ||
      !.spde_slope_gauge_tr_smoke_pid(worker$parent_pid) ||
      !.spde_slope_gauge_tr_smoke_pid(worker$child_pid) ||
      identical(worker$parent_pid, worker$child_pid) ||
      !is.character(worker$started_at) || length(worker$started_at) != 1L ||
      !is.character(worker$ended_at) || length(worker$ended_at) != 1L ||
      !is.double(worker$elapsed_s) || length(worker$elapsed_s) != 1L ||
      !is.finite(worker$elapsed_s) || worker$elapsed_s < 0 ||
      !is.character(worker$status) || length(worker$status) != 1L ||
      !is.character(worker$reason) || length(worker$reason) != 1L ||
      !is.character(worker$stage) || length(worker$stage) != 1L ||
      !is.character(worker$completed_stage) || length(worker$completed_stage) != 1L ||
      !is.character(worker$error) || length(worker$error) != 1L) {
    return(FALSE)
  }
  completed <- worker$status %in% spde_slope_gauge_trust_region_result_statuses() &&
    identical(worker$stage, "complete") && identical(worker$completed_stage, "complete")
  if (completed) {
    return(
      identical(worker$predecessor, predecessor) && .spde_slope_gauge_tr_smoke_md5(worker$state_md5) &&
        .spde_slope_gauge_tr_smoke_worker_dll(worker$dll) &&
        .spde_slope_gauge_tr_smoke_worker_object(worker$object, 1L, 1L) &&
        isTRUE(spde_slope_gauge_no_fit_evidence_ok(worker$nofit)) &&
        is.list(worker$sign_orbit) && isTRUE(worker$sign_orbit$valid) &&
        is.list(worker$trust_region) && identical(worker$trust_region$status, worker$status) &&
        identical(worker$trust_region$reason, worker$reason) && is.list(worker$audit) &&
        identical(worker$stage, "complete") && identical(worker$error, NA_character_)
    )
  }
  if (!identical(worker$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD") ||
      !nzchar(worker$error)) return(FALSE)
  prefix_ok <- function(completed_stage, released) {
    common <- identical(worker$predecessor, predecessor) &&
      .spde_slope_gauge_tr_smoke_md5(worker$state_md5) &&
      .spde_slope_gauge_tr_smoke_worker_dll(worker$dll) &&
      .spde_slope_gauge_tr_smoke_worker_object(worker$object, 1L, released)
    if (!common) return(FALSE)
    switch(
      completed_stage,
      factory = is.null(worker$nofit) && is.null(worker$sign_orbit) &&
        is.null(worker$trust_region) && is.null(worker$audit),
      no_fit = is.list(worker$nofit) && identical(worker$nofit$valid, FALSE) &&
        is.null(worker$sign_orbit) && is.null(worker$trust_region) && is.null(worker$audit),
      sign = isTRUE(spde_slope_gauge_no_fit_evidence_ok(worker$nofit)) &&
        is.list(worker$sign_orbit) && isTRUE(worker$sign_orbit$valid) &&
        is.null(worker$trust_region) && is.null(worker$audit),
      callback_adapter = isTRUE(spde_slope_gauge_no_fit_evidence_ok(worker$nofit)) &&
        is.list(worker$sign_orbit) && isTRUE(worker$sign_orbit$valid) &&
        is.null(worker$trust_region) && is.null(worker$audit),
      trust_region = isTRUE(spde_slope_gauge_no_fit_evidence_ok(worker$nofit)) &&
        is.list(worker$sign_orbit) && isTRUE(worker$sign_orbit$valid) &&
        is.list(worker$trust_region) && is.null(worker$audit),
      audit = isTRUE(spde_slope_gauge_no_fit_evidence_ok(worker$nofit)) &&
        is.list(worker$sign_orbit) && isTRUE(worker$sign_orbit$valid) &&
        is.list(worker$trust_region) && is.list(worker$audit),
      FALSE
    )
  }
  switch(
    worker$stage,
    predecessor = is.null(worker$predecessor) && .spde_slope_gauge_tr_smoke_missing_md5(worker$state_md5) &&
      is.null(worker$dll) && .spde_slope_gauge_tr_smoke_worker_object(worker$object, 0L, 0L) &&
      is.null(worker$nofit) && is.null(worker$sign_orbit) && is.null(worker$trust_region) && is.null(worker$audit) &&
      identical(worker$completed_stage, "none"),
    dll = identical(worker$predecessor, predecessor) && .spde_slope_gauge_tr_smoke_md5(worker$state_md5) &&
      is.null(worker$dll) && .spde_slope_gauge_tr_smoke_worker_object(worker$object, 0L, 0L) &&
      is.null(worker$nofit) && is.null(worker$sign_orbit) && is.null(worker$trust_region) && is.null(worker$audit) &&
      identical(worker$completed_stage, "v3_live"),
    v3_live = identical(worker$predecessor, predecessor) && .spde_slope_gauge_tr_smoke_md5(worker$state_md5) &&
      is.null(worker$dll) && .spde_slope_gauge_tr_smoke_worker_object(worker$object, 0L, 0L) &&
      is.null(worker$nofit) && is.null(worker$sign_orbit) && is.null(worker$trust_region) && is.null(worker$audit) &&
      identical(worker$completed_stage, "predecessor"),
    factory = prefix_ok("factory", 1L) && identical(worker$completed_stage, "factory"),
    no_fit = prefix_ok("no_fit", 1L) && identical(worker$completed_stage, "factory"),
    sign = identical(worker$completed_stage, "no_fit") &&
      isTRUE(spde_slope_gauge_no_fit_evidence_ok(worker$nofit)) &&
      (is.null(worker$sign_orbit) || (is.list(worker$sign_orbit) && identical(worker$sign_orbit$valid, FALSE))) &&
      identical(worker$predecessor, predecessor) && .spde_slope_gauge_tr_smoke_md5(worker$state_md5) &&
      .spde_slope_gauge_tr_smoke_worker_dll(worker$dll) &&
      .spde_slope_gauge_tr_smoke_worker_object(worker$object, 1L, 1L) &&
      is.null(worker$trust_region) && is.null(worker$audit),
    callback_adapter = prefix_ok("sign", 1L) && identical(worker$completed_stage, "sign"),
    trust_region = prefix_ok("callback_adapter", 1L) && identical(worker$completed_stage, "callback_adapter"),
    audit = prefix_ok("trust_region", 1L) && identical(worker$completed_stage, "trust_region"),
    release = worker$completed_stage %in% c("factory", "no_fit", "sign", "callback_adapter", "trust_region", "audit") &&
      prefix_ok(worker$completed_stage, 0L),
    FALSE
  )
}

.spde_slope_gauge_tr_smoke_exact_names <- function(x, names) {
  is.list(x) && identical(names(x), names)
}

spde_slope_gauge_trust_region_manifest_ok <- function(root, expected_files, expected_directories = character()) {
  manifest_path <- file.path(root, "file-manifest.csv")
  if (!.spde_slope_gauge_tr_smoke_regular_file(manifest_path) ||
      !all(vapply(file.path(root, expected_files), .spde_slope_gauge_tr_smoke_regular_file, logical(1L))) ||
      !all(vapply(file.path(root, expected_directories), .spde_slope_gauge_tr_smoke_empty_directory, logical(1L)))) {
    return(FALSE)
  }
  inventory <- list.files(root, all.files = TRUE, no.. = TRUE, recursive = FALSE)
  if (!identical(sort(inventory), sort(c(expected_files, expected_directories)))) return(FALSE)
  manifest <- tryCatch(utils::read.csv(manifest_path, stringsAsFactors = FALSE), error = function(e) NULL)
  declared <- setdiff(expected_files, "file-manifest.csv")
  is.data.frame(manifest) &&
    identical(names(manifest), c("path", "md5")) &&
    identical(as.character(manifest$path), declared) &&
    identical(as.character(manifest$md5), unname(tools::md5sum(file.path(root, declared))))
}

.spde_slope_gauge_tr_smoke_terminal_shape_ok <- function(ledger) {
  fields <- spde_slope_gauge_trust_region_terminal_fields()
  checks <- spde_slope_gauge_trust_region_checks()
  .spde_slope_gauge_tr_smoke_exact_names(ledger, fields) &&
    is.character(ledger$schema) && length(ledger$schema) == 1L &&
    identical(ledger$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ALL_ATTEMPT_V1") &&
    is.character(ledger$gate) && length(ledger$gate) == 1L &&
    is.character(ledger$root) && length(ledger$root) == 1L &&
    is.character(ledger$commit) && length(ledger$commit) == 1L && !is.na(ledger$commit) &&
    grepl("^[[:xdigit:]]{40}$", ledger$commit) &&
    is.logical(ledger$terminal) && length(ledger$terminal) == 1L && isTRUE(ledger$terminal) &&
    is.list(ledger$receipt) && (is.null(ledger$marker) || is.list(ledger$marker)) &&
    (is.null(ledger$v3_live_child) || is.list(ledger$v3_live_child)) &&
    .spde_slope_gauge_tr_smoke_exact_names(ledger$processes, c("v3_live", "worker")) &&
    all(vapply(ledger$processes, function(x) is.null(x) || is.list(x), logical(1L))) &&
    is.list(ledger$predecessor) &&
    is.list(ledger$controls) && is.logical(ledger$checks) &&
    identical(names(ledger$checks), checks) && length(ledger$checks) == length(checks) &&
    !any(is.na(ledger$checks)) && is.character(ledger$status) && length(ledger$status) == 1L &&
    is.character(ledger$reason) && length(ledger$reason) == 1L &&
    is.character(ledger$error) && length(ledger$error) == 1L &&
    is.list(ledger$timing)
}

spde_slope_gauge_trust_region_normalise_fallback <- function(ledger, reason, error) {
  if (!.spde_slope_gauge_tr_smoke_terminal_shape_ok(ledger) ||
      !is.character(reason) || length(reason) != 1L || is.na(reason) ||
      !is.character(error) || length(error) != 1L || is.na(error) || !nzchar(error)) {
    .spde_slope_gauge_tr_fail("trust-region fallback input is malformed")
  }
  ledger["worker"] <- list(NULL)
  ledger["trust_region"] <- list(NULL)
  ledger["checks"] <- list(stats::setNames(
    c(isTRUE(ledger$checks[["predecessor"]]), FALSE, FALSE, FALSE),
    spde_slope_gauge_trust_region_checks()
  ))
  ledger["status"] <- list("GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")
  ledger["reason"] <- list(reason)
  ledger["error"] <- list(error)
  ledger
}

spde_slope_gauge_trust_region_validate_terminal_ledger <- function(ledger) {
  if (!.spde_slope_gauge_tr_smoke_terminal_shape_ok(ledger)) {
    return(list(valid = FALSE, reason = "terminal_ledger_schema_invalid"))
  }
  checks <- ledger$checks
  fallback <- identical(ledger$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD") &&
    is.null(ledger$worker) && is.null(ledger$trust_region) &&
    isTRUE(checks[["predecessor"]]) && !isTRUE(checks[["infrastructure"]]) &&
    !isTRUE(checks[["numerical"]]) && !isTRUE(checks[["terminal_evidence"]]) &&
    nzchar(ledger$error)
  evidence_hold <- identical(ledger$status, spde_slope_gauge_trust_region_terminal_evidence_hold()) &&
    identical(ledger$reason, "terminal_evidence_inconsistent") && is.list(ledger$worker) &&
    (is.list(ledger$trust_region) || is.null(ledger$trust_region)) && isTRUE(checks[["predecessor"]]) &&
    !isTRUE(checks[["infrastructure"]]) && !isTRUE(checks[["numerical"]]) &&
    !isTRUE(checks[["terminal_evidence"]]) && nzchar(ledger$error)
  result_terminal <- ledger$status %in% spde_slope_gauge_trust_region_result_statuses() &&
    is.list(ledger$worker) &&
    if (identical(ledger$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")) {
      is.null(ledger$trust_region) || is.list(ledger$trust_region)
    } else {
      is.list(ledger$trust_region)
    } &&
    isTRUE(checks[["predecessor"]]) && !isTRUE(checks[["terminal_evidence"]]) &&
    if (identical(ledger$status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")) {
      isTRUE(checks[["infrastructure"]]) && isTRUE(checks[["numerical"]]) &&
        identical(ledger$reason, "selected_candidate_passed_all_gates") &&
        identical(ledger$error, NA_character_)
    } else if (ledger$status %in% c(
      "GAUGE_TRUST_REGION_CURVATURE_VALIDATION_HOLD",
      "GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE"
    )) {
      isTRUE(checks[["infrastructure"]]) && !isTRUE(checks[["numerical"]]) &&
        identical(ledger$error, NA_character_)
    } else {
      !isTRUE(checks[["infrastructure"]]) && !isTRUE(checks[["numerical"]]) &&
        (is.na(ledger$error) || nzchar(ledger$error))
    }
  list(valid = fallback || evidence_hold || result_terminal,
    reason = if (fallback || evidence_hold || result_terminal) {
      "terminal_ledger_shape_valid"
    } else {
      "terminal_ledger_projection_invalid"
    })
}

spde_slope_gauge_trust_region_validate_terminal_evidence <- function(
  ledger,
  phi0 = NULL,
  evaluate_fn = NULL,
  covariance_fn = NULL,
  controls = spde_slope_gauge_trust_region_controls(),
  state = NULL
) {
  shape <- spde_slope_gauge_trust_region_validate_terminal_ledger(ledger)
  if (!isTRUE(shape$valid)) return(shape)
  if (identical(ledger$status, spde_slope_gauge_trust_region_terminal_evidence_hold())) {
    worker_status <- if (is.character(ledger$worker$status) && length(ledger$worker$status) == 1L) {
      ledger$worker$status
    } else {
      NA_character_
    }
    worker_reason <- if (is.character(ledger$worker$reason) && length(ledger$worker$reason) == 1L) {
      ledger$worker$reason
    } else {
      NA_character_
    }
    worker_error <- if (is.character(ledger$worker$error) && length(ledger$worker$error) == 1L) {
      ledger$worker$error
    } else {
      NA_character_
    }
    if (identical(worker_status, spde_slope_gauge_trust_region_terminal_evidence_hold())) {
      return(list(valid = FALSE, reason = "terminal_evidence_hold_nested"))
    }
    probe <- ledger
    probe["status"] <- list(worker_status)
    probe["reason"] <- list(worker_reason)
    probe["error"] <- list(worker_error)
    probe["trust_region"] <- list(ledger$worker$trust_region)
    probe["checks"] <- list(stats::setNames(c(
      isTRUE(ledger$checks[["predecessor"]]),
      !identical(worker_status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"),
      identical(worker_status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION"), FALSE
    ), spde_slope_gauge_trust_region_checks()))
    recomputed <- spde_slope_gauge_trust_region_validate_terminal_evidence(
      probe, phi0, evaluate_fn, covariance_fn, controls, state
    )
    return(if (isTRUE(recomputed$valid)) {
      list(valid = FALSE, reason = "terminal_evidence_hold_not_forced_by_evidence")
    } else {
      list(valid = TRUE, reason = "terminal_evidence_hold_valid")
    })
  }
  if (identical(ledger$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")) {
    if (is.null(ledger$trust_region)) {
      if (is.null(ledger$worker)) {
        return(list(valid = TRUE, reason = "terminal_infrastructure_fallback_valid"))
      }
      return(if (spde_slope_gauge_trust_region_worker_ok(ledger$worker, ledger$predecessor)) {
        list(valid = TRUE, reason = "terminal_partial_worker_evidence_valid")
      } else {
        list(valid = FALSE, reason = "terminal_worker_evidence_invalid")
      })
    }
  }
  if (!spde_slope_gauge_trust_region_worker_ok(ledger$worker, ledger$predecessor)) {
    return(list(valid = FALSE, reason = "terminal_worker_evidence_invalid"))
  }
  if (!is.null(state)) {
    theta <- tryCatch(.spde_slope_gauge_full_vector(
      state$theta, spde_slope_gauge_raw_order(), "terminal state theta"
    ), error = function(e) NULL)
    gradient <- tryCatch(.spde_slope_gauge_full_vector(
      state$gradient, spde_slope_gauge_raw_order(), "terminal state gradient"
    ), error = function(e) NULL)
    objective <- tryCatch(.spde_slope_gauge_scalar_double(state$objective, "terminal state objective"),
      error = function(e) NULL)
    nofit <- ledger$worker$nofit
    if (is.null(theta) || is.null(gradient) || is.null(objective) ||
        .spde_slope_gauge_relative_error(nofit$raw_theta, theta) > nofit$controls$theta ||
        abs(nofit$objective - objective) / max(1, abs(nofit$objective), abs(objective)) > nofit$controls$objective ||
        .spde_slope_gauge_relative_error(nofit$raw_gradient, gradient) > nofit$controls$gradient) {
      return(list(valid = FALSE, reason = "terminal_no_fit_state_binding_invalid"))
    }
  }
  replay_from_audit <- is.null(phi0) && is.null(evaluate_fn) && is.null(covariance_fn)
  if (replay_from_audit) {
    phi0 <- tryCatch(spde_slope_gauge_phi_from_theta(ledger$worker$trust_region$hessian$base$raw_theta),
      error = function(e) NULL)
    audit_matches_worker <- is.list(ledger$worker$audit) &&
      identical(ledger$worker$audit$object_id, 1L) &&
      identical(ledger$worker$audit$dll_path, ledger$worker$dll$path) &&
      identical(ledger$worker$audit$dll_md5, ledger$worker$dll$md5)
    callbacks <- if (is.null(phi0) || !audit_matches_worker) NULL else spde_slope_gauge_trust_region_callbacks_from_audit(
      ledger$worker$audit, ledger$worker$audit$object_id,
      ledger$worker$audit$dll_path, ledger$worker$audit$dll_md5
    )
    if (is.null(callbacks)) return(list(valid = FALSE, reason = "terminal_callback_audit_invalid"))
    evaluate_fn <- callbacks$evaluate
    covariance_fn <- callbacks$covariance
  } else if (is.null(phi0) || !is.function(evaluate_fn) || !is.function(covariance_fn)) {
    return(list(valid = FALSE, reason = "terminal_replay_inputs_invalid"))
  }
  recomputation <- spde_slope_gauge_trust_region_validate_result(
    result = ledger$trust_region,
    phi0 = phi0,
    evaluate_fn = evaluate_fn,
    covariance_fn = covariance_fn,
    controls = controls
  )
  if (!isTRUE(recomputation$valid) || !identical(recomputation$status, ledger$status) ||
      !identical(recomputation$status, ledger$trust_region$status) ||
      !identical(ledger$reason, ledger$trust_region$reason)) {
    return(list(valid = FALSE, reason = "terminal_evidence_recomputation_failed"))
  }
  if (replay_from_audit && !isTRUE(callbacks$complete())) {
    return(list(valid = FALSE, reason = "terminal_callback_audit_incomplete"))
  }
  list(valid = TRUE, reason = if (identical(ledger$status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")) {
    "terminal_numerical_admission_recomputed"
  } else {
    "terminal_nonadmission_recomputed"
  })
}
