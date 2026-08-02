## Design 108 recovery pilot -- JOB 3: find where va_tips_only stops being
## locally affordable.
##
## va_tips_only's inner solve is O(N^2) (dense tip-correlation precision);
## va_augmented's is flat in N (sparse augmented precision, ~3 nz/row --
## Design 108 Stage 7 test "tips-only is admitted too -- and it is the route
## that densifies"). Per the maintainer's LOCKED decision (PROTOCOL.md,
## "DECISIONS LOCKED"), Arm 4 runs across Part A ONLY and the crossover at
## envelope scale is reported as a LABELLED EXTRAPOLATION from this ladder
## plus Stage 7's own sparsity numbers -- this script does not push N to the
## envelope (5,000-10,000) itself.
##
## One seed per N (this is a cost/affordability trend, not an accuracy
## estimate -- accuracy is Job 2's job, on the SAME tier-2 rel_frob metric,
## reported there with proper seed replication). Stops escalating N the
## first time a fit exceeds LOCAL_BUDGET_S wall-clock, per "if a cell is too
## slow locally, say so and stop rather than escalating to the cluster."
##
## Results are LOCAL only (D-50): writes an .rds under
## dev/design108-recovery/pilot-results/, never committed.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

OUTDIR <- "dev/design108-recovery/pilot-results"
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

T0 <- 20L; q0 <- 1L; n_trials0 <- 6L
Ns <- c(100L, 250L, 500L, 1000L, 1500L)
LOCAL_BUDGET_S <- 180   # stop escalating N once one fit exceeds this
seed0 <- 1L

source_path <- .d108_va_source()

rows <- list()
stopped_at <- NA_integer_
for (i in seq_along(Ns)) {
  N <- Ns[i]
  cat(sprintf("--- tips_only N=%d (%d/%d) ---\n", N, i, length(Ns)))
  sim <- simulate_two_tier(N = N, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                           n_trials = n_trials0)
  va <- tryCatch(
    .d108_fit_va(sim, q0, route = "tips_only", source = source_path,
                n_starts = 1L, H = 15L, time_budget_s = LOCAL_BUDGET_S + 30),
    error = function(e) list(status = "ERROR", note = conditionMessage(e),
                             elapsed_s = NA_real_, peak_rss_mb = NA_real_,
                             elbo = NA_real_, admitted = NA, Sigma1 = NULL, Sigma2 = NULL))
  rf1 <- if (!is.null(va$Sigma1)) rel_frob(va$Sigma1, sim$truth$tier1$Sigma_B) else NA_real_
  rf2 <- if (!is.null(va$Sigma2)) rel_frob(va$Sigma2, sim$truth$tier2$Sigma_B) else NA_real_
  row <- data.frame(N = N, T = T0, q = q0, seed = seed0, status = va$status,
                    elapsed_s = va$elapsed_s, peak_rss_mb = va$peak_rss_mb,
                    rel_frob_tier1 = rf1, rel_frob_tier2 = rf2, note = va$note,
                    stringsAsFactors = FALSE)
  rows[[i]] <- row
  cat(sprintf("  status=%s elapsed_s=%.1f rf1=%.4f rf2=%.4f\n",
             va$status, va$elapsed_s %||% NA_real_, rf1, rf2))
  saveRDS(do.call(rbind, rows), file.path(OUTDIR, "job3_tips_only_wall.rds"))

  if (i == 1L) {
    stopifnot(!is.na(va$elapsed_s))  # SMOKE-FIRST: first cell must produce a real timing
  }
  if (!is.na(va$elapsed_s) && va$elapsed_s > LOCAL_BUDGET_S) {
    stopped_at <- N
    cat(sprintf("\nSTOPPING: N=%d exceeded the %ds local budget (%.1fs). Not escalating further.\n",
               N, LOCAL_BUDGET_S, va$elapsed_s))
    break
  }
}

job3 <- do.call(rbind, rows)
write.csv(job3, file.path(OUTDIR, "job3_tips_only_wall.csv"), row.names = FALSE)
cat("\n=== tips_only wall-clock trend ===\n")
print(job3[, c("N", "status", "elapsed_s", "peak_rss_mb", "rel_frob_tier1", "rel_frob_tier2")])
saveRDS(list(job3 = job3, stopped_at = stopped_at, local_budget_s = LOCAL_BUDGET_S),
       file.path(OUTDIR, "job3_full.rds"))
