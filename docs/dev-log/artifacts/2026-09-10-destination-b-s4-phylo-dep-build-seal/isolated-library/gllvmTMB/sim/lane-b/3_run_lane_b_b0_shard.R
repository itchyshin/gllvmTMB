#!/usr/bin/env Rscript

args0 <- commandArgs(trailingOnly = FALSE)
self <- sub("^--file=", "", args0[grepl("^--file=", args0)])[[1L]]
source(file.path(dirname(normalizePath(self)), "lane-b-b2-runner.R"))

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag) {
  where <- match(flag, args)
  if (is.na(where) || where == length(args)) stop("Missing ", flag)
  args[[where + 1L]]
}

root <- lane_b_validate_campaign_root(value_after("--root"))
shard_id <- value_after("--shard-id")
paths <- lane_b_campaign_paths(root)
frozen <- readRDS(file.path(paths[["frozen"]], "lane-b-b2-frozen.rds"))
if (!identical(frozen$manifest_version, lane_b_manifest_version())) {
  stop("The B0 supplement manifest version does not match the fit campaign.")
}
queue_row <- frozen$queue[frozen$queue$shard_id == shard_id, , drop = FALSE]
if (nrow(queue_row) != 1L) stop("Unknown shard ID: ", shard_id)
if (!identical(queue_row$table[[1L]], "ordinary"))
  stop("The exact B0 supplement accepts ordinary shards only.")

out_dir <- file.path(root, "b0-exact-v3")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, paste0(shard_id, ".rds"))
if (file.exists(out_path)) quit(save = "no", status = 0L)

cell <- frozen$ordinary_manifest[
  frozen$ordinary_manifest$cell_id == queue_row$cell_id[[1L]],
  , drop = FALSE
]
rows <- lane_b_b0_registry_rows(
  cell,
  seq.int(queue_row$replicate_first[[1L]], queue_row$replicate_last[[1L]])
)
lane_b_atomic_save_rds(rows, out_path)
