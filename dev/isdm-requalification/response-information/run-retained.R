## One immutable retained identity in one fresh R worker.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) stop("usage: Rscript run-retained.R <scientific-plan.rds> <task-id> <output-dir> <runtime-identity.rds>", call. = FALSE)
plan_path <- args[[1L]]; task_id <- as.integer(args[[2L]]); output_dir <- args[[3L]]; runtime_path <- args[[4L]]
file_arg <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())])
if (length(file_arg) != 1L || !nzchar(file_arg)) stop("cannot locate retained-run script", call. = FALSE)
script_dir <- dirname(normalizePath(file_arg, mustWork = TRUE))
source(file.path(script_dir, "contract.R"), local = TRUE); source(file.path(script_dir, "runner.R"), local = TRUE)
plan <- readRDS(plan_path); isdm_respinfo_validate_plan(plan)
task <- plan[plan$task_id == task_id, , drop = FALSE]
if (nrow(task) != 1L) stop("retained identity not found", call. = FALSE)
qualification <- readRDS(runtime_path)
if (!identical(qualification$schema, "isdm-response-information-runtime-identity-v1")) stop("runtime identity is malformed", call. = FALSE)
isdm_respinfo_run_one(task, output_dir, qualification)
cat("response information retained task completed\n")
