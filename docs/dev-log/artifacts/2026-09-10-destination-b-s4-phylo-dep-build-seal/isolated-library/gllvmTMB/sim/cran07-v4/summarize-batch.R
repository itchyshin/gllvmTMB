#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 6L) stop(paste("Usage: summarize-batch.R OUTPUT MANIFEST",
  "CAMPAIGN smoke|pilot|production SOURCE_SHA SUMMARY [PILOT_GATE.rds]"),
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
manifest <- utils::read.csv(args[[2L]], stringsAsFactors = FALSE)
stage <- match.arg(args[[4L]], names(CRAN07_V4_STAGE_REPS))
pilot <- if (stage == "production") {
  if (length(args) < 7L || !nzchar(args[[7L]])) {
    stop("Production summary requires the matching pilot-gate RDS.",
         call. = FALSE)
  }
  readRDS(args[[7L]])
} else NULL
registry <- cran07_v4_read_campaign_registry(args[[3L]], repo)
summary <- cran07_v4_summarize(args[[1L]], manifest, registry, args[[3L]], stage,
                               args[[5L]], pilot)
saveRDS(summary, args[[6L]], version = 3)
cat("campaign=", args[[3L]], " stage=", stage, " manifest_sha256=",
    summary$v4_identity$manifest_sha256, " complete=TRUE\n", sep = "")
