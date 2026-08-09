# V4 attempt schema overlay. Core status classification stays unchanged.

CRAN07_V4_ATTEMPT_COLUMNS <- c(
  cran07_attempt_columns, "source_archive_sha256",
  "warm_restart_attempted", "warm_restart_accepted",
  "objective_before_restart", "objective_after_restart",
  "max_gradient_before_restart", "max_gradient_after_restart",
  "convergence_code_before_restart", "convergence_code_after_restart",
  "pd_hessian_before_restart", "pd_hessian_after_restart",
  "boundary_before_restart", "boundary_after_restart",
  "warm_restart_trigger_reason"
)

cran07_v4_scalar_logical <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(name, " must be one non-missing logical value.", call. = FALSE)
  }
  x
}

cran07_v4_restart_evidence <- function(record, require_provenance = TRUE) {
  if (is.null(record)) {
    if (isTRUE(require_provenance)) {
      stop("V4 fit is missing required warm-restart provenance.", call. = FALSE)
    }
    return(list(warm_restart_attempted = FALSE, warm_restart_accepted = FALSE,
      objective_before_restart = NA_real_, objective_after_restart = NA_real_,
      max_gradient_before_restart = NA_real_, max_gradient_after_restart = NA_real_,
      convergence_code_before_restart = NA_integer_,
      convergence_code_after_restart = NA_integer_,
      pd_hessian_before_restart = NA, pd_hessian_after_restart = NA,
      boundary_before_restart = NA, boundary_after_restart = NA,
      warm_restart_trigger_reason = "fit_unavailable"))
  }
  required <- c("warm_restart_attempted", "warm_restart_accepted",
                "objective_before_restart", "objective_after_restart",
                "max_gradient_before_restart", "max_gradient_after_restart",
                "convergence_code_before_restart", "convergence_code_after_restart",
                "pd_hessian_before_restart", "pd_hessian_after_restart",
                "boundary_before_restart", "boundary_after_restart",
                "warm_restart_trigger_reason")
  if (!is.list(record) || length(setdiff(required, names(record)))) {
    stop("Warm-restart provenance lacks the frozen v4 fields.", call. = FALSE)
  }
  out <- record[required]
  out$warm_restart_attempted <- cran07_v4_scalar_logical(
    out$warm_restart_attempted, "warm_restart_attempted")
  out$warm_restart_accepted <- cran07_v4_scalar_logical(
    out$warm_restart_accepted, "warm_restart_accepted")
  for (nm in c("objective_before_restart", "objective_after_restart",
               "max_gradient_before_restart", "max_gradient_after_restart")) {
    if (!is.numeric(out[[nm]]) || length(out[[nm]]) != 1L) {
      stop(nm, " must be one numeric value (NA allowed by state).", call. = FALSE)
    }
    out[[nm]] <- as.numeric(out[[nm]])
  }
  for (nm in c("convergence_code_before_restart",
               "convergence_code_after_restart")) {
    x <- out[[nm]]
    if (!is.integer(x) && !is.numeric(x) || length(x) != 1L ||
        (!is.na(x) && x != as.integer(x))) {
      stop(nm, " must be one integer value (NA allowed by state).", call. = FALSE)
    }
    out[[nm]] <- as.integer(x)
  }
  for (nm in c("pd_hessian_before_restart", "pd_hessian_after_restart",
               "boundary_before_restart", "boundary_after_restart")) {
    x <- out[[nm]]
    if (!is.logical(x) || length(x) != 1L) {
      stop(nm, " must be one logical value (NA allowed by state).", call. = FALSE)
    }
  }
  if (!is.character(out$warm_restart_trigger_reason) ||
      length(out$warm_restart_trigger_reason) != 1L ||
      is.na(out$warm_restart_trigger_reason) ||
      !nzchar(out$warm_restart_trigger_reason)) {
    stop("warm_restart_trigger_reason must be one nonempty string.", call. = FALSE)
  }
  if (!isTRUE(require_provenance)) {
    unavailable <- identical(out$warm_restart_trigger_reason, "fit_unavailable") &&
      !out$warm_restart_attempted && !out$warm_restart_accepted &&
      all(vapply(out[c("objective_before_restart", "objective_after_restart",
                       "max_gradient_before_restart", "max_gradient_after_restart",
                       "convergence_code_before_restart",
                       "convergence_code_after_restart",
                       "pd_hessian_before_restart", "pd_hessian_after_restart",
                       "boundary_before_restart", "boundary_after_restart")],
                 function(x) length(x) == 1L && is.na(x), logical(1L)))
    if (unavailable) return(out)
  }
  if (!is.finite(out$objective_before_restart) ||
      !is.finite(out$max_gradient_before_restart) ||
      out$max_gradient_before_restart < 0 ||
      is.na(out$convergence_code_before_restart) ||
      is.na(out$pd_hessian_before_restart) || is.na(out$boundary_before_restart)) {
    stop("Every fitted v4 attempt requires finite, nonnegative, typed before-fields.",
         call. = FALSE)
  }
  trigger <- out$convergence_code_before_restart == 0L &&
    out$max_gradient_before_restart >= 0.01 &&
    out$pd_hessian_before_restart && !out$boundary_before_restart
  expected_reason <- if (trigger) "eligible_raw_gradient_at_or_above_0.01" else
    if (out$convergence_code_before_restart != 0L) "optimizer_code_nonzero" else
      if (!out$pd_hessian_before_restart) "non_pd_hessian" else
        if (out$boundary_before_restart) "boundary" else
          "raw_gradient_below_0.01"
  if (!identical(out$warm_restart_attempted, trigger) ||
      !identical(out$warm_restart_trigger_reason, expected_reason)) {
    stop("Warm-restart attempted state or trigger reason contradicts the frozen predicate.",
         call. = FALSE)
  }
  after_names <- c("objective_after_restart", "max_gradient_after_restart",
                   "convergence_code_after_restart", "pd_hessian_after_restart",
                   "boundary_after_restart")
  if (!trigger) {
    if (out$warm_restart_accepted ||
        any(!vapply(out[after_names], function(x) is.na(x), logical(1L)))) {
      stop("Unattempted warm restart must be unaccepted with all after-fields NA.",
           call. = FALSE)
    }
    return(out)
  }
  if (!is.finite(out$objective_after_restart) ||
      !is.finite(out$max_gradient_after_restart) ||
      out$max_gradient_after_restart < 0 ||
      is.na(out$convergence_code_after_restart) ||
      is.na(out$pd_hessian_after_restart) || is.na(out$boundary_after_restart)) {
    stop("Attempted warm restart requires finite, nonnegative, typed after-fields.",
         call. = FALSE)
  }
  tol <- 64 * .Machine$double.eps * max(1, abs(out$objective_before_restart))
  accept <- out$convergence_code_after_restart == 0L &&
    out$max_gradient_after_restart < out$max_gradient_before_restart &&
    out$pd_hessian_after_restart && !out$boundary_after_restart &&
    out$objective_after_restart <= out$objective_before_restart + tol
  if (!identical(out$warm_restart_accepted, accept)) {
    stop("Warm-restart accepted state contradicts the frozen acceptance predicate.",
         call. = FALSE)
  }
  out
}

# The optimizer implementation may choose its own fit-level storage name. This
# adapter is the sole coupling point: callers pass the discovered record here.
cran07_v4_restart_record_from_fit <- function(fit) {
  candidates <- c("warm_restart_provenance", "warm_restart_history",
                  "optimizer_restart_provenance")
  hit <- candidates[vapply(candidates, function(nm) !is.null(fit[[nm]]), logical(1L))]
  if (length(hit) != 1L) {
    stop("V4 requires exactly one recognized fit-level warm-restart provenance record.",
         call. = FALSE)
  }
  cran07_v4_restart_evidence(fit[[hit]], require_provenance = TRUE)
}

cran07_v4_validate_attempt_table <- function(x) {
  cran07_validate_attempt_table(x)
  absent <- setdiff(CRAN07_V4_ATTEMPT_COLUMNS, names(x))
  if (length(absent)) stop("V4 attempt ledger is missing columns: ",
                           paste(absent, collapse = ", "), call. = FALSE)
  if (any(!grepl("^[0-9a-f]{64}$", x$source_archive_sha256))) {
    stop("V4 attempt ledger contains an invalid source archive SHA-256.",
         call. = FALSE)
  }
  restart_fields <- c(
    "warm_restart_attempted", "warm_restart_accepted",
    "objective_before_restart", "objective_after_restart",
    "max_gradient_before_restart", "max_gradient_after_restart",
    "convergence_code_before_restart", "convergence_code_after_restart",
    "pd_hessian_before_restart", "pd_hessian_after_restart",
    "boundary_before_restart", "boundary_after_restart",
    "warm_restart_trigger_reason")
  for (i in seq_len(nrow(x))) {
    unavailable <- x$status[[i]] %in% c("construction_error", "fit_error")
    cran07_v4_restart_evidence(as.list(x[i, restart_fields]),
      require_provenance = !unavailable)
  }
  invisible(TRUE)
}

cran07_v4_assert_attempt_manifest_identity <- function(attempts, manifest) {
  if (length(setdiff(CRAN07_V4_IDENTITY_COLUMNS, names(attempts))) ||
      length(setdiff(CRAN07_V4_IDENTITY_COLUMNS, names(manifest)))) {
    stop("Attempt or manifest lacks the six-field v4 identity.", call. = FALSE)
  }
  order_id <- function(x) {
    x <- x[, CRAN07_V4_IDENTITY_COLUMNS, drop = FALSE]
    x <- x[do.call(order, x), , drop = FALSE]
    rownames(x) <- NULL
    x
  }
  if (!identical(order_id(attempts), order_id(manifest))) {
    stop("Attempt output is not a six-field bijection with the v4 manifest.",
         call. = FALSE)
  }
  invisible(TRUE)
}
cran07_v4_normalize_structural_psi <- function(estimands) {
  structural <- estimands$estimand == "Psi" &
    estimands$trait_i != estimands$trait_j
  if (any(structural)) {
    z <- estimands[structural, , drop = FALSE]
    active <- z$applicable
    bad_truth <- anyNA(z$truth) || any(z$truth != 0)
    bad_active_estimate <- any(active &
      (is.na(z$estimate) | z$estimate != 0))
    bad_inactive_estimate <- any(!active &
      !is.na(z$estimate) & z$estimate != 0)
    if (bad_truth || bad_active_estimate || bad_inactive_estimate) {
      stop("Off-diagonal Psi rows must be exact structural zeros.", call. = FALSE)
    }
    estimands$applicable[structural] <- FALSE
  }
  estimands
}
