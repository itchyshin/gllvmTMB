## TASK B (Curie, VA-speed lane): SPECIFICATION DISCRIMINATOR for the 73/71-split finding.
##
## In Task A's cell, PSI = 0.6 is planted in the DGP as a residual (u) term, but the fit
## uses unique = FALSE -- i.e. the model is loadings-only and CANNOT represent the
## residual variance the data contains. So "our optimiser degrades under misspecification"
## explains any blow-up just as well as "ill-conditioning" does, and the two must be told
## apart before touching the loadings reparameterisation.
##
## ONE CHANGE from 73-split-instrumented.R: PSI <- 0 (no residual term in the DGP), so the
## loadings-only AC fit is now CORRECTLY SPECIFIED. Everything else -- N, T, q, NTR, the AC
## arm, collapse_variational_cov, unique = FALSE, the 8 seeds, the warm-up, the run-order
## randomisation, the tracer -- is unchanged. Per the brief: do NOT instead switch the psi
## tier on in the fit -- that changes two things at once (ledger claim 13, STANDS: the AC
## evaluator collapses a real ψ, estimating 0.0001 against a planted 0.6 where the GH tier
## recovers 0.6207) and would prove nothing about conditioning vs misspecification.
##
## TRACE TARGET, corrected from the brief's suggested `where = asNamespace("gllvmTMB")`:
## empirically verified against a live toy fit (see dev/va-speed/verify-trace2.R history)
## that (a) trace(nlminb, where = asNamespace("stats")) alone gives non-zero, structurally
## sensible counts (12 nlminb + 4 optim calls for 4 starts x up to 3 nlminb + 1 L-BFGS-B
## each -- exactly the polish-loop structure in R/va-r3-proto.R), and (b) there is NO direct
## `nlminb` binding inside asNamespace("gllvmTMB") at all (get(..., inherits=FALSE) errors
## "object not found") -- every optimiser call in R/va-r3-proto.R is explicitly
## `stats::nlminb(...)` / `stats::optim(...)`, which always resolves straight against
## stats's own namespace and never consults any local/imported binding gllvmTMB might hold.
## So the ONLY place tracing can intercept these calls is asNamespace("stats").
##
## WARM-UP (added per coordinator direction after finding 71/73 lacked one, unlike its
## sibling 57-gllvm-scaling.R:74-78): an untimed, tiny-N throwaway fit for BOTH arms before
## any timed run, so first-call TMB-compile / gllvm-setup cost cannot land on whichever seed
## happens to run first.
##
## RUN ORDER: the 8 seeds are run in a RANDOMISED order (fixed permutation seed 20260805 for
## reproducibility), and that order is recorded as `run_order_position` in every row, so a
## first-in-loop artefact cannot be silently attributed to "seed 1" specifically.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(gllvm) })
`%||%` <- function(a, b) if (is.null(a)) b else a

cat("=== load average BEFORE any work ===\n")
system("cat /proc/loadavg")

## --- DGP: byte-identical to 71-split25.R::mk() when called as mk(seed); N gains a
## default = N0 solely so an explicit tiny-N WARM-UP cell can reuse the same generator
## without inventing a second DGP. Calling mk(seed) reproduces 71 exactly. -------------
N0 <- 120L; T0 <- 10L; q0 <- 1L; NTR <- 6L; PSI <- 0; H0 <- 15L  ## <- ONLY CHANGE FROM 73: PSI 0.6 -> 0
SEEDS <- 1:8

mk <- function(seed, N = N0) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N * q0), N, q0)
  u   <- matrix(rnorm(N * T0, 0, PSI), N, T0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+") + u
  Y   <- matrix(rbinom(N * T0, NTR, pnorm(eta)), N, T0)
  list(Y = Y, lam = lam, N = N)
}

run_ours <- function(cell) {
  N <- cell$N
  long <- expand.grid(site = seq_len(N), trait_idx = seq_len(T0))
  gllvmTMB:::.va_r3_fit(
    y = as.integer(cell$Y), n_trials = rep(NTR, N * T0),
    X = matrix(1, N * T0, 1L),
    unit_id = long$site, trait_id = long$trait_idx, q = q0,
    family = "binomial_probit", eval_method = "ac",
    collapse_variational_cov = TRUE, unique = FALSE
  )
}
run_gllvm <- function(cell, seed) {
  gllvm::gllvm(y = cell$Y, family = binomial(link = "probit"),
               num.lv = q0, method = "VA", Ntrials = NTR,
               seed = seed, trace = FALSE)
}

tm <- function(e) { t0 <- proc.time()[["elapsed"]]; v <- force(e); list(s = proc.time()[["elapsed"]] - t0, v = v) }
sc1 <- function(x, na) { v <- suppressWarnings(tryCatch(x, error = function(e) na)); if (is.null(v) || length(v) != 1L) na else v }

## --- Optimiser-work tracer: accumulate stats::nlminb / stats::optim work across
## ALL starts within one .va_r3_fit() call (default n_starts = 4, unchanged from 71). ---
TR <- new.env()
reset_tr <- function() {
  TR$n_nlminb <- 0L; TR$n_optim <- 0L
  TR$iters_total <- 0; TR$fn_total <- 0; TR$gr_total <- 0
}
reset_tr()
nlminb_exit <- quote({
  rv <- returnValue()
  TR$n_nlminb <- TR$n_nlminb + 1L
  it <- rv$iterations
  if (!is.null(it) && is.finite(it)) TR$iters_total <- TR$iters_total + it
  ev <- rv$evaluations
  if (!is.null(ev)) {
    fe <- ev[["function"]]; ge <- ev[["gradient"]]
    if (!is.null(fe) && is.finite(fe)) TR$fn_total <- TR$fn_total + fe
    if (!is.null(ge) && is.finite(ge)) TR$gr_total <- TR$gr_total + ge
  }
})
optim_exit <- quote({
  rv <- returnValue()
  TR$n_optim <- TR$n_optim + 1L
  ct <- rv$counts
  if (!is.null(ct)) {
    fe <- ct[["function"]]; ge <- ct[["gradient"]]
    if (!is.null(fe) && is.finite(fe)) TR$fn_total <- TR$fn_total + fe
    if (!is.null(ge) && is.finite(ge)) TR$gr_total <- TR$gr_total + ge
  }
})
suppressMessages(trace(nlminb, where = asNamespace("stats"), exit = nlminb_exit, print = FALSE))
suppressMessages(trace(optim, where = asNamespace("stats"), exit = optim_exit, print = FALSE))

## Verify tracing BEFORE running anything that counts, per the brief's mandate: if this
## prints all zeros, STOP -- do not produce meaningless numbers.
reset_tr()
verify_cell <- mk(12345L, N = 25L)
invisible(tryCatch(run_ours(verify_cell), error = function(e) NULL))
cat(sprintf("\n=== TRACE VERIFICATION (tiny N=25 cell, discarded): n_nlminb=%d n_optim=%d fn_total=%d gr_total=%d ===\n",
            TR$n_nlminb, TR$n_optim, TR$fn_total, TR$gr_total))
if (TR$n_nlminb == 0L && TR$n_optim == 0L) {
  stop("TRACING PRODUCED ZERO COUNTS on a verification fit -- refusing to run the campaign. ",
       "Falling back to wall-clock only is the honest move here, not silently proceeding.",
       call. = FALSE)
}
cat("Tracing verified non-zero. Proceeding.\n\n")

## --- untimed warm-up, BOTH arms, tiny N -- pays TMB compile + gllvm first-call cost ----
wu <- mk(999L, N = 40L)
invisible(try(run_ours(wu), silent = TRUE))
invisible(try(suppressWarnings(run_gllvm(wu, seed = 999L)), silent = TRUE))
cat("warm-up done (UNTIMED, both arms, N=40, seed=999, discarded)\n\n")

## --- randomised run order over the 8 seeds; recorded, not just applied -----------------
set.seed(20260805)
run_order <- sample(SEEDS)
cat("run order (seed values, in execution sequence):", paste(run_order, collapse = ", "), "\n\n")

cat("=== load average AT START OF TIMED LOOP ===\n")
system("cat /proc/loadavg")
cat("\n")

rows <- list()
for (idx in seq_along(run_order)) {
  s <- run_order[idx]
  cell <- mk(s)

  reset_tr()
  o <- tm(tryCatch(run_ours(cell), error = function(e) NULL))
  o_status <- sc1(as.character(o$v$status), NA_character_)
  o_polish <- sc1(as.character(o$v$best$polish_optimizer), NA_character_)
  n_nlminb <- TR$n_nlminb; n_optim <- TR$n_optim
  iters_total <- TR$iters_total; fn_total <- TR$fn_total; gr_total <- TR$gr_total
  ms_per_fn_eval <- if (!is.na(fn_total) && fn_total > 0) 1000 * o$s / fn_total else NA_real_

  g <- tm(tryCatch(suppressWarnings(run_gllvm(cell, seed = s)), error = function(e) NULL))
  g_status <- if (!is.null(g$v)) "fit_returned" else "error"

  rows[[length(rows) + 1L]] <- data.frame(
    seed = s, run_order_position = idx,
    ours_wall_s = sc1(o$s, NA_real_), status = o_status, polish_optimizer = o_polish,
    n_nlminb_calls = n_nlminb, n_optim_calls = n_optim,
    iters_total = iters_total, fn_total = fn_total, gr_total = gr_total,
    ms_per_fn_eval = ms_per_fn_eval,
    gllvm_wall_s = sc1(g$s, NA_real_), gllvm_status = g_status,
    stringsAsFactors = FALSE
  )
  cat(sprintf("[pos %d] seed %d  ours %.3fs (%s, %s, nlminb=%d optim=%d iters=%d fn=%d gr=%d, %.3f ms/fn)   gllvm %.3fs\n",
              idx, s, o$s, o_status, o_polish, n_nlminb, n_optim, iters_total, fn_total, gr_total,
              ms_per_fn_eval, g$s))
}
r <- do.call(rbind, rows)

cat("\n=== load average AT END OF TIMED LOOP ===\n")
system("cat /proc/loadavg")

try(suppressMessages(untrace(nlminb, where = asNamespace("stats"))), silent = TRUE)
try(suppressMessages(untrace(optim, where = asNamespace("stats"))), silent = TRUE)

cat("\n=== TASK B SUMMARY (seed-ordered, not run-ordered) -- PSI = 0, correctly specified ===\n")
r_by_seed <- r[order(r$seed), ]
print(r_by_seed, row.names = FALSE)
cat(sprintf("\nours wall:   median %.3fs   max %.3fs (seed %d)\n",
            median(r$ours_wall_s, na.rm = TRUE), max(r$ours_wall_s, na.rm = TRUE),
            r$seed[which.max(r$ours_wall_s)]))
cat(sprintf("fn_total:    median %d   max %d (seed %d)\n",
            as.integer(median(r$fn_total, na.rm = TRUE)), max(r$fn_total, na.rm = TRUE),
            r$seed[which.max(r$fn_total)]))
cat(sprintf("ms_per_fn:   median %.4f   max %.4f (seed %d)\n",
            median(r$ms_per_fn_eval, na.rm = TRUE), max(r$ms_per_fn_eval, na.rm = TRUE),
            r$seed[which.max(r$ms_per_fn_eval)]))

meta <- list(
  cell = list(N0 = N0, T0 = T0, q0 = q0, NTR = NTR, PSI = PSI, H0 = H0),
  seeds = SEEDS, run_order = run_order,
  trace_target = "asNamespace('stats') -- verified empirically; asNamespace('gllvmTMB') has no direct nlminb/optim binding",
  warmup = "untimed, both arms, N=40, seed=999",
  loadavg_start = tryCatch(readLines("/proc/loadavg"), error = function(e) NA_character_),
  git_head = tryCatch(system("git rev-parse HEAD", intern = TRUE), error = function(e) NA_character_),
  timestamp = Sys.time()
)
saveRDS(list(data = r, meta = meta), "dev/va-speed/74-spec-discriminator.rds")
cat("\nSaved dev/va-speed/74-spec-discriminator.rds\n")
cat("DONE\n")
