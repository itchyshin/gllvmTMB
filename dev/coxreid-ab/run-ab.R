#!/usr/bin/env Rscript
## Design 121 A+B campaign — Cox-Reid (REML) vs Laplace-ML, Totoro runner.
##
## COMMIT=<sha>  -- filled in by the deploy step (R CMD INSTALL'd revision
##                  this run's fits were produced against; leave the
##                  placeholder if run before deploy pins it).
##
## Grid: family in {binomial, ordinal_probit} x T in {4, 8} x n in {100, 200}
##       = 8 cells x seed 1:100 x arm in {A, B} = 1,600 fits (full mode).
## Arms (arm C / AGHQ-ML is DROPPED for this campaign -- A/B only):
##   A = Laplace-ML  (defaults, aghq_ridge = Inf)
##   B = Laplace + Cox-Reid (REML = TRUE, allow_nongaussian_reml = TRUE,
##       aghq_ridge = Inf)
##
## Two corrections inherited from dev/coxreid-prerun/run-prerun.R (read that
## file first -- it is the validated core this script adapts):
##   1. aghq_ridge = Inf, NOT 0. The live validator
##      (.gllvmTMB_normalize_aghq_ridge, R/aghq-auto-ridge.R:8-20) requires a
##      POSITIVE number, Inf, or "auto"; 0 is rejected outright. Inf is the
##      package's actual "ridge off" sentinel (see
##      tests/testthat/helper-aghq-golden.R's `.golden_aghq_control()`).
##   2. The formula uses `latent(0 + trait | site, d = 1, unique = FALSE)`
##      -- loadings-only, no diagonal Psi companion -- NOT the literal
##      `latent(0 + trait | site, d = 1)` (which defaults to unique = TRUE).
##      The DGP has no idiosyncratic per-trait noise beyond the response
##      family's own; fitting a Psi the DGP does not contain invites Heywood
##      cases unrelated to the Cox-Reid question this campaign is testing.
##
## THIRD correction, found running on Totoro (2026-08-16): mirai daemons are
## PERSISTENT, SEPARATE R processes that do NOT share the launching script's
## global environment. A function passed to mirai_map() is serialized as a
## closure; if its body calls ANOTHER top-level helper function (e.g. the
## original design's `run_task()` calling a separately-defined `run_one()`),
## that helper is simply absent in the worker -- R resolves the closure's
## lexical .GlobalEnv reference to the WORKER's own (empty) global env, not a
## copy of the launcher's. The call then fails with "could not find function
## ...", which mirai wraps as a `miraiError`/`errorValue` -- silently
## filtered out by `vapply(res, is.data.frame, ...)`, i.e. every task
## "succeeds" at returning nothing, producing 0 rows with no visible error.
## (Reproduced directly on Totoro: a two-line `run_task <- function(x)
## run_one(x) * 2` sent to a mirai daemon fails with exactly
## "could not find function \"run_one\"".)
## FIX: `run_row()` below is the ONLY function used for per-task work and is
## fully SELF-CONTAINED -- no free variables resolved from the launching
## process's globalenv, only base R, stats, and `gllvmTMB::`-qualified calls.
## It is passed directly to `mirai_map()` (not wrapped in another function
## that calls it) and is also called directly, unchanged, by the local
## sequential (AB_LOCAL_DEV) path -- one implementation, no duplication, and
## no path where a fit can silently vanish instead of becoming a row: the
## entire body is wrapped in `tryCatch()` so any error (data-gen, fit, or
## extraction) still returns a row with family/T/n/arm/seed populated and the
## error message recorded, never NULL.
##
## Design 121 Section 3 requirement carried forward to analysis (NOT done by
## this script): compare arms A and B only on the INTERSECTION of seeds that
## converged in BOTH arms for a given cell -- do not compare on each arm's
## own marginal converged set.
##
## Compute: Totoro, <= 150 workers (D-143 shared ceiling). OPENBLAS_NUM_THREADS
## / OMP_NUM_THREADS / MKL_NUM_THREADS are pinned to 1 INSIDE every worker --
## without this each R process spawns its own BLAS pool and N workers consume
## far more than N threads, blowing the ceiling while running slower from
## contention.
##
## Package loading in workers: workers must `library(gllvmTMB)` from the
## INSTALLED package (the deploy step runs R CMD INSTALL on Totoro before
## this script is launched) -- NOT `devtools::load_all()`, which races other
## workers compiling the same shared object. The ONLY exception is the local
## smoke path below (AB_LOCAL_DEV = 1), which runs sequentially in the main
## process (no mirai workers at all) so there is nothing to race.
##
## Env vars:
##   GRID_SMOKE    TRUE/FALSE (default FALSE) -- TRUE truncates the task
##                 list to exactly 1 fit.
##   GRID_WORKERS  integer (default 64) -- mirai daemon count.
##   AB_MODE       "canary" (seed 1 only: 8 cells x 2 arms = 16 rows) or
##                 "full" (seeds 1:100: 1,600 rows). Default "canary".
##   AB_LOCAL_DEV  1 to fall back to devtools::load_all() for a LOCAL SMOKE
##                 run only (no installed gllvmTMB required); runs
##                 sequentially, no mirai daemons. Never set on Totoro.
##
## Results: ONE final .rds + .csv written to
##   $HOME/gllvm_work/results/coxreid-ab-<mode>.{rds,csv}
## plus a per-completion progress line from each worker (forwarded to the
## host console by mirai's default stdout capture). If the run produces zero
## rows, no file is written and the script exits non-zero with a loud
## FAILURE banner instead of crashing inside the summary.

AB_LOCAL_DEV <- Sys.getenv("AB_LOCAL_DEV", "0") %in% c("1", "TRUE", "true")

if (AB_LOCAL_DEV) {
  devtools::load_all("/private/tmp/gllvmtmb-doc-lane-20260816", quiet = TRUE)
} else {
  if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
    stop(
      "gllvmTMB is not installed. This script requires an INSTALLED build ",
      "(the Totoro deploy step runs R CMD INSTALL before launch) -- it does ",
      "not devtools::load_all() in worker processes (compile races). For a ",
      "local smoke test without an installed package, set AB_LOCAL_DEV=1."
    )
  }
  library(gllvmTMB)
}

## ---------------------------------------------------------------------------
## run_row(): the ONE per-task function. SELF-CONTAINED (see the THIRD
## correction above) -- do not factor pieces of this out into separate
## top-level helper functions that run_row() would then call; that split is
## exactly what broke silently under mirai on Totoro.
##
## `tk` is a one-row data.frame with columns family, T, n, arm, seed,
## cell_index (see the task-list construction below). Returns exactly one
## row, always -- a successful fit row or an error row -- never NULL.
## ---------------------------------------------------------------------------

run_row <- function(tk) {
  family     <- tk$family[[1]]
  Tn         <- tk$T[[1]]
  n          <- tk$n[[1]]
  arm        <- tk$arm[[1]]
  seed_index <- tk$seed[[1]]
  cell_index <- tk$cell_index[[1]]

  error_row <- function(msg, wall = NA_real_) {
    data.frame(
      family = family, T = Tn, n = n, arm = arm, seed = seed_index,
      converged = FALSE, wall_time_s = wall,
      norm_ratio = NA_real_, bias_pct = NA_real_,
      max_abs_lambda = NA_real_, max_abs_gradient = NA_real_,
      warning = "", error = msg, stringsAsFactors = FALSE
    )
  }

  result <- tryCatch({
    Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
               MKL_NUM_THREADS = "1")
    if (!("gllvmTMB" %in% loadedNamespaces())) {
      if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
        stop("gllvmTMB is not installed on this worker.")
      }
      library(gllvmTMB)
    }

    ## --- DGP (identical to dev/coxreid-prerun/run-prerun.R) ---
    ## actual_seed = cell_index * 100000 + seed_index (see CELL_SEED_OFFSET
    ## below for why this scheme is deterministic and canary/full-mode
    ## identical for a given cell + seed_index).
    actual_seed <- as.integer(cell_index * 100000L + seed_index)
    set.seed(actual_seed)
    beta0 <- seq(-0.5, 0.5, length.out = Tn)
    lambda_true <- seq(0.6, 1.4, length.out = Tn)
    u <- rnorm(n)
    eta <- outer(u, lambda_true) + matrix(beta0, n, Tn, byrow = TRUE)

    if (family == "binomial") {
      y <- matrix(rbinom(n * Tn, size = 1, prob = plogis(eta)), n, Tn)
    } else if (family == "ordinal_probit") {
      tau <- c(0, 0.8, 1.6)
      ystar <- eta + matrix(rnorm(n * Tn), n, Tn)
      y <- matrix(1L, n, Tn)
      for (k in tau) y <- y + (ystar > k) * 1L
      storage.mode(y) <- "integer"
    } else {
      stop("unknown family: ", family)
    }

    trait_names <- paste0("t", seq_len(Tn))
    df <- data.frame(
      site  = factor(rep(seq_len(n), each = Tn)),
      trait = factor(rep(trait_names, n), levels = trait_names),
      value = as.vector(t(y))
    )

    ## --- fit (arm C / AGHQ dropped -- A/B only) ---
    fam_obj <- switch(family,
      binomial       = binomial(),
      ordinal_probit = gllvmTMB::ordinal_probit()
    )
    form <- value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

    ctrl_args <- list(aghq_ridge = Inf)
    reml <- FALSE
    if (arm == "A") {
      ## defaults, ridge off
    } else if (arm == "B") {
      reml <- TRUE
      ctrl_args$allow_nongaussian_reml <- TRUE
    } else {
      stop("unknown arm (A/B only in this campaign): ", arm)
    }
    ctrl <- do.call(gllvmTMB::gllvmTMBcontrol, ctrl_args)

    t0 <- Sys.time()
    cond <- list(warning = NULL, error = NULL)
    fit <- withCallingHandlers(
      tryCatch(
        gllvmTMB::gllvmTMB(
          form,
          data    = df,
          unit    = "site",
          family  = fam_obj,
          REML    = reml,
          control = ctrl
        ),
        error = function(e) {
          cond$error <<- conditionMessage(e)
          NULL
        }
      ),
      warning = function(w) {
        cond$warning <<- paste(unique(c(cond$warning, conditionMessage(w))), collapse = " | ")
        invokeRestart("muffleWarning")
      }
    )
    wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

    ratio <- NA_real_
    max_lam <- NA_real_
    max_grad <- NA_real_
    conv <- FALSE
    if (!is.null(fit)) {
      Lambda_hat <- tryCatch(gllvmTMB::extract_loadings(fit, level = "unit"), error = function(e) NULL)
      if (!is.null(Lambda_hat)) {
        ratio <- norm(as.matrix(Lambda_hat), "F") / norm(matrix(lambda_true, ncol = 1), "F")
        max_lam <- max(abs(as.matrix(Lambda_hat)))
      }
      ## fit$fit_health$max_gradient is already computed by
      ## .gllvmTMB_build_fit_health() (R/diagnose.R) for every
      ## gllvmTMB_multi fit -- max(abs(fit$tmb_obj$gr(fit$opt$par))) at the
      ## reported optimum. Reuse it; fall back to a direct gr() call if
      ## fit_health is absent for any reason.
      g <- tryCatch(fit$fit_health$max_gradient, error = function(e) NULL)
      max_grad <- if (!is.null(g) && is.finite(g)) {
        g
      } else {
        tryCatch(max(abs(fit$tmb_obj$gr(fit$opt$par))), error = function(e) NA_real_)
      }
      conv_opt <- isTRUE(fit$opt$convergence == 0L)
      pdh <- if (!is.null(fit$sd_report$pdHess)) isTRUE(fit$sd_report$pdHess) else TRUE
      conv <- isTRUE(conv_opt && pdh)
    }

    data.frame(
      family           = family,
      T                = Tn,
      n                = n,
      arm              = arm,
      seed             = seed_index,
      converged        = conv,
      wall_time_s      = wall,
      norm_ratio       = ratio,
      bias_pct         = if (is.na(ratio)) NA_real_ else 100 * (ratio - 1),
      max_abs_lambda   = max_lam,
      max_abs_gradient = max_grad,
      warning          = if (is.null(cond$warning)) "" else cond$warning,
      error            = if (is.null(cond$error)) "" else cond$error,
      stringsAsFactors = FALSE
    )
  }, error = function(e) error_row(conditionMessage(e)))

  cat(sprintf(
    "[done] family=%s T=%d n=%d arm=%s seed=%d converged=%s ratio=%s max|lambda|=%s max|grad|=%s wall=%s%s\n",
    family, Tn, n, arm, seed_index, result$converged,
    if (is.na(result$norm_ratio)) "NA" else sprintf("%.4f", result$norm_ratio),
    if (is.na(result$max_abs_lambda)) "NA" else sprintf("%.3f", result$max_abs_lambda),
    if (is.na(result$max_abs_gradient)) "NA" else sprintf("%.3g", result$max_abs_gradient),
    if (is.na(result$wall_time_s)) "NA" else sprintf("%.1fs", result$wall_time_s),
    if (nzchar(result$error)) paste0(" ERROR=", result$error) else ""
  ))
  result
}

## ---------------------------------------------------------------------------
## Task list. CELL_SEED_OFFSET must match the literal (100000L) hardcoded
## inside run_row() above -- duplicated rather than shared because run_row()
## must stay free of references to top-level objects (see the THIRD
## correction).
## ---------------------------------------------------------------------------

CELL_SEED_OFFSET <- 100000L

cell_grid <- expand.grid(
  family = c("binomial", "ordinal_probit"),
  T      = c(4L, 8L),
  n      = c(100L, 200L),
  stringsAsFactors = FALSE
)
cell_grid$cell_index <- seq_len(nrow(cell_grid))

AB_MODE <- Sys.getenv("AB_MODE", "canary")
if (!AB_MODE %in% c("canary", "full")) {
  stop("AB_MODE must be 'canary' or 'full', got: ", AB_MODE)
}
seed_indices <- if (AB_MODE == "canary") 1L else seq_len(100L)

tasks <- merge(cell_grid, expand.grid(arm = c("A", "B"), seed = seed_indices,
                                       stringsAsFactors = FALSE),
               by = NULL)
tasks <- tasks[order(tasks$cell_index, tasks$arm, tasks$seed), ]
rownames(tasks) <- NULL

SMOKE <- isTRUE(as.logical(Sys.getenv("GRID_SMOKE", "FALSE")))
if (SMOKE) tasks <- tasks[1L, , drop = FALSE]

cat(sprintf("AB_MODE=%s  tasks=%d  smoke=%s  local_dev=%s\n",
            AB_MODE, nrow(tasks), SMOKE, AB_LOCAL_DEV))

## ---------------------------------------------------------------------------
## Run: sequential (AB_LOCAL_DEV, local smoke only) or mirai (Totoro).
## Both paths call the SAME run_row() with NO wrapper function in between --
## see the THIRD correction in the header comment.
## ---------------------------------------------------------------------------

OUT <- file.path(Sys.getenv("HOME"), "gllvm_work", "results")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

if (AB_LOCAL_DEV) {

  results <- vector("list", nrow(tasks))
  for (i in seq_len(nrow(tasks))) {
    results[[i]] <- run_row(tasks[i, , drop = FALSE])
  }
  out <- do.call(rbind, results)

} else {

  library(mirai)
  NWORK <- as.integer(Sys.getenv("GRID_WORKERS", "64"))

  task_rows <- split(tasks, seq_len(nrow(tasks)))

  daemons(NWORK, dispatcher = TRUE)
  on.exit(daemons(0), add = TRUE)
  t0 <- proc.time()[["elapsed"]]
  res <- mirai_map(task_rows, run_row)[.progress]
  elapsed <- proc.time()[["elapsed"]] - t0

  ok <- vapply(res, is.data.frame, logical(1))
  n_bad <- sum(!ok)
  if (n_bad > 0L) {
    cat(sprintf("*** %d/%d tasks did NOT return a data.frame (mirai-level failure, not a fit error) ***\n",
                n_bad, length(res)))
    bad_idx <- which(!ok)[seq_len(min(3L, n_bad))]
    for (i in bad_idx) {
      cat(sprintf("  task %d: %s\n", i, paste(utils::capture.output(print(res[[i]])), collapse = " / ")))
    }
  }
  cat(sprintf("mirai: %d/%d tasks returned a row (%.1f s elapsed)\n",
              sum(ok), length(res), elapsed))
  out <- if (any(ok)) do.call(rbind, res[ok]) else NULL
}

## ---------------------------------------------------------------------------
## Summary. Never crash on an empty frame -- report loudly instead.
## ---------------------------------------------------------------------------

if (is.null(out) || nrow(out) == 0L) {
  cat("\n*** FAILURE: 0 rows produced. No results file written. ***\n")
  quit(status = 1, save = "no")
}

tag <- sprintf("coxreid-ab-%s", AB_MODE)
saveRDS(out, file.path(OUT, sprintf("%s.rds", tag)))
write.csv(out, file.path(OUT, sprintf("%s.csv", tag)), row.names = FALSE)

cat(sprintf("\nDONE. rows=%d  written to %s/%s.{rds,csv}\n", nrow(out), OUT, tag))
cat("rows per arm:\n")
print(table(out$arm))
cat("converged per arm:\n")
if (nrow(out) > 0L && length(unique(out$arm)) > 0L) {
  print(tapply(out$converged, out$arm, sum))
} else {
  cat("(no rows -- nothing to tabulate)\n")
}
n_nonfinite <- sum(!is.finite(out$norm_ratio))
cat(sprintf("non-finite norm_ratio rows: %d / %d\n", n_nonfinite, nrow(out)))
