## Noether diagnostic 1: element-wise Sigma_hat vs Sigma_true for the
## gaussian_control arm at ONE cell. Read-only investigation.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0 <- as.integer(Sys.getenv("D108_N", "250"))
seed0 <- as.integer(Sys.getenv("D108_SEED", "1"))
T0 <- 20L; q0 <- 1L; n_trials0 <- 6L; gauss_sd0 <- 0.4

sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                         n_trials = n_trials0)
gcf <- .d108_fit_gaussian_control(sim, q0, gauss_sd = gauss_sd0,
                                  obs_seed = seed0 + 900000L)

S1h <- as.matrix(gcf$Sigma1); S2h <- as.matrix(gcf$Sigma2)
S1t <- sim$truth$tier1$Sigma_B; S2t <- sim$truth$tier2$Sigma_B

cat(sprintf("N=%d seed=%d status=%s conv=%s pdHess=%s\n", N0, seed0, gcf$status,
            gcf$convergence, gcf$pdHess))
cat(sprintf("rel_frob tier1=%.4f tier2=%.4f\n", rel_frob(S1h, S1t), rel_frob(S2h, S2t)))

off <- function(M) M[upper.tri(M)]
rep1 <- function(lab, h, t) {
  cat("\n---- ", lab, " ----\n", sep = "")
  cat(sprintf("  diag  true: mean=%.4f  range=[%.4f, %.4f]\n", mean(diag(t)), min(diag(t)), max(diag(t))))
  cat(sprintf("  diag  hat : mean=%.4f  range=[%.4f, %.4f]\n", mean(diag(h)), min(diag(h)), max(diag(h))))
  cat(sprintf("  diag  hat-true: mean=%+.4f sd=%.4f  cor=%.4f\n",
              mean(diag(h) - diag(t)), sd(diag(h) - diag(t)), cor(diag(h), diag(t))))
  cat(sprintf("  offd  true: mean=%+.4f sd=%.4f\n", mean(off(t)), sd(off(t))))
  cat(sprintf("  offd  hat : mean=%+.4f sd=%.4f\n", mean(off(h)), sd(off(h))))
  cat(sprintf("  offd  cor(hat,true)=%.4f  slope(hat~true)=%.4f\n",
              cor(off(h), off(t)), coef(lm(off(h) ~ off(t)))[2]))
  ## global scale factor solving min ||c*T - H||_F
  cc <- sum(h * t) / sum(t * t)
  cat(sprintf("  best scalar c (hat ~ c*true): c=%.4f  resid rel_frob=%.4f\n",
              cc, rel_frob(h, cc * t)))
  ## additive diagonal shift: hat ~ true + diag(delta)?
  cat(sprintf("  rel_frob of OFF-DIAG block only = %.4f\n",
              sqrt(sum(off(h) - off(t))^0 * sum((off(h) - off(t))^2)) / sqrt(sum(off(t)^2))))
  cat(sprintf("  rel_frob of DIAG only          = %.4f\n",
              sqrt(sum((diag(h) - diag(t))^2)) / sqrt(sum(diag(t)^2))))
  ## contribution decomposition of the total squared error
  num2 <- sum((h - t)^2); den2 <- sum(t^2)
  cat(sprintf("  err^2 share: diag=%.1f%%  offdiag=%.1f%%\n",
              100 * sum((diag(h) - diag(t))^2) / num2,
              100 * 2 * sum((off(h) - off(t))^2) / num2))
  invisible(NULL)
}
rep1("TIER 1 (unit / ordinary latent)", S1h, S1t)
rep1("TIER 2 (phy / phylo latent)", S2h, S2t)

## --- THE SUM: is only the total identified? ---
cat("\n======== SUM OF TIERS ========\n")
rep1("TIER1 + TIER2", S1h + S2h, S1t + S2t)

## --- psi split diagnostic ---
cat("\n======== psi / loading split ========\n")
L1t <- sim$truth$tier1$Lambda; L2t <- sim$truth$tier2$Lambda
p1t <- sim$truth$tier1$psi;    p2t <- sim$truth$tier2$psi
cat(sprintf("truth psi1: mean=%.4f  psi2: mean=%.4f  sum=%.4f\n",
            mean(p1t), mean(p2t), mean(p1t + p2t)))
cat(sprintf("truth LL' diag tier1 mean=%.4f  tier2 mean=%.4f\n",
            mean(diag(L1t %*% t(L1t))), mean(diag(L2t %*% t(L2t)))))
cat(sprintf("hat  diag tier1 mean=%.4f  tier2 mean=%.4f  sum=%.4f (truth sum=%.4f)\n",
            mean(diag(S1h)), mean(diag(S2h)), mean(diag(S1h) + diag(S2h)),
            mean(diag(S1t) + diag(S2t))))

saveRDS(list(S1h = S1h, S2h = S2h, S1t = S1t, S2t = S2t, gcf = gcf,
             truth = sim$truth[c("beta0", "tier1", "tier2")], N = N0, seed = seed0),
        sprintf("dev/design108-recovery/pilot-results/noether-diag1-N%d-s%d.rds", N0, seed0))
cat("\nDONE\n")
