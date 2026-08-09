#!/usr/bin/env Rscript

args0 <- commandArgs(trailingOnly = FALSE)
self <- sub("^--file=", "", args0[grepl("^--file=", args0)])[[1L]]
sim_dir <- dirname(normalizePath(self))
source(file.path(sim_dir, "lane-b-b2-runner.R"))
source(file.path(sim_dir, "lane-b-b2-adjudication.R"))

args <- commandArgs(trailingOnly = TRUE)
where <- match("--root", args)
if (is.na(where) || where == length(args)) stop("Missing --root")
root <- lane_b_validate_campaign_root(args[[where + 1L]])
frozen <- readRDS(file.path(root, "frozen", "lane-b-b2-frozen.rds"))
files <- list.files(file.path(root, "b0-exact-v3"),
                    pattern = "\\.rds$", full.names = TRUE)
expected <- sum(frozen$queue$table == "ordinary")
receipt <- list(
  completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  expected_shards = expected,
  observed_shards = length(files),
  complete = identical(as.integer(length(files)), as.integer(expected)),
  manifest_version = frozen$manifest_version,
  detector_version = as.character(utils::packageVersion("detectseparation")),
  source_sha256 = lane_b_b0_source_receipt(),
  registry_sha256 = setNames(vapply(files, lane_b_sha256_file, character(1L)),
                             basename(files))
)
saveRDS(receipt, file.path(root, "session", "b0-exact-receipt-v3.rds"))
print(receipt[c("completed_at_utc", "expected_shards", "observed_shards",
                "complete", "manifest_version", "detector_version")])
if (!isTRUE(receipt$complete)) quit(save = "no", status = 1L)
