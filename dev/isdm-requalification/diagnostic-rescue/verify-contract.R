## Independent verifier for a frozen diagnostic seed manifest and task plan.

.ISDM_DIAG_VERIFY_FILE <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(current) || !nzchar(current)) {
    script <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
    current <- if (length(script) == 1L)
      sub("^--file=", "", script) else "verify-contract.R"
  }
  normalizePath(current, mustWork = TRUE)
})
.ISDM_DIAG_VERIFY_DIR <- dirname(.ISDM_DIAG_VERIFY_FILE)
source(file.path(.ISDM_DIAG_VERIFY_DIR, "select-seeds.R"), local = TRUE)

isdm_diag_verify_seed_manifest <- function(path, production_dir = NULL) {
  path <- normalizePath(path, mustWork = TRUE)
  sidecar <- paste0(path, ".sha256")
  if (!file.exists(sidecar)) {
    .isdm_diag_abort("seed manifest checksum sidecar is missing",
                     "isdm_diag_seed_manifest_sidecar_missing")
  }
  line <- readLines(sidecar, warn = FALSE)
  if (length(line) != 1L ||
      !grepl("^[[:xdigit:]]{64}[[:space:]]+[^/]+$", line)) {
    .isdm_diag_abort("seed manifest checksum sidecar is malformed",
                     "isdm_diag_seed_manifest_sidecar_invalid")
  }
  expected <- tolower(sub("[[:space:]].*$", "", line))
  if (!identical(sub("^[[:xdigit:]]{64}[[:space:]]+", "", line),
                 basename(path))) {
    .isdm_diag_abort("seed manifest checksum sidecar names another file",
                     "isdm_diag_seed_manifest_sidecar_invalid")
  }
  .isdm_diag_verify_hash(
    path, expected, "isdm_diag_seed_manifest_hash_mismatch"
  )
  manifest <- readRDS(path)
  plan <- diagnostic_plan(manifest)
  smoke <- diagnostic_smoke_plan(manifest)
  binding <- manifest$production_binding
  expected_binding <- list(
    source_sha = ISDM_DIAG_PRODUCTION_SOURCE_SHA,
    source_tree = ISDM_DIAG_PRODUCTION_SOURCE_TREE,
    raw_manifest_sha256 = ISDM_DIAG_RAW_MANIFEST_SHA256,
    chain_manifest_sha256 = ISDM_DIAG_CHAIN_MANIFEST_SHA256,
    adjudication_v3_sha256 = ISDM_DIAG_ADJUDICATION_V3_SHA256
  )
  if (!is.list(binding) || !all(vapply(names(expected_binding), function(key) {
    identical(binding[[key]], expected_binding[[key]])
  }, logical(1L)))) {
    .isdm_diag_abort("seed manifest production binding is invalid",
                     "isdm_diag_seed_manifest_binding_invalid")
  }
  if (!is.null(production_dir)) {
    live <- isdm_diag_verify_production(production_dir)
    for (selected in list(manifest$nonspatial, manifest$spatial)) {
      for (i in seq_len(nrow(selected))) {
        record_path <- .isdm_diag_record_path(
          live$production_dir, selected$task_id[[i]]
        )
        observed <- .isdm_diag_record_hash(record_path, live)
        if (!identical(observed, selected$record_sha256[[i]])) {
          .isdm_diag_abort("selected terminal record changed after selection",
                           "isdm_diag_selected_record_changed")
        }
      }
    }
  }
  list(
    schema = "isdm-identifiability-contract-verification-v1",
    seed_manifest_sha256 = expected,
    planned_n = nrow(plan), smoke_n = nrow(smoke),
    selected_nonspatial_n = nrow(manifest$nonspatial),
    selected_spatial_n = nrow(manifest$spatial),
    plan = plan, smoke = smoke
  )
}

isdm_diag_verify_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (!length(args) %in% c(1L, 2L)) {
    stop("usage: verify-contract.R SEED_MANIFEST_RDS [PRODUCTION_DIR]")
  }
  result <- isdm_diag_verify_seed_manifest(
    args[[1L]], if (length(args) == 2L) args[[2L]] else NULL
  )
  print(result[setdiff(names(result), c("plan", "smoke"))])
  invisible(result)
}

.isdm_diag_running_verify_file <- function() {
  script <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  length(script) == 1L && identical(
    normalizePath(sub("^--file=", "", script), mustWork = TRUE),
    normalizePath(.ISDM_DIAG_VERIFY_FILE, mustWork = TRUE)
  )
}

if (.isdm_diag_running_verify_file()) isdm_diag_verify_cli()
