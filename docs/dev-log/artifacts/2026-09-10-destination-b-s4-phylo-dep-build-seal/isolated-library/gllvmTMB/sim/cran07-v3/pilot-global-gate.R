#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("Usage: pilot-global-gate.R CORE_SUMMARY.rds SILENT_SUMMARY.rds ROBUST_SUMMARY.rds GATE.rds",
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
`%||%` <- function(x, y) if (is.null(x)) y else x
ids <- vapply(summaries, function(x) x$v3_identity$campaign_id %||% "", character(1L))
if (!setequal(ids, CRAN07_V3_CAMPAIGNS$campaign_id) || anyDuplicated(ids) ||
    any(!vapply(summaries, function(x) identical(x$v3_identity$stage, "pilot") &&
      isTRUE(x$v3_identity$complete) &&
      identical(x$v3_identity$expected_attempts, x$v3_identity$observed_attempts),
      logical(1L)))) {
  stop("Inputs are not the three complete, distinct v3 pilot summaries.", call. = FALSE)
}
expected <- do.call(rbind, lapply(CRAN07_V3_CAMPAIGNS$campaign_id, function(id) {
  registry <- cran07_v3_read_campaign_registry(id, repo)
  data.frame(campaign_id = id, cell_id = registry$cell_id, stringsAsFactors = FALSE)
}))
attempts <- do.call(rbind, lapply(summaries, `[[`, "attempts"))
admission <- do.call(rbind, lapply(seq_along(summaries), function(i) {
  x <- summaries[[i]]$v3_gate
  x$campaign_id <- summaries[[i]]$v3_identity$campaign_id
  x
}))
gate <- cran07_v3_pilot_verdict(attempts, expected, admission)
gate$campaign_ids <- sort(ids)
gate$expected_campaign_cells <- expected
gate$cell_admission <- admission
saveRDS(gate, args[[4L]], version = 3)
print(gate$detector_global)
print(admission[, c("cell_id", "n_unusable", "n_unclassified",
                    "n_nonfinite_core", "admitted")])
cat("admitted_cells=", nrow(gate$admitted_cells),
    " held_cells=", nrow(gate$held_cells), "\n", sep = "")
if (!gate$production_authorized) {
  stop("V3 pilot has no detector-qualified nonempty production subset.",
       call. = FALSE)
}
