## Split the 25x: is it CONDITIONING (iteration count) or EVALUATION COST?
##
## Arc E measured ours-AC at ~25x gllvm-VA's wall clock on a matched cell, 0/12.
## That contradicts ledger claim 20 (STANDS): gllvm spends ~57% of its outer
## parameters numerically rediscovering the A_i closed form we exploit. We
## removed more than half their parameters and are still an order of magnitude
## slower, so something between the theory and the clock is missing.
##
## The split determines the fix and nothing else does:
##   many more ITERATIONS at similar per-iteration cost -> CONDITIONING.
##       Matches 21-WHY-GLLVM-IS-FAST.md ("objective conditioned so plain BFGS
##       converges in far fewer") and the named gap in claim 30 (their loadings
##       diagonal is pinned with a separate scale; ours is unconstrained).
##   similar iterations at much higher PER-ITERATION cost -> EVALUATION COST,
##       and conditioning work would be wasted effort.
##
## Same DGP as 18-four-way.R so the numbers are comparable to Arc E.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(gllvm) })

N0 <- 120L; T0 <- 10L; q0 <- 1L; NTR <- 6L; PSI <- 0.6; H0 <- 15L
SEEDS <- 1:3

mk <- function(seed) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N0 * q0), N0, q0)
  u   <- matrix(rnorm(N0 * T0, 0, PSI), N0, T0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+") + u
  Y   <- matrix(rbinom(N0 * T0, NTR, pnorm(eta)), N0, T0)
  list(Y = Y, lam = lam)
}
tm <- function(e) { t0 <- proc.time()[["elapsed"]]; v <- force(e); list(s = proc.time()[["elapsed"]] - t0, v = v) }

## A NULL slot yields a ZERO-LENGTH value, not an error, so tryCatch alone does
## not protect data.frame() from it. Coerce to exactly one element.
sc1 <- function(x, na) {
  v <- suppressWarnings(tryCatch(x, error = function(e) na))
  if (is.null(v) || length(v) != 1L) na else v
}

rows <- list()
for (s in SEEDS) {
  d <- mk(s)

  ## --- gllvm VA -----------------------------------------------------------
  g <- tm(tryCatch(gllvm::gllvm(y = d$Y, family = binomial(link = "probit"),
                                num.lv = q0, method = "VA", Ntrials = NTR,
                                seed = s, trace = FALSE), error = function(e) NULL))
  g_it <- if (!is.null(g$v)) {
    ## gllvm stores optimiser output; try the common slots, else NA
    sc1(as.integer(g$v$optim.out$counts[["function"]]), NA_integer_)
  } else NA_integer_

  ## --- ours, AC + collapse -------------------------------------------------
  long <- expand.grid(site = seq_len(N0), trait_idx = seq_len(T0))
  o <- tm(tryCatch(.va_r3_fit(
    y = as.integer(d$Y), n_trials = rep(NTR, N0 * T0),
    X = matrix(1, N0 * T0, 1L),
    unit_id = long$site, trait_id = long$trait_idx, q = q0,
    family = "binomial_probit", eval_method = "ac",
    collapse_variational_cov = TRUE, unique = FALSE
  ), error = function(e) NULL))
  o_it <- sc1(as.integer(o$v$iterations), NA_integer_)
  o_st <- sc1(as.character(o$v$status), NA_character_)

  rows[[length(rows) + 1L]] <- data.frame(
    seed = s,
    gllvm_s = sc1(g$s, NA_real_), gllvm_iter = g_it,
    ours_s = sc1(o$s, NA_real_), ours_iter = o_it, ours_status = o_st,
    stringsAsFactors = FALSE
  )
  cat(sprintf("seed %d  gllvm %.2fs (iter %s)   ours-AC %.2fs (iter %s, %s)\n",
              s, g$s, g_it, o$s, o_it, o_st))
}
r <- do.call(rbind, rows)
cat("\n=== SPLIT ===\n")
cat(sprintf("median wall:      gllvm %.3fs   ours %.3fs   ratio %.1fx\n",
            median(r$gllvm_s), median(r$ours_s), median(r$ours_s)/median(r$gllvm_s)))
if (all(!is.na(r$gllvm_iter)) && all(!is.na(r$ours_iter))) {
  cat(sprintf("median iters:     gllvm %.0f      ours %.0f      ratio %.1fx\n",
              median(r$gllvm_iter), median(r$ours_iter), median(r$ours_iter)/median(r$gllvm_iter)))
  cat(sprintf("per-iteration ms: gllvm %.2f    ours %.2f    ratio %.1fx\n",
              1000*median(r$gllvm_s)/median(r$gllvm_iter),
              1000*median(r$ours_s)/median(r$ours_iter),
              (median(r$ours_s)/median(r$ours_iter))/(median(r$gllvm_s)/median(r$gllvm_iter))))
} else cat("iteration counts unavailable on at least one side -- see raw rows\n")
print(r, row.names = FALSE)
saveRDS(r, "/tmp/split25.rds")
