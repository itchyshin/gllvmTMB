## Per-pass trace of the NEW continuation loop, with the Laplace reference and
## the truth alongside, so a "runaway" claim can be checked against both.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet = TRUE))
source("dev/arc0/lib.R")

one <- function(n, p, q, seed, k = 9L, ...) {
  d <- arc0_data(n, p, q, seed)
  fl <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial()))
  Ll <- fl$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  ctl <- gllvmTMBcontrol(aghq = k)
  extra <- list(...)
  for (nm in names(extra)) ctl[[nm]] <- extra[[nm]]
  t0 <- Sys.time()
  fa <- suppressWarnings(gllvmTMB(d$fml, data = d$df,
                                  family = stats::binomial(), control = ctl))
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  La <- fa$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  cat(sprintf("\n=== n=%d p=%d q=%d seed=%d k=%d %s ===\n", n, p, q, seed, k,
              paste(names(extra), unlist(extra), sep = "=", collapse = " ")))
  cat(sprintf("  TRUE    ||Sigma_B||_F = %.6g\n", norm(d$Sigma_true, "F")))
  cat(sprintf("  LAPLACE ||Sigma_B||_F = %.6g   nll = %.6f\n",
              norm(Ll %*% t(Ll), "F"), fl$opt$objective))
  cat(sprintf("  AGHQ    ||Sigma_B||_F = %.6g   F   = %.6f   %.1fs\n",
              norm(La %*% t(La), "F"), fa$opt$objective, el))
  cat(sprintf("  stop: %s (passes = %d)\n", fa$aghq$stop_reason, fa$aghq$passes))
  tr <- fa$aghq$trace
  print(utils::head(tr, 15), row.names = FALSE)
  if (nrow(tr) > 15) print(utils::tail(tr, 5), row.names = FALSE)
  invisible(fa)
}

args <- commandArgs(TRUE)
if (length(args) && args[1] == "seed7") {
  one(60, 6, 2, 7)
} else {
  one(60, 6, 2, 1)
  one(40, 8, 2, 1)
}
