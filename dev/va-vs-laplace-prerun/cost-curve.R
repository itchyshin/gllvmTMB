#!/usr/bin/env Rscript
## Design 122 SS7 follow-up (maintainer-authorised): VGH cost-curve check
## BEFORE committing to the reduced sentinel pre-run. Times ONE VGH fit each
## at n=100 and n=400, same (p=27, T-strong) cell identity as the original
## "most_expensive" sentinel (which did not complete at n=1600 in 17.3 min --
## see RESULTS.md). Sequential, not parallel: this is a timing probe, not a
## campaign.
##
## Reuses run_row() from run-prerun122.R VERBATIM (same extraction technique
## used for local validation before the first attempt) so the fit call, the
## control object, and the DGP are byte-identical to what the reduced pre-run
## will actually run -- this is a timing measurement of the real harness, not
## a separate approximation of it.

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
cat("run_row extracted from", src_file, "--", length(body_lines), "lines.\n\n")

cell_base <- list(cell_id = 99L, label = "cost_curve", family = "binomial_probit",
                   p = 27L, truth = "T-strong")

results <- list()
for (n in c(100L, 400L)) {
  g <- c(cell_base, list(n = n, arm = "VGH", seed = 1L))
  cat(sprintf("=== COST CURVE: n=%d, p=27, T-strong, arm=VGH, seed=1 ===\n", n))
  t0 <- Sys.time()
  row <- run_row(g, PKG_DIR, OUT, TRUTH_SEED_BASE)
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("n=%d wall=%.1fs (%.2f min) status=%s converged=%s error=%s\n\n",
              n, wall, wall / 60, row$status, row$converged,
              if (nzchar(row$error)) substr(row$error, 1, 120) else "(none)"))
  row$measured_wall_s <- wall
  results[[as.character(n)]] <- row
}

final <- do.call(rbind, results)
write.csv(final, file.path(OUT, "va-laplace-cost-curve.csv"), row.names = FALSE)
saveRDS(final, file.path(OUT, "va-laplace-cost-curve.rds"))
cat("\n=== COST CURVE SUMMARY ===\n")
print(final[, c("n", "status", "converged", "measured_wall_s", "testA_c_hat", "testA_pass")])
cat(sprintf("\nn=100: %.1fs (%.2f min)\nn=400: %.1fs (%.2f min)\nn=1600 (prior attempt, killed, incomplete): >1037s (>17.3 min)\n",
            results[["100"]]$measured_wall_s, results[["100"]]$measured_wall_s / 60,
            results[["400"]]$measured_wall_s, results[["400"]]$measured_wall_s / 60))
affordable <- results[["400"]]$measured_wall_s <= 180
cat(sprintf("\nAFFORDABLE (n=400 <= 3 min): %s\n", affordable))
