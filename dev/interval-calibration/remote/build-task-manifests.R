#!/usr/bin/env Rscript
## Build the exact approved task TSVs. This script performs no fit or simulation.

if (!exists("interval_stop", mode = "function")) {
  source("dev/interval-calibration/remote/shard-io.R")
}

interval_task_grid <- function(packet) {
  switch(
    packet,
    PVT02 = expand.grid(cell_id = 1L, rep = 50001:55000),
    CI09 = expand.grid(cell_id = 1:6, rep = 1:5000),
    CI13 = expand.grid(cell_id = 1:4, rep = 1:5000),
    CI14 = expand.grid(cell_id = 1:2, rep = 1:5000),
    CI15 = expand.grid(cell_id = 1:4, rep = 1:5000),
    CI10_COST = expand.grid(cell_id = 1:18, rep = 3L),
    interval_stop("unknown task-manifest packet: ", packet)
  )
}

interval_task_source <- function(packet) {
  interval_approved_source(packet)
}

interval_build_task_manifest <- function(packet) {
  grid <- interval_task_grid(packet)
  grid$packet <- packet
  grid$scientific_source_sha <- interval_task_source(packet)
  grid$attempt_version <- 1L
  grid$seed <- switch(
    packet,
    PVT02 = 800000000L + grid$rep,
    CI09 = 90000000L + grid$cell_id * 10000L + grid$rep,
    CI13 = 130000000L + grid$cell_id * 10000L + grid$rep,
    CI14 = 140000000L + grid$cell_id * 10000L + grid$rep,
    CI15 = 150000000L + grid$cell_id * 10000L + grid$rep,
    CI10_COST = (20260718L %% 100000L) +
      1000003L * (grid$cell_id %% 997L) + grid$rep
  )
  grid <- grid[, c(
    "packet",
    "cell_id",
    "rep",
    "scientific_source_sha",
    "attempt_version",
    "seed"
  )]
  rownames(grid) <- NULL
  grid
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) {
    interval_stop("usage: build-task-manifests.R OUTPUT_DIRECTORY")
  }
  out_dir <- args[[1L]]
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  for (packet in c("PVT02", "CI09", "CI13", "CI14", "CI15", "CI10_COST")) {
    out <- file.path(out_dir, paste0(tolower(packet), "-tasks.tsv"))
    if (file.exists(out)) interval_stop("refusing to overwrite task manifest: ", out)
    write.table(
      interval_build_task_manifest(packet),
      out,
      sep = "\t",
      row.names = FALSE,
      quote = FALSE
    )
  }
}
