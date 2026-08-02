source("/private/tmp/gllvmtmb-logphi/dev/logphi-reconciliation/01-primitives.R")
outdir <- "/private/tmp/gllvmtmb-logphi/dev/logphi-reconciliation"

## ---- Part 1: pointwise grid ------------------------------------------------
mk <- function(region, x) data.frame(region = region, x = x)
grid <- rbind(
  mk("bulk [-8, 5]",              seq(-8, 5, length.out = 601)),
  mk("VA switch nbhd [-12,-8]",   sort(c(seq(-12, -8, length.out = 401), -10,
                                         -10 + 1e-9, -10 - 1e-9))),
  mk("between switches [-20,-10]",seq(-20, -10, length.out = 801)),
  mk("ship switch nbhd [-22,-18]",sort(c(seq(-22, -18, length.out = 401), -20,
                                         -20 + 1e-9, -20 - 1e-9))),
  mk("Stage5 AGHQ [-60,-20]",     seq(-60, -20, length.out = 801)),
  mk("deep tail [-300,-60]",      seq(-300, -60, length.out = 801))
)
grid$ship <- ship_logphi(grid$x)
grid$va   <- va_logphi(grid$x)
write.csv(grid, file.path(outdir, "grid.csv"), row.names = FALSE)

## ---- Part 2: the DIFFERENCE (ordinal middle-category cell probability) -----
## Shipped ordinal_probit path (src/gllvmTMB.cpp:2300):
##   logp_k = gll_log_pnorm_diff(cuts(k-1) - eta, cuts(k-2) - eta)
## so a = upper cutpoint - eta, b = a - gap, gap = the cutpoint spacing.
## Realistic gaps come from cuts(j) = cuts(j-1) + exp(log_increment): typically
## O(0.3-1.5). Adversarially small gaps are included to find where it breaks.
gaps <- c(1e-8, 1e-6, 1e-4, 1e-3, 1e-2, 0.05, 0.1, 0.3, 0.5, 1.0, 1.5, 3.0)
as_  <- c(5, 2, 0, -2, -5, -9.9, -10, -10.1, -15, -19.9, -20, -20.1,
          -22, -25, -30, -40, -60, -100)
dd <- expand.grid(a = as_, gap = gaps)
dd$b <- dd$a - dd$gap
dd$ship_diff <- gll_log_pnorm_diff(dd$a, dd$b, ship_logphi)
dd$va_diff   <- gll_log_pnorm_diff(dd$a, dd$b, va_logphi)
dd$ship_lss  <- logspace_sub_naive(dd$a, dd$b, ship_logphi)
dd$va_lss    <- logspace_sub_naive(dd$a, dd$b, va_logphi)
write.csv(dd, file.path(outdir, "diffs.csv"), row.names = FALSE)
cat("rows:", nrow(grid), nrow(dd), "\n")
