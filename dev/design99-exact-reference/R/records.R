# Private Design-99 immutable-record helpers.  Nothing in this file constructs
# a scientific objective, fixture, quadrature rule, or optimiser.

d99_json <- function(x, pretty = FALSE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Design-99 records require jsonlite", call. = FALSE)
  }
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", pretty = pretty,
                   digits = 17, POSIXt = "ISO8601")
}

d99_sha256_raw <- function(x) {
  tf <- tempfile("d99-sha-")
  on.exit(unlink(tf), add = TRUE)
  writeBin(x, tf)
  unname(tools::sha256sum(tf))
}

d99_sha256_object <- function(x) d99_sha256_raw(serialize(x, NULL, version = 2))
d99_sha256_file <- function(path) {
  if (!file.exists(path)) stop("Cannot hash a missing file: ", path, call. = FALSE)
  unname(tools::sha256sum(path))
}

d99_now <- function() format(Sys.time(), tz = "UTC", usetz = TRUE)
d99_host <- function() unname(Sys.info()[["nodename"]])
d99_path <- function(root, kind, id, ext = "json") {
  file.path(root, kind, paste0(id, ".", ext))
}

# "wx" is POSIX exclusive create.  A crash after it leaves a deliberately
# invalid partial record rather than silently replacing evidence.
d99_write_exclusive_text <- function(path, text) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- tryCatch(suppressWarnings(file(path, open = "wx", encoding = "UTF-8")), error = function(e) NULL)
  if (is.null(con)) stop("Refusing to overwrite immutable Design-99 artefact: ", path, call. = FALSE)
  ok <- tryCatch({ writeLines(enc2utf8(text), con, useBytes = TRUE); TRUE }, error = function(e) FALSE)
  try(close(con), silent = TRUE)
  if (!ok) stop("Exclusive artefact creation was interrupted: ", path, call. = FALSE)
  invisible(path)
}

d99_write_exclusive_json <- function(path, value) {
  d99_write_exclusive_text(path, d99_json(value, pretty = TRUE))
}

d99_read_json <- function(path) {
  if (!file.exists(path) || !requireNamespace("jsonlite", quietly = TRUE)) return(NULL)
  tryCatch(jsonlite::fromJSON(path, simplifyVector = TRUE), error = function(e) NULL)
}

d99_forbidden_design98 <- function(x) {
  grepl("design98-factorial-va-jj", paste(unlist(x, use.names = FALSE), collapse = "\n"),
        fixed = TRUE)
}

d99_validate_quadrature_input <- function(x) {
  rules <- if (is.list(x$rules)) x$rules else x
  if (!length(rules)) return(FALSE)
  all(vapply(rules, function(rule) {
    is.list(rule) && all(c("nodes", "weights", "node_hash", "weight_hash") %in% names(rule)) &&
      is.numeric(rule$nodes) && is.numeric(rule$weights) && length(rule$nodes) == length(rule$weights) &&
      is.character(rule$node_hash) && is.character(rule$weight_hash)
  }, logical(1)))
}

d99_validate_fixture_input <- function(x) {
  is.list(x) && all(c("prefix_hashes", "pattern_count_hashes") %in% names(x)) &&
    is.list(x$prefix_hashes) && is.list(x$pattern_count_hashes)
}

d99_validate_input <- function(x) {
  req <- c("schema", "task_id", "task_class", "run_id", "dependencies",
           "contract_hash", "source_hashes", "runtime", "quadrature")
  missing <- setdiff(req, names(x))
  if (length(missing) || !identical(x$schema, "d99-input-v1") ||
      d99_forbidden_design98(x)) return(FALSE)
  is.list(x$source_hashes) && is.list(x$runtime) && d99_validate_quadrature_input(x$quadrature) &&
    d99_validate_fixture_input(x$fixture)
}

d99_validate_terminal <- function(x, task = NULL) {
  req <- c("schema", "task_id", "task_class", "run_id", "status", "started_at",
           "finished_at", "input_hash", "host", "pid", "exit_status", "telemetry")
  if (!is.list(x) || !identical(x$schema, "d99-terminal-v1") ||
      length(setdiff(req, names(x))) || d99_forbidden_design98(x)) return(FALSE)
  if (!is.null(task) && !identical(x$task_id, task$task_id)) return(FALSE)
  vocabulary <- c("PASS", "PROVENANCE_STOP", "SCOPE_STOP", "INFRASTRUCTURE_FAILURE", "INFRASTRUCTURE_INCOMPLETE", "TIMEOUT", "ORPHAN", "INTERRUPTED", "CRASH", "SIGNALED", "LAUNCH_FAILURE", "TECHNICAL_INCOMPLETE", "MALFORMED", "MISSING_DEPENDENCY", "DEPENDENCY_BLOCKED", "MECHANICAL_STOP", "QUADRATURE_STABILITY_STOP", "WEAK_OR_NONIDENTIFIED_REFERENCE", "OPTIMIZER_HEALTH_STOP", "DIAGNOSTIC_N128_NONINTERIOR", "BOUNDED_ORACLE_PASS")
  is.character(x$status) && length(x$status) == 1L && x$status %in% vocabulary && is.list(x$telemetry) &&
    all(c("wall_time_s", "dependency_ids") %in% names(x$telemetry))
}

d99_terminal_path <- function(root, task_id) d99_path(root, "records", task_id)
d99_input_path <- function(root, task_id) d99_path(root, "inputs", task_id)
d99_launch_path <- function(root, task_id) d99_path(root, "launches", task_id)
d99_payload_path <- function(root, task_id) d99_path(root, "payloads", task_id)

d99_read_terminal <- function(root, task) {
  x <- d99_read_json(d99_terminal_path(root, task$task_id))
  if (!d99_validate_terminal(x, task)) return(NULL)
  x
}

d99_or <- function(x, y) if (is.null(x)) y else x

d99_abort_mechanical <- function(message, code = "MECHANICAL_ERROR") {
  condition <- structure(list(message = as.character(message), call = NULL, code = code),
                         class = c("d99_mechanical_error", "error", "condition"))
  stop(condition)
}

d99_error_status <- function(error, otherwise = "OPTIMIZER_HEALTH_STOP") {
  message <- conditionMessage(error)
  if (inherits(error, "d99_mechanical_error") || grepl("package .*required|there is no package called|checksum|malformed|fixture", message, ignore.case = TRUE)) "MECHANICAL_STOP" else otherwise
}

d99_write_terminal <- function(root, task, status, input_hash, details = list()) {
  finished <- d99_now()
  started <- d99_or(details$started_at, finished)
  start_time <- suppressWarnings(as.numeric(as.POSIXct(started, tz = "UTC")))
  finish_time <- suppressWarnings(as.numeric(as.POSIXct(finished, tz = "UTC")))
  telemetry <- c(list(wall_time_s = if (is.finite(start_time) && is.finite(finish_time)) max(0, finish_time - start_time) else NA_real_,
                      dependency_ids = d99_or(details$dependency_ids, task$dependencies),
                      heartbeat_expected_s = 5L), d99_or(details$telemetry, list()))
  details$telemetry <- telemetry
  rec <- c(list(schema = "d99-terminal-v1", task_id = task$task_id,
                task_class = task$task_class, run_id = task$run_id, status = status,
                started_at = started, finished_at = finished,
                input_hash = input_hash, host = d99_host(), pid = Sys.getpid(),
                exit_status = d99_or(details$exit_status, 0L)), details)
  d99_write_exclusive_json(d99_terminal_path(root, task$task_id), rec)
}

d99_write_heartbeat <- function(root, task_id, sequence, state = "alive") {
  if (!grepl("^[0-9]+$", as.character(sequence))) stop("Heartbeat sequence must be numeric", call. = FALSE)
  d99_write_exclusive_json(d99_path(root, file.path("heartbeats", task_id),
                                     sprintf("%08d", as.integer(sequence))),
                           list(schema = "d99-heartbeat-v1", task_id = task_id,
                                sequence = as.integer(sequence), state = state,
                                at = d99_now(), host = d99_host(), pid = Sys.getpid()))
}

d99_write_log_chunk <- function(root, task_id, stream, sequence, text) {
  if (!stream %in% c("stdout", "stderr")) stop("Unknown log stream", call. = FALSE)
  d99_write_exclusive_text(d99_path(root, file.path("logs", task_id, stream),
                                     sprintf("%08d", as.integer(sequence)), "log"), text)
}

d99_write_payload <- function(root, task_id, payload) {
  path <- d99_payload_path(root, task_id)
  d99_write_exclusive_json(path, payload)
  d99_sha256_file(path)
}

d99_validate_launch <- function(x, task = NULL) {
  req <- c("schema", "task_id", "task_class", "run_id", "timeout_s", "launched_at", "host", "parent_pid", "mode", "input_hash")
  is.list(x) && identical(x$schema, "d99-launch-v1") && !length(setdiff(req, names(x))) &&
    (is.null(task) || (identical(x$task_id, task$task_id) && identical(x$task_class, task$task_class))) &&
    is.character(x$input_hash) && length(x$input_hash) == 1L && nzchar(x$input_hash)
}

d99_validate_dependency_payload <- function(root, record, require_payload = TRUE) {
  if (!is.list(record) || !file.exists(d99_input_path(root, record$task_id)) ||
      !identical(record$input_hash, d99_sha256_file(d99_input_path(root, record$task_id)))) return(FALSE)
  if (!require_payload) return(TRUE)
  path <- d99_payload_path(root, record$task_id)
  file.exists(path) && is.character(record$payload_hash) && identical(record$payload_hash, d99_sha256_file(path)) && is.list(d99_read_json(path))
}

d99_validate_source_hashes <- function(input, repo_root) {
  hashes <- input$source_hashes
  if (!is.list(hashes) || !length(hashes) || is.null(names(hashes))) return(FALSE)
  all(vapply(names(hashes), function(path) {
    target <- file.path(repo_root, path)
    file.exists(target) && identical(d99_sha256_file(target), as.character(hashes[[path]]))
  }, logical(1)))
}

d99_create_real_run <- function(root, manifest) {
  if (!identical(manifest$preflight_status, "PASS") ||
      !identical(manifest$mode, "REAL_RUN") || d99_forbidden_design98(manifest)) {
    stop("REAL_RUN sentinel requires a passing, isolated preflight manifest", call. = FALSE)
  }
  d99_write_exclusive_json(file.path(root, "REAL_RUN.json"), manifest)
}

d99_is_real_run <- function(root) file.exists(file.path(root, "REAL_RUN.json"))

d99_validate_real_run <- function(root, run_id = NULL, expected_root = NULL) {
  if (!is.null(expected_root) && !identical(normalizePath(root, mustWork = FALSE), normalizePath(expected_root, mustWork = FALSE))) return(FALSE)
  manifest <- d99_read_json(file.path(root, "REAL_RUN.json"))
  preflight <- file.path(root, "preflight.json")
  is.list(manifest) && identical(manifest$schema, "d99-real-preflight-v1") &&
    identical(manifest$preflight_status, "PASS") && identical(manifest$mode, "REAL_RUN") &&
    (is.null(run_id) || identical(manifest$run_id, run_id)) && file.exists(preflight) &&
    identical(d99_sha256_file(preflight), d99_sha256_file(file.path(root, "REAL_RUN.json")))
}

d99_runtime_metadata <- function() list(
  r_version = R.version.string, platform = R.version$platform,
  packages = lapply(c("statmod", "numDeriv", "nloptr", "cubature"), function(p) {
    if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else NA_character_
  }), sysname = Sys.info()[["sysname"]]
)
