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

.bfgs_smoke_exact_names <- function(x, expected) {
  is.list(x) && identical(names(x), expected)
}

.bfgs_smoke_regular_file <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !file.exists(path) || nzchar(Sys.readlink(path))) return(FALSE)
  info <- file.info(path)
  nrow(info) == 1L && !is.na(info$isdir) && !info$isdir &&
    !is.na(info$mode)
}

.bfgs_smoke_empty_directory <- function(path) {
  dir.exists(path) && !nzchar(Sys.readlink(path)) &&
    !length(list.files(path, all.files = TRUE, no.. = TRUE))
}

.bfgs_smoke_materialized_md5 <- function(path) {
  if (!.bfgs_smoke_regular_file(path)) return(NA_character_)
  unname(tools::md5sum(path))[[1L]]
}

.bfgs_smoke_live_receipt_ok <- function(receipt, root) {
  root <- tryCatch(normalizePath(root, mustWork = TRUE),
    error = function(e) NA_character_)
  if (!.bfgs_smoke_scalar_character(root) ||
      !identical(receipt$root, root) ||
      !identical(basename(dirname(root)), "results") ||
      !identical(basename(dirname(dirname(root))), "isdm-package-recovery") ||
      !identical(basename(dirname(dirname(dirname(root)))), "dev")) return(FALSE)
  pkg <- dirname(dirname(dirname(dirname(root))))
  source_gate <- receipt$source_gate
  fixture <- if (identical(source_gate, "BFGS_P1_S3_C360_R3_V4")) {
    "spatial-isdm-gate-b-smoke-fixture.R"
  } else if (identical(source_gate, "BFGS_P2_S6_C360_R3_V4")) {
    "g2h-360cell-fixture.R"
  } else {
    return(FALSE)
  }
  runner <- if (identical(source_gate, "BFGS_P1_S3_C360_R3_V4")) {
    "run-bfgs-paper1-smoke.R"
  } else {
    "run-bfgs-paper2-smoke.R"
  }
  paths <- c(
    runner = file.path(pkg, "dev", "isdm-package-recovery", runner),
    core_runner = file.path(pkg, "dev", "isdm-package-recovery",
      "run-bfgs-paper2-smoke.R"),
    fixture = file.path(pkg, "dev", "isdm-package-recovery", fixture),
    design = file.path(pkg, "dev", "isdm-package-recovery",
      "2026-08-14-bfgs-exact-gradient-continuation-design.md"),
    fit_multi = file.path(pkg, "R", "fit-multi.R"),
    isdm_fit = file.path(pkg, "R", "isdm-developer-fit.R"),
    tmb = file.path(pkg, "src", "gllvmTMB.cpp"),
    bfgs_contract = file.path(pkg, "dev", "isdm-package-recovery",
      "bfgs-smoke-contract.R"),
    dll = file.path(pkg, "src", "gllvmTMB.so")
  )
  if (!all(vapply(paths, .bfgs_smoke_regular_file, logical(1L)))) return(FALSE)
  md5 <- stats::setNames(
    unname(tools::md5sum(unname(paths))), names(paths)
  )
  control_constructor <- get0("gllvmTMBcontrol", mode = "function",
    inherits = TRUE)
  live_control <- if (is.null(control_constructor)) NULL else tryCatch({
    out <- control_constructor(n_init = 1L, init_jitter = 0, se = TRUE,
      aghq = FALSE, warn_runaway = TRUE)
    out$.internal_continuation <- FALSE
    out
  }, error = function(e) NULL)
  is.list(live_control) &&
    identical(receipt$runner_md5, md5[["runner"]]) &&
    identical(receipt$core_runner_md5, md5[["core_runner"]]) &&
    identical(receipt$fixture_md5, md5[["fixture"]]) &&
    identical(receipt$design_md5, md5[["design"]]) &&
    identical(receipt$source_md5, c(
      fit_multi = md5[["fit_multi"]], isdm_fit = md5[["isdm_fit"]],
      tmb = md5[["tmb"]], bfgs_contract = md5[["bfgs_contract"]],
      dll = md5[["dll"]]
    )) &&
    identical(receipt$dll_path, normalizePath(paths[["dll"]], mustWork = TRUE)) &&
    identical(receipt$session_info_md5,
      unname(tools::md5sum(file.path(root, "session-info.rds")))[[1L]]) &&
    identical(receipt$time_estimate_md5,
      unname(tools::md5sum(file.path(root, "time-estimate.md")))[[1L]]) &&
    identical(receipt$control_md5, .bfgs_smoke_hash_object(live_control))
}

.bfgs_smoke_attempt_marker_names <- c(
  "schema", "source_gate", "root", "commit", "receipt_md5",
  "claim", "claimed_at", "started_at", "parent_pid"
)
.bfgs_smoke_entry_names <- c(
  "schema", "source_gate", "root", "commit", "attempt_marker_md5",
  "entered_at", "parent_pid", "parameter_order_hash"
)
.bfgs_smoke_ledger_names <- c(
  "schema", "status", "reason", "terminal", "receipt", "attempt_marker",
  "bfgs_entry", "signature", "raw", "continuation_source", "bfgs",
  "fit_control", "control_md5", "covariance_hash", "order_hash", "checks",
  "warnings", "error", "timing", "peak_rss_kb"
)
.bfgs_smoke_check_names <- c(
  "provenance", "preflight", "attempt_claimed", "fit_available",
  "bfgs_entered", "terminal_evidence"
)

bfgs_smoke_validate_attempt_marker <- function(marker, receipt, receipt_md5) {
  ok <- .bfgs_smoke_exact_names(marker, .bfgs_smoke_attempt_marker_names) &&
    is.list(receipt) && identical(marker$schema,
      paste0(receipt$source_gate, "_ATTEMPT_STARTED_V1")) &&
    identical(marker$source_gate, receipt$source_gate) &&
    identical(marker$root, receipt$root) && identical(marker$commit, receipt$commit) &&
    .bfgs_smoke_md5(receipt_md5) && identical(marker$receipt_md5, receipt_md5) &&
    identical(marker$claim,
      ".attempt-started.claim") && .bfgs_smoke_scalar_character(marker$claimed_at) &&
    .bfgs_smoke_scalar_character(marker$started_at) &&
    is.integer(marker$parent_pid) && length(marker$parent_pid) == 1L &&
    !is.na(marker$parent_pid) && marker$parent_pid > 0L
  .bfgs_smoke_verdict(ok, if (ok) "attempt_marker_valid" else
    "attempt_marker_invalid")
}

bfgs_smoke_validate_bfgs_entry <- function(entry, marker, order_hash,
                                            attempt_marker_md5) {
  ok <- .bfgs_smoke_exact_names(entry, .bfgs_smoke_entry_names) &&
    is.list(marker) && identical(entry$schema,
      paste0(marker$source_gate, "_BFGS_ENTERED_V1")) &&
    identical(entry$source_gate, marker$source_gate) &&
    identical(entry$root, marker$root) && identical(entry$commit, marker$commit) &&
    .bfgs_smoke_md5(attempt_marker_md5) &&
    identical(entry$attempt_marker_md5, attempt_marker_md5) &&
    .bfgs_smoke_scalar_character(entry$entered_at) &&
    identical(entry$parent_pid, marker$parent_pid) &&
    .bfgs_smoke_md5(entry$parameter_order_hash) &&
    identical(entry$parameter_order_hash, order_hash)
  .bfgs_smoke_verdict(ok, if (ok) "bfgs_entry_valid" else "bfgs_entry_invalid")
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

bfgs_smoke_validate_manifest <- function(root, expected_paths = NULL,
                                         expected_dirs = character()) {
  manifest_path <- file.path(root, "file-manifest.csv")
  if (!dir.exists(root) || !.bfgs_smoke_regular_file(manifest_path)) {
    return(.bfgs_smoke_verdict(FALSE, "manifest_unavailable"))
  }
  top <- list.files(root, all.files = TRUE, no.. = TRUE, recursive = FALSE)
  info <- file.info(file.path(root, top))
  if (any(is.na(info$isdir)) || any(nzchar(Sys.readlink(file.path(root, top))))) {
    return(.bfgs_smoke_verdict(FALSE, "manifest_file_type_invalid"))
  }
  directories <- sort(top[info$isdir %in% TRUE], method = "radix")
  if (!is.character(expected_dirs) || anyNA(expected_dirs) ||
      anyDuplicated(expected_dirs) ||
      !identical(directories, sort(expected_dirs, method = "radix")) ||
      (length(expected_dirs) && !all(vapply(file.path(root, expected_dirs),
        .bfgs_smoke_empty_directory, logical(1L))))) {
    return(.bfgs_smoke_verdict(FALSE, "manifest_directory_set_mismatch"))
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
  current <- sort(setdiff(top[info$isdir %in% FALSE], "file-manifest.csv"),
    method = "radix")
  declared <- sort(manifest$path, method = "radix")
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
  if (!all(vapply(file.path(root, manifest$path),
      .bfgs_smoke_regular_file, logical(1L)))) {
    return(.bfgs_smoke_verdict(FALSE, "manifest_file_type_invalid"))
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
  claimed <- dir.exists(file.path(root, ".attempt-started.claim"))
  reason <- if (terminal && attempted && claimed) {
    "attempt_marker_and_terminal_ledger_exist"
  } else if (terminal) {
    "terminal_ledger_exists"
  } else if (attempted || claimed) {
    "attempt_marker_exists"
  } else {
    "fresh_root"
  }
  list(
    consumed = terminal || attempted || claimed, reason = reason,
    terminal_ledger_exists = terminal, attempt_marker_exists = attempted,
    attempt_claim_exists = claimed
  )
}

.bfgs_smoke_curvature_callback_ok <- function(x, ids) {
  .bfgs_smoke_exact_names(x, c(
    "available", "reason", "par.fixed", "cov.fixed", "pdHess",
    "positional_ids", "error"
  )) && is.logical(x$available) && length(x$available) == 1L &&
    !is.na(x$available) && .bfgs_smoke_scalar_character(x$reason) &&
    identical(x$positional_ids, ids) && is.character(x$error) &&
    length(x$error) == 1L
}

.bfgs_smoke_signature_names <- c(
  "objective", "gradient", "parameter_order", "map", "data", "random",
  "bounds", "scale", "controls", "starts", "selection", "source_gate"
)

.bfgs_smoke_callback_payload_ok <- function(x, ids) {
  .bfgs_smoke_curvature_callback_ok(x, ids) &&
    is.logical(x$pdHess) && length(x$pdHess) == 1L &&
    (is.null(x$par.fixed) || is.numeric(x$par.fixed)) &&
    (is.null(x$cov.fixed) || is.matrix(x$cov.fixed))
}

.bfgs_smoke_callback_failure_ok <- function(x, ids) {
  if (!.bfgs_smoke_callback_payload_ok(x, ids) ||
      !identical(x$available, FALSE)) return(FALSE)
  if (x$reason %in% c("curvature_callback_error", "sdreport_unavailable")) {
    return(is.null(x$par.fixed) && is.null(x$cov.fixed) && is.na(x$pdHess) &&
      .bfgs_smoke_scalar_character(x$error))
  }
  identical(x$reason, "sdreport_positional_identity_failure") &&
    is.na(x$error)
}

.bfgs_smoke_callback_success_ok <- function(x, ids) {
  .bfgs_smoke_callback_payload_ok(x, ids) &&
    identical(x$available, TRUE) && is.na(x$error)
}

.bfgs_smoke_prefix_names <- c(
  "selection_source", "parameter_vector", "objective", "gradient",
  "convergence", "pd_hessian", "boundary_flags", "objective_replay_error",
  "gradient_replay_relative_error", "gradient_replay_relative_tolerance",
  "internal_continuation_disabled", "warm_restart_provenance",
  "isdm_polish_provenance", "restart_history", "start_provenance",
  "provenance_hashes"
)

.bfgs_smoke_validate_prefix <- function(ledger) {
  invalid <- function(reason) .bfgs_smoke_verdict(FALSE, reason,
    order_hash = NA_character_)
  x <- ledger$continuation_source
  hash_names <- c("warm_restart_provenance", "isdm_polish_provenance",
    "restart_history", "start_provenance", "selection_source")
  if (!.bfgs_smoke_exact_names(x, .bfgs_smoke_prefix_names) ||
      !identical(x$selection_source, "fit$isdm_polish_provenance$raw") ||
      !is.double(x$parameter_vector) || !length(x$parameter_vector) ||
      any(!is.finite(x$parameter_vector)) || is.null(names(x$parameter_vector)) ||
      anyNA(names(x$parameter_vector)) || any(!nzchar(names(x$parameter_vector))) ||
      !is.double(x$objective) || length(x$objective) != 1L ||
      !is.finite(x$objective) || !is.double(x$gradient) ||
      length(x$gradient) != length(x$parameter_vector) ||
      any(!is.finite(x$gradient)) ||
      !identical(names(x$gradient), names(x$parameter_vector)) ||
      !identical(x$convergence, 0L) || !is.logical(x$pd_hessian) ||
      length(x$pd_hessian) != 1L || is.na(x$pd_hessian) ||
      !is.character(x$boundary_flags) || length(x$boundary_flags) ||
      !is.double(x$objective_replay_error) ||
      length(x$objective_replay_error) != 1L ||
      !is.finite(x$objective_replay_error) || x$objective_replay_error < 0 ||
      !is.double(x$gradient_replay_relative_error) ||
      length(x$gradient_replay_relative_error) != 1L ||
      !is.finite(x$gradient_replay_relative_error) ||
      x$gradient_replay_relative_error < 0 ||
      !identical(x$gradient_replay_relative_tolerance, 1e-8) ||
      x$gradient_replay_relative_error > x$gradient_replay_relative_tolerance ||
      !identical(x$internal_continuation_disabled, TRUE) ||
      !is.list(x$warm_restart_provenance) ||
      !is.list(x$isdm_polish_provenance) || !is.data.frame(x$restart_history) ||
      !is.list(x$start_provenance) ||
      !.bfgs_smoke_exact_names(x$provenance_hashes, hash_names)) {
    return(invalid("continuation_prefix_schema_invalid"))
  }
  expected_hashes <- list(
    warm_restart_provenance = .bfgs_smoke_hash_object(x$warm_restart_provenance),
    isdm_polish_provenance = .bfgs_smoke_hash_object(x$isdm_polish_provenance),
    restart_history = .bfgs_smoke_hash_object(x$restart_history),
    start_provenance = .bfgs_smoke_hash_object(x$start_provenance),
    selection_source = .bfgs_smoke_hash_object(x$selection_source)
  )
  polish_raw <- x$isdm_polish_provenance$raw
  if (!identical(x$provenance_hashes, expected_hashes) ||
      !is.list(polish_raw) ||
      !identical(unname(x$parameter_vector),
        unname(polish_raw$parameter_vector)) ||
      !is.numeric(polish_raw$objective) || length(polish_raw$objective) != 1L ||
      !is.finite(polish_raw$objective) ||
      !identical(x$objective_replay_error,
        abs(x$objective - as.numeric(polish_raw$objective))) ||
      !is.numeric(polish_raw$gradient) ||
      length(polish_raw$gradient) != length(x$gradient) ||
      any(!is.finite(polish_raw$gradient))) {
    return(invalid("continuation_prefix_provenance_invalid"))
  }
  difference_norm <- sqrt(sum(
    (as.numeric(x$gradient) - as.numeric(polish_raw$gradient))^2
  ))
  relative_error <- difference_norm / max(
    sqrt(sum(as.numeric(x$gradient)^2)),
    sqrt(sum(as.numeric(polish_raw$gradient)^2)),
    sqrt(.Machine$double.eps)
  )
  if (!identical(x$gradient_replay_relative_error, relative_error))
    return(invalid("continuation_gradient_replay_invalid"))
  labels <- names(x$parameter_vector)
  ids <- paste0(labels, "[", seq_along(labels), "]")
  order_hash <- .bfgs_smoke_hash_object(list(labels = labels, ids = ids))
  raw_state <- list(
    optimizer = "nlminb", convergence = x$convergence,
    pd_hessian = x$pd_hessian, boundary_flags = x$boundary_flags,
    is_isdm = TRUE, aghq = FALSE, ridge = FALSE,
    retry_enabled = !isTRUE(x$internal_continuation_disabled),
    profile_enabled = FALSE, source_gate = ledger$receipt$source_gate
  )
  prefix_raw <- list(
    parameter_vector = x$parameter_vector, gradient = x$gradient,
    objective = x$objective, raw_state = raw_state,
    selection_source = x$selection_source
  )
  expected_signature <- list(
    objective = .bfgs_smoke_hash_object(list(fn = "tmb_obj$fn",
      value = x$objective, dll = ledger$receipt$source_md5[["dll"]])),
    gradient = .bfgs_smoke_hash_object(list(gr = "tmb_obj$gr", exact = TRUE,
      value = x$gradient)), parameter_order = order_hash,
    map = ledger$signature$map, data = ledger$signature$data,
    random = ledger$signature$random, bounds = "unconstrained_transformed_scale",
    scale = "package_internal_unconstrained", controls = .bfgs_smoke_hash_object(list(
      starting_fit = list(full_control = ledger$fit_control), method = "BFGS",
      control = list(maxit = 500L, reltol = 1e-12, trace = 0L, REPORT = 1L))),
    starts = .bfgs_smoke_hash_object(list(parameter_vector = x$parameter_vector,
      selection_source = x$selection_source,
      provenance_hashes = x$provenance_hashes)),
    selection = "isdm_polish_provenance_raw_initial_nlminb",
    source_gate = ledger$receipt$source_gate
  )
  if (!identical(ledger$signature, expected_signature))
    return(invalid("continuation_signature_invalid"))
  .bfgs_smoke_verdict(TRUE, "continuation_prefix_valid",
    order_hash = order_hash, prefix_raw = prefix_raw)
}

bfgs_smoke_recompute_result <- function(result) {
  invalid <- function(reason) .bfgs_smoke_verdict(FALSE, reason,
    status = NA_character_, result_reason = NA_character_,
    order_hash = NA_character_, covariance_hash = NA_character_)
  finish <- function(status, reason, order_hash = NA_character_,
                     covariance_hash = NA_character_) {
    ok <- identical(result$status, status) && identical(result$reason, reason)
    .bfgs_smoke_verdict(ok, if (ok) "bfgs_result_recomputed" else
      "bfgs_result_projection_mismatch", status = status,
      result_reason = reason, order_hash = order_hash,
      covariance_hash = covariance_hash)
  }
  top <- c("estimator", "status", "reason", "optimizer_entered", "method",
    "control", "signature", "raw_state", "raw", "optimizer", "candidate",
    "curvature")
  frozen_control <- list(maxit = 500L, reltol = 1e-12, trace = 0L, REPORT = 1L)
  raw_state_names <- c("optimizer", "convergence", "pd_hessian", "boundary_flags",
    "is_isdm", "aghq", "ridge", "retry_enabled", "profile_enabled", "source_gate")
  if (!.bfgs_smoke_exact_names(result, top) ||
      !identical(result$estimator, "BFGS_EXACT_GRADIENT_CONTINUATION_V1") ||
      !.bfgs_smoke_scalar_character(result$status) ||
      !.bfgs_smoke_scalar_character(result$reason) ||
      !is.logical(result$optimizer_entered) ||
      length(result$optimizer_entered) != 1L || is.na(result$optimizer_entered) ||
      !identical(result$method, "BFGS") || !identical(result$control, frozen_control) ||
      !.bfgs_smoke_exact_names(result$signature,
        .bfgs_smoke_signature_names) ||
      !all(vapply(result$signature, .bfgs_smoke_scalar_character, logical(1L))) ||
      !.bfgs_smoke_exact_names(result$raw_state, raw_state_names) ||
      !identical(result$raw_state$optimizer, "nlminb") ||
      !identical(result$raw_state$convergence, 0L) ||
      !is.logical(result$raw_state$pd_hessian) ||
      length(result$raw_state$pd_hessian) != 1L ||
      is.na(result$raw_state$pd_hessian) ||
      !is.character(result$raw_state$boundary_flags) ||
      !identical(result$raw_state$is_isdm, TRUE) ||
      !identical(result$raw_state$aghq, FALSE) ||
      !identical(result$raw_state$ridge, FALSE) ||
      !identical(result$raw_state$retry_enabled, FALSE) ||
      !identical(result$raw_state$profile_enabled, FALSE) ||
      !identical(result$raw_state$source_gate, result$signature$source_gate)) {
    return(invalid("bfgs_result_outer_schema_invalid"))
  }
  if (is.null(result$raw)) {
    if (!is.null(result$optimizer) || !is.null(result$candidate) ||
        !is.null(result$curvature)) return(invalid("bfgs_null_raw_tail_invalid"))
    if (identical(result$status, "BFGS_INFRASTRUCTURE_HOLD") &&
        identical(result$reason, "objective_or_curvature_interface_unavailable")) {
      if (isTRUE(result$optimizer_entered))
        return(invalid("bfgs_pre_optimizer_entry_invalid"))
      return(finish(result$status, result$reason))
    }
    if (identical(result$status, "BFGS_RAW_INELIGIBLE") &&
        identical(result$reason, "invalid_or_unlocked_raw_inputs")) {
      if (isTRUE(result$optimizer_entered))
        return(invalid("bfgs_pre_optimizer_entry_invalid"))
      return(finish(result$status, result$reason))
    }
    return(invalid("bfgs_null_raw_status_invalid"))
  }
  partial_raw_names <- c("parameter_vector", "block_labels", "positional_ids",
    "objective", "expected_objective", "gradient")
  full_raw_names <- c(partial_raw_names, "max_gradient", "objective_replay_error")
  raw <- result$raw
  if (!is.list(raw) || !identical(names(raw), partial_raw_names) &&
      !identical(names(raw), full_raw_names) ||
      !is.double(raw$parameter_vector) || !length(raw$parameter_vector) ||
      any(!is.finite(raw$parameter_vector)) ||
      !is.character(raw$block_labels) ||
      length(raw$block_labels) != length(raw$parameter_vector) ||
      anyNA(raw$block_labels) || any(!nzchar(raw$block_labels)) ||
      !identical(raw$positional_ids,
        paste0(raw$block_labels, "[", seq_along(raw$block_labels), "]")) ||
      anyDuplicated(raw$positional_ids) ||
      !identical(names(raw$parameter_vector), raw$positional_ids) ||
      !is.double(raw$objective) || length(raw$objective) != 1L ||
      !is.double(raw$expected_objective) || length(raw$expected_objective) != 1L ||
      !is.double(raw$gradient) || length(raw$gradient) != length(raw$parameter_vector) ||
      !identical(names(raw$gradient), raw$positional_ids)) {
    return(invalid("bfgs_raw_schema_invalid"))
  }
  order_hash <- .bfgs_smoke_hash_object(list(
    labels = raw$block_labels, ids = raw$positional_ids
  ))
  if (identical(names(raw), partial_raw_names)) {
    ok <- identical(result$status, "BFGS_INFRASTRUCTURE_HOLD") &&
      identical(result$reason, "raw_objective_or_gradient_unavailable") &&
      identical(result$optimizer_entered, FALSE) &&
      is.null(result$optimizer) && is.null(result$candidate) &&
      is.null(result$curvature)
    if (!ok) return(invalid("bfgs_partial_raw_projection_invalid"))
    return(finish(result$status, result$reason, order_hash))
  }
  derived_max <- max(abs(raw$gradient))
  derived_replay <- abs(raw$objective - raw$expected_objective)
  if (any(!is.finite(c(raw$objective, raw$expected_objective, raw$gradient,
      raw$max_gradient, raw$objective_replay_error))) ||
      !identical(raw$max_gradient, derived_max) ||
      !identical(raw$objective_replay_error, derived_replay)) {
    return(invalid("bfgs_raw_derived_evidence_invalid"))
  }
  raw_tolerance <- 64 * .Machine$double.eps * max(1, abs(raw$expected_objective))
  if (derived_replay > raw_tolerance) {
    if (isTRUE(result$optimizer_entered))
      return(invalid("bfgs_pre_optimizer_entry_invalid"))
    return(finish("BFGS_RAW_INELIGIBLE", "raw_objective_replay_mismatch", order_hash))
  }
  if (!(derived_max > 1e-3 && derived_max < 1e-2)) {
    if (isTRUE(result$optimizer_entered))
      return(invalid("bfgs_pre_optimizer_entry_invalid"))
    return(finish("BFGS_RAW_INELIGIBLE", "raw_gradient_gate", order_hash))
  }
  if (.bfgs_smoke_exact_names(result$optimizer, c("error", "elapsed_s"))) {
    optimizer <- result$optimizer
    if (!identical(result$optimizer_entered, TRUE) ||
        !.bfgs_smoke_scalar_character(optimizer$error) ||
        !is.double(optimizer$elapsed_s) || length(optimizer$elapsed_s) != 1L ||
        !is.finite(optimizer$elapsed_s) || optimizer$elapsed_s < 0 ||
        !is.null(result$candidate) || !is.null(result$curvature)) {
      return(invalid("bfgs_optimizer_error_schema_invalid"))
    }
    expected_reason <- if (identical(optimizer$error, "malformed_optimizer_result"))
      "malformed_optimizer_result" else optimizer$error
    return(finish("BFGS_OPTIMIZER_ERROR", expected_reason, order_hash))
  }
  optimizer_names <- c("par", "value", "counts", "convergence", "message", "elapsed_s")
  optimizer <- result$optimizer
  if (!identical(result$optimizer_entered, TRUE) ||
      !.bfgs_smoke_exact_names(optimizer, optimizer_names) ||
      !is.double(optimizer$par) || length(optimizer$par) != length(raw$parameter_vector) ||
      any(!is.finite(optimizer$par)) ||
      !(is.null(names(optimizer$par)) || identical(names(optimizer$par), raw$positional_ids)) ||
      !is.double(optimizer$value) || length(optimizer$value) != 1L ||
      !is.finite(optimizer$value) || !is.numeric(optimizer$counts) ||
      length(optimizer$counts) != 2L || any(!is.finite(optimizer$counts)) ||
      !is.integer(optimizer$convergence) || length(optimizer$convergence) != 1L ||
      is.na(optimizer$convergence) || !is.character(optimizer$message) ||
      length(optimizer$message) != 1L || !is.double(optimizer$elapsed_s) ||
      length(optimizer$elapsed_s) != 1L || !is.finite(optimizer$elapsed_s) ||
      optimizer$elapsed_s < 0) return(invalid("bfgs_optimizer_schema_invalid"))
  if (is.null(result$candidate)) {
    if (!is.null(result$curvature)) return(invalid("bfgs_null_candidate_tail_invalid"))
    return(finish("BFGS_INFRASTRUCTURE_HOLD",
      "candidate_exact_replay_unavailable", order_hash))
  }
  candidate_base_names <- c("parameter_vector", "objective", "optimizer_objective",
    "gradient", "convergence", "counts", "message", "max_gradient",
    "objective_replay_error")
  candidate_names <- c(candidate_base_names, "gates")
  candidate <- result$candidate
  if (!(.bfgs_smoke_exact_names(candidate, candidate_base_names) ||
      .bfgs_smoke_exact_names(candidate, candidate_names)) ||
      !is.double(candidate$parameter_vector) ||
      length(candidate$parameter_vector) != length(raw$parameter_vector) ||
      any(!is.finite(candidate$parameter_vector)) ||
      !identical(names(candidate$parameter_vector), raw$positional_ids) ||
      !is.double(candidate$objective) || length(candidate$objective) != 1L ||
      !is.finite(candidate$objective) ||
      !identical(candidate$optimizer_objective, optimizer$value) ||
      !is.double(candidate$gradient) ||
      length(candidate$gradient) != length(raw$parameter_vector) ||
      any(!is.finite(candidate$gradient)) ||
      !identical(names(candidate$gradient), raw$positional_ids) ||
      !identical(candidate$convergence, optimizer$convergence) ||
      !identical(candidate$counts, optimizer$counts) ||
      !identical(candidate$message, optimizer$message) ||
      !is.double(candidate$max_gradient) || length(candidate$max_gradient) != 1L ||
      !is.double(candidate$objective_replay_error) ||
      length(candidate$objective_replay_error) != 1L) {
    return(invalid("bfgs_candidate_schema_invalid"))
  }
  replay_error <- abs(candidate$objective - optimizer$value)
  max_gradient <- max(abs(candidate$gradient))
  objective_tolerance <- 64 * .Machine$double.eps * max(1, abs(optimizer$value))
  if (!identical(candidate$objective_replay_error, replay_error) ||
      !identical(candidate$max_gradient, max_gradient)) {
    return(invalid("bfgs_candidate_derived_evidence_invalid"))
  }
  if (identical(names(candidate), candidate_base_names)) {
    if (!(replay_error > objective_tolerance) || !is.null(result$curvature))
      return(invalid("bfgs_candidate_pre_gate_projection_invalid"))
    return(finish("BFGS_INFRASTRUCTURE_HOLD",
      "candidate_objective_replay_mismatch", order_hash))
  }
  if (!.bfgs_smoke_exact_names(candidate$gates,
      c("convergence", "objective", "gradient", "curvature"))) {
    return(invalid("bfgs_candidate_gate_schema_invalid"))
  }
  if (replay_error > objective_tolerance) {
    return(invalid("bfgs_candidate_late_replay_mismatch"))
  }
  gates <- list(
    convergence = identical(optimizer$convergence, 0L),
    objective = candidate$objective <= raw$objective +
      64 * .Machine$double.eps * max(1, abs(raw$objective)),
    gradient = max_gradient <= 1e-3, curvature = NA
  )
  if (!identical(candidate$gates[1:3], gates[1:3])) {
    return(invalid("bfgs_candidate_gate_evidence_invalid"))
  }
  if (!all(unlist(gates[1:3], use.names = FALSE))) {
    if (!identical(candidate$gates$curvature, NA) || !is.null(result$curvature))
      return(invalid("bfgs_nonadmission_tail_invalid"))
    return(finish("BFGS_NO_NUMERICAL_ADMISSION",
      "optimizer_convergence_objective_or_gradient_gate_failed", order_hash))
  }
  curvature <- result$curvature
  if (.bfgs_smoke_callback_failure_ok(curvature, raw$positional_ids)) {
    if (!identical(candidate$gates$curvature, NA))
      return(invalid("bfgs_unavailable_curvature_gate_invalid"))
    return(finish("BFGS_CURVATURE_UNAVAILABLE", curvature$reason, order_hash))
  }
  if (.bfgs_smoke_callback_success_ok(curvature, raw$positional_ids)) {
    callback_par_ok <- is.double(curvature$par.fixed) &&
      length(curvature$par.fixed) == length(candidate$parameter_vector) &&
      all(is.finite(curvature$par.fixed)) &&
      identical(names(curvature$par.fixed), raw$positional_ids) &&
      max(abs(curvature$par.fixed - candidate$parameter_vector)) <=
        64 * .Machine$double.eps *
          max(1, max(abs(candidate$parameter_vector)))
    callback_cov_ok <- is.matrix(curvature$cov.fixed) &&
      identical(dim(curvature$cov.fixed),
        c(length(raw$parameter_vector), length(raw$parameter_vector))) &&
      identical(rownames(curvature$cov.fixed), raw$positional_ids) &&
      identical(colnames(curvature$cov.fixed), raw$positional_ids)
    if (callback_par_ok && callback_cov_ok)
      return(invalid("bfgs_unwrapped_curvature_success_invalid"))
    if (!identical(candidate$gates$curvature, NA))
      return(invalid("bfgs_positional_curvature_gate_invalid"))
    return(finish("BFGS_CURVATURE_UNAVAILABLE",
      "curvature_positional_identity_failure", order_hash))
  }
  curvature_names <- c("callback", "covariance", "eigenvalues", "condition",
    "finite", "symmetric", "positive_definite", "pdHess", "metric_source")
  if (!.bfgs_smoke_exact_names(curvature, curvature_names) ||
      !.bfgs_smoke_callback_success_ok(curvature$callback,
        raw$positional_ids) ||
      !is.double(curvature$callback$par.fixed) ||
      length(curvature$callback$par.fixed) != length(candidate$parameter_vector) ||
      any(!is.finite(curvature$callback$par.fixed)) ||
      !identical(names(curvature$callback$par.fixed), raw$positional_ids) ||
      max(abs(curvature$callback$par.fixed - candidate$parameter_vector)) >
        64 * .Machine$double.eps *
          max(1, max(abs(candidate$parameter_vector))) ||
      !is.matrix(curvature$covariance) ||
      !identical(dim(curvature$covariance),
        c(length(raw$parameter_vector), length(raw$parameter_vector))) ||
      !identical(rownames(curvature$covariance), raw$positional_ids) ||
      !identical(colnames(curvature$covariance), raw$positional_ids) ||
      !identical(curvature$callback$cov.fixed, curvature$covariance) ||
      !identical(curvature$pdHess, curvature$callback$pdHess) ||
      !identical(curvature$metric_source, "sdreport_cov_fixed")) {
    return(invalid("bfgs_curvature_schema_invalid"))
  }
  covariance <- curvature$covariance
  finite <- all(is.finite(covariance))
  symmetric <- finite && max(abs(covariance - t(covariance))) <= 1e-10
  chol_covariance <- if (symmetric) tryCatch(chol(covariance),
    error = function(e) NULL) else NULL
  eigenvalues <- if (symmetric) tryCatch(eigen(covariance, symmetric = TRUE,
    only.values = TRUE)$values, error = function(e) rep(NA_real_, nrow(covariance))) else
      rep(NA_real_, nrow(covariance))
  condition <- if (!is.null(chol_covariance)) tryCatch(kappa(covariance,
    exact = TRUE), error = function(e) Inf) else Inf
  derived <- list(finite = finite, symmetric = symmetric,
    positive_definite = !is.null(chol_covariance))
  if (!identical(curvature$eigenvalues, eigenvalues) ||
      !identical(curvature$condition, condition) ||
      !identical(curvature$finite, derived$finite) ||
      !identical(curvature$symmetric, derived$symmetric) ||
      !identical(curvature$positive_definite, derived$positive_definite)) {
    return(invalid("bfgs_curvature_derived_evidence_invalid"))
  }
  covariance_hash <- .bfgs_smoke_hash_object(covariance)
  curvature_valid <- identical(curvature$pdHess, TRUE) && finite && symmetric &&
    !is.null(chol_covariance) && all(is.finite(eigenvalues)) &&
    is.finite(condition) && condition <= 1e8
  if (!curvature_valid) {
    if (!identical(candidate$gates$curvature, NA))
      return(invalid("bfgs_invalid_curvature_gate_invalid"))
    return(finish("BFGS_CURVATURE_INVALID", "candidate_curvature_invalid",
      order_hash, covariance_hash))
  }
  if (!identical(candidate$gates$curvature, TRUE))
    return(invalid("bfgs_admission_curvature_gate_invalid"))
  finish("BFGS_NUMERICAL_ADMISSION", "all_admission_gates_passed",
    order_hash, covariance_hash)
}

bfgs_smoke_validate_terminal_ledger <- function(ledger, source_gate, commit,
                                                root = NULL) {
  allowed <- c(
    "INVALID_PROVENANCE", "BFGS_INFRASTRUCTURE_HOLD",
    "BFGS_RAW_INELIGIBLE", "BFGS_OPTIMIZER_ERROR",
    "BFGS_CURVATURE_UNAVAILABLE", "BFGS_CURVATURE_INVALID",
    "BFGS_NO_NUMERICAL_ADMISSION", "BFGS_NUMERICAL_ADMISSION"
  )
  receipt_path <- if (is.list(ledger) && is.list(ledger$receipt) &&
      .bfgs_smoke_scalar_character(ledger$receipt$root)) {
    file.path(ledger$receipt$root, "root-receipt.rds")
  } else {
    NA_character_
  }
  marker_path <- if (is.list(ledger) && is.list(ledger$receipt) &&
      .bfgs_smoke_scalar_character(ledger$receipt$root)) {
    file.path(ledger$receipt$root, "attempt-started.rds")
  } else {
    NA_character_
  }
  receipt_md5 <- .bfgs_smoke_materialized_md5(receipt_path)
  attempt_marker_md5 <- .bfgs_smoke_materialized_md5(marker_path)
  typed <- .bfgs_smoke_exact_names(ledger, .bfgs_smoke_ledger_names) &&
    .bfgs_smoke_scalar_character(source_gate) &&
    .bfgs_smoke_scalar_character(commit) && grepl("^[[:xdigit:]]{40}$", commit) &&
    identical(ledger$schema, paste0(source_gate, "_ALL_ATTEMPT_V2")) &&
    identical(ledger$terminal, TRUE) && .bfgs_smoke_scalar_character(ledger$status) &&
    ledger$status %in% allowed && .bfgs_smoke_scalar_character(ledger$reason) &&
    is.list(ledger$receipt) && identical(ledger$receipt$source_gate, source_gate) &&
    identical(ledger$receipt$commit, commit) &&
    bfgs_smoke_validate_receipt(ledger$receipt, ledger$receipt)$valid &&
    bfgs_smoke_validate_attempt_marker(ledger$attempt_marker, ledger$receipt,
      receipt_md5)$valid &&
    is.list(ledger$fit_control) && .bfgs_smoke_md5(ledger$control_md5) &&
    identical(ledger$control_md5, .bfgs_smoke_hash_object(ledger$fit_control)) &&
    identical(ledger$control_md5, ledger$receipt$control_md5) &&
    .bfgs_smoke_exact_names(ledger$checks, .bfgs_smoke_check_names) &&
    all(vapply(ledger$checks, function(x) is.logical(x) && length(x) == 1L &&
      !is.na(x), logical(1L))) && is.character(ledger$warnings) &&
    is.character(ledger$error) && length(ledger$error) == 1L &&
    .bfgs_smoke_exact_names(ledger$timing, c("fit_elapsed_s")) &&
    is.double(ledger$timing$fit_elapsed_s) &&
    length(ledger$timing$fit_elapsed_s) == 1L &&
    (is.na(ledger$timing$fit_elapsed_s) ||
      is.finite(ledger$timing$fit_elapsed_s) && ledger$timing$fit_elapsed_s >= 0) &&
    is.double(ledger$peak_rss_kb) && length(ledger$peak_rss_kb) == 1L &&
    (is.na(ledger$peak_rss_kb) ||
      is.finite(ledger$peak_rss_kb) && ledger$peak_rss_kb >= 0)
  if (!typed) return(.bfgs_smoke_verdict(FALSE, "terminal_ledger_schema_invalid"))
  normal <- !is.null(ledger$bfgs)
  entered <- !is.null(ledger$bfgs_entry)
  prefix <- if (entered) .bfgs_smoke_validate_prefix(ledger) else NULL
  if (normal) {
    replay <- bfgs_smoke_recompute_result(ledger$bfgs)
    entry <- bfgs_smoke_validate_bfgs_entry(ledger$bfgs_entry,
      ledger$attempt_marker, replay$order_hash, attempt_marker_md5)
    expected_checks <- stats::setNames(as.list(rep(TRUE, 6L)),
      .bfgs_smoke_check_names)
    error_ok <- if (ledger$status %in% c("BFGS_INFRASTRUCTURE_HOLD",
        "BFGS_OPTIMIZER_ERROR", "BFGS_CURVATURE_UNAVAILABLE")) {
      .bfgs_smoke_scalar_character(ledger$error)
    } else is.na(ledger$error)
    evidence_ok <- entered && isTRUE(prefix$valid) && replay$valid && entry$valid &&
      identical(ledger$status, replay$status) &&
      identical(ledger$reason, replay$result_reason) &&
      identical(ledger$signature, ledger$bfgs$signature) &&
      identical(ledger$raw, ledger$bfgs$raw) &&
      identical(ledger$bfgs$signature, ledger$signature) &&
      identical(ledger$bfgs$raw_state, prefix$prefix_raw$raw_state) &&
      identical(unname(ledger$bfgs$raw$parameter_vector),
        unname(prefix$prefix_raw$parameter_vector)) &&
      identical(ledger$bfgs$raw$expected_objective,
        prefix$prefix_raw$objective) &&
      identical(ledger$order_hash, replay$order_hash) &&
      identical(ledger$order_hash, prefix$order_hash) &&
      identical(ledger$covariance_hash, replay$covariance_hash) &&
      identical(ledger$checks, expected_checks) && error_ok
  } else {
    fallback_status <- ledger$status %in% c("INVALID_PROVENANCE",
      "BFGS_INFRASTRUCTURE_HOLD")
    fallback_reason <- ledger$reason %in% c("provenance_failure", "runner_unwind")
    entry_ok <- if (entered) {
      .bfgs_smoke_md5(ledger$order_hash) && is.list(ledger$signature) &&
        is.list(ledger$raw) && is.list(ledger$continuation_source) &&
        isTRUE(prefix$valid) && identical(ledger$order_hash, prefix$order_hash) &&
        identical(ledger$raw, prefix$prefix_raw) &&
        bfgs_smoke_validate_bfgs_entry(ledger$bfgs_entry,
          ledger$attempt_marker, ledger$order_hash, attempt_marker_md5)$valid
    } else {
      is.null(ledger$signature) && is.null(ledger$raw) &&
        is.null(ledger$continuation_source) && is.na(ledger$order_hash)
    }
    expected_checks <- list(provenance = identical(ledger$status,
      "BFGS_INFRASTRUCTURE_HOLD"), preflight = TRUE, attempt_claimed = TRUE,
      fit_available = !is.na(ledger$timing$fit_elapsed_s), bfgs_entered = entered,
      terminal_evidence = FALSE)
    evidence_ok <- fallback_status && fallback_reason &&
      entry_ok && is.na(ledger$covariance_hash) &&
      identical(ledger$checks, expected_checks) &&
      .bfgs_smoke_scalar_character(ledger$error)
  }
  if (!evidence_ok) return(.bfgs_smoke_verdict(FALSE,
    "terminal_evidence_recomputation_failed"))
  if (!is.null(root)) {
    if (!.bfgs_smoke_scalar_character(root) || !dir.exists(root) ||
        !identical(normalizePath(root, mustWork = TRUE), ledger$receipt$root) ||
        !.bfgs_smoke_empty_directory(file.path(root, ".attempt-started.claim")) ||
        !.bfgs_smoke_regular_file(file.path(root, "all-attempt-ledger.rds")) ||
        !identical(tryCatch(readRDS(file.path(root, "all-attempt-ledger.rds")),
          error = function(e) NULL), ledger) ||
        !identical(tryCatch(readRDS(file.path(root, "root-receipt.rds")),
          error = function(e) NULL), ledger$receipt) ||
        !identical(tryCatch(readRDS(file.path(root, "attempt-started.rds")),
          error = function(e) NULL), ledger$attempt_marker) ||
        !identical(ledger$attempt_marker$receipt_md5,
          unname(tools::md5sum(file.path(root, "root-receipt.rds")))[[1L]]) ||
        (!is.null(ledger$bfgs_entry) &&
          !identical(ledger$bfgs_entry$attempt_marker_md5,
            unname(tools::md5sum(file.path(root, "attempt-started.rds")))[[1L]]))) {
      return(.bfgs_smoke_verdict(FALSE, "terminal_disk_binding_invalid"))
    }
    if (!.bfgs_smoke_live_receipt_ok(ledger$receipt, root)) {
      return(.bfgs_smoke_verdict(FALSE, "terminal_live_receipt_invalid"))
    }
    preflight <- c("fixture.rds", "root-receipt.rds", "session-info.rds",
      "time-estimate.md")
    if (identical(source_gate, "BFGS_P1_S3_C360_R3_V4"))
      preflight <- c(preflight, "mesh.rds")
    expected <- c(preflight, "attempt-started.rds", "all-attempt-ledger.rds")
    if (file.exists(file.path(root, "fit.rds"))) expected <- c(expected, "fit.rds")
    if (!is.null(ledger$bfgs_entry)) expected <- c(expected, "bfgs-entered.rds")
    if (!identical(file.exists(file.path(root, "fit.rds")),
        isTRUE(ledger$checks$fit_available))) {
      return(.bfgs_smoke_verdict(FALSE, "terminal_fit_inventory_invalid"))
    }
    if (isTRUE(ledger$checks$fit_available)) {
      fit <- tryCatch(readRDS(file.path(root, "fit.rds")),
        error = function(e) NULL)
      fit_binding_ok <- is.list(fit) && (!entered ||
        isTRUE(prefix$valid) &&
          identical(fit$warm_restart_provenance,
            ledger$continuation_source$warm_restart_provenance) &&
          identical(fit$isdm_polish_provenance,
            ledger$continuation_source$isdm_polish_provenance) &&
          identical(fit$restart_history,
            ledger$continuation_source$restart_history) &&
          identical(fit$start_provenance,
            ledger$continuation_source$start_provenance) &&
          identical(ledger$signature$map,
            .bfgs_smoke_hash_object(fit$tmb_map)) &&
          identical(ledger$signature$data,
            .bfgs_smoke_hash_object(fit$tmb_data)) &&
          identical(ledger$signature$random,
            .bfgs_smoke_hash_object(fit$random)))
      if (!fit_binding_ok) return(.bfgs_smoke_verdict(FALSE,
        "terminal_fit_evidence_binding_invalid"))
    }
    if (!is.null(ledger$bfgs_entry) &&
        (!.bfgs_smoke_regular_file(file.path(root, "bfgs-entered.rds")) ||
        !identical(tryCatch(readRDS(file.path(root, "bfgs-entered.rds")),
          error = function(e) NULL), ledger$bfgs_entry))) {
      return(.bfgs_smoke_verdict(FALSE, "terminal_entry_disk_binding_invalid"))
    }
    manifest <- bfgs_smoke_validate_manifest(root, expected,
      expected_dirs = ".attempt-started.claim")
    if (!manifest$valid) return(.bfgs_smoke_verdict(FALSE,
      paste0("terminal_", manifest$reason)))
  }
  .bfgs_smoke_verdict(TRUE, "terminal_ledger_recomputed")
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
      !identical(consumed$attempt_marker_exists, TRUE) ||
      !identical(consumed$attempt_claim_exists, TRUE)) {
    return(c(.bfgs_smoke_verdict(
      FALSE, "paper2_terminal_or_attempt_marker_missing"
    ), empty))
  }
  ledger <- tryCatch(readRDS(path), error = function(e) NULL)
  md5 <- unname(tools::md5sum(path))[[1L]]
  verdict <- bfgs_smoke_validate_terminal_ledger(
    ledger, "BFGS_P2_S6_C360_R3_V4", commit, root
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
    identical(receipt$schema, "BFGS_P2_S6_C360_R3_V4_PREFLIGHT_V1") &&
    identical(receipt$source_gate, "BFGS_P2_S6_C360_R3_V4") &&
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
  algorithm_statuses <- c(
    "BFGS_RAW_INELIGIBLE", "BFGS_OPTIMIZER_ERROR",
    "BFGS_CURVATURE_UNAVAILABLE", "BFGS_CURVATURE_INVALID",
    "BFGS_NO_NUMERICAL_ADMISSION", "BFGS_NUMERICAL_ADMISSION"
  )
  result_ok <- provenance_ok && is.list(ledger$bfgs) &&
    is.list(ledger$bfgs_entry) &&
    identical(ledger$bfgs$optimizer_entered, TRUE) &&
    ledger$status %in% algorithm_statuses &&
    identical(ledger$bfgs$estimator, "BFGS_EXACT_GRADIENT_CONTINUATION_V1") &&
    identical(ledger$bfgs$status, ledger$status) &&
    identical(ledger$bfgs$signature, ledger$signature) &&
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
