#!/usr/bin/env Rscript

# Gate-2 guard.  This script deliberately cannot run until the maintainer opens
# the smoke gate; it is not invoked during Gate 0/1 implementation.
if (!identical(Sys.getenv("D91_AUTHORIZE_SMOKE"), "YES")) {
  stop("Design 91 Gate 2 is closed. Set D91_AUTHORIZE_SMOKE=YES only after explicit maintainer approval.")
}
source(file.path("dev", "design91-eva-va-envelope", "design91-producer.R"))
config <- read_d91_config()
grid <- d91_grid(config)
smoke_ids <- c("n060_t30_p25_s35_r00", "n060_t60_p50_s35_r50",
               "n240_t30_p25_s70_r00", "n240_t60_p50_s70_r50")
smoke <- grid[match(smoke_ids, grid$cell_id), , drop = FALSE]
if (anyNA(smoke$cell_index)) stop("Configured smoke cells are not in the frozen grid.")
fixture_root <- file.path("dev", "design91-eva-va-envelope", "fixtures")
result_root <- file.path("dev", "design91-eva-va-envelope", "results", "smoke")
if (!dir.exists(fixture_root) || !dir.exists(result_root)) stop("Gate-2 roots must be created before smoke.")
for (row in seq_len(nrow(smoke))) {
  fixture <- d91_make_fixture(smoke[row, ], config)
  fixture_path <- d91_write_fixture(fixture, fixture_root)
  init_seed <- as.integer(config$initialization_seed_base + smoke$cell_index[row])
  for (method in config$fit$methods) d91_run_method(fixture_path, init_seed, method, result_root, config)
}
