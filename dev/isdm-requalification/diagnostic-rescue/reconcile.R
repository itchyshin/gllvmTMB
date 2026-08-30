args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("usage: reconcile.R PLAN_RDS OUTPUT_DIR QUALIFICATION_RDS REASON")
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
source(file.path(dirname(normalizePath(script)), "record.R"), local = TRUE)
plan <- readRDS(args[[1L]])
qualification <- readRDS(args[[3L]])
tryCatch({
  receipt <- diagnostic_reconcile(plan, args[[2L]], qualification, args[[4L]])
  print(receipt[c("planned", "reconciled", "reason")])
}, error = function(e) {
  failure <- list(
    schema = "isdm-diagnostic-reconciliation-failure-v1",
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    reason = args[[4L]], error_class = class(e),
    error_message = conditionMessage(e)
  )
  path <- file.path(args[[2L]], "coordinator",
                    paste0("reconciliation-failure-",
                           format(Sys.time(), "%Y%m%dT%H%M%S"), ".rds"))
  try(diagnostic_atomic_save(failure, path), silent = TRUE)
  stop(e)
})
