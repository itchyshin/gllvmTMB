d <- read.csv("dev/aghq-evidence/25-convergence-nladder.csv")
has <- grepl("max .grad. = ", d$stop_reason)
d$grad <- ifelse(has, as.numeric(sub(".*max .grad. = ([0-9.e+-]+).*", "\\1", d$stop_reason)), NA)

cat("=== convergence % by n x arm (150 fits, Totoro, gllvmTMB built 2026-07-29) ===\n")
print(round(100 * tapply(d$converged, list(d$n, d$arm), mean), 1))

cat("\n=== why the loop stopped, by n ===\n")
cls <- ifelse(grepl("^converged", d$stop_reason), "converged",
       ifelse(grepl("^stalled", d$stop_reason), "stalled at cap 1",
       ifelse(grepl("gradient|exceeds", d$stop_reason), "grad above tolerance", "adaptation failed")))
print(table(d$n, cls))

cat("\n=== max|grad| at stop vs the FIXED 1e-4 tolerance ===\n")
cat(sprintf("%6s %6s %13s %13s %13s %9s\n", "n", "nrep", "median|grad|", "min", "max", "x tol"))
for (n in sort(unique(d$n))) {
  s <- d$grad[d$n == n & !is.na(d$grad)]
  if (!length(s)) next
  cat(sprintf("%6d %6d %13.3e %13.3e %13.3e %9.1f\n",
              n, length(s), median(s), min(s), max(s), median(s) / 1e-4))
}

md <- tapply(d$grad[!is.na(d$grad)], d$n[!is.na(d$grad)], median)
cat("\n=== does the gradient scale with n? (n quadruples at each step) ===\n")
cat(sprintf("median |grad|: n=100 %.3e  ->  n=400 %.3e  ->  n=1600 %.3e\n", md[1], md[2], md[3]))
cat(sprintf("step ratios  : %.2f  and  %.2f      (n ratio = 4.00 each step)\n", md[2]/md[1], md[3]/md[2]))
cat(sprintf("|grad|/n     : %.3e   %.3e   %.3e   <- flat means the gradient is O(n)\n",
            md[1]/100, md[2]/400, md[3]/1600))

cat("\n=== how many would converge under a RELATIVE tolerance (1e-4 * n/100)? ===\n")
for (n in sort(unique(d$n))) {
  s <- d[d$n == n, ]
  gg <- s$grad[!is.na(s$grad)]
  if (!length(gg)) next
  cat(sprintf("  n=%-5d fixed 1e-4: %2d/%2d converged | scaled tol %.1e would also clear %2d of the %d near-misses\n",
              n, sum(s$converged), nrow(s), 1e-4 * n / 100, sum(gg < 1e-4 * n / 100), length(gg)))
}
cat("\nNOTE: the `stalled at cap 1` branch does NOT report its gradient, so those fits\n")
cat("cannot be classified from outside the engine. Counts above are a LOWER BOUND on\n")
cat("what a scale-aware tolerance would recover.\n")
