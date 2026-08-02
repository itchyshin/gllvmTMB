## Design 108 recovery pilot -- JOB 1: calibrate the N-ladder floor.
##
## Sweeps the gaussian_control arm (Laplace engine, identity link) across
## N in {100, 250, 500, 1000} at T=20, q=1 (Design108-recovery/PROTOCOL.md's
## Part A floor trait count), 3 seeds each, and records rel_frob/pdHess/
## convergence. The smallest N at which the control clears the gate
## (rel_frob <= 0.5 both tiers, pdHess TRUE, convergence 0, at EVERY seed) is
## the recommended N-ladder floor -- per non-negotiable 3, no other rate at a
## smaller N is interpretable, so the floor is read off this measurement, not
## assumed.
##
## Results are LOCAL only (D-50): this script writes an .rds under
## dev/design108-recovery/pilot-results/, never committed.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

OUTDIR <- "dev/design108-recovery/pilot-results"
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

T0 <- 20L; q0 <- 1L; n_trials0 <- 6L; gauss_sd0 <- 0.4
Ns <- c(100L, 250L, 500L, 1000L)
seeds <- 1:3

rows <- list()
i <- 0L
for (N in Ns) {
  for (seed in seeds) {
    i <- i + 1L
    t0 <- proc.time()[["elapsed"]]
    sim <- simulate_two_tier(N = N, T = T0, q = q0, seed = seed, phylo_scale = 1,
                             n_trials = n_trials0)
    gcf <- .d108_fit_gaussian_control(sim, q0, gauss_sd = gauss_sd0,
                                      obs_seed = seed + 900000L)
    rf1 <- if (!is.null(gcf$Sigma1)) rel_frob(gcf$Sigma1, sim$truth$tier1$Sigma_B) else NA_real_
    rf2 <- if (!is.null(gcf$Sigma2)) rel_frob(gcf$Sigma2, sim$truth$tier2$Sigma_B) else NA_real_
    row <- data.frame(N = N, T = T0, q = q0, seed = seed, status = gcf$status,
                      convergence = gcf$convergence, pdHess = gcf$pdHess,
                      rel_frob_tier1 = rf1, rel_frob_tier2 = rf2,
                      elapsed_s = gcf$elapsed_s, total_s = proc.time()[["elapsed"]] - t0,
                      stringsAsFactors = FALSE)
    rows[[i]] <- row
    cat(sprintf("[%d/%d] N=%d seed=%d status=%s conv=%s pdHess=%s rf1=%.4f rf2=%.4f (%.1fs)\n",
               i, length(Ns) * length(seeds), N, seed, gcf$status,
               gcf$convergence, gcf$pdHess, rf1, rf2, row$total_s))
    ## SMOKE-FIRST: abort the instant the very first cell is empty/NA/broken.
    if (i == 1L) {
      stopifnot(identical(gcf$status, "OK"), is.finite(rf1), is.finite(rf2))
    }
    saveRDS(do.call(rbind, rows), file.path(OUTDIR, "job1_floor_sweep.rds"))
  }
}

job1 <- do.call(rbind, rows)
write.csv(job1, file.path(OUTDIR, "job1_floor_sweep.csv"), row.names = FALSE)

cat("\n=== per-N summary ===\n")
clean <- function(d) d$status == "OK" & !is.na(d$rel_frob_tier1) & !is.na(d$rel_frob_tier2) &
  d$rel_frob_tier1 <= 0.5 & d$rel_frob_tier2 <= 0.5 & isTRUE(d$pdHess) & identical(d$convergence, 0L)
job1$clean <- vapply(seq_len(nrow(job1)), function(i) clean(job1[i, ]), logical(1))
summ <- do.call(rbind, lapply(split(job1, job1$N), function(d) {
  data.frame(N = d$N[1], n_seeds = nrow(d), n_clean = sum(d$clean),
            mean_rf1 = mean(d$rel_frob_tier1), mean_rf2 = mean(d$rel_frob_tier2),
            max_rf1 = max(d$rel_frob_tier1), max_rf2 = max(d$rel_frob_tier2),
            all_clean = all(d$clean))
}))
print(summ)
floor_candidates <- summ$N[summ$all_clean]
floor_N <- if (length(floor_candidates)) min(floor_candidates) else NA_integer_
cat("\nFLOOR_N =", floor_N, "\n")
saveRDS(list(job1 = job1, summary = summ, floor_N = floor_N),
       file.path(OUTDIR, "job1_full.rds"))
