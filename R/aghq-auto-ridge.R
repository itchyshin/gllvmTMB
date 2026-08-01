## Experimental scale-aware AGHQ ridge selection (#847).
##
## The scale yardstick is deliberately an UNPENALISED, MULTI-START AGHQ fit.
## A plain Laplace fit is not an admissible pilot: the calibration campaign
## found it in the intended basin in only 0--1% of fits.  The public wrapper
## below is kept separate from gllvmTMB_multi_fit() so numeric and Inf ridge
## requests still take the established single-fit path unchanged.

.gllvmTMB_normalize_aghq_ridge <- function(x) {
  if (is.character(x) && length(x) == 1L && !is.na(x) &&
      identical(tolower(x), "auto")) {
    return("auto")
  }
  if (is.numeric(x) && length(x) == 1L && !is.na(x) &&
      x > 0) {
    return(as.numeric(x))
  }
  cli::cli_abort(c(
    "{.arg aghq_ridge} must be a positive number, {.code Inf}, or {.val auto}.",
    "i" = "{.val auto} is an opt-in experimental scale-aware AGHQ ridge."
  ))
}

.gllvmTMB_aghq_auto_requested <- function(control) {
  identical(control$aghq_ridge, "auto")
}

.gllvmTMB_aghq_auto_pilot_problem <- function(fit) {
  if (!inherits(fit, "gllvmTMB")) return("pilot did not return a gllvmTMB fit")
  if (!isTRUE(fit$aghq$used)) return("pilot did not use AGHQ")
  if (!isTRUE(fit$aghq$converged)) return("pilot AGHQ did not converge")
  if (length(fit$aghq$k) != 1L || !identical(as.integer(fit$aghq$k), 9L)) {
    return("pilot did not use the calibrated 9-node AGHQ rule")
  }
  if (length(fit$aghq$n_starts) != 1L ||
      !is.finite(fit$aghq$n_starts) || fit$aghq$n_starts < 2L) {
    return("pilot did not complete multi-start AGHQ")
  }
  if (length(fit$aghq$ridge_tau) != 1L ||
      !identical(as.numeric(fit$aghq$ridge_tau), Inf)) {
    return("pilot AGHQ was not unpenalised")
  }

  td <- fit$tmb_data
  calibrated_scope <- isTRUE(td$use_rr_B == 1L) &&
    identical(fit$random, "z_B") &&
    length(td$family_id_vec) > 0L &&
    isTRUE(all(td$family_id_vec == 1L)) &&
    isTRUE(all(td$n_trials == 1)) &&
    length(td$diag_B_skip) == td$n_traits &&
    isTRUE(all(td$diag_B_skip == 1L))
  if (!calibrated_scope) {
    return(paste(
      "model is outside the calibrated pure single-trial Bernoulli",
      "ordinary-latent scope"
    ))
  }

  p <- as.integer(td$n_traits)
  q <- as.integer(td$d_B)
  L <- fit$report$Lambda_B
  if (!is.matrix(L) || p < 1L || q < 1L ||
      nrow(L) < p || ncol(L) < q) {
    return("pilot did not report the calibrated loading block")
  }
  L <- L[seq_len(p), seq_len(q), drop = FALSE]
  if (any(!is.finite(L))) return("pilot loading scale is non-finite")
  NULL
}

.gllvmTMB_aghq_auto_tau <- function(fit, cap = 6) {
  problem <- .gllvmTMB_aghq_auto_pilot_problem(fit)
  if (!is.null(problem)) {
    return(list(ok = FALSE, problem = problem, tau_raw = NA_real_,
                tau_used = NA_real_, clipped = NA))
  }
  p <- as.integer(fit$tmb_data$n_traits)
  q <- as.integer(fit$tmb_data$d_B)
  L <- fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  tau_raw <- max(1, sqrt(sum(L^2)) / sqrt(p * q))
  list(
    ok = TRUE,
    problem = NULL,
    tau_raw = tau_raw,
    tau_used = min(cap, tau_raw),
    clipped = isTRUE(tau_raw > cap)
  )
}

.gllvmTMB_aghq_auto_final_problem <- function(fit) {
  if (!inherits(fit, "gllvmTMB")) return("candidate did not return a gllvmTMB fit")
  if (!isTRUE(fit$aghq$used)) return("candidate did not use AGHQ")
  if (!isTRUE(fit$aghq$converged)) return("candidate AGHQ did not converge")
  if (is.null(fit$report$Lambda_B) || any(!is.finite(fit$report$Lambda_B))) {
    return("candidate loading scale is non-finite")
  }
  NULL
}

.gllvmTMB_attach_aghq_auto_provenance <- function(fit, pilot, decision,
                                                   selected, fallback_reason,
                                                   cap, fallback_tau) {
  fit$aghq$ridge_auto <- list(
    requested = TRUE,
    selected = selected,
    source = "unpenalised_multistart_aghq",
    cap = cap,
    tau_raw = decision$tau_raw,
    tau_used = if (identical(selected, "auto")) decision$tau_used else fallback_tau,
    clipped = decision$clipped,
    fallback = identical(selected, "fixed2_fallback"),
    fallback_reason = fallback_reason,
    pilot_used = isTRUE(pilot$aghq$used),
    pilot_converged = isTRUE(pilot$aghq$converged),
    pilot_k = as.integer(pilot$aghq$k %||% NA_integer_),
    pilot_n_starts = as.integer(pilot$aghq$n_starts %||% NA_integer_),
    pilot_ridge_tau = as.numeric(pilot$aghq$ridge_tau %||% NA_real_)
  )
  fit$aghq$ridge_source <- if (identical(selected, "auto")) {
    "auto_unpenalised_multistart_aghq"
  } else {
    "fixed2_fallback"
  }
  fit$aghq$ridge_tau_raw <- decision$tau_raw
  fit$aghq$ridge_tau_used <- fit$aghq$ridge_auto$tau_used
  fit$aghq$ridge_tau_cap <- cap
  fit
}

.gllvmTMB_fit_aghq_auto_ridge <- function(fit_once, control,
                                          cap = 6, fallback_tau = 2) {
  cli::cli_warn(c(
    "{.code aghq_ridge = \"auto\"} is experimental and opt-in.",
    "i" = "It is calibrated for pure single-trial Bernoulli models with one ordinary unit-tier latent block and 9-node multi-start AGHQ.",
    "i" = "The measured grid used logit, p = 6, q = 2, and n = 100, 400, or 1600; other links and dimensions are extrapolations.",
    "i" = "Evidence supports failure/runaway avoidance at that scope, not a broad loading-accuracy improvement.",
    ">" = "Read {.code fit$aghq$ridge_auto} for the pilot, selected scale, clipping, and any fallback."
  ), .frequency = "once", .frequency_id = "gllvmTMB-aghq-auto-ridge")

  pilot_control <- control
  pilot_control$aghq <- 9L
  pilot_control$aghq_ridge <- Inf
  pilot_control$aghq_ridge_explicit <- TRUE
  pilot_control$aghq_multistart <- TRUE
  pilot_control$warn_runaway <- FALSE
  pilot_control$start_from <- control$start_from

  pilot <- tryCatch(fit_once(pilot_control), error = function(e) e)
  if (inherits(pilot, "error")) {
    pilot_stub <- list(aghq = list())
    class(pilot_stub) <- "gllvmTMB"
    decision <- list(ok = FALSE, problem = conditionMessage(pilot),
                     tau_raw = NA_real_, tau_used = NA_real_, clipped = NA)
    pilot <- pilot_stub
  } else {
    decision <- .gllvmTMB_aghq_auto_tau(pilot, cap = cap)
  }

  candidate_problem <- decision$problem
  if (isTRUE(decision$ok)) {
    candidate_control <- control
    candidate_control$aghq <- 9L
    candidate_control$aghq_multistart <- TRUE
    candidate_control$aghq_ridge <- decision$tau_used
    candidate_control$aghq_ridge_explicit <- TRUE
    candidate_control$start_from <- pilot
    candidate <- tryCatch(fit_once(candidate_control), error = function(e) e)
    if (inherits(candidate, "error")) {
      candidate_problem <- conditionMessage(candidate)
    } else {
      candidate_problem <- .gllvmTMB_aghq_auto_final_problem(candidate)
      if (is.null(candidate_problem)) {
        return(.gllvmTMB_attach_aghq_auto_provenance(
          candidate, pilot, decision, selected = "auto",
          fallback_reason = NULL, cap = cap, fallback_tau = fallback_tau
        ))
      }
    }
  }

  fallback_control <- control
  fallback_control$aghq <- 9L
  fallback_control$aghq_multistart <- TRUE
  fallback_control$aghq_ridge <- fallback_tau
  fallback_control$aghq_ridge_explicit <- TRUE
  fallback_control$start_from <- control$start_from
  fallback <- fit_once(fallback_control)
  cli::cli_warn(c(
    "Scale-aware AGHQ ridge selection was not used; the returned fit uses the shipped {.code tau = 2} fallback.",
    "i" = "Reason: {candidate_problem}.",
    ">" = "Inspect {.code fit$aghq$ridge_auto$fallback_reason} for machine-readable provenance."
  ))
  .gllvmTMB_attach_aghq_auto_provenance(
    fallback, pilot, decision, selected = "fixed2_fallback",
    fallback_reason = candidate_problem, cap = cap,
    fallback_tau = fallback_tau
  )
}
