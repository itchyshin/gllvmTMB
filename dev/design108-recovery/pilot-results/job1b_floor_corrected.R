## Design 108 recovery pilot -- JOB 1b: the N-ladder floor, RE-MEASURED.
##
## Job 1's answer was measured on a broken instrument and is void. Four defects
## have been corrected since, every one of which ran clean and reported success:
##
##   1. the DGP drew the phylo Psi iid across species where the model wants it
##      phylogenetically structured (Psi_phy (x) A)          -- commit 132aa79b
##   2. scoring compared against the TOTAL while PROTOCOL.md's estimand is
##      loadings-only -- this is what made the "plateau" look real -- c20fb681
##   3. the VA phylo-Psi tier was byte-identical to another tier, so starting
##      values decided the psi split                          -- commit 37531e09
##   4. the positive control had no loadings extraction, so its gate would have
##      passed VACUOUSLY on a silent NA                       -- commit c20fb681
##
## Same grid as Job 1 (N in {100,250,500,1000}, T=20, 3 seeds) so the corrected
## control curve is DIRECTLY COMPARABLE to the broken one. `q` is a real column
## here rather than a fixed scalar, per non-negotiable 4/5 and the VGH lane's
## lesson that a q-fixed grid cannot support a general claim.
##
## HEADLINE is the LOADINGS estimand (PROTOCOL.md:382-383). The totals are
## recorded beside it so any future estimand drift is visible in the table
## rather than silent -- see PROTOCOL.md "DECISIONS TAKEN BY THE ORCHESTRATOR".
##
## Results are LOCAL only (D-50): writes an .rds, never committed.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

OUTDIR <- "dev/design108-recovery/pilot-results"
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

T0 <- 20L; n_trials0 <- 6L; gauss_sd0 <- 0.4
Ns    <- as.integer(strsplit(Sys.getenv("D108_N", "100,250,500,1000"), ",")[[1]])
qs    <- as.integer(strsplit(Sys.getenv("D108_Q", "1,2"), ",")[[1]])
seeds <- as.integer(strsplit(Sys.getenv("D108_SEEDS", "1,2,3"), ",")[[1]])

rows <- list(); i <- 0L
for (N in Ns) for (q0 in qs) for (seed in seeds) {
  i <- i + 1L
  t0 <- proc.time()[["elapsed"]]
  ## The tree is SPANNED, not blocked: each seed draws a new tree. The design is
  ## paired, so tree-driven variation cancels in the contrast and only inflates
  ## the absolute numbers. If d_prop's within-N spread later turns out to be
  ## comparable to its mean, tree shape is an EFFECT MODIFIER rather than a
  ## nuisance and must become an explicit axis -- that is the falsifiable risk
  ## this choice carries.
  sim <- simulate_two_tier(N = N, T = T0, q = q0, seed = seed, phylo_scale = 1,
                           n_trials = n_trials0)
  gcf <- .d108_fit_gaussian_control(sim, q0, gauss_sd = gauss_sd0,
                                    obs_seed = seed + 900000L)
  sc <- function(hat, true) if (is.null(hat)) NA_real_ else rel_frob(hat, true)
  row <- data.frame(
    N = N, T = T0, q = q0, seed = seed, status = gcf$status,
    convergence = gcf$convergence, pdHess = gcf$pdHess,
    ## HEADLINE: the protocol estimand.
    rf_load_t1  = sc(gcf$Sigma1_load, sim$truth$tier1$Sigma_B_loadings),
    rf_load_t2  = sc(gcf$Sigma2_load, sim$truth$tier2$Sigma_B_loadings),
    ## Kept beside it so drift between the two is visible, not silent.
    rf_total_t1 = sc(gcf$Sigma1,      sim$truth$tier1$Sigma_B_total),
    rf_total_t2 = sc(gcf$Sigma2,      sim$truth$tier2$Sigma_B_total),
    elapsed_s = gcf$elapsed_s, total_s = proc.time()[["elapsed"]] - t0,
    stringsAsFactors = FALSE)
  rows[[i]] <- row
  cat(sprintf("N=%5d q=%d seed=%d | %s conv=%s pdHess=%s | LOAD t1=%.4f t2=%.4f | TOT t1=%.4f t2=%.4f | %.0fs\n",
              N, q0, seed, gcf$status, gcf$convergence, gcf$pdHess,
              row$rf_load_t1, row$rf_load_t2, row$rf_total_t1, row$rf_total_t2,
              row$total_s))
  utils::flush.console()
  saveRDS(do.call(rbind, rows), file.path(OUTDIR, "job1b_floor_corrected.rds"))
}

res <- do.call(rbind, rows)
cat("\n=== corrected control curve, mean by N x q (HEADLINE = loadings) ===\n")
print(aggregate(cbind(rf_load_t1, rf_load_t2, rf_total_t1, rf_total_t2, elapsed_s) ~ N + q,
                data = res, FUN = mean))
cat("\nJOB1B_DONE\n")
