#!/usr/bin/env Rscript
## Targeted re-run of the L2 arm ONLY (40 fits: 4 cells x 10 seeds), after
## fixing testA_laplace()'s ridge-penalty omission (see the header comment
## added at that function in run-prerun122.R). L0 and VGH are UNCHANGED --
## L0 because ridge_tau = Inf makes the fix a no-op (verified: L0's TEST A
## was 40/40 PASS before the fix and does not need re-measurement), VGH
## because it uses a completely different testA_vgh() path untouched by this
## bug. Same seeds, same cells, same DGP (set.seed(seed) inside run_row is
## deterministic), so rel_frob/kappa/wall_time_s reproduce the original L2
## run; only testA_c_hat/testA_pass/testA_note change.

suppressMessages(library(gllvmTMB))
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")

OUT <- file.path(Sys.getenv("HOME"), "gllvm_work", "results")
PKG_DIR <- Sys.getenv("PRERUN_PKG_DIR", normalizePath("."))
TRUTH_SEED_BASE <- 12200000L

src_file <- Sys.getenv("PRERUN_RUNNER_R", "run-prerun122.R")
stopifnot(file.exists(src_file))
lines <- readLines(src_file)
start <- grep("^run_row <- function", lines)
end_marker <- grep("^## =+ 4\\. smoke-first", lines)
stopifnot(length(start) == 1, length(end_marker) == 1)
body_lines <- lines[start:(end_marker - 1)]
while (length(body_lines) && !nzchar(trimws(body_lines[length(body_lines)]))) {
  body_lines <- body_lines[-length(body_lines)]
}
eval(parse(text = body_lines), envir = .GlobalEnv)
stopifnot(exists("run_row"))
cat("run_row (with the TEST A ridge fix) extracted --", length(body_lines), "lines.\n\n")

sentinels <- data.frame(
  cell_id = 1:4,
  label   = c("cheapest", "most_expensive", "ordinal", "strong_small_n"),
  family  = c("binomial_probit", "binomial_probit", "ordinal_probit", "binomial_probit"),
  n       = c(100L, 400L, 400L, 100L),
  p       = c(12L, 27L, 12L, 27L),
  truth   = c("T-weak", "T-strong", "T-mid", "T-strong"),
  stringsAsFactors = FALSE
)
SEEDS <- 1:10

grid <- do.call(rbind, lapply(seq_len(nrow(sentinels)), function(i) {
  cell <- sentinels[i, ]
  eg <- expand.grid(cell_id = cell$cell_id, arm = "L2", seed = SEEDS, stringsAsFactors = FALSE)
  merge(eg, cell, by = "cell_id")
}))
grid_list <- lapply(split(grid, seq_len(nrow(grid))), as.list)

cat(sprintf("Re-running %d L2 fits sequentially...\n", length(grid_list)))
t0 <- Sys.time()
results <- lapply(grid_list, function(g) run_row(g, PKG_DIR, OUT, TRUTH_SEED_BASE))
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("Done in %.1fs (%.2f min)\n", wall, wall / 60))

final <- do.call(rbind, results)
write.csv(final, file.path(OUT, "va-laplace-prerun-L2-corrected.csv"), row.names = FALSE)
cat("\nstatus:\n"); print(table(final$status))
cat("\ntestA_pass:\n"); print(table(final$testA_pass, useNA = "ifany"))
cat("\ntestA_c_hat summary:\n"); print(summary(final$testA_c_hat))
