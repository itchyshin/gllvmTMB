## Checkpointed array tasks for the frozen temporal--phylogenetic damped-Newton
## qualification. Every expensive TMB evaluation writes a new receipt; the
## collector stages are pure R and refuse incomplete or mismatched receipts.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name) {
  hit <- grep(paste0("^", name, "="), args, value = TRUE)
  if (length(hit) != 1L) return(NULL)
  sub(paste0("^", name, "="), "", hit)
}
root <- normalizePath(".", mustWork = TRUE)
script_dir <- file.path(root, "dev", "temporal-program", "remote")
sys.source(file.path(script_dir, "phylo-damped-newton-common.R"), envir = globalenv())
mode <- arg_value("--mode")
if (is.null(mode)) mode <- "task"
plan <- temporal_phylo_damped_newton_plan()
plan$task_id <- seq_len(nrow(plan))
plan <- plan[c("task_id", "role", "phi", "seed")]
controls <- temporal_phylo_damped_newton_controls()

same_number <- function(x, y) {
  length(x) == length(y) && all(is.finite(x)) && all(is.finite(y)) &&
    isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance = 0))
}
need_arg <- function(name, exists = FALSE, directory = FALSE) {
  value <- arg_value(name)
  if (is.null(value) || !nzchar(value) || (exists && !file.exists(value)) || (directory && !dir.exists(value))) {
    stop(sprintf("%s is required.", name), call. = FALSE)
  }
  value
}
read_baseline <- function(checkpoint_dir, task_id) {
  path <- file.path(checkpoint_dir, sprintf("phylo-damped-newton-baseline-%02d.rds", task_id))
  if (!file.exists(path)) stop(sprintf("Missing frozen baseline checkpoint for task %d.", task_id), call. = FALSE)
  x <- readRDS(path)
  expected <- plan[task_id, , drop = FALSE]
  ok <- is.list(x) && identical(x$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
    identical(x$stage, "baseline") && identical(as.numeric(x$phi), as.numeric(expected$phi[[1L]])) &&
    identical(as.integer(x$seed), as.integer(expected$seed[[1L]])) &&
    identical(as.character(x$role), as.character(expected$role[[1L]])) &&
    length(x$theta) > 0L && length(x$theta_names) == length(x$theta) &&
    is.list(x$baseline) && !is.null(x$baseline$fresh$gradient)
  if (!ok) stop(sprintf("Invalid frozen baseline checkpoint for task %d.", task_id), call. = FALSE)
  x$theta <- stats::setNames(as.numeric(x$theta), x$theta_names)
  list(path = normalizePath(path), value = x)
}
new_receipt_path <- function(results_dir, stem, task_id, width = 2L) {
  dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  results_dir <- normalizePath(results_dir, mustWork = TRUE)
  path <- file.path(results_dir, sprintf(paste0(stem, "%0", width, "d.rds"), task_id))
  if (file.exists(path)) stop(sprintf("Refusing to overwrite retained receipt: %s", path), call. = FALSE)
  path
}
read_table_nonempty_columns <- function(path, columns) {
  x <- utils::read.delim(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!identical(names(x), columns)) stop("Frozen task plan has the wrong columns.", call. = FALSE)
  x
}

if (identical(mode, "plan")) {
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_TASK_PLAN_PASS tasks=%d\n", nrow(plan)))
  quit(save = "no", status = 0L)
}
valid_modes <- c("task", "baseline", "probe_plan", "probe", "curvature_collect", "line_plan", "line_probe", "step_collect", "final_plan", "final_probe", "final_collect")
if (!mode %in% valid_modes) {
  stop("usage: Rscript --vanilla phylo-damped-newton-task.R --mode=plan|task|baseline|probe_plan|probe|curvature_collect|line_plan|line_probe|step_collect|final_plan|final_probe|final_collect", call. = FALSE)
}

task_id <- suppressWarnings(as.integer(arg_value("--task-id")))
results_dir <- arg_value("--results-dir")

if (identical(mode, "probe_plan")) {
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  output <- need_arg("--output")
  if (file.exists(output)) stop("Refusing to overwrite frozen probe plan.", call. = FALSE)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    baseline <- read_baseline(checkpoint_dir, i)$value
    expand.grid(cell_task_id = i, coordinate = seq_along(baseline$theta),
      multiplier = controls$fd_multipliers, direction = c("plus", "minus"),
      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  })
  probes <- do.call(rbind, rows)
  probes$probe_task_id <- seq_len(nrow(probes))
  probes <- probes[c("probe_task_id", "cell_task_id", "coordinate", "multiplier", "direction")]
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(probes, output, sep = "\t", row.names = FALSE, quote = FALSE)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_PROBE_PLAN_PASS probes=%d output=%s\n", nrow(probes), output))
  quit(save = "no", status = 0L)
}

if (identical(mode, "probe")) {
  probe_plan <- need_arg("--probe-plan", exists = TRUE)
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  probe_task_id <- suppressWarnings(as.integer(arg_value("--probe-task-id")))
  if (is.na(probe_task_id) || is.null(results_dir) || !nzchar(results_dir)) stop("probe requires a task id and results directory.", call. = FALSE)
  probes <- read_table_nonempty_columns(probe_plan, c("probe_task_id", "cell_task_id", "coordinate", "multiplier", "direction"))
  row <- probes[probes$probe_task_id == probe_task_id, , drop = FALSE]
  if (nrow(row) != 1L) stop("Probe task id is absent or duplicated in its frozen plan.", call. = FALSE)
  cell <- plan[row$cell_task_id[[1L]], , drop = FALSE]
  checkpoint <- read_baseline(checkpoint_dir, row$cell_task_id[[1L]])
  out_path <- new_receipt_path(results_dir, "phylo-damped-newton-probe-", probe_task_id, width = 4L)
  runner <- file.path(script_dir, "phylo-damped-newton.R")
  status <- system2("Rscript", c("--vanilla", runner, "--stage=curvature_probe",
    paste0("--phi=", cell$phi[[1L]]), paste0("--seed=", cell$seed[[1L]]),
    paste0("--checkpoint=", checkpoint$path), paste0("--coordinate=", row$coordinate[[1L]]),
    paste0("--multiplier=", row$multiplier[[1L]]), paste0("--direction=", row$direction[[1L]]),
    paste0("--output=", out_path)))
  if (!identical(as.integer(status), 0L) || !file.exists(out_path)) stop("Curvature probe did not retain its receipt.", call. = FALSE)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_PROBE_PASS task=%d output=%s\n", probe_task_id, out_path))
  quit(save = "no", status = 0L)
}

if (identical(mode, "curvature_collect")) {
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  probe_plan <- need_arg("--probe-plan", exists = TRUE)
  probe_dir <- need_arg("--probe-dir", directory = TRUE)
  if (length(task_id) != 1L || is.na(task_id) || task_id < 1L || task_id > nrow(plan) || is.null(results_dir) || !nzchar(results_dir)) {
    stop("curvature_collect requires a valid cell task id and results directory.", call. = FALSE)
  }
  baseline <- read_baseline(checkpoint_dir, task_id)
  probes <- read_table_nonempty_columns(probe_plan, c("probe_task_id", "cell_task_id", "coordinate", "multiplier", "direction"))
  needed <- probes[probes$cell_task_id == task_id, , drop = FALSE]
  expected_n <- length(baseline$value$theta) * length(controls$fd_multipliers) * 2L
  if (nrow(needed) != expected_n || anyDuplicated(needed[c("coordinate", "multiplier", "direction")])) {
    stop("Frozen curvature plan is incomplete or duplicated for this cell.", call. = FALSE)
  }
  lookup <- vector("list", nrow(needed))
  for (i in seq_len(nrow(needed))) {
    row <- needed[i, , drop = FALSE]
    path <- file.path(probe_dir, sprintf("phylo-damped-newton-probe-%04d.rds", row$probe_task_id[[1L]]))
    if (!file.exists(path)) stop(sprintf("Missing curvature probe %d.", row$probe_task_id[[1L]]), call. = FALSE)
    x <- readRDS(path)
    coordinate <- as.integer(row$coordinate[[1L]])
    h <- as.numeric(row$multiplier[[1L]]) * controls$fd_scale * max(1, abs(baseline$value$theta[[coordinate]]))
    endpoint <- baseline$value$theta
    endpoint[[coordinate]] <- endpoint[[coordinate]] + if (identical(row$direction[[1L]], "plus")) h else -h
    ok <- is.list(x) && identical(x$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
      identical(x$stage, "curvature_probe") && identical(as.numeric(x$phi), as.numeric(baseline$value$phi)) &&
      identical(as.integer(x$seed), as.integer(baseline$value$seed)) && identical(as.integer(x$coordinate), coordinate) &&
      identical(as.numeric(x$multiplier), as.numeric(row$multiplier[[1L]])) && identical(as.character(x$direction), as.character(row$direction[[1L]])) &&
      same_number(x$endpoint, endpoint) && is.list(x$evaluated) && length(x$evaluated$gradient) == length(endpoint)
    if (!ok) stop(sprintf("Curvature probe %d does not match its frozen endpoint.", row$probe_task_id[[1L]]), call. = FALSE)
    lookup[[i]] <- list(endpoint = endpoint, evaluated = x$evaluated, path = normalizePath(path))
  }
  gradient_fn <- function(theta) {
    if (same_number(theta, baseline$value$theta)) return(baseline$value$baseline$fresh$gradient)
    hit <- vapply(lookup, function(x) same_number(theta, x$endpoint), logical(1))
    if (sum(hit) != 1L) return(rep(NA_real_, length(theta)))
    lookup[[which(hit)]]$evaluated$gradient
  }
  curvature <- temporal_phylo_damped_newton_curvature(baseline$value$theta, gradient_fn)
  out_path <- new_receipt_path(results_dir, "phylo-damped-newton-curvature-", task_id)
  receipt <- list(schema = "temporal_phylo_damped_newton_checkpoint_v1", stage = "curvature_collect",
    source_commit = baseline$value$source_commit, phi = baseline$value$phi, seed = baseline$value$seed,
    role = baseline$value$role, checkpoint = baseline$path, theta = unname(baseline$value$theta),
    theta_names = names(baseline$value$theta), curvature = curvature, probe_receipts = vapply(lookup, `[[`, character(1), "path"))
  saveRDS(receipt, out_path)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_CURVATURE_COLLECT_PASS task=%d output=%s\n", task_id, out_path))
  quit(save = "no", status = 0L)
}

if (identical(mode, "line_plan")) {
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  curvature_dir <- need_arg("--curvature-dir", directory = TRUE)
  output <- need_arg("--output")
  if (file.exists(output)) stop("Refusing to overwrite frozen line-search plan.", call. = FALSE)
  rows <- list()
  for (i in seq_len(nrow(plan))) {
    baseline <- read_baseline(checkpoint_dir, i)$value
    path <- file.path(curvature_dir, sprintf("phylo-damped-newton-curvature-%02d.rds", i))
    if (!file.exists(path)) stop(sprintf("Missing curvature collection for task %d.", i), call. = FALSE)
    x <- readRDS(path)
    ok <- is.list(x) && identical(x$schema, "temporal_phylo_damped_newton_checkpoint_v1") && identical(x$stage, "curvature_collect") &&
      identical(as.numeric(x$phi), as.numeric(baseline$phi)) && identical(as.integer(x$seed), as.integer(baseline$seed)) &&
      identical(x$theta_names, names(baseline$theta)) && same_number(x$theta, baseline$theta)
    if (!ok) stop(sprintf("Invalid curvature collection for task %d.", i), call. = FALSE)
    if (isTRUE(x$curvature$eligible)) rows[[length(rows) + 1L]] <- data.frame(cell_task_id = i, alpha = controls$alpha)
  }
  line <- if (length(rows)) do.call(rbind, rows) else data.frame(cell_task_id = integer(), alpha = numeric())
  line$line_task_id <- seq_len(nrow(line))
  line <- line[c("line_task_id", "cell_task_id", "alpha")]
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(line, output, sep = "\t", row.names = FALSE, quote = FALSE)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_LINE_PLAN_PASS trials=%d output=%s\n", nrow(line), output))
  quit(save = "no", status = 0L)
}

if (identical(mode, "line_probe")) {
  line_plan <- need_arg("--line-plan", exists = TRUE)
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  curvature_dir <- need_arg("--curvature-dir", directory = TRUE)
  line_task_id <- suppressWarnings(as.integer(arg_value("--line-task-id")))
  if (is.na(line_task_id) || is.null(results_dir) || !nzchar(results_dir)) stop("line_probe requires a task id and results directory.", call. = FALSE)
  line <- read_table_nonempty_columns(line_plan, c("line_task_id", "cell_task_id", "alpha"))
  row <- line[line$line_task_id == line_task_id, , drop = FALSE]
  if (nrow(row) != 1L) stop("Line task id is absent or duplicated in its frozen plan.", call. = FALSE)
  cell <- plan[row$cell_task_id[[1L]], , drop = FALSE]
  checkpoint <- read_baseline(checkpoint_dir, row$cell_task_id[[1L]])
  curvature <- file.path(curvature_dir, sprintf("phylo-damped-newton-curvature-%02d.rds", row$cell_task_id[[1L]]))
  out_path <- new_receipt_path(results_dir, "phylo-damped-newton-line-", line_task_id, width = 4L)
  status <- system2("Rscript", c("--vanilla", file.path(script_dir, "phylo-damped-newton.R"), "--stage=endpoint_probe", "--purpose=line_trial",
    paste0("--phi=", cell$phi[[1L]]), paste0("--seed=", cell$seed[[1L]]), paste0("--checkpoint=", checkpoint$path),
    paste0("--curvature=", normalizePath(curvature)), paste0("--alpha=", row$alpha[[1L]]), paste0("--output=", out_path)))
  if (!identical(as.integer(status), 0L) || !file.exists(out_path)) stop("Line trial did not retain its receipt.", call. = FALSE)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_LINE_PROBE_PASS task=%d output=%s\n", line_task_id, out_path))
  quit(save = "no", status = 0L)
}

if (identical(mode, "step_collect")) {
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  curvature_dir <- need_arg("--curvature-dir", directory = TRUE)
  line_plan <- need_arg("--line-plan", exists = TRUE)
  line_dir <- need_arg("--line-dir", directory = TRUE)
  if (length(task_id) != 1L || is.na(task_id) || task_id < 1L || task_id > nrow(plan) || is.null(results_dir) || !nzchar(results_dir)) stop("step_collect requires a valid cell task id and results directory.", call. = FALSE)
  baseline <- read_baseline(checkpoint_dir, task_id)
  curvature_path <- file.path(curvature_dir, sprintf("phylo-damped-newton-curvature-%02d.rds", task_id))
  if (!file.exists(curvature_path)) stop("Missing curvature receipt for step collection.", call. = FALSE)
  curvature_receipt <- readRDS(curvature_path)
  curvature_ok <- is.list(curvature_receipt) &&
    identical(curvature_receipt$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
    identical(curvature_receipt$stage, "curvature_collect") &&
    identical(as.numeric(curvature_receipt$phi), as.numeric(baseline$value$phi)) &&
    identical(as.integer(curvature_receipt$seed), as.integer(baseline$value$seed)) &&
    identical(curvature_receipt$theta_names, names(baseline$value$theta)) &&
    same_number(curvature_receipt$theta, baseline$value$theta)
  if (!curvature_ok) stop("Curvature receipt does not match the frozen baseline.", call. = FALSE)
  curvature <- curvature_receipt$curvature
  if (!isTRUE(curvature$eligible)) {
    step <- list(accepted = FALSE, selected_index = NA_integer_, selected_alpha = NA_real_, selected = NULL, trials = list(), rejection_reasons = "curvature_ineligible")
  } else {
    line <- read_table_nonempty_columns(line_plan, c("line_task_id", "cell_task_id", "alpha"))
    needed <- line[line$cell_task_id == task_id, , drop = FALSE]
    if (nrow(needed) != length(controls$alpha) || !identical(as.numeric(needed$alpha), as.numeric(controls$alpha))) stop("Frozen line-search plan is incomplete or reordered.", call. = FALSE)
    lookup <- vector("list", nrow(needed))
    for (i in seq_len(nrow(needed))) {
      row <- needed[i, , drop = FALSE]
      path <- file.path(line_dir, sprintf("phylo-damped-newton-line-%04d.rds", row$line_task_id[[1L]]))
      if (!file.exists(path)) stop(sprintf("Missing line trial %d.", row$line_task_id[[1L]]), call. = FALSE)
      x <- readRDS(path)
      endpoint <- baseline$value$theta + row$alpha[[1L]] * curvature$direction
      ok <- is.list(x) && identical(x$schema, "temporal_phylo_damped_newton_checkpoint_v1") && identical(x$stage, "endpoint_probe") &&
        identical(x$purpose, "line_trial") && identical(as.numeric(x$phi), as.numeric(baseline$value$phi)) && identical(as.integer(x$seed), as.integer(baseline$value$seed)) &&
        identical(as.numeric(x$alpha), as.numeric(row$alpha[[1L]])) && same_number(x$endpoint, endpoint) && is.list(x$evaluated)
      if (!ok) stop(sprintf("Line trial %d does not match its frozen endpoint.", row$line_task_id[[1L]]), call. = FALSE)
      lookup[[i]] <- list(endpoint = endpoint, evaluated = x$evaluated, path = normalizePath(path))
    }
    evaluate <- function(endpoint) {
      hit <- vapply(lookup, function(x) same_number(endpoint, x$endpoint), logical(1))
      if (sum(hit) != 1L) return(list(eligible = FALSE, objective = NA_real_, error = "unplanned line endpoint"))
      lookup[[which(hit)]]$evaluated
    }
    step <- temporal_phylo_damped_newton_select_step(baseline$value$theta, curvature$direction, curvature$gradient,
      baseline$value$baseline$fresh$objective, evaluate)
  }
  out_path <- new_receipt_path(results_dir, "phylo-damped-newton-step-", task_id)
  receipt <- list(schema = "temporal_phylo_damped_newton_checkpoint_v1", stage = "step_collect",
    source_commit = baseline$value$source_commit, phi = baseline$value$phi, seed = baseline$value$seed, role = baseline$value$role,
    checkpoint = baseline$path, curvature = normalizePath(curvature_path), theta = unname(baseline$value$theta), theta_names = names(baseline$value$theta), step = step)
  saveRDS(receipt, out_path)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_STEP_COLLECT_PASS task=%d output=%s\n", task_id, out_path))
  quit(save = "no", status = 0L)
}

if (identical(mode, "final_plan")) {
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  step_dir <- need_arg("--step-dir", directory = TRUE)
  output <- need_arg("--output")
  if (file.exists(output)) stop("Refusing to overwrite frozen final-replay plan.", call. = FALSE)
  rows <- list()
  for (i in seq_len(nrow(plan))) {
    baseline <- read_baseline(checkpoint_dir, i)$value
    path <- file.path(step_dir, sprintf("phylo-damped-newton-step-%02d.rds", i))
    if (!file.exists(path)) stop(sprintf("Missing step receipt for task %d.", i), call. = FALSE)
    x <- readRDS(path)
    ok <- is.list(x) && identical(x$schema, "temporal_phylo_damped_newton_checkpoint_v1") && identical(x$stage, "step_collect") &&
      identical(as.numeric(x$phi), as.numeric(baseline$phi)) && identical(as.integer(x$seed), as.integer(baseline$seed)) && same_number(x$theta, baseline$theta)
    if (!ok) stop(sprintf("Invalid step receipt for task %d.", i), call. = FALSE)
    if (isTRUE(x$step$accepted)) rows[[length(rows) + 1L]] <- data.frame(cell_task_id = i, replicate = 1:2)
  }
  final <- if (length(rows)) do.call(rbind, rows) else data.frame(cell_task_id = integer(), replicate = integer())
  final$final_task_id <- seq_len(nrow(final))
  final <- final[c("final_task_id", "cell_task_id", "replicate")]
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(final, output, sep = "\t", row.names = FALSE, quote = FALSE)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_FINAL_PLAN_PASS replays=%d output=%s\n", nrow(final), output))
  quit(save = "no", status = 0L)
}

if (identical(mode, "final_probe")) {
  final_plan <- need_arg("--final-plan", exists = TRUE)
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  step_dir <- need_arg("--step-dir", directory = TRUE)
  final_task_id <- suppressWarnings(as.integer(arg_value("--final-task-id")))
  if (is.na(final_task_id) || is.null(results_dir) || !nzchar(results_dir)) stop("final_probe requires a task id and results directory.", call. = FALSE)
  final <- read_table_nonempty_columns(final_plan, c("final_task_id", "cell_task_id", "replicate"))
  row <- final[final$final_task_id == final_task_id, , drop = FALSE]
  if (nrow(row) != 1L) stop("Final task id is absent or duplicated in its frozen plan.", call. = FALSE)
  cell <- plan[row$cell_task_id[[1L]], , drop = FALSE]
  checkpoint <- read_baseline(checkpoint_dir, row$cell_task_id[[1L]])
  step_path <- file.path(step_dir, sprintf("phylo-damped-newton-step-%02d.rds", row$cell_task_id[[1L]]))
  out_path <- new_receipt_path(results_dir, "phylo-damped-newton-final-", final_task_id, width = 4L)
  status <- system2("Rscript", c("--vanilla", file.path(script_dir, "phylo-damped-newton.R"), "--stage=endpoint_probe", "--purpose=final_replay",
    paste0("--phi=", cell$phi[[1L]]), paste0("--seed=", cell$seed[[1L]]), paste0("--checkpoint=", checkpoint$path),
    paste0("--step=", normalizePath(step_path)), paste0("--replicate=", row$replicate[[1L]]), paste0("--output=", out_path)))
  if (!identical(as.integer(status), 0L) || !file.exists(out_path)) stop("Final replay did not retain its receipt.", call. = FALSE)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_FINAL_PROBE_PASS task=%d output=%s\n", final_task_id, out_path))
  quit(save = "no", status = 0L)
}

if (identical(mode, "final_collect")) {
  checkpoint_dir <- need_arg("--checkpoint-dir", directory = TRUE)
  curvature_dir <- need_arg("--curvature-dir", directory = TRUE)
  step_dir <- need_arg("--step-dir", directory = TRUE)
  final_plan <- need_arg("--final-plan", exists = TRUE)
  final_dir <- need_arg("--final-dir", directory = TRUE)
  if (length(task_id) != 1L || is.na(task_id) || task_id < 1L || task_id > nrow(plan) || is.null(results_dir) || !nzchar(results_dir)) stop("final_collect requires a valid cell task id and results directory.", call. = FALSE)
  baseline <- read_baseline(checkpoint_dir, task_id)
  curvature_path <- file.path(curvature_dir, sprintf("phylo-damped-newton-curvature-%02d.rds", task_id))
  step_path <- file.path(step_dir, sprintf("phylo-damped-newton-step-%02d.rds", task_id))
  if (!file.exists(curvature_path) || !file.exists(step_path)) stop("Missing curvature or step receipt for final collection.", call. = FALSE)
  curvature_receipt <- readRDS(curvature_path)
  step_receipt <- readRDS(step_path)
  curvature_ok <- is.list(curvature_receipt) &&
    identical(curvature_receipt$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
    identical(curvature_receipt$stage, "curvature_collect") &&
    identical(as.numeric(curvature_receipt$phi), as.numeric(baseline$value$phi)) &&
    identical(as.integer(curvature_receipt$seed), as.integer(baseline$value$seed)) &&
    identical(curvature_receipt$theta_names, names(baseline$value$theta)) &&
    same_number(curvature_receipt$theta, baseline$value$theta)
  step_ok <- is.list(step_receipt) &&
    identical(step_receipt$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
    identical(step_receipt$stage, "step_collect") &&
    identical(as.numeric(step_receipt$phi), as.numeric(baseline$value$phi)) &&
    identical(as.integer(step_receipt$seed), as.integer(baseline$value$seed)) &&
    identical(step_receipt$theta_names, names(baseline$value$theta)) &&
    same_number(step_receipt$theta, baseline$value$theta)
  if (!curvature_ok || !step_ok) stop("Curvature or step receipt does not match the frozen baseline.", call. = FALSE)
  curvature <- curvature_receipt$curvature
  step <- step_receipt$step
  final <- replay <- NULL
  if (isTRUE(step$accepted)) {
    table <- read_table_nonempty_columns(final_plan, c("final_task_id", "cell_task_id", "replicate"))
    needed <- table[table$cell_task_id == task_id, , drop = FALSE]
    if (nrow(needed) != 2L || !identical(as.integer(needed$replicate), 1:2)) stop("Frozen final-replay plan is incomplete or reordered.", call. = FALSE)
    evaluations <- vector("list", 2L)
    for (i in 1:2) {
      row <- needed[needed$replicate == i, , drop = FALSE]
      path <- file.path(final_dir, sprintf("phylo-damped-newton-final-%04d.rds", row$final_task_id[[1L]]))
      if (!file.exists(path)) stop(sprintf("Missing final replay %d.", i), call. = FALSE)
      x <- readRDS(path)
      ok <- is.list(x) && identical(x$schema, "temporal_phylo_damped_newton_checkpoint_v1") && identical(x$stage, "endpoint_probe") &&
        identical(x$purpose, "final_replay") && identical(as.integer(x$replicate), i) &&
        identical(as.numeric(x$phi), as.numeric(baseline$value$phi)) && identical(as.integer(x$seed), as.integer(baseline$value$seed)) &&
        same_number(x$endpoint, step$selected$endpoint) && is.list(x$evaluated)
      if (!ok) stop(sprintf("Final replay %d does not match its selected endpoint.", i), call. = FALSE)
      evaluations[[i]] <- x$evaluated
    }
    final <- evaluations[[1L]]; replay <- evaluations[[2L]]
  }
  adjudication <- temporal_phylo_damped_newton_adjudicate_evaluated(baseline$value$baseline, curvature, step, final, replay)
  out_path <- new_receipt_path(results_dir, "phylo-damped-newton-decision-", task_id)
  receipt <- list(schema = "temporal_phylo_damped_newton_checkpoint_v1", stage = "final_collect",
    source_commit = baseline$value$source_commit, phi = baseline$value$phi, seed = baseline$value$seed, role = baseline$value$role,
    checkpoint = baseline$path, curvature = normalizePath(curvature_path), step = normalizePath(step_path), adjudication = adjudication)
  saveRDS(receipt, out_path)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_FINAL_COLLECT_%s task=%d output=%s\n", if (isTRUE(adjudication$accepted)) "ACCEPT" else "REJECT", task_id, out_path))
  quit(save = "no", status = 0L)
}

if (length(task_id) != 1L || is.na(task_id) || task_id < 1L || task_id > nrow(plan) || is.null(results_dir) || !nzchar(results_dir)) {
  stop("task and baseline modes require a valid --task-id and --results-dir.", call. = FALSE)
}
task <- plan[plan$task_id == task_id, , drop = FALSE]
out_path <- if (identical(mode, "baseline")) {
  new_receipt_path(results_dir, "phylo-damped-newton-baseline-", task_id)
} else new_receipt_path(results_dir, "phylo-damped-newton-attempt-", task_id)
runner <- file.path(script_dir, "phylo-damped-newton.R")
status <- system2("Rscript", c("--vanilla", runner, if (identical(mode, "baseline")) "--stage=baseline",
  paste0("--phi=", task$phi[[1L]]), paste0("--seed=", task$seed[[1L]]), paste0("--output=", out_path)))
if (!identical(as.integer(status), 0L) || !file.exists(out_path)) stop("The single-cell runner did not retain its receipt.", call. = FALSE)
receipt <- readRDS(out_path)
expected_schema <- if (identical(mode, "baseline")) "temporal_phylo_damped_newton_checkpoint_v1" else "temporal_phylo_damped_newton_v1"
if (!is.list(receipt) || !identical(receipt$schema, expected_schema) || identical(as.numeric(receipt$phi), numeric()) ||
    !identical(as.numeric(receipt$phi), as.numeric(task$phi[[1L]])) || !identical(as.integer(receipt$seed), as.integer(task$seed[[1L]])) ||
    !identical(as.character(receipt$role), as.character(task$role[[1L]]))) stop("The retained receipt does not match its assigned task.", call. = FALSE)
cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_%s_PASS task=%d role=%s phi=%s seed=%d output=%s\n",
  if (identical(mode, "baseline")) "BASELINE" else "TASK", task_id, task$role[[1L]], task$phi[[1L]], task$seed[[1L]], out_path))
