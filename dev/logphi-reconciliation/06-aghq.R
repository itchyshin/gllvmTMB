source("/private/tmp/gllvmtmb-logphi/dev/logphi-reconciliation/01-primitives.R")
## End-to-end check of the bound: for one ordinal observation in a MIDDLE
## category, the AGHQ log-marginal log sum_h w_h exp(logp_k(eta_h)) is a
## log-sum-exp, i.e. a convex-weighted average of the per-node terms, so the
## error in the marginal cannot exceed the worst per-node error. Confirm it.
gh <- function(H) {                       # physicists' Gauss-Hermite
  i <- 1:(H - 1); d <- sqrt(i / 2)
  e <- eigen(diag(0, H) + diag(d, H, H)[, , drop = FALSE] * 0, only.values = FALSE)
  J <- matrix(0, H, H); J[cbind(i, i + 1)] <- d; J[cbind(i + 1, i)] <- d
  e <- eigen(J, symmetric = TRUE)
  o <- order(e$values)
  list(x = e$values[o], w = (e$vectors[1, o]^2) * sqrt(pi))
}
set.seed(1)
worst <- 0; worst_case <- NULL
for (H in c(15, 31, 61)) {
  q <- gh(H)
  for (s in c(0.5, 1, 2, 3)) for (mu in c(0, -3, -8, -14)) for (gap in c(0.1, 0.5, 1, 1.5)) {
    eta <- mu + sqrt(2) * s * q$x
    a <- 0 - eta; b <- a - gap              # upper/lower cutpoint minus eta
    lS <- gll_log_pnorm_diff(a, b, ship_logphi)
    lV <- gll_log_pnorm_diff(a, b, va_logphi)
    lw <- log(q$w / sqrt(pi))
    mS <- max(lS + lw); MS <- mS + log(sum(exp(lS + lw - mS)))
    mV <- max(lV + lw); MV <- mV + log(sum(exp(lV + lw - mV)))
    d <- abs(MS - MV)
    if (d > worst) { worst <- d; worst_case <- c(H = H, s = s, mu = mu, gap = gap) }
  }
}
cat("max |AGHQ log-marginal(ship) - AGHQ log-marginal(va)| over 192 configs =",
    format(worst, digits = 4), "\n"); print(worst_case)
cat("per-node bound measured earlier = 9.14e-11\n")
