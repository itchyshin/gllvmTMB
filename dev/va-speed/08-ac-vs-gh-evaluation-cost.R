## S6 (narrowed) -- per-EVALUATION cost of the AC tier vs the GH tier.
##
## WHY THIS AND NOT FULL FITS. Full-fit wall-clock confounds two things: the cost
## per objective evaluation (which is what swapping the evaluator changes) and the
## number of evaluations the optimiser needs (which it does not, directly). The
## substitution's whole claim is about the FIRST. Isolating it is both the honest
## measurement and a reliable one -- repeated attempts to run full fits at the
## reference cell were killed mid-fit with no error, so a fit-level number is not
## available from this session at all.
##
## What this does NOT measure, stated so nobody reads it as more than it is:
##   * NOT wall-clock for a whole fit, so it does NOT test the arc's acceptance
##     gate (a) "within a small factor of gllvm's 0.70 s";
##   * NOT accuracy -- the binding falsifier (rel_frob <= 0.298) is still OWED;
##   * NOT a comparison with gllvm, whose evaluator is not callable this way.
##
## DISCIPLINE: interleaved. Each replicate calls GH and AC back to back and the
## ORDER ALTERNATES, so machine drift is spread across both arms rather than
## landing on one. A sequential pass is the exact error that inflated the July
## L-BFGS-B claim ~3x and forced its retraction.
## Results LOCAL (D-50).
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

NTR <- 6L
CELLS <- list(c(N = 100L, T = 10L, q = 1L),
              c(N = 250L, T = 20L, q = 1L))
REPS <- 12L

build_pair <- function(N, T0, q, H = 15L) {
  set.seed(42L)
  lam <- matrix(rnorm(T0 * q, 0, 0.8), T0, q); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N * q), N, q)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y   <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  d   <- data.frame(y = y, unit = rep(seq_len(N), times = T0),
                    trait = rep(seq_len(T0), each = N))
  X   <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))
  v <- gllvmTMB:::.va_r3_validate_data(
    y = d$y, n_trials = rep(NTR, nrow(d)), X = X, unit_id = d$unit,
    trait_id = d$trait, q = q, family = "binomial_probit", link = "probit",
    unique = TRUE)
  list(gh = gllvmTMB:::.va_r3_make_objective(v, H = H, eval_method = "gh"),
       ac = gllvmTMB:::.va_r3_make_objective(v, H = H, eval_method = "ac"))
}

out <- list()
for (cl in CELLS) {
  N <- cl[["N"]]; T0 <- cl[["T"]]; q <- cl[["q"]]
  cat(sprintf("\n=== cell N=%d T=%d q=%d  (H=15) ===\n", N, T0, q))
  ob <- build_pair(N, T0, q)
  p  <- ob$gh$par
  stopifnot(identical(length(p), length(ob$ac$par)))

  ## sanity: same parameter vector, and AC really is the looser bound
  v_gh <- ob$gh$fn(p); v_ac <- ob$ac$fn(p)
  cat(sprintf("  objective at start:  GH %.4f   AC %.4f   (AC-GH = %+.4f, must be > 0)\n",
              v_gh, v_ac, v_ac - v_gh))

  tf <- tg <- matrix(NA_real_, REPS, 2, dimnames = list(NULL, c("gh", "ac")))
  for (r in seq_len(REPS)) {
    ord <- if (r %% 2L == 1L) c("gh", "ac") else c("ac", "gh")   # interleave
    for (arm in ord) {
      o <- ob[[arm]]
      t0 <- proc.time()[["elapsed"]]; invisible(o$fn(p))
      tf[r, arm] <- proc.time()[["elapsed"]] - t0
      t0 <- proc.time()[["elapsed"]]; invisible(o$gr(p))
      tg[r, arm] <- proc.time()[["elapsed"]] - t0
    }
  }
  mf <- apply(tf, 2, median); mg <- apply(tg, 2, median)
  cat(sprintf("  fn()  median: GH %8.2f ms   AC %8.2f ms   speedup %5.2fx\n",
              mf[["gh"]] * 1000, mf[["ac"]] * 1000, mf[["gh"]] / mf[["ac"]]))
  cat(sprintf("  gr()  median: GH %8.2f ms   AC %8.2f ms   speedup %5.2fx\n",
              mg[["gh"]] * 1000, mg[["ac"]] * 1000, mg[["gh"]] / mg[["ac"]]))
  ## gr dominates the profile (65.1% of nlminb vs fn's 33.9%), so weight by that
  wt_gh <- 0.651 * mg[["gh"]] + 0.339 * mf[["gh"]]
  wt_ac <- 0.651 * mg[["ac"]] + 0.339 * mf[["ac"]]
  cat(sprintf("  profile-weighted (0.651*gr + 0.339*fn): speedup %5.2fx\n",
              wt_gh / wt_ac))
  out[[length(out) + 1]] <- data.frame(
    N = N, T = T0, q = q,
    fn_gh_ms = mf[["gh"]] * 1000, fn_ac_ms = mf[["ac"]] * 1000,
    gr_gh_ms = mg[["gh"]] * 1000, gr_ac_ms = mg[["ac"]] * 1000,
    fn_speedup = mf[["gh"]] / mf[["ac"]], gr_speedup = mg[["gh"]] / mg[["ac"]],
    weighted_speedup = wt_gh / wt_ac)
}

res <- do.call(rbind, out)
cat("\n================ SUMMARY ================\n")
print(res, row.names = FALSE, digits = 4)

## Amdahl: if GH is ~75% of fit time and the evaluator gets S times faster, the
## whole-fit bound is 1 / (0.25 + 0.75/S) -- ASSUMING iteration count is unchanged,
## which this script does NOT establish.
s <- res$weighted_speedup[nrow(res)]
cat(sprintf("\nAmdahl bound on WHOLE-FIT gain at evaluator speedup %.2fx (GH = 75%%%%):\n", s))
cat(sprintf("  1 / (0.25 + 0.75/%.2f) = %.2fx  -- ASSUMES equal iteration counts, UNVERIFIED\n",
            s, 1 / (0.25 + 0.75 / s)))
saveRDS(res, "dev/va-speed/08-eval-cost.rds")   # gitignored, D-50
cat("\nEVAL_COST_DONE\n")
