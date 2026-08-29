args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("usage: reconcile.R PLAN_RDS OUTPUT_DIR QUALIFICATION_RDS REASON")
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
source(file.path(dirname(normalizePath(script)), "record.R"), local = TRUE)
plan <- readRDS(args[[1L]])
qualification <- readRDS(args[[3L]])
receipt <- diagnostic_reconcile(plan, args[[2L]], qualification, args[[4L]])
print(receipt[c("planned", "reconciled", "reason")])

