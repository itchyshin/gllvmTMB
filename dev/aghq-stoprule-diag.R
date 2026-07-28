## TASK 1 DIAGNOSIS -- why does the AGHQ adaptation stopping rule never fire?
##
## Runs the existing loop with verbose = TRUE, captures the per-pass trajectory
## (objective, max |mode shift|), and reconstructs the objective gain the loop
## actually tests. NOTHING is changed here; this is a look-before-you-touch run.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet = TRUE))
source("dev/arc0/lib.R")

trace_fit <- function(n, p, q, seed, k = 9L, n_adapt = 400L, cap = 1L) {
  d <- arc0_data(n, p, q, seed)
  ctl <- gllvmTMBcontrol(aghq = k, verbose = TRUE)
  ctl$aghq_n_adapt  <- as.integer(n_adapt)
  ctl$aghq_iter_cap <- as.integer(cap)
  t0 <- Sys.time()
  txt <- utils::capture.output(
    fit <- suppressWarnings(gllvmTMB(d$fml, data = d$df,
                                     family = stats::binomial(), control = ctl))
  )
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  ln <- grep("^  AGHQ pass", txt, value = TRUE)
  pass <- as.integer(sub("^  AGHQ pass ([0-9]+):.*", "\\1", ln))
  nll  <- as.numeric(sub(".*-logLik = ([-0-9.eE+]+),.*", "\\1", ln))
  shft <- as.numeric(sub(".*max \\|mode shift\\| = ([-0-9.eE+]+|Inf)$", "\\1", ln))
  list(fit = fit, d = d, elapsed = el,
       tr = data.frame(pass = pass, nll = nll, shift = shft,
                       gain = c(NA, -diff(nll))))
}

show <- function(z, lab) {
  tr <- z$tr; f <- z$fit; p <- ncol(z$d$Y); q <- ncol(z$d$Lt)
  L <- f$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  cat(sprintf("\n=== %s  (%.1f s, %d passes) ===\n", lab, z$elapsed, nrow(tr)))
  cat(sprintf("  aghq$used=%s reason=%s\n", f$aghq$used, f$aghq$reason))
  cat(sprintf("  final nll = %.8f   ||Sigma_B||_F = %.6g   true = %.6g\n",
              f$opt$objective, norm(L %*% t(L), "F"), norm(z$d$Sigma_true, "F")))
  idx <- unique(c(1:8, seq(10, nrow(tr), by = max(1, nrow(tr) %/% 12)), nrow(tr)))
  idx <- idx[idx >= 1 & idx <= nrow(tr)]
  cat("  pass        nll            gain        max|mode shift|\n")
  for (i in idx)
    cat(sprintf("  %4d  %14.8f  %13.6g  %14.6g\n",
                tr$pass[i], tr$nll[i], tr$gain[i], tr$shift[i]))
  cat(sprintf("  TAIL: min |gain| over last 50 = %.6g ; min shift over last 50 = %.6g\n",
              min(abs(tail(tr$gain, 50)), na.rm = TRUE),
              min(tail(tr$shift, 50), na.rm = TRUE)))
  cat(sprintf("  passes with shift<1e-4: %d ; with |gain|<1e-8: %d ; with BOTH: %d\n",
              sum(tr$shift < 1e-4, na.rm = TRUE),
              sum(abs(tr$gain) < 1e-8, na.rm = TRUE),
              sum(tr$shift < 1e-4 & abs(tr$gain) < 1e-8, na.rm = TRUE)))
  invisible(tr)
}

A <- trace_fit(60, 6, 2, 1)
tA <- show(A, "binomial n=60 p=6 q=2 seed=1 k=9 cap=1")
B <- trace_fit(100, 8, 2, 1)
tB <- show(B, "binomial n=100 p=8 q=2 seed=1 k=9 cap=1")
saveRDS(list(A = tA, B = tB), "dev/aghq-stoprule-diag.rds")
