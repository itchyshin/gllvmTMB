#!/usr/bin/env Rscript
## Design 122 (docs/design/122-va-vs-laplace-recovery.md) Section 7 pre-run,
## authorised under D-139. NOT the confirmatory campaign -- exactly the
## pre-run: ~10 seeds x 4 sentinel cells x 3 confirmatory arms (L0, L2, VGH),
## smoke-first, 25-minute stop rule.
##
## REDUCED-SENTINEL RE-RUN (maintainer-authorised follow-up, same date). The
## FIRST attempt's smoke fit -- VGH at n=1600, p=27, T-strong -- did not
## complete in 17.3 minutes of wall-clock (killed; see RESULTS.md's original
## "STOP RULE FIRED" section, kept intact below the new one). A standalone
## VGH cost-curve check (n=100 and n=400 at the same p=27/T-strong config,
## see RESULTS.md) found n=400 affordable, so the "most_expensive" sentinel
## below is now n = 400 (not 1600) -- the n=1600 corner is deferred, not
## measured by this run. The smoke-first + 25-min stop rule below still
## binds unmodified; only the sentinel's own n changed.
##
## READ FIRST: docs/design/122-va-vs-laplace-recovery.md SS7 (spec), SS5.1
## (arm control calls), SS3 (DGP), SS4/SS6.1 (estimands / stratification).
##
## Compute: Totoro (D-50, local-only). R_LIBS pins the frozen gllvmTMB 0.7.0
## (commit ae17a501) install + mirai. Workers capped at 96.
##
## Harness conventions mirrored from (never copied verbatim, cited inline):
##   - dev/coxreid-prerun/run-prerun.R    -- error-as-row, incremental writes,
##                                           smoke-first + 25 min stop rule.
##   - dev/totoro-grid/run-grid.R         -- mirai_map / daemons() idiom,
##                                           OPENBLAS_NUM_THREADS pin per worker.
##   - dev/coxreid-ab/run-ab.R:12-40      -- CRITICAL mirai lesson, found on
##     Totoro the same day this file was written: mirai daemons are separate
##     R processes that do NOT share the launcher's globalenv. A function
##     passed to mirai_map() that calls ANOTHER top-level helper fails with
##     "could not find function", and that failure is silently filtered out
##     by an `is.data.frame()` check -- every task "succeeds" at returning
##     nothing. FIX (applied below, same as run-ab.R): exactly ONE function,
##     `run_row()`, is used for all per-task work; every helper it needs is
##     defined or sourced INSIDE it; it is passed directly to mirai_map() and
##     also called directly for the smoke test -- one implementation, no
##     duplication, no silent-vanish path.
##   - dev/va-gate3/run-gate3.R           -- frozen-truth construction recipe
##                                           (.gate3_build_truths, lines
##                                           109-146), stratified rel_frob
##                                           (.gate3_stratum_relfrob, line 315).
##   - dev/va-gate3/two-sided-detector.R  -- canonical two-sided degenerate
##                                           flag (rel_frob > 10 OR kappa <
##                                           1/3), sourced inside run_row().
##
## Scope discipline: touches ONLY this directory. Does not touch
## dev/coxreid-ab/ (another lane is active there). Not committed by this
## script.

suppressMessages({
  library(gllvmTMB)
  library(mirai)
})

OUT <- file.path(Sys.getenv("HOME"), "gllvm_work", "results")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
NWORK <- min(96L, as.integer(Sys.getenv("PRERUN_WORKERS", "96")))
SEEDS <- 1:10
Q <- 2L
PKG_DIR <- Sys.getenv("PRERUN_PKG_DIR", normalizePath("."))

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")

## =========================================================== 1. sentinels ==
## Design SS7, items 1-4, REDUCED: item 2 (originally n=1600, the confirmatory
## grid's own large-n rung) is replaced by its n=400 counterpart, per the
## maintainer-authorised follow-up above -- the cost-curve check found n=1600
## VGH did not complete in the pre-run's budget at all, while n=400 did (see
## RESULTS.md). Same (p=27, T-strong) cell identity, only n changed.
sentinels <- data.frame(
  cell_id = 1:4,
  label   = c("cheapest", "most_expensive", "ordinal", "strong_small_n"),
  family  = c("binomial_probit", "binomial_probit", "ordinal_probit", "binomial_probit"),
  n       = c(100L, 400L, 400L, 100L),
  p       = c(12L, 27L, 12L, 27L),
  truth   = c("T-weak", "T-strong", "T-mid", "T-strong"),
  stringsAsFactors = FALSE
)

TRUTH_TARGET_MAX <- c("T-weak" = 0.35, "T-mid" = 0.70, "T-strong" = 1.40)

## ===================================================== 2. frozen truths ====
## dev/va-gate3/truths.rds only carries p in {8, 20, 80} (P_VALUES,
## dev/va-gate3/run-gate3.R:96) -- this design's p in {12, 27} (Ayumi's trait
## count, SS5.2) is NOT a subset, so Design 122 SS3's "reused verbatim...
## wherever a cell already exists there" does not apply to any sentinel cell.
## This pre-run therefore builds fresh (truth, p) truths using GATE 3's
## IDENTICAL construction (raw <- matrix(rnorm(p*q,0,0.6),p,q); scale to
## max|.| = target; rotate to canonical lower-triangular basis via
## gllvmTMB:::.va_r3_rotate_to_lower_triangular), under a freshly declared
## seed per (truth, p) pair, and freezes them to disk. This is a documented
## DEVIATION from cell-reuse, not a violation of it -- flagged in RESULTS.md.
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
needed <- unique(sentinels[, c("truth", "p")])
TRUTHS <- list()
for (i in seq_len(nrow(needed))) {
  tr <- needed$truth[i]; p <- needed$p[i]
  TRUTHS[[.truth_key(tr, p)]] <- .build_truth(tr, p, Q, TRUTH_SEED_BASE + i, TRUTH_TARGET_MAX)
}
saveRDS(TRUTHS, file.path(OUT, "va-laplace-prerun-truths.rds"))
cat("Frozen truths built for:\n")
for (k in names(TRUTHS)) {
  cat(sprintf("  %s: max|Lambda_0| = %.4f (target %.4f)\n", k,
              max(abs(TRUTHS[[k]]$Lambda_0)), TRUTHS[[k]]$target_max_abs_lambda0))
}

## ======================================= 3. the ONE self-contained worker ==
## Everything a task needs -- DGP, metrics, TEST A, the fit call itself -- is
## defined or sourced INSIDE run_row(). No free variable is resolved from the
## launching process's globalenv (see the mirai lesson in the file header).
## Called directly for the smoke test AND passed directly to mirai_map() for
## the full grid: one implementation, no duplication.
run_row <- function(g, pkg_dir, out_dir, truth_seed_base) {
  suppressMessages(library(gllvmTMB))
  `%||%` <- function(x, y) if (is.null(x)) y else x

  ## ---- local helpers (all nested; no top-level globalenv dependency) ----
  TRUTH_TARGET_MAX <- c("T-weak" = 0.35, "T-mid" = 0.70, "T-strong" = 1.40)
  ORD_TAU <- c(0, 0.7, 1.4)
  TESTA_C <- c(0.95, 0.99, 1, 1.01, 1.05)

  build_truth <- function(truth, p, q, seed, target_max) {
    set.seed(seed)
    target <- target_max[[truth]]
    raw <- matrix(stats::rnorm(p * q, 0, 0.6), p, q)
    Lambda_0 <- raw / max(abs(raw)) * target
    Lambda_0_aligned <- gllvmTMB:::.va_r3_rotate_to_lower_triangular(Lambda_0, q)
    beta_0 <- stats::rnorm(p, 0.3, 0.3)
    list(truth = truth, q = q, p = p, target_max_abs_lambda0 = unname(target),
         Lambda_0 = Lambda_0_aligned, beta_0 = beta_0)
  }

  ## Prefer the frozen truths.rds the launcher wrote (byte-identical across
  ## every worker); rebuild only if that file is somehow unavailable to this
  ## worker (defensive -- should not happen, filesystem is shared).
  truths_path <- file.path(out_dir, "va-laplace-prerun-truths.rds")
  truth_entry <- if (file.exists(truths_path)) {
    readRDS(truths_path)[[paste0(g$truth, "_p", g$p)]]
  } else {
    needed <- unique(data.frame(truth = g$truth, p = g$p))
    build_truth(g$truth, g$p, 2L, truth_seed_base + 1L, TRUTH_TARGET_MAX)
  }

  ## Canonical two-sided detector (dev/va-gate3/two-sided-detector.R),
  ## sourced fresh in every worker so the algebra is not re-derived.
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

  ## Laplace TEST A: fit$tmb_obj$fn() with theta_rr_B entries scaled by c.
  ## FIX (found by the reduced-sentinel run itself, on real L2 fits): the
  ## `aghq_ridge` loading penalty on the LAPLACE path is applied at the R
  ## level -- `run_one()`'s closure adds `0.5*sum(par[loading_idx]^2)/tau^2`
  ## on top of `obj$fn()`'s raw value (R/fit-multi.R:5586-5592) -- it is NOT
  ## baked into the TMB C++ template's objective. `fit$tmb_obj$fn()` alone is
  ## therefore the UNPENALISED negative log-likelihood, not "the arm's own
  ## objective" F1 requires for a penalised (L2) fit: evaluating it along the
  ## scale ray was measuring the wrong function and would show `c_hat > 1`
  ## by construction (the raw likelihood always "wants" to grow the loadings
  ## back toward the unpenalised ML scale). Corrected here by re-adding the
  ## SAME penalty term the optimiser actually used, read from
  ## `fit$aghq$ridge_tau`/`fit$aghq$penalised` (R/fit-multi.R:6816,
  ## "ridge_tau"/"penalised are recorded on BOTH engines and every reporting
  ## surface reads the same two fields"). For L0 (`ridge_tau = Inf`,
  ## `penalised = FALSE`) this adds exactly 0 -- byte-identical to the
  ## original, unpenalised behaviour.
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
    out$note <- paste0(if (penalised) sprintf("ridge_tau=%.4g penalty ADDED (fix); ", ridge_tau) else "unpenalised (ridge_tau=Inf); ",
                        paste(sprintf("c=%.2f:%.4f", TESTA_C, vals), collapse = "; "))
    out
  }

  ## VGH TEST A: FIXED-VARIATIONAL-PARAMETER fallback (m_i/S_i held at the
  ## fitted optimum, NOT re-optimised per c -- re-driving the engine's own
  ## inner solver at each c is out of scope for the pre-run's time budget).
  ## TESTA_VGH_partial = TRUE always for this arm; a pre-registered
  ## limitation to REPORT, not hide.
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
    out$note <- paste0("FIXED-VARIATIONAL fallback (m_i/S_i at fitted optimum, ",
                        "not re-optimised per c); ",
                        paste(sprintf("c=%.2f:%.4f", TESTA_C, vals), collapse = "; "))
    out
  }

  empty_row <- function() {
    data.frame(
      cell_id = g$cell_id, label = g$label, family = g$family,
      n = g$n, p = g$p, truth = g$truth, arm = g$arm, seed = g$seed,
      status = "error", converged = NA, pdHess = NA, max_abs_gradient = NA_real_,
      wall_time_s = NA_real_,
      rel_frob = NA_real_, kappa = NA_real_,
      rel_frob_diag = NA_real_, rel_frob_offdiag_strong = NA_real_,
      rel_frob_offdiag_weak = NA_real_,
      flag_inflated = NA, flag_contracted = NA, degenerate = NA,
      silent_divergent = NA, silent_divergent_onesided = NA,
      max_abs_lambda_hat = NA_real_,
      tau2_hat = NA_real_, tau3_hat = NA_real_, max_abs_tau_error = NA_real_,
      testA_c_hat = NA_real_, testA_pass = NA, testA_vgh_partial = NA,
      testA_note = "", error = "", stringsAsFactors = FALSE
    )
  }

  row <- empty_row()
  if (is.null(truth_entry)) {
    row$error <- paste0("no frozen truth for ", g$truth, "_p", g$p)
    return(row)
  }

  ## ---- DGP (Design 122 SS3) ----
  set.seed(g$seed)
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
  row$error <- cond$warning %||% ""
  if (!is.null(cond$error)) {
    row$error <- paste0(row$error, if (nzchar(row$error)) " || " else "", cond$error)
  }

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
    ## gllvmTMB() itself abort (R/va-routing.R .va_route_build_fit gate), so
    ## any successfully returned object already has status == "healthy".
    ## There is therefore no in-band "guard_rejected"/"nonconvergence" state
    ## to report separately from "error" for this arm via the public route
    ## -- a genuine cross-arm instrument asymmetry (Design 122 F2), noted
    ## here rather than papered over.
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

## ==================================================== 4. smoke-first =======
smoke_cell <- sentinels[sentinels$label == "most_expensive", ]
smoke_g <- list(cell_id = smoke_cell$cell_id, label = smoke_cell$label,
                 family = smoke_cell$family, n = smoke_cell$n, p = smoke_cell$p,
                 truth = smoke_cell$truth, arm = "VGH", seed = 1L)

cat(sprintf("=== SMOKE: cell=%s family=%s n=%d p=%d truth=%s arm=VGH seed=1 ===\n",
            smoke_cell$label, smoke_cell$family, smoke_cell$n, smoke_cell$p, smoke_cell$truth))
smoke_t0 <- Sys.time()
smoke_row <- run_row(smoke_g, PKG_DIR, OUT, TRUTH_SEED_BASE)
smoke_wall <- as.numeric(difftime(Sys.time(), smoke_t0, units = "secs"))
print(smoke_row[, c("status", "converged", "wall_time_s", "rel_frob", "kappa",
                     "max_abs_lambda_hat", "testA_c_hat", "testA_pass", "error")])
cat(sprintf("Smoke wall: %.1f s (%.2f min)\n", smoke_wall, smoke_wall / 60))

## CORRECTED projection (the first attempt's own formula under-counted a
## real cost -- see RESULTS.md's "STOP RULE FIRED" section, item 2). The
## smoke fit runs SEQUENTIALLY, before daemons()/mirai_map() ever start; its
## own elapsed wall-clock is a sunk cost that must be ADDED to the grid's
## own projected wall, not folded into the same `waves * smoke_wall` term
## that also covers the PARALLEL remainder (the smoke row is reused, not
## refit, so it costs the grid stage nothing further -- but it already cost
## the launcher `smoke_wall` seconds before the grid stage even begins).
## fits_in_cell / workers) + overhead, taken over the most expensive cell (30
## fits: 10 seeds x 3 arms), using the measured VGH time as the ceiling for
## that cell (VGH is the unmeasured unknown this smoke exists to resolve;
## L0/L2 at this corner are expected far cheaper, c.f. Design 108 Stage 8's
## ~37s/fit at the ORIGINAL n=1600 corner, dev/design108-stage8/README.md --
## not directly comparable to this reduced n=400 corner, but an existence
## proof that Laplace-path arms are cheap here regardless).
fits_in_expensive_cell <- length(SEEDS) * 3L
waves <- ceiling(fits_in_expensive_cell / NWORK)
projected_expensive_cell_s <- waves * smoke_wall
## Remaining 90 fits across the 3 cheaper cells (n <= 400, p <= 27): budget
## 60 s/fit as an upper bound.
fits_remaining <- (nrow(sentinels) - 1L) * length(SEEDS) * 3L
projected_remaining_s <- ceiling(fits_remaining / NWORK) * 60
projected_total_s <- smoke_wall + projected_expensive_cell_s + projected_remaining_s + 30
cat(sprintf(
  "Projection (CORRECTED): sequential smoke=%.1fs; expensive-cell parallel wave fits=%d, waves=%d @ %.1fs => %.1fs; remaining %d fits => %.1fs; +30s overhead => TOTAL %.1fs (%.2f min)\n",
  smoke_wall, fits_in_expensive_cell, waves, smoke_wall, projected_expensive_cell_s,
  fits_remaining, projected_remaining_s, projected_total_s, projected_total_s / 60))

STOP_RULE_FIRED <- projected_total_s > 25 * 60
if (STOP_RULE_FIRED) {
  cat("\n*** D-139 STOP RULE FIRED: projected total exceeds 25 minutes. ***\n")
  cat("Writing smoke-only results and RESULTS.md inputs, NOT launching the full grid.\n")
  write.csv(smoke_row, file.path(OUT, "va-laplace-prerun.csv"), row.names = FALSE)
  saveRDS(list(smoke_row = smoke_row, smoke_wall = smoke_wall,
               projected_total_s = projected_total_s, stopped = TRUE),
          file.path(OUT, "va-laplace-prerun.rds"))
  quit(save = "no", status = 0)
}

cat("\nSmoke passed the stop-rule check. Proceeding to the full 120-fit grid.\n\n")

## ======================================================= 5. full grid ======
grid <- do.call(rbind, lapply(seq_len(nrow(sentinels)), function(i) {
  cell <- sentinels[i, ]
  eg <- expand.grid(cell_id = cell$cell_id, arm = c("L0", "L2", "VGH"), seed = SEEDS,
                     stringsAsFactors = FALSE)
  merge(eg, cell, by = "cell_id")
}))

grid_list <- split(grid, seq_len(nrow(grid)))
grid_list <- lapply(grid_list, function(r) as.list(r))

smoke_key <- paste(smoke_g$cell_id, "VGH", 1L)
key_of <- function(r) paste(r$cell_id, r$arm, r$seed)
smoke_idx <- which(vapply(grid_list, key_of, character(1)) == smoke_key)

cat(sprintf("Full grid: %d fits, workers=%d\n", length(grid_list), NWORK))

daemons(NWORK, dispatcher = TRUE)
on.exit(daemons(0), add = TRUE)

run_t0 <- Sys.time()
results <- vector("list", length(grid_list))
if (length(smoke_idx)) results[[smoke_idx]] <- smoke_row
todo <- setdiff(seq_along(grid_list), smoke_idx)

m <- mirai_map(grid_list[todo], run_row,
               .args = list(pkg_dir = PKG_DIR, out_dir = OUT,
                             truth_seed_base = TRUTH_SEED_BASE))[.progress]
for (j in seq_along(todo)) {
  results[[todo[j]]] <- tryCatch(m[[j]], error = function(e) NULL)
}

total_wall <- as.numeric(difftime(Sys.time(), run_t0, units = "secs"))
cat(sprintf("\n=== FULL GRID WALL: %.1f s (%.2f min) ===\n", total_wall, total_wall / 60))

ok <- vapply(results, function(r) is.data.frame(r) && nrow(r) == 1L, logical(1))
if (any(!ok)) {
  cat(sprintf("WARNING: %d of %d tasks returned no row (mirai task failure) -- recorded as a missing count, NOT silently dropped.\n",
              sum(!ok), length(results)))
}
final <- do.call(rbind, results[ok])

write.csv(final, file.path(OUT, "va-laplace-prerun.csv"), row.names = FALSE)
saveRDS(list(final = final, smoke_wall = smoke_wall,
             projected_total_s = projected_total_s, total_wall_s = total_wall,
             n_rows_ok = sum(ok), n_rows_total = length(grid_list)),
        file.path(OUT, "va-laplace-prerun.rds"))
cat(sprintf("Rows completed: %d / %d\n", nrow(final), length(grid_list)))
cat("status by arm:\n"); print(table(final$arm, final$status, useNA = "ifany"))
