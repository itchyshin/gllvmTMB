## One immutable phylogenetic temporal-recovery task for a DRAC Slurm array.
## Each task writes exactly one CSV, so concurrent jobs never share a file.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name) {
  hit <- grep(paste0("^", name, "="), args, value = TRUE)
  if (length(hit) != 1L) return(NULL)
  sub(paste0("^", name, "="), "", hit)
}
mode <- arg_value("--mode")
if (is.null(mode)) mode <- "task"

root <- normalizePath(".", mustWork = TRUE)
task_path <- file.path(root, "dev/temporal-program/results/phylo-recovery-160-tasks-20260909.csv")
base_path <- file.path(root, "dev/temporal-program/results/phylo-recovery-160-20260909.csv")
if (!file.exists(task_path) || !file.exists(base_path)) {
  stop("The frozen phylogenetic task manifest or retained base receipt is missing.", call. = FALSE)
}
tasks <- utils::read.csv(task_path, check.names = FALSE)
base <- utils::read.csv(base_path, check.names = FALSE)
full <- expand.grid(phi = c(-.4, 0, .6), seed = 2609181:2609190)
full <- full[order(full$phi, full$seed), , drop = FALSE]
expected <- full[!paste(full$phi, full$seed) %in% paste(base$phi, base$seed), , drop = FALSE]
expected$task_id <- seq_len(nrow(expected))
expected <- expected[c("task_id", "phi", "seed")]
rownames(expected) <- NULL
if (!identical(tasks, expected)) {
  stop("The DRAC task manifest differs from the exact retained recovery remainder.", call. = FALSE)
}
if (identical(mode, "plan")) {
  cat(sprintf("TEMPORAL_PHYLO_TASK_PLAN_PASS tasks=%d\n", nrow(tasks)))
  quit(save = "no", status = 0L)
}
if (!identical(mode, "task")) {
  stop("usage: Rscript --vanilla phylo-recovery-task.R --mode=plan | --mode=task --task-id=N --results-dir=PATH", call. = FALSE)
}
task_id <- suppressWarnings(as.integer(arg_value("--task-id")))
results_dir <- arg_value("--results-dir")
if (length(task_id) != 1L || is.na(task_id) || task_id < 1L || task_id > nrow(tasks) ||
    is.null(results_dir) || !nzchar(results_dir)) {
  stop("task mode requires a valid --task-id and --results-dir.", call. = FALSE)
}

dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
results_dir <- normalizePath(results_dir, mustWork = TRUE)
out_path <- file.path(results_dir, sprintf("phylo-recovery-attempt-%02d.csv", task_id))
if (file.exists(out_path)) {
  stop("Refusing to overwrite an existing DRAC task receipt: ", out_path, call. = FALSE)
}

sys.source(file.path(root, "dev/temporal-program/remote/phylo-recovery-common.R"), envir = globalenv())
task <- tasks[tasks$task_id == task_id, , drop = FALSE]
attempt <- fit_one(task$phi[[1L]], task$seed[[1L]])
if (!is.data.frame(attempt) || nrow(attempt) != 1L ||
    !identical(as.numeric(attempt$phi[[1L]]), as.numeric(task$phi[[1L]])) ||
    !identical(as.integer(attempt$seed[[1L]]), as.integer(task$seed[[1L]]))) {
  stop("The task result is not a one-row receipt for its assigned phi--seed cell.", call. = FALSE)
}
tmp_path <- tempfile("phylo-recovery-attempt-", tmpdir = results_dir, fileext = ".csv")
utils::write.csv(attempt, tmp_path, row.names = FALSE)
if (!file.rename(tmp_path, out_path)) stop("Could not atomically retain task output.", call. = FALSE)
cat(sprintf("TEMPORAL_PHYLO_TASK_PASS task=%d phi=%s seed=%d output=%s\n",
  task_id, task$phi[[1L]], task$seed[[1L]], out_path))
