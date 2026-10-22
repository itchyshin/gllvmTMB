## Deterministic checkpoint receipt for the retained 16-fit DRAC pilot.
## The runtime projection intentionally uses the slowest observed task and
## the predeclared maximum of 16 concurrent one-thread workers.

source("dev/isdm-requalification/response-information/contract.R", local = TRUE)
source("dev/isdm-requalification/response-information/records.R", local = TRUE)
source("dev/isdm-requalification/response-information/recompute.R", local = TRUE)

isdm_respinfo_pilot_checkpoint <- function(plan_path, output_dir,
                                           max_concurrent = 16L,
                                           remaining_fits = 784L) {
  remaining_fits <- as.integer(remaining_fits)
  if (!identical(as.integer(max_concurrent), 16L) || !remaining_fits %in% c(784L, 770L)) {
    stop("pilot checkpoint must use 16 workers and either the original 784 or approved 770 remaining-fit contract", call. = FALSE)
  }
  plan <- readRDS(plan_path)
  if (nrow(plan) != 16L || !all(plan$seed_index == 1L)) {
    stop("pilot checkpoint requires the frozen 16-identity pilot plan", call. = FALSE)
  }
  records <- isdm_respinfo_pilot_dispositions(plan, output_dir)
  worker_paths <- list.files(file.path(output_dir, "attempts"), pattern = "^task-[0-9]{6}[.]rds$", full.names = TRUE)
  worker_ids <- unname(sort(vapply(worker_paths, function(path) as.integer(readRDS(path)$task_id), integer(1L))))
  recovery_ids <- as.integer(c(1:16, 101, 102, 201, 202, 301, 302, 401, 402, 501, 502, 601, 602, 701, 702))
  expected_worker_ids <- if (identical(remaining_fits, 784L)) sort(as.integer(plan$task_id)) else recovery_ids
  if (!identical(worker_ids, expected_worker_ids)) stop("pilot checkpoint worker receipts do not match its frozen allocation", call. = FALSE)
  valid <- vapply(records, function(x) {
    identical(x$status, "fit_returned") &&
      identical(x$disposition_source, "worker") &&
      isTRUE(x$optimizer_entered) &&
      identical(as.integer(x$diagnostics$convergence), 0L) &&
      isTRUE(x$diagnostics$pd_hessian) &&
      isTRUE(x$diagnostics$finite) &&
      is.finite(x$diagnostics$max_gradient) &&
      x$diagnostics$max_gradient <= ISDM_RESPINFO_GRADIENT_MAX &&
      !is.null(x$raw) &&
      all(is.finite(unlist(isdm_respinfo_recompute_raw(x$raw), use.names = FALSE))) &&
      is.finite(x$diagnostics$peak_rss_bytes) &&
      x$diagnostics$peak_rss_bytes <= 8 * 1024^3
  }, logical(1L))
  if (length(records) != 16L || !all(valid)) stop("retained pilot checkpoint gate failed", call. = FALSE)
  if (length(unique(vapply(records, `[[`, character(1L), "source_sha"))) != 1L ||
      length(unique(vapply(records, `[[`, character(1L), "harness_manifest_sha256"))) != 1L) {
    stop("retained pilot checkpoint is not bound to one source and manifest", call. = FALSE)
  }
  pairs <- split(records, vapply(records, function(x) as.integer(x$task$dataset_id), integer(1L)))
  if (!all(vapply(pairs, function(pair) {
    length(pair) == 2L && identical(pair[[1L]]$raw$baseline_data_sha256, pair[[2L]]$raw$baseline_data_sha256)
  }, logical(1L)))) stop("retained pilot checkpoint baseline nesting receipt failed", call. = FALSE)
  runtime_s <- vapply(records, `[[`, numeric(1L), "runtime_s")
  rss_bytes <- vapply(records, function(x) x$diagnostics$peak_rss_bytes, numeric(1L))
  gradients <- vapply(records, function(x) x$diagnostics$max_gradient, numeric(1L))
  projected_s <- max(runtime_s) * ceiling(as.integer(remaining_fits) / as.integer(max_concurrent))
  receipt <- list(
    schema = "isdm-response-information-pilot-checkpoint-v2",
    source_sha = records[[1L]]$source_sha,
    harness_manifest_sha256 = records[[1L]]$harness_manifest_sha256,
    planned_pilot_fits = 16L,
    valid_pilot_fits = sum(valid),
    pre_scaleup_terminal_fits = length(worker_ids),
    pilot_mapping_recovery = identical(remaining_fits, 770L),
    maximum_gradient = max(gradients),
    peak_rss_bytes = max(rss_bytes),
    max_task_runtime_s = max(runtime_s),
    median_task_runtime_s = stats::median(runtime_s),
    max_concurrent_workers = as.integer(max_concurrent),
    remaining_retained_fits = as.integer(remaining_fits),
    conservative_projected_runtime_s = projected_s,
    projection_within_six_hours = isTRUE(projected_s <= 6 * 60 * 60),
    checkpoint_eligible = isTRUE(projected_s <= 6 * 60 * 60)
  )
  if (!receipt$checkpoint_eligible) stop("pilot projection exceeds the frozen six-hour limit", call. = FALSE)
  receipt
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  if (!length(args) %in% c(3L, 4L)) stop("usage: pilot-checkpoint.R <pilot-plan.rds> <output-dir> <checkpoint.rds> [remaining-fits]", call. = FALSE)
  remaining_fits <- if (length(args) == 4L) as.integer(args[[4L]]) else 784L
  receipt <- isdm_respinfo_pilot_checkpoint(args[[1L]], args[[2L]], remaining_fits = remaining_fits)
  saveRDS(receipt, args[[3L]], version = 3)
  cat("response information pilot checkpoint passed\n")
}
