#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop("Usage: run-adjudication.R CORE.rds SILENT.rds ROBUSTNESS.rds PILOT.rds OUTPUT_DIR",
       call. = FALSE)
}
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
core_dir <- file.path(repo, "inst/sim/cran07-core")
v3_dir <- file.path(repo, "inst/sim/cran07-v3")
source(file.path(core_dir, "schema.R"), local = .GlobalEnv)
source(file.path(core_dir, "campaign.R"), local = .GlobalEnv)
source(file.path(core_dir, "batch.R"), local = .GlobalEnv)
source(file.path(v3_dir, "campaign-v3.R"), local = .GlobalEnv)
source(file.path(v3_dir, "gates-v3.R"), local = .GlobalEnv)
source(file.path(script_dir, "adjudication.R"), local = .GlobalEnv)

paths <- c(core = args[[1L]], silent = args[[2L]], robustness = args[[3L]],
           pilot = args[[4L]])
registries <- stats::setNames(lapply(CRAN07_V3_CAMPAIGNS$campaign_id, function(id)
  cran07_v3_read_campaign_registry(id, repo)), CRAN07_V3_CAMPAIGNS$campaign_id)
result <- cran07_adjudicate_production(paths, registries)
out <- normalizePath(args[[5L]], mustWork = FALSE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
saveRDS(result, file.path(out, "adjudication.rds"), version = 3)
utils::write.csv(result$closeout$campaign_gate,
                 file.path(out, "campaign-gate.csv"), row.names = FALSE)
utils::write.csv(result$closeout$family_pair_gate,
                 file.path(out, "family-pair-gate.csv"), row.names = FALSE)
utils::write.csv(result$closeout$rmse_component_gate,
                 file.path(out, "rmse-component-gate.csv"), row.names = FALSE)
utils::write.csv(result$identity_gate,
                 file.path(out, "identity-gate.csv"), row.names = FALSE)
utils::write.csv(data.frame(
  campaign_id = names(result$psi_structural_rows_normalized),
  psi_structural_rows_normalized = unname(result$psi_structural_rows_normalized)),
  file.path(out, "normalization-counts.csv"), row.names = FALSE)
writeLines(result$closeout$release_verdict,
           file.path(out, "release-verdict.txt"))
writeLines(paste(names(result$input_hashes), result$input_hashes, sep = ","),
           file.path(out, "input-hashes.csv"))
print(result$closeout$campaign_gate)
print(result$closeout$family_pair_gate)
cat("adjudication_id=", result$adjudication_id,
    " release_verdict=", result$closeout$release_verdict,
    " fits_run=0 thresholds_changed=FALSE\n", sep = "")
