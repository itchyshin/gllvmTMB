## Design 108 s0.2 -- analysis of the silent-divergence grid.
##
## WHY THIS EXISTS SEPARATELY: the campaign script's built-in summary reports
## family x arm, family x miss, and sigma_lambda x arm -- but NOT by n. The
## n-ladder is the axis the central hypothesis lives on, so it needs its own
## pass. Read-only over the results CSV; runs anywhere, changes nothing.
##
## THE HYPOTHESIS UNDER TEST (pre-registered here before the grid returned, so
## it cannot be retrofitted to the data):
##   Silent divergence is a SMALL-n phenomenon that decays with n.
## Prior evidence pointing that way, all of it thin:
##   * Design 108 s0.2's own baseline: 8/10 degenerate at n=60 vs 2/10 at n=100
##     (Bernoulli-LOGIT, one cell each).
##   * This arc's smoke: binomial-probit n=60 rel_frob 605 (conv=0, pdHess=TRUE).
##   * This arc's Totoro probes at n=1600, sigma_lambda=3, ONE seed each:
##     binomial-probit 0.178 (default) / 0.148 (ridge2);
##     ordinal_probit  0.153 (default) / 0.108 (ridge2). None divergent.
## If it holds, it is decision-relevant in a specific way: Ayumi's model is
## n = 5397, i.e. FAR above the regime where the problem appears to live, which
## argues differently about the 26-42 day programme than a failure that persists.
##
## WHAT WOULD FALSIFY IT: a flat or rising rate across the n ladder, or a rate
## that stays materially > 0 at n = 1600. Report the falsifier either way --
## a null result here is a real result.

args <- commandArgs(trailingOnly = TRUE)
csv  <- if (length(args)) args[[1]] else "~/gllvm_work/results/design108-stage8-grid.csv"
d <- utils::read.csv(path.expand(csv), stringsAsFactors = FALSE)

cat("rows:", nrow(d), " OK fits:", sum(d$status == "OK"), "\n")
bad <- d[d$status != "OK", ]
if (nrow(bad)) {
  cat("\nNON-OK CELLS (report, never silently drop):\n")
  print(table(bad$family, bad$status))
}
ok <- d[d$status == "OK", ]

pct <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else round(100 * mean(x, na.rm = TRUE), 1)

## Wilson interval -- with 30 seeds a bare proportion invites over-reading.
wilson <- function(x) {
  x <- x[!is.na(x)]; n <- length(x); if (!n) return(c(NA, NA))
  p <- mean(x); z <- 1.96; den <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / den
  hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  round(100 * c(max(0, ctr - hw), min(1, ctr + hw)), 1)
}

cat("\n================ THE HEADLINE: silent-divergence rate by n ================\n")
cat("(silent = rel_frob > 10 AND convergence == 0 AND pdHess == TRUE)\n\n")
for (fam in sort(unique(ok$family))) {
  cat("--", fam, "--\n")
  s <- ok[ok$family == fam, ]
  tab <- tapply(s$silent_divergent, list(s$n, s$arm), pct)
  print(tab)
  cat("\n")
}

cat("\n=========== n x sigma_lambda x arm (does the ridge hold at scale?) ===========\n")
cat("#847 says aghq_ridge = 2 still runs away in 67% of fits at n=1600,\n")
cat("sigma_lambda=3. THIS is the cell that adjudicates it:\n\n")
for (sl in sort(unique(ok$sigma_lambda))) {
  cat("-- sigma_lambda =", sl, "--\n")
  s <- ok[ok$sigma_lambda == sl, ]
  print(tapply(s$silent_divergent, list(s$n, s$arm), pct))
  cat("\n")
}

cat("\n=========== the #847 comparison cell, with a Wilson 95% interval ===========\n")
cell <- ok[ok$n == 1600 & ok$sigma_lambda == 3 & ok$arm == "ridge2", ]
if (nrow(cell)) {
  cat("n=1600, sigma_lambda=3, arm=ridge2:  n_fits =", nrow(cell),
      " rate =", pct(cell$silent_divergent), "%",
      " 95% CI [", paste(wilson(cell$silent_divergent), collapse = ", "), "]\n")
  cat("#847's reported figure for comparison: 67%\n")
} else cat("cell absent\n")

cat("\n=========== positive control (MUST be ~0, else the instrument is broken) ===========\n")
gc_ <- ok[ok$family == "gaussian_control", ]
cat("gaussian_control silent-divergence rate:", pct(gc_$silent_divergent), "%",
    " (n_fits =", nrow(gc_), ")\n")
if (isTRUE(pct(gc_$silent_divergent) > 5)) {
  cat("*** WARNING: the positive control is diverging. A null result elsewhere is\n")
  cat("*** NOT interpretable until this is explained. Do not report rates.\n")
}

cat("\n=========== how OFTEN do the health flags lie? ===========\n")
cat("degenerate := rel_frob > 10, regardless of what the fit reported.\n\n")
ok$degenerate <- ok$rel_frob > 10
deg <- ok[which(ok$degenerate), ]
cat("degenerate fits:", nrow(deg), "of", nrow(ok),
    sprintf("(%.1f%%)", 100 * nrow(deg) / nrow(ok)), "\n")
if (nrow(deg)) {
  silent <- sum(deg$convergence == 0 & deg$pdHess, na.rm = TRUE)
  cat("of those, SILENT (conv==0 & pdHess==TRUE):", silent,
      sprintf("(%.1f%%)", 100 * silent / nrow(deg)), "\n")
  cat("=> the package's own signal catches",
      sprintf("%.1f%%", 100 * (1 - silent / nrow(deg))), "of its own failures.\n")
}

cat("\n=========== missingness axis ===========\n")
print(tapply(ok$silent_divergent, list(ok$family, ok$miss), pct))

cat("\n=========== VERDICT SCAFFOLD (fill from the numbers above) ===========\n")
rate_small <- pct(ok$silent_divergent[ok$n <= 150])
rate_large <- pct(ok$silent_divergent[ok$n >= 1600])
cat("rate at n <= 150 :", rate_small, "%\n")
cat("rate at n >= 1600:", rate_large, "%\n")
if (!is.na(rate_small) && !is.na(rate_large)) {
  if (rate_small > rate_large + 5) {
    cat("=> CONSISTENT with the small-n hypothesis. Ayumi is n=5397, far above\n")
    cat("   the affected regime. State the n at which it becomes negligible.\n")
  } else if (rate_large >= rate_small) {
    cat("=> HYPOTHESIS FALSIFIED: the rate does not decay with n. This is the\n")
    cat("   more expensive answer and must be reported as such.\n")
  } else {
    cat("=> AMBIGUOUS: decay present but small. Do not over-read.\n")
  }
}
cat("\nREMEMBER: this measures the SHIPPED LAPLACE engine only. It says nothing\n")
cat("about VA accuracy, and nothing here promotes any capability claim.\n")
