source("/private/tmp/gllvmtmb-logphi/dev/logphi-reconciliation/01-primitives.R")
outdir <- "/private/tmp/gllvmtmb-logphi/dev/logphi-reconciliation"
## Dense sweep over a, realistic cutpoint gaps only.
a  <- seq(-45, 10, by = 0.005)
gs <- c(0.05, 0.1, 0.3, 0.5, 1.0, 1.5, 3.0)
dd <- expand.grid(a = a, gap = gs); dd$b <- dd$a - dd$gap
dd$ship <- gll_log_pnorm_diff(dd$a, dd$b, ship_logphi)
dd$va   <- gll_log_pnorm_diff(dd$a, dd$b, va_logphi)
write.csv(dd, file.path(outdir, "diffs_dense.csv"), row.names = FALSE)

## Branch-boundary behaviour: value and one-sided derivative jump at each switch
h <- 1e-6
probe <- function(lp, cut) {
  vL <- lp(cut - 1e-12); vR <- lp(cut + 1e-12)
  dL <- (lp(cut - 1e-12) - lp(cut - 1e-12 - h)) / h
  dR <- (lp(cut + 1e-12 + h) - lp(cut + 1e-12)) / h
  c(vjump = vR - vL, dL = dL, dR = dR, djump = dR - dL)
}
cat("shipped switch x = -20 :\n"); print(probe(ship_logphi, -20))
cat("VA      switch x = -10 :\n"); print(probe(va_logphi,   -10))
cat("exact lambda(-20) =", dnorm(-20)/pnorm(-20), " lambda(-10) =", dnorm(-10)/pnorm(-10), "\n")
