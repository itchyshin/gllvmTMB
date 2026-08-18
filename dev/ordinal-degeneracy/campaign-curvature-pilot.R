## Precondition-check and timing-pilot script for the curvature (Arm C) and
## multi-start (Arm D) pre-registration:
## dev/ordinal-degeneracy/pass-criteria-curvature.md
##
## Reuses the DGP and helper functions from campaign-ordinal-calibration.R
## (which itself reuses probe-mechanism.R via .load_probe_defs()) by the
## SAME parse-and-eval-named-defs technique that file already uses -- never
## sourcing either file's own top-level --mode dispatch as a side effect,
## and never hand-copying any DGP code.
##
## ALL output of this script is a PILOT and is QUARANTINED per
## pass-criteria-curvature.md's pilot-quarantine clause: written under the
## "pilot-curvature-" filename prefix, never merged into or read by any
## future scored-grid script.
##
## Usage (OPENBLAS_NUM_THREADS=1 is a hard constraint -- see the campaign's
## D-139 cost estimate section):
##   OPENBLAS_NUM_THREADS=1 Rscript dev/ordinal-degeneracy/campaign-curvature-pilot.R --stage precondition
##   OPENBLAS_NUM_THREADS=1 Rscript dev/ordinal-degeneracy/campaign-curvature-pilot.R --stage timing

suppressPackageStartupMessages({
  library(gllvmTMB)
})

ARGS <- commandArgs(trailingOnly = TRUE)
stage_idx <- which(ARGS == "--stage")
STAGE <- if (length(stage_idx) == 1L && length(ARGS) > stage_idx) {
  ARGS[[stage_idx + 1L]]
} else {
  "precondition"
}
if (!STAGE %in% c("precondition", "timing")) {
  stop("--stage must be one of: precondition, timing")
}

OUTDIR <- file.path("dev", "ordinal-degeneracy", "results")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
PILOT_PREFIX <- "pilot-curvature-"

## --------------------------------------------- reuse, never hand-copy ---
.load_named_defs <- function(path, wanted) {
  exprs <- parse(path)
  env <- new.env(parent = globalenv())
  found <- character(0)
  for (e in exprs) {
    if (
      is.call(e) && length(e) >= 2L &&
        identical(as.character(e[[1L]]), "<-") &&
        is.name(e[[2L]])
    ) {
      nm <- as.character(e[[2L]])
      if (nm %in% wanted) {
        eval(e, envir = env)
        found <- c(found, nm)
      }
    }
  }
  missing <- setdiff(wanted, found)
  if (length(missing) > 0L) {
    stop(
      path, " no longer defines: ", paste(missing, collapse = ", "),
      " -- update `wanted` or investigate before trusting this pilot."
    )
  }
  env
}

## Extract campaign-ordinal-calibration.R's DGP-extension functions and its
## own .load_probe_defs() (never that file's top-level --mode dispatch).
camp <- .load_named_defs(
  file.path("dev", "ordinal-degeneracy", "campaign-ordinal-calibration.R"),
  c(
    ".load_probe_defs", "sim_ordinal_transport", "fit_ordinal_transport",
    "sim_ordinal_mixed", "fit_ordinal_mixed"
  )
)
## .load_probe_defs() itself parses probe-mechanism.R for sim_ordinal(),
## relfrob(), TAUS, Q_FACTORS, P_TRAITS, DEGEN_RF -- called exactly as
## campaign-ordinal-calibration.R calls it.
probe <- camp$.load_probe_defs()

## ------------------------------------------------- Arm C: exact functional ---
## Implements pass-criteria-curvature.md's "Exact functional (frozen)"
## section verbatim, including the B9 length(idx)==0 guard and the
## positional-name fallback.
arm_c_stats <- function(fit, max_loading_unit) {
  out <- list(
    curvature_available = FALSE, idx_source = NA_character_,
    n_idx = NA_integer_, cond_LL = NA_real_, min_eig_raw = NA_real_,
    max_eig = NA_real_, min_eig_scaled = NA_real_
  )
  cov_fixed <- tryCatch(as.matrix(fit$sd_report$cov.fixed), error = function(e) NULL)
  if (is.null(cov_fixed) || length(cov_fixed) == 0L || !all(is.finite(cov_fixed))) {
    return(out)
  }

  rn <- rownames(cov_fixed)
  idx <- integer(0)
  if (!is.null(rn)) {
    idx <- which(rn == "theta_rr_B")
    if (length(idx) > 0L) out$idx_source <- "rownames(cov.fixed)"
  }
  if (length(idx) == 0L) {
    par_names <- tryCatch(names(fit$tmb_obj$par), error = function(e) NULL)
    if (!is.null(par_names)) {
      idx <- which(par_names == "theta_rr_B")
      if (length(idx) > 0L) out$idx_source <- "names(tmb_obj$par) [positional fallback]"
    }
  }
  ## B9 guard: never let max()/min() on an empty numeric vector silently
  ## produce -Inf/Inf that would be scored as a real value.
  if (length(idx) == 0L) return(out)
  out$n_idx <- length(idx)

  cov_LL <- cov_fixed[idx, idx, drop = FALSE]
  Schur_LL <- tryCatch(solve(cov_LL), error = function(e) NULL)
  if (is.null(Schur_LL) || !all(is.finite(Schur_LL))) return(out)

  ev <- tryCatch(
    eigen(Schur_LL, symmetric = TRUE, only.values = TRUE)$values,
    error = function(e) NA_real_
  )
  if (length(ev) == 0L || any(!is.finite(ev))) return(out)

  min_ev <- min(ev)
  max_ev <- max(ev)
  out$curvature_available <- TRUE
  out$min_eig_raw <- min_ev
  out$max_eig <- max_ev
  out$cond_LL <- if (min_ev > 0) max_ev / min_ev else Inf
  out$min_eig_scaled <- (min_ev) * max(max_loading_unit, 1)^2  ## per-obs division applied by caller
  out
}

## ------------------------------------------------- Arm D: exact functional ---
arm_d_stats <- function(fit, n_obs) {
  out <- list(
    disagreement_available = FALSE, n_success = NA_integer_,
    obj_spread_per_obs = NA_real_, n_modes_frac = NA_real_
  )
  rh <- fit$restart_history
  if (is.null(rh) || !all(c("objective", "success") %in% names(rh))) return(out)
  obj_i <- rh$objective[isTRUE(rh$success) | rh$success %in% TRUE]
  ## success may be logical vector; guard NA-safe subset
  ok <- rh$success & is.finite(rh$objective)
  ok[is.na(ok)] <- FALSE
  obj_i <- rh$objective[ok]
  if (length(obj_i) < 2L) {
    out$n_success <- length(obj_i)
    return(out)
  }
  out$disagreement_available <- TRUE
  out$n_success <- length(obj_i)
  out$obj_spread_per_obs <- (max(obj_i) - min(obj_i)) / n_obs
  out$n_modes_frac <- mean((obj_i - min(obj_i)) / n_obs > 0.01)
  out
}

## ---------------------------------------------- fit wrappers with control ---
## probe$fit_ordinal() / camp$fit_ordinal_transport() / camp$fit_ordinal_mixed()
## take no `control` argument, so this pilot needs its own thin wrappers to
## pass n_init/init_jitter through -- these restate the SAME formula/family
## those functions already use (verbatim, read from probe-mechanism.R and
## campaign-ordinal-calibration.R), never a different fit specification.
## The DGP itself (sim_ordinal / sim_ordinal_transport / sim_ordinal_mixed)
## is still called unmodified via `probe$`/`camp$`.
.fit_ordinal_ctrl <- function(dat, control) {
  gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = probe$Q_FACTORS, unique = FALSE),
    data = dat, unit = "site", family = gllvmTMB::ordinal_probit(), control = control
  )
}
.fit_ordinal_transport_ctrl <- function(dat, q, control) {
  gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE),
    data = dat, unit = "site", family = gllvmTMB::ordinal_probit(), control = control
  )
}
.fit_ordinal_mixed_ctrl <- function(dat, q, control) {
  family_list <- list(gllvmTMB::ordinal_probit(), stats::gaussian())
  attr(family_list, "family_var") <- "family"
  gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = q),
    data = dat, unit = "site", family = family_list, control = control
  )
}

## --------------------------------------------------------- one-fit runner ---
run_one_curvature <- function(subarm, n, sigma_lambda, seed, n_init = 1L,
                               q = probe$Q_FACTORS, p = probe$P_TRAITS) {
  t0 <- proc.time()[["elapsed"]]
  sim <- switch(
    subarm,
    scale_healthy    = ,
    scale_boundary   = ,
    scale_degenerate = probe$sim_ordinal(n, p, q, sigma_lambda, seed),
    transport        = camp$sim_ordinal_transport(n, p, q, seed),
    mixed            = camp$sim_ordinal_mixed(n, q, seed)
  )
  n_obs <- nrow(sim$data)

  ## init_jitter per pass-criteria-curvature.md's B5 fix: scale-relative to
  ## the cell's own known DGP loading scale, not a flat 0.3.
  nominal_scale <- switch(
    subarm,
    scale_healthy    = ,
    scale_boundary   = ,
    scale_degenerate = sigma_lambda,
    transport        = 9,   ## sim_ordinal_transport()'s own scale_hi default
    mixed             = 0.7
  )
  init_jitter_cell <- 0.5 * max(nominal_scale, 1)

  ctrl <- gllvmTMB::gllvmTMBcontrol(n_init = n_init, init_jitter = init_jitter_cell)
  fit <- tryCatch(
    withCallingHandlers(
      switch(
        subarm,
        scale_healthy    = ,
        scale_boundary   = ,
        scale_degenerate = .fit_ordinal_ctrl(sim$data, control = ctrl),
        transport        = .fit_ordinal_transport_ctrl(sim$data, q, control = ctrl),
        mixed            = .fit_ordinal_mixed_ctrl(sim$data, q, control = ctrl)
      ),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "cell_error")
  )
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "cell_error")) {
    return(data.frame(
      subarm = subarm, n = n, sigma_lambda = sigma_lambda, seed = seed,
      n_init = n_init, n_obs = n_obs, init_jitter = init_jitter_cell,
      seconds = secs, status = "ERROR", note = fit$msg,
      rel_frob = NA_real_, degenerate_label = NA,
      curvature_available = NA, idx_source = NA_character_, n_idx = NA_integer_,
      cond_LL = NA_real_, min_eig_raw = NA_real_, max_eig = NA_real_,
      min_eig_scaled_per_obs = NA_real_, max_loading_unit = NA_real_,
      disagreement_available = NA, n_success = NA_integer_,
      obj_spread_per_obs = NA_real_, n_modes_frac = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  rel_frob <- NA_real_
  degenerate_label <- NA
  if (subarm %in% c("scale_healthy", "scale_boundary", "scale_degenerate", "transport")) {
    Lam_hat <- tryCatch(fit$report$Lambda_B, error = function(e) NULL)
    if (!is.null(Lam_hat) && all(is.finite(Lam_hat))) {
      rel_frob <- probe$relfrob(tcrossprod(Lam_hat), sim$Sig_true)
      degenerate_label <- isTRUE(rel_frob > probe$DEGEN_RF)
    }
  }

  ord_ids <- tryCatch({
    td <- fit$tmb_data
    sort(unique(as.integer(td$trait_id[td$family_id_vec == 14L]))) + 1L
  }, error = function(e) NULL)
  stats_tab <- tryCatch(
    gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit, reference_traits = ord_ids),
    error = function(e) NULL
  )
  max_loading_unit <- if (!is.null(stats_tab) && "max_loading_unit" %in% names(stats_tab)) {
    suppressWarnings(max(stats_tab$max_loading_unit, na.rm = TRUE))
  } else NA_real_

  c_stats <- arm_c_stats(fit, max_loading_unit)
  d_stats <- arm_d_stats(fit, n_obs)

  data.frame(
    subarm = subarm, n = n, sigma_lambda = sigma_lambda, seed = seed,
    n_init = n_init, n_obs = n_obs, init_jitter = init_jitter_cell,
    seconds = secs, status = "OK", note = "",
    rel_frob = rel_frob, degenerate_label = degenerate_label,
    curvature_available = c_stats$curvature_available,
    idx_source = c_stats$idx_source, n_idx = c_stats$n_idx,
    cond_LL = c_stats$cond_LL, min_eig_raw = c_stats$min_eig_raw,
    max_eig = c_stats$max_eig,
    min_eig_scaled_per_obs = if (isTRUE(c_stats$curvature_available)) {
      c_stats$min_eig_scaled / n_obs
    } else NA_real_,
    max_loading_unit = max_loading_unit,
    disagreement_available = d_stats$disagreement_available,
    n_success = d_stats$n_success,
    obj_spread_per_obs = d_stats$obj_spread_per_obs,
    n_modes_frac = d_stats$n_modes_frac,
    stringsAsFactors = FALSE
  )
}

## =========================================================================
if (identical(STAGE, "precondition")) {
  cat("=== PRECONDITION CHECK 1: rownames(cov.fixed) vs names(tmb_obj$par) ===\n")
  sim1 <- probe$sim_ordinal(100L, probe$P_TRAITS, probe$Q_FACTORS, 3.0, 1L)
  fit1 <- probe$fit_ordinal(sim1$data)
  cf <- as.matrix(fit1$sd_report$cov.fixed)
  rn <- rownames(cf)
  pn <- names(fit1$tmb_obj$par)
  cat("class(fit1$sd_report$cov.fixed):", class(fit1$sd_report$cov.fixed), "\n")
  cat("dim(cov.fixed):", paste(dim(cf), collapse = " x "), "\n")
  cat("is.null(rownames(cov.fixed)):", is.null(rn), "\n")
  if (!is.null(rn)) {
    cat("rownames(cov.fixed)[1:10]:", paste(utils::head(rn, 10), collapse = ", "), "\n")
  }
  cat("names(tmb_obj$par)[1:10]:  ", paste(utils::head(pn, 10), collapse = ", "), "\n")
  identical_names <- !is.null(rn) && identical(rn, pn)
  cat("identical(rownames(cov.fixed), names(tmb_obj$par)):", identical_names, "\n")
  n_theta_rr_B_rn <- if (!is.null(rn)) sum(rn == "theta_rr_B") else NA_integer_
  n_theta_rr_B_pn <- sum(pn == "theta_rr_B")
  cat("sum(rownames(cov.fixed) == 'theta_rr_B'):", n_theta_rr_B_rn, "\n")
  cat("sum(names(tmb_obj$par) == 'theta_rr_B'):  ", n_theta_rr_B_pn, "\n")

  cat("\n=== PRECONDITION CHECK 2: length(idx)==0 guard + positional fallback ===\n")
  ## Exercise the guard by pretending rownames() is stripped.
  cf_stripped <- cf
  rownames(cf_stripped) <- NULL
  colnames(cf_stripped) <- NULL
  fit1_stripped <- fit1
  fit1_stripped$sd_report$cov.fixed <- cf_stripped
  c_stats_fallback <- arm_c_stats(fit1_stripped, max_loading_unit = 1)
  cat("With rownames(cov.fixed) stripped -- idx_source:", c_stats_fallback$idx_source,
      " n_idx:", c_stats_fallback$n_idx,
      " curvature_available:", c_stats_fallback$curvature_available, "\n")
  ## Exercise the true zero-length guard: strip BOTH naming routes.
  fit1_noboth <- fit1_stripped
  names(fit1_noboth$tmb_obj$par) <- NULL
  c_stats_noboth <- arm_c_stats(fit1_noboth, max_loading_unit = 1)
  cat("With BOTH naming routes stripped -- curvature_available:",
      c_stats_noboth$curvature_available,
      " (expect FALSE, not an error, not Inf/-Inf)\n")

  cat("\n=== PRECONDITION CHECK 3: finite, in-range statistics on ONE real fit ===\n")
  ord_ids <- {
    td <- fit1$tmb_data
    sort(unique(as.integer(td$trait_id[td$family_id_vec == 14L]))) + 1L
  }
  stats_tab <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit1, reference_traits = ord_ids)
  max_loading_unit <- suppressWarnings(max(stats_tab$max_loading_unit, na.rm = TRUE))
  c_stats <- arm_c_stats(fit1, max_loading_unit)
  n_obs <- nrow(sim1$data)
  cat(sprintf(
    "curvature_available=%s idx_source=%s n_idx=%d\n",
    c_stats$curvature_available, c_stats$idx_source, c_stats$n_idx
  ))
  cat(sprintf(
    "cond_LL=%.6g min_eig_raw=%.6g max_eig=%.6g min_eig_scaled_per_obs=%.6g max_loading_unit=%.4f\n",
    c_stats$cond_LL, c_stats$min_eig_raw, c_stats$max_eig,
    c_stats$min_eig_scaled / n_obs, max_loading_unit
  ))
  finite_ok <- is.finite(c_stats$cond_LL) && is.finite(c_stats$min_eig_raw) &&
    is.finite(c_stats$max_eig)
  cat("All three Arm C statistics finite (not NA/Inf/-Inf):", finite_ok, "\n")

  ## Arm D smoke: force n_init = 3 on a fresh fit to keep this cheap.
  fit1_multistart <- .fit_ordinal_ctrl(
    sim1$data, control = gllvmTMB::gllvmTMBcontrol(n_init = 3L, init_jitter = 1.5)
  )
  d_stats <- arm_d_stats(fit1_multistart, n_obs)
  cat(sprintf(
    "\nArm D smoke: disagreement_available=%s n_success=%s obj_spread_per_obs=%.6g n_modes_frac=%.4f\n",
    d_stats$disagreement_available, d_stats$n_success,
    d_stats$obj_spread_per_obs, d_stats$n_modes_frac
  ))
  d_finite_ok <- is.finite(d_stats$obj_spread_per_obs) && is.finite(d_stats$n_modes_frac)
  cat("Both Arm D statistics finite:", d_finite_ok, "\n")

  precondition_pass <- identical_names && !c_stats_noboth$curvature_available &&
    finite_ok && d_finite_ok
  cat("\n=== PRECONDITION VERDICT:", if (precondition_pass) "PASS" else "FAIL", "===\n")

  out <- data.frame(
    check = c(
      "rownames_identical_to_par_names", "n_theta_rr_B_in_rownames",
      "n_theta_rr_B_in_par_names", "guard_fires_clean_on_stripped_names",
      "arm_c_finite", "arm_d_finite"
    ),
    result = c(
      identical_names, n_theta_rr_B_rn, n_theta_rr_B_pn,
      !c_stats_noboth$curvature_available, finite_ok, d_finite_ok
    ),
    stringsAsFactors = FALSE
  )
  write.csv(
    out, file.path(OUTDIR, paste0(PILOT_PREFIX, "precondition.csv")),
    row.names = FALSE
  )
}

## =========================================================================
if (identical(STAGE, "timing")) {
  cat("=== TIMING PILOT: cells spanning the flagged cost drivers ===\n")
  cat("(sigma_lambda up to 8, and n_init=5 with scale-relative jitter)\n\n")

  cells <- list(
    list(subarm = "scale_healthy",    n = 100L, sigma_lambda = 0.7, seed = 1L, n_init = 1L),
    list(subarm = "scale_degenerate", n = 100L, sigma_lambda = 3.0, seed = 1L, n_init = 1L),
    list(subarm = "scale_degenerate", n = 100L, sigma_lambda = 8.0, seed = 1L, n_init = 1L),
    list(subarm = "scale_degenerate", n = 400L, sigma_lambda = 8.0, seed = 1L, n_init = 1L),
    list(subarm = "transport",        n = 100L, sigma_lambda = NA,  seed = 1L, n_init = 1L),
    list(subarm = "mixed",            n = 100L, sigma_lambda = NA,  seed = 1L, n_init = 1L),
    ## n_init = 5 cells -- the OTHER flagged cost driver.
    list(subarm = "scale_degenerate", n = 100L, sigma_lambda = 8.0, seed = 2L, n_init = 5L),
    list(subarm = "scale_degenerate", n = 400L, sigma_lambda = 8.0, seed = 2L, n_init = 5L),
    list(subarm = "transport",        n = 400L, sigma_lambda = NA,  seed = 2L, n_init = 5L)
  )

  rows <- vector("list", length(cells))
  for (i in seq_along(cells)) {
    cl <- cells[[i]]
    cat(sprintf(
      "[%d/%d] subarm=%-16s n=%-4d sigma=%s seed=%d n_init=%d ... ",
      i, length(cells), cl$subarm, cl$n, format(cl$sigma_lambda), cl$seed, cl$n_init
    ))
    r <- run_one_curvature(cl$subarm, cl$n, cl$sigma_lambda, cl$seed, n_init = cl$n_init)
    rows[[i]] <- r
    cat(sprintf(
      "%.1fs status=%s curv_avail=%s cond_LL=%s min_eig_scaled=%s obj_spread=%s\n",
      r$seconds, r$status, r$curvature_available,
      format(r$cond_LL, digits = 3), format(r$min_eig_scaled_per_obs, digits = 3),
      format(r$obj_spread_per_obs, digits = 3)
    ))
  }
  out <- do.call(rbind, rows)
  write.csv(
    out, file.path(OUTDIR, paste0(PILOT_PREFIX, "timing.csv")), row.names = FALSE
  )

  cat("\n=== Per-cell seconds ===\n")
  print(out[, c("subarm", "n", "sigma_lambda", "n_init", "seconds", "status")])

  ## ------------------------------------------------ extrapolate full grid ---
  ## Grid per pass-criteria-curvature.md:
  ##   n_init=1: scale_healthy 140, scale_boundary 40, scale_degenerate 120,
  ##             transport 80, mixed 70  -> 450 fits total, 310 of them
  ##             single-start-only (n_init=1 cells not also covered by D).
  ##   n_init=5: 140 base replicates (48 scale_healthy, 48 scale_degenerate,
  ##             24 transport, 20 mixed), each costing ~5x a single fit.
  single_start_secs <- mean(out$seconds[out$n_init == 1L & out$status == "OK"])
  n5_secs <- out$seconds[out$n_init == 5L & out$status == "OK"]
  n5_mean_secs <- if (length(n5_secs) > 0L) mean(n5_secs) else NA_real_
  n5_per_restart_secs <- if (!is.na(n5_mean_secs)) n5_mean_secs / 5 else NA_real_

  cat(sprintf(
    "\nMean single-start (n_init=1) cell time (this pilot): %.2fs\n", single_start_secs
  ))
  cat(sprintf(
    "Mean n_init=5 cell time (this pilot): %.2fs (%.2fs/restart)\n",
    n5_mean_secs, n5_per_restart_secs
  ))

  n_single_start_fits <- 310L
  n_multistart_base <- 140L
  proj_single_secs <- n_single_start_fits * single_start_secs
  proj_multistart_secs <- n_multistart_base * n5_mean_secs
  proj_total_secs <- proj_single_secs + proj_multistart_secs

  cat(sprintf(
    "\nProjected (serial, 1 core): %d single-start fits x %.2fs = %.1fs (%.1f min)\n",
    n_single_start_fits, single_start_secs, proj_single_secs, proj_single_secs / 60
  ))
  cat(sprintf(
    "                            %d n_init=5 calls x %.2fs = %.1fs (%.1f min)\n",
    n_multistart_base, n5_mean_secs, proj_multistart_secs, proj_multistart_secs / 60
  ))
  cat(sprintf(
    "TOTAL serial projection: %.1fs = %.1f min = %.2f h\n",
    proj_total_secs, proj_total_secs / 60, proj_total_secs / 3600
  ))
  for (cores in c(10, 20)) {
    cat(sprintf(
      "  at %d-core parallel efficiency (linear, optimistic): %.1f min\n",
      cores, proj_total_secs / 60 / cores
    ))
  }
  if (proj_total_secs / 60 > 30) {
    cat(
      "\n*** Even at 20-core linear parallelism this may sit near/over the",
      "D-139 30-minute line -- see reply for the recommendation. ***\n"
    )
  }
}
