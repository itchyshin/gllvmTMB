## Noether diagnostic 8 (VA double-diagonal, STEP 4): is the tier-2/tier-4
## split a LABELLING SYMMETRY of the objective?
##
## Two tests, binomial_probit (the campaign's actual VA configuration):
##
##  A. EXCHANGE TEST (exact, no optimisation). Take the fitted parameter
##     vector and swap tier 2's and tier 4's blocks wholesale -- log_sd_tier,
##     m, log_L_diag, L_off -- using the layout's own offsets. If the two tiers
##     are exchangeable in the objective, obj$fn is bit-for-bit unchanged. That
##     proves the reported split is arbitrary up to labelling: whichever tier
##     the optimiser happens to load is a coin flip, and the campaign folds
##     tier 4 (and not tier 2) into the reported tier-2 Sigma_hat.
##
##  B. MIRRORED-START TEST (empirical). Optimise twice from mirrored starts --
##     (tier2 high, tier4 low) and (tier2 low, tier4 high) -- and compare the
##     final objective and the final split.
##
## Read-only; writes only under pilot-results/.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0 <- as.integer(Sys.getenv("D108_N", "100"))
T0 <- as.integer(Sys.getenv("D108_T", "10"))
seed0 <- as.integer(Sys.getenv("D108_SEED", "1"))
q0 <- 1L; H0 <- 15L

sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                         n_trials = 6L)
dat <- sim$data
unit <- dat$unit; trait <- dat$trait
X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T0))))
phy <- .d108_va_phylo_tiers("augmented", sim$tree, sim$species_levels, unit, T0, q0)

v <- gllvmTMB:::.va_r3_validate_data(
  y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
  q = q0, family = "binomial_probit", link = "probit", unique = TRUE,
  structured = phy$structured, extra_tiers = phy$extra_tiers)
lay <- v$tier_layout

## ---- block index helpers, from the layout's own offsets (va-r3-proto.R:604-611)
blk <- function(par, role, k) {
  idx <- which(names(par) == role)
  n <- switch(role,
    log_sd_tier = if (lay$kind[k] == "diagonal") T0 else 0L,
    m           = lay$n_levels[k] * lay$dim[k],
    log_L_diag  = lay$n_levels[k] * lay$dim[k],
    L_off       = lay$n_levels[k] * lay$off_per_level[k])
  off <- switch(role,
    log_sd_tier = lay$sd_offset[k], m = lay$m_offset[k],
    log_L_diag  = lay$m_offset[k],  L_off = lay$off_offset[k])
  if (n == 0L) return(integer(0))
  idx[(off + 1L):(off + n)]
}
swap_tiers <- function(par, k1, k2) {
  out <- par
  for (role in c("log_sd_tier", "m", "log_L_diag", "L_off")) {
    i1 <- blk(par, role, k1); i2 <- blk(par, role, k2)
    stopifnot(length(i1) == length(i2))
    if (!length(i1)) next
    out[i1] <- par[i2]; out[i2] <- par[i1]
  }
  out
}
psi_of <- function(par, k) exp(par[blk(par, "log_sd_tier", k)])^2

obj <- gllvmTMB:::.va_r3_make_objective(v, H = H0, silent = TRUE)
cat("### objective built. names:", paste(names(obj), collapse = ", "), "\n")
cat(sprintf("### n par = %d  (m %d, log_L_diag %d, L_off %d, theta_rr %d, log_sd_tier %d)\n",
            length(obj$par), lay$total_mean, lay$total_mean, lay$total_off,
            lay$total_theta, lay$total_sd))
cat(sprintf("### tier off_per_level: %s   (diagonal tiers carry no L_off)\n",
            paste(lay$off_per_level, collapse = " | ")))

## ================= TEST A: exchange symmetry =================
prev <- sprintf("dev/design108-recovery/pilot-results/noether-diag7-N%d-T%d-s%d.rds", N0, T0, seed0)
par_fit <- if (file.exists(prev)) readRDS(prev)$binomial_probit$par else NULL
cat("\n======== TEST A: exchange tier 2 <-> tier 4 ========\n")
test_A <- function(par, lab) {
  f0 <- obj$fn(par)
  ps <- swap_tiers(par, 2L, 4L)
  f1 <- obj$fn(ps)
  cat(sprintf("[%s] obj(par) = %.10f\n", lab, f0))
  cat(sprintf("[%s] obj(swap) = %.10f      difference = %.3e\n", lab, f1, f1 - f0))
  cat(sprintf("[%s] psi tier2 mean %.6e -> %.6e ; tier4 mean %.6e -> %.6e\n", lab,
              mean(psi_of(par, 2L)), mean(psi_of(ps, 2L)),
              mean(psi_of(par, 4L)), mean(psi_of(ps, 4L))))
  invisible(f1 - f0)
}
set.seed(11)
par_rand <- obj$par + stats::rnorm(length(obj$par), 0, 0.25)
test_A(par_rand, "random par")
if (!is.null(par_fit)) test_A(par_fit, "FITTED par")

## ================= TEST B: mirrored starts =================
cat("\n======== TEST B: optimise from mirrored starts ========\n")
base_par <- gllvmTMB:::.va_r3_default_parameters(v, 1L)
run_from <- function(sd2_log, sd4_log, lab) {
  p <- base_par
  if (is.null(p$log_sd_tier)) p$log_sd_tier <- rep(log(0.3), lay$total_sd)
  ls <- p$log_sd_tier
  ls[(lay$sd_offset[2] + 1L):(lay$sd_offset[2] + T0)] <- sd2_log
  ls[(lay$sd_offset[4] + 1L):(lay$sd_offset[4] + T0)] <- sd4_log
  p$log_sd_tier <- ls
  o <- gllvmTMB:::.va_r3_make_objective(v, H = H0, parameters = p, silent = TRUE)
  t0 <- proc.time()[["elapsed"]]
  fit <- stats::nlminb(o$par, o$fn, o$gr,
                       control = list(eval.max = 2000L, iter.max = 2000L))
  el <- proc.time()[["elapsed"]] - t0
  pr <- fit$par; names(pr) <- names(o$par)
  ps2 <- mean(psi_of(pr, 2L)); ps4 <- mean(psi_of(pr, 4L))
  cat(sprintf("[%s] start (sd2=%.2f, sd4=%.2f) -> obj=%.6f conv=%d (%.0fs)\n",
              lab, exp(sd2_log), exp(sd4_log), fit$objective, fit$convergence, el))
  cat(sprintf("        final psi: tier2=%.6e  tier4=%.6e   SUM=%.6f   tier4 share=%.2f%%\n",
              ps2, ps4, ps2 + ps4, 100 * ps4 / (ps2 + ps4)))
  list(obj = fit$objective, psi2 = ps2, psi4 = ps4, conv = fit$convergence, par = pr)
}
b1 <- run_from(log(0.9), log(0.05), "tier2 HIGH")
b2 <- run_from(log(0.05), log(0.9), "tier4 HIGH")
cat(sprintf("\n  objective difference between the two starts: %.3e\n", b2$obj - b1$obj))
cat(sprintf("  row-level SUM: %.6f vs %.6f   (difference %.3e)\n",
            b1$psi2 + b1$psi4, b2$psi2 + b2$psi4,
            (b2$psi2 + b2$psi4) - (b1$psi2 + b1$psi4)))
cat(sprintf("  tier-4 share: %.2f%% vs %.2f%%\n",
            100 * b1$psi4 / (b1$psi2 + b1$psi4), 100 * b2$psi4 / (b2$psi2 + b2$psi4)))

saveRDS(list(b1 = b1, b2 = b2, lay = lay, N = N0, T = T0, seed = seed0),
        sprintf("dev/design108-recovery/pilot-results/noether-diag8-N%d-T%d-s%d.rds", N0, T0, seed0))
cat("\nDONE\n")
