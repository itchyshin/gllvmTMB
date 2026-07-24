#!/usr/bin/env Rscript

d98_fit_worker_script <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(arg)) stop("fit-worker.R requires --file", call. = FALSE)
  normalizePath(sub("^--file=", "", arg[[1L]]))
}

d98_fit_worker_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  take <- function(name) {
    position <- match(name, args)
    if (is.na(position) || position == length(args)) {
      stop("Missing ", name, call. = FALSE)
    }
    args[[position + 1L]]
  }
  list(root = take("--root"), task_id = take("--task-id"))
}

script_path <- d98_fit_worker_script()
design_dir <- dirname(script_path)
options(d98_design_dir = design_dir)
source(file.path(design_dir, "R", "records.R"))
source(file.path(design_dir, "R", "oracle.R"))
source(file.path(design_dir, "R", "fits.R"))
d98_require()

args <- d98_fit_worker_args()
if (!d98_safe_task_id(args$task_id)) d98_abort("Unsafe task id")
input_read <- d98_task_input(args$root, args$task_id)
if (!input_read$ok) d98_abort("Fit-worker input is missing or malformed")
input <- input_read$value

payload_path <- d98_path(args$root, "payloads", args$task_id)
if (file.exists(payload_path)) d98_abort("Fit-worker payload already exists")

dependencies <- lapply(input$dependencies %||% character(), function(id) {
  terminal <- d98_task_record(args$root, id)
  payload <- d98_task_payload(args$root, id)
  list(
    task_id = id,
    terminal_status = d98_task_state(args$root, id),
    terminal = if (terminal$ok) terminal$value else NULL,
    payload = if (payload$ok) payload$value else NULL,
    payload_sha256 = d98_hash_file(d98_path(args$root, "payloads", id))
  )
})
dependency_hashes <- vapply(
  input$dependencies %||% character(),
  function(id) d98_hash_file(d98_path(args$root, "payloads", id)),
  character(1)
)

d98_write_heartbeat(args$root, args$task_id, "starting")
heartbeat <- d98_start_concurrent_heartbeat(
  args$root,
  args$task_id,
  as.numeric(input$heartbeat_sec %||% 5)
)
on.exit(d98_stop_concurrent_heartbeat(heartbeat), add = TRUE)
on.exit(d98_cleanup_fit_cache(), add = TRUE)

payload <- tryCatch(
  d98_run_fit_action(input, dependencies, design_dir, root = args$root),
  error = function(error) {
    list(
      status = "unhealthy",
      healthy = FALSE,
      reason = "worker_error",
      action = input$action %||% NA_character_,
      raw_coordinates = numeric(),
      transformed_parameters = list(),
      objective = NA_real_,
      phase_code = NA_integer_,
      gradient = numeric(),
      gradient_max = NA_real_,
      metrics = list(),
      optimizer = NULL,
      warnings = character(),
      error = conditionMessage(error)
    )
  }
)
payload$task_id <- args$task_id
payload$input_sha256 <- input$input_sha256
payload$dependency_task_ids <- input$dependencies %||% character()
payload$dependency_payload_sha256 <- dependency_hashes
payload$realised_inputs <- input
payload$completed_utc <- d98_now()

d98_write_heartbeat(args$root, args$task_id, "publishing")
d98_write_json_exclusive(payload_path, payload)
d98_write_heartbeat(args$root, args$task_id, "completed")
