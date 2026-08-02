## Design 108 recovery pilot -- JOB 2: measure SD(d) at the cheapest cell
## that clears the Job-1 floor, and solve n_sim.
##
## d_i = rel_frob_tier2(va_augmented, seed i) - rel_frob_tier2(laplace, seed i)
## (tier 2 = the phylogenetic tier, the primary estimand per PROTOCOL.md).
## Both engines are fit to the SAME simulated cell per seed (paired design,
## non-negotiable 2) via run_cell(), which also gives Job 3 (tips_only) and
## the positive-control gate a free data point at this N.
##
## Results are LOCAL only (D-50): writes an .rds under
## dev/design108-recovery/pilot-results/, never committed.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

OUTDIR <- "dev/design108-recovery/pilot-results"
job1 <- readRDS(file.path(OUTDIR, "job1_full.rds"))
floor_N <- job1$floor_N
if (is.na(floor_N)) stop("Job 1 found no clean N in its sweep -- cannot pick a Job 2 cell.")
cat("Using floor_N =", floor_N, "from Job 1 as the cheapest cell that clears the gate.\n")

T0 <- 20L; q0 <- 1L; n_trials0 <- 6L; gauss_sd0 <- 0.4
seeds <- 101:110   # distinct from Job 1's seeds 1:3

rows <- list()
i <- 0L
for (seed in seeds) {
  i <- i + 1L
  cat(sprintf("--- seed %d (%d/%d) ---\n", seed, i, length(seeds)))
  t0 <- proc.time()[["elapsed"]]
  cell <- list(N = floor_N, T = T0, q = q0, seed = seed, phylo_scale = 1,
              n_trials = n_trials0)
  out <- run_cell(cell, n_starts = 1L, H = 15L, gauss_sd = gauss_sd0)
  cat(sprintf("  cell wall-clock: %.1fs\n", proc.time()[["elapsed"]] - t0))
  print(out[, c("arm", "status", "convergence", "pdHess", "rel_frob_tier1",
               "rel_frob_tier2", "elapsed_s")])
  rows[[i]] <- out
  if (i == 1L) {
    ## SMOKE-FIRST at the first seed: laplace and va_augmented must both be
    ## non-empty/non-NA before trusting the loop.
    lap0 <- out[out$arm == "laplace", ]
    va0  <- out[out$arm == "va_augmented", ]
    stopifnot(nrow(lap0) == 1L, nrow(va0) == 1L,
             is.finite(lap0$rel_frob_tier2), is.finite(va0$rel_frob_tier2))
  }
  saveRDS(do.call(rbind, rows), file.path(OUTDIR, "job2_sd_d.rds"))
}

job2 <- do.call(rbind, rows)
write.csv(job2, file.path(OUTDIR, "job2_sd_d.csv"), row.names = FALSE)

## Positive-control gate check at this N, per non-negotiable 3.
gate <- .d108_positive_control_gate(job2, rel_frob_gate = 0.5)
cat("\n=== positive control gate at N =", floor_N, "===\n")
cat("n_checked:", gate$n_checked, " n_pass:", gate$n_pass, " PASS:", gate$pass, "\n")

## Paired difference on tier 2 (phylogenic), va_augmented vs laplace.
lap <- job2[job2$arm == "laplace", c("seed", "rel_frob_tier2")]
names(lap)[2] <- "rf2_laplace"
va  <- job2[job2$arm == "va_augmented", c("seed", "rel_frob_tier2")]
names(va)[2] <- "rf2_va"
paired <- merge(lap, va, by = "seed")
paired$d <- paired$rf2_va - paired$rf2_laplace
cat("\n=== paired d = rel_frob_tier2(va_augmented) - rel_frob_tier2(laplace) ===\n")
print(paired)

d <- paired$d[is.finite(paired$d)]
sd_d <- if (length(d) >= 2L) stats::sd(d) else NA_real_
mean_d <- if (length(d)) mean(d) else NA_real_
delta <- 0.1
n_sim <- if (is.finite(sd_d)) ceiling((3 * sd_d / delta)^2) else NA_integer_
cat("\nn (finite d):", length(d), "\n")
cat("mean(d):", mean_d, "\n")
cat("SD(d):", sd_d, "\n")
cat("delta:", delta, "\n")
cat("n_sim >= (3*SD(d)/delta)^2 =", n_sim, "\n")

saveRDS(list(job2 = job2, gate = gate, paired = paired, sd_d = sd_d, mean_d = mean_d,
            delta = delta, n_sim = n_sim, floor_N = floor_N, T = T0, q = q0),
       file.path(OUTDIR, "job2_full.rds"))
