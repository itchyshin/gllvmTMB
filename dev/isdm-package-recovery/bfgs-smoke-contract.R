## Pure validation predicates shared by the private exact-gradient BFGS
## runners and their adversarial tests.  These functions do not fit models,
## mutate result roots, or infer missing provenance.

.bfgs_smoke_verdict <- function(valid, reason, ...) {
  c(list(valid = isTRUE(valid), reason = as.character(reason)[[1L]]), list(...))
}

.bfgs_smoke_md5 <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) &&
    grepl("^[[:xdigit:]]{32}$", x)
}

.bfgs_smoke_scalar_character <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

bfgs_smoke_gradient_order_ok <- function(gradient, parameter_vector) {
  is.numeric(gradient) && is.numeric(parameter_vector) &&
    length(gradient) == length(parameter_vector) &&
    (is.null(names(gradient)) ||
      identical(names(gradient), names(parameter_vector)))
}

.bfgs_smoke_hash_object <- function(x) {
  path <- tempfile("bfgs-contract-hash-")
  on.exit(unlink(path), add = TRUE)
  saveRDS(x, path, version = 3)
  unname(tools::md5sum(path))[[1L]]
}

bfgs_smoke_validate_receipt <- function(receipt, expected) {
  base_names <- c(
    "schema", "source_gate", "root", "commit", "seed", "dimensions", "n_rows",
    "runner_md5", "core_runner_md5", "fixture_md5", "design_md5",
    "source_md5", "dll_path", "session_info_md5", "time_estimate_md5",
    "control_md5", "paper2_terminal_status", "paper2_terminal_md5"
  )
  expected_names <- if (is.list(expected)) names(expected) else NULL
  names_ok <- is.list(receipt) && is.list(expected) &&
    identical(names(receipt), expected_names) &&
    identical(expected_names, base_names)
  if (!names_ok) {
    return(.bfgs_smoke_verdict(FALSE, "receipt_schema_names_invalid"))
  }
  character_fields <- c("schema", "source_gate", "root", "commit", "dll_path")
  typed <- all(vapply(receipt[character_fields],
    .bfgs_smoke_scalar_character, logical(1L))) &&
    is.integer(receipt$seed) && length(receipt$seed) == 1L &&
    !is.na(receipt$seed) &&
    is.integer(receipt$dimensions) && length(receipt$dimensions) == 5L &&
    identical(names(receipt$dimensions), c("S", "C", "r", "b", "d")) &&
    all(is.finite(receipt$dimensions)) && all(receipt$dimensions > 0L) &&
    is.integer(receipt$n_rows) && length(receipt$n_rows) == 1L &&
    !is.na(receipt$n_rows) && receipt$n_rows > 0L &&
    is.character(receipt$source_md5) &&
    identical(names(receipt$source_md5),
      c("fit_multi", "isdm_fit", "tmb", "bfgs_contract", "dll")) &&
    all(vapply(as.list(receipt$source_md5), .bfgs_smoke_md5, logical(1L))) &&
    all(vapply(receipt[c(
      "runner_md5", "core_runner_md5", "fixture_md5", "design_md5",
      "session_info_md5", "time_estimate_md5", "control_md5"
    )], .bfgs_smoke_md5, logical(1L)))
  paper2_absent <- is.character(receipt$paper2_terminal_status) &&
    length(receipt$paper2_terminal_status) == 1L &&
    is.na(receipt$paper2_terminal_status) &&
    is.character(receipt$paper2_terminal_md5) &&
    length(receipt$paper2_terminal_md5) == 1L &&
    is.na(receipt$paper2_terminal_md5)
  paper2_present <- .bfgs_smoke_scalar_character(
    receipt$paper2_terminal_status
  ) && .bfgs_smoke_md5(receipt$paper2_terminal_md5)
  typed <- typed && (paper2_absent || paper2_present)
  if (!typed) return(.bfgs_smoke_verdict(FALSE, "receipt_types_invalid"))
  if (!identical(receipt, expected)) {
    return(.bfgs_smoke_verdict(FALSE, "receipt_values_mismatch"))
  }
  .bfgs_smoke_verdict(TRUE, "receipt_valid")
}

bfgs_smoke_validate_manifest <- function(root, expected_paths = NULL) {
  manifest_path <- file.path(root, "file-manifest.csv")
  if (!dir.exists(root) || !file.exists(manifest_path)) {
    return(.bfgs_smoke_verdict(FALSE, "manifest_unavailable"))
  }
  manifest <- tryCatch(
    utils::read.csv(manifest_path, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (!is.data.frame(manifest) || !identical(names(manifest), c("path", "md5")) ||
      !is.character(manifest$path) || !is.character(manifest$md5) ||
      anyNA(manifest$path) || anyNA(manifest$md5) ||
      any(!nzchar(manifest$path)) || anyDuplicated(manifest$path) ||
      any(grepl("(^/|(^|/)\\.\\.(/|$))", manifest$path)) ||
      any(!vapply(as.list(manifest$md5), .bfgs_smoke_md5, logical(1L)))) {
    return(.bfgs_smoke_verdict(FALSE, "manifest_schema_invalid"))
  }
  current <- list.files(root, recursive = TRUE, all.files = TRUE,
    no.. = TRUE, include.dirs = FALSE)
  current <- sort(setdiff(current, "file-manifest.csv"))
  declared <- sort(manifest$path)
  if (!is.null(expected_paths)) {
    if (!is.character(expected_paths) || anyNA(expected_paths) ||
        any(!nzchar(expected_paths)) || anyDuplicated(expected_paths) ||
        !identical(sort(expected_paths), declared)) {
      return(.bfgs_smoke_verdict(FALSE, "manifest_expected_paths_mismatch"))
    }
  }
  if (!identical(current, declared)) {
    return(.bfgs_smoke_verdict(FALSE, "manifest_file_set_mismatch"))
  }
  observed <- unname(tools::md5sum(file.path(root, manifest$path)))
  if (anyNA(observed) || !identical(observed, manifest$md5)) {
    return(.bfgs_smoke_verdict(FALSE, "manifest_hash_mismatch"))
  }
  .bfgs_smoke_verdict(TRUE, "manifest_valid")
}

bfgs_smoke_consumed_state <- function(root) {
  terminal <- file.exists(file.path(root, "all-attempt-ledger.rds"))
  attempted <- file.exists(file.path(root, "attempt-started.rds"))
  reason <- if (terminal && attempted) {
    "attempt_marker_and_terminal_ledger_exist"
  } else if (terminal) {
    "terminal_ledger_exists"
  } else if (attempted) {
    "attempt_marker_exists"
  } else {
    "fresh_root"
  }
  list(
    consumed = terminal || attempted, reason = reason,
    terminal_ledger_exists = terminal, attempt_marker_exists = attempted
  )
}

bfgs_smoke_validate_terminal_ledger <- function(ledger, source_gate, commit) {
  allowed <- c(
    "INVALID_PROVENANCE", "BFGS_INFRASTRUCTURE_HOLD",
    "BFGS_RAW_INELIGIBLE", "BFGS_OPTIMIZER_ERROR",
    "BFGS_CURVATURE_UNAVAILABLE", "BFGS_CURVATURE_INVALID",
    "BFGS_NO_NUMERICAL_ADMISSION", "BFGS_NUMERICAL_ADMISSION"
  )
  typed <- is.list(ledger) && .bfgs_smoke_scalar_character(source_gate) &&
    .bfgs_smoke_scalar_character(commit) &&
    .bfgs_smoke_scalar_character(ledger$schema) &&
    identical(ledger$schema, paste0(source_gate, "_ALL_ATTEMPT_V1")) &&
    is.logical(ledger$terminal) && length(ledger$terminal) == 1L &&
    identical(ledger$terminal, TRUE) &&
    .bfgs_smoke_scalar_character(ledger$status) && ledger$status %in% allowed &&
    is.list(ledger$receipt) && identical(ledger$receipt$source_gate, source_gate) &&
    identical(ledger$receipt$commit, commit)
  if (!typed) {
    return(.bfgs_smoke_verdict(FALSE, "terminal_ledger_invalid"))
  }
  .bfgs_smoke_verdict(TRUE, "terminal_ledger_valid")
}

bfgs_smoke_validate_paper2_prerequisite <- function(path, commit, expected) {
  empty <- list(ledger = NULL, md5 = NA_character_)
  expected_names <- c(
    "runner_md5", "core_runner_md5", "fixture_md5", "design_md5",
    "source_md5", "dll_path", "control_md5"
  )
  if (!.bfgs_smoke_scalar_character(path) || !file.exists(path) ||
      !is.list(expected) || !identical(names(expected), expected_names)) {
    return(c(.bfgs_smoke_verdict(FALSE, "paper2_ledger_unavailable"), empty))
  }
  root <- tryCatch(normalizePath(dirname(path), mustWork = TRUE),
    error = function(e) NA_character_)
  exact_path <- is.character(root) && length(root) == 1L && !is.na(root) &&
    identical(
      normalizePath(path, mustWork = TRUE),
      file.path(root, "all-attempt-ledger.rds")
    )
  if (!exact_path) {
    return(c(.bfgs_smoke_verdict(FALSE, "paper2_ledger_path_invalid"), empty))
  }
  consumed <- bfgs_smoke_consumed_state(root)
  if (!identical(consumed$terminal_ledger_exists, TRUE) ||
      !identical(consumed$attempt_marker_exists, TRUE)) {
    return(c(.bfgs_smoke_verdict(
      FALSE, "paper2_terminal_or_attempt_marker_missing"
    ), empty))
  }
  manifest_verdict <- bfgs_smoke_validate_manifest(root)
  if (!identical(manifest_verdict$valid, TRUE)) {
    return(c(.bfgs_smoke_verdict(
      FALSE, paste0("paper2_", manifest_verdict$reason)
    ), empty))
  }
  ledger <- tryCatch(readRDS(path), error = function(e) NULL)
  md5 <- unname(tools::md5sum(path))[[1L]]
  verdict <- bfgs_smoke_validate_terminal_ledger(
    ledger, "BFGS_P2_S6_C360_R3_V3", commit
  )
  if (!verdict$valid) {
    return(list(
      valid = FALSE, reason = "paper2_terminal_ledger_invalid",
      ledger = ledger, md5 = md5
    ))
  }
  receipt_path <- file.path(root, "root-receipt.rds")
  receipt <- tryCatch(readRDS(receipt_path), error = function(e) NULL)
  receipt_verdict <- bfgs_smoke_validate_receipt(receipt, receipt)
  receipt_constants <- is.list(receipt) &&
    identical(receipt$schema, "BFGS_P2_S6_C360_R3_V3_PREFLIGHT_V1") &&
    identical(receipt$source_gate, "BFGS_P2_S6_C360_R3_V3") &&
    identical(receipt$root, root) &&
    identical(receipt$commit, commit) && identical(receipt$seed, 86302L) &&
    identical(receipt$dimensions, c(S = 6L, C = 360L, r = 3L, b = 1L, d = 1L)) &&
    identical(receipt$n_rows, 8640L) &&
    is.character(receipt$paper2_terminal_status) &&
    length(receipt$paper2_terminal_status) == 1L &&
    is.na(receipt$paper2_terminal_status) &&
    is.character(receipt$paper2_terminal_md5) &&
    length(receipt$paper2_terminal_md5) == 1L &&
    is.na(receipt$paper2_terminal_md5)
  receipt_expected <- receipt_constants &&
    identical(receipt$runner_md5, expected$runner_md5) &&
    identical(receipt$core_runner_md5, expected$core_runner_md5) &&
    identical(receipt$fixture_md5, expected$fixture_md5) &&
    identical(receipt$design_md5, expected$design_md5) &&
    identical(receipt$source_md5, expected$source_md5) &&
    identical(receipt$dll_path, expected$dll_path) &&
    identical(receipt$control_md5, expected$control_md5) &&
    identical(receipt$session_info_md5,
      unname(tools::md5sum(file.path(root, "session-info.rds")))[[1L]]) &&
    identical(receipt$time_estimate_md5,
      unname(tools::md5sum(file.path(root, "time-estimate.md")))[[1L]]) &&
    file.exists(receipt$dll_path) &&
    identical(receipt$source_md5[["dll"]],
      unname(tools::md5sum(receipt$dll_path))[[1L]]) &&
    identical(ledger$receipt, receipt)
  if (!identical(receipt_verdict$valid, TRUE) || !receipt_expected) {
    return(list(
      valid = FALSE, reason = "paper2_receipt_or_source_evidence_invalid",
      ledger = ledger, md5 = md5
    ))
  }
  marker <- tryCatch(
    readRDS(file.path(root, "attempt-started.rds")), error = function(e) NULL
  )
  marker_ok <- is.list(marker) &&
    identical(marker, list(status = "OPTIMIZER_ENTERED"))
  continuation <- ledger$continuation_source
  provenance_hashes <- if (is.list(continuation)) {
    continuation$provenance_hashes
  } else NULL
  provenance_ok <- is.list(provenance_hashes) &&
    identical(provenance_hashes$warm_restart_provenance,
      .bfgs_smoke_hash_object(continuation$warm_restart_provenance)) &&
    identical(provenance_hashes$isdm_polish_provenance,
      .bfgs_smoke_hash_object(continuation$isdm_polish_provenance)) &&
    identical(provenance_hashes$restart_history,
      .bfgs_smoke_hash_object(continuation$restart_history)) &&
    identical(provenance_hashes$start_provenance,
      .bfgs_smoke_hash_object(continuation$start_provenance)) &&
    identical(provenance_hashes$selection_source,
      .bfgs_smoke_hash_object(continuation$selection_source))
  parameter_vector <- if (is.list(ledger$raw)) {
    ledger$raw$parameter_vector
  } else NULL
  labels <- names(parameter_vector)
  ids <- if (is.numeric(parameter_vector) && length(parameter_vector)) {
    paste0(labels, "[", seq_along(parameter_vector), "]")
  } else character()
  expected_order_hash <- if (length(ids)) {
    .bfgs_smoke_hash_object(list(labels = labels, ids = ids))
  } else NA_character_
  covariance <- if (is.list(ledger$bfgs) && is.list(ledger$bfgs$curvature)) {
    ledger$bfgs$curvature$covariance
  } else NULL
  expected_covariance_hash <- if (is.null(covariance)) {
    NA_character_
  } else {
    .bfgs_smoke_hash_object(covariance)
  }
  algorithm_statuses <- c(
    "BFGS_RAW_INELIGIBLE", "BFGS_OPTIMIZER_ERROR",
    "BFGS_CURVATURE_UNAVAILABLE", "BFGS_CURVATURE_INVALID",
    "BFGS_NO_NUMERICAL_ADMISSION", "BFGS_NUMERICAL_ADMISSION"
  )
  result_ok <- marker_ok && provenance_ok && is.list(ledger$bfgs) &&
    ledger$status %in% algorithm_statuses &&
    identical(ledger$bfgs$estimator, "BFGS_EXACT_GRADIENT_CONTINUATION_V1") &&
    identical(ledger$bfgs$status, ledger$status) &&
    identical(ledger$bfgs$signature, ledger$signature) &&
    identical(ledger$order_hash, expected_order_hash) &&
    identical(ledger$covariance_hash, expected_covariance_hash) &&
    is.list(ledger$fit_control) &&
    identical(ledger$control_md5, .bfgs_smoke_hash_object(ledger$fit_control)) &&
    identical(ledger$control_md5, receipt$control_md5)
  if (!result_ok) {
    return(list(
      valid = FALSE, reason = "paper2_bfgs_or_hash_evidence_invalid",
      ledger = ledger, md5 = md5
    ))
  }
  list(valid = TRUE, reason = "paper2_terminal_ledger_valid", ledger = ledger,
       md5 = md5)
}
