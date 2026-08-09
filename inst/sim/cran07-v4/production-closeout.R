#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) stop("Usage: production-closeout.R CORE.rds SILENT.rds ROBUST.rds PILOT.rds CLOSEOUT.rds",
                             call. = FALSE)
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_arg <- gsub("~+~", " ", script_arg, fixed = TRUE)
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
core_dir <- file.path(script_dir, "../cran07-core"); v3_dir <- file.path(script_dir, "../cran07-v3")
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
for (f in c(file.path(core_dir, c("schema.R", "campaign.R", "batch.R")),
            file.path(v3_dir, c("campaign-v3.R", "gates-v3.R")),
            file.path(script_dir, c("campaign-v4.R", "schema-v4.R", "gates-v4.R",
                                    "summary-v4.R")))) source(f, local = .GlobalEnv)
summaries_raw <- lapply(args[1:3], readRDS)
ids <- vapply(summaries_raw, function(x) x$v4_identity$campaign_id, character(1L))
if (!setequal(ids, CRAN07_V4_CAMPAIGNS$campaign_id) || anyDuplicated(ids)) {
  stop("Production summaries are not the three distinct v4 campaigns.", call. = FALSE)
}
summaries <- stats::setNames(summaries_raw, ids)
registries <- stats::setNames(lapply(CRAN07_V4_CAMPAIGNS$campaign_id, function(id)
  cran07_v4_read_campaign_registry(id, repo)), CRAN07_V4_CAMPAIGNS$campaign_id)
closeout <- cran07_v4_production_closeout(summaries, readRDS(args[[4L]]), registries)
saveRDS(closeout, args[[5L]], version = 3)
print(closeout$campaign_gate); print(closeout$detector_global)
print(closeout$family_pair_gate)
cat("release_verdict=", closeout$release_verdict, "\n", sep = "")
if (!identical(closeout$release_verdict, "PASS")) stop("V4 closeout is HOLD.",
                                                       call. = FALSE)
