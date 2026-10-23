#!/usr/bin/env Rscript
## Design 122 (docs/design/122-va-vs-laplace-recovery.md) CONFIRMATORY
## campaign runner. NOT a pre-run -- this is the grid authorised by SS15's
## (c-modified) disposition: n in {100, 400} (n=1600 EXCLUDED, exploratory-
## budgeted only, per the measured VGH cost curve in
## dev/va-vs-laplace-prerun/RESULTS.md), families {binomial_probit,
## ordinal_probit}, p in {12, 27}, q = 2, 3 frozen truths (T-weak/T-mid/
## T-strong), arms {L0, L2, VGH}, 300 seeds/cell.
##
## PRE-REGISTERED DEFERRALS (record, not silent drop):
##   - The binomial-logit continuity block (VJJ nested sub-study, Design 122
##     SS5.3) is NOT built or run by this script. VJJ is admitted only for
##     pure binomial-logit fits and was scoped as a SEPARATE nested
##     sub-study; it is out of scope for this confirmatory grid.
##   - No `n_starts` arm and no n=1600 confirmatory tier (Design 122 SS14/
##     SS15): the VGH engine's default n_starts=4 makes n=1600 cost >17.3
##     min/fit (measured, unfinished) vs ~126s at n=400 -- SS15's
##     "(c-modified)" disposition drops n=1600 from the confirmatory grid
##     rather than changing the VGH estimand or accepting a multi-day budget.
##
## READ FIRST:
##   docs/design/122-va-vs-laplace-recovery.md  SS3 (DGP), SS4/SS6.1
##     (estimands/stratification), SS5 (arms/grid), SS6.2 (kill criteria),
##     SS14/SS15 (pre-run outcome -- this grid's own justification).
##   dev/va-vs-laplace-prerun/run-prerun122.R   -- DGP, metrics, TEST A
##     machinery, all REUSED (not copied blind) below. Read its header for
##     full provenance of every convention.
##   dev/va-vs-laplace-prerun/rerun-L2-testA-fix.R -- the L2 TEST A
##     ridge-penalty correction (fit$aghq$ridge_tau / fit$aghq$penalised
##     re-added to the scale-ray objective for a penalised Laplace fit).
##     Baked into testA_laplace() below FROM THE START (no un-fixed version
##     ever shipped in this file).
##   dev/coxreid-ab/run-ab.R:12-40               -- the mirai self-contained
##     run_row() lesson: daemons are separate R processes that do NOT share
##     the launcher's globalenv; a closure calling ANOTHER top-level helper
##     fails silently (is.data.frame() filter absorbs the error). FIX
##     applied identically here: run_row() is the ONE function, every helper
##     nested inside it, passed directly to mirai_map() and also called
##     directly for GRID_SMOKE.
##   dev/campaign-admission/admit.sh + RESULT-SCHEMA.md + smoke-ladder.md --
##     result-row schema (identity/outcome/error-as-row/three-denominator
##     convention) and the rung1/2/3 ladder this script's modes implement.
##
## Modes (env vars, mirroring dev/coxreid-ab/run-ab.R's GRID_SMOKE/AB_MODE):
##   GRID_SMOKE       TRUE/FALSE (default FALSE). TRUE runs exactly ONE fit
##                    (rung 1) sequentially, no mirai, prints the row, exits.
##   CAMPAIGN_MODE     "canary" | "full" (default "canary").
##       canary: 1 seed x 24 cells x 3 arms = 72 rows -> canary.csv (rung 2).
##       full:   the real grid. Without CAMPAIGN_CHUNK, loops over all 24
##               cells, writing chunk-NNN.csv incrementally per cell (so a
##               long run's progress survives a crash mid-grid). WITH
##               CAMPAIGN_CHUNK=<cell_id>, runs ONLY that one cell (900
##               fits: 3 arms x 300 seeds) -- this is rung 3's exact shape,
##               and is also how a full campaign should be launched in
##               practice: one chunk job per cell_id, 24 jobs, each
##               independently retriable under a NEW campaign id per
##               RESULT-SCHEMA.md's no-automatic-retries policy.
##   CAMPAIGN_CHUNK    integer cell_id (1..24), full mode only.
##   CAMPAIGN_ID       stamped into every row's campaign_id column. Supplied
##                     by the launcher from admit.sh's MANIFEST.txt; falls
##                     back to "UNADMITTED-DEV-RUN" so a bare local
##                     invocation is never mistaken for an admitted result.
##   CAMPAIGN_WORKERS  integer, default 96, hard-capped at 96 in this script
##                     (the launcher's own D-143 150-core ceiling is a
##                     SEPARATE, looser check -- this script's own default
##                     mirrors run-prerun122.R's 96-worker pin).
##   CAMPAIGN_DEST     output directory for chunk/canary/smoke files.
##                     Default $HOME/gllvm_work/results/design122-dev (a
##                     throwaway dev path); the launcher overrides this to
##                     the admitted campaign destination
##                     ($HOME/gllvm_work/campaigns/<campaign_id>/) for any
##                     real run.
##   CAMPAIGN_LOCAL_DEV 1 to fall back to devtools::load_all() for a LOCAL
##                     SMOKE run only (no installed gllvmTMB required); runs
##                     sequentially, no mirai. Never set on Totoro. Mirrors
##                     dev/coxreid-ab/run-ab.R's AB_LOCAL_DEV.
##   CAMPAIGN_PKG_DIR  package source dir (for the local-dev load_all() path
##                     and for locating dev/va-gate3/two-sided-detector.R).
##
## Compute: Totoro (D-50, local-only), <=96 workers pinned inside this
## script (launcher caps at 150 per D-143, but this campaign never asks for
## more than 96). OPENBLAS_NUM_THREADS/OMP_NUM_THREADS/MKL_NUM_THREADS
## pinned to 1 inside every worker.
##
## Scope discipline: touches ONLY dev/design122-campaign/. Not committed by
## this script.

CAMPAIGN_LOCAL_DEV <- Sys.getenv("CAMPAIGN_LOCAL_DEV", "0") %in% c("1", "TRUE", "true")
PKG_DIR <- Sys.getenv("CAMPAIGN_PKG_DIR", normalizePath("."))

if (CAMPAIGN_LOCAL_DEV) {
  devtools::load_all(PKG_DIR, quiet = TRUE)
} else {
  if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
    stop(
      "gllvmTMB is not installed. This script requires an INSTALLED build ",
      "(the Totoro deploy step runs R CMD INSTALL before launch) -- it does ",
      "not devtools::load_all() in worker processes (compile races). For a ",
      "local smoke test without an installed package, set CAMPAIGN_LOCAL_DEV=1."
    )
  }
  library(gllvmTMB)
}

CAMPAIGN_ID <- Sys.getenv("CAMPAIGN_ID", "UNADMITTED-DEV-RUN")
OUT <- Sys.getenv("CAMPAIGN_DEST", file.path(Sys.getenv("HOME"), "gllvm_work", "results", "design122-dev"))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
NWORK <- min(96L, max(1L, as.integer(Sys.getenv("CAMPAIGN_WORKERS", "96"))))
Q <- 2L
CELL_SEED_OFFSET <- 100000L  ## matches dev/coxreid-ab/run-ab.R's convention

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")

## ==================================================== 1. confirmatory grid ==
## Design 122 SS5.2, n=1600 EXCLUDED per SS15 (see header). 2 families x 2 n
## x 2 p x 3 truths = 24 cells; arm and seed are separate factors applied
## below (arm x seed = 3 x 300 = 900 fits/cell; 24 x 900 = 21,600 total).
CELLS <- expand.grid(
  family = c("binomial_probit", "ordinal_probit"),
  n      = c(100L, 400L),
  p      = c(12L, 27L),
  truth  = c("T-weak", "T-mid", "T-strong"),
  stringsAsFactors = FALSE
)
## Explicit truth ordering (T-weak < T-mid < T-strong, not alphabetical --
## alphabetical would put T-mid before T-strong before T-weak) so cell_id 1
## is genuinely the cheapest/weakest-signal cell, matching the GRID_SMOKE
## comment below and Design 122's own truth-strength ordering.
CELLS$truth <- factor(CELLS$truth, levels = c("T-weak", "T-mid", "T-strong"))
CELLS <- CELLS[order(CELLS$family, CELLS$n, CELLS$p, CELLS$truth), ]
CELLS$truth <- as.character(CELLS$truth)
CELLS$cell_id <- seq_len(nrow(CELLS))
rownames(CELLS) <- NULL
ARMS <- c("L0", "L2", "VGH")
N_SEEDS_FULL <- 300L

TRUTH_TARGET_MAX <- c("T-weak" = 0.35, "T-mid" = 0.70, "T-strong" = 1.40)

## ================================================ 2. frozen truths (once) ===
## Gate 3's own construction (dev/va-gate3/run-gate3.R:109-146), reused --
## NOT dev/va-gate3/truths.rds itself, because that file only carries p in
## {8, 20, 80} (P_VALUES) and this design's p in {12, 27} (Ayumi's trait
## count, SS5.2) is not a subset -- an explicitly documented DEVIATION from
## cell-reuse, identical to dev/va-vs-laplace-prerun/run-prerun122.R's own
## deviation (see that file's SS2 comment) and reusing that EXACT recipe.
## Truths depend on (truth, p) only -- NOT on family or n (Design 122 SS3:
## the same frozen Lambda_0/beta_0 generates both binomial_probit and
## ordinal_probit responses via a shared eta). 3 truths x 2 p values = 6
## frozen (truth,p) entries, built under a fresh deterministic seed per
## entry and frozen to disk so every worker (and every chunk run, replayed
## from this campaign's own destination) sees byte-identical truths.
TRUTH_SEED_BASE <- 12200000L
.build_truth <- function(truth, p, q, seed, target_max) {
  set.seed(seed)
  target <- target_max[[truth]]
  raw <- matrix(stats::rnorm(p * q, 0, 0.6), p, q)
  Lambda_0 <- raw / max(abs(raw)) * target
  Lambda_0_aligned <- gllvmTMB:::.va_r3_rotate_to_lower_triangular(Lambda_0, q)
  if (is.null(Lambda_0_aligned)) {
    stop("Truth ", truth, " p=", p, " failed the lower-triangular rotation ",
         "check (near-singular top q x q block).", call. = FALSE)
  }
  beta_0 <- stats::rnorm(p, 0.3, 0.3)
  list(truth = truth, q = q, p = p, target_max_abs_lambda0 = unname(target),
       Lambda_0 = Lambda_0_aligned, beta_0 = beta_0)
}
.truth_key <- function(truth, p) paste0(truth, "_p", p)

truths_path <- file.path(OUT, "design122-campaign-truths.rds")
if (file.exists(truths_path)) {
  TRUTHS <- readRDS(truths_path)
  cat("Loaded existing frozen truths from", truths_path, "\n")
} else {
  needed <- unique(CELLS[, c("truth", "p")])
  TRUTHS <- list()
  for (i in seq_len(nrow(needed))) {
    tr <- needed$truth[i]; p <- needed$p[i]
    TRUTHS[[.truth_key(tr, p)]] <- .build_truth(tr, p, Q, TRUTH_SEED_BASE + i, TRUTH_TARGET_MAX)
  }
  saveRDS(TRUTHS, truths_path)
  cat("Frozen truths built for:\n")
  for (k in names(TRUTHS)) {
    cat(sprintf("  %s: max|Lambda_0| = %.4f (target %.4f)\n", k,
                max(abs(TRUTHS[[k]]$Lambda_0)), TRUTHS[[k]]$target_max_abs_lambda0))
  }
}

## ======================================= 3. the ONE self-contained worker ==
## Directly ported from dev/va-vs-laplace-prerun/run-prerun122.R's run_row(),
## generalised from "sentinel cell" to "any (family,n,p,truth) cell", with
## the L2 TEST A ridge-penalty fix baked in from the start (never shipped
## un-fixed in this file -- see dev/va-vs-laplace-prerun/RESULTS.md's
## "TEST A verdicts -- including a bug found and fixed mid-run" section for
## the root-cause writeup this fix closes). TESTA_C uses Design 122 SS2 F1's
## FULL pre-registered grid (`seq(0.95, 1.15, by = 0.01)`), not the pre-run's
## own coarse reduction -- this is the confirmatory campaign, not a pre-run.
##
## `g` is a one-row list: cell_id, family, n, p, truth, arm, seed.
## `truths` is the full TRUTHS list (passed by value via mirai .args -- small,
## 6 entries -- avoiding a shared-filesystem read race across workers).
## Returns exactly one data.frame row, always (error-as-row, RESULT-SCHEMA.md).
run_row <- function(g, truths, pkg_dir, campaign_id, cell_seed_offset) {
  suppressMessages(library(gllvmTMB))
  `%||%` <- function(x, y) if (is.null(x)) y else x

  ORD_TAU <- c(0, 0.7, 1.4)
  TESTA_C <- seq(0.95, 1.15, by = 0.01)  ## Design 122 SS2 F1's full grid

  two_sided_env <- new.env()
  sys.source(file.path(pkg_dir, "dev/va-gate3/two-sided-detector.R"), envir = two_sided_env)

  stratum_relfrob <- function(Sigma_hat, Sigma_true, idx) {
    if (!is.matrix(idx) || nrow(idx) == 0L) return(NA_real_)
    den <- sqrt(sum(Sigma_true[idx]^2))
    if (!is.finite(den) || den == 0) return(NA_real_)
    sqrt(sum((Sigma_hat[idx] - Sigma_true[idx])^2)) / den
  }

  recovery_metrics <- function(Lambda_hat, Lambda_true) {
    out <- list(rel_frob = NA_real_, kappa = NA_real_, rel_frob_diag = NA_real_,
                rel_frob_offdiag_strong = NA_real_, rel_frob_offdiag_weak = NA_real_,
                flag_inflated = NA, flag_contracted = NA, degenerate = NA,
                max_abs_lambda_hat = NA_real_)
    if (is.null(Lambda_hat) || !is.matrix(Lambda_hat) || !all(is.finite(Lambda_hat)) ||
        nrow(Lambda_hat) != nrow(Lambda_true) || ncol(Lambda_hat) != ncol(Lambda_true)) {
      return(out)
    }
    out$max_abs_lambda_hat <- max(abs(Lambda_hat))
    Sigma_hat  <- tcrossprod(Lambda_hat)
    Sigma_true <- tcrossprod(Lambda_true)
    ts <- two_sided_env$two_sided_from_matrices(Sigma_hat, Sigma_true)
    out$rel_frob <- ts$rel_frob; out$kappa <- ts$kappa
    out$flag_inflated <- ts$flag_inflated; out$flag_contracted <- ts$flag_contracted
    out$degenerate <- ts$flag_two_sided
    p <- nrow(Sigma_true)
    diag_idx  <- cbind(seq_len(p), seq_len(p))
    upper_idx <- which(row(Sigma_true) < col(Sigma_true), arr.ind = TRUE)
    out$rel_frob_diag <- stratum_relfrob(Sigma_hat, Sigma_true, diag_idx)
    if (nrow(upper_idx) > 0L) {
      strong <- abs(Sigma_true[upper_idx]) >= 0.1
      if (any(strong)) out$rel_frob_offdiag_strong <-
        stratum_relfrob(Sigma_hat, Sigma_true, upper_idx[strong, , drop = FALSE])
      if (any(!strong)) out$rel_frob_offdiag_weak <-
        stratum_relfrob(Sigma_hat, Sigma_true, upper_idx[!strong, , drop = FALSE])
    }
    out
  }

  testA_chat <- function(cs, vals) {
    ok <- is.finite(vals)
    if (sum(ok) < 3L) return(NA_real_)
    fit <- tryCatch(stats::lm(vals[ok] ~ poly(cs[ok], 2, raw = TRUE)), error = function(e) NULL)
    if (is.null(fit)) return(cs[ok][which.min(vals[ok])])
    b <- unname(stats::coef(fit))
    if (length(b) < 3L || !is.finite(b[3]) || b[3] == 0) return(cs[ok][which.min(vals[ok])])
    chat <- -b[2] / (2 * b[3])
    if (!is.finite(chat)) return(cs[ok][which.min(vals[ok])])
    chat
  }

  ## Laplace TEST A -- WITH the ridge-penalty fix from the start (see header
  ## and dev/va-vs-laplace-prerun/rerun-L2-testA-fix.R): the aghq_ridge
  ## penalty is applied at the R level (R/fit-multi.R:5586-5592), NOT baked
  ## into tmb_obj$fn(); an L2 fit's own objective must re-add the identical
  ## penalty term at each scale-perturbed c, else the raw likelihood's
  ## unpenalised pull inflates c_hat by construction. For L0 (ridge_tau=Inf,
  ## penalised=FALSE) this adds exactly 0 -- byte-identical to no fix.
  testA_laplace <- function(fit) {
    out <- list(c_hat = NA_real_, pass = NA, note = "")
    obj <- fit$tmb_obj; par0 <- fit$opt$par
    idx <- which(names(par0) == "theta_rr_B")
    if (is.null(obj) || length(idx) == 0L) { out$note <- "tmb_obj/theta_rr_B not found"; return(out) }
    ridge_tau <- tryCatch(fit$aghq$ridge_tau, error = function(e) Inf)
    penalised <- isTRUE(fit$aghq$penalised) && is.finite(ridge_tau) && ridge_tau > 0
    vals <- vapply(TESTA_C, function(c) {
      par1 <- par0; par1[idx] <- par1[idx] * c
      v <- tryCatch(as.numeric(obj$fn(par1)), error = function(e) NA_real_)
      if (is.finite(v) && penalised) v <- v + 0.5 * sum(par1[idx]^2) / (ridge_tau^2)
      v
    }, numeric(1))
    chat <- testA_chat(TESTA_C, vals)
    out$c_hat <- chat; out$pass <- is.finite(chat) && abs(chat - 1) <= 0.01
    out$note <- if (penalised) sprintf("ridge_tau=%.4g penalty ADDED", ridge_tau) else "unpenalised (ridge_tau=Inf)"
    out
  }

  ## VGH TEST A: FIXED-VARIATIONAL-PARAMETER fallback (m_i/S_i held at the
  ## fitted optimum, not re-optimised per c -- Design 122 SS7's own
  ## pre-registered limitation, TESTA_VGH_partial=TRUE always, carried
  ## forward unchanged from the pre-run).
  testA_vgh <- function(fit) {
    out <- list(c_hat = NA_real_, pass = NA, note = "")
    obj <- fit$engine_result$objective; par0 <- fit$engine_result$best$par
    idx <- if (!is.null(par0)) which(names(par0) == "theta_rr") else integer(0)
    if (is.null(obj) || length(idx) == 0L) {
      out$note <- "engine_result$objective/theta_rr not found"; return(out)
    }
    vals <- vapply(TESTA_C, function(c) {
      par1 <- par0; par1[idx] <- par1[idx] * c
      tryCatch(as.numeric(obj$fn(par1)), error = function(e) NA_real_)
    }, numeric(1))
    chat <- testA_chat(TESTA_C, vals)
    out$c_hat <- chat; out$pass <- is.finite(chat) && abs(chat - 1) <= 0.01
    out$note <- "FIXED-VARIATIONAL fallback (m_i/S_i at fitted optimum, not re-optimised per c)"
    out
  }

  empty_row <- function() {
    data.frame(
      campaign_id = campaign_id,
      cell_id = g$cell_id, family = g$family, n = g$n, p = g$p, truth = g$truth,
      arm = g$arm, seed = g$seed, actual_seed = actual_seed,
      status = "error", converged = FALSE, pdHess = NA, max_abs_gradient = NA_real_,
      wall_time_s = NA_real_,
      rel_frob = NA_real_, kappa = NA_real_,
      rel_frob_diag = NA_real_, rel_frob_offdiag_strong = NA_real_,
      rel_frob_offdiag_weak = NA_real_,
      flag_inflated = NA, flag_contracted = NA, degenerate = NA,
      silent_divergent = NA, silent_divergent_onesided = NA,
      max_abs_lambda_hat = NA_real_,
      tau2_hat = NA_real_, tau3_hat = NA_real_, max_abs_tau_error = NA_real_,
      testA_c_hat = NA_real_, testA_pass = NA, testA_vgh_partial = NA,
      testA_note = "", warning = "", error = "", stringsAsFactors = FALSE
    )
  }

  actual_seed <- as.integer(g$cell_id * cell_seed_offset + g$seed)
  row <- empty_row()

  truth_entry <- truths[[paste0(g$truth, "_p", g$p)]]
  if (is.null(truth_entry)) {
    row$error <- paste0("no frozen truth for ", g$truth, "_p", g$p)
    return(row)
  }

  ## ---- DGP (Design 122 SS3) ----
  set.seed(actual_seed)
  Lambda0 <- truth_entry$Lambda_0; beta0 <- truth_entry$beta_0
  q <- ncol(Lambda0); n <- g$n; p <- g$p
  u <- matrix(stats::rnorm(n * q), n, q)
  eta <- sweep(u %*% t(Lambda0), 2, beta0, "+")
  if (g$family == "binomial_probit") {
    Y <- matrix(stats::rbinom(n * p, 1L, stats::pnorm(eta)), n, p)
  } else {
    ystar <- eta + matrix(stats::rnorm(n * p), n, p)
    Y <- matrix(1L, n, p)
    for (k in ORD_TAU) Y <- Y + (ystar > k) * 1L
    storage.mode(Y) <- "integer"
  }
  trait_names <- paste0("sp", seq_len(p))
  colnames(Y) <- trait_names
  long <- data.frame(
    site  = factor(rep(seq_len(n), p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names),
    value = as.vector(Y), stringsAsFactors = FALSE
  )

  fml <- value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE)
  fam_obj <- if (g$family == "binomial_probit") binomial(link = "probit") else ordinal_probit()
  ctrl <- switch(g$arm,
    L0  = gllvmTMBcontrol(),
    L2  = gllvmTMBcontrol(aghq_ridge = 2),
    VGH = gllvmTMBcontrol(integration = "va", va_eval_method = "gh")
  )

  t0 <- Sys.time()
  cond <- list(warning = NULL, error = NULL)
  fit <- withCallingHandlers(
    tryCatch(
      gllvmTMB(fml, data = long, unit = "site", family = fam_obj, control = ctrl),
      error = function(e) { cond$error <<- conditionMessage(e); NULL }
    ),
    warning = function(w) {
      cond$warning <<- paste(unique(c(cond$warning, conditionMessage(w))), collapse = " | ")
      invokeRestart("muffleWarning")
    }
  )
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  row$wall_time_s <- wall
  row$warning <- cond$warning %||% ""
  if (!is.null(cond$error)) row$error <- cond$error

  if (is.null(fit)) { row$status <- "error"; return(row) }

  if (g$arm %in% c("L0", "L2")) {
    conv <- isTRUE(fit$opt$convergence == 0L)
    pdh  <- isTRUE(fit$sd_report$pdHess)
    row$converged <- conv && pdh
    row$pdHess <- pdh
    row$status <- if (conv && pdh) "ok" else "nonconvergence"
    row$max_abs_gradient <- tryCatch(fit$fit_health$max_gradient %||% NA_real_,
                                      error = function(e) NA_real_)
    Lambda_hat <- tryCatch(extract_ordination(fit, level = "unit")$loadings,
                            error = function(e) NULL)
    testA <- tryCatch(testA_laplace(fit), error = function(e)
      list(c_hat = NA_real_, pass = NA, note = paste("TEST A error:", conditionMessage(e))))
    row$testA_vgh_partial <- FALSE
  } else {
    ## VGH via the public route: a non-"healthy" engine status makes
    ## gllvmTMB() itself abort, so any successfully returned object already
    ## has status == "healthy" -- no in-band "guard_rejected"/
    ## "nonconvergence" state distinct from "error" for this arm (Design 122
    ## F2, cross-arm instrument asymmetry, named not papered over).
    row$status <- if (identical(fit$status, "healthy")) "ok" else "nonconvergence"
    row$converged <- identical(fit$status, "healthy")
    row$max_abs_gradient <- tryCatch(fit$diagnostics$max_abs_gradient %||% NA_real_,
                                      error = function(e) NA_real_)
    Lambda_hat <- tryCatch(extract_ordination(fit, level = "unit")$loadings,
                            error = function(e) NULL)
    testA <- tryCatch(testA_vgh(fit), error = function(e)
      list(c_hat = NA_real_, pass = NA, note = paste("TEST A error:", conditionMessage(e))))
    row$testA_vgh_partial <- TRUE
  }

  met <- recovery_metrics(Lambda_hat, Lambda0)
  row$rel_frob <- met$rel_frob; row$kappa <- met$kappa
  row$rel_frob_diag <- met$rel_frob_diag
  row$rel_frob_offdiag_strong <- met$rel_frob_offdiag_strong
  row$rel_frob_offdiag_weak <- met$rel_frob_offdiag_weak
  row$flag_inflated <- met$flag_inflated; row$flag_contracted <- met$flag_contracted
  row$degenerate <- met$degenerate
  row$max_abs_lambda_hat <- met$max_abs_lambda_hat

  if (g$arm %in% c("L0", "L2")) {
    row$silent_divergent <- isTRUE(met$degenerate) && isTRUE(row$converged)
    row$silent_divergent_onesided <- isTRUE(met$flag_inflated) && isTRUE(row$converged)
  } else {
    row$silent_divergent <- isTRUE(met$degenerate) && identical(row$status, "ok")
    row$silent_divergent_onesided <- isTRUE(met$flag_inflated) && identical(row$status, "ok")
  }

  if (g$family == "ordinal_probit") {
    taus <- tryCatch(extract_cutpoints(fit, quiet = TRUE), error = function(e) {
      row$error <<- paste0(row$error, if (nzchar(row$error)) " || " else "",
                            "extract_cutpoints: ", conditionMessage(e))
      NULL
    })
    if (!is.null(taus) && nrow(taus) > 0) {
      t2 <- taus$tau_estimate[taus$cutpoint_label == "cutpoint_2"]
      t3 <- taus$tau_estimate[taus$cutpoint_label == "cutpoint_3"]
      row$tau2_hat <- if (length(t2)) mean(t2, na.rm = TRUE) else NA_real_
      row$tau3_hat <- if (length(t3)) mean(t3, na.rm = TRUE) else NA_real_
      errs <- c(if (length(t2)) abs(t2 - 0.7) else NA_real_,
                if (length(t3)) abs(t3 - 1.4) else NA_real_)
      row$max_abs_tau_error <- if (all(is.na(errs))) NA_real_ else max(errs, na.rm = TRUE)
    }
  }

  row$testA_c_hat <- testA$c_hat
  row$testA_pass <- testA$pass
  row$testA_note <- testA$note %||% ""
  row
}

## ============================================== 4. task-list construction ==
build_cell_grid <- function(cell_row, seeds) {
  eg <- expand.grid(arm = ARMS, seed = seeds, stringsAsFactors = FALSE)
  eg$cell_id <- cell_row$cell_id; eg$family <- cell_row$family
  eg$n <- cell_row$n; eg$p <- cell_row$p; eg$truth <- cell_row$truth
  eg[, c("cell_id", "family", "n", "p", "truth", "arm", "seed")]
}

run_grid_mirai <- function(grid_df, tag) {
  grid_list <- lapply(split(grid_df, seq_len(nrow(grid_df))), as.list)
  cat(sprintf("[%s] %d fits, workers=%d\n", tag, length(grid_list), NWORK))
  library(mirai)
  daemons(NWORK, dispatcher = TRUE)
  on.exit(daemons(0), add = TRUE)
  t0 <- Sys.time()
  m <- mirai_map(grid_list, run_row,
                 .args = list(truths = TRUTHS, pkg_dir = PKG_DIR,
                               campaign_id = CAMPAIGN_ID,
                               cell_seed_offset = CELL_SEED_OFFSET))[.progress]
  results <- vector("list", length(grid_list))
  for (j in seq_along(grid_list)) {
    results[[j]] <- tryCatch(m[[j]], error = function(e) NULL)
  }
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  ok <- vapply(results, function(r) is.data.frame(r) && nrow(r) == 1L, logical(1))
  if (any(!ok)) {
    cat(sprintf("WARNING [%s]: %d of %d tasks returned no row (mirai task failure) -- recorded as a missing count, NOT silently dropped.\n",
                tag, sum(!ok), length(results)))
  }
  final <- if (any(ok)) do.call(rbind, results[ok]) else NULL
  cat(sprintf("[%s] wall=%.1fs (%.2f min), rows=%d/%d\n", tag, wall, wall / 60,
              if (is.null(final)) 0L else nrow(final), length(grid_list)))
  list(final = final, wall_s = wall, n_attempted = length(grid_list),
       n_ok = if (is.null(final)) 0L else nrow(final))
}

## ==================================================== 5. GRID_SMOKE (rung1) =
SMOKE <- isTRUE(as.logical(Sys.getenv("GRID_SMOKE", "FALSE")))
if (SMOKE) {
  smoke_cell <- CELLS[1L, ]  ## cheapest confirmatory cell: binomial_probit, n=100, p=12, T-weak
  smoke_g <- list(cell_id = smoke_cell$cell_id, family = smoke_cell$family,
                   n = smoke_cell$n, p = smoke_cell$p, truth = smoke_cell$truth,
                   arm = "L0", seed = 1L)
  cat(sprintf("=== GRID_SMOKE: cell_id=%d family=%s n=%d p=%d truth=%s arm=L0 seed=1 ===\n",
              smoke_g$cell_id, smoke_g$family, smoke_g$n, smoke_g$p, smoke_g$truth))
  row <- run_row(smoke_g, TRUTHS, PKG_DIR, CAMPAIGN_ID, CELL_SEED_OFFSET)
  print(row[, c("status", "converged", "wall_time_s", "rel_frob", "kappa",
                "max_abs_lambda_hat", "testA_c_hat", "testA_pass", "error")])
  write.csv(row, file.path(OUT, "smoke.csv"), row.names = FALSE)
  cat("Smoke row written to", file.path(OUT, "smoke.csv"), "\n")
  quit(save = "no", status = 0)
}

## ============================================ 6. CANARY / FULL (rung 2/3+) ==
CAMPAIGN_MODE <- Sys.getenv("CAMPAIGN_MODE", "canary")
if (!CAMPAIGN_MODE %in% c("canary", "full")) stop("CAMPAIGN_MODE must be canary or full, got: ", CAMPAIGN_MODE)

if (CAMPAIGN_MODE == "canary") {
  grid <- do.call(rbind, lapply(seq_len(nrow(CELLS)), function(i) build_cell_grid(CELLS[i, ], 1L)))
  res <- run_grid_mirai(grid, "canary")
  if (is.null(res$final)) { cat("*** FAILURE: 0 canary rows produced. ***\n"); quit(status = 1, save = "no") }
  write.csv(res$final, file.path(OUT, "canary.csv"), row.names = FALSE)
  cat(sprintf("Canary written: %s (n_attempted=%d, n_ok=%d)\n",
              file.path(OUT, "canary.csv"), res$n_attempted, res$n_ok))
  cat("status by family x arm:\n"); print(table(res$final$family, res$final$arm, res$final$status))
} else {
  CHUNK <- Sys.getenv("CAMPAIGN_CHUNK", "")
  if (nzchar(CHUNK)) {
    chunk_id <- as.integer(CHUNK)
    stopifnot(chunk_id %in% CELLS$cell_id)
    cells_to_run <- CELLS[CELLS$cell_id == chunk_id, ]
  } else {
    cells_to_run <- CELLS
  }
  for (i in seq_len(nrow(cells_to_run))) {
    cell <- cells_to_run[i, ]
    chunk_path <- file.path(OUT, sprintf("chunk-%03d.csv", cell$cell_id))
    if (file.exists(chunk_path)) {
      cat(sprintf("chunk-%03d.csv already exists -- SKIPPING (immutable destination; a rerun needs a new campaign_id per RESULT-SCHEMA.md).\n", cell$cell_id))
      next
    }
    grid <- build_cell_grid(cell, seq_len(N_SEEDS_FULL))
    tag <- sprintf("chunk-%03d (%s n=%d p=%d %s)", cell$cell_id, cell$family, cell$n, cell$p, cell$truth)
    res <- run_grid_mirai(grid, tag)
    if (is.null(res$final)) {
      cat(sprintf("*** WARNING: chunk %03d produced 0 rows. NOT writing an empty file; re-check before re-launching. ***\n", cell$cell_id))
      next
    }
    write.csv(res$final, chunk_path, row.names = FALSE)
    cat(sprintf("Wrote %s (n_attempted=%d, n_ok=%d, wall=%.1fs)\n",
                chunk_path, res$n_attempted, res$n_ok, res$wall_s))
  }
}
