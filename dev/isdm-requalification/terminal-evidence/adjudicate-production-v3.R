args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop(paste(
    "usage: adjudicate-production-v3.R OUTPUT_DIR SOURCE_CONTRACT_RDS",
    "RECEIPT_RDS V1_RECEIPT_RDS V2_RECEIPT_RDS"
  ))
}
output_dir <- normalizePath(args[[1L]], mustWork = TRUE)
source_contract <- readRDS(args[[2L]])
source("dev/isdm-requalification/campaign.R", local = TRUE)
source("dev/isdm-requalification/summarise.R", local = TRUE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]),
                             mustWork = TRUE)
helper_path <- file.path(dirname(script_path), "adjudication-v3-functions.R")
source(helper_path, local = TRUE)

raw_manifest_path <- file.path(output_dir, "raw-manifest-sha256.txt")
manifest_check <- system2(
  "sha256sum", c("-c", shQuote(raw_manifest_path)),
  stdout = TRUE, stderr = TRUE
)
if (!identical(as.integer(attr(manifest_check, "status") %||% 0L), 0L)) {
  stop("frozen raw production manifest verification failed")
}
v1 <- readRDS(args[[4L]])
v2 <- readRDS(args[[5L]])
if (!identical(v1$schema, "isdm-point-production-adjudication-v1") ||
    !identical(v2$schema, "isdm-point-production-adjudication-v2") ||
    !identical(v1$source_sha, source_contract$source_sha) ||
    !identical(v2$source_sha, source_contract$source_sha) ||
    !identical(v1$source_tree, source_contract$source_tree) ||
    !identical(v2$source_tree, source_contract$source_tree) ||
    !identical(v2$superseded_receipt_sha256,
               unname(isdm_sha256(args[[4L]]))) ||
    !identical(v2$raw_manifest_sha256,
               unname(isdm_sha256(raw_manifest_path)))) {
  stop("v1/v2 adjudication chain does not match this frozen campaign")
}

ordinary_native <- isdm_point_plan("ordinary")
attack_native <- isdm_point_plan("attack")
common_fields <- intersect(names(ordinary_native), names(attack_native))
ordinary_plan <- rbind(
  ordinary_native[common_fields],
  attack_native[common_fields]
)
spatial_plan <- isdm_point_plan("spatial")
ordinary_ledger <- isdm_attempt_ledger(
  output_dir, ordinary_plan, source_contract = source_contract
)
spatial_ledger <- isdm_attempt_ledger(
  output_dir, spatial_plan, source_contract = source_contract
)
ordinary_denominators <- isdm_denominators(ordinary_ledger)
spatial_denominators <- isdm_denominators(spatial_ledger)

read_records <- function(plan) {
  lapply(plan$task_id, function(task_id) {
    path <- file.path(output_dir, "attempts", sprintf("task-%06d.rds", task_id))
    if (!file.exists(path)) return(NULL)
    tryCatch(readRDS(path), error = function(e) NULL)
  })
}
ordinary_records_raw <- read_records(ordinary_plan)
spatial_records <- read_records(spatial_plan)
ordinary_complete <- all(ordinary_ledger$terminal %in% TRUE) &&
  all(vapply(ordinary_records_raw, is.list, logical(1L)))
spatial_complete <- all(spatial_ledger$terminal %in% TRUE) &&
  all(vapply(spatial_records, is.list, logical(1L)))

ordinary_records <- lapply(ordinary_records_raw, isdm_v3_normalize_psi)
ordinary_verdict <- if (ordinary_complete) {
  isdm_adjudicate_ordinary(
    ordinary_records, plan = ordinary_plan, source_contract = source_contract
  )
} else list(verdict = "FAIL", complete = FALSE)
attack_records <- ordinary_records_raw[vapply(
  ordinary_records_raw,
  function(record) is.list(record) && identical(record$programme, "attack"),
  logical(1L)
)]
attack_verdict <- isdm_v3_attack_verdict(attack_records, ordinary_complete)
spatial_verdict <- if (spatial_complete) {
  isdm_adjudicate_spatial(
    spatial_records, plan = spatial_plan, source_contract = source_contract
  )
} else list(verdict = "FAIL", complete = FALSE)

receipt <- list(
  schema = "isdm-point-production-adjudication-v3",
  adjudicated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  corrections = c(
    "bind unnamed finite Psi estimates only through exact truth/Sigma trait order",
    "exclude unrelated lifecycle warnings from attack diagnostic qualification"
  ),
  v1_receipt_sha256 = unname(isdm_sha256(args[[4L]])),
  v2_receipt_sha256 = unname(isdm_sha256(args[[5L]])),
  raw_manifest_sha256 = unname(isdm_sha256(raw_manifest_path)),
  raw_manifest_verified_n = length(manifest_check),
  adjudicator_sha256 = unname(isdm_sha256(script_path)),
  helper_sha256 = unname(isdm_sha256(helper_path)),
  source_sha = source_contract$source_sha,
  source_tree = source_contract$source_tree,
  ordinary_denominators = ordinary_denominators,
  spatial_denominators = spatial_denominators,
  ordinary = ordinary_verdict,
  attack = attack_verdict,
  spatial = spatial_verdict
)
isdm_atomic_save(receipt, args[[3L]])
print(receipt)
if (!identical(ordinary_verdict$verdict, "PASS") ||
    !identical(attack_verdict$verdict, "PASS") ||
    !identical(spatial_verdict$verdict, "PASS")) quit(status = 2L)
