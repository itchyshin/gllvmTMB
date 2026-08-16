#!/usr/bin/env Rscript

args0 <- commandArgs(trailingOnly = FALSE)
self <- sub("^--file=", "", args0[grepl("^--file=", args0)])[[1L]]
source(file.path(dirname(normalizePath(self)), "lane-b-b2-runner.R"))
source(file.path(dirname(normalizePath(self)), "lane-b-b2-adjudication.R"))
source(file.path(dirname(normalizePath(self)), "lane-b-quasi-supplement.R"))

args <- commandArgs(trailingOnly = TRUE)
where <- match("--root", args)
if (is.na(where) || where == length(args)) stop("Missing --root")
root <- lane_b_validate_campaign_root(args[[where + 1L]])
b0_where <- match("--b0-root", args)
b0_root <- if (is.na(b0_where)) root else {
  if (b0_where == length(args)) stop("Missing value after --b0-root")
  lane_b_validate_campaign_root(args[[b0_where + 1L]])
}
paths <- lane_b_campaign_paths(root)
original_path <- file.path(paths[["summaries"]], "ordinary-summary.rds")
if (!file.exists(original_path)) stop("Run the immutable campaign aggregation first.")
original <- readRDS(original_path)
if (!identical(original$label, "COMPLETE"))
  stop("Strict adjudication requires the COMPLETE immutable campaign summary.")
frozen <- readRDS(file.path(paths[["frozen"]], "lane-b-b2-frozen.rds"))
campaign_scope <- frozen$campaign_scope %||% "all"
verified <- lane_b_verify_shard_receipts(
  frozen$queue, paths[["raw"]], paths[["state/complete"]],
  hash_field = "sha256", require_complete = TRUE
)
verified_attempts <- do.call(rbind, verified$attempts)
if (!identical(verified_attempts, original$attempts))
  stop("Immutable summary attempts differ from the SHA-256-verified raw shards.")

registry <- lane_b_read_exact_b0_registry(b0_root, version = "v3")
corrected_attempts <- lane_b_recompute_relative_multistart(original$attempts)
corrected_cell_metrics <- lane_b_promotion_metrics(corrected_attempts)
metrics <- lane_b_adjudicate_ordinary(
  corrected_attempts, registry,
  original_metrics = corrected_cell_metrics
)
family_gate <- lane_b_ordinary_family_gate(metrics)
quasi_path <- file.path(root, "quasi-v1", "summaries", "lane-b-quasi-summary-v1.rds")
quasi <- if (file.exists(quasi_path)) readRDS(quasi_path) else NULL
combined_gate <- family_gate
combined_gate$quasi_cells <- 0L
combined_gate$quasi_passing_cells <- 0L
combined_gate$quasi_pass <- FALSE
quasi_multistart_metrics <- NULL
quasi_multistart_gate <- NULL
if (!is.null(quasi)) {
  lane_b_validate_quasi_summary(quasi, dirname(dirname(quasi_path)))
  quasi_corrected_attempts <- lane_b_recompute_relative_multistart(quasi$attempts)
  quasi_corrected_metrics <- lane_b_quasi_cell_metrics(quasi_corrected_attempts)
  qgate <- lane_b_quasi_family_gate(quasi_corrected_metrics)
  quasi_multistart_metrics <- lane_b_adjudicate_quasi_multistart(
    quasi_corrected_attempts
  )
  quasi_multistart_gate <- lane_b_quasi_multistart_family_gate(
    quasi_multistart_metrics
  )
  key <- paste(combined_gate$link, combined_gate$q)
  qkey <- paste(qgate$link, qgate$q)
  idx <- match(key, qkey)
  strict_idx <- match(key, paste(quasi_multistart_gate$link,
                                 quasi_multistart_gate$q))
  combined_gate$quasi_cells <- qgate$cells[idx]
  combined_gate$quasi_passing_cells <- qgate$passing_cells[idx]
  combined_gate$quasi_pass <- qgate$pass[idx] &
    quasi_multistart_gate$pass[strict_idx]
}
combined_gate$pass <- combined_gate$pass & combined_gate$quasi_pass
if (identical(campaign_scope, "all")) {
  authenticated_spatial_v1 <- lane_b_authenticate_spatial_v1(
    verified_attempts, original$spatial_promotion_metrics
  )
  spatial_metrics <- lane_b_adjudicate_spatial(
    corrected_attempts,
    original_metrics = authenticated_spatial_v1
  )
  spatial_family_gate <- lane_b_spatial_family_gate(spatial_metrics)
} else if (identical(campaign_scope, "ordinary_only")) {
  ## Spatial is deliberately absent from this campaign.  Its label remains
  ## withheld below; it must never be inferred from ordinary evidence.
  authenticated_spatial_v1 <- data.frame()
  spatial_metrics <- data.frame()
  spatial_family_gate <- data.frame()
} else {
  stop("Unknown frozen Lane B campaign scope: ", campaign_scope)
}
permutation_metrics <- lane_b_adjudicate_permutation(corrected_attempts)
permutation_gate <- lane_b_permutation_family_gate(permutation_metrics)
labels <- lane_b_final_promotion_labels(
  combined_gate, spatial_family_gate, permutation_gate
)
result <- list(
  label = labels$ordinary_label,
  overall_label = labels$overall_label,
  ordinary_label = labels$ordinary_label,
  spatial_label = labels$spatial_label,
  amendment = paste(
    "Stricter post-launch adjudication using exact realized B0 strata and",
    "mutually usable estimator pairs. The approved relative-Frobenius",
    "multistart statistic supersedes only the immutable elementwise diagnostic;",
    "all thresholds, fits, seeds, and other v1 gates remain unchanged."
  ),
  manifest_version = original$manifest_version,
  campaign_scope = campaign_scope,
  original_summary = basename(original_path),
  original_summary_sha256 = lane_b_sha256_file(original_path),
  original_cell_promotion_metrics = original$cell_promotion_metrics,
  corrected_cell_promotion_metrics = corrected_cell_metrics,
  b0_registry_version = "v3",
  b0_registry_root = b0_root,
  b0_registry_rows = nrow(registry),
  b0_registry_status = as.data.frame(table(registry$b0_stratum),
                                    stringsAsFactors = FALSE),
  ordinary_stratum_metrics = metrics,
  ordinary_family_gate = family_gate,
  quasi_summary = if (is.null(quasi)) NULL else basename(quasi_path),
  quasi_summary_sha256 = if (is.null(quasi)) NA_character_ else
    lane_b_sha256_file(quasi_path),
  original_quasi_cell_metrics = if (is.null(quasi)) NULL else quasi$cell_metrics,
  corrected_quasi_cell_metrics = if (is.null(quasi)) NULL else
    quasi_corrected_metrics,
  quasi_multistart_metrics = quasi_multistart_metrics,
  quasi_multistart_family_gate = quasi_multistart_gate,
  combined_ordinary_gate = combined_gate,
  original_permutation_invariance_metrics =
    original$permutation_invariance_metrics,
  permutation_invariance_metrics = permutation_metrics,
  permutation_cell_gate = permutation_gate$cell_gate,
  permutation_family_gate = permutation_gate$family_gate,
  permutation_pass = permutation_gate$pass,
  original_spatial_promotion_metrics = authenticated_spatial_v1,
  spatial_promotion_metrics = spatial_metrics,
  spatial_family_gate = spatial_family_gate,
  thresholds = lane_b_adjudication_thresholds()
)
out <- file.path(paths[["summaries"]], "lane-b-b2-adjudication-v2.rds")
lane_b_atomic_save_rds(result, out)
cat(result$overall_label, "\n")
cat(result$ordinary_label, "\n")
print(combined_gate)
cat(result$spatial_label, "\n")
print(spatial_family_gate)
