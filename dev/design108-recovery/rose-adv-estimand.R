## ROSE ADVERSARIAL REVIEW -- estimand check.
## The campaign's VA arm fits `scale(sim$data$y)` with family="gaussian_anchor",
## link="identity" (totoro_grid.R:15,19-23), while the DGP is BINOMIAL PROBIT
## (dgp.R:167 `rbinom(N*T, n_trials, pnorm(eta))`) and the planted truth
## `Sigma_B_loadings = Lambda2 Lambda2'` lives on the ETA (probit) scale.
## The Laplace arm fits binomial(probit) on the RAW y (harness.R:404-407).
##
## Question: on the standardized-count scale a gaussian-identity fit actually
## targets, what is the ORACLE rel_frob -- i.e. the score a PERFECT gaussian
## fit would get against the eta-scale truth? If that is far from 0, the
## metric charges VA for a scale change, not for bad recovery.
setwd("/private/tmp/gllvmtmb-d108-recovery")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
source("dev/design108-recovery/dgp.R")
T0 <- 10L

out <- do.call(rbind, lapply(1:6, function(s) {
  sim <- simulate_two_tier(N = 500L, T = T0, q = 1L, seed = s,
                           phylo_scale = 1, n_trials = 6L)
  d <- sim$data
  yv <- as.numeric(scale(d$y))
  eta <- d$eta_true
  ## best linear (attenuation) coefficient of the standardized response on eta
  k <- as.numeric(cov(yv, eta) / var(eta))
  S2 <- sim$truth$tier2$Sigma_B_loadings
  S1 <- sim$truth$tier1$Sigma_B_loadings
  ## A gaussian-identity fit that recovers the standardized-scale structure
  ## PERFECTLY estimates k^2 * Sigma (signal scaled by k). Its score against
  ## the eta-scale truth is ||k^2 S - S||_F/||S||_F = |k^2 - 1|.
  data.frame(seed = s,
             sd_y = sd(d$y), mean_y = mean(d$y),
             sd_eta = sd(eta),
             k = k, k2 = k^2,
             oracle_relfrob = abs(k^2 - 1),
             norm_S2 = norm(S2, "F"), norm_S1 = norm(S1, "F"),
             ## what a pure zero-estimate scores (the collapse signature)
             zero_relfrob = rel_frob(matrix(0, T0, T0), S2))
}))
print(out, row.names = FALSE, digits = 4)
cat("\nmean k^2 =", round(mean(out$k2), 4),
    " mean ORACLE rel_frob for a perfect gaussian-identity fit =",
    round(mean(out$oracle_relfrob), 4), "\n")
cat("rel_frob of an exact-ZERO estimate (by construction) =",
    round(mean(out$zero_relfrob), 6), "\n")
cat("\nROSE_ESTIMAND_DONE\n")
