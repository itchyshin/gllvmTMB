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
if (!identical(mode, "task")) {
  stop("usage: Rscript --vanilla phylo-damped-newton-task.R --mode=plan | --mode=task --task-id=N --results-dir=PATH", call. = FALSE)
}
task_id <- suppressWarnings(as.integer(arg_value("--task-id")))
results_dir <- arg_value("--results-dir")
if (length(task_id) != 1L || is.na(task_id) || task_id < 1L || task_id > nrow(plan) ||
    is.null(results_dir) || !nzchar(results_dir)) {
  stop("task mode requires a valid --task-id and --results-dir.", call. = FALSE)
}
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
results_dir <- normalizePath(results_dir, mustWork = TRUE)
task <- plan[plan$task_id == task_id, , drop = FALSE]
out_path <- file.path(results_dir, sprintf("phylo-damped-newton-attempt-%02d.rds", task_id))
if (file.exists(out_path)) stop("Refusing to overwrite an existing damped-Newton task receipt.", call. = FALSE)

runner <- file.path(script_dir, "phylo-damped-newton.R")
status <- system2("Rscript", c("--vanilla", runner,
  paste0("--phi=", task$phi[[1L]]), paste0("--seed=", task$seed[[1L]]),
  paste0("--output=", out_path)))
if (!identical(as.integer(status), 0L) || !file.exists(out_path)) {
  stop("The single-cell damped-Newton runner did not retain its receipt.", call. = FALSE)
}
receipt <- readRDS(out_path)
if (!is.list(receipt) || !identical(receipt$schema, "temporal_phylo_damped_newton_v1") ||
    !identical(as.numeric(receipt$phi), as.numeric(task$phi[[1L]])) ||
    !identical(as.integer(receipt$seed), as.integer(task$seed[[1L]])) ||
    !identical(as.character(receipt$role), as.character(task$role[[1L]]))) {
  stop("The retained damped-Newton receipt does not match its assigned task.", call. = FALSE)
}
cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_TASK_PASS task=%d role=%s phi=%s seed=%d output=%s\n",
  task_id, task$role[[1L]], task$phi[[1L]], task$seed[[1L]], out_path))
