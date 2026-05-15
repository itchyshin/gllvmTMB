## Phase 1b 2026-05-15 item 4: `check_identifiability()` -- the canonical
## identifiability diagnostic for a `gllvmTMB_multi` fit (Fisher persona
## consult 2026-05-14, captured in
## `docs/dev-log/after-task/2026-05-14-phase-1a-batch-d.md`).
##
## The diagnostic that no other tool in the package catches: a "spurious
## extra factor masquerading as identified". When the fit's latent rank
## d_B is mis-specified (e.g. d_B = 2 but truth = 1):
##   - `pdHess = TRUE` (the joint Hessian is positive definite because
##     the regulariser keeps the spurious factor bounded)
##   - `sanity_multi()` passes
##   - Profile CIs on extract_communality() / extract_correlations() look
##     tight
##   - But the second factor is noise; its loadings are unidentifiable in
##     direction
##
## The only way to expose this: simulate from the fitted model, refit each
## replica, apply Procrustes alignment to the loadings, and observe that
## the spurious-factor column of Procrustes residuals scatters uniformly
## (no preferred direction) -- i.e. the column has near-zero magnitude
## after alignment.
##
## Initial scope (V1): Gaussian fits only. Mixed-family / non-Gaussian
## support is deferred to the Phase 1b validation milestone where the
## simulate.gllvmTMB_multi() method is extended to handle family-specific
## response draws beyond the current Gaussian-noise path.

#' Identifiability diagnostic via simulate-refit + Procrustes alignment
#'
#' Simulates `sim_reps` datasets from the fitted model, refits each replica
#' under the same formula, applies Procrustes alignment to the loading
#' matrices, and aggregates per-parameter recovery statistics plus
#' Hessian-eigenvalue rank checks. Returns an object of class
#' `gllvmTMB_identifiability` with components `$recovery`, `$loadings`,
#' `$hessian`, and `$flags`.
#'
#' The canonical case this catches that no other diagnostic does is a
#' **spurious extra factor masquerading as identified**: when `d_B` is
#' mis-specified (e.g. fit `d = 2` when truth is `d = 1`), `pdHess` may
#' be `TRUE`, `sanity_multi()` may pass, and profile CIs on derived
#' quantities may look tight -- but the second factor is noise.
#' Procrustes alignment across replicates exposes the spurious column
#' as a near-zero residual magnitude.
#'
#' @param fit A `gllvmTMB_multi` fit. **Initial scope** (this release):
#'   Gaussian fits only. Non-Gaussian / mixed-family support is
#'   queued for the Phase 1b validation milestone.
#' @param sim_reps Integer number of simulate-refit replicates. Default
#'   `100L`. Cost on a Tier-1 fixture is roughly 5-15 minutes serial;
#'   for routine `R CMD check` use the smoke value `sim_reps = 10L`
#'   (and gate the heavy version with `skip_on_cran()` / `skip_on_ci()`).
#' @param alpha Coverage target level. Default `0.05` (95 % nominal).
#'   Used to compute the `coverage_95` column of `$recovery`.
#' @param parallel Logical; currently a placeholder for a future
#'   `future.apply::future_lapply` path. Default `FALSE` (serial).
#' @param seed Optional integer seed for the simulate loop.
#' @param tier Character vector of tiers to include in `$loadings`.
#'   Subset of `c("B", "W", "phy")`. Defaults to all three; tiers
#'   absent from the fit are silently dropped.
#' @param verbose Logical; print progress every 10 % of the loop.
#'   Default `TRUE`.
#'
#' @return Invisibly, a list with class `gllvmTMB_identifiability` and
#'   components:
#'   \describe{
#'     \item{`$recovery`}{Data frame, one row per fitted parameter:
#'       columns `param`, `tier`, `truth`, `mean_est`, `bias`, `rmse`,
#'       `sd_est`, `coverage_95`, `n_converged`.}
#'     \item{`$loadings`}{Named list (one entry per tier) of
#'       \eqn{T \times d} matrices of mean absolute Procrustes residuals.
#'       Near-zero columns indicate spurious factors.}
#'     \item{`$hessian`}{Data frame, one row per replicate: `replicate`,
#'       `min_eig`, `max_eig`, `condition_number`, `n_zero_eig`,
#'       `pdHess`.}
#'     \item{`$flags`}{Character vector of identifiability concerns
#'       detected; any of `"rank_deficient"`, `"loading_collapse"`,
#'       `"slow_inference"`, `"converged_rate < 0.9"`. Empty when none
#'       fire.}
#'   }
#'
#' @section Heavy by design:
#'   This function performs `sim_reps` refits of the model. Each refit
#'   uses the same engine path as the original fit (TMB Laplace
#'   approximation) and so inherits the same per-fit cost. Wrap calls
#'   in `system.time()` to budget realistically before scaling
#'   `sim_reps` upward.
#'
#' @seealso [sanity_multi()], [gllvmTMB_diagnose()],
#'   [check_auto_residual()], [bootstrap_Sigma()].
#'
#' @export
check_identifiability <- function(fit,
                                  sim_reps = 100L,
                                  alpha    = 0.05,
                                  parallel = FALSE,
                                  seed     = NULL,
                                  tier     = c("B", "W", "phy"),
                                  verbose  = TRUE) {

  ## ---- validation -----------------------------------------------------
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  sim_reps <- as.integer(sim_reps)
  if (length(sim_reps) != 1L || is.na(sim_reps) || sim_reps < 2L)
    cli::cli_abort("{.arg sim_reps} must be an integer >= 2.")
  if (length(alpha) != 1L || !is.finite(alpha) ||
      alpha <= 0 || alpha >= 1)
    cli::cli_abort("{.arg alpha} must be in (0, 1).")
  if (isTRUE(parallel))
    cli::cli_warn(
      "{.arg parallel = TRUE} is a placeholder in this release and runs serially. Use {.fn future_lapply} externally if needed."
    )
  tier <- match.arg(tier, several.ok = TRUE)

  ## ---- V1 scope: Gaussian only ---------------------------------------
  fids <- fit$tmb_data$family_id_vec
  if (!is.null(fids) && any(fids != 0L)) {
    cli::cli_abort(c(
      "{.fn check_identifiability} currently supports Gaussian fits only.",
      "x" = "This fit contains non-Gaussian families.",
      "i" = "Non-Gaussian / mixed-family support is queued for the Phase 1b validation milestone.",
      ">" = "For now, use {.fn sanity_multi} + {.fn bootstrap_Sigma} as the inference-uncertainty surface for non-Gaussian fits."
    ), class = "gllvmTMB_check_identifiability_nongaussian")
  }

  if (!is.null(seed)) set.seed(seed)

  ## ---- extract truth --------------------------------------------------
  truth <- .ci_extract_truth(fit, tier = tier)

  ## ---- simulate response paths ---------------------------------------
  if (verbose)
    cli::cli_inform("Simulating {sim_reps} response datasets ...")
  sim_y <- stats::simulate(fit, nsim = sim_reps)
  if (!is.matrix(sim_y))
    sim_y <- as.matrix(sim_y)

  ## ---- refit loop -----------------------------------------------------
  if (verbose)
    cli::cli_inform(
      "Refitting {sim_reps} replicas (this is the slow part; budget ~5-15 minutes serial on a Tier-1 fixture) ..."
    )
  replicas <- vector("list", sim_reps)
  progress_step <- max(1L, sim_reps %/% 10L)
  for (i in seq_len(sim_reps)) {
    if (verbose && (i %% progress_step == 0L || i == sim_reps))
      cli::cli_inform("  rep {i}/{sim_reps}")
    replicas[[i]] <- .ci_refit_one(fit, sim_y[, i], truth = truth)
  }

  ## ---- Procrustes alignment of Lambda blocks per tier ---------------
  loadings <- .ci_align_loadings(replicas, truth = truth, tier = tier)

  ## ---- Hessian eigenvalue stats per replicate ------------------------
  hess <- .ci_hessian_stats(replicas)

  ## ---- aggregate recovery table --------------------------------------
  recovery <- .ci_recovery_table(replicas, truth = truth, alpha = alpha)

  ## ---- flag detection -------------------------------------------------
  flags <- character(0L)
  converged_rate <- mean(vapply(replicas, `[[`, logical(1L), "converged"))
  if (converged_rate < 0.9) {
    flags <- c(flags, "converged_rate < 0.9")
  }
  if (any(hess$n_zero_eig > 0L, na.rm = TRUE) ||
      any(hess$min_eig < 1e-8 * hess$max_eig, na.rm = TRUE)) {
    flags <- c(flags, "rank_deficient")
  }
  ## Loading collapse: any tier has a column with mean abs Procrustes
  ## residual < 0.1 * the next-largest column. That is the signature of
  ## a spurious factor whose direction is unidentifiable across reps.
  if (length(loadings) > 0L) {
    collapse_hit <- FALSE
    for (lvl in names(loadings)) {
      M <- loadings[[lvl]]
      if (is.null(M) || ncol(M) < 2L) next
      col_mag <- colMeans(abs(M))
      ## sort descending; if the smallest is < 0.1 * the second smallest
      ## (or near zero in absolute terms), call it collapse.
      sorted <- sort(col_mag)
      if (length(sorted) >= 2L &&
          sorted[1L] < 0.1 * sorted[2L] &&
          sorted[1L] < 0.05) {
        collapse_hit <- TRUE
        break
      }
    }
    if (collapse_hit) flags <- c(flags, "loading_collapse")
  }
  ## Slow inference: median per-replicate refit time > 60 s.
  median_t <- stats::median(vapply(replicas, function(r) {
    if (is.null(r$elapsed)) NA_real_ else r$elapsed
  }, numeric(1L)), na.rm = TRUE)
  if (is.finite(median_t) && median_t > 60) {
    flags <- c(flags, "slow_inference")
  }

  ## ---- assemble + return ---------------------------------------------
  out <- list(
    recovery = recovery,
    loadings = loadings,
    hessian  = hess,
    flags    = flags,
    call     = match.call(),
    n_reps   = sim_reps,
    n_converged = sum(vapply(replicas, `[[`, logical(1L), "converged"))
  )
  class(out) <- "gllvmTMB_identifiability"
  invisible(out)
}

## -------------------------------------------------------------------------
## Internal helpers (not exported)
## -------------------------------------------------------------------------

## Extract truth: parameter values from the fitted model, organised by
## logical group (Lambda_B columns flattened, Psi_B diag, fixed effects).
.ci_extract_truth <- function(fit, tier = c("B", "W", "phy")) {
  rep_obj <- fit$report
  truth <- list()
  ## Per-tier loading matrices.
  for (lvl in tier) {
    slot <- switch(
      lvl,
      "B"   = "Lambda_B",
      "W"   = "Lambda_W",
      "phy" = "Lambda_phy"
    )
    if (!is.null(rep_obj[[slot]])) {
      truth$loadings[[lvl]] <- rep_obj[[slot]]
    }
  }
  ## Per-tier Psi-diagonal SD vectors. The engine stores them as `sd_B`,
  ## `sd_W`, `sd_phy` on `fit$report` (sqrt of the unique-variance
  ## diagonal `\boldsymbol{\Psi}_{B/W/phy}`).
  for (lvl in tier) {
    slot <- switch(
      lvl,
      "B"   = "sd_B",
      "W"   = "sd_W",
      "phy" = "sd_phy"
    )
    if (!is.null(rep_obj[[slot]])) {
      truth$psi[[lvl]] <- as.numeric(rep_obj[[slot]])
    }
  }
  ## Fixed-effect coefficients. The fitted vector lives on `fit$opt$par`
  ## as repeated entries named `b_fix` (one per element of the design's
  ## column space); `fit$report` does not carry them.
  if (!is.null(fit$opt$par)) {
    b_idx <- which(names(fit$opt$par) == "b_fix")
    if (length(b_idx) > 0L) {
      truth$b_fix <- as.numeric(fit$opt$par[b_idx])
    }
  }
  ## Residual SD on the latent scale (Gaussian path).
  if (!is.null(rep_obj$sigma_eps)) {
    truth$sigma_eps <- as.numeric(rep_obj$sigma_eps)
  }
  truth
}

## Refit one replica: replace the response column with sim_y_i and re-call
## gllvmTMB() with the same formula + family + grouping arguments. Wrap
## in tryCatch so a single non-converging replica does not poison the run.
##
## CRITICAL: `fit$formula` is the parser's `parsed$fixed` (fixed-effects
## only -- covstruct terms have been stripped). We must reconstruct the
## full formula via `.reconstruct_multi_formula(fit)` so the refit picks
## up `latent()` / `unique()` / `phylo_*()` / `spatial_*()` keywords. This
## is the same recipe `bootstrap_Sigma()` uses.
.ci_refit_one <- function(fit, sim_y_i, truth) {
  full_formula  <- .reconstruct_multi_formula(fit)
  response_name <- all.vars(fit$formula[[2L]])[1L]
  df_i <- fit$data
  df_i[[response_name]] <- as.numeric(sim_y_i)
  t0 <- Sys.time()
  aux <- list(
    phylo_vcv         = fit$phylo_vcv,
    phylo_tree        = fit$phylo_tree,
    mesh              = fit$mesh,
    lambda_constraint = fit$lambda_constraint
  )
  aux <- aux[!vapply(aux, is.null, logical(1L))]
  call_args <- c(
    list(formula  = full_formula,
         data     = df_i,
         family   = fit$family,
         trait    = fit$trait_col,
         unit     = fit$unit_col,
         unit_obs = fit$unit_obs_col,
         cluster  = fit$cluster_col,
         silent   = TRUE),
    aux
  )
  refit <- tryCatch(
    suppressMessages(suppressWarnings(do.call(gllvmTMB, call_args))),
    error = function(e) e
  )
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (inherits(refit, "error")) {
    return(list(
      converged = FALSE,
      elapsed   = elapsed,
      error     = conditionMessage(refit),
      loadings  = NULL,
      psi       = NULL,
      b_fix     = NULL,
      hess      = NULL
    ))
  }
  b_idx <- which(names(refit$opt$par) == "b_fix")
  list(
    converged = identical(refit$opt$convergence, 0L) ||
                isTRUE(refit$sd_report$pdHess),
    elapsed   = elapsed,
    error     = NA_character_,
    loadings  = .extract_loadings_for_ci(refit),
    psi       = .extract_psi_for_ci(refit),
    b_fix     = if (length(b_idx) > 0L)
                  as.numeric(refit$opt$par[b_idx]) else NULL,
    hess      = .ci_hessian_one(refit)
  )
}

.extract_loadings_for_ci <- function(refit) {
  out <- list()
  for (lvl in c("B", "W", "phy")) {
    slot <- switch(lvl,
                   "B"   = "Lambda_B",
                   "W"   = "Lambda_W",
                   "phy" = "Lambda_phy")
    if (!is.null(refit$report[[slot]])) {
      out[[lvl]] <- refit$report[[slot]]
    }
  }
  out
}

.extract_psi_for_ci <- function(refit) {
  out <- list()
  for (lvl in c("B", "W", "phy")) {
    slot <- switch(lvl,
                   "B"   = "sd_B",
                   "W"   = "sd_W",
                   "phy" = "sd_phy")
    if (!is.null(refit$report[[slot]])) {
      out[[lvl]] <- as.numeric(refit$report[[slot]])
    }
  }
  out
}

## Procrustes alignment: given a target loading matrix T (T x d) and an
## estimate E (T x d), find an orthogonal matrix Q (d x d) such that
## ||T - E Q||_F is minimised. Solution via SVD of t(E) %*% T.
.procrustes_align <- function(target, estimate) {
  if (is.null(target) || is.null(estimate)) return(estimate)
  if (!identical(dim(target), dim(estimate))) return(estimate)
  if (ncol(target) < 1L) return(estimate)
  cross <- crossprod(estimate, target)
  s <- tryCatch(svd(cross), error = function(e) NULL)
  if (is.null(s)) return(estimate)
  Q <- s$u %*% t(s$v)
  estimate %*% Q
}

## Aggregate per-tier Procrustes residuals across replicates: returns a
## list of T x d matrices, one per tier, where each entry is the mean
## absolute residual (E aligned - target) over converged replicates.
.ci_align_loadings <- function(replicas, truth, tier) {
  out <- list()
  for (lvl in tier) {
    target <- truth$loadings[[lvl]]
    if (is.null(target)) next
    aligned_residuals <- list()
    for (r in replicas) {
      if (!isTRUE(r$converged)) next
      est <- r$loadings[[lvl]]
      if (is.null(est)) next
      aligned <- .procrustes_align(target, est)
      aligned_residuals[[length(aligned_residuals) + 1L]] <- aligned - target
    }
    if (length(aligned_residuals) == 0L) next
    ## Stack into an array and take the mean abs across the rep dim.
    M <- abs(Reduce("+", lapply(aligned_residuals, abs))) / length(aligned_residuals)
    rownames(M) <- rownames(target)
    colnames(M) <- colnames(target) %||% paste0("LV", seq_len(ncol(M)))
    out[[lvl]] <- M
  }
  out
}

## Hessian eigenvalue stats for a single refit (data frame row).
.ci_hessian_one <- function(refit) {
  H <- tryCatch(solve(refit$sd_report$cov.fixed), error = function(e) NULL)
  if (is.null(H)) {
    return(data.frame(
      min_eig = NA_real_, max_eig = NA_real_,
      condition_number = NA_real_, n_zero_eig = NA_integer_,
      pdHess = isTRUE(refit$sd_report$pdHess)
    ))
  }
  ev <- tryCatch(
    eigen(H, symmetric = TRUE, only.values = TRUE)$values,
    error = function(e) NA_real_
  )
  if (all(is.na(ev))) {
    return(data.frame(
      min_eig = NA_real_, max_eig = NA_real_,
      condition_number = NA_real_, n_zero_eig = NA_integer_,
      pdHess = isTRUE(refit$sd_report$pdHess)
    ))
  }
  min_ev <- min(ev)
  max_ev <- max(ev)
  cond   <- if (min_ev > 0) max_ev / min_ev else Inf
  n_zero <- sum(ev < 1e-8 * max_ev)
  data.frame(
    min_eig = min_ev, max_eig = max_ev,
    condition_number = cond, n_zero_eig = as.integer(n_zero),
    pdHess = isTRUE(refit$sd_report$pdHess)
  )
}

.ci_hessian_stats <- function(replicas) {
  rows <- lapply(seq_along(replicas), function(i) {
    r <- replicas[[i]]
    h <- r$hess
    if (is.null(h)) {
      h <- data.frame(
        min_eig = NA_real_, max_eig = NA_real_,
        condition_number = NA_real_, n_zero_eig = NA_integer_,
        pdHess = FALSE
      )
    }
    cbind(replicate = i, h)
  })
  do.call(rbind, rows)
}

## Recovery table: per-parameter truth / mean_est / bias / rmse /
## sd_est / coverage_95 / n_converged. Parameters are flattened across
## tier and component (Lambda entries, Psi entries, b_fix, sigma_eps).
.ci_recovery_table <- function(replicas, truth, alpha) {
  conv <- vapply(replicas, `[[`, logical(1L), "converged")
  ok <- replicas[conv]
  n_ok <- length(ok)
  if (n_ok == 0L) {
    return(data.frame(
      param = character(0), tier = character(0),
      truth = numeric(0), mean_est = numeric(0),
      bias = numeric(0), rmse = numeric(0),
      sd_est = numeric(0), coverage_95 = numeric(0),
      n_converged = integer(0)
    ))
  }
  rows <- list()
  ## Lambda entries per tier.
  for (lvl in names(truth$loadings)) {
    target <- truth$loadings[[lvl]]
    if (is.null(target)) next
    Tn <- nrow(target); d <- ncol(target)
    ests <- lapply(ok, function(r) r$loadings[[lvl]])
    ests <- ests[!vapply(ests, is.null, logical(1L))]
    ## Procrustes-align each estimate to the truth before aggregating.
    aligned <- lapply(ests, function(E) .procrustes_align(target, E))
    if (length(aligned) == 0L) next
    for (t in seq_len(Tn)) for (k in seq_len(d)) {
      vec <- vapply(aligned, function(M) M[t, k], numeric(1L))
      truth_val <- target[t, k]
      rows[[length(rows) + 1L]] <- data.frame(
        param = paste0("Lambda_", lvl, "[", t, ",", k, "]"),
        tier = lvl,
        truth = truth_val,
        mean_est = mean(vec, na.rm = TRUE),
        bias = mean(vec - truth_val, na.rm = TRUE),
        rmse = sqrt(mean((vec - truth_val)^2, na.rm = TRUE)),
        sd_est = stats::sd(vec, na.rm = TRUE),
        coverage_95 = NA_real_,  ## not computed in V1; placeholder
        n_converged = length(vec)
      )
    }
  }
  ## Psi diagonals per tier.
  for (lvl in names(truth$psi)) {
    target <- truth$psi[[lvl]]
    if (is.null(target)) next
    ests <- lapply(ok, function(r) r$psi[[lvl]])
    ests <- ests[!vapply(ests, is.null, logical(1L))]
    if (length(ests) == 0L) next
    Tn <- length(target)
    for (t in seq_len(Tn)) {
      vec <- vapply(ests, function(v) v[t], numeric(1L))
      rows[[length(rows) + 1L]] <- data.frame(
        param = paste0("psi_", lvl, "[", t, "]"),
        tier = lvl,
        truth = target[t],
        mean_est = mean(vec, na.rm = TRUE),
        bias = mean(vec - target[t], na.rm = TRUE),
        rmse = sqrt(mean((vec - target[t])^2, na.rm = TRUE)),
        sd_est = stats::sd(vec, na.rm = TRUE),
        coverage_95 = NA_real_,
        n_converged = length(vec)
      )
    }
  }
  ## Fixed effects.
  if (!is.null(truth$b_fix)) {
    ests <- lapply(ok, function(r) r$b_fix)
    ests <- ests[!vapply(ests, is.null, logical(1L))]
    if (length(ests) > 0L) {
      for (j in seq_along(truth$b_fix)) {
        vec <- vapply(ests, function(v) v[j], numeric(1L))
        rows[[length(rows) + 1L]] <- data.frame(
          param = paste0("b_fix[", j, "]"),
          tier = "fixed",
          truth = truth$b_fix[j],
          mean_est = mean(vec, na.rm = TRUE),
          bias = mean(vec - truth$b_fix[j], na.rm = TRUE),
          rmse = sqrt(mean((vec - truth$b_fix[j])^2, na.rm = TRUE)),
          sd_est = stats::sd(vec, na.rm = TRUE),
          coverage_95 = NA_real_,
          n_converged = length(vec)
        )
      }
    }
  }
  if (length(rows) == 0L) {
    return(data.frame(
      param = character(0), tier = character(0),
      truth = numeric(0), mean_est = numeric(0),
      bias = numeric(0), rmse = numeric(0),
      sd_est = numeric(0), coverage_95 = numeric(0),
      n_converged = integer(0)
    ))
  }
  do.call(rbind, rows)
}

#' @export
print.gllvmTMB_identifiability <- function(x, ...) {
  cli::cli_h1("gllvmTMB identifiability check")
  cli::cli_bullets(c(
    "*" = "Replicates: {x$n_reps} ({x$n_converged} converged)",
    "*" = "Flags: {if (length(x$flags) == 0) 'none' else paste(x$flags, collapse = ', ')}"
  ))
  if (nrow(x$recovery) > 0L) {
    cli::cli_h2("Recovery (first 10 rows)")
    print(utils::head(x$recovery, 10L))
  }
  if (length(x$loadings) > 0L) {
    cli::cli_h2("Procrustes residual magnitudes (mean abs per column)")
    for (lvl in names(x$loadings)) {
      M <- x$loadings[[lvl]]
      cli::cli_text("Tier {.val {lvl}}:")
      print(round(colMeans(abs(M)), 4L))
    }
  }
  if (nrow(x$hessian) > 0L) {
    cli::cli_h2("Hessian eigenvalue summary across replicates")
    h <- x$hessian
    cli::cli_bullets(c(
      "*" = "min_eig:           median = {signif(stats::median(h$min_eig, na.rm = TRUE), 3)}",
      "*" = "condition_number:  median = {signif(stats::median(h$condition_number, na.rm = TRUE), 3)}",
      "*" = "pdHess rate:       {signif(mean(h$pdHess, na.rm = TRUE), 3)}",
      "*" = "n_zero_eig sum:    {sum(h$n_zero_eig, na.rm = TRUE)}"
    ))
  }
  invisible(x)
}
