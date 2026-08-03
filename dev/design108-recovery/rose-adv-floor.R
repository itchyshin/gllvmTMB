## ROSE ADVERSARIAL REVIEW -- per-cell ORACLE FLOOR for the VA arm.
## The VA arm fits scale(y) with gaussian identity; the truth is on the eta
## (probit) scale. A PERFECT gaussian-identity fit therefore recovers the
## attenuated structure D Sigma D (D = diag of per-trait attenuation k_t) and
## scores rel_frob(D S D, S) > 0 against the eta-scale truth. Laplace fits the
## correctly-specified binomial probit, so ITS floor is 0. This computes the
## VA floor for every cell of the campaign grid, with no fitting at all.
setwd("/private/tmp/gllvmtmb-d108-recovery")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
source("dev/design108-recovery/dgp.R")
T0 <- 10L

GRID <- expand.grid(N = c(500L, 1000L), q = c(1L, 2L), seed = 1:20, KEEP.OUT.ATTRS = FALSE)
res <- do.call(rbind, lapply(seq_len(nrow(GRID)), function(i) {
  g <- GRID[i, ]
  sim <- simulate_two_tier(N = g$N, T = T0, q = g$q, seed = g$seed,
                           phylo_scale = 1, n_trials = 6L)
  d <- sim$data; yv <- as.numeric(scale(d$y))
  kt <- sapply(seq_len(T0), function(t) {
    ii <- d$trait == t
    as.numeric(cov(yv[ii], d$eta_true[ii]) / var(d$eta_true[ii]))
  })
  D <- diag(kt)
  S1 <- sim$truth$tier1$Sigma_B_loadings; S2 <- sim$truth$tier2$Sigma_B_loadings
  data.frame(N = g$N, q = g$q, seed = g$seed,
             floor_t1 = rel_frob(D %*% S1 %*% D, S1),
             floor_t2 = rel_frob(D %*% S2 %*% D, S2))
}))
saveRDS(res, "dev/design108-recovery/pilot-results/rose-adv-floor.rds")

camp <- read.csv("dev/design108-recovery/pilot-results/campaign_grid.csv")
m <- merge(camp, res, by = c("N", "q", "seed"))
m$cell <- paste0("N", m$N, "_q", m$q)
ord <- c("N500_q1", "N1000_q1", "N500_q2", "N1000_q2")

cat("\n##### VA ORACLE FLOOR (score a PERFECT gaussian-identity fit gets) #####\n")
print(aggregate(cbind(floor_t1, floor_t2) ~ cell, m, median), digits = 3)

cat("\n##### TIER 1: observed vs floor  (excess = observed - floor) #####\n")
for (c in ord) {
  s <- m[m$cell == c & !is.na(m$va_t1), ]
  a <- m[m$cell == c, ]
  cat(sprintf("%-9s VA obs=%.3f floor=%.3f EXCESS=%.3f | LAP obs=%.3f floor=0 EXCESS=%.3f\n",
      c, median(s$va_t1), median(s$floor_t1), median(s$va_t1 - s$floor_t1),
      median(a$lap_t1), median(a$lap_t1)))
}
cat("\n##### TIER 2: observed vs floor #####\n")
for (c in ord) {
  s <- m[m$cell == c & !is.na(m$va_t2), ]
  a <- m[m$cell == c, ]
  cat(sprintf("%-9s VA obs=%.3f floor=%.3f EXCESS=%.3f | LAP obs=%.3f floor=0 EXCESS=%.3f\n",
      c, median(s$va_t2), median(s$floor_t2), median(s$va_t2 - s$floor_t2),
      median(a$lap_t2), median(a$lap_t2)))
}
cat("\n##### Could a PERFECT VA have WON on this metric? #####\n")
for (c in ord) {
  a <- m[m$cell == c, ]
  cat(sprintf("%-9s median VA floor(t2)=%.3f vs median LAP observed(t2)=%.3f  -> perfect VA %s\n",
      c, median(a$floor_t2), median(a$lap_t2),
      ifelse(median(a$floor_t2) < median(a$lap_t2), "WINS", "LOSES ANYWAY")))
}
cat("\nROSE_FLOOR_DONE\n")
