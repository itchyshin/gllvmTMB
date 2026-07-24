#!/usr/bin/env Rscript

d98_finalize_script <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(arg)) {
    stop("finalize.R requires --file", call. = FALSE)
  }
  normalizePath(sub("^--file=", "", arg[[1L]]))
}

d98_finalize <- function(root) {
  record_dir <- file.path(root, "records")
  if (!dir.exists(record_dir)) {
    d98_abort("Missing records directory")
  }
  ids <- d98_list_task_ids(root, "inputs")
  states <- vapply(ids, function(id) d98_task_state(root, id), character(1))
  summary <- list(
    design = 98L,
    root = normalizePath(root),
    task_states = as.list(states),
    terminal_count = sum(states != "PENDING"),
    healthy_count = sum(states == "healthy"),
    worker_launches = 0L,
    objective_constructions = 0L,
    status = if (any(states %in% c("PENDING", "orphaned"))) {
      "TECHNICAL_INCOMPLETE"
    } else {
      "AGGREGATED_ONLY"
    },
    completed_utc = d98_now()
  )
  path <- file.path(root, "summary.json")
  if (file.exists(path)) {
    return(d98_read_json(path)$value)
  }
  d98_write_json_exclusive(path, summary)
  summary
}

if (sys.nframe() == 0L) {
  script_path <- d98_finalize_script()
  design_dir <- dirname(script_path)
  options(d98_design_dir = file.path(design_dir, "R"))
  source(file.path(design_dir, "R", "records.R"))
  args <- commandArgs(trailingOnly = TRUE)
  pos <- match("--root", args)
  if (is.na(pos) || pos == length(args)) {
    d98_abort("finalize.R requires --root")
  }
  print(d98_finalize(args[[pos + 1L]]))
}
