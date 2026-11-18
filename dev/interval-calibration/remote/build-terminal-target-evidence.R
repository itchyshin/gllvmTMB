#!/usr/bin/env Rscript
## Replay terminal target evidence from an immutable corrected campaign root.
## This script performs no fit, simulation, or interval calculation from data;
## it adjudicates retained rows using each packet's frozen source tree.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop(
    paste(
      "usage: build-terminal-target-evidence.R",
      "CORRECTED_ROOT OUTPUT_RDS OUTPUT_CSV"
    ),
    call. = FALSE
  )
}
root <- normalizePath(args[[1L]], mustWork = TRUE)
output_rds <- args[[2L]]
output_csv <- args[[3L]]
source("dev/interval-calibration/remote/shard-io.R")

scientific_root <- function(sha) {
  path <- file.path(root, "scientific", sha)
  if (!dir.exists(path)) {
    interval_stop("corrected archive lacks frozen source ", sha)
  }
  path
}

pvt_sha <- "1d4e03d926f78a244257d03c3a0669549c0eceac"
pvt_source <- scientific_root(pvt_sha)
pvt <- readRDS(file.path(root, "pvt02", "aggregate", "result.rds"))
pvt_receipt <- readRDS(file.path(
  root,
  "deployment",
  "post-guard-receipt-v2.rds"
))
pvt_shard_path <- file.path(
  root,
  "post-guard-pvt02-c01-r50001",
  "canonical",
  "pvt02-c01-r50001.rds"
)
pvt_shard <- readRDS(pvt_shard_path)
pvt_tasks <- utils::read.delim(
  file.path(root, "deployment", "manifests", "pvt02-tasks.tsv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
interval_validate_post_guard_receipt(
  pvt_receipt,
  pvt_tasks,
  shard_path_override = pvt_shard_path
)
if (!identical(pvt$source_sha, pvt_sha)) {
  interval_stop("PVT aggregate uses the wrong frozen source")
}
pvt_env <- new.env(parent = globalenv())
sys.source(file.path(pvt_source, "dev", "pvt02", "pvt02-contract.R"), pvt_env)
interval_extract_assignment(
  file.path(pvt_source, "dev", "pvt02", "pvt02-smoke.R"),
  "cell",
  pvt_env
)
pvt_manifest <- pvt_env$pvt02_campaign_manifest(pvt_env$cell, pvt_sha)
pvt_canonical <- interval_apply_post_guard_import(
  pvt$merged$canonical,
  pvt_receipt,
  pvt_shard$attempt
)
pvt_batch <- pvt_env$pvt02_batch_receipt(pvt_manifest, pvt_canonical)
pvt_merged <- pvt_env$pvt02_merge_batch_receipts(
  pvt_manifest,
  list(pvt_batch)
)
pvt_summary <- pvt_env$pvt02_summarise_campaign(pvt_merged, pvt_manifest)
pvt_verdict <- pvt_env$pvt02_campaign_promotion_verdict(
  pvt_env$cell,
  pvt_manifest,
  pvt_merged,
  seed_disjoint = TRUE
)
if (
  nrow(pvt_canonical) != 5000L ||
    sum(pvt_canonical$rep == 50001L & pvt_canonical$seed == 800050001L) != 1L ||
    !isTRUE(all.equal(pvt$summary, pvt_summary))
) {
  interval_stop("PVT adjudication does not reproduce the frozen aggregate")
}
pvt_rows <- do.call(rbind, lapply(1:2, function(target) {
  eligible <- pvt_canonical[pvt_canonical$eligible, , drop = FALSE]
  results <- do.call(rbind, lapply(eligible$targets, function(x) {
    x[x$trait == target, , drop = FALSE]
  }))
  coverage <- mean(results$covered)
  mcse <- stats::sd(as.numeric(results$covered)) / sqrt(nrow(results))
  data.frame(
    packet = "PVT02",
    cell_id = 1L,
    target_id = paste0("V_trait_", target),
    n_outer = nrow(pvt_canonical),
    n_eligible = nrow(results),
    n_covered = sum(results$covered),
    n_ci_failed = sum(results$ci_failed),
    n_base_fit_failed = sum(!pvt_canonical$eligible),
    availability_rate = mean(pvt_canonical$eligible),
    coverage = coverage,
    mcse = mcse,
    lower_2mcse = coverage - 2 * mcse,
    target_pass = coverage >= 0.94 && coverage - 2 * mcse >= 0.94,
    stringsAsFactors = FALSE
  )
}))

ci09_sha <- "822024b1bd31a90a9dbe211ad09e1b26b2030ac8"
ci09_source <- scientific_root(ci09_sha)
ci09_env <- new.env(parent = globalenv())
sys.source(
  file.path(
    ci09_source,
    "dev",
    "interval-calibration",
    "ci09",
    "ci09-kernels.R"
  ),
  ci09_env
)
ci09 <- readRDS(file.path(root, "ci09", "aggregate", "result.rds"))
if (!identical(ci09$source_sha, ci09_sha)) {
  interval_stop("CI-09 aggregate uses the wrong frozen source")
}
ci09_recomputed <- ci09_env$ci09_summarise(ci09$merged)$targets
if (!isTRUE(all.equal(ci09$summary$targets, ci09_recomputed))) {
  interval_stop("CI-09 retained rows do not reproduce their aggregate")
}
ci09_rows <- data.frame(
  packet = "CI09",
  cell_id = ci09_recomputed$cell_id,
  target_id = ci09_recomputed$target_id,
  n_outer = ci09_recomputed$n_outer,
  n_eligible = ci09_recomputed$n_eligible,
  n_covered = ci09_recomputed$n_covered,
  n_ci_failed = ci09_recomputed$n_ci_failed +
    ci09_recomputed$n_interval_unavailable,
  n_base_fit_failed = ci09_recomputed$base_fit_failed,
  availability_rate = ci09_recomputed$availability_rate,
  coverage = ci09_recomputed$coverage,
  mcse = ci09_recomputed$mcse,
  lower_2mcse = ci09_recomputed$lower,
  target_pass = with(
    ci09_recomputed,
    coverage >= 0.94 & lower >= 0.94
  ),
  stringsAsFactors = FALSE
)

ci13_sha <- "39ab3b2983560fd3dea7bdfee124144d203cba2e"
ci13_source <- scientific_root(ci13_sha)
ci13_env <- new.env(parent = globalenv())
sys.source(
  file.path(
    ci13_source,
    "dev",
    "interval-calibration",
    "ci13",
    "ci13-kernels.R"
  ),
  ci13_env
)
ci13 <- readRDS(file.path(root, "ci13", "aggregate", "result.rds"))
if (!identical(ci13$source_sha, ci13_sha)) {
  interval_stop("CI-13 aggregate uses the wrong frozen source")
}
ci13_recomputed <- ci13_env$ci13_summarise(ci13$merged)$targets
if (!isTRUE(all.equal(ci13$summary$targets, ci13_recomputed))) {
  interval_stop("CI-13 retained rows do not reproduce their aggregate")
}
ci13_rows <- data.frame(
  packet = "CI13",
  cell_id = ci13_recomputed$cell_id,
  target_id = ci13_recomputed$target_id,
  n_outer = ci13_recomputed$n_outer,
  n_eligible = ci13_recomputed$n_eligible,
  n_covered = ci13_recomputed$n_covered,
  n_ci_failed = ci13_recomputed$n_ci_failed,
  n_base_fit_failed = ci13_recomputed$base_fit_failed,
  availability_rate = ci13_recomputed$availability_rate,
  coverage = ci13_recomputed$coverage,
  mcse = ci13_recomputed$mcse,
  lower_2mcse = ci13_recomputed$lower_2mcse,
  target_pass = with(
    ci13_recomputed,
    coverage >= 0.94 & lower_2mcse >= 0.94
  ),
  stringsAsFactors = FALSE
)

targets <- rbind(pvt_rows, ci09_rows, ci13_rows)
if (
  nrow(targets) != 18L ||
    !all(targets$target_pass[targets$packet == "PVT02"]) ||
    any(targets$target_pass[targets$packet == "CI09"]) ||
    sum(targets$target_pass[targets$packet == "CI13"]) != 8L
) {
  interval_stop("terminal target dispositions differ from retained evidence")
}

ci14_manifest <- utils::read.delim(
  file.path(root, "deployment", "manifests", "ci14-tasks.tsv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
ci14_failed_files <- list.files(
  file.path(root, "ci14", "operations"),
  pattern = "-failed[.]rds$",
  full.names = TRUE
)
ci14_failed <- lapply(ci14_failed_files, readRDS)
ci14_messages <- table(vapply(ci14_failed, `[[`, character(1), "message"))
ci14_expected_message <- paste(
  "scientific paths differ from frozen source",
  "328d8abc9125ce1e7edbcdcdcb1a41f043488431"
)
if (
  nrow(ci14_manifest) != 10000L ||
    length(ci14_failed) != 10000L ||
    length(ci14_messages) != 1L ||
    !identical(names(ci14_messages), ci14_expected_message) ||
    length(list.files(
      file.path(root, "ci14", "canonical"),
      pattern = "[.]rds$"
    )) != 0L ||
    file.exists(file.path(root, "ci14", "aggregate", "result.rds"))
) {
  interval_stop("CI-14 terminal source-guard state does not match its manifest")
}
if (dir.exists(file.path(root, "ci15"))) {
  interval_stop("CI-15 unexpectedly has a corrected campaign root")
}

payload <- list(
  schema = "INTERVAL_CALIBRATION_ADJUDICATED_EVIDENCE_V1",
  targets = targets,
  pvt = list(
    canonical = pvt_canonical,
    summary = pvt_summary,
    verdict = pvt_verdict,
    post_guard_receipt = pvt_receipt
  ),
  ci09 = ci09_recomputed,
  ci13 = ci13_recomputed,
  ci14 = list(
    n_manifest = nrow(ci14_manifest),
    n_failed = length(ci14_failed),
    messages = ci14_messages,
    n_canonical = 0L,
    aggregate_exists = FALSE
  ),
  ci15 = list(root_exists = FALSE),
  source = list(
    pvt_sha = pvt_sha,
    ci09_sha = ci09_sha,
    ci13_sha = ci13_sha,
    receipt_schema = pvt_receipt$schema,
    receipt_shard_sha256 = pvt_receipt$shard_sha256
  )
)
dir.create(dirname(output_rds), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(output_csv), recursive = TRUE, showWarnings = FALSE)
saveRDS(payload, output_rds, version = 3L)
utils::write.csv(targets, output_csv, row.names = FALSE, na = "")
cat(sprintf(
  "INTERVAL_TARGET_EVIDENCE_WROTE %s %s %d\n",
  output_rds,
  output_csv,
  nrow(targets)
))
