## HEAD-TO-HEAD driver. Run once with the pre-continuation R/fit-multi.R and once
## with the new one; dev/aghq-h2h-compare.R then scores both on a COMMON honest
## objective. Usage: Rscript dev/aghq-h2h-run.R <label>
lab <- commandArgs(TRUE)[1]
stopifnot(!is.na(lab))
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet = TRUE))
source("dev/arc0/lib.R")

## HEALTHY cells only (dev/aghq-healthy-scan.R): on an Arc-0 degenerate cell the
## Laplace fit is already at ||Sigma_B||_F = 1e3-1e6 before any quadrature runs,
## so nothing measured after AGHQ is attributable to the loop.
cells <- list(list(n = 60, p = 6, q = 2, seed = 7),
              list(n = 100, p = 8, q = 2, seed = 2))

out <- lapply(cells, function(cl) {
  d <- arc0_data(cl$n, cl$p, cl$q, cl$seed)
  ctl <- gllvmTMBcontrol(aghq = 9L)
  t0 <- Sys.time()
  f <- suppressWarnings(gllvmTMB(d$fml, data = d$df,
                                 family = stats::binomial(), control = ctl))
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  L <- f$report$Lambda_B[seq_len(cl$p), seq_len(cl$q), drop = FALSE]
  cat(sprintf("%-6s n=%d p=%d q=%d seed=%d : passes=%s  reported nll=%.6f  ||Sigma_B||_F=%.6g  %.0fs\n",
              lab, cl$n, cl$p, cl$q, cl$seed, f$aghq$passes %||% NA,
              f$opt$objective, norm(L %*% t(L), "F"), el))
  c(cl, list(par = f$opt$par, objective = f$opt$objective,
             frob = norm(L %*% t(L), "F"), elapsed = el,
             passes = f$aghq$passes %||% NA_integer_,
             stop_reason = f$aghq$stop_reason %||% NA_character_))
})
saveRDS(out, sprintf("dev/aghq-h2h-%s.rds", lab))
