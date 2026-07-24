d98_abort <- function(...) {
  stop(paste0(..., collapse = ""), call. = FALSE)
}

d98_require <- function() {
  for (pkg in c("jsonlite", "digest")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      d98_abort("Missing required package: ", pkg)
    }
  }
  invisible(TRUE)
}

d98_now <- function() format(Sys.time(), tz = "UTC", usetz = TRUE)

d98_uuid <- function() {
  paste(
    format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC"),
    Sys.getpid(),
    sprintf("%08x", sample.int(.Machine$integer.max, 1L)),
    sep = "-"
  )
}

d98_hash_file <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }
  digest::digest(file = path, algo = "sha256")
}

d98_hash_object <- function(x) {
  digest::digest(
    serialize(x, NULL, version = 2L),
    algo = "sha256",
    serialize = FALSE
  )
}

d98_safe_task_id <- function(task_id) {
  is.character(task_id) &&
    length(task_id) == 1L &&
    grepl("^[A-Za-z][A-Za-z0-9_.-]*$", task_id)
}

d98_path <- function(root, type, task_id = NULL) {
  if (!is.null(task_id) && !d98_safe_task_id(task_id)) {
    d98_abort("Unsafe task id")
  }
  file.path(root, type, if (is.null(task_id)) "" else paste0(task_id, ".json"))
}

d98_make_directories <- function(root) {
  for (dir in c(
    root,
    file.path(root, "inputs"),
    file.path(root, "launches"),
    file.path(root, "payloads"),
    file.path(root, "records"),
    file.path(root, "heartbeats"),
    file.path(root, "logs")
  )) {
    if (
      !dir.exists(dir) &&
        !dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    ) {
      d98_abort("Could not create directory: ", dir)
    }
  }
  invisible(root)
}

# Atomic, no-overwrite publication: write beside the target, then use a hard
# link as the exclusive create operation. A malformed direct write is therefore
# recognisable as a fault, never silently repaired.
d98_write_json_exclusive <- function(path, object) {
  d98_require()
  if (!dir.exists(dirname(path))) {
    d98_abort("Missing parent directory: ", dirname(path))
  }
  tmp <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(unlink(tmp, force = TRUE), add = TRUE)
  text <- jsonlite::toJSON(
    object,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = 16,
    pretty = TRUE
  )
  writeLines(text, tmp, useBytes = TRUE)
  if (!file.link(tmp, path)) {
    d98_abort("Refusing overwrite or nonexclusive publish: ", path)
  }
  invisible(path)
}

d98_read_json <- function(path) {
  if (!file.exists(path)) {
    return(list(ok = FALSE, missing = TRUE, value = NULL, error = "missing"))
  }
  value <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) e
  )
  if (inherits(value, "error")) {
    return(list(
      ok = FALSE,
      missing = FALSE,
      value = NULL,
      error = conditionMessage(value)
    ))
  }
  list(ok = TRUE, missing = FALSE, value = value, error = NULL)
}

d98_create_real_run <- function(results_dir, uuid, base_commit, contract_path) {
  d98_require()
  if (
    !dir.exists(results_dir) &&
      !dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  ) {
    d98_abort("Could not create results directory")
  }
  if (!file.exists(contract_path)) {
    d98_abort("Missing contract: ", contract_path)
  }
  lock <- file.path(results_dir, "REAL_RUN.json")
  root <- file.path(results_dir, uuid)
  lock_record <- list(
    design = 98L,
    uuid = uuid,
    base_commit = base_commit,
    contract_sha256 = d98_hash_file(contract_path),
    status = "reserved",
    created_utc = d98_now()
  )
  d98_write_json_exclusive(lock, lock_record)
  if (!dir.create(root, recursive = FALSE, showWarnings = FALSE)) {
    d98_abort(
      "REAL_RUN lock was created but UUID root could not be created: ",
      root
    )
  }
  d98_make_directories(root)
  list(root = root, lock = lock)
}

d98_create_disposable_root <- function(parent, label = "fault") {
  if (
    !dir.exists(parent) &&
      !dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  ) {
    d98_abort("Could not create disposable-root parent")
  }
  root <- file.path(parent, paste0(label, "-", d98_uuid()))
  if (!dir.create(root, recursive = FALSE, showWarnings = FALSE)) {
    d98_abort("Could not create disposable root")
  }
  d98_make_directories(root)
  d98_write_json_exclusive(
    file.path(root, "manifest.json"),
    list(
      design = 98L,
      fault_injection = TRUE,
      uuid = basename(root),
      created_utc = d98_now()
    )
  )
  root
}

d98_create_manifest <- function(root, fields) {
  d98_make_directories(root)
  required <- c(
    "base_commit",
    "contract_sha256",
    "oracle_sha256",
    "cpp_sha256",
    "worker_sha256",
    "rng_kind",
    "gh_checksums"
  )
  missing <- setdiff(required, names(fields))
  if (length(missing)) {
    d98_abort(
      "Manifest lacks required fields: ",
      paste(missing, collapse = ", ")
    )
  }
  manifest <- fields
  manifest$design <- 98L
  manifest$git_status_porcelain <- fields$git_status_porcelain %||% ""
  manifest$created_utc <- d98_now()
  d98_write_json_exclusive(file.path(root, "manifest.json"), manifest)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

d98_create_task_input <- function(root, task) {
  d98_make_directories(root)
  if (is.null(task$task_id) || !d98_safe_task_id(task$task_id)) {
    d98_abort("Task must have a safe task_id")
  }
  task$dependencies <- task$dependencies %||% character()
  if (
    !is.character(task$dependencies) ||
      any(!vapply(task$dependencies, d98_safe_task_id, logical(1)))
  ) {
    d98_abort("Task dependencies must be safe task IDs")
  }
  task$wall_time_sec <- task$wall_time_sec %||% 60
  task$heartbeat_sec <- task$heartbeat_sec %||% 5
  task$created_utc <- d98_now()
  task$input_sha256 <- d98_hash_object(task[setdiff(
    names(task),
    "input_sha256"
  )])
  d98_write_json_exclusive(d98_path(root, "inputs", task$task_id), task)
}

d98_task_input <- function(root, task_id) {
  d98_read_json(d98_path(root, "inputs", task_id))
}
d98_task_record <- function(root, task_id) {
  d98_read_json(d98_path(root, "records", task_id))
}
d98_task_launch <- function(root, task_id) {
  d98_read_json(d98_path(root, "launches", task_id))
}
d98_task_payload <- function(root, task_id) {
  d98_read_json(d98_path(root, "payloads", task_id))
}

d98_task_state <- function(root, task_id) {
  record <- d98_task_record(root, task_id)
  if (record$ok) {
    return(record$value$status %||% "malformed_record")
  }
  if (!record$missing) {
    return("malformed_record")
  }
  launch <- d98_task_launch(root, task_id)
  if (launch$ok || !launch$missing) {
    return("orphaned")
  }
  "PENDING"
}

d98_is_healthy <- function(root, task_id) {
  identical(d98_task_state(root, task_id), "healthy")
}

d98_write_launch <- function(root, task_id, input, pid = NA_integer_) {
  d98_write_json_exclusive(
    d98_path(root, "launches", task_id),
    list(
      task_id = task_id,
      dependencies = input$dependencies %||% character(),
      input_sha256 = input$input_sha256,
      pid = pid,
      host = Sys.info()[["nodename"]],
      started_utc = d98_now()
    )
  )
}

d98_write_heartbeat <- function(root, task_id, state = "running") {
  path <- file.path(root, "heartbeats", paste0(task_id, ".json"))
  # Heartbeats are deliberately mutable liveness signals, not evidence records.
  # Direct replacement avoids platform-specific rename-over-existing failures.
  writeLines(
    jsonlite::toJSON(
      list(task_id = task_id, state = state, utc = d98_now()),
      auto_unbox = TRUE
    ),
    path
  )
  invisible(path)
}

d98_heartbeat_age <- function(root, task_id) {
  path <- file.path(root, "heartbeats", paste0(task_id, ".json"))
  if (!file.exists(path)) {
    return(Inf)
  }
  as.numeric(difftime(Sys.time(), file.info(path)$mtime, units = "secs"))
}

d98_write_terminal <- function(root, task_id, terminal) {
  terminal$task_id <- task_id
  terminal$completed_utc <- terminal$completed_utc %||% d98_now()
  d98_write_json_exclusive(d98_path(root, "records", task_id), terminal)
}

d98_list_task_ids <- function(root, type = "inputs") {
  dir <- file.path(root, type)
  files <- list.files(dir, pattern = "[.]json$", full.names = FALSE)
  sub("[.]json$", "", sort(files))
}
