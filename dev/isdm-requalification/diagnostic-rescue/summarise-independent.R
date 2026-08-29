## Independent, pure-reader adjudicator for retained diagnostic records.
## This file deliberately sources no runner, contract, or diagnostic helper.

ISDM_DIAG_SUMMARY_SCHEMA <- "isdm-identifiability-independent-summary-v1"

.ind_abort <- function(message) stop(message, call. = FALSE)
.ind_scalar <- function(x) length(x) == 1L && !is.na(x)
.ind_finite <- function(x) .ind_scalar(x) && is.finite(x)
.ind_leaf <- function(id) sprintf("task-%06d.rds", as.integer(id))

.ind_plan <- function(path, expected_n = 52L) {
  plan <- readRDS(path)
  required <- c("task_id", "slice", "native_task_id", "seed", "n_sources",
                "overlap", "n_cells", "variant", "sentinel_class")
  if (!is.data.frame(plan) || !all(required %in% names(plan)) ||
      nrow(plan) != expected_n || anyNA(plan$task_id) ||
      anyDuplicated(plan$task_id)) {
    .ind_abort("plan does not contain the expected unique task identities")
  }
  if (expected_n == 52L &&
      (!identical(as.integer(plan$task_id), 1:52) ||
       sum(plan$slice == "nonspatial") != 16L ||
       sum(plan$slice == "spatial") != 36L)) {
    .ind_abort("production plan differs from the frozen 16 + 36 contract")
  }
  plan
}

.ind_read_rds_files <- function(directory, pattern) {
  if (!dir.exists(directory)) return(list())
  paths <- sort(list.files(directory, pattern = pattern, full.names = TRUE))
  stats::setNames(lapply(paths, readRDS), basename(paths))
}

.ind_task_matches <- function(record, row) {
  if (!is.list(record$task)) return(FALSE)
  keys <- intersect(names(row), names(record$task))
  length(keys) == ncol(row) && all(vapply(keys, function(key) {
    identical(record$task[[key]], as.list(row)[[key]])
  }, logical(1L)))
}

.ind_dispositions <- function(plan, output_dir) {
  workers <- .ind_read_rds_files(file.path(output_dir, "attempts"),
                                 "^task-[0-9]{6}[.]rds$")
  started <- .ind_read_rds_files(file.path(output_dir, "started"),
                                 "^task-[0-9]{6}[.]rds$")
  reconciliation <- .ind_read_rds_files(
    file.path(output_dir, "coordinator"), "^reconciliation-.*[.]rds$"
  )
  coordinator <- unlist(lapply(reconciliation, function(x) {
    if (!is.list(x) ||
        !identical(x$schema, "isdm-diagnostic-coordinator-reconciliation-v1") ||
        !is.list(x$dispositions)) .ind_abort("invalid coordinator receipt")
    x$dispositions
  }), recursive = FALSE)
  all_records <- c(workers, coordinator)
  ids <- vapply(all_records, function(x) as.integer(x$task_id), integer(1L))
  if (length(all_records) != nrow(plan) || anyNA(ids) ||
      !identical(unname(sort(ids)), sort(as.integer(plan$task_id)))) {
    .ind_abort("terminal dispositions are not exactly one per planned task")
  }
  started_ids <- vapply(started, function(x) as.integer(x$task_id), integer(1L))
  if (anyNA(started_ids) || anyDuplicated(started_ids) ||
      any(!started_ids %in% plan$task_id)) {
    .ind_abort("started receipts contain invalid or duplicate task identities")
  }
  records <- lapply(plan$task_id, function(id) all_records[[which(ids == id)]])
  for (i in seq_along(records)) {
    x <- records[[i]]
    row <- plan[i, , drop = FALSE]
    if (!identical(x$schema, "isdm-identifiability-diagnostic-v1") ||
        !identical(as.integer(x$task_id), as.integer(row$task_id)) ||
        !.ind_task_matches(x, row) ||
        !x$status %in% c("fit_returned", "error", "interrupted", "unavailable") ||
        !x$disposition_source %in% c("worker", "coordinator")) {
      .ind_abort(sprintf("terminal record for task %d is invalid", row$task_id))
    }
  }
  list(records = records, started_n = length(started),
       worker_n = length(workers), coordinator_n = length(coordinator))
}

.ind_metric <- function(record, target, metric) {
  value <- record$metrics[[target]][[metric]]
  if (.ind_finite(value)) as.numeric(value) else NA_real_
}

.ind_nonsp_row <- function(record, task) {
  returned <- identical(record$status, "fit_returned")
  data.frame(
    task_id = task$task_id, native_task_id = task$native_task_id,
    variant = task$variant, n_sources = task$n_sources,
    overlap = task$overlap, n_cells = task$n_cells, returned = returned,
    fixed_correlation = if (returned) .ind_metric(record, "fixed", "correlation") else NA,
    fixed_nrmse = if (returned) .ind_metric(record, "fixed", "normalized_rmse") else NA,
    shared_correlation = if (returned) .ind_metric(record, "shared", "correlation") else NA,
    shared_nrmse = if (returned) .ind_metric(record, "shared", "normalized_rmse") else NA,
    full_correlation = if (returned) .ind_metric(record, "full", "correlation") else NA,
    full_nrmse = if (returned) .ind_metric(record, "full", "normalized_rmse") else NA,
    sigma_error = if (returned && .ind_finite(record$metrics$Sigma_relative_frobenius))
      record$metrics$Sigma_relative_frobenius else NA,
    psi1_error = if (returned && length(record$metrics$Psi_relative_error) >= 1L &&
                         is.finite(record$metrics$Psi_relative_error[[1L]]))
      record$metrics$Psi_relative_error[[1L]] else NA,
    curvature_available = returned && isTRUE(record$curvature$available),
    stringsAsFactors = FALSE
  )
}

.ind_state <- function(record) {
  if (!identical(record$status, "fit_returned")) return(record$status)
  convergence <- record$diagnostics$convergence
  pd <- record$diagnostics$pd_hessian
  if (!.ind_scalar(convergence) || !.ind_scalar(pd)) return("diagnostic_unavailable")
  paste0(if (as.integer(convergence) == 0L) "converged" else "nonconverged",
         if (isTRUE(pd)) "_pd" else "_nonpd")
}

.ind_spatial_row <- function(record, task) {
  returned <- identical(record$status, "fit_returned")
  top <- if (returned) record$curvature$attribution$relative$smallest_algebraic$block_mass else NULL
  data.frame(
    task_id = task$task_id, native_task_id = task$native_task_id,
    variant = task$variant, sentinel_class = task$sentinel_class,
    n_sources = task$n_sources, overlap = task$overlap,
    status = record$status, state = .ind_state(record), returned = returned,
    fresh_objective = if (returned && .ind_finite(record$diagnostics$fresh_objective))
      record$diagnostics$fresh_objective else NA,
    max_gradient = if (returned && .ind_finite(record$diagnostics$max_gradient))
      record$diagnostics$max_gradient else NA,
    heldout_correlation = if (returned) .ind_metric(record, "heldout", "correlation") else NA,
    heldout_nrmse = if (returned) .ind_metric(record, "heldout", "normalized_rmse") else NA,
    curvature_available = returned && isTRUE(record$curvature$available),
    ranking_agrees = returned && isTRUE(record$curvature$attribution$ranking_agrees),
    top_block = if (is.data.frame(top) && nrow(top)) as.character(top$block[[1L]]) else NA_character_,
    top_N = if (is.data.frame(top) && nrow(top) && is.finite(top$N[[1L]])) top$N[[1L]] else NA_real_,
    stringsAsFactors = FALSE
  )
}

.ind_quantiles <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(c(median = NA, q25 = NA, q75 = NA))
  c(median = stats::median(x), q25 = unname(stats::quantile(x, .25)),
    q75 = unname(stats::quantile(x, .75)))
}

.ind_pair_nonsp <- function(nonsp) {
  groups <- split(nonsp, nonsp$native_task_id)
  rows <- lapply(groups, function(x) {
    base <- x[x$variant == "baseline", , drop = FALSE]
    rep3 <- x[x$variant == "rep3", , drop = FALSE]
    available <- nrow(base) == 1L && nrow(rep3) == 1L &&
      isTRUE(base$returned) && isTRUE(rep3$returned) &&
      all(is.finite(c(base$full_nrmse, rep3$full_nrmse,
                      base$full_correlation, rep3$full_correlation,
                      base$psi1_error, rep3$psi1_error,
                      base$shared_nrmse, base$shared_correlation)))
    data.frame(
      native_task_id = x$native_task_id[[1L]], available = available,
      full_nrmse_reduction = if (available) base$full_nrmse - rep3$full_nrmse else NA,
      full_correlation_change = if (available) rep3$full_correlation - base$full_correlation else NA,
      psi1_error_reduction = if (available) base$psi1_error - rep3$psi1_error else NA,
      baseline_estimand_nrmse_gap = if (available) base$full_nrmse - base$shared_nrmse else NA,
      baseline_shared_correlation_advantage = if (available)
        base$shared_correlation - base$full_correlation else NA,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

.ind_optimizer_comparison <- function(spatial, variant) {
  groups <- split(spatial, spatial$native_task_id)
  do.call(rbind, lapply(groups, function(x) {
    default <- x[x$variant == "default", , drop = FALSE]
    alternative <- x[x$variant == variant, , drop = FALSE]
    eligible_input <- nrow(default) == 1L && default$sentinel_class != "converged_pd"
    comparable <- eligible_input && nrow(alternative) == 1L &&
      isTRUE(default$returned) && isTRUE(alternative$returned) &&
      all(is.finite(c(default$fresh_objective, alternative$fresh_objective,
                      default$max_gradient, alternative$max_gradient,
                      default$heldout_correlation, alternative$heldout_correlation,
                      default$heldout_nrmse, alternative$heldout_nrmse)))
    passes <- comparable && alternative$state == "converged_pd" &&
      alternative$fresh_objective <= default$fresh_objective +
        1e-6 * (1 + abs(default$fresh_objective)) &&
      alternative$max_gradient <= max(default$max_gradient, .01) &&
      alternative$heldout_correlation >= default$heldout_correlation - .005 &&
      alternative$heldout_nrmse <= default$heldout_nrmse + .01
    data.frame(native_task_id = x$native_task_id[[1L]], variant = variant,
               eligible_input = eligible_input, comparable = comparable,
               passes = passes, stringsAsFactors = FALSE)
  }))
}

isdm_diag_independent_summary <- function(plan_path, output_dir) {
  plan <- .ind_plan(plan_path, 52L)
  disposition <- .ind_dispositions(plan, output_dir)
  records <- disposition$records
  status <- factor(vapply(records, `[[`, character(1L), "status"),
                   levels = c("fit_returned", "error", "interrupted", "unavailable"))
  non_idx <- which(plan$slice == "nonspatial")
  spatial_idx <- which(plan$slice == "spatial")
  nonsp <- do.call(rbind, Map(.ind_nonsp_row, records[non_idx],
                              split(plan[non_idx, , drop = FALSE], seq_along(non_idx))))
  spatial <- do.call(rbind, Map(.ind_spatial_row, records[spatial_idx],
                                split(plan[spatial_idx, , drop = FALSE], seq_along(spatial_idx))))
  contrasts <- .ind_pair_nonsp(nonsp)
  basin <- .ind_optimizer_comparison(spatial, "nlminb5")
  termination <- .ind_optimizer_comparison(spatial, "bfgs_continuation")

  replication_signal <- nrow(contrasts) == 8L && all(contrasts$available) &&
    sum(contrasts$full_nrmse_reduction > 0) >= 7L &&
    median(contrasts$full_nrmse_reduction) >= .05 &&
    sum(contrasts$full_correlation_change >= 0) >= 7L &&
    sum(contrasts$psi1_error_reduction > 0) >= 6L &&
    median(contrasts$psi1_error_reduction) >= .10
  estimand_signal <- nrow(contrasts) == 8L && all(contrasts$available) &&
    sum(contrasts$baseline_estimand_nrmse_gap >= .10 &
          contrasts$baseline_shared_correlation_advantage >= 0) >= 7L
  basin_signal <- sum(basin$eligible_input) == 8L &&
    sum(basin$passes[basin$eligible_input]) >= 6L
  termination_signal <- sum(termination$eligible_input) == 8L &&
    sum(termination$passes[termination$eligible_input]) >= 6L

  defaults <- spatial[spatial$variant == "default", , drop = FALSE]
  curvature_block <- NA_character_
  curvature_count <- 0L
  curvature_median_N <- NA_real_
  curvature_agreement <- nrow(defaults) == 12L && all(defaults$ranking_agrees)
  if (curvature_agreement && all(!is.na(defaults$top_block))) {
    block_counts <- sort(table(defaults$top_block), decreasing = TRUE)
    curvature_block <- names(block_counts)[[1L]]
    curvature_count <- as.integer(block_counts[[1L]])
    curvature_median_N <- median(defaults$top_N[defaults$top_block == curvature_block])
  }
  curvature_signal <- !basin_signal && !termination_signal &&
    curvature_agreement && curvature_count >= 9L &&
    is.finite(curvature_median_N) && curvature_median_N >= .50
  signals <- c(REPLICATION_SIGNAL = replication_signal,
               ESTIMAND_SIGNAL = estimand_signal,
               BASIN_SIGNAL = basin_signal,
               TERMINATION_SIGNAL = termination_signal,
               CURVATURE_SIGNAL = curvature_signal)
  fired <- names(signals)[signals]
  next_action <- if (length(fired) == 1L) fired else "MIXED"

  target_available <- c(
    nonspatial_fixed = sum(is.finite(nonsp$fixed_nrmse) & is.finite(nonsp$fixed_correlation)),
    nonspatial_shared = sum(is.finite(nonsp$shared_nrmse) & is.finite(nonsp$shared_correlation)),
    nonspatial_full = sum(is.finite(nonsp$full_nrmse) & is.finite(nonsp$full_correlation)),
    nonspatial_sigma = sum(is.finite(nonsp$sigma_error)),
    nonspatial_psi1 = sum(is.finite(nonsp$psi1_error)),
    nonspatial_curvature = sum(nonsp$curvature_available),
    spatial_heldout = sum(is.finite(spatial$heldout_nrmse) & is.finite(spatial$heldout_correlation)),
    spatial_curvature = sum(spatial$curvature_available),
    spatial_joint_precision = sum(vapply(records[spatial_idx], function(x)
      identical(x$status, "fit_returned") && isTRUE(x$curvature$joint_precision$available), logical(1L)))
  )
  list(
    schema = ISDM_DIAG_SUMMARY_SCHEMA,
    denominators = list(
      planned = nrow(plan), started = disposition$started_n,
      terminal = length(records), worker = disposition$worker_n,
      coordinator = disposition$coordinator_n,
      status = stats::setNames(as.integer(table(status)), levels(status)),
      target_available = target_available,
      nonspatial_pairs_planned = 8L,
      nonspatial_pairs_available = sum(contrasts$available),
      spatial_sentinels_planned = 12L,
      spatial_ineligible_planned = sum(basin$eligible_input),
      basin_comparable = sum(basin$comparable),
      termination_comparable = sum(termination$comparable)
    ),
    nonspatial = nonsp, nonspatial_contrasts = contrasts,
    nonspatial_delta_summary = rbind(
      full_nrmse_reduction = .ind_quantiles(contrasts$full_nrmse_reduction),
      full_correlation_change = .ind_quantiles(contrasts$full_correlation_change),
      psi1_error_reduction = .ind_quantiles(contrasts$psi1_error_reduction)
    ),
    spatial = spatial, basin_comparison = basin,
    termination_comparison = termination,
    curvature = list(ranking_agrees_all = curvature_agreement,
                     dominant_block = curvature_block,
                     dominant_count = curvature_count,
                     dominant_median_N = curvature_median_N),
    signals = signals, fired_signals = fired, next_action = next_action
  )
}

.ind_running_file <- function() {
  script <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  length(script) == 1L && identical(
    normalizePath(sub("^--file=", "", script), mustWork = TRUE),
    normalizePath(tryCatch(sys.frame(1)$ofile, error = function(e) script),
                  mustWork = TRUE)
  )
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) {
    stop("usage: summarise-independent.R PLAN_RDS OUTPUT_DIR SUMMARY_RDS")
  }
  if (file.exists(args[[3L]])) stop("summary output already exists")
  summary <- isdm_diag_independent_summary(args[[1L]], args[[2L]])
  saveRDS(summary, args[[3L]], version = 3)
  cat("DIAGNOSTIC_INDEPENDENT_SUMMARY_WRITTEN\n")
}
