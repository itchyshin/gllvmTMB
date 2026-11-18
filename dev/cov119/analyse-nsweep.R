## Wave-5 (Design 119 §8) — analyse the n-sweep.
##
## Question: the closed five-route ladder localised the residual
## under-coverage to the FITTED MODEL at n = 50, not to any variance
## formula. If that reading is right, coverage must rise toward nominal as n
## grows. This scores the sweep and reports where (or whether) it closes.
##
## TWO THINGS ARE REPORTED, DELIBERATELY, AND THE ORDER MATTERS.
##
## 1. The COVERAGE CURVE is primary. It answers the scientific question
##    directly and its interpretation does not move with n.
## 2. The GATE verdict is secondary, because the gate TIGHTENS as n grows:
##    the band is +/-2*MCSE, and MCSE shrinks both with more masked cells per
##    fit (250 at n = 50, 8000 at n = 1600) and with the coverage estimate
##    itself. A deficit that passes at n = 50 could fail at n = 1600 while
##    the interval got BETTER. Reporting the gate alone would therefore
##    invert the finding. Both are printed; the curve leads.
##
##   Rscript analyse-nsweep.R <dir-of-summary-n*.csv>

args <- commandArgs(trailingOnly = TRUE)
dir  <- if (length(args)) args[[1]] else "."
files <- Sys.glob(file.path(dir, "summary-n*.csv"))
stopifnot("no summary-n*.csv found" = length(files) > 0)

ns <- as.integer(sub(".*summary-n([0-9]+)\\.csv$", "\\1", files))
files <- files[order(ns)]; ns <- sort(ns)

all <- do.call(rbind, Map(function(f, n) { d <- read.csv(f); d$n <- n; d }, files, ns))

kinds <- list(c("cov95_conf","mcse95_conf",0.95), c("cov90_conf","mcse90_conf",0.90),
              c("cov95_pred","mcse95_pred",0.95), c("cov90_pred","mcse90_pred",0.90))

cat("=== COVERAGE CURVE (primary) — failure-inclusive, mean over 4 mechanisms ===\n\n")
cat(sprintf("%-6s %-8s %9s %9s %9s %9s %8s\n",
            "n", "cells", "conf95", "conf90", "pred95", "pred90", "conv"))
for (n in ns) {
  s <- all[all$n == n, ]
  fi <- function(col) mean(s[[col]])
  cat(sprintf("%-6d %-8d %9.4f %9.4f %9.4f %9.4f %8.3f\n", n,
              as.integer(mean(s$n_attempt)), fi("fi_cov95_conf"), fi("fi_cov90_conf"),
              fi("fi_cov95_pred"), fi("fi_cov90_pred"), mean(s$conv_rate)))
}

cat("\n=== DEFICIT (nominal - coverage), in percentage points ===\n\n")
cat(sprintf("%-6s %9s %9s %9s %9s\n", "n", "conf95", "conf90", "pred95", "pred90"))
for (n in ns) {
  s <- all[all$n == n, ]
  cat(sprintf("%-6d %9.2f %9.2f %9.2f %9.2f\n", n,
              100*(0.95 - mean(s$fi_cov95_conf)), 100*(0.90 - mean(s$fi_cov90_conf)),
              100*(0.95 - mean(s$fi_cov95_pred)), 100*(0.90 - mean(s$fi_cov90_pred))))
}

cat("\n=== GATE (secondary; the band TIGHTENS with n — see header) ===\n\n")
cat(sprintf("%-6s %-18s %8s %10s %10s %s\n", "n", "mechanism", "conf95", "2xMCSE", "|dev|", "pass"))
tot <- data.frame()
for (n in ns) {
  s <- all[all$n == n, ]
  for (i in seq_len(nrow(s))) {
    for (k in kinds) {
      cov <- s[[sub("^cov", "fi_cov", k[1])]][i]; mc <- as.numeric(s[[k[2]]][i]); tgt <- as.numeric(k[3])
      tot <- rbind(tot, data.frame(n = n, mech = s$mechanism[i], kind = k[1],
                                   cov = cov, band = 2*mc, dev = abs(cov - tgt),
                                   pass = abs(cov - tgt) <= 2*mc))
    }
    r <- s[i, ]
    cat(sprintf("%-6d %-18s %8.4f %10.4f %10.4f %s\n", n, r$mechanism,
                r$fi_cov95_conf, 2*r$mcse95_conf, abs(r$fi_cov95_conf - 0.95),
                ifelse(abs(r$fi_cov95_conf - 0.95) <= 2*r$mcse95_conf, "PASS", "fail")))
  }
}

cat("\n=== GATE SUMMARY (16 cells per n: 4 mechanisms x conf/pred x 90/95) ===\n\n")
for (n in ns) {
  t <- tot[tot$n == n, ]
  cat(sprintf("n=%-6d %2d/%2d pass   mean band = %.4f (tightens with n)\n",
              n, sum(t$pass), nrow(t), mean(t$band)))
}
cat("\nNOTE: a falling pass-count alongside RISING coverage means the gate\n",
    "outran the estimator, not that the interval got worse. Read the curve.\n", sep = "")
