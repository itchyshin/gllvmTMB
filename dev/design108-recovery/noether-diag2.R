## Noether diagnostic 2: decompose the gaussian_control fit into
## shared (Lambda Lambda') and unique (psi) parts per tier, and test the
## psi-split identifiability hypothesis directly. Read-only.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0 <- as.integer(Sys.getenv("D108_N", "250"))
seed0 <- as.integer(Sys.getenv("D108_SEED", "1"))
T0 <- 20L; q0 <- 1L; n_trials0 <- 6L
gauss_sd0 <- as.numeric(Sys.getenv("D108_GSD", "0.4"))

sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                         n_trials = n_trials0)
dat <- sim$data
set.seed(seed0 + 900000L)
dat$y <- dat$eta_true + stats::rnorm(nrow(dat), 0, gauss_sd0)
dat$trait <- factor(dat$trait)
dat$species <- factor(dat$species, levels = sim$tree$tip.label)
tree <- sim$tree
fml <- .d108_two_tier_formula(q0, environment())
fit <- suppressWarnings(gllvmTMB::gllvmTMB(fml, data = dat, unit = "species",
                                           trait = "trait", family = stats::gaussian(),
                                           control = gllvmTMB::gllvmTMBcontrol()))

get <- function(level, part) {
  tryCatch(as.matrix(gllvmTMB::extract_Sigma(fit, level = level, part = part,
                                             link_residual = "none")$Sigma),
           error = function(e) {cat("  [", level, part, "ERR:", conditionMessage(e), "]\n"); NULL})
}
cat("\n### parts available\n")
for (lv in c("unit", "phy")) for (pt in c("total", "shared", "unique")) {
  M <- get(lv, pt)
  if (!is.null(M)) cat(sprintf("  %-5s %-7s diag mean=%.4f  offdiag sd=%.4f\n",
                              lv, pt, mean(diag(M)), sd(M[upper.tri(M)])))
}

L1t <- sim$truth$tier1$Lambda; L2t <- sim$truth$tier2$Lambda
p1t <- sim$truth$tier1$psi;    p2t <- sim$truth$tier2$psi
Sh1 <- get("unit", "shared"); Su1 <- get("unit", "unique")
Sh2 <- get("phy", "shared");  Su2 <- get("phy", "unique")

cat("\n### SHARED part (Lambda Lambda') -- should be identified\n")
cmp <- function(lab, h, t) {
  if (is.null(h)) return(invisible())
  o <- upper.tri(h)
  cat(sprintf("%-28s rel_frob=%.4f  cor(off)=%.4f slope(off)=%.4f  cor(diag)=%.4f slope(diag)=%.4f\n",
              lab, rel_frob(h, t), cor(h[o], t[o]), coef(lm(h[o] ~ t[o]))[2],
              cor(diag(h), diag(t)), coef(lm(diag(h) ~ diag(t)))[2]))
}
cmp("tier1 LL'", Sh1, L1t %*% t(L1t))
cmp("tier2 LL'", Sh2, L2t %*% t(L2t))

cat("\n### UNIQUE part (psi) -- the split hypothesis\n")
ps1h <- if (!is.null(Su1)) diag(Su1) else rep(NA_real_, T0)
ps2h <- if (!is.null(Su2)) diag(Su2) else rep(NA_real_, T0)
cat(sprintf("psi1: true mean=%.4f  hat mean=%.4f  cor=%.4f\n", mean(p1t), mean(ps1h), cor(p1t, ps1h)))
cat(sprintf("psi2: true mean=%.4f  hat mean=%.4f  cor=%.4f\n", mean(p2t), mean(ps2h), cor(p2t, ps2h)))
cat(sprintf("psi1+psi2: true mean=%.4f  (+gauss_sd^2=%.4f => %.4f)   hat mean=%.4f\n",
            mean(p1t + p2t), gauss_sd0^2, mean(p1t + p2t) + gauss_sd0^2, mean(ps1h + ps2h)))
cat(sprintf("psi SUM: cor(hat, true+gsd2)=%.4f  rel err of sum=%.4f\n",
            cor(ps1h + ps2h, p1t + p2t + gauss_sd0^2),
            sqrt(sum((ps1h + ps2h - (p1t + p2t + gauss_sd0^2))^2)) / sqrt(sum((p1t + p2t + gauss_sd0^2)^2))))
cat("\nper-trait psi table (true1, hat1, true2, hat2, sum_true+g, sum_hat):\n")
print(round(data.frame(psi1_true = p1t, psi1_hat = ps1h, psi2_true = p2t, psi2_hat = ps2h,
                       sum_true_g = p1t + p2t + gauss_sd0^2, sum_hat = ps1h + ps2h), 3))

cat("\n### sigma_eps (residual) status\n")
print(tryCatch(fit$sd_report$par.fixed[grep("sigma|eps|disp", names(fit$sd_report$par.fixed))],
               error = function(e) "n/a"))
cat("\nDONE\n")
