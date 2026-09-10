#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) stop("Usage: pilot-global-gate.R CORE.rds SILENT.rds ROBUST.rds GATE.rds",
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
summaries <- lapply(args[1:3], readRDS)
ids <- vapply(summaries, function(x) x$v4_identity$campaign_id, character(1L))
if (!setequal(ids, CRAN07_V4_CAMPAIGNS$campaign_id) || anyDuplicated(ids) ||
    any(!vapply(summaries, function(x) identical(x$v4_identity$stage, "pilot") &&
      isTRUE(x$v4_identity$complete) &&
      identical(x$v4_identity$expected_attempts, x$v4_identity$observed_attempts),
      logical(1L)))) stop("Inputs are not three complete distinct v4 pilots.", call. = FALSE)
registries <- stats::setNames(lapply(CRAN07_V4_CAMPAIGNS$campaign_id, function(id)
  cran07_v4_read_campaign_registry(id, repo)), CRAN07_V4_CAMPAIGNS$campaign_id)
expected <- cran07_v4_expected_campaign_cells(registries)
recomputed <- stats::setNames(lapply(seq_along(summaries), function(i) {
  id <- summaries[[i]]$v4_identity$campaign_id
  cran07_v4_validate_pilot_summary(summaries[[i]], registries[[id]], id)
}), ids)
attempts <- do.call(rbind, lapply(summaries, `[[`, "attempts"))
admission <- do.call(rbind, lapply(seq_along(summaries), function(i) {
  z <- recomputed[[ids[[i]]]]; z$campaign_id <- ids[[i]]; z
}))
gate <- cran07_v4_pilot_verdict(attempts, expected, admission)
gate$campaign_ids <- sort(ids); gate$expected_campaign_cells <- expected
gate$cell_admission <- admission
source_hashes <- unique(vapply(summaries, function(x)
  x$v4_identity$source_archive_sha256, character(1L)))
if (length(source_hashes) != 1L || !grepl("^[0-9a-f]{64}$", source_hashes)) {
  stop("V4 pilot summaries do not share one source-archive identity.", call. = FALSE)
}
gate$source_archive_sha256 <- source_hashes
saveRDS(gate, args[[4L]], version = 3)
print(gate$detector_global)
cat("admitted_cells=", nrow(gate$admitted_cells), " held_cells=",
    nrow(gate$held_cells), "\n", sep = "")
if (!gate$production_authorized) stop("V4 pilot did not authorize production.",
                                      call. = FALSE)
