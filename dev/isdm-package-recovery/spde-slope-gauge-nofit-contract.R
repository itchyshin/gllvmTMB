## Byte and state binding for the non-scientific SPDE-slope gauge no-fit gate.
##
## This file deliberately does not construct TMB objects, load a DLL, execute
## callbacks, create an optimiser, or write a root.  The runner must combine
## this byte-level predecessor proof with the historical MSPDE V3 live terminal
## validator before it enters the one-object callback gate.

.spde_slope_gauge_nofit_verdict <- function(valid, reason, ...) {
  c(list(valid = isTRUE(valid), reason = as.character(reason)[[1L]]), list(...))
}

.spde_slope_gauge_nofit_md5 <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) &&
    grepl("^[[:xdigit:]]{32}$", x)
}

.spde_slope_gauge_nofit_regular_file <- function(path) {
  info <- suppressWarnings(file.info(path))
  is.character(path) && length(path) == 1L && !is.na(path) &&
    file.exists(path) && !isTRUE(info$isdir[[1L]]) &&
    identical(Sys.readlink(path), "")
}

spde_slope_gauge_nofit_locked_predecessor <- function() {
  list(
    root = paste0(
      "/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/",
      "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3"
    ),
    commit = "a6255290810269510bba87951ea2dee365861e21",
    files = c(
      "all-attempt-ledger.rds" = "a9f19416c126a9f2054092835cdb8aaa",
      "attempt-started.rds" = "8b5421d35a4b50d46b690eee0c2b3cb2",
      "file-manifest.csv" = "32f93c4de1988dad08ac01f12e30a674",
      "root-receipt.rds" = "1940354271459b695e3ed2af70f1ca9c",
      "session-info.rds" = "817aea4f16c4ddc7d844bb7af342024e",
      "time-estimate.md" = "e0a79bbfdb48668328d5f0224e6bd40f",
      "v2-materialized-state.rds" = "e3b17636c9f5fa0e9e555a307c923724"
    ),
    directories = ".attempt-started.claim",
    receipt_schema = "MSPDE_P1_S3_C360_R3_V3_CLOSEOUT_PREFLIGHT_V1",
    state_schema = "MSPDE_P1_S3_C360_R3_V3_MATERIALIZED_V2_STATE_V1"
  )
}

.spde_slope_gauge_nofit_state_ok <- function(state, schema) {
  fields <- c("schema", "objective", "theta", "gradient", "convergence",
    "covariance", "start_provenance", "restart_history",
    "warm_restart_provenance", "isdm_polish_provenance", "parameters", "map",
    "data", "random", "block_labels", "parameter_order")
  raw_order <- spde_slope_gauge_raw_order()
  is.list(state) && identical(names(state), fields) && identical(state$schema, schema) &&
    is.double(state$objective) && length(state$objective) == 1L && is.finite(state$objective) &&
    is.double(state$theta) && identical(names(state$theta), raw_order) &&
    length(state$theta) == length(raw_order) && all(is.finite(state$theta)) &&
    is.double(state$gradient) && identical(names(state$gradient), raw_order) &&
    length(state$gradient) == length(raw_order) && all(is.finite(state$gradient)) &&
    is.integer(state$convergence) && length(state$convergence) == 1L &&
    is.list(state$covariance) && is.list(state$start_provenance) &&
    is.data.frame(state$restart_history) && is.list(state$warm_restart_provenance) &&
    is.list(state$isdm_polish_provenance) && is.list(state$parameters) &&
    is.list(state$map) && is.list(state$data) && is.character(state$random) &&
    is.character(state$block_labels) && length(state$block_labels) == length(raw_order) &&
    identical(state$parameter_order, raw_order)
}

.spde_slope_gauge_nofit_manifest_ok <- function(root, locked) {
  manifest_path <- file.path(root, "file-manifest.csv")
  manifest <- if (.spde_slope_gauge_nofit_regular_file(manifest_path)) {
    tryCatch(utils::read.csv(manifest_path, stringsAsFactors = FALSE), error = function(e) NULL)
  } else NULL
  declared_files <- setdiff(names(locked$files), "file-manifest.csv")
  is.data.frame(manifest) && identical(names(manifest), c("path", "md5")) &&
    identical(as.character(manifest$path), declared_files) &&
    identical(as.character(manifest$md5), unname(locked$files[declared_files]))
}

spde_slope_gauge_nofit_validate_predecessor_bytes <- function(
    root = spde_slope_gauge_nofit_locked_predecessor()$root,
    locked = spde_slope_gauge_nofit_locked_predecessor()) {
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  expected_root <- tryCatch(normalizePath(locked$root, mustWork = TRUE), error = function(e) NA_character_)
  if (!is.character(normal_root) || length(normal_root) != 1L || is.na(normal_root) ||
      is.na(expected_root) || !identical(normal_root, expected_root)) {
    return(.spde_slope_gauge_nofit_verdict(FALSE, "predecessor_root_invalid"))
  }
  inventory <- list.files(normal_root, all.files = TRUE, no.. = TRUE, recursive = FALSE)
  expected_files <- names(locked$files)
  expected_dirs <- locked$directories
  paths <- file.path(normal_root, expected_files)
  directory_paths <- file.path(normal_root, expected_dirs)
  bytes_ok <- identical(sort(inventory), sort(c(expected_files, expected_dirs))) &&
    all(vapply(paths, .spde_slope_gauge_nofit_regular_file, logical(1L))) &&
    all(vapply(directory_paths, function(path) {
      isTRUE(file.info(path)$isdir[[1L]]) && identical(Sys.readlink(path), "") &&
        identical(list.files(path, all.files = TRUE, no.. = TRUE), character())
    }, logical(1L))) &&
    identical(unname(tools::md5sum(paths)), unname(locked$files)) &&
    .spde_slope_gauge_nofit_manifest_ok(normal_root, locked)
  if (!bytes_ok) return(.spde_slope_gauge_nofit_verdict(FALSE, "predecessor_packet_bytes_invalid"))
  receipt <- tryCatch(readRDS(file.path(normal_root, "root-receipt.rds")), error = function(e) NULL)
  state <- tryCatch(readRDS(file.path(normal_root, "v2-materialized-state.rds")), error = function(e) NULL)
  receipt_ok <- is.list(receipt) && identical(names(receipt), c(
    "schema", "source_gate", "root", "commit", "consumed_v2", "runner_md5",
    "contract_md5", "design_md5"
  )) && identical(receipt$schema, locked$receipt_schema) &&
    identical(receipt$root, normal_root) && identical(receipt$commit, locked$commit) &&
    all(vapply(receipt[c("runner_md5", "contract_md5", "design_md5")],
      .spde_slope_gauge_nofit_md5, logical(1L)))
  state_ok <- .spde_slope_gauge_nofit_state_ok(state, locked$state_schema)
  .spde_slope_gauge_nofit_verdict(
    receipt_ok && state_ok,
    if (receipt_ok && state_ok) "predecessor_bytes_valid" else "predecessor_receipt_or_state_invalid",
    receipt = receipt, state = state, state_md5 = unname(locked$files[["v2-materialized-state.rds"]])
  )
}
