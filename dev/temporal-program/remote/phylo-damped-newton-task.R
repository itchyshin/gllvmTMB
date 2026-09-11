## One frozen temporal--phylogenetic damped-Newton qualification task.  Each
## array element invokes the already validated single-cell runner and keeps an
## independent RDS receipt; a rejected cell is retained evidence, not a task
## infrastructure failure.

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

if (identical(mode, "plan")) {
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_TASK_PLAN_PASS tasks=%d\n", nrow(plan)))
  quit(save = "no", status = 0L)
}
if (!mode %in% c("task", "baseline", "probe_plan", "probe")) {
  stop("usage: Rscript --vanilla phylo-damped-newton-task.R --mode=plan|task|baseline|probe_plan|probe", call. = FALSE)
}
task_id <- suppressWarnings(as.integer(arg_value("--task-id")))
results_dir <- arg_value("--results-dir")
if (identical(mode, "probe_plan")) {
  checkpoint_dir <- arg_value("--checkpoint-dir")
  output <- arg_value("--output")
  if (is.null(checkpoint_dir) || !dir.exists(checkpoint_dir) || is.null(output) || !nzchar(output) || file.exists(output)) {
    stop("probe_plan requires an existing --checkpoint-dir and a new --output path.", call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    checkpoint <- file.path(checkpoint_dir, sprintf("phylo-damped-newton-baseline-%02d.rds", i))
    x <- readRDS(checkpoint)
    if (!is.list(x) || !identical(x$schema, "temporal_phylo_damped_newton_checkpoint_v1") ||
        !identical(x$stage, "baseline") || !identical(as.numeric(x$phi), as.numeric(plan$phi[[i]])) ||
        !identical(as.integer(x$seed), as.integer(plan$seed[[i]]))) {
      stop(sprintf("Invalid frozen baseline checkpoint for task %d.", i), call. = FALSE)
    }
    expand.grid(cell_task_id = i, coordinate = seq_along(x$theta),
      multiplier = temporal_phylo_damped_newton_controls()$fd_multipliers,
      direction = c("plus", "minus"), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
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
  probe_plan <- arg_value("--probe-plan")
  checkpoint_dir <- arg_value("--checkpoint-dir")
  probe_task_id <- suppressWarnings(as.integer(arg_value("--probe-task-id")))
  if (is.null(probe_plan) || !file.exists(probe_plan) || is.null(checkpoint_dir) || !dir.exists(checkpoint_dir) ||
      is.na(probe_task_id) || is.null(results_dir) || !nzchar(results_dir)) {
    stop("probe requires --probe-plan, --checkpoint-dir, --probe-task-id, and --results-dir.", call. = FALSE)
  }
  probes <- utils::read.delim(probe_plan, stringsAsFactors = FALSE, check.names = FALSE)
  row <- probes[probes$probe_task_id == probe_task_id, , drop = FALSE]
  if (nrow(row) != 1L) stop("probe task id is absent or duplicated in its frozen plan.", call. = FALSE)
  dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  results_dir <- normalizePath(results_dir, mustWork = TRUE)
  out_path <- file.path(results_dir, sprintf("phylo-damped-newton-probe-%04d.rds", probe_task_id))
  if (file.exists(out_path)) stop("Refusing to overwrite an existing curvature-probe receipt.", call. = FALSE)
  cell <- plan[row$cell_task_id[[1L]], , drop = FALSE]
  checkpoint <- file.path(checkpoint_dir, sprintf("phylo-damped-newton-baseline-%02d.rds", row$cell_task_id[[1L]]))
  runner <- file.path(script_dir, "phylo-damped-newton.R")
  status <- system2("Rscript", c("--vanilla", runner, "--stage=curvature_probe",
    paste0("--phi=", cell$phi[[1L]]), paste0("--seed=", cell$seed[[1L]]),
    paste0("--checkpoint=", checkpoint), paste0("--coordinate=", row$coordinate[[1L]]),
    paste0("--multiplier=", row$multiplier[[1L]]), paste0("--direction=", row$direction[[1L]]),
    paste0("--output=", out_path)))
  if (!identical(as.integer(status), 0L) || !file.exists(out_path)) stop("The curvature-probe runner did not retain its receipt.", call. = FALSE)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_PROBE_PASS task=%d output=%s\n", probe_task_id, out_path))
  quit(save = "no", status = 0L)
}
if (length(task_id) != 1L || is.na(task_id) || task_id < 1L || task_id > nrow(plan) ||
    is.null(results_dir) || !nzchar(results_dir)) {
  stop("task and baseline modes require a valid --task-id and --results-dir.", call. = FALSE)
}
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
results_dir <- normalizePath(results_dir, mustWork = TRUE)
task <- plan[plan$task_id == task_id, , drop = FALSE]
out_path <- if (identical(mode, "baseline")) {
  file.path(results_dir, sprintf("phylo-damped-newton-baseline-%02d.rds", task_id))
} else file.path(results_dir, sprintf("phylo-damped-newton-attempt-%02d.rds", task_id))
if (file.exists(out_path)) stop("Refusing to overwrite an existing damped-Newton task receipt.", call. = FALSE)

runner <- file.path(script_dir, "phylo-damped-newton.R")
status <- system2("Rscript", c("--vanilla", runner,
  if (identical(mode, "baseline")) "--stage=baseline",
  paste0("--phi=", task$phi[[1L]]), paste0("--seed=", task$seed[[1L]]),
  paste0("--output=", out_path)))
if (!identical(as.integer(status), 0L) || !file.exists(out_path)) {
  stop("The single-cell damped-Newton runner did not retain its receipt.", call. = FALSE)
}
receipt <- readRDS(out_path)
expected_schema <- if (identical(mode, "baseline")) "temporal_phylo_damped_newton_checkpoint_v1" else "temporal_phylo_damped_newton_v1"
if (!is.list(receipt) || !identical(receipt$schema, expected_schema) ||
    !identical(as.numeric(receipt$phi), as.numeric(task$phi[[1L]])) ||
    !identical(as.integer(receipt$seed), as.integer(task$seed[[1L]])) ||
    !identical(as.character(receipt$role), as.character(task$role[[1L]]))) {
  stop("The retained damped-Newton receipt does not match its assigned task.", call. = FALSE)
}
cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_%s_PASS task=%d role=%s phi=%s seed=%d output=%s\n",
  if (identical(mode, "baseline")) "BASELINE" else "TASK",
  task_id, task$role[[1L]], task$phi[[1L]], task$seed[[1L]], out_path))
