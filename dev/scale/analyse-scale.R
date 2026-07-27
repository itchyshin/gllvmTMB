#!/usr/bin/env Rscript
## Analysis of the SCALE regime grid: crossover point, scaling exponents,
## and accuracy-at-scale. Run locally on the rsync'd results (D-50).

args <- commandArgs(trailingOnly = TRUE)
here <- if (length(args)) args[1] else "dev/scale/results"
d <- read.csv(file.path(here, "scale.csv"), stringsAsFactors = FALSE)
out <- file.path(here, "SCALE.md")
say <- function(...) cat(sprintf(...), file = out, append = TRUE)
cat("", file = out)

ARMS <- c(gtmb_gh = "gllvmTMB GH-VA (H=15)", gtmb_jj = "gllvmTMB JJ-VA",
          gllvm_va = "gllvm VA", gtmb_laplace = "gllvmTMB Laplace (Psi suppressed)")

med <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)

say("# Scale-regime comparison: VA vs Laplace, n up to 5000, p up to 50\n\n")
say("Design: family x n(500,1000,2500,5000) x p(27,50) x q=2 x seed(1:3).\n")
say("Compute: Totoro. Results local (D-50).\n\n")
say("Cells attempted: %d rows, %d cells.\n\n", nrow(d),
    nrow(unique(d[c("family","n","p","q","seed")])))

## ---------------------------------------------------- completeness table ---
say("## 0. What ran\n\n")
say("| arm | rows | ERROR | TIMEOUT | usable Sigma |\n|---|---:|---:|---:|---:|\n")
for (a in names(ARMS)) {
  sub <- d[d$arm == a, ]
  say("| %s | %d | %d | %d | %d |\n", ARMS[a], nrow(sub),
      sum(sub$status == "ERROR", na.rm = TRUE),
      sum(sub$status == "TIMEOUT", na.rm = TRUE),
      sum(is.finite(sub$rel_frob)))
}
say("\n")

## ------------------------------------------------------------ 1. crossover
say("## 1. Crossover: at what n does VA become faster than Laplace?\n\n")
say("Median seconds by arm x n x p (pooled over family, seed):\n\n")
say("| n | p | gtmb_gh | gtmb_jj | gllvm_va | gtmb_laplace | VA/Laplace (gh) |\n")
say("|---:|---:|---:|---:|---:|---:|---:|\n")
for (pp in sort(unique(d$p))) {
  for (nn in sort(unique(d$n))) {
    sub <- d[d$n == nn & d$p == pp, ]
    m_gh <- med(sub$seconds[sub$arm == "gtmb_gh"])
    m_jj <- med(sub$seconds[sub$arm == "gtmb_jj"])
    m_va <- med(sub$seconds[sub$arm == "gllvm_va"])
    m_lp <- med(sub$seconds[sub$arm == "gtmb_laplace"])
    ratio <- if (is.finite(m_gh) && is.finite(m_lp) && m_lp > 0) m_gh / m_lp else NA
    say("| %d | %d | %s | %s | %s | %s | %s |\n", nn, pp,
        ifelse(is.na(m_gh), "NA", sprintf("%.1f", m_gh)),
        ifelse(is.na(m_jj), "NA", sprintf("%.1f", m_jj)),
        ifelse(is.na(m_va), "NA", sprintf("%.1f", m_va)),
        ifelse(is.na(m_lp), "NA", sprintf("%.1f", m_lp)),
        ifelse(is.na(ratio), "NA", sprintf("%.2f", ratio)))
  }
}
say("\nRatio column is gtmb_gh seconds / gtmb_laplace seconds; <1 means our VA is faster.\n\n")

## ------------------------------------------------------- 2. scaling exponent
say("## 2. Scaling exponents (log-log OLS slope of median seconds vs n, and vs p)\n\n")
fit_exponent <- function(x, y) {
  ok <- is.finite(x) & is.finite(y) & x > 0 & y > 0
  ## the design has only 2 distinct p values, so a >=3 threshold silently
  ## NA'd every p-exponent; >=2 gives the (deterministic, noisier) 2-point
  ## slope, which is still the honest answer for a 2-level factor.
  if (sum(ok) < 2) return(NA_real_)
  coef(lm(log(y[ok]) ~ log(x[ok])))[2]
}
say("| arm | exponent vs n (p pooled) | exponent vs p (n pooled) |\n|---|---:|---:|\n")
for (a in names(ARMS)) {
  sub <- d[d$arm == a & is.finite(d$seconds), ]
  agg_n <- aggregate(seconds ~ n, sub, median)
  agg_p <- aggregate(seconds ~ p, sub, median)
  en <- fit_exponent(agg_n$n, agg_n$seconds)
  ep <- fit_exponent(agg_p$p, agg_p$seconds)
  say("| %s | %s | %s |\n", ARMS[a],
      ifelse(is.na(en), "NA", sprintf("%.2f", en)),
      ifelse(is.na(ep), "NA", sprintf("%.2f", ep)))
}
say("\n")

## --------------------------------------------------- 3. accuracy at scale
say("## 3. Accuracy/reliability at scale (relative Frobenius error vs true Sigma)\n\n")
say("| arm | n | median rel_frob | median attenuation |\n|---|---:|---:|---:|\n")
for (a in names(ARMS)) {
  for (nn in sort(unique(d$n))) {
    sub <- d[d$arm == a & d$n == nn, ]
    say("| %s | %d | %s | %s |\n", ARMS[a], nn,
        ifelse(is.finite(med(sub$rel_frob)), sprintf("%.3f", med(sub$rel_frob)), "NA"),
        ifelse(is.finite(med(sub$attenuation)), sprintf("%.3f", med(sub$attenuation)), "NA"))
  }
}
say("\n")

say("## 4. Raw status table\n\n")
say("```\n")
tab <- table(d$arm, d$status, useNA = "ifany")
say("%s\n", paste(capture.output(print(tab)), collapse = "\n"))
say("```\n")

cat("Wrote", out, "\n")
