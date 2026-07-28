## Does the ordinal_probit p_k clamp (src/gllvmTMB.cpp:2180-2182) bind at
## realistic adaptive-GH node reach? Measures the eta excursion over a k-node
## adaptive rule and the resulting minimum cell probability.
suppressPackageStartupMessages(library(gllvmTMB))
ctl <- gllvmTMBcontrol(se = FALSE)
gh_x <- function(k) { J <- matrix(0,k,k); off <- sqrt(seq_len(k-1)/2)
  J[cbind(seq_len(k-1),2:k)] <- off; J[cbind(2:k,seq_len(k-1))] <- off
  sort(eigen(J, symmetric=TRUE)$values) }
set.seed(21); ns <- 25L; nt <- 3L
Y <- matrix(sample(1:4, ns*nt, TRUE), ns, nt); colnames(Y) <- paste0("t",1:nt)
d <- data.frame(site = factor(seq_len(ns)), Y, check.names = FALSE)
fit <- suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3) ~ 1 + latent(1 | site, d = 1, unique = FALSE),
  data = d, unit = "site", family = ordinal_probit(), control = ctl)))
ob <- fit$tmb_obj; th <- ob$env$last.par.best; ri <- ob$env$random
H <- ob$env$spHess(th, random = TRUE)
sd_cond <- 1/sqrt(diag(as.matrix(H)))          # per-unit conditional SD (q=1)
lam <- as.numeric(fit$report$Lambda_B)
for (k in c(5,9,15,25)) {
  reach <- sqrt(2) * max(abs(gh_x(k)))          # in conditional-SD units
  u_max <- reach * max(sd_cond)
  eta_shift <- u_max * max(abs(lam))
  cat(sprintf("k=%2d  GH max node %.3f -> u excursion %.3f -> |eta| shift %.3f -> min cell p ~ %.3g %s\n",
      k, reach, u_max, eta_shift, pnorm(-eta_shift),
      if (pnorm(-eta_shift) < 1e-12) "*** CLAMP BINDS (1e-12 floor) ***" else ""))
}
cat("\n  max |Lambda_B| =", round(max(abs(lam)),3),
    " max conditional SD =", round(max(sd_cond),3), "\n")
cat("  clamp binds once |eta - tau| > ", round(-qnorm(1e-12),2), "\n")
