## Build the 72-cell x 200-rep design grid (design.md D). Writes grid.rds.
out <- Sys.getenv("AUTOD_OUT", "docs/dev-log/lanes/auto-d-recovery/sim/out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
grid <- expand.grid(
  rep = 1:200, d = 1:3, n_traits = c(8L, 16L), n_units = c(50L, 150L, 400L),
  family = c("gaussian", "poisson", "binomial", "nbinom2"),
  stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
grid <- grid[, c("family", "n_units", "n_traits", "d", "rep")]
grid$task_id <- seq_len(nrow(grid))
set.seed(20260930)
grid$seed <- sample.int(.Machine$integer.max, nrow(grid))
stopifnot(nrow(grid) == 14400L, !anyDuplicated(grid$seed))
saveRDS(grid, file.path(out, "grid.rds"))
cat("wrote", file.path(out, "grid.rds"), "with", nrow(grid), "tasks\n")
