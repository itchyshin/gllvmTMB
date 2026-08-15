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
    state_schema = "MSPDE_P1_S3_C360_R3_V3_MATERIALIZED_V2_STATE_V1",
    historical_contract_path = paste0(
      "/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/",
      "dev/isdm-package-recovery/matched-spde-smoke-contract.R"
    ),
    historical_contract_md5 = "8b1b58aa72406ed5a2de74f93239a1d0"
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
    identical(receipt$contract_md5, locked$historical_contract_md5) &&
    .spde_slope_gauge_nofit_regular_file(locked$historical_contract_path) &&
    identical(unname(tools::md5sum(locked$historical_contract_path))[[1L]],
      locked$historical_contract_md5) &&
    all(vapply(receipt[c("runner_md5", "contract_md5", "design_md5")],
      .spde_slope_gauge_nofit_md5, logical(1L)))
  state_ok <- .spde_slope_gauge_nofit_state_ok(state, locked$state_schema)
  .spde_slope_gauge_nofit_verdict(
    receipt_ok && state_ok,
    if (receipt_ok && state_ok) "predecessor_bytes_valid" else "predecessor_receipt_or_state_invalid",
    root = normal_root, commit = locked$commit, receipt = receipt, state = state,
    state_md5 = unname(locked$files[["v2-materialized-state.rds"]])
  )
}

## V2 begins from the V1 forensic terminal, but never consumes its numerical
## payload.  These are deliberately V2-named predicates: the V1 byte/root
## validators above remain the historical implementation used to classify V1.
.spde_slope_gauge_nofit_v2_v1_root <- function() {
  "/private/tmp/gllvmtmb-isdm-bfgs-exact-gradient/dev/isdm-package-recovery/results/PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1"
}

.spde_slope_gauge_nofit_v2_locked_v1 <- function() {
  list(
    root = .spde_slope_gauge_nofit_v2_v1_root(),
    commit = "4eb710ed12cc5346d4ed4bcae0e8182d8ba3fbc3",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1",
    receipt_schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_ROOT_V1",
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    reason = "child_evidence_invalid",
    files = c(
      "child-receipt.rds" = "e5481430c170b8f3fa5c1eb1da33e27e",
      "no-fit-result.rds" = "0af4bc98742861950896c1e79dadb2e0",
      "materializer.R" = "38548a8e8c18f4e8f89c3e465ace8ad4",
      "root-receipt.rds" = "1d9b1b0b31a993dc88427ce6989dea85",
      "session-info.rds" = "e5a10dc9cb603476373cbea8ac84c8ba",
      "time-estimate.md" = "b3167b86ae6660cd9422ef0b7e151312",
      "file-manifest.csv" = "fd83183495b88a37c677682b9f9e6015"
    ),
    directories = ".attempt-started.claim"
  )
}

.spde_slope_gauge_nofit_v2_manifest_ok <- function(root, locked) {
  path <- file.path(root, "file-manifest.csv")
  manifest <- if (.spde_slope_gauge_nofit_regular_file(path)) {
    tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
  } else NULL
  declared <- setdiff(names(locked$files), "file-manifest.csv")
  is.data.frame(manifest) && identical(names(manifest), c("path", "md5")) &&
    identical(as.character(manifest$path), declared) &&
    identical(as.character(manifest$md5), unname(locked$files[declared]))
}

spde_slope_gauge_nofit_v2_validate_v1_forensic <- function(
    root = .spde_slope_gauge_nofit_v2_locked_v1()$root,
    locked = .spde_slope_gauge_nofit_v2_locked_v1()) {
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  expected_root <- tryCatch(normalizePath(locked$root, mustWork = TRUE), error = function(e) NA_character_)
  if (!.spde_slope_gauge_nofit_scalar_character(normal_root) || is.na(expected_root) ||
      !identical(normal_root, expected_root)) {
    return(.spde_slope_gauge_nofit_verdict(FALSE, "v1_forensic_root_invalid"))
  }
  inventory <- list.files(normal_root, all.files = TRUE, no.. = TRUE, recursive = FALSE)
  files <- names(locked$files)
  claim <- file.path(normal_root, locked$directories)
  paths <- file.path(normal_root, files)
  bytes_ok <- identical(sort(inventory), sort(c(files, locked$directories))) &&
    all(vapply(paths, .spde_slope_gauge_nofit_regular_file, logical(1L))) &&
    identical(unname(tools::md5sum(paths)), unname(locked$files)) &&
    isTRUE(file.info(claim)$isdir[[1L]]) && identical(Sys.readlink(claim), "") &&
    identical(list.files(claim, all.files = TRUE, no.. = TRUE), character()) &&
    .spde_slope_gauge_nofit_v2_manifest_ok(normal_root, locked)
  if (!bytes_ok) return(.spde_slope_gauge_nofit_verdict(FALSE, "v1_forensic_packet_bytes_invalid"))
  receipt <- tryCatch(readRDS(file.path(normal_root, "root-receipt.rds")), error = function(e) NULL)
  receipt_root <- if (is.list(receipt) && .spde_slope_gauge_nofit_scalar_character(receipt$root)) {
    tryCatch(normalizePath(receipt$root, mustWork = TRUE), error = function(e) NA_character_)
  } else NA_character_
  fields <- c(
    "schema", "gate", "root", "commit", "status", "reason", "predecessor", "sources", "dll",
    "controls", "parent_stage", "process", "child_result_md5", "time_estimate_md5"
  )
  receipt_ok <- .spde_slope_gauge_nofit_exact_names(receipt, fields) &&
    identical(receipt$schema, locked$receipt_schema) && identical(receipt$gate, locked$gate) &&
    identical(receipt_root, normal_root) && identical(receipt$commit, locked$commit) &&
    identical(receipt$status, locked$status) && identical(receipt$reason, locked$reason) &&
    .spde_slope_gauge_nofit_md5(receipt$child_result_md5) &&
    identical(receipt$child_result_md5, locked$files[["no-fit-result.rds"]]) &&
    .spde_slope_gauge_nofit_md5(receipt$time_estimate_md5) &&
    identical(receipt$time_estimate_md5, locked$files[["time-estimate.md"]])
  .spde_slope_gauge_nofit_verdict(
    receipt_ok,
    if (receipt_ok) "v1_forensic_terminal_valid" else "v1_forensic_receipt_invalid",
    root = normal_root, commit = locked$commit, receipt = receipt,
    files = locked$files, status = locked$status, terminal_reason = locked$reason
  )
}

.spde_slope_gauge_nofit_v2_v3_projection_ok <- function(predecessor, v3_verdict) {
  fields <- c("root", "commit", "receipt", "state_md5")
  .spde_slope_gauge_nofit_exact_names(predecessor, fields) &&
    is.list(v3_verdict) && isTRUE(v3_verdict$valid) &&
    identical(v3_verdict$reason, "predecessor_bytes_valid") &&
    identical(predecessor$root, v3_verdict$root) &&
    identical(predecessor$commit, v3_verdict$commit) &&
    identical(predecessor$receipt, v3_verdict$receipt) &&
    identical(predecessor$state_md5, v3_verdict$state_md5)
}

.spde_slope_gauge_nofit_v2_child_ok <- function(child, v1_verdict, v3_verdict, expected_dll) {
  fields <- c(
    "schema", "parent_pid", "child_pid", "started_at", "deadline_s", "status", "reason",
    "predecessor", "dll", "object", "nofit", "callback_audit", "error", "ended_at", "elapsed_s"
  )
  predecessor_fields <- c(
    "root", "commit", "receipt", "state_md5", "v1_forensic", "historical_reason", "post_replay_gc"
  )
  if (!.spde_slope_gauge_nofit_exact_names(child, fields) ||
      !identical(child$schema, "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_CHILD_V1") ||
      !isTRUE(v1_verdict$valid) || !identical(v1_verdict$reason, "v1_forensic_terminal_valid") ||
      !.spde_slope_gauge_nofit_exact_names(child$predecessor, predecessor_fields) ||
      !.spde_slope_gauge_nofit_v2_v3_projection_ok(
        child$predecessor[c("root", "commit", "receipt", "state_md5")], v3_verdict
      ) ||
      !identical(child$predecessor$v1_forensic, v1_verdict[c(
        "root", "commit", "receipt", "files", "status", "terminal_reason"
      )])) return(FALSE)
  legacy <- child
  legacy$schema <- "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_CHILD_V1"
  legacy$predecessor <- child$predecessor[c("root", "commit", "state_md5", "historical_reason", "post_replay_gc")]
  .spde_slope_gauge_nofit_child_ok(legacy, v3_verdict, expected_dll, state = v3_verdict$state)
}

## Bridge an already-created object to the strict generic callback contract.
## The runner alone must prove the live DLL/object lifecycle; this local helper
## checks the supplied bridge evidence and retains its callback records.  It
## never loads a DLL or calls TMB::MakeADFun.
spde_slope_gauge_nofit_wrap_object_callbacks <- function(
    object, state, object_id, dll_path, dll_md5,
    locked = spde_slope_gauge_nofit_locked_predecessor()) {
  if (!.spde_slope_gauge_nofit_state_ok(state, locked$state_schema) ||
      !is.list(object) || !is.function(object$fn) || !is.function(object$gr) ||
      !is.numeric(object$par) || !identical(names(object$par), state$block_labels) ||
      length(object$par) != length(state$theta) ||
      !is.integer(object_id) || length(object_id) != 1L || is.na(object_id) || object_id < 1L ||
      !is.character(dll_path) || length(dll_path) != 1L || is.na(dll_path) || !file.exists(dll_path) ||
      !.spde_slope_gauge_nofit_md5(dll_md5) ||
      !identical(unname(tools::md5sum(dll_path))[[1L]], dll_md5)) {
    .spde_slope_gauge_fail("object callback bridge evidence is invalid")
  }
  raw_order <- state$parameter_order
  audit <- new.env(parent = emptyenv())
  audit$objective <- list()
  audit$gradient <- list()
  require_theta <- function(theta) {
    if (!is.numeric(theta) || length(theta) != length(raw_order) || any(!is.finite(theta))) {
      .spde_slope_gauge_fail("fresh object callback received an invalid raw vector")
    }
    unname(as.double(theta))
  }
  objective_fn <- function(theta) {
    input <- require_theta(theta)
    value <- .spde_slope_gauge_scalar_double(object$fn(input), "fresh object objective")
    audit$objective[[length(audit$objective) + 1L]] <- list(
      input = stats::setNames(input, raw_order), value = value
    )
    value
  }
  gradient_fn <- function(theta) {
    input <- require_theta(theta)
    gradient <- object$gr(input)
    if (!is.numeric(gradient) || length(gradient) != length(raw_order) || any(!is.finite(gradient))) {
      .spde_slope_gauge_fail("fresh object gradient is not finite positional evidence")
    }
    supplied_names <- names(gradient)
    raw_gradient <- as.double(gradient)
    if (is.null(names(gradient))) {
      gradient <- stats::setNames(as.double(gradient), raw_order)
    } else if (!identical(names(gradient), raw_order)) {
      .spde_slope_gauge_fail("fresh object gradient supplied a noncanonical positional order")
    } else {
      gradient <- stats::setNames(as.double(gradient), raw_order)
    }
    audit$gradient[[length(audit$gradient) + 1L]] <- list(
      input = stats::setNames(input, raw_order), raw_gradient = raw_gradient,
      supplied_names = supplied_names, named_gradient = gradient
    )
    gradient
  }
  list(
    object_id = object_id, dll_path = normalizePath(dll_path, mustWork = TRUE), dll_md5 = dll_md5,
    block_labels = state$block_labels, parameter_order = raw_order,
    objective_fn = objective_fn, gradient_fn = gradient_fn,
    evaluation_audit = function() list(
      object_id = object_id, dll_path = normalizePath(dll_path, mustWork = TRUE),
      dll_md5 = dll_md5, objective = audit$objective, gradient = audit$gradient
    )
  )
}

## The parent-side gate contract is deliberately byte- and evidence-oriented.
## It does not construct a TMB object or re-run an objective: the child is the
## one-object executor, while this validator proves that exactly the retained
## process/result evidence supports the non-scientific gate status.

.spde_slope_gauge_nofit_gate_schema <- function() {
  "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_ROOT_V1"
}

.spde_slope_gauge_nofit_process_schema <- function() {
  "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_PROCESS_V1"
}

.spde_slope_gauge_nofit_gate_files <- function(has_child_result) {
  base <- c(
    "child-receipt.rds", "file-manifest.csv", "materializer.R",
    "root-receipt.rds", "session-info.rds", "time-estimate.md"
  )
  if (isTRUE(has_child_result)) c(base[[1L]], "no-fit-result.rds", base[-1L]) else base
}

.spde_slope_gauge_nofit_exact_names <- function(x, fields) {
  is.list(x) && identical(names(x), fields)
}

.spde_slope_gauge_nofit_scalar_character <- function(x, allow_na = FALSE) {
  is.character(x) && length(x) == 1L && (isTRUE(allow_na) || !is.na(x))
}

.spde_slope_gauge_nofit_scalar_double <- function(x, allow_na = FALSE) {
  is.double(x) && length(x) == 1L && (isTRUE(allow_na) || is.finite(x))
}

.spde_slope_gauge_nofit_named_hashes_ok <- function(x, names) {
  is.character(x) && identical(names(x), names) &&
    all(vapply(unname(x), .spde_slope_gauge_nofit_md5, logical(1L)))
}

.spde_slope_gauge_nofit_gate_manifest_ok <- function(root, files) {
  manifest_path <- file.path(root, "file-manifest.csv")
  manifest <- if (.spde_slope_gauge_nofit_regular_file(manifest_path)) {
    tryCatch(utils::read.csv(manifest_path, stringsAsFactors = FALSE), error = function(e) NULL)
  } else NULL
  declared <- setdiff(files, "file-manifest.csv")
  is.data.frame(manifest) && identical(names(manifest), c("path", "md5")) &&
    identical(as.character(manifest$path), declared) &&
    identical(as.character(manifest$md5), unname(tools::md5sum(file.path(root, declared))))
}

.spde_slope_gauge_nofit_controls_ok <- function(x) {
  identical(x, spde_slope_gauge_no_fit_controls())
}

spde_slope_gauge_nofit_audit_ok <- function(audit, nofit) {
  records <- if (is.list(nofit)) nofit$finite_difference else NULL
  raw_order <- spde_slope_gauge_raw_order()
  if (!is.list(audit) || !identical(names(audit), c(
    "object_id", "dll_path", "dll_md5", "objective", "gradient"
  )) || !is.list(nofit) || !is.list(records) || length(records) != 22L ||
      !is.integer(audit$object_id) || length(audit$object_id) != 1L || audit$object_id < 1L ||
      !.spde_slope_gauge_nofit_scalar_character(audit$dll_path) ||
      !.spde_slope_gauge_nofit_md5(audit$dll_md5) ||
      !is.list(audit$objective) || length(audit$objective) != 45L ||
      !is.list(audit$gradient) || length(audit$gradient) != 1L ||
      !is.double(nofit$raw_theta) || !identical(names(nofit$raw_theta), raw_order) ||
      !is.double(nofit$raw_gradient) || !identical(names(nofit$raw_gradient), raw_order) ||
      !all(vapply(audit$objective, function(record) {
        is.list(record) && identical(names(record), c("input", "value")) &&
          is.double(record$input) && identical(names(record$input), raw_order) &&
          is.double(record$value) && length(record$value) == 1L && is.finite(record$value)
      }, logical(1L))) ||
      !.spde_slope_gauge_nofit_exact_names(audit$gradient[[1L]], c(
        "input", "raw_gradient", "supplied_names", "named_gradient"
      )) || !identical(audit$objective[[1L]]$input, nofit$raw_theta) ||
      !identical(audit$objective[[1L]]$value, nofit$objective) ||
      !identical(audit$gradient[[1L]]$input, nofit$raw_theta) ||
      !identical(audit$gradient[[1L]]$raw_gradient, unname(nofit$raw_gradient)) ||
      !(is.null(audit$gradient[[1L]]$supplied_names) ||
        identical(audit$gradient[[1L]]$supplied_names, raw_order)) ||
      !identical(audit$gradient[[1L]]$named_gradient, nofit$raw_gradient)) return(FALSE)
  expected <- unlist(lapply(records, function(record) list(
    list(input = record$theta_plus, value = record$objective_plus),
    list(input = record$theta_minus, value = record$objective_minus)
  )), recursive = FALSE)
  all(vapply(seq_along(expected), function(i) {
    identical(audit$objective[[i + 1L]]$input, expected[[i]]$input) &&
      identical(audit$objective[[i + 1L]]$value, expected[[i]]$value)
  }, logical(1L)))
}

.spde_slope_gauge_nofit_complete_result_ok <- function(nofit, state) {
  fields <- c(
    "valid", "reason", "phi", "raw_theta", "objective", "raw_gradient",
    "transformed_gradient", "transformed_gradient_fd", "finite_difference", "controls", "errors"
  )
  raw_order <- spde_slope_gauge_raw_order()
  phi_order <- spde_slope_gauge_phi_order()
  if (!.spde_slope_gauge_nofit_exact_names(nofit, fields) ||
      !is.logical(nofit$valid) || length(nofit$valid) != 1L || is.na(nofit$valid) ||
      !.spde_slope_gauge_nofit_scalar_character(nofit$reason) ||
      !is.double(nofit$phi) || !identical(names(nofit$phi), phi_order) ||
      !is.double(nofit$raw_theta) || !identical(names(nofit$raw_theta), raw_order) ||
      !is.double(nofit$objective) || length(nofit$objective) != 1L || !is.finite(nofit$objective) ||
      !is.double(nofit$raw_gradient) || !identical(names(nofit$raw_gradient), raw_order) ||
      !is.double(nofit$transformed_gradient) || !identical(names(nofit$transformed_gradient), phi_order) ||
      !is.double(nofit$transformed_gradient_fd) ||
      !identical(names(nofit$transformed_gradient_fd), phi_order) ||
      !.spde_slope_gauge_nofit_controls_ok(nofit$controls) ||
      !is.list(nofit$errors) || !identical(names(nofit$errors), c(
        "theta", "objective", "gradient", "transformed_gradient"
      )) || !all(vapply(nofit$errors, .spde_slope_gauge_nofit_scalar_double, logical(1L))) ||
      !is.list(nofit$finite_difference) || length(nofit$finite_difference) != 22L ||
      any(!is.finite(c(nofit$phi, nofit$raw_theta, nofit$raw_gradient,
        nofit$transformed_gradient, nofit$transformed_gradient_fd)))) return(FALSE)
  records_ok <- all(vapply(seq_along(nofit$finite_difference), function(j) {
    record <- nofit$finite_difference[[j]]
    is.list(record) && identical(names(record), c(
      "index", "phi_id", "h", "phi_plus", "phi_minus", "theta_plus", "theta_minus",
      "objective_plus", "objective_minus"
    )) && identical(record$index, as.integer(j)) && identical(record$phi_id, phi_order[[j]]) &&
      is.double(record$h) && length(record$h) == 1L && is.finite(record$h) &&
      is.double(record$phi_plus) && identical(names(record$phi_plus), phi_order) &&
      is.double(record$phi_minus) && identical(names(record$phi_minus), phi_order) &&
      is.double(record$theta_plus) && identical(names(record$theta_plus), raw_order) &&
      is.double(record$theta_minus) && identical(names(record$theta_minus), raw_order) &&
      is.double(record$objective_plus) && length(record$objective_plus) == 1L &&
      is.double(record$objective_minus) && length(record$objective_minus) == 1L &&
      is.finite(record$objective_plus) && is.finite(record$objective_minus)
  }, logical(1L)))
  if (!records_ok) return(FALSE)
  recomputed <- tryCatch({
    phi <- spde_slope_gauge_phi_from_theta(state$theta)
    raw_theta <- spde_slope_gauge_theta_from_phi(phi)
    transformed <- spde_slope_gauge_full_chain_gradient(phi, nofit$raw_gradient)
    step <- .Machine$double.eps^(1 / 3) * pmax(1, abs(phi))
    fd <- vapply(nofit$finite_difference, function(record) {
      (record$objective_plus - record$objective_minus) / (2 * record$h)
    }, numeric(1L))
    names(fd) <- phi_order
    errors <- c(
      theta = .spde_slope_gauge_relative_error(raw_theta, state$theta),
      objective = abs(nofit$objective - state$objective) / max(1, abs(nofit$objective), abs(state$objective)),
      gradient = .spde_slope_gauge_relative_error(nofit$raw_gradient, state$gradient),
      transformed_gradient = .spde_slope_gauge_relative_error(transformed, fd)
    )
    list(phi = phi, raw_theta = raw_theta, transformed = transformed, step = step, fd = fd, errors = errors)
  }, error = function(e) NULL)
  if (is.null(recomputed) || !identical(nofit$phi, recomputed$phi) ||
      !identical(nofit$raw_theta, recomputed$raw_theta) ||
      !identical(nofit$transformed_gradient, recomputed$transformed) ||
      !identical(nofit$transformed_gradient_fd, recomputed$fd) ||
      !identical(unname(nofit$errors), unname(as.list(recomputed$errors)))) return(FALSE)
  for (j in seq_along(nofit$finite_difference)) {
    record <- nofit$finite_difference[[j]]
    delta <- rep(0, 22L); names(delta) <- phi_order; delta[[j]] <- recomputed$step[[j]]
    if (!identical(record$h, as.double(recomputed$step[[j]])) ||
        !identical(record$phi_plus, recomputed$phi + delta) ||
        !identical(record$phi_minus, recomputed$phi - delta) ||
        !identical(record$theta_plus, spde_slope_gauge_theta_from_phi(recomputed$phi + delta)) ||
        !identical(record$theta_minus, spde_slope_gauge_theta_from_phi(recomputed$phi - delta))) return(FALSE)
  }
  expected_valid <- all(recomputed$errors <= unlist(nofit$controls[c(
    "theta", "objective", "gradient", "transformed_gradient"
  )]))
  identical(nofit$valid, expected_valid) && identical(nofit$reason,
    if (expected_valid) "no_fit_state_valid" else "no_fit_state_replay_failed")
}

.spde_slope_gauge_nofit_child_ok <- function(child, predecessor, expected_dll, state = NULL) {
  fields <- c(
    "schema", "parent_pid", "child_pid", "started_at", "deadline_s", "status", "reason",
    "predecessor", "dll", "object", "nofit", "callback_audit", "error", "ended_at", "elapsed_s"
  )
  complete_status <- c("SPDE_SLOPE_GAUGE_NOFIT_VALID", "SPDE_SLOPE_GAUGE_NOFIT_REPLAY_HOLD")
  if (!.spde_slope_gauge_nofit_exact_names(child, fields) ||
      !identical(child$schema, "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_CHILD_V1") ||
      !is.integer(child$parent_pid) || length(child$parent_pid) != 1L || child$parent_pid < 1L ||
      !is.integer(child$child_pid) || length(child$child_pid) != 1L || child$child_pid < 1L ||
      identical(child$parent_pid, child$child_pid) ||
      !.spde_slope_gauge_nofit_scalar_double(child$deadline_s) || child$deadline_s != 1800 ||
      !.spde_slope_gauge_nofit_scalar_double(child$elapsed_s) || child$elapsed_s < 0 ||
      !.spde_slope_gauge_nofit_scalar_character(child$status) ||
      !.spde_slope_gauge_nofit_scalar_character(child$reason) ||
      !.spde_slope_gauge_nofit_scalar_character(child$started_at) ||
      !.spde_slope_gauge_nofit_scalar_character(child$ended_at) ||
      !is.list(child$object) || !is.integer(child$object$created) ||
      !is.integer(child$object$released) || length(child$object$created) != 1L ||
      length(child$object$released) != 1L || child$object$created < 0L ||
      child$object$released < 0L || child$object$created < child$object$released) return(FALSE)
  if (child$status %in% complete_status) {
    return(is.list(child$predecessor) && identical(child$predecessor$root, predecessor$root) &&
      identical(child$predecessor$commit, predecessor$commit) &&
      identical(child$predecessor$state_md5, predecessor$state_md5) &&
      identical(child$predecessor$historical_reason, "closeout_recomputed") &&
      isTRUE(child$predecessor$post_replay_gc) && is.list(child$dll) &&
      identical(child$dll$path, expected_dll$path) && identical(child$dll$md5, expected_dll$md5) &&
      identical(child$object$created, 1L) && identical(child$object$released, 1L) &&
      is.list(child$nofit) && is.list(child$callback_audit) &&
      is.character(child$error) && length(child$error) == 1L && is.na(child$error) &&
      is.list(state) && .spde_slope_gauge_nofit_complete_result_ok(child$nofit, state) &&
      spde_slope_gauge_nofit_audit_ok(child$callback_audit, child$nofit) &&
      if (identical(child$status, "SPDE_SLOPE_GAUGE_NOFIT_VALID")) isTRUE(child$nofit$valid) else
        identical(child$nofit$reason, "no_fit_state_replay_failed"))
  }
  identical(child$status, "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD") &&
    child$reason %in% c("predecessor_bytes_invalid", "dll_identity_failure",
      "historical_v3_replay_failure", "fresh_object_unavailable",
      "callback_or_finite_difference_failure", "callback_audit_invalid",
      "object_release_failure", "time_limit_exceeded", "child_unexpected_failure") &&
    !isTRUE(child$nofit$valid) && .spde_slope_gauge_nofit_scalar_character(child$error)
}

.spde_slope_gauge_nofit_process_ok <- function(
    process, child, command, arguments, child_evidence_valid = TRUE) {
  fields <- c(
    "schema", "command", "arguments", "parent_pid", "child_pid", "started_at", "ended_at",
    "elapsed_s", "deadline_s", "timed_out", "exit_status", "signal", "stdout_md5", "stderr_md5", "child_result_md5"
  )
  if (!.spde_slope_gauge_nofit_exact_names(process, fields) ||
      !identical(process$schema, .spde_slope_gauge_nofit_process_schema()) ||
      !identical(process$command, command) || !identical(process$arguments, arguments) ||
      !is.integer(process$parent_pid) ||
      length(process$parent_pid) != 1L || process$parent_pid < 1L ||
      !.spde_slope_gauge_nofit_scalar_character(process$started_at) ||
      !.spde_slope_gauge_nofit_scalar_character(process$ended_at) ||
      !.spde_slope_gauge_nofit_scalar_double(process$elapsed_s) || process$elapsed_s < 0 ||
      !.spde_slope_gauge_nofit_scalar_double(process$deadline_s) || process$deadline_s != 1800 ||
      !is.logical(process$timed_out) || length(process$timed_out) != 1L || is.na(process$timed_out) ||
      !.spde_slope_gauge_nofit_md5(process$stdout_md5) || !.spde_slope_gauge_nofit_md5(process$stderr_md5) ||
      !(is.integer(process$exit_status) && length(process$exit_status) == 1L) ||
      !.spde_slope_gauge_nofit_scalar_character(process$signal, allow_na = TRUE)) return(FALSE)
  if (is.null(child)) {
    return(is.integer(process$child_pid) && length(process$child_pid) == 1L && is.na(process$child_pid) &&
      is.character(process$child_result_md5) && length(process$child_result_md5) == 1L && is.na(process$child_result_md5) &&
      .spde_slope_gauge_nofit_scalar_character(process$signal, allow_na = TRUE))
  }
  if (!isTRUE(child_evidence_valid)) {
    return(!isTRUE(process$timed_out) && identical(process$exit_status, 0L) && is.na(process$signal) &&
      ((is.integer(process$child_pid) && length(process$child_pid) == 1L && is.na(process$child_pid)) ||
        (is.integer(process$child_pid) && length(process$child_pid) == 1L &&
        process$child_pid > 0L && !identical(process$child_pid, process$parent_pid))) &&
      .spde_slope_gauge_nofit_md5(process$child_result_md5))
  }
  !isTRUE(process$timed_out) && identical(process$parent_pid, child$parent_pid) &&
    identical(process$child_pid, child$child_pid) && !identical(process$child_pid, process$parent_pid) &&
    identical(process$exit_status, 0L) && is.na(process$signal) &&
    .spde_slope_gauge_nofit_md5(process$child_result_md5)
}

spde_slope_gauge_nofit_validate_gate_root <- function(
    root, source_paths, predecessor = spde_slope_gauge_nofit_locked_predecessor(),
    commit = NULL) {
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  source_names <- c("child_runner", "pure_contract", "nofit_contract", "historical_contract",
    "design", "materializer")
  if (!.spde_slope_gauge_nofit_scalar_character(normal_root) ||
      !is.character(source_paths) || !identical(names(source_paths), source_names) ||
      !all(vapply(unname(source_paths), .spde_slope_gauge_nofit_regular_file, logical(1L)))) {
    return(.spde_slope_gauge_nofit_verdict(FALSE, "gate_root_or_source_invalid"))
  }
  inventory <- list.files(normal_root, all.files = TRUE, no.. = TRUE, recursive = FALSE)
  has_result <- "no-fit-result.rds" %in% inventory
  files <- .spde_slope_gauge_nofit_gate_files(has_result)
  claim <- file.path(normal_root, ".attempt-started.claim")
  paths <- file.path(normal_root, files)
  packet_ok <- identical(sort(inventory), sort(c(files, ".attempt-started.claim"))) &&
    all(vapply(paths, .spde_slope_gauge_nofit_regular_file, logical(1L))) &&
    isTRUE(file.info(claim)$isdir[[1L]]) && identical(Sys.readlink(claim), "") &&
    identical(list.files(claim, all.files = TRUE, no.. = TRUE), character()) &&
    .spde_slope_gauge_nofit_gate_manifest_ok(normal_root, files)
  if (!packet_ok) return(.spde_slope_gauge_nofit_verdict(FALSE, "gate_packet_bytes_invalid"))
  root_receipt <- tryCatch(readRDS(file.path(normal_root, "root-receipt.rds")), error = function(e) NULL)
  process <- tryCatch(readRDS(file.path(normal_root, "child-receipt.rds")), error = function(e) NULL)
  child <- if (has_result) tryCatch(readRDS(file.path(normal_root, "no-fit-result.rds")), error = function(e) NULL) else NULL
  receipt_fields <- c(
    "schema", "gate", "root", "commit", "status", "reason", "predecessor", "sources", "dll",
    "controls", "parent_stage", "process", "child_result_md5", "time_estimate_md5"
  )
  source_hashes <- unname(tools::md5sum(source_paths)); names(source_hashes) <- source_names
  if (is.null(commit)) {
    repo <- dirname(dirname(dirname(source_paths[["materializer"]])))
    commit <- tryCatch(system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE,
      stderr = FALSE), error = function(e) NA_character_)
    commit <- if (is.character(commit) && length(commit) == 1L) commit else NA_character_
  }
  predecessor_verdict <- spde_slope_gauge_nofit_validate_predecessor_bytes(predecessor$root, predecessor)
  receipt_ok <- .spde_slope_gauge_nofit_exact_names(root_receipt, receipt_fields) &&
    identical(root_receipt$schema, .spde_slope_gauge_nofit_gate_schema()) &&
    identical(root_receipt$gate, "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1") &&
    identical(root_receipt$root, normal_root) && identical(root_receipt$commit, commit) &&
    .spde_slope_gauge_nofit_scalar_character(root_receipt$status) &&
    .spde_slope_gauge_nofit_scalar_character(root_receipt$reason) &&
    identical(root_receipt$predecessor, predecessor_verdict[c("receipt", "state_md5")]) &&
    identical(root_receipt$sources, source_hashes) && .spde_slope_gauge_nofit_exact_names(
      root_receipt$dll, c("path", "md5")
    ) &&
    identical(unname(tools::md5sum(file.path(normal_root, "materializer.R")))[[1L]],
      source_hashes[["materializer"]]) && is.list(root_receipt$dll) &&
    .spde_slope_gauge_nofit_controls_ok(root_receipt$controls) &&
    .spde_slope_gauge_nofit_exact_names(root_receipt$parent_stage, c(
      "schema", "gate_base", "stage", "parent_pid", "child_output"
    )) && identical(root_receipt$parent_stage$schema,
      "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_PARENT_STAGE_V1") &&
    identical(root_receipt$parent_stage$gate_base, dirname(normal_root)) &&
    identical(dirname(root_receipt$parent_stage$stage), dirname(normal_root)) &&
    grepl("^\\.PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-", basename(root_receipt$parent_stage$stage)) &&
    identical(root_receipt$parent_stage$child_output,
      file.path(root_receipt$parent_stage$stage, "child-result.rds")) &&
    identical(root_receipt$parent_stage$parent_pid, process$parent_pid) &&
    identical(root_receipt$process, process) && .spde_slope_gauge_nofit_md5(root_receipt$time_estimate_md5) &&
    identical(root_receipt$time_estimate_md5,
      unname(tools::md5sum(file.path(normal_root, "time-estimate.md")))[[1L]]) &&
    if (has_result) identical(root_receipt$child_result_md5,
      unname(tools::md5sum(file.path(normal_root, "no-fit-result.rds")))[[1L]]) else is.na(root_receipt$child_result_md5)
  child_declared_dll <- if (has_result && is.list(child) && is.list(child$dll)) child$dll else
    list(path = NA_character_, md5 = NA_character_)
  raw_child_ok <- has_result && isTRUE(tryCatch(.spde_slope_gauge_nofit_child_ok(
    child, predecessor_verdict, child_declared_dll, state = predecessor_verdict$state
  ), error = function(e) FALSE))
  evidence_hold <- has_result && identical(root_receipt$status,
    "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD") &&
    identical(root_receipt$reason, "child_evidence_invalid") && !raw_child_ok
  expected_dll <- root_receipt$dll
  child_ok <- !has_result || evidence_hold || raw_child_ok
  complete_child <- has_result && !evidence_hold &&
    is.list(child) && .spde_slope_gauge_nofit_scalar_character(child$status) && child$status %in% c(
      "SPDE_SLOPE_GAUGE_NOFIT_VALID", "SPDE_SLOPE_GAUGE_NOFIT_REPLAY_HOLD"
    )
  dll_missing <- is.character(root_receipt$dll$path) && length(root_receipt$dll$path) == 1L &&
    is.na(root_receipt$dll$path) && is.character(root_receipt$dll$md5) &&
    length(root_receipt$dll$md5) == 1L && is.na(root_receipt$dll$md5)
  dll_live <- .spde_slope_gauge_nofit_scalar_character(root_receipt$dll$path) &&
    .spde_slope_gauge_nofit_md5(root_receipt$dll$md5) &&
    .spde_slope_gauge_nofit_regular_file(root_receipt$dll$path) &&
    identical(unname(tools::md5sum(root_receipt$dll$path))[[1L]], root_receipt$dll$md5)
  dll_ok <- if (complete_child) {
    dll_live && identical(root_receipt$dll, child$dll)
  } else if (has_result && !evidence_hold && is.list(child$dll)) {
    dll_live && identical(root_receipt$dll, child$dll)
  } else {
    dll_missing
  }
  expected_command <- R.home("bin/Rscript")
  expected_arguments <- c("--vanilla", source_paths[["child_runner"]], "child",
    root_receipt$parent_stage$child_output, as.character(process$parent_pid))
  process_ok <- .spde_slope_gauge_nofit_process_ok(process, child, expected_command,
    expected_arguments, child_evidence_valid = !evidence_hold) &&
    (!has_result || identical(process$child_result_md5, root_receipt$child_result_md5))
  status_ok <- if (!has_result) {
    identical(root_receipt$status, "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD") &&
      identical(root_receipt$reason, "child_process_no_result")
  } else if (evidence_hold) {
    TRUE
  } else if (identical(child$status, "SPDE_SLOPE_GAUGE_NOFIT_VALID")) {
    identical(root_receipt$status, child$status) && identical(root_receipt$reason, child$reason)
  } else if (identical(child$status, "SPDE_SLOPE_GAUGE_NOFIT_REPLAY_HOLD")) {
    identical(root_receipt$status, child$status) && identical(root_receipt$reason, child$reason)
  } else {
    identical(root_receipt$status, "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD") &&
      identical(root_receipt$reason, child$reason)
  }
  valid <- packet_ok && isTRUE(predecessor_verdict$valid) && receipt_ok && dll_ok && child_ok && process_ok && status_ok
  .spde_slope_gauge_nofit_verdict(
    valid,
    if (valid)
      "nofit_gate_root_valid" else "nofit_gate_evidence_invalid",
    receipt = root_receipt, process = process, child = child,
    checks = c(packet = packet_ok, predecessor = isTRUE(predecessor_verdict$valid),
      receipt = receipt_ok, dll = dll_ok, child = child_ok, process = process_ok, status = status_ok)
  )
}
