## SLICE D: is the Laplace/AGHQ crossover a function of T (traits per site),
## or is n=400-800 (measured only at T=4, see 04-n-ladder.R / 05-descend.csv) a
## coincidence of one row of the (T, n) surface?
##
## THE TWO PREDICTIONS BEING TESTED (both written before the run):
##   1. Laplace's error is O(1/T) (Breslow & Lin 1995 / Joe 2008 -- see
##      07-prior-art-crossover.md) -- it should SHRINK as T grows and vanish for
##      large T. AGHQ's small-n bias should be governed by TOTAL information (n*T
##      observations feeding one q=1 latent factor per site), so it should also
##      improve with T at fixed n, though via a different mechanism (variance,
##      not integration bias). Whichever moves faster decides where -- or
##      whether -- the crossover sits for a given T.
##   2. Direct test of the O(1/T) claim itself: at fixed large n=800, Laplace's
##      median ratio should move toward 1.000 as T grows from 2 to 16. If it does
##      NOT, the theoretical basis for routing the AGHQ/Laplace choice on T is
##      wrong, and that must be reported loudly, not smoothed over.
##
## DGP: byte-identical convention to 04-n-ladder.R / 05-descend.csv (same repo,
## same evidence trail) --
##   set.seed(seed); Lt <- matrix(rnorm(p*q,0,lam_sd),p,q); u <- matrix(rnorm(n*q),n,q)
##   b <- rnorm(p,0.3,0.4); eta <- sweep(u %*% t(Lt),2,b,"+")
##   Y <- matrix(rbinom(n*p,1,plogis(eta)),n,p)
## lam_sd = 1.2, q = 1, k = 9 (AGHQ), k = 1 IS Laplace exactly (Liu & Pierce 1994).
##
## GRID, AS SPECIFIED: T in {2,4,8,16} x n in {50,100,200,400,800}, q=1, k=9,
## >=20 seeds. FEASIBILITY WAS BENCHMARKED FIRST (dev/aghq-evidence/12-bench*.log,
## not shipped -- ephemeral scratch), because a first blind attempt at the full
## corner (T=16, n=800) HUNG for >2 minutes on a single seed: nlminb's numerical
## gradient has npar = 2T dimensions (T intercepts + T loadings at q=1), so its
## per-gradient cost scales as npar * (per-eval cost, itself ~ n*T) = O(n*T^2).
## The bench also showed some small-(n,T) cells with genuine non-convergence
## inside 20s (T=8,n=50 Laplace: one seed hit an extreme-loading region and did
## not settle in the timeout window) -- these are the SAME degenerate-fit /
## quasi-separation regime the reference file's own header describes for small
## n, large T binary data, not a bug in the harness.
##
## DECISIONS MADE UNDER THE ~15-MINUTE BUDGET (stated, not hidden):
##   * A per-fit wall-clock cap of TIMEOUT_S seconds (R.utils::withTimeout) is
##     applied to EVERY fit, both engines. A fit that does not converge inside
##     the cap is recorded as NON-CONVERGENT (NA ratio), not silently retried
##     forever -- non-convergence is itself data about the (T,n) cell.
##   * SEEDS_PER_CELL seeds per cell (documented below; the task asked for
##     >=20 -- if the realised budget forced fewer, that reduction is reported,
##     not hidden).
##   * If any single (T,n) corner still threatens the whole design's runtime
##     even under the cap (i.e. most seeds there time out AND each timeout
##     consumes the full cap), it is DROPPED and named in the .md, per the
##     brief's explicit permission to drop "the most expensive corner."
##
## INCREMENTAL WRITE: every (T, n, seed) result is appended to
## 12-crossover-vs-T-INCREMENTAL.csv immediately after that seed's two fits, so
## a kill mid-run leaves a usable partial table.
##
## THE VACUOUSNESS CHECK (required by the brief): before trusting "non-converged
## fits are rare," the script deliberately breaks its own convergence-timeout
## logic once (forces TIMEOUT_S so low that EVERY fit must time out), confirms
## the run goes all-NA / all-FALSE (red), then restores the real cap. See the
## "BREAK-THEN-RESTORE" block below and the .md for what was observed.

source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressMessages(library(R.utils))

EVID_DIR <- "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence"
INC_CSV  <- file.path(EVID_DIR, "12-crossover-vs-T-INCREMENTAL.csv")
FULL_CSV <- file.path(EVID_DIR, "12-crossover-vs-T.csv")

mk <- function(n, p, q, lam_sd, seed) {
  set.seed(seed)
  Lt  <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u   <- matrix(rnorm(n * q), n, q)
  b   <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  list(Y = matrix(rbinom(n * p, 1, plogis(eta)), n, p), Lt = Lt)
}

fit_one <- function(Y, q, k, start, timeout_s) {
  f <- tryCatch(
    withTimeout(ref_fit(Y, q, k, start = start), timeout = timeout_s, onTimeout = "silent"),
    error = function(e) NULL
  )
  f
}

append_row <- function(df) {
  utils::write.table(df, INC_CSV, sep = ",", append = file.exists(INC_CSV),
                      col.names = !file.exists(INC_CSV), row.names = FALSE)
}

run_cell <- function(Tt, n, seeds, k_aghq, lam_sd, timeout_s) {
  out <- vector("list", length(seeds))
  for (i in seq_along(seeds)) {
    s <- seeds[i]
    d  <- mk(n, Tt, 1L, lam_sd, s)
    pr <- pmin(pmax(colMeans(d$Y), 1 / (4 * n)), 1 - 1 / (4 * n))
    st <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(Tt, 1L))))

    f1 <- fit_one(d$Y, 1L, 1L,      st, timeout_s)
    f9 <- fit_one(d$Y, 1L, k_aghq,  st, timeout_s)

    r1 <- data.frame(T = Tt, n = n, seed = s, engine = "laplace",
                      ratio = if (is.null(f1)) NA_real_ else norm(f1$Lambda, "F") / norm(d$Lt, "F"),
                      conv  = if (is.null(f1)) NA_integer_ else f1$convergence,
                      timed_out = is.null(f1))
    r9 <- data.frame(T = Tt, n = n, seed = s, engine = "aghq",
                      ratio = if (is.null(f9)) NA_real_ else norm(f9$Lambda, "F") / norm(d$Lt, "F"),
                      conv  = if (is.null(f9)) NA_integer_ else f9$convergence,
                      timed_out = is.null(f9))
    append_row(r1); append_row(r9)
    out[[i]] <- rbind(r1, r9)
  }
  do.call(rbind, out)
}

## ---- BREAK-THEN-RESTORE: prove the convergence/timeout bookkeeping is not
## vacuous, per the mandatory discipline check. First attempt (kept here as a
## recorded finding, not scrubbed): a 0.01s cap was tried first and FAILED to
## force a timeout -- the AGHQ (k=9) fit came back CONVERGED (ratio=2.409,
## conv=0, timed_out=FALSE) in nominally 0.01s. That is not a real 10ms
## convergence; it means R.utils::withTimeout's elapsed-time check only fires
## at R-level dispatch points, and whatever the actual wall time was, the
## reported/enforced cap was NOT reliably sub-second here under this box's
## contention. Lesson taken: do not trust a sub-second withTimeout cap as a
## guaranteed cutoff. The FIX is to force the break using a cap that is well
## below the EMPIRICALLY MEASURED typical fit time for this cell (5-6s per the
## pre-run survey), not an arbitrarily tiny number.
cat("=== BREAK CHECK: forcing TIMEOUT_S = 1s on T=4, n=50, 1 seed (typical fit here takes 5-6s) ===\n")
broken <- run_cell(Tt = 4L, n = 50L, seeds = 9001L, k_aghq = 9L, lam_sd = 1.2, timeout_s = 1)
cat("broken-run rows (expect timed_out = TRUE for both engines, ratio = NA):\n")
print(broken)
stopifnot(all(broken$timed_out), all(is.na(broken$ratio)))
cat("CONFIRMED RED under the deliberately-broken (1s) cap.\n\n")
## remove the throwaway seed-9001 rows from the incremental file before the real run
if (file.exists(INC_CSV)) {
  tmp <- utils::read.csv(INC_CSV)
  tmp <- tmp[!(tmp$seed == 9001L & tmp$n == 50L & tmp$T == 4L), ]
  utils::write.csv(tmp, INC_CSV, row.names = FALSE)
}
cat("=== RESTORE CHECK: same cell, real TIMEOUT_S ===\n")
restored <- run_cell(Tt = 4L, n = 50L, seeds = 9002L, k_aghq = 9L, lam_sd = 1.2, timeout_s = 20)
print(restored)
stopifnot(any(!restored$timed_out))
cat("CONFIRMED GREEN after restoring the real cap -- the check is not vacuous.\n\n")
if (file.exists(INC_CSV)) {
  tmp <- utils::read.csv(INC_CSV)
  tmp <- tmp[!(tmp$seed %in% c(9001L, 9002L) & tmp$n == 50L & tmp$T == 4L), ]
  utils::write.csv(tmp, INC_CSV, row.names = FALSE)
}

## ---- THE REAL DESIGN ---------------------------------------------------------
## THE MACHINE WAS UNDER EXTREME CONTENTION WHEN THIS RAN: `uptime` showed load
## averages of ~285/265/199 on a 20-core box, with ~230 concurrently-running R
## processes (three sibling slices A/B/C dispatched alongside this one, each
## itself parallel). A pre-run survey (dev scratch, not shipped) timed
## individual fits under that contention: even T=2, n=200 (trivially cheap by
## FLOP count) took 17-20s wall-clock, and T=16, n=50 timed out on BOTH engines
## at 20s. That is CPU-starvation time, not algorithmic time -- bench3 (a single
## nll evaluation, no optimizer loop) showed every (T,n) cell in the grid
## costing <0.6s per eval under a quieter moment. The fitter itself is not
## pathological here; the box was.
## CONSEQUENCE FOR THE DESIGN: running the nominal 4x5x20-seed x 2-engine grid
## (800 fits) serially under this contention could not finish in 15 minutes, and
## adding parallel workers (mclapply) would only worsen the shared-box
## contention for the sibling slices. So this script:
##   (a) runs SEQUENTIALLY (no extra parallel load on the box),
##   (b) processes cells CHEAPEST-FIRST (by T*n) so a time-budget cutoff drops
##       the most expensive corners first, automatically, not by a static guess,
##   (c) allocates seeds in BATCHES OF 5 across a BREADTH-FIRST outer loop: pass
##       1 gives every surviving cell its first 5 seeds, pass 2 gives every
##       cell 5 more (if the wall budget allows), and so on toward 20. This
##       guarantees a same-seed-count table across the (T,n) grid at whatever
##       point the budget runs out, rather than exhausting the whole budget
##       depth-first on the cheapest one or two cells while T=16 gets nothing.
##   (d) enforces a WALL_BUDGET_S ceiling checked BETWEEN (cell, batch) units:
##       once elapsed time exceeds it, no new (cell,batch) unit starts, and
##       whatever partial coverage exists is written out and reported exactly,
##       cell by cell, in the console output and the .md -- not silently
##       smoothed into "20 seeds everywhere."
LAM_SD       <- 1.2
K_AGHQ       <- 9L
TIMEOUT_S    <- 15        # per-fit wall-clock cap, both engines (< 20s survey cap,
                          # deliberately tighter given the observed contention)
WALL_BUDGET_S <- 600      # 10 min hard ceiling for the sweep loop itself, leaving
                          # headroom in the ~15 min total for the break/restore
                          # check already run above and for writing the .md
Ts        <- c(2L, 4L, 8L, 16L)
Ns        <- c(50L, 100L, 200L, 400L, 800L)
SEED_BATCHES <- split(501:520, ceiling(seq_len(20) / 5))  # 4 batches of 5 -> up to 20/cell

## PRE-PLANNED DROPPED CORNER, stated per the brief's explicit permission: an
## untimed single-seed probe at (T=16, n=800) (dev scratch, not shipped) did not
## return within 2 minutes even in a quieter moment -- nlminb's numerical
## gradient has npar=2T=32 dimensions there, and per-eval cost also scales with
## n=800, so its gradient cost is the worst in the grid by construction. Not run.
DROP <- data.frame(T = 16L, n = 800L)

if (file.exists(FULL_CSV)) file.remove(FULL_CSV)
grid <- expand.grid(T = Ts, n = Ns)
grid <- grid[!(paste(grid$T, grid$n) %in% paste(DROP$T, DROP$n)), ]
grid <- grid[order(grid$T * grid$n), ]  # cheapest cells first WITHIN a batch pass

cat(sprintf("=== BREADTH-FIRST SWEEP: %d candidate cells (pre-dropped T=16,n=800), %d batches of 5 seeds, k=%d, timeout=%ds/fit, wall budget=%ds ===\n",
            nrow(grid), length(SEED_BATCHES), K_AGHQ, TIMEOUT_S, WALL_BUDGET_S))

all_res <- vector("list", 0)
seeds_done <- setNames(rep(0L, nrow(grid)), paste(grid$T, grid$n))
budget_hit <- FALSE
sweep_t0 <- Sys.time()

for (b in seq_along(SEED_BATCHES)) {
  if (budget_hit) break
  batch_seeds <- SEED_BATCHES[[b]]
  cat(sprintf("--- batch %d/%d: seeds %s ---\n", b, length(SEED_BATCHES),
              paste(range(batch_seeds), collapse = "-")))
  for (i in seq_len(nrow(grid))) {
    elapsed_so_far <- as.numeric(Sys.time() - sweep_t0, units = "secs")
    if (elapsed_so_far > WALL_BUDGET_S) {
      cat(sprintf("-- WALL_BUDGET_S (%ds) exceeded at batch %d, cell %d/%d (%.0fs elapsed) -- stopping here --\n",
                  WALL_BUDGET_S, b, i, nrow(grid), elapsed_so_far))
      budget_hit <- TRUE
      break
    }
    Tt <- grid$T[i]; n <- grid$n[i]
    t0 <- Sys.time()
    cell <- run_cell(Tt, n, batch_seeds, K_AGHQ, LAM_SD, TIMEOUT_S)
    all_res[[length(all_res) + 1L]] <- cell
    key <- paste(Tt, n)
    seeds_done[key] <- seeds_done[key] + length(batch_seeds)
    el <- as.numeric(Sys.time() - t0, units = "secs")
    med_lap  <- median(cell$ratio[cell$engine == "laplace"], na.rm = TRUE)
    med_aghq <- median(cell$ratio[cell$engine == "aghq"], na.rm = TRUE)
    n_to <- sum(cell$timed_out)
    cat(sprintf("  T=%2d n=%3d  [%5.1fs, cum %5.0fs]  batch med_ratio laplace=%.3f aghq=%.3f  (%d/%d timeouts)  [seeds so far: %d]\n",
                Tt, n, el, elapsed_so_far + el, med_lap, med_aghq, n_to, nrow(cell), seeds_done[key]))
  }
}
res <- do.call(rbind, all_res)
write.csv(res, FULL_CSV, row.names = FALSE)
## record realised seed coverage per cell, for the .md -- this IS the honest
## record of "which cells got the full 20, which got fewer, which got none."
coverage <- data.frame(T = grid$T, n = grid$n, seeds_run = seeds_done[paste(grid$T, grid$n)])
coverage <- rbind(coverage, data.frame(T = DROP$T, n = DROP$n, seeds_run = 0L))
write.csv(coverage, file.path(EVID_DIR, "12-seed-coverage.csv"), row.names = FALSE)
cat("\nSeed coverage per cell (0 = never reached; pre-dropped T=16,n=800 shown separately):\n")
print(coverage[order(-coverage$seeds_run), ])
DROP_BY_BUDGET <- coverage[coverage$seeds_run == 0 & !(coverage$T == DROP$T & coverage$n == DROP$n), c("T","n")]

## ---- SUMMARY TABLE + CROSSOVER-n PER T ---------------------------------------
cat("\n\n=== median |ratio - 1| by (T, n, engine); crossover n = first n where\n")
cat("    AGHQ's |ratio-1| stops exceeding Laplace's, scanning n ascending ===\n\n")
summarize <- function(res) {
  agg <- aggregate(abs(ratio - 1) ~ T + n + engine, data = res, FUN = median, na.rm = TRUE)
  names(agg)[4] <- "abs_dev"
  agg
}
agg <- summarize(res)

UNAVAILABLE <- rbind(DROP, DROP_BY_BUDGET)  # pre-planned drop + anything the wall budget cut off

for (Tt in Ts) {
  cat(sprintf("--- T = %d ---\n", Tt))
  cat(sprintf("%6s  %10s  %10s\n", "n", "|Lap-1|", "|AGHQ-1|"))
  cross_n <- NA
  for (n in Ns) {
    if (nrow(UNAVAILABLE[UNAVAILABLE$T == Tt & UNAVAILABLE$n == n, ]) > 0) {
      cat(sprintf("%6d  %10s  %10s  (NOT RUN)\n", n, "-", "-"))
      next
    }
    lap  <- agg$abs_dev[agg$T == Tt & agg$n == n & agg$engine == "laplace"]
    aghq <- agg$abs_dev[agg$T == Tt & agg$n == n & agg$engine == "aghq"]
    lap  <- if (length(lap))  lap  else NA
    aghq <- if (length(aghq)) aghq else NA
    nseeds_cell <- seeds_done[paste(Tt, n)]
    cat(sprintf("%6d  %10.4f  %10.4f%s  [n_seeds=%d]\n", n, lap, aghq,
                if (!is.na(lap) && !is.na(aghq) && aghq <= lap) "  <- AGHQ <= Laplace here" else "",
                nseeds_cell))
    if (is.na(cross_n) && !is.na(lap) && !is.na(aghq) && aghq <= lap) cross_n <- n
  }
  cat(sprintf("crossover n for T=%d: %s\n\n", Tt, if (is.na(cross_n)) "NOT REACHED in {50,...,800}" else cross_n))
}

## ---- DOES LAPLACE'S BIAS SHRINK WITH T AT FIXED LARGE n=800? -----------------
cat("=== Laplace median ratio vs T, fixed n=800 (direct O(1/T) check) ===\n")
lap800 <- res[res$engine == "laplace" & res$n == 800L, ]
for (Tt in Ts) {
  if (nrow(UNAVAILABLE[UNAVAILABLE$T == Tt & UNAVAILABLE$n == 800L, ]) > 0) {
    cat(sprintf("T=%2d  n=800: NOT RUN, no data\n", Tt)); next
  }
  s <- lap800[lap800$T == Tt, ]
  cat(sprintf("T=%2d  n=800  median ratio = %.4f  (n_converged=%d/%d)\n",
              Tt, median(s$ratio, na.rm = TRUE), sum(!is.na(s$ratio)), nrow(s)))
}

cat("\nDone. Full table: ", FULL_CSV, "\nIncremental (per-seed) table: ", INC_CSV, "\n")
