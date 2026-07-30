## Reads the false-positive sweep and reports the operating characteristic of
## each candidate rule for the runaway-loading gate.
##
## HEALTHY  rel_frob <= 0.5   (G = Lambda Lambda' recovered to within 50%
##                             relative Frobenius error of the known truth)
## DEGENERATE rel_frob >= 5   (off by a factor of 5 or more)
## MIDDLE   everything else -- reported, never counted as either.
##
## The row only exists for binomial fits, so FPR/TPR are computed on binomial
## rows alone. Gaussian and poisson are reported separately as transport
## evidence for the statistic itself.

args <- commandArgs(trailingOnly = TRUE)
csv <- if (length(args) >= 1) args[[1]] else "dev/heywood/fp-sweep-full.csv"
d <- utils::read.csv(csv)

d$health <- ifelse(
  d$rel_frob <= 0.5, "healthy",
  ifelse(d$rel_frob >= 5, "degenerate", "middle")
)
ok <- !is.na(d$rl_max) & is.na(d$error)
cat(sprintf(
  "rows=%d  errors=%d  usable=%d  total fit time=%.1f h\n",
  nrow(d), sum(!is.na(d$error)), sum(ok), sum(d$seconds, na.rm = TRUE) / 3600
))

d <- d[ok, ]
cat("\n=== fits by family x dgp x health ===\n")
print(ftable(table(d$family, d$dgp, d$health)))

## ------------------------------------------------ the null distribution ----

h <- d[d$health == "healthy", ]
cat("\n=== HEALTHY rl_max upper tail, by family x dgp (max over cells) ===\n")
print(round(tapply(h$rl_max, list(h$dgp, h$family), max), 2))
cat("\n=== HEALTHY rl_max quantiles, binomial only, by dgp ===\n")
hb <- h[h$family == "binomial", ]
print(round(do.call(rbind, tapply(
  hb$rl_max, hb$dgp, stats::quantile, c(.5, .9, .99, 1)
)), 2))
cat("\n=== HEALTHY binomial rl_max max, by n x p (worst over dgp, q) ===\n")
print(round(tapply(hb$rl_max, list(hb$n, hb$p), max), 2))
cat("\n=== HEALTHY binomial rl_max max, by q ===\n")
print(round(tapply(hb$rl_max, hb$q, max), 2))

g <- d[d$health == "degenerate" & d$family == "binomial", ]
cat("\n=== DEGENERATE binomial rl_max quantiles ===\n")
print(round(stats::quantile(g$rl_max, c(0, .01, .05, .1, .25, .5, 1)), 2))
cat(sprintf("  n healthy binomial = %d, n degenerate binomial = %d\n",
            nrow(hb), nrow(g)))

cat("\n=== saturation of the worst-ratio trait ===\n")
cat("healthy   :", paste(round(stats::quantile(
  hb$rl_argmax_saturation, c(.5, .9, .99, 1), na.rm = TRUE
), 3), collapse = " "), "\n")
cat("degenerate:", paste(round(stats::quantile(
  g$rl_argmax_saturation, c(0, .05, .25, .5), na.rm = TRUE
), 3), collapse = " "), "\n")

## ------------------------------------------- operating characteristics ----

## the shipped rule, reconstructed: extreme_prevalence & (dominant | saturated)
old_flag <- function(x, rel_thresh = 8) {
  x$rl_argmax_extreme_prev &
    (x$rl_max >= rel_thresh |
      (!is.na(x$rl_argmax_saturation) & x$rl_argmax_saturation >= 0.5))
}

rules <- list(
  shipped = function(x, tau) old_flag(x),
  runaway_alone = function(x, tau) old_flag(x) | (x$rl_max >= tau),
  runaway_and_saturated = function(x, tau) {
    old_flag(x) |
      (x$rl_max >= tau &
        !is.na(x$rl_argmax_saturation) &
        x$rl_argmax_saturation >= 0.5)
  }
)

taus <- c(8, 15, 25, 40, 50, 60, 75, 100, 150, 200)
cat("\n=== operating characteristic (binomial fits only) ===\n")
cat(sprintf("%-24s %6s %8s %8s %8s\n", "rule", "tau", "FPR", "TPR", "FP/FN"))
for (rn in names(rules)) {
  for (tau in taus) {
    fpr <- mean(rules[[rn]](hb, tau))
    tpr <- mean(rules[[rn]](g, tau))
    cat(sprintf(
      "%-24s %6.0f %8.4f %8.4f %4.0f/%-4.0f\n",
      rn, tau, fpr, tpr, sum(rules[[rn]](hb, tau)), sum(!rules[[rn]](g, tau))
    ))
    if (rn == "shipped") break # tau-independent
  }
}

## worst-case false positive per dgp at the candidate thresholds
cat("\n=== runaway_alone FPR by dgp (binomial healthy) ===\n")
for (tau in c(40, 50, 60, 75, 100)) {
  fp <- tapply(hb$rl_max >= tau, hb$dgp, mean)
  cat(sprintf("tau=%3.0f  %s\n", tau, paste(
    sprintf("%s=%.4f", names(fp), fp), collapse = "  "
  )))
}

cat("\n=== what a runaway gate would do to gaussian/poisson if generalised ===\n")
ho <- h[h$family != "binomial", ]
for (tau in c(40, 50, 60, 75, 100)) {
  fp <- tapply(ho$rl_max >= tau, list(ho$dgp, ho$family), mean)
  cat(sprintf("tau=%3.0f\n", tau))
  print(round(fp, 4))
}
