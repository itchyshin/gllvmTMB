#!/usr/bin/env Rscript
## Gate 3 campaign runner -- VA joint-fit known-DGP recovery, pre-registered.
##
## READ FIRST AND TREAT AS FROZEN: docs/dev-log/2026-07-30-gate3-preregistration.md
## Design 85 Sec.11: "tolerances cannot be widened after seeing the result." This
## file implements that document exactly. docs/design/85-highdim-nongaussian-va-
## formal-contract.md SSSS10-11 bounds what any output built here may claim.
##
## Status as of 2026-07-30: BUILD-ONLY. This runner has been exercised on its one
## declared smoke cell (T-mid, q=2, p=8, n=100, seed=1) and nothing else. The full
## 1,440-cell / 4,320-fit campaign is explicitly blocked on a separate slice (S3)
## measuring whether the R/va-r3-proto.R:1271 variance-domain guard
## (`variance_domain_ok <- max_projected_variance <= 4`) is reachable under
## T-strong -- if it rejects T-strong outright it truncates the gate's own
## strong-signal arm. Do not launch the full grid before that slice reports.
##
## A sibling slice (2026-07-30) measured the guard directly on the existing
## 2,880-row totoro-grid and found it fires asymmetrically: gtmb_gh 93/640
## (14.5%) vs gtmb_jj 0/320 (0.0%), concentrated on GH's most-inflated fits. Two
## consequences baked into this file, not optional:
##   (a) NEVER filter rows on status == "ok" (or the engine's own "healthy") or
##       on health$admitted before computing recovery metrics -- doing so would
##       silently delete GH's high-variance tail while leaving JJ untouched,
##       manufacturing exactly the asymmetry the campaign exists to test. Every
##       metric below is computed from the fitted report whenever it exists and
##       is finite, regardless of status.
##   (b) `max_projected_variance` (continuous) and `variance_domain_ok` (the
##       frozen <=4 threshold applied to it) are recorded as their OWN columns,
##       separately from the multi-start agreement mechanism (`healthy_starts`,
##       `attempted_starts`, `objective_agreement`), so admission under any
##       alternative threshold is re-derivable later without re-fitting. The
##       <=4 threshold itself is untouched (frozen by a prior maintainer
##       decision; docs/dev-log/handover/2026-07-26-codex-handover-va-variance-
##       gate-close.md).
##
## Usage:
##   GATE3_SMOKE=TRUE Rscript dev/va-gate3/run-gate3.R    # one cell, one seed, 3 arms
##   Rscript dev/va-gate3/run-gate3.R                     # the full campaign (DO NOT
##                                                         # run until S3 clears -- see above)
## Env vars (all optional): GATE3_WORKERS (default 6), GATE3_FIT_SECONDS (default 900).
##
## Run from the repository root (this script locates itself relative to getwd()).
##
## Compute: LOCAL only (D-50). Never a GitHub Actions workflow or artifact.

suppressMessages({
  library(parallel)
  library(callr)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

PKG_DIR <- normalizePath(".")
if (!file.exists(file.path(PKG_DIR, "DESCRIPTION"))) {
  stop("run-gate3.R must be run from the gllvmTMB repository root (no DESCRIPTION found in ",
       PKG_DIR, ").", call. = FALSE)
}
## devtools::load_all(), not library(gllvmTMB): the installed package (0.5.0)
## predates recent va_r3/approximation-engine internals (confirmed: it lacks
## .vgh_fit, per test-vgh-oracle.R's known 11/12 failures against the
## installed build). library() here would silently run the whole campaign
## against stale code.
suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

OUT       <- file.path("dev", "va-gate3", "results")
OUT_CELLS <- file.path(OUT, "cells")
dir.create(OUT_CELLS, showWarnings = FALSE, recursive = TRUE)

SMOKE  <- isTRUE(as.logical(Sys.getenv("GATE3_SMOKE", "FALSE")))
NWORK  <- as.integer(Sys.getenv("GATE3_WORKERS", "6"))
FITSEC <- as.integer(Sys.getenv("GATE3_FIT_SECONDS", "900"))

## =========================================================== 1. truths ====
## Design section, "Fixed truths": three regimes (weak/mid/strong), each
## scaled so max|Lambda_0| hits an exact target. The pass-rule table crosses
## truth x q x p (Cell count formula: "3 truths x 2 q x 3 p x 2 n x 40
## seeds"), so a single p x q Lambda_0 per truth cannot satisfy every cell --
## one (Lambda_0, beta_0) pair is generated per (truth, q, p) combination
## (18 total), all under ONE set.seed(20260730) call in a fixed nested order,
## so the whole set is reproducible from that one seed. This resolves an
## underspecified generation order in the frozen prereg (which names "three
## Lambda_0" but a cell count that needs 18); see the handoff note on this.
TRUTH_NAMES <- c("T-weak", "T-mid", "T-strong")
TRUTH_TARGET_MAX <- c("T-weak" = 0.35, "T-mid" = 0.70, "T-strong" = 1.40)
Q_VALUES <- c(1L, 2L)
P_VALUES <- c(8L, 20L, 80L)
N_VALUES <- c(100L, 400L)
SEEDS    <- 1:40

.gate3_truth_key <- function(truth, q, p) sprintf("%s_q%d_p%d", truth, q, p)

## Raw entries rnorm(p*q, 0, 0.6), matching the existing (unfrozen) grid's
## Lambda convention that the prereg's "Fixed truths" section points at
## directly, then rescaled by one scalar so max(abs(.)) hits the target
## exactly. beta_0 ~ rnorm(p, 0.3, 0.3), matching the same existing grid's
## per-trait-intercept convention (dev/heywood, dev/scale, dev/totoro-grid) --
## the prereg freezes beta_0 "alongside" Lambda_0 but does not give its own
## recipe, so this reuses the one already established in this codebase.
.gate3_build_truths <- function() {
  set.seed(20260730L)
  truths <- list()
  for (truth in TRUTH_NAMES) {
    target <- TRUTH_TARGET_MAX[[truth]]
    for (q in Q_VALUES) {
      for (p in P_VALUES) {
        raw <- matrix(stats::rnorm(p * q, 0, 0.6), p, q)
        Lambda_0 <- raw / max(abs(raw)) * target
        beta_0 <- stats::rnorm(p, 0.3, 0.3)
        ## Rotate Lambda_0 into the SAME canonical lower-triangular basis the
        ## live packer uses for every fitted Lambda (verified directly:
        ## src/gllvmTMB.cpp's Lambda_B construction and
        ## .va_r3_unpack_theta_rr() both fill head(q) = diagonal, then the
        ## strict lower triangle column-major, strict upper exactly zero).
        ## Because both arms' FITTED Lambda already comes out in that basis,
        ## this is the only rotation Gate 3 ever needs: fitted Lambda vs this
        ## frozen Lambda_0_aligned, column-by-column, no per-fit Procrustes.
        Lambda_0_aligned <- gllvmTMB:::.va_r3_rotate_to_lower_triangular(Lambda_0, q)
        if (is.null(Lambda_0_aligned)) {
          stop("Truth ", truth, " q=", q, " p=", p, " failed the lower-",
               "triangular rotation check (near-singular top q x q block); ",
               "the frozen seed must be revisited, not silently redrawn.",
               call. = FALSE)
        }
        key <- .gate3_truth_key(truth, q, p)
        truths[[key]] <- list(
          truth = truth, q = q, p = p,
          target_max_abs_lambda0 = unname(target),
          Lambda_0 = Lambda_0,
          Lambda_0_aligned = Lambda_0_aligned,
          beta_0 = beta_0
        )
      }
    }
  }
  truths
}

.gate3_write_truths_md <- function(truths, rds_path, md_path) {
  checksum <- unname(tools::md5sum(rds_path))
  rows <- vapply(truths, function(e) {
    sprintf("| %s | %d | %d | %.6f | %.6f |",
            e$truth, e$q, e$p, e$target_max_abs_lambda0, max(abs(e$Lambda_0)))
  }, character(1))
  lines <- c(
    "# Gate 3 frozen truths",
    "",
    "Generated once under `set.seed(20260730)` by `.gate3_build_truths()` in",
    "`dev/va-gate3/run-gate3.R`, nested loop order truth x q x p (weak/mid/strong",
    "outer, q inner-outer, p innermost). Never regenerated: this file's own",
    "runner loads `truths.rds` unconditionally when it already exists.",
    "",
    sprintf("`truths.rds` md5sum: `%s`", checksum),
    "",
    "| truth | q | p | target max\\|Lambda_0\\| | actual max\\|Lambda_0\\| |",
    "|---|---|---|---|---|",
    rows
  )
  writeLines(lines, md_path)
}

TRUTHS_FILE <- file.path("dev", "va-gate3", "truths.rds")
TRUTHS_MD   <- file.path("dev", "va-gate3", "truths.md")
if (file.exists(TRUTHS_FILE)) {
  truths <- readRDS(TRUTHS_FILE)
} else {
  truths <- .gate3_build_truths()
  saveRDS(truths, TRUTHS_FILE)
  .gate3_write_truths_md(truths, TRUTHS_FILE, TRUTHS_MD)
}

## =========================================================== 2. grid ======
grid <- expand.grid(truth = TRUTH_NAMES, q = Q_VALUES, p = P_VALUES, n = N_VALUES,
                     seed = SEEDS, stringsAsFactors = FALSE)
grid$cell_id <- seq_len(nrow(grid))
if (SMOKE) {
  grid <- grid[grid$truth == "T-mid" & grid$q == 2L & grid$p == 8L &
               grid$n == 100L & grid$seed == 1L, ]
}

## ================================================ 3. data-generation ======
## Injective combined seed over (truth, q, p, n, seed) so every cell draws an
## independent stream -- mirrors dev/heywood/vgh-vs-laplace-degeneracy.R:44's
## `seed*4021 + n*19 + p` technique (named in the brief as the pattern to
## mirror for "both arms see identical data"), extended with two more mixed-
## radix digits for the truth and q factors this design adds. Each digit's
## multiplier exceeds the maximum possible sum of all lower digits, so the
## mapping is provably 1:1: no two distinct (truth,q,p,n,seed) tuples can
## collide on the same set.seed() value.
.gate3_cell_seed <- function(truth, q, p, n, seed) {
  truth_id <- match(truth, TRUTH_NAMES)
  p_idx <- match(p, P_VALUES)
  n_idx <- match(n, N_VALUES)
  as.integer(seed + 100L * (truth_id - 1L) + 1000L * (q - 1L) +
             10000L * (p_idx - 1L) + 1000000L * (n_idx - 1L))
}

## unit-major / trait-minor flatten throughout (as.numeric(t(.))), matching
## .va_r3_validate_data's cell-ordering requirement and the long-format data
## frame the ml_laplace arm below is built from -- one shared representation,
## not three independently-constructed ones, is what makes the data byte-
## identical across arms by construction rather than by careful bookkeeping.
.gate3_draw_cell_data <- function(truth_entry, n, seed) {
  q <- truth_entry$q
  p <- truth_entry$p
  set.seed(.gate3_cell_seed(truth_entry$truth, q, p, n, seed))
  U <- matrix(stats::rnorm(n * q), n, q)
  eta_true  <- sweep(U %*% t(truth_entry$Lambda_0), 2, truth_entry$beta_0, "+")  # n x p
  prob_true <- stats::plogis(eta_true)
  ## n_trials = 1 exactly: frozen prereg Design section AND this task's own
  ## instruction both specify it explicitly. FLAGGED, not silently resolved:
  ## Design 85 Sec.2's data contract requires n_it in {2,3,...} and explicitly
  ## prohibits "single-trial Bernoulli rows" -- n_trials = 1 is exactly that.
  ## The va_r3 engine's own validator (.va_r3_validate_data) does not reject
  ## n_trials = 1 (it only requires n_trials >= 1), so nothing breaks
  ## mechanically; the conflict is with the FORMAL CONTRACT's stated scope,
  ## not with any code path here. See the handoff note; implemented exactly
  ## as both the prereg and the task instruction specify, not "improved."
  Y <- matrix(stats::rbinom(n * p, size = 1L, prob = as.numeric(prob_true)), n, p)
  list(
    yv = as.numeric(t(Y)),
    trait_id = rep(seq_len(p), times = n),
    unit_id  = rep(seq_len(n), each = p),
    n_trials = rep(1L, n * p),
    p_true_flat = as.numeric(t(prob_true)),
    p = p, n = n, q = q
  )
}

## ================================================== 4. recovery metrics ===
.gate3_empty_metrics <- function() {
  list(
    beta_bias = NA_real_, beta_rmse = NA_real_,
    sigma_relfrob = NA_real_, sigma_relfrob_diag = NA_real_,
    sigma_relfrob_offdiag_strong = NA_real_, sigma_relfrob_offdiag_weak = NA_real_,
    kappa = NA_real_, fitted_prob_rmse = NA_real_, lambda_aligned_rmse = NA_real_,
    axis1_collapsed = NA, axis2_collapsed = NA, any_axis_collapsed = NA
  )
}

.gate3_stratum_relfrob <- function(Sigma_hat, Sigma_true, idx) {
  if (!is.matrix(idx) || nrow(idx) == 0L) return(NA_real_)
  den <- sqrt(sum(Sigma_true[idx]^2))
  if (!is.finite(den) || den == 0) return(NA_real_)
  sqrt(sum((Sigma_hat[idx] - Sigma_true[idx])^2)) / den
}

## Computed whenever Lambda_hat/beta_hat/phat exist and are finite --
## REGARDLESS of the fit's status/admitted flag (see the file header: never
## filter on health before this point). truth_entry$Lambda_0_aligned is
## already in the shared canonical basis (built once in section 1); a fitted
## Lambda_hat from either arm needs no further rotation, only a per-column
## sign resolution (Design 85 Sec.6: the lower-triangular constraint removes
## continuous rotation but leaves axis-sign reflections).
.gate3_compute_metrics <- function(Lambda_hat, beta_hat, phat_flat, truth_entry, p_true_flat) {
  m <- .gate3_empty_metrics()
  q <- truth_entry$q
  p <- truth_entry$p
  if (is.null(Lambda_hat) || !is.matrix(Lambda_hat) || !all(is.finite(Lambda_hat)) ||
      nrow(Lambda_hat) != p || ncol(Lambda_hat) != q) {
    return(m)
  }
  Lambda_true <- truth_entry$Lambda_0_aligned
  beta_true   <- truth_entry$beta_0

  if (!is.null(beta_hat) && length(beta_hat) == length(beta_true) && all(is.finite(beta_hat))) {
    err <- beta_hat - beta_true
    m$beta_bias <- mean(err)
    m$beta_rmse <- sqrt(mean(err^2))
  }

  Sigma_hat  <- tcrossprod(Lambda_hat)
  Sigma_true <- tcrossprod(Lambda_true)
  nt <- norm(Sigma_true, "F")
  if (is.finite(nt) && nt > 0) {
    ## Overall (unstratified) relative Frobenius error -- this is the exact
    ## quantity the pass rule's RMSE_arm formula is defined on ("The pass
    ## rule -- quoted, not paraphrased" section item 1). The (a)/(b)/(c)
    ## stratified breakdown below is the SEPARATE, ADDITIONAL "Estimands"
    ## reporting requirement -- descriptive, not the pass-rule input.
    m$sigma_relfrob <- norm(Sigma_hat - Sigma_true, "F") / nt
    m$kappa <- sum(diag(Sigma_hat)) / sum(diag(Sigma_true))

    diag_idx  <- cbind(seq_len(p), seq_len(p))
    upper_idx <- which(row(Sigma_true) < col(Sigma_true), arr.ind = TRUE)
    if (nrow(upper_idx) > 0L) {
      strong <- abs(Sigma_true[upper_idx]) >= 0.1
      m$sigma_relfrob_diag <- .gate3_stratum_relfrob(Sigma_hat, Sigma_true, diag_idx)
      if (any(strong)) {
        m$sigma_relfrob_offdiag_strong <-
          .gate3_stratum_relfrob(Sigma_hat, Sigma_true, upper_idx[strong, , drop = FALSE])
      }
      if (any(!strong)) {
        m$sigma_relfrob_offdiag_weak <-
          .gate3_stratum_relfrob(Sigma_hat, Sigma_true, upper_idx[!strong, , drop = FALSE])
      }
    } else {
      m$sigma_relfrob_diag <- .gate3_stratum_relfrob(Sigma_hat, Sigma_true, diag_idx)
    }
  }

  if (!is.null(phat_flat) && !is.null(p_true_flat) &&
      length(phat_flat) == length(p_true_flat) && all(is.finite(phat_flat))) {
    m$fitted_prob_rmse <- sqrt(mean((phat_flat - p_true_flat)^2))
  }

  Lambda_hat_signed <- Lambda_hat
  for (k in seq_len(q)) {
    if (sum(Lambda_hat[, k] * Lambda_true[, k]) < 0) Lambda_hat_signed[, k] <- -Lambda_hat[, k]
  }
  nl <- norm(Lambda_true, "F")
  if (is.finite(nl) && nl > 0) {
    m$lambda_aligned_rmse <- norm(Lambda_hat_signed - Lambda_true, "F") / nl
  }

  ## Planted-axis collapse: column norm in the shared canonical basis, not a
  ## fresh SVD (which would re-mix axes and undo the alignment above). "its
  ## aligned singular value" in the frozen prereg is operationalised here as
  ## this column norm -- flagged as an interpretation call in the handoff,
  ## since a 1-column block's only singular value already equals its norm,
  ## so this is well-defined for q=1 and is the natural per-axis analogue at
  ## q=2 given the shared-basis construction above.
  s_true <- sqrt(colSums(Lambda_true^2))
  s_hat  <- sqrt(colSums(Lambda_hat^2))
  collapsed <- s_hat < 0.10 * s_true
  m$axis1_collapsed <- collapsed[1]
  m$axis2_collapsed <- if (q >= 2L) collapsed[2] else NA
  m$any_axis_collapsed <- any(collapsed)

  m
}

## ==================================================== 5. row builder ======
.gate3_extra_defaults <- list(
  max_projected_variance = NA_real_, variance_domain_ok = NA,
  healthy_starts = NA_integer_, attempted_starts = NA_integer_,
  objective_agreement = NA, best_three_objective_range = NA_real_,
  admitted = NA, source_commit = NA_character_, source_checksum = NA_character_,
  convergence_code = NA_integer_, pd_hess = NA
)

make_row <- function(arm, truth_entry, n, seed, status, seconds, detail = "",
                      Lambda_hat = NULL, beta_hat = NULL, phat_flat = NULL,
                      p_true_flat = NULL, extra = list()) {
  metrics <- .gate3_compute_metrics(Lambda_hat, beta_hat, phat_flat, truth_entry, p_true_flat)
  base <- data.frame(
    truth = truth_entry$truth, q = truth_entry$q, p = truth_entry$p,
    n = n, seed = seed, arm = arm, status = status, seconds = seconds,
    detail = detail, stringsAsFactors = FALSE
  )
  ed <- .gate3_extra_defaults
  ed[names(extra)] <- extra
  cbind(base, as.data.frame(metrics, stringsAsFactors = FALSE),
        as.data.frame(ed, stringsAsFactors = FALSE), stringsAsFactors = FALSE)
}

extract_va_fields <- function(res) {
  er <- res$engine_result
  rp <- er$report
  Lambda_hat <- if (is.list(rp) && !is.null(rp$Lambda)) as.matrix(rp$Lambda) else NULL
  beta_hat <- NULL
  if (!is.null(er$best$par)) {
    nm <- names(er$best$par)
    if (!is.null(nm)) beta_hat <- unname(er$best$par[nm == "beta"])
  }
  phat_flat <- if (is.list(rp) && !is.null(rp$mu_by_obs)) {
    stats::plogis(as.numeric(rp$mu_by_obs))
  } else NULL
  list(Lambda_hat = Lambda_hat, beta_hat = beta_hat, phat_flat = phat_flat)
}

extract_laplace_fields <- function(fit) {
  Lambda_hat <- tryCatch(as.matrix(fit$report$Lambda_B), error = function(e) NULL)
  beta_hat   <- tryCatch(gllvmTMB:::.gllvmTMB_b_fix_values(fit), error = function(e) NULL)
  phat_flat  <- tryCatch(stats::plogis(as.numeric(fit$report$eta)), error = function(e) NULL)
  list(Lambda_hat = Lambda_hat, beta_hat = beta_hat, phat_flat = phat_flat)
}

## ============================================ 6. per-fit budget machinery =
## Two tiers, mirroring dev/scale/run-scale.R's proven split (its own header
## documents WHY at length): ml_laplace is compiled once at package INSTALL
## time, so a fresh callr::r(timeout=) subprocess per call costs only spawn
## overhead. va_gh/va_jj share the va_r3 engine, which TMB::compile()s its
## template on the fly, PER R SESSION -- a fresh subprocess per call would
## recompile every single time (dev/scale measured ~20-60s/call for this).
## A persistent callr::r_session, created lazily and stashed in THIS FORKED
## WORKER's own .GlobalEnv, is reused across every task that worker
## processes (parallel::mclapply's default mc.preschedule=TRUE forks once
## per core and then loops that one process over its assigned tasks, so the
## session genuinely persists the way it needs to). Closed and recreated
## only after a real timeout/error, never routinely.
##
## Both subprocess functions devtools::load_all(pkg_dir) rather than
## library(gllvmTMB) -- see the file header on why library() is unsafe here.
## setTimeLimit() is not used anywhere in this file: dev/scale/SCALE.md:164-
## 167 records it hanging for 60+ minutes past its nominal budget on this
## exact workload, because R's elapsed-time check is cooperative and a TMB
## fit spends long stretches inside non-yielding C++ code.

.gate3_fit_va <- function(pkg_dir, yv, n_trials, X, unit_id, trait_id, q, eval_method, H) {
  suppressMessages(devtools::load_all(pkg_dir, quiet = TRUE))
  gllvmTMB:::.approximation_engine_fit(
    engine = "va_r3", y = yv, n_trials = n_trials, X = X,
    unit_id = unit_id, trait_id = trait_id, q = q,
    family = "binomial", link = "logit", H = H, eval_method = eval_method
  )
}

.gate3_fit_laplace <- function(pkg_dir, fml, data) {
  suppressMessages(devtools::load_all(pkg_dir, quiet = TRUE))
  gllvmTMB::gllvmTMB(fml, data = data, family = stats::binomial())
}

.gate3_get_va_session <- function() {
  sess <- mget(".gate3_va_session", envir = .GlobalEnv, ifnotfound = list(NULL))[[1]]
  if (is.null(sess)) {
    sess <- callr::r_session$new(wait = TRUE)
    assign(".gate3_va_session", sess, envir = .GlobalEnv)
  }
  sess
}

.gate3_kill_va_session <- function() {
  sess <- mget(".gate3_va_session", envir = .GlobalEnv, ifnotfound = list(NULL))[[1]]
  if (!is.null(sess)) try(sess$close(grace = 200), silent = TRUE)
  assign(".gate3_va_session", NULL, envir = .GlobalEnv)
}

.gate3_run_va_budget <- function(pkg_dir, args, budget) {
  t0 <- proc.time()[["elapsed"]]
  res <- tryCatch({
    sess <- .gate3_get_va_session()
    sess$call(.gate3_fit_va, c(list(pkg_dir = pkg_dir), args))
    state <- sess$poll_process(as.integer(budget * 1000))
    if (!identical(state, "ready")) stop("GATE3_TIMEOUT")
    out <- sess$read()
    if (!is.null(out$error)) stop(conditionMessage(out$error))
    out$result
  }, error = function(e) {
    msg <- conditionMessage(e)
    .gate3_kill_va_session()  # conservative: recreate after ANY error/timeout
    if (grepl("GATE3_TIMEOUT", msg, fixed = TRUE)) {
      structure(list(msg = "timeout"), class = "gate3_timeout")
    } else {
      structure(list(msg = msg), class = "gate3_error")
    }
  })
  list(v = res, secs = proc.time()[["elapsed"]] - t0)
}

.gate3_run_laplace_budget <- function(pkg_dir, fml, data, budget) {
  t0 <- proc.time()[["elapsed"]]
  res <- tryCatch({
    callr::r(.gate3_fit_laplace, args = list(pkg_dir = pkg_dir, fml = fml, data = data),
             timeout = budget,
             env = c(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1"))
  }, error = function(e) {
    msg <- conditionMessage(e)
    if (inherits(e, "callr_timeout_error") ||
        grepl("timed out|timeout", msg, ignore.case = TRUE)) {
      structure(list(msg = "timeout"), class = "gate3_timeout")
    } else {
      structure(list(msg = msg), class = "gate3_error")
    }
  })
  list(v = res, secs = proc.time()[["elapsed"]] - t0)
}

## ==================================================== 7. row assembly =====
.gate3_row_from_va_result <- function(arm, truth_entry, n, seed, r, p_true_flat) {
  if (inherits(r$v, "gate3_timeout")) {
    return(make_row(arm, truth_entry, n, seed, status = "error", seconds = r$secs,
                     detail = "timeout"))
  }
  if (inherits(r$v, "gate3_error")) {
    return(make_row(arm, truth_entry, n, seed, status = "error", seconds = r$secs,
                     detail = substr(r$v$msg, 1, 200)))
  }
  res <- r$v
  ## Exact match on the engine's own status string -- never a substring test
  ## (dev/totoro-grid/analyse-grid.R:100's grepl("...converged...") bug: an
  ## unanchored pattern matches "converged" INSIDE "not_converged").
  status <- switch(res$status %||% "",
    healthy = "ok",
    failed_variance_domain = "guard_rejected",
    failed_health_gate = "nonconvergence",
    "error"  # covers not_applicable_rank_zero (shouldn't occur: q always >= 1
             # here) and any unrecognised value -- fails closed, not silently ok
  )
  fields <- extract_va_fields(res)
  health <- res$engine_result$health %||% list()
  prov   <- res$provenance %||% list()
  extra <- list(
    max_projected_variance = health$max_projected_variance %||% NA_real_,
    variance_domain_ok = health$variance_domain_ok %||% NA,
    healthy_starts = health$healthy_starts %||% NA_integer_,
    attempted_starts = health$attempted_starts %||% NA_integer_,
    objective_agreement = health$objective_agreement %||% NA,
    best_three_objective_range = health$best_three_objective_range %||% NA_real_,
    admitted = health$admitted %||% NA,
    source_commit = prov$source_commit %||% NA_character_,
    source_checksum = prov$source_checksum %||% NA_character_
  )
  make_row(arm, truth_entry, n, seed, status = status, seconds = r$secs,
           detail = res$status %||% NA_character_,
           Lambda_hat = fields$Lambda_hat, beta_hat = fields$beta_hat,
           phat_flat = fields$phat_flat, p_true_flat = p_true_flat, extra = extra)
}

.gate3_row_from_laplace_result <- function(truth_entry, n, seed, r, p_true_flat) {
  if (inherits(r$v, "gate3_timeout")) {
    return(make_row("ml_laplace", truth_entry, n, seed, status = "error", seconds = r$secs,
                     detail = "timeout"))
  }
  if (inherits(r$v, "gate3_error")) {
    return(make_row("ml_laplace", truth_entry, n, seed, status = "error", seconds = r$secs,
                     detail = substr(r$v$msg, 1, 200)))
  }
  fit  <- r$v
  conv <- tryCatch(fit$opt$convergence, error = function(e) NA_integer_)
  pdh  <- tryCatch(isTRUE(fit$sd_report$pdHess), error = function(e) NA)
  status <- if (length(conv) != 1L || is.na(conv)) {
    "error"
  } else if (identical(as.integer(conv), 0L)) {
    "ok"
  } else {
    "nonconvergence"
  }
  fields <- extract_laplace_fields(fit)
  make_row("ml_laplace", truth_entry, n, seed, status = status, seconds = r$secs,
           detail = sprintf("convergence=%s pdHess=%s", conv, pdh),
           Lambda_hat = fields$Lambda_hat, beta_hat = fields$beta_hat,
           phat_flat = fields$phat_flat, p_true_flat = p_true_flat,
           extra = list(convergence_code = if (length(conv) == 1L) as.integer(conv) else NA_integer_,
                        pd_hess = pdh))
}

## ==================================================== 8. one task =========
## One task = one (truth,q,p,n,seed) cell -> one 3-row (va_gh, va_jj,
## ml_laplace) result, all three fit on byte-identical data (same yv,
## trait_id, unit_id, n_trials; the X used for the VA arms and the
## trait/site factors used for the ml_laplace formula are built from those
## SAME vectors, not reconstructed separately). Persisted immediately
## (dev/scale/run-scale.R:303's pattern) so a killed run loses only its
## in-flight cell; re-running the same invocation skips any cell whose
## output file already exists, so the run resumes rather than restarting.
run_task <- function(task_row, truths, pkg_dir, out_cells, fitsec) {
  outfile <- file.path(out_cells, sprintf("cell_%05d.rds", task_row$cell_id))
  if (file.exists(outfile)) return(invisible(NULL))

  truth_entry <- truths[[.gate3_truth_key(task_row$truth, task_row$q, task_row$p)]]
  if (is.null(truth_entry)) stop("Unknown truth/q/p combination for cell ", task_row$cell_id)

  d <- .gate3_draw_cell_data(truth_entry, task_row$n, task_row$seed)
  X <- stats::model.matrix(~ 0 + factor(d$trait_id, levels = seq_len(task_row$p)))

  rows <- list()

  r <- .gate3_run_va_budget(pkg_dir,
    list(yv = d$yv, n_trials = d$n_trials, X = X, unit_id = d$unit_id,
         trait_id = d$trait_id, q = task_row$q, eval_method = "gh", H = 15L),
    fitsec)
  rows[["va_gh"]] <- .gate3_row_from_va_result("va_gh", truth_entry, task_row$n,
                                                task_row$seed, r, d$p_true_flat)

  r <- .gate3_run_va_budget(pkg_dir,
    list(yv = d$yv, n_trials = d$n_trials, X = X, unit_id = d$unit_id,
         trait_id = d$trait_id, q = task_row$q, eval_method = "jj", H = 15L),
    fitsec)
  rows[["va_jj"]] <- .gate3_row_from_va_result("va_jj", truth_entry, task_row$n,
                                                task_row$seed, r, d$p_true_flat)

  df <- data.frame(
    y = d$yv,
    trait = factor(d$trait_id, levels = seq_len(task_row$p)),
    site  = factor(d$unit_id,  levels = seq_len(task_row$n))
  )
  fml <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)", task_row$q))
  environment(fml) <- globalenv()  # don't drag d/X/truths into the callr args via closure
  r <- .gate3_run_laplace_budget(pkg_dir, fml, df, fitsec)
  rows[["ml_laplace"]] <- .gate3_row_from_laplace_result(truth_entry, task_row$n,
                                                          task_row$seed, r, d$p_true_flat)

  result <- do.call(rbind, rows)
  saveRDS(result, outfile)
  invisible(result)
}

## ==================================================== 9. warm-up ==========
## In-process (NOT a callr call): forces .va_r3_load_dll() to compile+
## dyn.load() the va_r3 TMB template ONCE, here, in the master, before
## mclapply forks. Every forked child inherits the compiled/loaded DLL via
## ordinary fork() copy-on-write semantics, so no worker (and no callr
## session any worker later creates against the same cached build directory
## under tempdir()) pays a redundant compile. Must run before the mclapply
## call below, not inside any task.
.gate3_warmup <- function() {
  p <- 2L; q <- 1L; n <- 3L
  trait_id <- rep(seq_len(p), times = n)
  unit_id  <- rep(seq_len(n), each = p)
  X <- stats::model.matrix(~ 0 + factor(trait_id, levels = seq_len(p)))
  yv <- rep(c(0L, 1L), length.out = n * p)
  invisible(try(gllvmTMB:::.approximation_engine_fit(
    engine = "va_r3", y = yv, n_trials = rep(1L, n * p), X = X,
    unit_id = unit_id, trait_id = trait_id, q = q,
    family = "binomial", link = "logit", H = 15L, eval_method = "gh"
  ), silent = TRUE))
}
.gate3_warmup()

## ==================================================== 10. dispatch ========
tasks <- split(grid, grid$cell_id)
cat(sprintf("gate3: %d task(s) (%d fits), %d worker(s), fit budget %ds, smoke=%s\n",
            length(tasks), length(tasks) * 3L, NWORK, FITSEC, SMOKE))

t0 <- proc.time()[["elapsed"]]
invisible(parallel::mclapply(tasks, run_task, truths = truths, pkg_dir = PKG_DIR,
                              out_cells = OUT_CELLS, fitsec = FITSEC,
                              mc.cores = NWORK, mc.preschedule = TRUE))
elapsed <- proc.time()[["elapsed"]] - t0

## ==================================================== 11. combine =========
## Reads back EVERY cell file present (not just the ones this invocation
## produced), so a resumed run's report reflects the full accumulated state.
files <- list.files(OUT_CELLS, pattern = "^cell_[0-9]+\\.rds$", full.names = TRUE)
out <- do.call(rbind, lapply(files, readRDS))
tag <- if (SMOKE) "smoke" else "gate3"
saveRDS(out, file.path(OUT, sprintf("%s.rds", tag)))
utils::write.csv(out, file.path(OUT, sprintf("%s.csv", tag)), row.names = FALSE)

cat(sprintf("\nDONE in %.1fs this invocation | cell files on disk: %d/%d | rows: %d\n",
            elapsed, length(files), nrow(grid), nrow(out)))
cat("status by arm (exact labels: ok/error/nonconvergence/guard_rejected):\n")
print(table(out$arm, out$status, useNA = "ifany"))
cat("\nhead:\n")
print(utils::head(out, 12))
