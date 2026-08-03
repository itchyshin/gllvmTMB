## Noether diagnostic 9 (VA double-diagonal, STEP 5): does the proposed fix
## remove the symmetry?
##
## Proposed minimal change to harness.R:231-232 -- declare the phylo Psi tier
## STRUCTURED over the augmented-node index, exactly like the phylo dense tier,
## which is the Laplace engine's Psi_phy (x) A and what R/va-r3-proto.R:356-359
## says phylo_latent(unique = TRUE) needs:
##
##   list(kind = "diagonal", dim = as.integer(T),
##        level_id = as.integer(lid_dense),   # NOT unit - 1L
##        structured = TRUE,                   # NOT FALSE
##        label = "phylo_psi")
##
## Checks: (1) it validates; (2) tier 4 no longer has tier 2's shape, so the
## exchange symmetry is gone by construction; (3) mirrored starts now agree on
## the split, not just on the objective.
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

st <- gllvmTMB:::.va_r3_phylo_structure(sim$tree, sim$species_levels)
structured <- st$structured
lid_dense <- st$node_of_species[unit]        # 0-based augmented-node ids

fixed_tiers <- list(
  list(kind = "dense", dim = as.integer(q0), level_id = as.integer(lid_dense),
       structured = TRUE, label = "phylo"),
  list(kind = "diagonal", dim = as.integer(T0), level_id = as.integer(lid_dense),
       structured = TRUE, label = "phylo_psi")          # <- THE FIX
)

v <- tryCatch(gllvmTMB:::.va_r3_validate_data(
  y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
  q = q0, family = "binomial_probit", link = "probit", unique = TRUE,
  structured = structured, extra_tiers = fixed_tiers),
  error = function(e) structure(list(msg = conditionMessage(e)), class = "verr"))
if (inherits(v, "verr")) { cat("VALIDATION FAILED:", v$msg, "\n"); quit(status = 0) }
lay <- v$tier_layout
cat("### FIXED declaration validates.\n")
cat(sprintf("  kind       : %s\n", paste(lay$kind, collapse = " | ")))
cat(sprintf("  label      : %s\n", paste(lay$label, collapse = " | ")))
cat(sprintf("  dim        : %s\n", paste(lay$dim, collapse = " | ")))
cat(sprintf("  n_levels   : %s\n", paste(lay$n_levels, collapse = " | ")))
cat(sprintf("  structured : %s\n", paste(lay$structured, collapse = " | ")))
cat(sprintf("\n  tier2 variational block = %d x %d = %d params\n",
            lay$n_levels[2], lay$dim[2], lay$n_levels[2] * lay$dim[2]))
cat(sprintf("  tier4 variational block = %d x %d = %d params\n",
            lay$n_levels[4], lay$dim[4], lay$n_levels[4] * lay$dim[4]))
cat(sprintf("  => tiers 2 and 4 exchangeable? %s (block sizes %s)\n",
            identical(lay$n_levels[2], lay$n_levels[4]) &&
              identical(lay$structured[2], lay$structured[4]),
            if (identical(lay$n_levels[2], lay$n_levels[4])) "equal" else "DIFFER"))

psi_of <- function(par, k) {
  ls <- par[names(par) == "log_sd_tier"]
  off <- lay$sd_offset[k]
  exp(ls[(off + 1L):(off + T0)])^2
}
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
  fit <- stats::nlminb(o$par, o$fn, o$gr, control = list(eval.max = 2000L, iter.max = 2000L))
  el <- proc.time()[["elapsed"]] - t0
  pr <- fit$par; names(pr) <- names(o$par)
  ps2 <- mean(psi_of(pr, 2L)); ps4 <- mean(psi_of(pr, 4L))
  cat(sprintf("[%s] start (sd2=%.2f, sd4=%.2f) -> obj=%.6f conv=%d (%.0fs)\n",
              lab, exp(sd2_log), exp(sd4_log), fit$objective, fit$convergence, el))
  cat(sprintf("        final psi: tier2=%.6e  tier4=%.6e  SUM=%.6f  tier4 share=%.2f%%\n",
              ps2, ps4, ps2 + ps4, 100 * ps4 / (ps2 + ps4)))
  list(obj = fit$objective, psi2 = ps2, psi4 = ps4)
}
cat("\n======== mirrored starts, UNDER THE FIX ========\n")
a <- run_from(log(0.9), log(0.05), "tier2 HIGH")
b <- run_from(log(0.05), log(0.9), "tier4 HIGH")
cat(sprintf("\n  objective difference : %.6f\n", b$obj - a$obj))
cat(sprintf("  tier-4 share         : %.2f%% vs %.2f%%\n",
            100 * a$psi4 / (a$psi2 + a$psi4), 100 * b$psi4 / (b$psi2 + b$psi4)))
cat(sprintf("  truth: the DGP's tier-2 Psi is IID across species (dgp.R:133), so a\n"))
cat(sprintf("         CORRECTLY-declared phylo Psi should collapse -- as the Laplace\n"))
cat(sprintf("         engine's sd_phy_diag did (1.98e-08).\n"))
saveRDS(list(a = a, b = b, lay = lay), sprintf(
  "dev/design108-recovery/pilot-results/noether-diag9-N%d-T%d-s%d.rds", N0, T0, seed0))
cat("\nDONE\n")
