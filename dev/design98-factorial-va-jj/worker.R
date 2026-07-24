#!/usr/bin/env Rscript

d98_worker_script <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(arg)) {
    stop("worker.R requires --file", call. = FALSE)
  }
  normalizePath(sub("^--file=", "", arg[[1L]]))
}

d98_parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  take <- function(name) {
    pos <- match(name, args)
    if (is.na(pos) || pos == length(args)) {
      stop("Missing ", name, call. = FALSE)
    }
    args[[pos + 1L]]
  }
  list(root = take("--root"), task_id = take("--task-id"))
}

script_path <- d98_worker_script()
design_dir <- dirname(script_path)
options(d98_design_dir = file.path(design_dir, "R"))
source(file.path(design_dir, "R", "records.R"))
d98_require()

args <- d98_parse_args()
if (!d98_safe_task_id(args$task_id)) {
  d98_abort("Unsafe task id")
}
input_read <- d98_task_input(args$root, args$task_id)
if (!input_read$ok) {
  d98_abort("Worker input is missing or malformed")
}
input <- input_read$value

d98_write_heartbeat(args$root, args$task_id, "started")
action <- input$action %||% "success"
payload_path <- d98_path(args$root, "payloads", args$task_id)

if (identical(action, "crash")) {
  cat("fault-injection crash\n", file = stderr())
  quit(save = "no", status = 86L)
}
if (identical(action, "malformed")) {
  writeLines("{ malformed-json", payload_path)
  quit(save = "no", status = 0L)
}
if (identical(action, "partial")) {
  con <- file(payload_path, open = "w")
  writeChar("{\"status\":", con, eos = NULL)
  close(con)
  quit(save = "no", status = 0L)
}

if (identical(action, "sleep")) {
  seconds <- as.numeric(input$sleep_sec %||% 1)
  deadline <- Sys.time() + seconds
  while (Sys.time() < deadline) {
    d98_write_heartbeat(args$root, args$task_id, "sleeping")
    Sys.sleep(min(1, as.numeric(input$heartbeat_sec %||% 1)))
  }
}

d98_write_heartbeat(args$root, args$task_id, "publishing")
d98_write_json_exclusive(
  payload_path,
  list(
    task_id = args$task_id,
    status = "healthy",
    action = action,
    raw_coordinates = input$raw_coordinates %||% numeric(),
    transformed_parameters = input$transformed_parameters %||% list(),
    objective = input$objective %||% NA_real_,
    phase_code = input$phase_code %||% 0L,
    gradient_max = input$gradient_max %||% 0,
    warnings = character(),
    error = NULL,
    realised_inputs = input,
    completed_utc = d98_now()
  )
)
d98_write_heartbeat(args$root, args$task_id, "completed")
