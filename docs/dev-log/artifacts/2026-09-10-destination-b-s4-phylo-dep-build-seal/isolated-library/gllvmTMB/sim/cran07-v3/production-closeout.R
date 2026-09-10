#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop("Usage: production-closeout.R CORE.rds SILENT.rds ROBUSTNESS.rds PILOT_GATE.rds CLOSEOUT.rds",
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

summaries <- lapply(args[1:3], readRDS)
pilot <- readRDS(args[[4L]])
registries <- stats::setNames(lapply(CRAN07_V3_CAMPAIGNS$campaign_id, function(id)
  cran07_v3_read_campaign_registry(id, repo)), CRAN07_V3_CAMPAIGNS$campaign_id)
closeout <- cran07_v3_production_closeout(
  summaries[[1L]], summaries[[2L]], summaries[[3L]], pilot, registries)
saveRDS(closeout, args[[5L]], version = 3)
print(closeout$campaign_gate)
if (nrow(closeout$held_pilot_cells)) print(closeout$held_pilot_cells)
print(closeout$family_pair_gate)
cat("release_verdict=", closeout$release_verdict, "\n", sep = "")
if (!identical(closeout$release_verdict, "PASS")) {
  stop("V3 production closeout is HOLD.", call. = FALSE)
}
