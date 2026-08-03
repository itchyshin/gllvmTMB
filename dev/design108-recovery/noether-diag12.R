## Noether diagnostic 12: the gaussian control's own residual (gauss_sd) and
## which truth the `_total` column should be paired with for THAT arm.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")
N0 <- 120L; T0 <- 8L; q0 <- 1L; seed0 <- 1L; gsd <- 0.4
sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1, n_trials = 6L)
dat <- sim$data
set.seed(seed0 + 900000L)
dat$y <- dat$eta_true + stats::rnorm(nrow(dat), 0, gsd)
dat$trait <- factor(dat$trait)
dat$species <- factor(dat$species, levels = sim$tree$tip.label)
tree <- sim$tree
fml <- .d108_two_tier_formula(q0, environment())
fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  fml, data = dat, unit = "species", trait = "trait", family = stats::gaussian(),
  control = gllvmTMB::gllvmTMBcontrol())))
g <- function(lv, pt) as.matrix(gllvmTMB::extract_Sigma(fit, level = lv, part = pt,
                                                        link_residual = "none")$Sigma)
rf <- function(h, t) rel_frob(h, t)
t1 <- sim$truth$tier1; t2 <- sim$truth$tier2
Tot1 <- g("unit","total"); Sh1 <- g("unit","shared")
Tot2 <- g("phy","total");  Sh2 <- g("phy","shared")
cat("=== gaussian_control, TIER 1 (unit): where does gauss_sd^2 land? ===\n")
cat(sprintf("  psi_hat mean            = %.4f\n", mean(diag(Tot1) - diag(Sh1))))
cat(sprintf("  truth psi1              = %.4f\n", mean(t1$psi)))
cat(sprintf("  truth psi1 + gauss_sd^2 = %.4f\n", mean(t1$psi) + gsd^2))
cat(sprintf("\n  rel_frob(total,  Sigma_B_total)                  = %.4f\n", rf(Tot1, t1$Sigma_B_total)))
cat(sprintf("  rel_frob(total,  Sigma_B_total + diag(gauss_sd^2))= %.4f  <- residual-aware pairing\n",
            rf(Tot1, t1$Sigma_B_total + diag(gsd^2, T0))))
cat(sprintf("  rel_frob(shared, Sigma_B_loadings)               = %.4f  <- IMMUNE to gauss_sd\n",
            rf(Sh1, t1$Sigma_B_loadings)))
cat("\n=== gaussian_control, TIER 2 (phy): gauss_sd must NOT appear here ===\n")
cat(sprintf("  rel_frob(total,  Sigma_B_total)                  = %.4f\n", rf(Tot2, t2$Sigma_B_total)))
cat(sprintf("  rel_frob(total,  Sigma_B_total + diag(gauss_sd^2))= %.4f  <- WRONG for tier 2\n",
            rf(Tot2, t2$Sigma_B_total + diag(gsd^2, T0))))
cat(sprintf("  rel_frob(shared, Sigma_B_loadings)               = %.4f\n", rf(Sh2, t2$Sigma_B_loadings)))
cat("\nDONE\n")
