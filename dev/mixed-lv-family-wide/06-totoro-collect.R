args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("usage: 06-totoro-collect.R OUTPUT_DIR CAMPAIGN_KIND")
}

output_dir <- normalizePath(args[[1L]], mustWork = TRUE)
campaign_kind <- match.arg(args[[2L]], c("pure_recovery", "calibration"))
source("dev/mixed-lv-family-wide/00-manifest.R")
source("dev/mixed-lv-family-wide/01-run.R")
source("dev/mixed-lv-family-wide/02-summarise.R")

result <- mixed_lv_collect(output_dir, campaign_kind)
saveRDS(result, file.path(output_dir, "reconciled-result.rds"))
utils::write.csv(result$ledger, file.path(output_dir, "all-attempt-ledger.csv"),
  row.names = FALSE)
utils::write.csv(result$cell_summary, file.path(output_dir, "cell-summary.csv"),
  row.names = FALSE)
utils::write.csv(result$target_summary, file.path(output_dir, "target-summary.csv"),
  row.names = FALSE)
utils::write.csv(result$gates, file.path(output_dir, "frozen-gate-verdicts.csv"),
  row.names = FALSE)

plan <- mixed_lv_task_grid(campaign_kind)
expected <- if (campaign_kind == "calibration") {
  MIXED_LV_THRESHOLDS$calibration_reps
} else MIXED_LV_THRESHOLDS$recovery_reps
stopifnot(
  nrow(result$ledger) == nrow(plan),
  all(result$ledger$campaign_kind == campaign_kind),
  all(result$cell_summary$expected_reps == expected),
  all(result$cell_summary$n_attempted == expected),
  all(result$cell_summary$exact_denominator)
)

print(result$cell_summary)
print(result$gates)
