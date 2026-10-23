args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L || !args[[3L]] %in% c("smoke", "experiment")) {
  stop("usage: command-index.R PLAN_RDS OUTPUT_TSV smoke|experiment")
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                     value = TRUE)[[1L]])
source(file.path(dirname(normalizePath(script)), "contract.R"), local = TRUE)
plan <- readRDS(args[[1L]])
if (identical(args[[3L]], "experiment")) isdm_diag_validate_plan(plan) else
  isdm_diag_validate_smoke_plan(plan)
required <- c("task_id", "slice", "native_task_id", "variant")
if (!is.data.frame(plan) || !all(required %in% names(plan))) {
  stop("plan lacks command-index columns")
}
nonsp <- data.frame(mode = "nonspatial", key = plan$task_id[plan$slice == "nonspatial"])
spatial <- data.frame(mode = "spatial-group",
                      key = unique(plan$native_task_id[plan$slice == "spatial"]))
commands <- rbind(nonsp, spatial)
if (anyNA(commands$key) || anyDuplicated(paste(commands$mode, commands$key))) {
  stop("command index contains missing or duplicate group identities")
}
expected_n <- if (identical(args[[3L]], "smoke")) 2L else 28L
if (nrow(commands) != expected_n) {
  stop("command index count differs from the frozen launch mode")
}
utils::write.table(commands, args[[2L]], sep = "\t", quote = FALSE,
                   row.names = FALSE, col.names = FALSE)
cat("DIAGNOSTIC_COMMAND_INDEX_WRITTEN\n")
