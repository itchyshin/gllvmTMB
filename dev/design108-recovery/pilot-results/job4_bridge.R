## Design 108 recovery pilot -- BRIDGE: joint-vs-profiled agreement at the
## top of Part A (N ~ 1500), per the maintainer's LOCKED decision
## (PROTOCOL.md "DECISIONS LOCKED" #2). This is what licenses Part B's
## profiled-only design -- if the two routes disagree here, that is a
## PRIMARY finding, not a caveat, and must be reported prominently.
##
## Same simulated data, same seed, va_augmented route only (structured
## phylo tier), profile_variational = FALSE (joint) vs TRUE (profiled).
## Agreement is measured BOTH ways: rel_frob against PLANTED TRUTH for each
## route separately (the only accuracy-relevant number, per the trap), AND
## rel_frob(Sigma_joint_hat, Sigma_profiled_hat) as a route-agreement
## diagnostic, explicitly labelled "agreement, not accuracy" and never
## treated as a recovery result on its own.
##
## Ramps N (200, 500, 1000, then N_TARGET) before committing to the full
## N_TARGET run, since the joint route's memory profile is the thing being
## bridged and this is a LOCAL run -- if the ramp shows growth that would
## make N_TARGET locally unsafe, this script says so and stops rather than
## guessing.
##
## Results are LOCAL only (D-50): writes an .rds under
## dev/design108-recovery/pilot-results/, never committed.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

OUTDIR <- "dev/design108-recovery/pilot-results"
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

T0 <- 20L; q0 <- 1L; n_trials0 <- 6L; seed0 <- 1L
N_TARGET <- 1500L
ramp_Ns <- c(200L, 500L, 1000L)
LOCAL_MEM_BUDGET_MB <- 8000    # stop ramping if peak RSS trend threatens this at N_TARGET
LOCAL_TIME_BUDGET_S <- 240

source_path <- .d108_va_source()
fit_route <- function(sim, profile) {
  .d108_fit_va(sim, q0, route = "augmented", source = source_path,
              n_starts = 1L, H = 15L, profile_variational = profile)
}

ramp_rows <- list()
for (i in seq_along(ramp_Ns)) {
  N <- ramp_Ns[i]
  cat(sprintf("--- ramp N=%d (%d/%d), joint route only ---\n", N, i, length(ramp_Ns)))
  sim <- simulate_two_tier(N = N, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                           n_trials = n_trials0)
  jt <- fit_route(sim, profile = FALSE)
  row <- data.frame(N = N, elapsed_s = jt$elapsed_s, peak_rss_mb = jt$peak_rss_mb,
                    status = jt$status, stringsAsFactors = FALSE)
  ramp_rows[[i]] <- row
  cat(sprintf("  joint: status=%s elapsed_s=%.1f peak_rss_mb=%.1f\n",
             jt$status, jt$elapsed_s, jt$peak_rss_mb %||% NA_real_))
  if (i == 1L) stopifnot(!is.na(jt$elapsed_s))  # SMOKE-FIRST
  saveRDS(do.call(rbind, ramp_rows), file.path(OUTDIR, "job4_bridge_ramp.rds"))
  if (!is.na(jt$elapsed_s) && jt$elapsed_s > LOCAL_TIME_BUDGET_S) {
    cat(sprintf("STOPPING RAMP: N=%d joint route exceeded %ds locally.\n", N, LOCAL_TIME_BUDGET_S))
    break
  }
}
ramp <- do.call(rbind, ramp_rows)
cat("\n=== joint-route ramp (time/memory trend) ===\n")
print(ramp)

## Simple quadratic extrapolation of peak_rss_mb vs N (2 d.f. minimum) to
## sanity-check N_TARGET before committing to it -- informational only, the
## actual N_TARGET run below is what is reported, not this extrapolation.
safe_to_target <- TRUE
if (nrow(ramp) >= 2L && all(is.finite(ramp$peak_rss_mb))) {
  ratio <- (N_TARGET / max(ramp$N))^2
  extrap_mb <- max(ramp$peak_rss_mb) * ratio
  cat(sprintf("\nQuadratic-in-N extrapolation of peak RSS to N=%d: ~%.0f MB\n",
             N_TARGET, extrap_mb))
  if (extrap_mb > LOCAL_MEM_BUDGET_MB) safe_to_target <- FALSE
}

if (!safe_to_target) {
  cat("\nExtrapolated memory exceeds the local budget -- NOT attempting N_TARGET.\n")
  cat("Reporting the bridge at the largest ramp N instead.\n")
  N_TARGET <- max(ramp$N)
}

cat(sprintf("\n=== BRIDGE at N=%d: joint vs profiled, same data/seed ===\n", N_TARGET))
sim <- simulate_two_tier(N = N_TARGET, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                         n_trials = n_trials0)

t0 <- proc.time()[["elapsed"]]
joint <- fit_route(sim, profile = FALSE)
cat(sprintf("joint:    status=%s elapsed_s=%.1f peak_rss_mb=%.1f\n",
           joint$status, joint$elapsed_s, joint$peak_rss_mb %||% NA_real_))

profiled <- fit_route(sim, profile = TRUE)
cat(sprintf("profiled: status=%s elapsed_s=%.1f peak_rss_mb=%.1f\n",
           profiled$status, profiled$elapsed_s, profiled$peak_rss_mb %||% NA_real_))
cat(sprintf("total bridge wall-clock: %.1fs\n", proc.time()[["elapsed"]] - t0))

rf <- function(Sigma_hat, Sigma_true) {
  if (is.null(Sigma_hat)) return(NA_real_)
  rel_frob(Sigma_hat, Sigma_true)
}
joint_rf1 <- rf(joint$Sigma1, sim$truth$tier1$Sigma_B)
joint_rf2 <- rf(joint$Sigma2, sim$truth$tier2$Sigma_B)
prof_rf1  <- rf(profiled$Sigma1, sim$truth$tier1$Sigma_B)
prof_rf2  <- rf(profiled$Sigma2, sim$truth$tier2$Sigma_B)

## Route agreement (NOT accuracy -- the trap): rel_frob between the two
## routes' own Sigma_hat, labelled explicitly.
agree1 <- if (!is.null(joint$Sigma1) && !is.null(profiled$Sigma1)) {
  rel_frob(joint$Sigma1, profiled$Sigma1)
} else NA_real_
agree2 <- if (!is.null(joint$Sigma2) && !is.null(profiled$Sigma2)) {
  rel_frob(joint$Sigma2, profiled$Sigma2)
} else NA_real_

bridge <- data.frame(
  N = N_TARGET,
  route = c("joint", "profiled"),
  status = c(joint$status, profiled$status),
  elapsed_s = c(joint$elapsed_s, profiled$elapsed_s),
  peak_rss_mb = c(joint$peak_rss_mb, profiled$peak_rss_mb),
  rel_frob_tier1_vs_truth = c(joint_rf1, prof_rf1),
  rel_frob_tier2_vs_truth = c(joint_rf2, prof_rf2)
)
cat("\n=== bridge result (vs planted truth, never route-vs-route) ===\n")
print(bridge)
cat(sprintf("\nROUTE AGREEMENT (NOT ACCURACY): rel_frob(joint_hat, profiled_hat) tier1=%.4f tier2=%.4f\n",
           agree1, agree2))

write.csv(bridge, file.path(OUTDIR, "job4_bridge_result.csv"), row.names = FALSE)
saveRDS(list(ramp = ramp, bridge = bridge, agree_tier1 = agree1, agree_tier2 = agree2,
            N_TARGET = N_TARGET, safe_to_target = safe_to_target),
       file.path(OUTDIR, "job4_full.rds"))
