## Deterministic all-attempt reconciliation and ADEMP summaries.
## This file never fits a model.

if (!exists("MIXED_LV_HARNESS_SCHEMA", inherits = TRUE)) {
  candidates <- c(file.path("dev", "mixed-lv-family-wide", "00-manifest.R"),
    file.path("00-manifest.R"))
  f <- candidates[file.exists(candidates)][1L]
  if (is.na(f)) stop("Cannot locate 00-manifest.R")
  source(f, local = FALSE)
}

if (!exists("mixed_lv_attempt_stub", inherits = TRUE)) {
  candidates <- c(file.path("dev", "mixed-lv-family-wide", "01-run.R"),
    file.path("01-run.R"))
  f <- candidates[file.exists(candidates)][1L]
  if (is.na(f)) stop("Cannot locate 01-run.R")
  source(f, local = FALSE)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

mixed_lv_record_row <- function(x) data.frame(
  task_id = as.integer(x$task_id), cell_id = as.character(x$cell_id),
  campaign_kind = as.character(x$campaign_kind), rep = as.integer(x$rep),
  rep_seed = as.integer(x$rep_seed), evidence_eligible = isTRUE(x$evidence_eligible),
  status = as.character(x$status), failure_stage = x$failure_stage %||% NA_character_,
  fit_converged = isTRUE(x$fit_converged), point_eligible = isTRUE(x$point_eligible),
  interval_eligible = isTRUE(x$interval_eligible),
  max_gradient = x$max_gradient %||% NA_real_,
  pd_hessian = isTRUE(x$pd_hessian),
  family_ids_ok = isTRUE(x$family_ids_ok),
  link_pairs_ok = isTRUE(x$link_pairs_ok),
  diag_B_disabled = isTRUE(x$diag_B_disabled),
  dgp_support_ok = isTRUE(x$dgp_support_ok),
  B_lv_abs_error = x$B_lv_abs_error %||% NA_real_,
  Sigma_rel_frob_error = x$Sigma_rel_frob_error %||% NA_real_,
  intercept_rmse = x$intercept_rmse %||% NA_real_,
  score_identity_error = x$score_identity_error %||% NA_real_,
  covered_all_B_lv = x$covered_all_B_lv %||% NA,
  runtime_s = x$runtime_s %||% NA_real_, warning_count = x$warning_count %||% 0L,
  error_message = x$error_message %||% NA_character_, stringsAsFactors = FALSE
)

mixed_lv_validate_record_identity <- function(records) {
  if (!length(records)) return(invisible(TRUE))
  first_source <- records[[1L]]$source_manifest
  first_harness <- records[[1L]]$harness_manifest
  if (!identical(first_harness, mixed_lv_harness_manifest())) {
    stop("campaign_identity_mismatch: current harness/driver hashes differ from retained records")
  }
  for (r in records) {
    if (!identical(r$manifest_id, MIXED_LV_MANIFEST_ID) ||
        !identical(r$formula_id, MIXED_LV_FORMULA_ID) ||
        !identical(r$pinned_head, MIXED_LV_PINNED_HEAD)) {
      stop("campaign_identity_mismatch: manifest, formula, or source HEAD differs")
    }
    mixed_lv_validate_source_manifest(r$source_manifest)
    if (!identical(r$source_manifest, first_source) ||
        !identical(r$harness_manifest, first_harness)) {
      stop("campaign_identity_mismatch: source or driver hashes differ across attempts")
    }
  }
  invisible(TRUE)
}

mixed_lv_reconcile_attempts <- function(plan, records, started_records = list()) {
  record_ids <- vapply(records, function(x) as.character(x$task_id), character(1L))
  started_ids <- vapply(started_records, function(x) as.character(x$task_id), character(1L))
  if (anyDuplicated(record_ids)) stop("duplicate final attempt record for one task_id")
  if (anyDuplicated(started_ids)) stop("duplicate started attempt record for one task_id")
  plan_ids <- as.character(plan$task_id)
  if (any(!record_ids %in% plan_ids) || any(!started_ids %in% plan_ids)) {
    stop("campaign_identity_mismatch: attempt task_id is absent from the immutable plan")
  }
  by_id <- setNames(records, record_ids)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    key <- as.character(plan$task_id[[i]])
    if (!is.null(by_id[[key]])) {
      r <- by_id[[key]]
      if (!identical(as.character(r$cell_id), plan$cell_id[[i]]) ||
          !identical(as.character(r$campaign_kind), plan$campaign_kind[[i]]) ||
          !identical(as.integer(r$rep), plan$rep[[i]]) ||
          !identical(as.integer(r$rep_seed), plan$rep_seed[[i]])) {
        stop("campaign_identity_mismatch: record does not match its immutable task row")
      }
      return(mixed_lv_record_row(r))
    }
    was_started <- key %in% started_ids
    missing <- mixed_lv_attempt_stub(plan[i, , drop = FALSE],
      status = if (was_started) "interrupted_missing_final" else "planned_not_started",
      failure_stage = if (was_started) "retention" else "launch")
    mixed_lv_record_row(missing)
  })
  out <- do.call(rbind, rows); row.names(out) <- NULL
  if (!identical(out$task_id, plan$task_id) || nrow(out) != nrow(plan)) {
    stop("all-attempt denominator mismatch")
  }
  out
}

mixed_lv_summarise_cell <- function(rows, expected_reps) {
  n <- nrow(rows)
  status <- rows$status %||% rep("attempted_status_unavailable", n)
  n_attempted <- sum(status != "planned_not_started")
  n_conv <- sum(rows$fit_converged %in% TRUE)
  n_point <- sum(rows$point_eligible %in% TRUE)
  n_interval <- sum(rows$interval_eligible %in% TRUE)
  covered <- rows$covered_all_B_lv[rows$interval_eligible %in% TRUE]
  coverage <- if (n_interval) mean(covered, na.rm = TRUE) else NA_real_
  coverage_mcse <- if (n_interval && is.finite(coverage))
    sqrt(coverage * (1 - coverage) / n_interval) else NA_real_
  data.frame(
    cell_id = unique(rows$cell_id)[[1L]],
    campaign_kind = unique(rows$campaign_kind)[[1L]],
    expected_reps = as.integer(expected_reps), n_planned = n,
    n_attempted = n_attempted,
    exact_denominator = identical(as.integer(n), as.integer(expected_reps)),
    attempt_denominator_complete = identical(as.integer(n_attempted), as.integer(expected_reps)),
    n_converged = n_conv, convergence_rate = n_conv / n,
    fit_failure_rate = 1 - n_conv / n,
    n_point_eligible = n_point, point_availability_rate = n_point / n,
    n_interval_eligible = n_interval, interval_availability_rate = n_interval / n,
    coverage = coverage, coverage_mcse = coverage_mcse,
    median_B_lv_abs_error = if (n_point) stats::median(rows$B_lv_abs_error[rows$point_eligible], na.rm = TRUE) else NA_real_,
    median_Sigma_rel_frob_error = if (n_point) stats::median(rows$Sigma_rel_frob_error[rows$point_eligible], na.rm = TRUE) else NA_real_,
    mean_intercept_rmse = if (n_point) mean(rows$intercept_rmse[rows$point_eligible], na.rm = TRUE) else NA_real_,
    max_score_identity_error = if (n_point &&
      any(is.finite(rows$score_identity_error[rows$point_eligible]))) {
      max(rows$score_identity_error[rows$point_eligible], na.rm = TRUE)
    } else NA_real_,
    stringsAsFactors = FALSE
  )
}

mixed_lv_target_rows <- function(records) {
  out <- list(); k <- 0L
  add <- function(x) { k <<- k + 1L; out[[k]] <<- x }
  for (r in records) {
    if (!isTRUE(r$point_eligible)) next
    base <- data.frame(task_id = r$task_id, cell_id = r$cell_id,
      campaign_kind = r$campaign_kind, rep = r$rep, stringsAsFactors = FALSE)
    for (j in seq_along(r$B_lv_error %||% numeric())) add(transform(base,
      target = "B_lv", target_id = paste0("B_lv[", j, "]"), error = r$B_lv_error[[j]],
      covered = if (isTRUE(r$interval_eligible)) r$B_lv_covered[[j]] else NA))
    for (j in seq_along(r$Sigma_entry_error %||% numeric())) add(transform(base,
      target = "Sigma_shared", target_id = paste0("Sigma_shared[", j, "]"),
      error = r$Sigma_entry_error[[j]], covered = NA))
    for (j in seq_along(r$intercept_error %||% numeric())) add(transform(base,
      target = "intercept", target_id = paste0("intercept[", j, "]"),
      error = r$intercept_error[[j]], covered = NA))
  }
  if (!length(out)) return(data.frame())
  do.call(rbind, out)
}

mixed_lv_summarise_targets <- function(target_rows) {
  if (!nrow(target_rows)) return(data.frame())
  groups <- interaction(target_rows$cell_id, target_rows$target,
    target_rows$target_id, drop = TRUE)
  rows <- lapply(split(target_rows, groups), function(x) {
    n_ci <- sum(!is.na(x$covered)); coverage <- if (n_ci) mean(x$covered, na.rm = TRUE) else NA_real_
    data.frame(cell_id = x$cell_id[[1L]], target = x$target[[1L]],
      target_id = x$target_id[[1L]], n_point = nrow(x), bias = mean(x$error),
      bias_mcse = if (nrow(x) > 1L) stats::sd(x$error) / sqrt(nrow(x)) else NA_real_,
      rmse = sqrt(mean(x$error^2)),
      rmse_mcse = {
        rmse <- sqrt(mean(x$error^2))
        if (nrow(x) > 1L && rmse > 0) stats::sd(x$error^2) / sqrt(nrow(x)) / (2 * rmse) else if (rmse == 0) 0 else NA_real_
      },
      n_interval = n_ci, coverage = coverage,
      coverage_mcse = if (n_ci) sqrt(coverage * (1 - coverage) / n_ci) else NA_real_,
      nominal_coverage_mcse = if (n_ci) sqrt(.95 * .05 / n_ci) else NA_real_)
  })
  do.call(rbind, rows)
}

mixed_lv_apply_gates <- function(cell_summary, target_summary) {
  empty_targets <- data.frame(
    target = character(), target_id = character(), bias = numeric(),
    rmse = numeric(), n_interval = integer(), coverage = numeric(),
    stringsAsFactors = FALSE
  )
  by_cell <- if (nrow(target_summary) && "cell_id" %in% names(target_summary)) {
    split(target_summary, target_summary$cell_id)
  } else list()
  rows <- lapply(seq_len(nrow(cell_summary)), function(i) {
    s <- cell_summary[i, ]; t <- by_cell[[s$cell_id]] %||% empty_targets
    attempt_complete <- if ("attempt_denominator_complete" %in% names(s)) {
      isTRUE(s$attempt_denominator_complete)
    } else {
      isTRUE(s$exact_denominator)
    }
    B <- t[t$target == "B_lv", , drop = FALSE]
    S <- t[t$target == "Sigma_shared", , drop = FALSE]
    I <- t[t$target == "intercept", , drop = FALSE]
    calibration <- identical(s$campaign_kind, "calibration")
    interval_pass <- if (!calibration) NA else nrow(B) > 0L &&
      all(B$n_interval >= MIXED_LV_THRESHOLDS$min_interval_eligible) &&
      all(B$coverage >= MIXED_LV_THRESHOLDS$coverage_band[[1L]] &
          B$coverage <= MIXED_LV_THRESHOLDS$coverage_band[[2L]])
    data.frame(cell_id = s$cell_id, campaign_kind = s$campaign_kind,
      denominator_pass = isTRUE(s$exact_denominator) &&
        attempt_complete,
      convergence_pass = s$convergence_rate >= MIXED_LV_THRESHOLDS$min_convergence_rate,
      point_availability_pass = s$point_availability_rate >= MIXED_LV_THRESHOLDS$min_point_availability_rate,
      B_bias_pass = nrow(B) > 0L && max(abs(B$bias)) <= MIXED_LV_THRESHOLDS$max_abs_B_bias,
      B_rmse_pass = nrow(B) > 0L && max(B$rmse) <= MIXED_LV_THRESHOLDS$max_B_rmse,
      Sigma_bias_pass = nrow(S) > 0L && max(abs(S$bias)) <= MIXED_LV_THRESHOLDS$max_abs_Sigma_entry_bias,
      intercept_bias_pass = nrow(I) > 0L && max(abs(I$bias)) <= MIXED_LV_THRESHOLDS$max_abs_intercept_bias,
      score_identity_pass = is.finite(s$max_score_identity_error) &&
        s$max_score_identity_error <= MIXED_LV_THRESHOLDS$max_score_identity_error,
      interval_pass = interval_pass, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  required <- setdiff(names(out), c("cell_id", "campaign_kind", "interval_pass"))
  out$point_verdict <- apply(out[, required, drop = FALSE], 1L, function(x) all(x %in% TRUE))
  out$calibration_verdict <- ifelse(out$campaign_kind == "calibration",
    out$point_verdict & out$interval_pass, NA)
  out
}

mixed_lv_collect <- function(output_dir, campaign_kind) {
  plan <- mixed_lv_task_grid(campaign_kind); mixed_lv_assert_evidence_rows(plan)
  files <- list.files(file.path(output_dir, "attempts"), pattern = "\\.rds$", full.names = TRUE)
  started_files <- list.files(file.path(output_dir, "started"),
    pattern = "\\.rds$", full.names = TRUE)
  records <- lapply(files, readRDS)
  started_records <- lapply(started_files, readRDS)
  mixed_lv_validate_record_identity(records)
  mixed_lv_validate_record_identity(started_records)
  ledger <- mixed_lv_reconcile_attempts(plan, records, started_records)
  expected <- if (campaign_kind == "calibration") {
    MIXED_LV_THRESHOLDS$calibration_reps
  } else MIXED_LV_THRESHOLDS$recovery_reps
  cells <- lapply(split(ledger, ledger$cell_id), mixed_lv_summarise_cell, expected_reps = expected)
  cell_summary <- do.call(rbind, cells)
  target_summary <- mixed_lv_summarise_targets(mixed_lv_target_rows(records))
  list(ledger = ledger, cell_summary = cell_summary, target_summary = target_summary,
    gates = mixed_lv_apply_gates(cell_summary, target_summary))
}
