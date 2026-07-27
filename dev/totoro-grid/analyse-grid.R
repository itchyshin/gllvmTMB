#!/usr/bin/env Rscript
## Analysis of the Totoro wide grid: agreement/divergence map + runtime scaling.
## Run locally on the rsync'd results (D-50: results never leave local disk).
##
## Reads dev/totoro-grid/results/grid.csv and writes RESULTS.md next to it.

args <- commandArgs(trailingOnly = TRUE)
here <- if (length(args)) args[1] else "dev/totoro-grid/results"
d <- read.csv(file.path(here, "grid.csv"), stringsAsFactors = FALSE)
out <- file.path(here, "RESULTS.md")
say <- function(...) cat(sprintf(...), file = out, append = TRUE)
cat("", file = out)

ARMS <- c(gtmb_gh = "gllvmTMB GH-VA (H=15)", gtmb_jj = "gllvmTMB JJ-VA",
          gllvm_va = "gllvm VA (=JJ for binomial, exact for Poisson)",
          gllvm_eva = "gllvm EVA (Taylor)", gtmb_laplace = "gllvmTMB Laplace")

med <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)
pct <- function(x) sprintf("%.0f%%", 100 * mean(x, na.rm = TRUE))

say("# Wide-condition comparison — Totoro grid\n\n")
say("Design: n x p x q x family x seed; arms named by ALGEBRA, not package flag.\n")
say("Compute: Totoro, 64 workers, OPENBLAS_NUM_THREADS=1. Results local (D-50).\n\n")
say("Cells attempted: %d rows, %d cells.\n\n", nrow(d),
    nrow(unique(d[c("family","n","p","q","seed")])))

## ------------------------------------------------------- 0. completeness ---
say("## 0. What ran, and what did not\n\n")
say("| arm | rows | ERROR | non-finite objective | usable Sigma_B |\n|---|---:|---:|---:|---:|\n")
for (a in names(ARMS)) {
  s <- d[d$arm == a, ]
  if (!nrow(s)) { say("| `%s` | 0 | - | - | - |\n", a); next }
  say("| `%s` | %d | %d | %d | %d |\n", a, nrow(s),
      sum(s$status == "ERROR", na.rm = TRUE),
      sum(!is.finite(s$objective)), sum(is.finite(s$rel_frob)))
}
say("\nAn arm missing rows in a cell is a FAILURE recorded as a row, not a hole.\n\n")

## ------------------------------------------- 1. agreement: objective pairs --
say("## 1. Agreement map — do implementations of the SAME algebra agree?\n\n")
w <- reshape(d[c("family","n","p","q","seed","arm","objective")],
             idvar = c("family","n","p","q","seed"),
             timevar = "arm", direction = "wide")
names(w) <- sub("^objective\\.", "", names(w))
pair <- function(a, b, lbl, fam = NULL) {
  s <- if (is.null(fam)) w else w[w$family == fam, ]
  if (!all(c(a, b) %in% names(s))) return(invisible())
  ok <- is.finite(s[[a]]) & is.finite(s[[b]])
  if (!any(ok)) return(invisible())
  rel <- abs(s[[a]][ok] - s[[b]][ok]) / pmax(abs(s[[b]][ok]), 1e-12)
  say("- **%s** (n=%d): median rel. diff %.3g, max %.3g, agree <1%%: %s\n",
      lbl, sum(ok), median(rel), max(rel), pct(rel < 0.01))
}
pair("gtmb_jj", "gllvm_va", "ours JJ vs gllvm VA (same algebra, binomial)", "bernoulli")
pair("gtmb_gh", "gllvm_va", "ours GH vs gllvm VA (same algebra, Poisson)", "poisson")
pair("gtmb_gh", "gtmb_jj", "ours GH vs ours JJ (SAME engine, different bound)", "bernoulli")
say("\n")

## --------------------------------------------------- 2. bound ordering -----
say("## 2. Bound ordering — GH must sit ABOVE JJ (tighter bound scores higher)\n\n")
b <- w[w$family == "bernoulli", ]
if (all(c("gtmb_gh","gtmb_jj") %in% names(b))) {
  ok <- is.finite(b$gtmb_gh) & is.finite(b$gtmb_jj)
  gap <- b$gtmb_gh[ok] - b$gtmb_jj[ok]
  say("GH - JJ: median %+.3f nats, min %+.3f, max %+.3f. GH above JJ in %s of %d cells.\n\n",
      median(gap), min(gap), max(gap), pct(gap > 0), sum(ok))
  if (any(gap < 0)) say("**SIGN INVERSION in %d cells — a looser bound scored higher. Investigate.**\n\n",
                        sum(gap < 0))
}

## ------------------------------------------------ 3. recovery / divergence --
say("## 3. Divergence map — Sigma_B recovery by arm and size\n\n")
say("Relative Frobenius error vs known truth (lower better). ")
say("NOTE: `gtmb_laplace` Sigma_B may carry a link-implicit residual on its diagonal, ")
say("so its column is indicative, NOT like-for-like with the VA arms.\n\n")
for (fam in unique(d$family)) {
  say("### %s\n\n| n | p | q | %s |\n|---|---|---|%s|\n", fam,
      paste(names(ARMS), collapse = " | "),
      paste(rep("---", length(ARMS)), collapse = "|"))
  s <- d[d$family == fam, ]
  keys <- unique(s[c("n","p","q")]); keys <- keys[order(keys$n, keys$p, keys$q), ]
  for (i in seq_len(nrow(keys))) {
    k <- keys[i, ]
    cells <- s[s$n == k$n & s$p == k$p & s$q == k$q, ]
    vals <- vapply(names(ARMS), function(a) med(cells$rel_frob[cells$arm == a]), numeric(1))
    say("| %d | %d | %d | %s |\n", k$n, k$p, k$q,
        paste(ifelse(is.na(vals), "-", sprintf("%.3f", vals)), collapse = " | "))
  }
  say("\n")
}

## --------------------------------------------------- 4. silent failures ----
say("## 4. Silent failures — a clean flag on a broken fit\n\n")
say("A fit is DEGENERATE when rel_frob > 10 (loadings off by an order of magnitude+).\n\n")
say("| arm | fits with usable Sigma_B | degenerate | degenerate rate | reported OK anyway |\n|---|---:|---:|---:|---:|\n")
for (a in names(ARMS)) {
  s <- d[d$arm == a & is.finite(d$rel_frob), ]
  if (!nrow(s)) next
  deg <- s$rel_frob > 10
  clean <- grepl("pdHessTRUE|healthy|converged", s$status)
  say("| `%s` | %d | %d | %s | %d |\n", a, nrow(s), sum(deg), pct(deg), sum(deg & clean))
}
say("\nThe last column is the load-bearing one: a degenerate fit that reported a clean ")
say("status gives the user NO signal. That is worse than an honest failure label.\n\n")

## ------------------------------------------------------ 5. runtime scaling -
say("## 5. Runtime scaling\n\n")
say("Median seconds per fit. First-fit-in-session TMB compile is absorbed by the\n")
say("worker pool, so these are steady-state costs.\n\n")
for (fam in unique(d$family)) {
  say("### %s\n\n| n | p | q | %s |\n|---|---|---|%s|\n", fam,
      paste(names(ARMS), collapse = " | "),
      paste(rep("---", length(ARMS)), collapse = "|"))
  s <- d[d$family == fam, ]
  keys <- unique(s[c("n","p","q")]); keys <- keys[order(keys$n, keys$p, keys$q), ]
  for (i in seq_len(nrow(keys))) {
    k <- keys[i, ]
    cells <- s[s$n == k$n & s$p == k$p & s$q == k$q, ]
    vals <- vapply(names(ARMS), function(a) med(cells$seconds[cells$arm == a]), numeric(1))
    say("| %d | %d | %d | %s |\n", k$n, k$p, k$q,
        paste(ifelse(is.na(vals), "-", sprintf("%.2f", vals)), collapse = " | "))
  }
  say("\n")
}

## how does each arm scale with p?
say("### Scaling with species count p (median seconds, q=2, largest n)\n\n")
for (fam in unique(d$family)) {
  s <- d[d$family == fam & d$q == 2 & d$n == max(d$n), ]
  if (!nrow(s)) next
  say("**%s** — ", fam)
  for (a in names(ARMS)) {
    v <- vapply(sort(unique(s$p)), function(pp) med(s$seconds[s$arm == a & s$p == pp]), numeric(1))
    if (all(is.na(v))) next
    say("`%s`: %s; ", a, paste(sprintf("%.2f", v), collapse = " -> "))
  }
  say("\n\n")
}

cat(sprintf("Wrote %s\n", out))
