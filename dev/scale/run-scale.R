#!/usr/bin/env Rscript
## SCALE-regime VA vs Laplace comparison — Totoro runner.
##
## Question: the literature's argument for VA over Laplace is that Laplace's
## determinant cost grows ~O(m^3) in species while it also solves site-
## specific modes inside the outer loop. The 640-cell Totoro grid
## (dev/totoro-grid/) tested only p<=80, n<=400 and found VA slower there --
## that samples the wrong part of the curve. This harness tests the regime
## the argument is actually made in: n up to 5000, p up to 50 (Ayumi's model
## is n=5397, p=27).
##
## Reuses the dev/totoro-grid/run-grid.R pattern (mirai daemons, per-cell row
## function, thread pinning) rather than rewriting it. Differences from that
## harness:
##   - grid: family x n x p x q(fixed=2) x seed, sized for the scale question
##   - arms: gtmb_gh, gtmb_jj (bernoulli only), gllvm_va, gtmb_laplace
##     (no gllvm_eva -- not part of this question)
##   - a REAL per-arm-fit time budget via a hard-kill subprocess, not
##     setTimeLimit(). Empirically, setTimeLimit(elapsed=) never fired on the
##     worst cells: several mirai workers sat pegged at ~99% CPU for 60+
##     minutes on a single arm with the setTimeLimit budget nominally 900s.
##     R's elapsed-time check is cooperative (checked when control returns to
##     the R evaluator); a TMB fit that spends a very long stretch inside a
##     single C++-level nlminb/sdreport call never yields control back, so
##     the check never fires (confirmed directly: a tight non-yielding R
##     loop also survived setTimeLimit but was killed cleanly by the
##     mechanism below).
##   - gllvm_va / gtmb_laplace: a plain callr::r(timeout=) per call. Both
##     call into code compiled once at PACKAGE INSTALL time, so a fresh
##     subprocess per call costs only spawn+library() overhead (~1-2s,
##     confirmed against the pre-callr mirai-only timings).
##   - gtmb_gh / gtmb_jj: a PERSISTENT callr::r_session per mirai worker
##     (call()+poll_process(timeout)+read(), close()+recreate on timeout).
##     These use the va_r3 engine, which TMB::compile()s its template ON THE
##     FLY per R session (.va_r3_load_dll(), R/va-r3-proto.R, cached under
##     tempdir()). A fresh callr::r() subprocess per call was tried first and
##     measured to get a brand-new tempdir() every single spawn -- R appends
##     a random per-session suffix even when TMPDIR is fixed, and deletes it
##     on exit -- so that approach would silently recompile on EVERY call
##     (confirmed empirically: two callr::r() calls with an identical fixed
##     TMPDIR got two different tempdir() paths, and the shared directory
##     was empty after both exited). The persistent-session fix was verified
##     directly: a second call on the SAME r_session dropped from 21.6s to
##     0.12s by reusing the already-compiled DLL, and poll_process(timeout)
##     + close() forcibly killed a tight non-yielding R loop within the
##     requested budget. On timeout the session is closed and a fresh one is
##     created for that worker's next call, paying the compile cost again
##     only for that one worker, only right after an actual timeout.
##   - EVERY cell's result is written to its own file the moment run_cell()
##     produces it (dev/scale/results/cells/ on Totoro), not only at the very
##     end. The very first version of this harness lost an entire 48-cell,
##     ~70-minute run when a still-computing cell had to be killed: nothing
##     is written to disk until mirai_map()'s blocking collection returns,
##     so killing the master before that loses every already-finished cell
##     too. Per-cell files make the sweep resumable/inspectable mid-run.
##   - an explicit warm-up pass across all workers before the timed grid, to
##     force the one shared compile before the clock starts on any real cell
##   - cell order is shuffled so whatever confound the warm-up misses still
##     does not correlate systematically with n or p
##
## Compute: Totoro, <= 64 workers (150-core ceiling shared with Codex).
## OPENBLAS_NUM_THREADS=1 pinned in EVERY worker AND every callr subprocess.
## Results stay LOCAL (D-50) -- rsync'd back, never a GitHub artifact.

suppressMessages({
  library(gllvmTMB); library(gllvm); library(mirai); library(callr)
})

OUT       <- file.path(Sys.getenv("HOME"), "gllvm_work", "results-scale")
OUT_CELLS <- file.path(OUT, "cells")
dir.create(OUT_CELLS, showWarnings = FALSE, recursive = TRUE)
SMOKE  <- isTRUE(as.logical(Sys.getenv("GRID_SMOKE", "FALSE")))
NWORK  <- as.integer(Sys.getenv("GRID_WORKERS", "48"))
FITSEC <- as.integer(Sys.getenv("GRID_FIT_SECONDS", "900"))

## ---------------------------------------------------------------- design ---
grid <- expand.grid(
  family = c("poisson", "bernoulli"),
  n      = c(500L, 1000L, 2500L, 5000L),
  p      = c(27L, 50L),
  q      = 2L,
  seed   = 1:3,
  stringsAsFactors = FALSE
)
grid$cell_id <- seq_len(nrow(grid))
if (SMOKE) {
  grid <- grid[grid$family == "poisson" & grid$n == 1000L & grid$p == 27L &
               grid$seed == 1L, ]
}

## Shuffle so the first-task-per-worker compile penalty (if the warm-up below
## does not fully absorb it) lands on random conditions, not systematically
## on whichever n/p combination happens to sort first.
set.seed(42)
grid <- grid[sample(nrow(grid)), ]

## ------------------------------------------------------------------ cell ---
## `.fit_*` helpers and run_with_budget() are ALL nested INSIDE run_cell, not
## sibling top-level functions -- mirai workers do not inherit the
## dispatching session's globalenv, only what is captured in the closure
## actually passed to mirai_map (see the run_with_budget note below; the
## same "object not found" failure recurred here for the .fit_* helpers on
## the first callr-based smoke test and was fixed the same way). Passing
## these into callr::r(func = ...) as VALUES still works fine once they are
## in run_cell's own closure -- callr serializes the function by value, it
## does not need run_cell's environment, so no mirai-style problem crosses
## the callr boundary, only the mirai boundary above it.
run_cell <- function(cell, FITSEC) {
  Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
             MKL_NUM_THREADS = "1")
  suppressMessages({ library(gllvmTMB); library(gllvm); library(callr) })
  relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")
  out_cells <- file.path(Sys.getenv("HOME"), "gllvm_work", "results-scale", "cells")

  fit_gtmb_arm <- function(yv, n_trials, X, unit_id, trait_id, q, family,
                           link, H, eval_method) {
    suppressMessages(library(gllvmTMB))
    gllvmTMB:::.approximation_engine_fit(
      engine = "va_r3", y = yv, n_trials = n_trials, X = X,
      unit_id = unit_id, trait_id = trait_id, q = q, family = family,
      link = link, H = H, eval_method = eval_method)
  }
  fit_gllvm_va <- function(Y, family, num.lv) {
    suppressMessages(library(gllvm))
    gllvm::gllvm(y = Y, family = family, num.lv = num.lv, method = "VA", seed = 1)
  }
  fit_gtmb_laplace <- function(fml, data, family) {
    suppressMessages(library(gllvmTMB))
    gllvmTMB(fml, data = data, family = family)
  }

  ## Real hard timeout for gllvm_va / gtmb_laplace: callr::r() kills the OS
  ## subprocess if `budget` elapses, regardless of what C code it is stuck
  ## in. No DLL-cache concern here -- both arms call into code compiled once
  ## at PACKAGE INSTALL time (not per-session), so a fresh subprocess costs
  ## only spawn + library() overhead (~1-2s), verified empirically to match
  ## the pre-callr mirai-only timings closely.
  run_with_budget <- function(func, args, budget) {
    t0 <- proc.time()[["elapsed"]]
    res <- tryCatch({
      callr::r(func, args = args, timeout = budget,
               env = c(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
                       MKL_NUM_THREADS = "1"))
    }, error = function(e) {
      msg <- conditionMessage(e)
      if (inherits(e, "callr_timeout_error") ||
          grepl("timed out|timeout", msg, ignore.case = TRUE)) {
        structure(list(msg = "TIMEOUT"), class = "cell_timeout")
      } else {
        structure(list(msg = msg), class = "cell_error")
      }
    })
    list(v = res, secs = proc.time()[["elapsed"]] - t0)
  }

  ## gtmb_gh / gtmb_jj use a PERSISTENT callr::r_session instead, stored in
  ## this worker's own globalenv (a mirai worker is one persistent R process
  ## across the many cells it is dispatched, so .GlobalEnv survives between
  ## run_cell() invocations even though each invocation is a fresh call).
  ## The va_r3 engine's TMB template is compiled ON THE FLY per R session
  ## (R/va-r3-proto.R's .va_r3_load_dll(), cached under tempdir()); a fresh
  ## callr::r() subprocess per arm-fit call was measured to get a NEW
  ## tempdir() every spawn (R appends a random per-session suffix even with
  ## TMPDIR fixed, and cleans it up on exit), so it would recompile on EVERY
  ## call (~20-60s tax). Verified empirically instead: a persistent
  ## r_session's SECOND call reused the already-compiled DLL and dropped
  ## from 21.6s to 0.12s. poll_process(timeout)+close() gives a true
  ## OS-level kill (verified against a non-yielding tight R loop) -- on
  ## timeout the session is closed and a fresh one is created for the next
  ## call, paying the compile cost again only for that one worker, only
  ## after an actual timeout, not on every call.
  get_va_session <- function() {
    sess <- mget(".va_r3_session", envir = .GlobalEnv, ifnotfound = list(NULL))[[1]]
    if (is.null(sess)) {
      sess <- callr::r_session$new(wait = TRUE)
      assign(".va_r3_session", sess, envir = .GlobalEnv)
    }
    sess
  }
  kill_va_session <- function() {
    sess <- mget(".va_r3_session", envir = .GlobalEnv, ifnotfound = list(NULL))[[1]]
    if (!is.null(sess)) try(sess$close(grace = 200), silent = TRUE)
    assign(".va_r3_session", NULL, envir = .GlobalEnv)
  }
  run_va_with_budget <- function(args, budget) {
    t0 <- proc.time()[["elapsed"]]
    res <- tryCatch({
      sess <- get_va_session()
      sess$call(fit_gtmb_arm, args)
      state <- sess$poll_process(as.integer(budget * 1000))
      if (!identical(state, "ready")) stop("R3_TIMEOUT")
      out <- sess$read()
      if (!is.null(out$error)) stop(conditionMessage(out$error))
      out$result
    }, error = function(e) {
      msg <- conditionMessage(e)
      kill_va_session()  # be conservative: recreate after ANY error/timeout
      if (grepl("R3_TIMEOUT", msg, fixed = TRUE)) {
        structure(list(msg = "TIMEOUT"), class = "cell_timeout")
      } else {
        structure(list(msg = msg), class = "cell_error")
      }
    })
    list(v = res, secs = proc.time()[["elapsed"]] - t0)
  }

  result <- with(cell, {
    set.seed(seed)
    Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
    u  <- matrix(rnorm(n * q), n, q)
    b  <- rnorm(p, 0.3, 0.3)
    eta <- sweep(u %*% t(Lt), 2, b, "+")
    Y <- if (family == "poisson") matrix(rpois(n * p, exp(eta)), n, p)
         else                     matrix(rbinom(n * p, 1, plogis(eta)), n, p)
    colnames(Y) <- paste0("sp", seq_len(p))
    Sig_true <- Lt %*% t(Lt)
    lg <- expand.grid(unit = seq_len(n), trait = seq_len(p))
    lg <- lg[order(lg$unit, lg$trait), ]
    yv <- as.vector(t(Y)); X <- model.matrix(~ 0 + factor(lg$trait))
    fam_gtmb  <- if (family == "poisson") "poisson" else "binomial"
    link_gtmb <- if (family == "poisson") "log" else "logit"
    fam_r     <- if (family == "poisson") poisson() else binomial()

    row <- function(arm, obj = NA_real_, secs = NA_real_, status = NA_character_,
                    Lam = NULL, note = "") {
      rf <- at <- NA_real_
      if (!is.null(Lam) && is.matrix(Lam) && all(is.finite(Lam))) {
        Sh <- Lam %*% t(Lam)
        rf <- relfrob(Sh, Sig_true)
        at <- sum(diag(Sh)) / sum(diag(Sig_true))
      }
      data.frame(family = family, n = n, p = p, q = q, seed = seed, arm = arm,
                 objective = obj, seconds = secs, status = status,
                 rel_frob = rf, attenuation = at, note = note,
                 stringsAsFactors = FALSE)
    }
    out <- list()

    ## --- gtmb_gh (always), gtmb_jj (bernoulli only) ---
    for (em in c("auto", "jj")) {
      if (em == "jj" && family == "poisson") next
      arm <- if (em == "auto") "gtmb_gh" else "gtmb_jj"
      r <- run_va_with_budget(
        list(yv = yv, n_trials = rep(1L, length(yv)), X = X,
             unit_id = lg$unit, trait_id = lg$trait, q = q,
             family = fam_gtmb, link = link_gtmb, H = 15L, eval_method = em),
        FITSEC)
      out[[arm]] <- if (inherits(r$v, "cell_timeout")) {
        row(arm, secs = r$secs, status = "TIMEOUT", note = "budget exceeded")
      } else if (inherits(r$v, "cell_error")) {
        row(arm, secs = r$secs, status = "ERROR", note = r$v$msg)
      } else {
        row(arm, -r$v$score$negative_elbo_gh, r$secs, r$v$status,
            r$v$engine_result$report$Lambda)
      }
    }

    ## --- gllvm_va ---
    r <- run_with_budget(fit_gllvm_va, list(Y = Y, family = fam_r, num.lv = q), FITSEC)
    out[["gllvm_va"]] <- if (inherits(r$v, "cell_timeout")) {
      row("gllvm_va", secs = r$secs, status = "TIMEOUT", note = "budget exceeded")
    } else if (inherits(r$v, "cell_error")) {
      row("gllvm_va", secs = r$secs, status = "ERROR", note = r$v$msg)
    } else {
      Lam <- tryCatch(as.matrix(r$v$params$theta) %*%
                        diag(r$v$params$sigma.lv, q, q), error = function(e) NULL)
      row("gllvm_va", r$v$logL, r$secs,
          if (isTRUE(r$v$convergence)) "converged" else "not_converged", Lam)
    }

    ## --- gtmb_laplace (Psi suppressed) ---
    df <- as.data.frame(Y); df$site <- factor(seq_len(n))
    fml <- as.formula(sprintf(
      "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
      paste(colnames(Y), collapse = ","), q))
    environment(fml) <- globalenv()  # don't drag Y/df into the callr args via closure
    r <- run_with_budget(fit_gtmb_laplace, list(fml = fml, data = df, family = fam_r), FITSEC)
    out[["gtmb_laplace"]] <- if (inherits(r$v, "cell_timeout")) {
      row("gtmb_laplace", secs = r$secs, status = "TIMEOUT", note = "budget exceeded")
    } else if (inherits(r$v, "cell_error")) {
      row("gtmb_laplace", secs = r$secs, status = "ERROR", note = r$v$msg)
    } else {
      ll <- tryCatch(as.numeric(logLik(r$v)), error = function(e) NA_real_)
      ## Sigma_B may include a per-trait link-implicit residual variance on
      ## the diagonal (same caveat carried from run-grid.R) -- rel_frob for
      ## this arm is indicative, not strictly like-for-like against the VA
      ## arms' Lambda Lambda^T.
      Sb <- tryCatch(gllvmTMB::extract_Sigma_B(r$v)$Sigma_B, error = function(e) NULL)
      pd <- tryCatch(isTRUE(r$v$sd_report$pdHess), error = function(e) NA)
      rr <- row("gtmb_laplace", ll, r$secs,
                paste0("conv", r$v$opt$convergence, "_pdHess", pd),
                note = "Sigma_B may include link-implicit residual on diag")
      if (is.matrix(Sb) && all(is.finite(Sb))) {
        rr$rel_frob <- relfrob(Sb, Sig_true)
        rr$attenuation <- sum(diag(Sb)) / sum(diag(Sig_true))
      }
      rr
    }
    do.call(rbind, out)
  })

  ## Persist THIS cell immediately -- survives a killed/hung master.
  saveRDS(result, file.path(out_cells, sprintf("cell_%03d.rds", cell$cell_id[1])))
  ## Close the persistent va_r3 session (if this cell created one) rather
  ## than leaving it running -- with NWORK == number of cells there is no
  ## next cell on this worker to reuse it for.
  kill_va_session()
  result
}

## -------------------------------------------------------- warm-up cells ---
## One trivial fit per worker before the real grid: a basic package-load/
## sanity check, run through a throwaway direct call (not the persistent
## r_session run_cell() uses). It does NOT pre-warm that session -- with
## NWORK == number of cells, each worker handles exactly one real cell, so
## there is no "later cell on this worker" for a warm session to help; the
## real compile-amortization win is within-cell (gtmb_gh then gtmb_jj on the
## same bernoulli cell reusing one session), which this warm-up cannot
## capture and does not need to.
warmup_worker <- function(i) {
  Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
             MKL_NUM_THREADS = "1")
  suppressMessages({ library(gllvmTMB); library(gllvm) })
  set.seed(1)
  n <- 40L; p <- 8L; q <- 2L
  Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(rpois(n * p, exp(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  lg <- expand.grid(unit = seq_len(n), trait = seq_len(p))
  lg <- lg[order(lg$unit, lg$trait), ]
  yv <- as.vector(t(Y)); X <- model.matrix(~ 0 + factor(lg$trait))
  try(gllvmTMB:::.approximation_engine_fit(
    engine = "va_r3", y = yv, n_trials = rep(1L, length(yv)), X = X,
    unit_id = lg$unit, trait_id = lg$trait, q = q, family = "poisson",
    link = "log", H = 15L, eval_method = "auto"), silent = TRUE)
  try(gllvm::gllvm(y = Y, family = poisson(), num.lv = q, method = "VA"),
      silent = TRUE)
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y), collapse = ","), q))
  try(gllvmTMB(fml, data = df, family = poisson()), silent = TRUE)
  TRUE
}

## ------------------------------------------------------------------- run ---
cells <- split(grid, seq_len(nrow(grid)))
cat(sprintf("cells=%d  arms<=4  workers=%d  fit_budget=%ds  smoke=%s\n",
            length(cells), NWORK, FITSEC, SMOKE))

daemons(NWORK, dispatcher = TRUE)
on.exit(daemons(0), add = TRUE)

if (!SMOKE) {
  cat(sprintf("warming up %d workers (TMB compile penalty absorption)...\n", NWORK))
  wt0 <- proc.time()[["elapsed"]]
  invisible(mirai_map(seq_len(NWORK), warmup_worker)[.progress])
  cat(sprintf("warm-up done in %.1f s\n", proc.time()[["elapsed"]] - wt0))
}

## NOTE: mirai_map's `...` captures free variables referenced in `.f`'s BODY
## but not defined there -- it does not bind to `.f`'s formal parameters.
## Constant arguments matching formals (like FITSEC here) must go through
## `.args`. (The original run-grid.R's bare `FITSEC = FITSEC` never surfaced
## this because that harness's FITSEC parameter was unused dead code, so its
## lazy-eval promise was never forced.)
t0 <- proc.time()[["elapsed"]]
res <- mirai_map(cells, run_cell, .args = list(FITSEC = FITSEC))[.progress]
elapsed <- proc.time()[["elapsed"]] - t0

ok <- vapply(res, is.data.frame, logical(1))
out <- do.call(rbind, res[ok])
tag <- if (SMOKE) "smoke" else "scale"
saveRDS(out, file.path(OUT, sprintf("%s.rds", tag)))
write.csv(out, file.path(OUT, sprintf("%s.csv", tag)), row.names = FALSE)

cat(sprintf("\nDONE in %.1f s | cells ok %d/%d | rows %d\n",
            elapsed, sum(ok), length(res), nrow(out)))
cat("rows per arm:\n"); print(table(out$arm))
cat("status table:\n"); print(table(out$arm, out$status, useNA = "ifany"))
cat("non-finite objectives per arm:\n")
print(tapply(out$objective, out$arm, function(z) sum(!is.finite(z))))
cat("\nhead:\n"); print(utils::head(out, 12))
