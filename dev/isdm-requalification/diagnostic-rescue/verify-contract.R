## Independent verifier for a frozen diagnostic seed manifest and task plan.

.ISDM_DIAG_VERIFY_FILE <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(current) || !nzchar(current)) {
    script <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
    candidates <- c(
      if (length(script) == 1L) sub("^--file=", "", script) else character(),
      file.path("dev", "isdm-requalification", "diagnostic-rescue",
                "verify-contract.R"),
      file.path("..", "..", "dev", "isdm-requalification",
                "diagnostic-rescue", "verify-contract.R"),
      "verify-contract.R"
    )
    existing <- candidates[file.exists(candidates)]
    current <- if (length(existing)) existing[[1L]] else "verify-contract.R"
  }
  normalizePath(current, mustWork = TRUE)
})
.ISDM_DIAG_VERIFY_DIR <- dirname(.ISDM_DIAG_VERIFY_FILE)
source(file.path(.ISDM_DIAG_VERIFY_DIR, "select-seeds.R"), local = TRUE)

.isdm_diag_static_index <- function() {
  ordinary <- isdm_point_plan("ordinary")
  ordinary$status <- "fit_returned"
  ordinary$convergence <- 0L
  ordinary$pd_hessian <- TRUE
  ordinary$source_sha <- ISDM_DIAG_PRODUCTION_SOURCE_SHA
  ordinary$source_tree <- ISDM_DIAG_PRODUCTION_SOURCE_TREE
  ordinary$record_sha256 <- strrep("0", 64L)
  nonspatial <- isdm_diag_select_nonspatial(ordinary)

  spatial_native <- isdm_point_plan("spatial")
  spatial_rows <- do.call(rbind, lapply(c(2L, 3L), function(n_sources) {
    do.call(rbind, lapply(c("full", "weak"), function(overlap) {
      cell <- spatial_native[
        spatial_native$n_sources == n_sources &
          spatial_native$overlap == overlap, , drop = FALSE
      ]
      cell[seq_len(3L), , drop = FALSE]
    }))
  }))
  spatial_rows$pair_id <- NA_integer_
  spatial_rows$structure_seed <- NA_integer_
  spatial_rows$status <- "fit_returned"
  spatial_rows$convergence <- rep(c(0L, 0L, 1L), times = 4L)
  spatial_rows$pd_hessian <- rep(c(TRUE, FALSE, FALSE), times = 4L)
  spatial_rows$source_sha <- ISDM_DIAG_PRODUCTION_SOURCE_SHA
  spatial_rows$source_tree <- ISDM_DIAG_PRODUCTION_SOURCE_TREE
  spatial_rows$record_sha256 <- strrep("1", 64L)
  list(nonspatial = nonspatial,
       spatial = isdm_diag_select_spatial(spatial_rows))
}

isdm_diag_verify_static_contract <- function() {
  contract <- isdm_diag_contract()
  if (!identical(contract$schema, ISDM_DIAG_CONTRACT_SCHEMA) ||
      !identical(contract$production_source_sha,
                 ISDM_DIAG_PRODUCTION_SOURCE_SHA) ||
      !identical(contract$production_source_tree,
                 ISDM_DIAG_PRODUCTION_SOURCE_TREE) ||
      !identical(contract$planned_tasks, 52L) ||
      !identical(contract$smoke_tasks, 4L)) {
    .isdm_diag_abort("frozen diagnostic contract constants changed",
                     "isdm_diag_static_contract_invalid")
  }
  selected <- .isdm_diag_static_index()
  manifest <- list(
    schema = ISDM_DIAG_SEED_MANIFEST_SCHEMA,
    nonspatial = selected$nonspatial,
    spatial = selected$spatial
  )
  plan <- diagnostic_plan(manifest)
  smoke <- diagnostic_smoke_plan(manifest)
  list(
    schema = "isdm-identifiability-static-verification-v1",
    planned_n = as.integer(nrow(plan)),
    smoke_n = as.integer(nrow(smoke)),
    nonspatial_n = as.integer(sum(plan$slice == "nonspatial")),
    spatial_n = as.integer(sum(plan$slice == "spatial"))
  )
}

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
  if (length(args) == 0L) {
    result <- isdm_diag_verify_static_contract()
    print(result)
    cat("DIAGNOSTIC_CONTRACT_VERIFIED\n")
    return(invisible(result))
  }
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
