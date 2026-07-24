d98_supervisor_dir <- function() {
  candidates <- c(
    getOption("d98_design_dir"),
    file.path(getwd(), "dev", "design98-factorial-va-jj", "R"),
    getwd()
  )
  hit <- candidates[file.exists(file.path(candidates, "records.R"))]
  if (!length(hit)) {
    stop("Cannot locate Design-98 records.R", call. = FALSE)
  }
  normalizePath(hit[[1L]])
}

if (!exists("d98_write_json_exclusive", mode = "function")) {
  source(file.path(d98_supervisor_dir(), "records.R"))
}

d98_blocked_terminal <- function(root, task_id, input, reason) {
  d98_write_terminal(
    root,
    task_id,
    list(
      status = "blocked_dependency",
      healthy = FALSE,
      reason = reason,
      input_sha256 = input$input_sha256,
      worker_launches = 0L,
      objective_constructions = 0L
    )
  )
  "blocked_dependency"
}

d98_launch_task <- function(root, task_id, worker_path) {
  if (!requireNamespace("processx", quietly = TRUE)) {
    d98_abort("Missing required package: processx")
  }
  state <- d98_task_state(root, task_id)
  if (!identical(state, "PENDING")) {
    return(state)
  }
  input_read <- d98_task_input(root, task_id)
  if (!input_read$ok) {
    d98_abort("Missing or malformed input for task ", task_id)
  }
  input <- input_read$value
  existing_payload <- d98_task_payload(root, task_id)
  if (!existing_payload$missing) {
    status <- if (existing_payload$ok) {
      "duplicate_payload"
    } else {
      "malformed_payload"
    }
    d98_write_terminal(
      root,
      task_id,
      list(
        status = status,
        healthy = FALSE,
        reason = if (existing_payload$ok) {
          "payload exists before launch"
        } else {
          existing_payload$error
        },
        input_sha256 = input$input_sha256,
        payload_sha256 = d98_hash_file(d98_path(root, "payloads", task_id)),
        worker_launches = 0L,
        objective_constructions = 0L
      )
    )
    return(status)
  }
  dependency_policy <- input$dependency_policy %||% "all_healthy"
  if (!dependency_policy %in% c("all_healthy", "all_terminal")) {
    d98_abort("Unknown dependency policy for task ", task_id)
  }
  dep_states <- vapply(
    input$dependencies,
    function(dep) d98_task_state(root, dep),
    character(1)
  )
  if (length(dep_states) && any(dep_states %in% c("PENDING", "orphaned"))) {
    return("PENDING")
  }
  if (identical(dependency_policy, "all_terminal")) {
    dep_states <- character()
  }
  bad_deps <- names(dep_states)[dep_states != "healthy"]
  if (length(bad_deps)) {
    return(d98_blocked_terminal(
      root,
      task_id,
      input,
      paste(bad_deps, collapse = ",")
    ))
  }

  stdout_path <- file.path(root, "logs", paste0(task_id, ".stdout"))
  stderr_path <- file.path(root, "logs", paste0(task_id, ".stderr"))
  d98_write_launch(root, task_id, input)
  started <- Sys.time()
  worker <- processx::process$new(
    command = file.path(R.home("bin"), "Rscript"),
    args = c(worker_path, "--root", root, "--task-id", task_id),
    stdout = stdout_path,
    stderr = stderr_path
  )
  timed_out <- FALSE
  timeout_reason <- NULL
  stale_after <- max(2 * as.numeric(input$heartbeat_sec), 10)
  while (worker$is_alive()) {
    Sys.sleep(0.2)
    elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    if (elapsed > as.numeric(input$wall_time_sec)) {
      timed_out <- TRUE
      timeout_reason <- "wall_time_limit"
      worker$kill()
      break
    }
    heartbeat_path <- file.path(root, "heartbeats", paste0(task_id, ".json"))
    if (
      (file.exists(heartbeat_path) &&
        d98_heartbeat_age(root, task_id) > stale_after) ||
        (!file.exists(heartbeat_path) && elapsed > stale_after)
    ) {
      timed_out <- TRUE
      timeout_reason <- "heartbeat_stale"
      worker$kill()
      break
    }
  }
  worker$wait()
  exit_status <- worker$get_exit_status()
  payload <- d98_task_payload(root, task_id)
  if (timed_out) {
    status <- "timed_out"
    healthy <- FALSE
    reason <- timeout_reason
  } else if (!payload$ok && !payload$missing) {
    status <- "malformed_payload"
    healthy <- FALSE
    reason <- payload$error
  } else if (payload$missing) {
    status <- "worker_exit_without_payload"
    healthy <- FALSE
    reason <- "worker produced no payload"
  } else if (!identical(exit_status, 0L)) {
    status <- "worker_nonzero_exit"
    healthy <- FALSE
    reason <- paste0("exit_status=", exit_status)
  } else if (!identical(payload$value$status, "healthy")) {
    status <- "worker_reported_unhealthy"
    healthy <- FALSE
    reason <- payload$value$reason %||% "worker payload unhealthy"
  } else {
    status <- "healthy"
    healthy <- TRUE
    reason <- NULL
  }
  terminal <- list(
    status = status,
    healthy = healthy,
    reason = reason,
    input_sha256 = input$input_sha256,
    pid = worker$get_pid(),
    host = Sys.info()[["nodename"]],
    started_utc = format(started, tz = "UTC", usetz = TRUE),
    elapsed_sec = as.numeric(difftime(Sys.time(), started, units = "secs")),
    exit_status = exit_status,
    signal = if (timed_out) "supervisor_kill" else NULL,
    stdout_sha256 = d98_hash_file(stdout_path),
    stderr_sha256 = d98_hash_file(stderr_path),
    payload_sha256 = d98_hash_file(d98_path(root, "payloads", task_id)),
    payload = if (payload$ok) payload$value else NULL,
    worker_launches = 1L,
    objective_constructions = 0L
  )
  d98_write_terminal(root, task_id, terminal)
  status
}

d98_run_ready <- function(root, worker_path) {
  ids <- d98_list_task_ids(root, "inputs")
  repeat {
    pending <- ids[vapply(
      ids,
      function(id) identical(d98_task_state(root, id), "PENDING"),
      logical(1)
    )]
    if (!length(pending)) {
      break
    }
    before <- vapply(
      pending,
      function(id) d98_task_state(root, id),
      character(1)
    )
    for (task_id in pending) {
      d98_launch_task(root, task_id, worker_path)
    }
    after <- vapply(
      pending,
      function(id) d98_task_state(root, id),
      character(1)
    )
    if (identical(before, after)) break
  }
  invisible(vapply(ids, function(id) d98_task_state(root, id), character(1)))
}
