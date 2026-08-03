## Noether diagnostic 4: CAUSAL test of the psi-structure hypothesis.
## Rebuild the tier-2 psi component as a PHYLO-STRUCTURED per-trait field
## (which is what src/gllvmTMB.cpp:1204 `g_phy_diag.col(t) ~ N(0, A)` models),
## instead of dgp.R:133's iid-across-species Z2. If the mechanism is right,
## `sd_phy_diag` should stop collapsing and rel_frob should drop sharply.
## Read-only; writes only under dev/.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0 <- as.integer(Sys.getenv("D108_N", "250"))
seed0 <- as.integer(Sys.getenv("D108_SEED", "1"))
T0 <- 20L; q0 <- 1L; gauss_sd0 <- 0.4

sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                         n_trials = 6L)
tr <- sim$truth
L1 <- tr$tier1$Lambda; p1 <- tr$tier1$psi
L2 <- tr$tier2$Lambda; p2 <- tr$tier2$psi
tip_row <- sim$node_of_species + 1L

run_one <- function(phylo_psi) {
  ## rebuild eta from the SAME beta0/U1/B1/U2/Lambdas, only swapping the
  ## tier-2 psi component's cross-species structure.
  set.seed(seed0 + 5150L)
  if (phylo_psi) {
    G <- .d108_simulate_gmrf(sim$Ainv, T0)[tip_row, , drop = FALSE]   # N x T, cols ~ N(0, A)
    B2 <- sweep(G, 2, sqrt(p2), `*`)
  } else {
    B2 <- sweep(matrix(stats::rnorm(N0 * T0), N0, T0), 2, sqrt(p2), `*`)  # dgp.R:133 shape
  }
  F1 <- tr$tier1$U %*% t(L1) + tr$tier1$B
  F2 <- tr$tier2$U %*% t(L2) + B2
  eta <- matrix(tr$beta0, N0, T0, byrow = TRUE) + F1 + F2
  dat <- sim$data
  ## `sim$data` is row-sorted (dgp.R:158) while `eta` is an N x T matrix, so
  ## index it by (unit, trait) rather than by as.vector() column order.
  dat$y <- eta[cbind(dat$unit, dat$trait)] + stats::rnorm(nrow(dat), 0, gauss_sd0)
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
  psi_phy_hat <- diag(Tot2) - diag(Sh2)
  psi_row_hat <- diag(Tot1) - diag(Sh1)
  cat(sprintf("phylo_psi=%-5s  rf1_asis=%.4f rf2_asis=%.4f | rf1_shared=%.4f rf2_shared=%.4f\n",
              phylo_psi, rel_frob(Tot1, L1 %*% t(L1) + diag(p1)),
              rel_frob(Tot2, L2 %*% t(L2) + diag(p2)),
              rel_frob(Sh1, L1 %*% t(L1)), rel_frob(Sh2, L2 %*% t(L2))))
  cat(sprintf("   psi_phy_hat mean=%.4f (true psi2 mean=%.4f, cor=%.3f)\n",
              mean(psi_phy_hat), mean(p2),
              suppressWarnings(stats::cor(psi_phy_hat, p2))))
  cat(sprintf("   psi_row_hat mean=%.4f (true psi1=%.4f; psi1+psi2+gsd2=%.4f)\n",
              mean(psi_row_hat), mean(p1), mean(p1 + p2) + gauss_sd0^2))
  invisible(NULL)
}
cat(sprintf("\n### N=%d seed=%d, T=%d, q=%d\n", N0, seed0, T0, q0))
cat("--- A: tier-2 psi IID across species (what dgp.R:133 actually does) ---\n")
run_one(FALSE)
cat("--- B: tier-2 psi PHYLO-STRUCTURED (what the fitted model assumes) ---\n")
run_one(TRUE)
cat("\nDONE\n")
