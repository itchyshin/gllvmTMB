## Wave-6 (Design 119 §8b) — analyse the p-sweep.
##
## THE PREDICTION, STATED BEFORE THE DATA ARE READ.
##
## Wave-5 swept n over a 32-fold range at p = 25 and found a DISSOCIATION:
## the prediction-interval deficit fell monotonically (1.13 -> 0.56 points at
## 95%; pred90 crossed nominal), while the confidence-interval deficit stayed
## FLAT (0.61 -> 0.51). More units did not sharpen the reconstruction.
##
## The mechanism that predicts exactly that shape: a masked cell's linear
## predictor is eta_ut = x'b + lambda_t' u_i, and the unit score u_i is
## reconstructed from THAT UNIT'S OTHER OBSERVED TRAITS -- about p of them,
## however many units exist. So u_i's information is O(p), not O(n). Adding
## units sharpens lambda and b (whose uncertainty does vanish) but cannot
## sharpen u_i, which is the dominant term. Prediction intervals improve
## because their extra variance term is the family variance, estimated
## globally from n*p cells.
##
## HYPOTHESIS H: the confidence deficit is governed by p, not n.
##   H predicts: conf deficit falls substantially and monotonically in p.
##   H is REFUTED if the conf deficit is as flat in p as it was in n.
##
## A refutation is the more valuable outcome, because it would mean the
## residual is neither a small-n nor a small-p effect and the §7f reading
## needs replacing rather than refining. Report whichever the data show.
##
##   Rscript analyse-psweep.R <dir-of-summary-p*.csv>

args <- commandArgs(trailingOnly = TRUE)
dir  <- if (length(args)) args[[1]] else "."
files <- Sys.glob(file.path(dir, "summary-p*.csv"))
stopifnot("no summary-p*.csv found" = length(files) > 0)
ps <- as.integer(sub(".*summary-p([0-9]+)\\.csv$", "\\1", files))
files <- files[order(ps)]; ps <- sort(ps)
all <- do.call(rbind, Map(function(f, p) { d <- read.csv(f); d$p <- p; d }, files, ps))

cat("=== COVERAGE vs p (n = 200 fixed, q = 2, gaussian, sim route) ===\n\n")
cat(sprintf("%-6s %9s %9s %9s %9s %8s\n", "p", "conf95", "conf90", "pred95", "pred90", "conv"))
for (p in ps) {
  s <- all[all$p == p, ]
  cat(sprintf("%-6d %9.4f %9.4f %9.4f %9.4f %8.3f\n", p,
              mean(s$fi_cov95_conf), mean(s$fi_cov90_conf),
              mean(s$fi_cov95_pred), mean(s$fi_cov90_pred), mean(s$conv_rate)))
}

cat("\n=== DEFICIT (nominal - coverage), percentage points ===\n\n")
cat(sprintf("%-6s %9s %9s %9s %9s\n", "p", "conf95", "conf90", "pred95", "pred90"))
d95 <- numeric(0)
for (p in ps) {
  s <- all[all$p == p, ]
  v <- 100*(0.95 - mean(s$fi_cov95_conf)); d95 <- c(d95, v)
  cat(sprintf("%-6d %9.2f %9.2f %9.2f %9.2f\n", p, v,
              100*(0.90 - mean(s$fi_cov90_conf)), 100*(0.95 - mean(s$fi_cov95_pred)),
              100*(0.90 - mean(s$fi_cov90_pred))))
}

cat("\n=== VERDICT ON H ===\n\n")
cat(sprintf("conf95 deficit: %.2f pt at p=%d  ->  %.2f pt at p=%d   (change %+.2f pt)\n",
            d95[1], ps[1], d95[length(d95)], ps[length(ps)], d95[length(d95)] - d95[1]))
cat(sprintf("for comparison, wave-5 over a 32x range in n: 0.61 -> 0.51 pt (change -0.10 pt)\n"))
mono <- all(diff(d95) <= 0.05)
if (d95[length(d95)] < 0.5 * d95[1]) {
  cat("\nH SUPPORTED: the deficit at least halves across the p range. The\n",
      "confidence deficit is governed by traits-per-unit, not by units --\n",
      "so it is an information limit on the unit score, not a defect in any\n",
      "variance route. The usable rule is about p, not n.\n", sep="")
} else if (abs(d95[length(d95)] - d95[1]) < 0.15) {
  cat("\nH REFUTED: the deficit is as flat in p as it was in n. The residual\n",
      "is neither a small-n nor a small-p effect, so the sec.7f reading must be\n",
      "replaced, not refined. Do NOT report an n- or p-threshold.\n", sep="")
} else {
  cat("\nH PARTIAL: the deficit moves with p but does not halve. Report the\n",
      "measured curve; claim a direction, not a threshold.\n", sep="")
}
cat(sprintf("monotone non-increasing in p: %s\n", mono))
