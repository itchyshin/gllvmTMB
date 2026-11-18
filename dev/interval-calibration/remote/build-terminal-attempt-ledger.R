#!/usr/bin/env Rscript
## Build the compact all-attempt ledger from immutable retained campaign roots.
## This script performs no fit, simulation, interval calculation, or promotion.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop(
    paste(
      "usage: build-terminal-attempt-ledger.R",
      "ORIGINAL_ROOT CORRECTED_ROOT FIR_ROOT ADJUDICATED_RDS OUTPUT_CSV"
    ),
    call. = FALSE
  )
}
original_root <- normalizePath(args[[1L]], mustWork = TRUE)
corrected_root <- normalizePath(args[[2L]], mustWork = TRUE)
fir_root <- normalizePath(args[[3L]], mustWork = TRUE)
adjudicated <- readRDS(args[[4L]])
output_csv <- args[[5L]]

scalar_outcome <- function(attempt) {
  if (is.data.frame(attempt) && "endpoint_reason" %in% names(attempt)) {
    return(as.character(attempt$endpoint_reason[[1L]]))
  }
  if (is.list(attempt) && "outcome" %in% names(attempt)) {
    return(as.character(attempt$outcome[[1L]]))
  }
  NA_character_
}

ledger_row <- function(
  packet,
  cell_id,
  rep,
  seed,
  source_sha,
  attempt_version,
  execution_root,
  environment_valid,
  recorded_outcome,
  adjudicated_outcome,
  disposition,
  canonical,
  artifact_path
) {
  data.frame(
    packet = as.character(packet),
    cell_id = as.integer(cell_id),
    rep = as.integer(rep),
    seed = as.integer(seed),
    scientific_source_sha = as.character(source_sha),
    attempt_version = as.integer(attempt_version),
    execution_root = as.character(execution_root),
    environment_valid = as.logical(environment_valid),
    recorded_outcome = as.character(recorded_outcome),
    adjudicated_outcome = as.character(adjudicated_outcome),
    disposition = as.character(disposition),
    canonical = as.logical(canonical),
    artifact_path = as.character(artifact_path),
    stringsAsFactors = FALSE
  )
}

original_files <- unlist(lapply(
  c("pvt02", "ci09", "ci13", "ci14", "ci15"),
  function(packet) {
    list.files(
      file.path(original_root, packet, "canonical"),
      pattern = "[.]rds$",
      full.names = TRUE
    )
  }
), use.names = FALSE)
if (length(original_files) != 85000L) {
  stop("original Totoro root does not retain exactly 85,000 shards", call. = FALSE)
}
original <- lapply(original_files, function(path) {
  shard <- readRDS(path)
  ledger_row(
    shard$packet,
    shard$cell_id,
    shard$rep,
    shard$seed,
    shard$scientific_provenance$scientific_source_sha,
    shard$attempt_version,
    "totoro-original-invalid",
    FALSE,
    scalar_outcome(shard$attempt),
    "infrastructure_failure_missing_assertthat",
    "infrastructure_excluded",
    FALSE,
    file.path(
      tolower(shard$packet),
      "canonical",
      basename(path)
    )
  )
})

pvt <- adjudicated$pvt$canonical
pvt_rows <- lapply(seq_len(nrow(pvt)), function(i) {
  post_guard <- identical(as.integer(pvt$rep[[i]]), 50001L)
  ledger_row(
    "PVT02",
    1L,
    pvt$rep[[i]],
    pvt$seed[[i]],
    pvt$source_sha[[i]],
    pvt$attempt[[i]],
    if (post_guard) "totoro-r2-post-guard" else "totoro-r2-campaign",
    TRUE,
    pvt$endpoint_reason[[i]],
    pvt$endpoint_reason[[i]],
    "canonical",
    TRUE,
    if (post_guard) {
      file.path(
        "post-guard-pvt02-c01-r50001", "canonical",
        "pvt02-c01-r50001.rds"
      )
    } else {
      file.path("pvt02", "canonical", sprintf(
        "pvt02-c01-r%05d.rds", pvt$rep[[i]]
      ))
    }
  )
})

pvt_duplicate <- readRDS(
  file.path(corrected_root, "pvt02", "aggregate", "result.rds")
)$merged$canonical
pvt_duplicate <- pvt_duplicate[pvt_duplicate$rep == 50001L, , drop = FALSE]
pvt_duplicate_row <- ledger_row(
  "PVT02",
  1L,
  pvt_duplicate$rep,
  pvt_duplicate$seed,
  pvt_duplicate$source_sha,
  pvt_duplicate$attempt,
  "totoro-r2-campaign",
  TRUE,
  pvt_duplicate$endpoint_reason,
  pvt_duplicate$endpoint_reason,
  "duplicate_excluded",
  FALSE,
  file.path("pvt02", "canonical", "pvt02-c01-r50001.rds")
)

ci09 <- readRDS(
  file.path(corrected_root, "ci09", "aggregate", "result.rds")
)$merged$canonical
ci09_rows <- lapply(seq_len(nrow(ci09)), function(i) {
  ledger_row(
    "CI09",
    ci09$cell_id[[i]],
    ci09$rep[[i]],
    ci09$seed[[i]],
    ci09$source_sha[[i]],
    ci09$attempt_version[[i]],
    "totoro-r2-campaign",
    TRUE,
    ci09$outcome[[i]],
    ci09$outcome[[i]],
    "canonical",
    TRUE,
    file.path("ci09", "canonical", sprintf(
      "ci09-c%02d-r%05d.rds", ci09$cell_id[[i]], ci09$rep[[i]]
    ))
  )
})

ci13 <- readRDS(
  file.path(corrected_root, "ci13", "aggregate", "result.rds")
)$merged$canonical
ci13_rows <- lapply(seq_len(nrow(ci13)), function(i) {
  ledger_row(
    "CI13",
    ci13$cell_id[[i]],
    ci13$rep[[i]],
    ci13$seed[[i]],
    ci13$source_sha[[i]],
    ci13$attempt_version[[i]],
    "totoro-r2-campaign",
    TRUE,
    ci13$outcome[[i]],
    ci13$outcome[[i]],
    "canonical",
    TRUE,
    file.path("ci13", "canonical", sprintf(
      "ci13-c%02d-r%05d.rds", ci13$cell_id[[i]], ci13$rep[[i]]
    ))
  )
})

ci14_manifest <- utils::read.delim(
  file.path(corrected_root, "deployment", "manifests", "ci14-tasks.tsv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
ci14_failure_files <- list.files(
  file.path(corrected_root, "ci14", "operations"),
  pattern = "-failed[.]rds$",
  full.names = TRUE
)
if (length(ci14_failure_files) != 10000L) {
  stop("corrected CI-14 root lacks 10,000 failure receipts", call. = FALSE)
}
ci14_rows <- lapply(ci14_failure_files, function(path) {
  failure <- readRDS(path)
  hit <- ci14_manifest$cell_id == failure$cell_id &
    ci14_manifest$rep == failure$rep
  if (sum(hit) != 1L) stop("CI-14 failure identity is not unique", call. = FALSE)
  ledger_row(
    failure$packet,
    failure$cell_id,
    failure$rep,
    ci14_manifest$seed[hit],
    failure$scientific_source_sha,
    failure$attempt_version,
    "totoro-r2-campaign",
    TRUE,
    failure$message,
    "provenance_gate_failure_no_scientific_attempt",
    "blocked_provenance",
    FALSE,
    file.path("ci14", "operations", basename(path))
  )
})

fir_files <- list.files(
  file.path(fir_root, "canonical"),
  pattern = "[.]rds$",
  full.names = TRUE
)
if (length(fir_files) != 18L) {
  stop("Fir CI-10 root does not retain exactly 18 shards", call. = FALSE)
}
fir_rows <- lapply(fir_files, function(path) {
  shard <- readRDS(path)
  ledger_row(
    shard$packet,
    shard$cell_id,
    shard$rep,
    shard$seed,
    shard$scientific_provenance$scientific_source_sha,
    shard$attempt_version,
    "fir-ci10-cost",
    TRUE,
    scalar_outcome(shard$attempt),
    scalar_outcome(shard$attempt),
    "canonical_cost_preflight",
    TRUE,
    file.path("ci10-cost-array", "canonical", basename(path))
  )
})

ledger <- do.call(rbind, c(
  original,
  pvt_rows,
  list(pvt_duplicate_row),
  ci09_rows,
  ci13_rows,
  ci14_rows,
  fir_rows
))
ledger <- ledger[order(
  ledger$packet,
  ledger$cell_id,
  ledger$rep,
  ledger$execution_root,
  ledger$canonical
), , drop = FALSE]
rownames(ledger) <- NULL
if (nrow(ledger) != 150019L) {
  stop("all-attempt ledger does not retain exactly 150,019 rows", call. = FALSE)
}
utils::write.csv(ledger, output_csv, row.names = FALSE, na = "")
cat(sprintf("INTERVAL_ALL_ATTEMPT_LEDGER_WROTE %s %d\n", output_csv, nrow(ledger)))
