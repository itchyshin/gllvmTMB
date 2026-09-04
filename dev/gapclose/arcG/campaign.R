#!/usr/bin/env Rscript
## arcG coverage campaign: one (cell_id, seed) fit per invocation.
## For Totoro array dispatch — NOT for local Cell-1 smoke.
##
## Usage: Rscript campaign.R <cell_id> <seed> <out_dir> [repo_root]
##   cell_id  : 1-9 (arcG_grid() id)
##   seed     : integer RNG seed (campaign uses 1:500)
##   out_dir  : directory for cell<id>_seed<seed>.rds
##   repo_root: optional; defaults to getwd()
##
## Scores: extract_latent_scores() only. Uncertainty: ordination_uncertainty().

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) {
  stop("Usage: Rscript campaign.R <cell_id> <seed> <out_dir> [repo_root]")
}
cell_id <- as.integer(args[[1]])
seed    <- as.integer(args[[2]])
out_dir <- args[[3]]
repo_root <- if (length(args) >= 4L) args[[4]] else getwd()

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
setwd(repo_root)

.libPaths(c(file.path(repo_root, "inst"), .libPaths()))
suppressPackageStartupMessages({
  if (!requireNamespace("gllvmTMB", quietly = TRUE) ||
      !"extract_latent_scores" %in% ls("package:gllvmTMB", all = TRUE)) {
    devtools::load_all(repo_root, quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
})

source(file.path(repo_root, "dev/gapclose/arcG/coverage-harness.R"), local = TRUE)

grid <- arcG_grid()
idx <- which(vapply(grid, function(c) c$id == cell_id, logical(1)))
if (length(idx) != 1L) stop("unknown cell_id: ", cell_id)
cell <- grid[[idx]]

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_file <- file.path(out_dir, sprintf("cell%02d_seed%04d.rds", cell_id, seed))

result <- arcG_run_one_seed(cell, seed, verbose = FALSE)
result$git_head <- substr(trimws(system("git rev-parse HEAD", intern = TRUE)), 1, 12)
saveRDS(result, out_file)
cat("WROTE", out_file, "\n")
