## Sanity check: does .profile_ci_total_variance()'s trait order match the
## DGP's trait order (Lambda row t = trait t), so la_vj_cover in
## 40-step0-pilot.R is not silently mis-paired?
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

T0 <- 8L; Q0 <- 2L; N0 <- 150L; PSI_LO <- 0.3; PSI_HI <- 0.5
set.seed(20260801L)
Lambda <- matrix(0, T0, Q0)
for (k in seq_len(Q0)) Lambda[k, k] <- stats::runif(1, 0.7, 1.3)
for (k in 1:(Q0 - 1)) for (kk in (k + 1):Q0) Lambda[kk, k] <- stats::runif(1, -0.5, 0.5)
for (t in (Q0 + 1):T0) Lambda[t, ] <- stats::rnorm(Q0, 0, 0.7)
psi_true <- stats::runif(T0, PSI_LO, PSI_HI)
beta_true <- stats::rnorm(T0, 0, 0.5)
z <- matrix(stats::rnorm(N0 * Q0), N0, Q0)
x <- stats::rnorm(N0)
eta <- outer(x, beta_true) + z %*% t(Lambda)
y <- eta + matrix(stats::rnorm(N0 * T0, 0, sqrt(rep(psi_true, each = N0))), N0, T0)
d <- data.frame(y = as.numeric(t(y)), trait = factor(rep(seq_len(T0), times = N0)),
                unit = factor(rep(seq_len(N0), each = T0)), x = rep(x, each = T0))
Sigma_true <- Lambda %*% t(Lambda)
v_j_true <- diag(Sigma_true) + psi_true
cat("levels(d$trait):", paste(levels(d$trait), collapse=","), "\n")
cat("v_j_true (trait order 1..T0):", paste(sprintf("%.3f", v_j_true), collapse=", "), "\n")

fit <- gllvmTMB::gllvmTMB(
  y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q0, unique = FALSE),
  data = d, family = stats::gaussian(), unit = "unit", silent = TRUE
)
la_vj <- gllvmTMB:::.profile_ci_total_variance(fit, tier = "unit")
print(la_vj)
cat("\ncorrelation(estimate, truth) assuming SAME order:",
    cor(la_vj$estimate, v_j_true), "\n")
cat("does la_vj$trait match levels(d$trait) order exactly:",
    identical(as.character(la_vj$trait), levels(d$trait)), "\n")
cover <- (v_j_true >= la_vj$lower) & (v_j_true <= la_vj$upper)
cat("coverage this seed:", paste(cover, collapse=","), "mean=", mean(cover), "\n")
cat("\nside by side:\n")
print(data.frame(trait=la_vj$trait, truth=v_j_true, est=la_vj$estimate,
                  lower=la_vj$lower, upper=la_vj$upper, cover=cover))
