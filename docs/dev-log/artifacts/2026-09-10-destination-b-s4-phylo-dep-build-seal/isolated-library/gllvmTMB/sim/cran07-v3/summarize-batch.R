#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 5L) {
  stop("Usage: summarize-batch.R OUTPUT_DIR MANIFEST.csv CAMPAIGN_ID pilot|production SUMMARY.rds [ADMITTED_CELLS]",
       call. = FALSE)
}
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
core_dir <- normalizePath(file.path(script_dir, "../cran07-core"), mustWork = TRUE)
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
source(file.path(core_dir, "schema.R"), local = .GlobalEnv)
source(file.path(core_dir, "campaign.R"), local = .GlobalEnv)
source(file.path(core_dir, "batch.R"), local = .GlobalEnv)
source(file.path(script_dir, "campaign-v3.R"), local = .GlobalEnv)
source(file.path(script_dir, "gates-v3.R"), local = .GlobalEnv)

output <- args[[1L]]
manifest <- utils::read.csv(args[[2L]], stringsAsFactors = FALSE)
campaign_id <- args[[3L]]
stage <- match.arg(args[[4L]], c("pilot", "production"))
summary_path <- args[[5L]]
admitted <- if (stage == "production") {
  if (length(args) < 6L || !nzchar(args[[6L]])) {
    stop("Production summary requires the explicit admitted-cell list.", call. = FALSE)
  }
  strsplit(args[[6L]], ",", fixed = TRUE)[[1L]]
} else NULL
registry <- cran07_v3_read_campaign_registry(campaign_id, repo)
summary <- cran07_v3_summary(output, manifest, registry, campaign_id, stage, admitted)
saveRDS(summary, summary_path, version = 3)
cat("campaign=", campaign_id, " stage=", stage,
    " manifest_sha256=", summary$v3_identity$manifest_sha256,
    " complete=TRUE\n", sep = "")
print(summary$v3_gate)

