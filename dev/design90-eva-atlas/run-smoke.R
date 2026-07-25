#!/usr/bin/env Rscript

# Exactly four frozen Design-90 smoke attempts.  The full atlas has a distinct
# runner and is not invoked by this script.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: run-smoke.R <atlas.R> <config.json> <result-dir>")
source(args[[1L]])
cfg <- read_d90_config(args[[2L]])
grid <- make_d90_grid(cfg)
smoke_index <- c(1L, 24L, 49L, 72L)
if (length(smoke_index) != cfg$compute$smoke_cells) stop("Smoke cell count drift.")
out <- lapply(smoke_index, function(i) {
  run_d90_attempt(grid[i, , drop = FALSE],
                  fit_seed = as.integer(cfg$fit_seed_base + grid$cell_index[[i]] * 100L + 1L),
                  result_dir = args[[3L]], config = cfg)
})
if (!all(vapply(out, function(x) isTRUE(x$telemetry$healthy), logical(1)))) {
  quit(status = 2L)
}
message("D90_SMOKE_PASS")
