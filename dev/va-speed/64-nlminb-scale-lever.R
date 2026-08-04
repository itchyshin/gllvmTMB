#!/usr/bin/env Rscript
## Arc D -- the ONE cheap speed lever that is reachable without new plumbing.
##
## Scope correction (2026-08-04): the handover listed five "cheap untested
## levers". Four are NOT plumbed and are therefore build-then-measure, not
## measure:
##   sdreport knobs (skip.delta.method / ignore.parm.uncertainty) -- zero hits in R/
##   sdmTMB multiphase                                            -- zero hits in R/
##   optimHess polish                                             -- zero hits in R/ (one comment)
##   gllvm inner.control                                          -- a COMPARATOR's knob, not ours
## Only `nlminb(scale=)` is reachable today: gllvmTMBcontrol(optArgs=) whitelists
## `scale` (R/fit-multi.R:5196) and passes it to nlminb (:5211).
##
## ARMS. The point of arm B is that it must be a NULL result. `scale = 1` is
## nlminb's own default, so it must reproduce the baseline. If it does not, the
## pass-through is doing something other than what it claims, and every other
## number here is untrustworthy. A benchmark without a null control cannot tell
## "the lever works" from "the harness moved something".
##
## Usage: Rscript 64-nlminb-scale-lever.R <N> <SEED> <tag>
## Env:   GLLVMTMB_LANE_DIR (defaults to the local worktree)

## This lever touches only existing public API (`gllvmTMBcontrol(optArgs=)`),
## so the INSTALLED package is a valid target and avoids a load_all() compile on
## a remote box. Set GLLVMTMB_USE_INSTALLED=1 to take that route.
if (identical(Sys.getenv("GLLVMTMB_USE_INSTALLED"), "1")) {
  suppressMessages(library(gllvmTMB))
  if (!dir.exists("dev/va-speed")) dir.create("dev/va-speed", recursive = TRUE)
} else {
  setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
  suppressMessages(devtools::load_all("."))
}

args <- commandArgs(trailingOnly = TRUE)
N    <- if (length(args) >= 1) as.integer(args[1]) else 250L
SEED <- if (length(args) >= 2) as.integer(args[2]) else 1L
TAG  <- if (length(args) >= 3) args[3] else "local"

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

T0 <- 8L
make_data <- function(seed) {
  set.seed(seed)
  g <- expand.grid(site = seq_len(N), trait_idx = seq_len(T0))
  g$trait  <- factor(paste0("t", g$trait_idx))
  g$site_f <- factor(g$site)
  u <- rnorm(N, 0, 0.8)
  g$value <- (g$trait_idx * 0.4) + u[g$site] + rnorm(nrow(g), 0, 0.5)
  g
}

fit_arm <- function(dat, opt_args) {
  t0 <- proc.time()[["elapsed"]]
  f <- try(gllvmTMB(
    value ~ 0 + trait + (1 | site_f),
    data = dat, family = gaussian(), unit = "site_f",
    control = gllvmTMBcontrol(optArgs = opt_args)
  ), silent = TRUE)
  el <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "try-error")) {
    return(list(sec = NA_real_, conv = NA_integer_, ll = NA_real_,
                status = "fit_error", npar = NA_integer_))
  }
  list(
    sec    = el,
    conv   = f$opt$convergence,
    ll     = -f$opt$objective,
    ## STATUS BESIDE THE RESULT (this lane's standing rule): a timing number
    ## from a fit that did not converge measures giving up, not working.
    status = if (identical(f$opt$convergence, 0L)) "converged" else "NOT_CONVERGED",
    npar   = length(f$opt$par)
  )
}

dat <- make_data(SEED)

## npar is needed to size the `scale` vector; take it from an untimed warm-up
## that also warms the DLL so arm A is not charged for compilation.
warm <- fit_arm(dat, list())
npar <- warm$npar
if (is.na(npar)) stop("warm-up fit failed; nothing measurable")

arms <- list(
  A_baseline    = list(),
  B_scale_one   = list(scale = rep(1, npar)),          # NULL CONTROL
  C_scale_tenth = list(scale = rep(0.1, npar)),
  D_scale_ten   = list(scale = rep(10, npar))
)

REPS <- 3L
rows <- list()
for (nm in names(arms)) {
  secs <- numeric(REPS); st <- character(REPS); lls <- numeric(REPS)
  for (r in seq_len(REPS)) {
    res <- fit_arm(dat, arms[[nm]])
    secs[r] <- res$sec; st[r] <- res$status; lls[r] <- res$ll
  }
  rows[[nm]] <- data.frame(
    arm = nm, N = N, seed = SEED, npar = npar,
    median_sec = median(secs),
    status = paste(unique(st), collapse = ","),
    n_converged = sum(st == "converged"),
    logLik = median(lls),
    stringsAsFactors = FALSE
  )
}
out <- do.call(rbind, rows)

## The null control decides whether anything else here can be believed.
base_ll <- out$logLik[out$arm == "A_baseline"]
ctrl_ll <- out$logLik[out$arm == "B_scale_one"]
out$ll_matches_baseline <- isTRUE(all.equal(out$logLik, rep(base_ll, nrow(out)),
                                            tolerance = 1e-8))
null_control_ok <- isTRUE(all.equal(base_ll, ctrl_ll, tolerance = 0))

cat("\n=== nlminb(scale=) lever, N=", N, " seed=", SEED, " tag=", TAG, " ===\n", sep = "")
print(out[, c("arm", "median_sec", "status", "n_converged", "logLik")])
cat("\nNULL CONTROL (scale=1 must equal baseline exactly): ",
    if (null_control_ok) "PASS" else "*** FAIL -- distrust every row above ***", "\n", sep = "")
cat("All arms same logLik (estimates did not move): ",
    if (all(out$ll_matches_baseline)) "yes" else "NO -- this lever MOVES ESTIMATES, not free", "\n",
    sep = "")

saveRDS(out, sprintf("dev/va-speed/64-scale-lever-%s-N%d-s%d.rds", TAG, N, SEED))
cat("\nwrote dev/va-speed/64-scale-lever-", TAG, "-N", N, "-s", SEED, ".rds\n", sep = "")
