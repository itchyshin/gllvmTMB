## OWED step 2 (handover 2026-08-03-claude-handover-va-lane2): settle whether VA
## scales superlinearly. Two harnesses questioned the arc's founding premise --
## the hybrid ladder measured VA growing 14x for a 5x N increase (~N^1.6), and the
## coverage pilot had one VA fit exceed 350 s at n=5000 where n=400 took 2.44 s.
##
## DESIGN: arms are PAIRED WITHIN A PROCESS on the SAME dataset (VA then LA), which
## is the lesson from the 12-seed head-to-head -- pairing cancels box load, so the
## VA/LA RATIO is robust even if the absolute seconds are not. Cells are chosen to
## match 41-profile-ladder.R's q=2 arm exactly (N in {250,1000,2500}, q=2, T=20,
## binomial-probit, NTR=6), so the LA arm here can be cross-checked against the
## already-measured 41-ladder-N*_q2.rds totals.
##
## n_starts=1L for VA: this is an ENGINE-vs-ENGINE scaling measurement, and
## multistart is a separate, already-measured ~3.88x multiplier (PROFILE.md).
## H is left at the shipped formal default and the RESOLVED order is recorded, so
## the quadrature actually used is auditable rather than assumed.
##
## Results are written incrementally (after VA, again after LA) so a cell that is
## killed or never finishes still leaves a RIGHT-CENSORED observation on disk --
## a censored point still bounds the exponent from below, which is what the
## superlinear question needs.
##
## H is an explicit argument (default 61 = the shipped formal default) so the
## H=61-vs-H=15 confound is MEASURED rather than argued: GH cost is linear in H,
## and the arc's own PROFILE.md profiled H=15 while a user gets H=61.
##
## Usage: Rscript 43-va-vs-la-ladder.R <N0> <SEED> <cell_tag> [H]
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

args <- commandArgs(trailingOnly = TRUE)
N0 <- as.integer(args[[1]])
SEED <- as.integer(args[[2]])
CELL_TAG <- args[[3]]
H_ARG <- if (length(args) >= 4L) as.integer(args[[4]]) else 61L

`%||%` <- function(a, b) if (is.null(a)) b else a

LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2")
setwd(LANE)
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())

Q0 <- 2L; T0 <- 20L; NTR <- 6L
OUT <- sprintf("dev/va-speed/43-vala-%s.rds", CELL_TAG)

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(
      strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}

## Same DGP as 41-profile-ladder.R::mk() so the LA arm is comparable to the
## already-measured ladder cells.
mk <- function(seed, N, Q) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q, 0, 0.8), T0, Q); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q), N, Q)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  list(
    d = data.frame(y = y, succ = y, fail = NTR - y,
                   unit = factor(rep(seq_len(N), times = T0)),
                   trait = factor(rep(seq_len(T0), each = N))),
    lam = lam
  )
}

run_la <- function(d, Q) gllvmTMB::gllvmTMB(
  cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q, unique = FALSE),
  data = d, family = binomial(link = "probit"), unit = "unit")

run_va <- function(d, Q) {
  Xva <- unname(stats::model.matrix(~ 0 + trait, data = d))
  do.call(gllvmTMB:::.va_r3_fit, list(
    y = d$succ, n_trials = rep(NTR, nrow(d)), X = Xva,
    unit_id = as.integer(d$unit), trait_id = as.integer(d$trait),
    q = Q, family = "binomial_probit", link = "probit",
    unique = FALSE, psi = FALSE, H = H_ARG,
    n_starts = 1L,
    control = list(eval.max = 2000L, iter.max = 2000L)
  ))
}

res <- list(cell = CELL_TAG, N0 = N0, Q0 = Q0, T0 = T0, NTR = NTR, seed = SEED,
            H_requested = H_ARG,
            va_s = NA_real_, la_s = NA_real_,
            va_censored = TRUE, la_censored = TRUE,
            va_status = NA_character_, va_H = NA_integer_,
            va_eval_method = NA_character_, va_iters = NA_integer_,
            la_iters = NA_integer_, la_conv = NA_integer_,
            load_pre_va = NA_real_, load_pre_la = NA_real_,
            started = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
saveRDS(res, OUT)

cat(sprintf("== cell %s: N=%d q=%d T=%d seed=%d start %s ==\n",
            CELL_TAG, N0, Q0, T0, SEED, format(Sys.time(), "%H:%M:%S"))); flush.console()

## ---- untimed warm-up: pays the one-time TMB DLL/tape cost for BOTH engines ----
wu <- mk(999L, 40L, Q0)$d
tw <- proc.time()[["elapsed"]]
invisible(try(run_va(wu, Q0), silent = TRUE))
invisible(try(run_la(wu, Q0), silent = TRUE))
cat(sprintf("warm-up done (%.1fs, UNTIMED)\n", proc.time()[["elapsed"]] - tw)); flush.console()

dat <- mk(SEED, N0, Q0)
d1 <- dat$d

## ---- VA arm ----
res$load_pre_va <- loadavg()
cat(sprintf("VA start %s (load %.2f)\n", format(Sys.time(), "%H:%M:%S"), res$load_pre_va)); flush.console()
t0 <- proc.time()[["elapsed"]]
va <- try(run_va(d1, Q0), silent = TRUE)
res$va_s <- proc.time()[["elapsed"]] - t0
if (!inherits(va, "try-error")) {
  res$va_censored <- FALSE
  res$va_status <- as.character(va$status %||% NA_character_)
  res$va_H <- as.integer(va$quadrature$order %||% NA_integer_)
  res$va_eval_method <- as.character(va$eval_method %||% NA_character_)
  res$va_iters <- as.integer(va$best$iterations %||% NA_integer_)
} else {
  res$va_status <- paste("ERROR:", conditionMessage(attr(va, "condition")))
  res$va_censored <- FALSE  # errored, not censored -- distinguish from "never finished"
}
cat(sprintf("VA done %.2fs status=%s H=%s method=%s\n",
            res$va_s, res$va_status, res$va_H, res$va_eval_method)); flush.console()
saveRDS(res, OUT)

## ---- LA arm (same dataset) ----
res$load_pre_la <- loadavg()
cat(sprintf("LA start %s (load %.2f)\n", format(Sys.time(), "%H:%M:%S"), res$load_pre_la)); flush.console()
t0 <- proc.time()[["elapsed"]]
la <- try(run_la(d1, Q0), silent = TRUE)
res$la_s <- proc.time()[["elapsed"]] - t0
if (!inherits(la, "try-error")) {
  res$la_censored <- FALSE
  res$la_iters <- as.integer(la$opt$iterations %||% NA_integer_)
  res$la_conv <- as.integer(la$opt$convergence %||% NA_integer_)
}
cat(sprintf("LA done %.2fs iters=%s conv=%s\n", res$la_s, res$la_iters, res$la_conv)); flush.console()

res$ratio_la_over_va <- res$la_s / res$va_s
res$finished <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
saveRDS(res, OUT)
cat(sprintf("== cell %s DONE  VA %.2fs  LA %.2fs  LA/VA %.2fx  %s ==\n",
            CELL_TAG, res$va_s, res$la_s, res$ratio_la_over_va,
            format(Sys.time(), "%H:%M:%S")))
