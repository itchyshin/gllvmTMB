## ARC A1 — reconcile the two contradictory `profile_variational` measurements, and find
## the crossover. This is a MEASUREMENT script; it changes no default.
##
## THE CONTRADICTION
##   PROFILE.md Q2  (structured phylo tier, gaussian_anchor, outer par = 34*N):
##     profile=TRUE WINS 39x at N=1000; ~N^0.9 vs ~N^2.1. At N=1000, 99.83% of wall-clock is
##     nlminb's OWN quasi-Newton bookkeeping and only 0.17% is genuine fn()/gr().
##   lane-2 handover, Gotchas (plain latent tier):
##     profile=TRUE LOSES -- 27.7s vs 2.75s at N=250; 128.5s vs 29.1s at N=1000.
##   va-speed-arc handover:
##     a structured fit exceeding 3600s WITH profile=TRUE -- "does not sit easily beside the
##     profile's N^0.9 result. Reproduce both before building on either."
##
## HYPOTHESIS (to TEST, not assume): profiling pays exactly when the OUTER parameter vector it
## removes is large relative to what remains. `nlminb` (PORT) carries a DENSE packed
## quasi-Newton approximation of size p*(p+1)/2, so its own bookkeeping grows ~p^2 while the
## profiled route's inner sparse Newton solve grows ~linearly in the same block. There should
## therefore be a CROSSOVER in p, not a universal winner -- which would make the right fix an
## ADAPTIVE default keyed on p, not a flag flip.
##
## WHAT THIS SCRIPT MUST ESTABLISH, in order:
##   (1) both published results REPRODUCE on this machine;
##   (2) the two routes reach the SAME OBJECTIVE (if they do not, this is not a speed question
##       at all and the arc stops);
##   (3) where the crossover in outer-parameter count actually is.
##
## Usage: Rscript 51-profile-variational-crossover.R <tier: plain|structured> <N> <tag>
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

`%||%` <- function(a, b) if (is.null(a)) b else a
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())

args <- commandArgs(trailingOnly = TRUE)
TIER <- args[[1]]
N0   <- as.integer(args[[2]])
TAG  <- args[[3]]
T0   <- 10L
Q0   <- 2L
OUT  <- sprintf("dev/va-speed/51-crossover-%s.rds", TAG)

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(
      readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}

## gaussian_anchor deliberately: it has a CLOSED-FORM expectation, so there is no GH
## quadrature cost to confound the routing question. This is the same choice PROFILE.md made.
mk <- function(N) {
  set.seed(20260803L)
  lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- eta + matrix(rnorm(N * T0, 0, 0.5), N, T0)
  d <- data.frame(y = as.numeric(t(y)),
                  trait = factor(rep(seq_len(T0), times = N)),
                  unit  = factor(rep(seq_len(N),  each = T0)))
  d
}

d <- mk(N0)
X <- unname(stats::model.matrix(~ 0 + trait, data = d))

fit_one <- function(profile) {
  t0 <- proc.time()[["elapsed"]]
  f <- try(do.call(gllvmTMB:::.va_r3_fit, list(
    y = d$y, n_trials = rep(1L, nrow(d)), X = X,
    unit_id = as.integer(d$unit), trait_id = as.integer(d$trait),
    q = Q0, family = "gaussian_anchor", link = "identity",
    unique = FALSE, psi = FALSE, estimate_gaussian_sd = TRUE,
    n_starts = 1L, profile_variational = profile,
    control = list(eval.max = 2000L, iter.max = 2000L)
  )), silent = TRUE)
  el <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "try-error"))
    return(list(secs = el, err = conditionMessage(attr(f, "condition")),
                outer_par = NA_integer_, objective = NA_real_, status = "ERROR"))
  ## The load-bearing number: how many coordinates does the OUTER optimiser actually carry?
  outer_par <- tryCatch(length(f$objective$par), error = function(e) NA_integer_)
  list(secs = el, err = NA_character_, outer_par = outer_par,
       objective = f$best$objective %||% NA_real_,
       status = as.character(f$status %||% NA_character_))
}

cat(sprintf("== %s tier, N=%d, T=%d, q=%d, gaussian_anchor (no GH) — load %.2f ==\n",
            TIER, N0, T0, Q0, loadavg())); flush.console()

## Untimed warm-up so the TMB compile never lands inside a timed arm.
invisible(try(fit_one(FALSE), silent = TRUE))
cat("warm-up done (UNTIMED)\n"); flush.console()

joint   <- fit_one(FALSE)
cat(sprintf("joint   (profile=FALSE): %8.2fs  outer_par=%s  obj=%s  %s\n",
            joint$secs, joint$outer_par, format(joint$objective), joint$status)); flush.console()

profiled <- fit_one(TRUE)
cat(sprintf("profiled(profile=TRUE ): %8.2fs  outer_par=%s  obj=%s  %s\n",
            profiled$secs, profiled$outer_par, format(profiled$objective), profiled$status))

## (2) The routes MUST agree on the objective. If they do not, this is not a speed question.
obj_gap <- abs(joint$objective - profiled$objective)
rel_gap <- obj_gap / max(1, abs(joint$objective))
cat(sprintf("\nOBJECTIVE AGREEMENT: |gap| = %.3g   relative = %.3g   %s\n",
            obj_gap, rel_gap,
            if (is.finite(rel_gap) && rel_gap < 1e-6) "OK -- same optimum"
            else "*** ROUTES DISAGREE -- speed comparison is INVALID ***"))

speedup <- joint$secs / profiled$secs
cat(sprintf("SPEEDUP (joint/profiled): %.2fx  -> profiling %s here\n",
            speedup, if (speedup > 1) "WINS" else "LOSES"))
cat(sprintf("OUTER PAR REMOVED: %s -> %s\n", joint$outer_par, profiled$outer_par))

saveRDS(list(tier = TIER, N = N0, T = T0, q = Q0, tag = TAG,
             joint = joint, profiled = profiled,
             speedup = speedup, obj_gap = obj_gap, rel_gap = rel_gap,
             loadavg = loadavg()), OUT)
cat(sprintf("\n== %s DONE -> %s ==\n", TAG, OUT))
