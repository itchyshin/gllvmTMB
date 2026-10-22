#!/usr/bin/env Rscript
## arcG full coverage grid (arcF pattern).
## Usage: Rscript run_grid.R <out_dir> <repo_root> <lib_path> <mc_cores>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4L) {
  stop("Usage: Rscript run_grid.R <out_dir> <repo_root> <lib_path> <mc_cores>")
}
out_dir <- args[[1]]
repo_root <- args[[2]]
lib_path <- args[[3]]
mc_cores <- as.integer(args[[4]])

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", NOT_CRAN = "true")
.libPaths(c(lib_path, .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))

source(file.path(repo_root, "dev/gapclose/arcG/coverage-harness.R"), local = TRUE)

grid <- arcG_grid()
seeds <- 1:500
jobs <- do.call(rbind, lapply(grid, function(cell) {
  data.frame(cell_id = cell$id, seed = seeds, stringsAsFactors = FALSE)
}))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
cat("total jobs:", nrow(jobs), " mc_cores:", mc_cores, "\n")

run_one <- function(i) {
  cell_id <- jobs$cell_id[i]
  seed <- jobs$seed[i]
  out_file <- file.path(out_dir, sprintf("cell%02d_seed%04d.rds", cell_id, seed))
  if (file.exists(out_file)) return(invisible(NULL))
  idx <- which(vapply(grid, function(c) c$id == cell_id, logical(1)))
  cell <- grid[[idx]]
  result <- tryCatch(
    arcG_run_one_seed(cell, seed, verbose = FALSE),
    error = function(e) list(status = "worker_error", error = conditionMessage(e),
                             cell_id = cell_id, seed = seed, runtime = NA_real_)
  )
  result$git_head <- NA_character_
  saveRDS(result, out_file)
  invisible(NULL)
}

t0 <- proc.time()[["elapsed"]]
parallel::mclapply(seq_len(nrow(jobs)), run_one, mc.cores = mc_cores, mc.preschedule = FALSE)
wall <- proc.time()[["elapsed"]] - t0
n_done <- length(list.files(out_dir, pattern = "\\.rds$"))
cat("DONE wall_s=", wall, " n_rds=", n_done, "\n")
