## Noether diagnostic 3: does the CORRECTED estimand (shared part, Lambda Lambda')
## shrink with N, once the psi accounting mismatch is removed? Read-only.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

Ns <- as.integer(strsplit(Sys.getenv("D108_NS", "250"), ",")[[1]])
seeds <- as.integer(strsplit(Sys.getenv("D108_SEEDS", "1"), ",")[[1]])
T0 <- 20L; q0 <- 1L; n_trials0 <- 6L; gauss_sd0 <- 0.4

out <- list(); k <- 0L
for (N0 in Ns) for (seed0 in seeds) {
  sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                           n_trials = n_trials0)
  dat <- sim$data
  set.seed(seed0 + 900000L)
  dat$y <- dat$eta_true + stats::rnorm(nrow(dat), 0, gauss_sd0)
  dat$trait <- factor(dat$trait)
  dat$species <- factor(dat$species, levels = sim$tree$tip.label)
  tree <- sim$tree
  fml <- .d108_two_tier_formula(q0, environment())
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    fml, data = dat, unit = "species", trait = "trait", family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol())))
  g <- function(lv, pt) as.matrix(gllvmTMB::extract_Sigma(fit, level = lv, part = pt,
                                                          link_residual = "none")$Sigma)
  Tot1 <- g("unit", "total"); Sh1 <- g("unit", "shared")
  Tot2 <- g("phy", "total");  Sh2 <- g("phy", "shared")
  L1t <- sim$truth$tier1$Lambda; L2t <- sim$truth$tier2$Lambda
  p1t <- sim$truth$tier1$psi;    p2t <- sim$truth$tier2$psi
  psi_hat <- diag(Tot1) - diag(Sh1)
  k <- k + 1L
  out[[k]] <- data.frame(
    N = N0, seed = seed0,
    conv = tryCatch(as.integer(fit$opt$convergence), error = function(e) NA_integer_),
    ## AS-MEASURED (the campaign's current metric)
    rf1_asis = rel_frob(Tot1, sim$truth$tier1$Sigma_B),
    rf2_asis = rel_frob(Tot2, sim$truth$tier2$Sigma_B),
    ## CORRECTED estimand: shared part vs true Lambda Lambda'
    rf1_shared = rel_frob(Sh1, L1t %*% t(L1t)),
    rf2_shared = rel_frob(Sh2, L2t %*% t(L2t)),
    ## phy total == phy shared? (proof the phylo psi is absent from the fit side)
    phy_total_eq_shared = max(abs(Tot2 - Sh2)),
    ## the single row-level psi vs the SUM of everything iid in the DGP
    psi_hat_mean = mean(psi_hat),
    psi_sum_true_mean = mean(p1t + p2t) + gauss_sd0^2,
    rf_psi_vs_sum = sqrt(sum((psi_hat - (p1t + p2t + gauss_sd0^2))^2)) /
      sqrt(sum((p1t + p2t + gauss_sd0^2)^2)),
    ## off-diagonal-only errors (psi cannot touch these)
    rf1_off = sqrt(sum((Tot1 - sim$truth$tier1$Sigma_B)[upper.tri(Tot1)]^2)) /
      sqrt(sum(sim$truth$tier1$Sigma_B[upper.tri(Tot1)]^2)),
    rf2_off = sqrt(sum((Tot2 - sim$truth$tier2$Sigma_B)[upper.tri(Tot2)]^2)) /
      sqrt(sum(sim$truth$tier2$Sigma_B[upper.tri(Tot2)]^2)),
    stringsAsFactors = FALSE)
  cat(sprintf("N=%4d s=%d conv=%s | asis %.3f/%.3f | shared %.3f/%.3f | off %.3f/%.3f | psi_hat=%.3f vs sum=%.3f (rf=%.3f) | phyT-phyS=%.2e\n",
              N0, seed0, out[[k]]$conv, out[[k]]$rf1_asis, out[[k]]$rf2_asis,
              out[[k]]$rf1_shared, out[[k]]$rf2_shared, out[[k]]$rf1_off, out[[k]]$rf2_off,
              out[[k]]$psi_hat_mean, out[[k]]$psi_sum_true_mean, out[[k]]$rf_psi_vs_sum,
              out[[k]]$phy_total_eq_shared))
  flush(stdout())
}
res <- do.call(rbind, out)
saveRDS(res, sprintf("dev/design108-recovery/pilot-results/noether-diag3-%s.rds",
                     Sys.getenv("D108_TAG", "x")))
cat("\nDONE\n")
