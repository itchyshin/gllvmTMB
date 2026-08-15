#!/usr/bin/env Rscript
## One private Paper-2 exact-gradient BFGS continuation. No G3, retry,
## profile, recovery panel, remote compute, or public output.

args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
root_arg <- value("output")
pkg <- normalizePath(value("pkg", getwd()), mustWork = TRUE)
campaign_sha <- value("campaign-sha")
paper <- Sys.getenv("GLLVM_BFGS_SMOKE_PAPER", unset = "paper2")
if (!paper %in% c("paper1", "paper2")) {
  stop("invalid private BFGS paper route", call. = FALSE)
}
source_gate <- if (identical(paper, "paper1")) {
  "BFGS_P1_S3_C360_R3_V4"
} else {
  "BFGS_P2_S6_C360_R3_V4"
}
if (!mode %in% c("validate", "preflight", "smoke") || is.null(root_arg)) {
  stop("require --mode=validate|preflight|smoke and --output=PATH", call. = FALSE)
}
script <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
  mustWork = TRUE
)
base <- dirname(script)
core_runner_file <- file.path(base, "run-bfgs-paper2-smoke.R")
fixture_file <- file.path(
  base,
  if (identical(paper, "paper1")) {
    "spatial-isdm-gate-b-smoke-fixture.R"
  } else {
    "g2h-360cell-fixture.R"
  }
)
design_file <- file.path(base, "2026-08-14-bfgs-exact-gradient-continuation-design.md")
contract_file <- file.path(base, "bfgs-smoke-contract.R")
source(fixture_file, local = TRUE)
source(contract_file, local = TRUE)
if (identical(paper, "paper1")) spatial_isdm_gate_b_seed <- 86301L
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
hash_object <- function(x) {
  path <- tempfile("bfgs-hash-")
  on.exit(unlink(path), add = TRUE)
  saveRDS(x, path, version = 3)
  hash_file(path)
}
commit <- function() system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE)[[1L]]
dirty <- function() length(system2(
  "git", c("-C", pkg, "status", "--porcelain", "--untracked-files=normal"),
  stdout = TRUE
)) > 0L
atomic_rds <- function(value, path) {
  tmp <- tempfile(paste0(".", basename(path), "."), tmpdir = dirname(path))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  saveRDS(value, tmp, version = 3)
  if (!file.rename(tmp, path)) stop("atomic RDS rename failed", call. = FALSE)
  invisible(path)
}
atomic_lines <- function(value, path) {
  tmp <- tempfile(paste0(".", basename(path), "."), tmpdir = dirname(path))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  writeLines(value, tmp, useBytes = TRUE)
  if (!file.rename(tmp, path)) stop("atomic text rename failed", call. = FALSE)
  invisible(path)
}
manifest <- function(root, paths) {
  paths <- sort(paths, method = "radix")
  value <- data.frame(path = paths,
    md5 = unname(tools::md5sum(file.path(root, paths))),
    stringsAsFactors = FALSE, check.names = FALSE)
  tmp <- tempfile(".file-manifest.csv.", tmpdir = root)
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  utils::write.csv(value, tmp, row.names = FALSE, quote = TRUE)
  if (!file.rename(tmp, file.path(root, "file-manifest.csv")))
    stop("atomic manifest rename failed", call. = FALSE)
  invisible(file.path(root, "file-manifest.csv"))
}
peak_rss_kb <- function() {
  output <- tryCatch(
    suppressWarnings(system2(
      "ps", c("-o", "rss=", "-p", as.character(Sys.getpid())), stdout = TRUE
    )),
    error = function(e) character()
  )
  ans <- if (length(output)) {
    suppressWarnings(as.numeric(trimws(output[[1L]])))
  } else {
    NA_real_
  }
  if (is.finite(ans)) ans else NA_real_
}
loaded_dll <- function() {
  dlls <- getLoadedDLLs()
  paths <- unique(vapply(
    dlls[grepl("gllvmTMB", names(dlls), fixed = TRUE)],
    function(x) x[["path"]], character(1L)
  ))
  paths <- paths[file.exists(paths)]
  if (length(paths) != 1L) stop("require exactly one loaded gllvmTMB DLL", call. = FALSE)
  source_path <- normalizePath(file.path(pkg, "src", "gllvmTMB.so"),
    mustWork = TRUE)
  loaded_md5 <- hash_file(paths[[1L]])
  source_md5 <- hash_file(source_path)
  if (!identical(loaded_md5, source_md5)) {
    stop("loaded DLL content does not match the sealed source DLL", call. = FALSE)
  }
  list(path = source_path, loaded_path = paths[[1L]], md5 = source_md5)
}
make <- function() {
  suppressMessages(devtools::load_all(pkg, quiet = TRUE))
  if (identical(paper, "paper1")) {
    fixture <- spatial_isdm_gate_b_make_fixture(seed = 86301L)
    mesh <- make_mesh(
      fixture$mesh_data, c("lon", "lat"),
      cutoff = fixture$truth$constants$mesh_cutoff
    )
    spatial_isdm_gate_b_validate_fixture(fixture, mesh)
    list(fixture = fixture, mesh = mesh, dll = loaded_dll())
  } else {
    fixture <- g2h_make_fixture(seed = 86302L)
    g2h_validate_fixture(fixture)
    list(fixture = fixture, mesh = NULL, dll = loaded_dll())
  }
}
fit_control_object <- function() {
  control <- gllvmTMBcontrol(
    n_init = 1L, init_jitter = 0, se = TRUE, aghq = FALSE,
    warn_runaway = TRUE
  )
  control$.internal_continuation <- FALSE
  control
}
require_verdict <- function(verdict) {
  if (!is.list(verdict) || !identical(verdict$valid, TRUE)) {
    provenance_stop(if (is.list(verdict) && is.character(verdict$reason) &&
        length(verdict$reason) == 1L) verdict$reason else
      "malformed BFGS smoke-contract verdict")
  }
  invisible(verdict)
}
curvature_callback <- function(fit, expected_labels) {
  force(fit)
  force(expected_labels)
  function(theta, positional_ids) {
    unavailable <- function(reason, error = NA_character_, par.fixed = NULL,
                            cov.fixed = NULL, pdHess = NA) {
      list(
        available = FALSE, reason = reason, par.fixed = par.fixed,
        cov.fixed = cov.fixed, pdHess = as.logical(pdHess)[1L],
        positional_ids = positional_ids, error = as.character(error)[1L]
      )
    }
    report <- tryCatch(
      TMB::sdreport(
        fit$tmb_obj, par.fixed = unname(theta),
        getReportCovariance = FALSE
      ),
      error = function(e) e
    )
    if (inherits(report, "error")) {
      return(unavailable("sdreport_unavailable", conditionMessage(report)))
    }
    par_fixed <- report$par.fixed
    covariance <- report$cov.fixed
    pd_hess <- if (is.logical(report$pdHess) && length(report$pdHess) == 1L) {
      report$pdHess
    } else NA
    par_names <- names(par_fixed)
    par_ordered <- is.numeric(par_fixed) && length(par_fixed) == length(theta) &&
      (is.null(par_names) || identical(par_names, expected_labels) ||
        identical(par_names, positional_ids))
    shaped <- is.matrix(covariance) &&
      identical(dim(covariance), c(length(theta), length(theta)))
    axis_ok <- function(x) is.null(x) || identical(x, expected_labels) ||
      identical(x, positional_ids)
    if (!par_ordered || !shaped || !axis_ok(rownames(covariance)) ||
        !axis_ok(colnames(covariance))) {
      return(unavailable(
        "sdreport_positional_identity_failure", par.fixed = par_fixed,
        cov.fixed = covariance, pdHess = pd_hess
      ))
    }
    names(par_fixed) <- positional_ids
    dimnames(covariance) <- list(positional_ids, positional_ids)
    list(
      available = TRUE, reason = "sdreport_cov_fixed_available",
      par.fixed = par_fixed, cov.fixed = covariance, pdHess = pd_hess,
      positional_ids = positional_ids, error = NA_character_
    )
  }
}
provenance_stop <- function(message) {
  condition <- simpleError(message)
  class(condition) <- c("bfgs_provenance_error", class(condition))
  stop(condition)
}
select_initial_nlminb <- function(fit) {
  polish <- fit$isdm_polish_provenance
  warm <- fit$warm_restart_provenance
  history <- fit$restart_history
  start <- fit$start_provenance
  history_fields <- c(
    "restart", "start_label", "optimizer", "jitter_sd", "success", "selected"
  )
  history_ok <- is.data.frame(history) && nrow(history) == 1L &&
    all(history_fields %in% names(history)) &&
    identical(as.integer(history$restart), 1L) &&
    identical(as.character(history$start_label), "initial") &&
    identical(as.character(history$optimizer), "nlminb") &&
    isTRUE(is.finite(history$jitter_sd)) && history$jitter_sd == 0 &&
    identical(as.logical(history$success), TRUE) &&
    identical(as.logical(history$selected), TRUE)
  start_ok <- is.list(start) &&
    is.numeric(start$selected_restart) && length(start$selected_restart) == 1L &&
    identical(as.integer(start$selected_restart), 1L)
  continuation_ok <- is.list(warm) &&
    identical(warm$warm_restart_attempted, FALSE) &&
    identical(warm$warm_restart_accepted, FALSE) &&
    is.list(polish) && identical(polish$eligible, FALSE) &&
    identical(polish$attempted, FALSE) &&
    identical(polish$accepted, FALSE) &&
    identical(polish$candidate_method, "none") &&
    is.list(polish$candidate_attempts) &&
    !length(polish$candidate_attempts)
  raw <- if (is.list(polish)) polish$raw else NULL
  raw_ok <- is.list(polish) &&
    identical(polish$schema, "G2I_INTERNAL_ISDM_POLISH_V1") &&
    is.list(warm) && is.list(raw) &&
    is.numeric(raw$parameter_vector) && length(raw$parameter_vector) > 0L &&
    all(is.finite(raw$parameter_vector)) &&
    !is.null(names(raw$parameter_vector)) &&
    length(names(raw$parameter_vector)) == length(raw$parameter_vector) &&
    !anyNA(names(raw$parameter_vector)) && all(nzchar(names(raw$parameter_vector))) &&
    is.numeric(fit$tmb_obj$par) &&
    length(fit$tmb_obj$par) == length(raw$parameter_vector) &&
    identical(names(raw$parameter_vector), names(fit$tmb_obj$par)) &&
    is.integer(raw$convergence) && length(raw$convergence) == 1L &&
    identical(raw$convergence, 0L) &&
    is.numeric(raw$objective) && length(raw$objective) == 1L &&
    is.finite(raw$objective) && is.numeric(raw$gradient) &&
    length(raw$gradient) == length(raw$parameter_vector) &&
    all(is.finite(raw$gradient)) &&
    is.logical(raw$pd_hessian) && length(raw$pd_hessian) == 1L &&
    !is.na(raw$pd_hessian) && is.character(raw$boundary_flags)
  if (!history_ok || !start_ok || !continuation_ok || !raw_ok) {
    provenance_stop(
      "cannot prove one initial selected nlminb state from retained provenance"
    )
  }
  parameter_vector <- raw$parameter_vector
  replay_objective <- tryCatch(
    fit$tmb_obj$fn(unname(parameter_vector)), error = function(e) e
  )
  replay_gradient <- tryCatch(
    fit$tmb_obj$gr(unname(parameter_vector)), error = function(e) e
  )
  objective_tolerance <- 64 * .Machine$double.eps *
    max(1, abs(raw$objective))
  gradient_replay_relative_tolerance <- 1e-8
  gradient_replay_relative_error <- if (is.numeric(replay_gradient) &&
      length(replay_gradient) == length(raw$gradient) &&
      all(is.finite(replay_gradient))) {
    difference_norm <- sqrt(sum(
      (as.numeric(replay_gradient) - as.numeric(raw$gradient))^2
    ))
    difference_norm / max(
      sqrt(sum(as.numeric(replay_gradient)^2)),
      sqrt(sum(as.numeric(raw$gradient)^2)),
      sqrt(.Machine$double.eps)
    )
  } else {
    Inf
  }
  replay_ok <- is.numeric(replay_objective) &&
    length(replay_objective) == 1L && is.finite(replay_objective) &&
    abs(replay_objective - raw$objective) <= objective_tolerance &&
    is.numeric(replay_gradient) &&
    length(replay_gradient) == length(parameter_vector) &&
    all(is.finite(replay_gradient)) &&
    bfgs_smoke_gradient_order_ok(replay_gradient, parameter_vector) &&
    is.finite(gradient_replay_relative_error) &&
    gradient_replay_relative_error <= gradient_replay_relative_tolerance
  if (!replay_ok) {
    provenance_stop(
      "initial nlminb objective or exact gradient failed retained-state replay"
    )
  }
  list(
    selection_source = "fit$isdm_polish_provenance$raw",
    parameter_vector = parameter_vector,
    objective = as.numeric(replay_objective),
    gradient = stats::setNames(
      as.numeric(replay_gradient), names(parameter_vector)
    ),
    convergence = raw$convergence,
    pd_hessian = raw$pd_hessian,
    boundary_flags = raw$boundary_flags,
    objective_replay_error = abs(replay_objective - raw$objective),
    gradient_replay_relative_error = gradient_replay_relative_error,
    gradient_replay_relative_tolerance = gradient_replay_relative_tolerance,
    internal_continuation_disabled = continuation_ok,
    warm_restart_provenance = warm,
    isdm_polish_provenance = polish,
    restart_history = history,
    start_provenance = start
  )
}
expected_seed <- if (identical(paper, "paper1")) 86301L else 86302L
expected_dimensions <- if (identical(paper, "paper1")) {
  c(S = 3L, C = 360L, r = 3L, b = 1L, d = 1L)
} else {
  c(S = 6L, C = 360L, r = 3L, b = 1L, d = 1L)
}
time_lines <- c(
  paste0("# ", paper, " exact-gradient BFGS time estimate"),
  "Expected wall clock: 5-20 minutes.",
  "Hard elapsed-time limit: 1800 seconds."
)

root <- normalizePath(
  if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg),
  mustWork = FALSE
)
parent <- normalizePath(
  file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE
)
paper2_ledger_path <- file.path(
  parent, "BFGS_P2_S6_C360_R3_V4", "all-attempt-ledger.rds"
)
expected_root <- normalizePath(file.path(parent, source_gate), mustWork = FALSE)
if (!identical(root, expected_root)) {
  stop("private result root must equal the sealed source-gate root", call. = FALSE)
}
if (!identical(mode, "smoke") && !identical(campaign_sha, commit())) {
  stop("exact --campaign-sha is required", call. = FALSE)
}
if (identical(mode, "validate")) {
  z <- make()
  expected_rows <- if (identical(paper, "paper1")) 4320L else 8640L
  stopifnot(
    identical(z$fixture$truth$seed, expected_seed),
    nrow(z$fixture$rows) == expected_rows
  )
  cat(if (identical(paper, "paper1")) {
    "BFGS_P1_RUNNER_VALIDATION_PASS (no fit)\n"
  } else {
    "BFGS_P2_RUNNER_VALIDATION_PASS (no fit)\n"
  })
  quit(save = "no")
}
if (identical(mode, "preflight")) {
  if (dirty()) stop("preflight requires a clean estimator tree", call. = FALSE)
  if (file.exists(root)) stop("preflight root must not exist", call. = FALSE)
  if (!dir.exists(parent) && !dir.create(parent, recursive = TRUE, showWarnings = FALSE))
    stop("unable to create result parent", call. = FALSE)
  staging <- tempfile(paste0(".", source_gate, "-preflight-"), tmpdir = parent)
  if (!dir.create(staging)) stop("unable to create preflight staging root", call. = FALSE)
  on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE), add = TRUE)
  z <- make()
  fit_control <- fit_control_object()
  paper2_evidence <- NULL
  if (identical(paper, "paper1")) {
    paper2_evidence <- bfgs_smoke_validate_paper2_prerequisite(
      paper2_ledger_path, commit(), list(
        runner_md5 = hash_file(core_runner_file),
        core_runner_md5 = hash_file(core_runner_file),
        fixture_md5 = hash_file(file.path(base, "g2h-360cell-fixture.R")),
        design_md5 = hash_file(design_file),
        source_md5 = c(
          fit_multi = hash_file(file.path(pkg, "R", "fit-multi.R")),
          isdm_fit = hash_file(file.path(pkg, "R", "isdm-developer-fit.R")),
          tmb = hash_file(file.path(pkg, "src", "gllvmTMB.cpp")),
          bfgs_contract = hash_file(contract_file), dll = z$dll$md5
        ),
        dll_path = normalizePath(z$dll$path, mustWork = TRUE),
        control_md5 = hash_object(fit_control)
      )
    )
    if (!is.list(paper2_evidence) || !identical(paper2_evidence$valid, TRUE)) {
      stop(
        if (is.list(paper2_evidence)) paper2_evidence$reason else
          "Paper 2 terminal prerequisite is malformed",
        call. = FALSE
      )
    }
  }
  session_info <- sessionInfo()
  atomic_rds(z$fixture, file.path(staging, "fixture.rds"))
  if (!is.null(z$mesh)) atomic_rds(z$mesh, file.path(staging, "mesh.rds"))
  atomic_rds(session_info, file.path(staging, "session-info.rds"))
  atomic_lines(time_lines, file.path(staging, "time-estimate.md"))
  receipt <- list(
    schema = paste0(source_gate, "_PREFLIGHT_V1"), source_gate = source_gate,
    root = expected_root, commit = commit(), seed = expected_seed,
    dimensions = expected_dimensions, n_rows = nrow(z$fixture$rows),
    runner_md5 = hash_file(script), core_runner_md5 = hash_file(core_runner_file),
    fixture_md5 = hash_file(fixture_file), design_md5 = hash_file(design_file),
    source_md5 = c(
      fit_multi = hash_file(file.path(pkg, "R", "fit-multi.R")),
      isdm_fit = hash_file(file.path(pkg, "R", "isdm-developer-fit.R")),
      tmb = hash_file(file.path(pkg, "src", "gllvmTMB.cpp")),
      bfgs_contract = hash_file(contract_file), dll = z$dll$md5
    ),
    dll_path = normalizePath(z$dll$path, mustWork = TRUE),
    session_info_md5 = hash_file(file.path(staging, "session-info.rds")),
    time_estimate_md5 = hash_file(file.path(staging, "time-estimate.md")),
    control_md5 = hash_object(fit_control),
    paper2_terminal_status = if (is.null(paper2_evidence)) NA_character_ else
      paper2_evidence$ledger$status,
    paper2_terminal_md5 = if (is.null(paper2_evidence)) NA_character_ else
      paper2_evidence$md5
  )
  atomic_rds(receipt, file.path(staging, "root-receipt.rds"))
  preflight_paths <- c("fixture.rds", "root-receipt.rds", "session-info.rds",
    "time-estimate.md")
  if (!is.null(z$mesh)) preflight_paths <- c(preflight_paths, "mesh.rds")
  manifest(staging, preflight_paths)
  require_verdict(bfgs_smoke_validate_receipt(receipt, receipt))
  require_verdict(bfgs_smoke_validate_manifest(staging, preflight_paths))
  if (!file.rename(staging, root)) stop("atomic preflight root rename failed", call. = FALSE)
  reread_receipt <- tryCatch(readRDS(file.path(root, "root-receipt.rds")),
    error = function(e) NULL)
  require_verdict(bfgs_smoke_validate_receipt(reread_receipt, receipt))
  require_verdict(bfgs_smoke_validate_manifest(root, preflight_paths))
  cat(if (identical(paper, "paper1")) {
    "BFGS_P1_PREFLIGHT_PASS (no fit)\n"
  } else {
    "BFGS_P2_PREFLIGHT_PASS (no fit)\n"
  })
  quit(save = "no")
}

main <- function() {
  current_commit <- commit()
  if (!identical(campaign_sha, current_commit))
    provenance_stop("exact --campaign-sha is required")
  if (!dir.exists(root)) provenance_stop("smoke requires one untouched immutable preflight")
  initial_consumed <- bfgs_smoke_consumed_state(root)
  if (isTRUE(initial_consumed$consumed))
    provenance_stop("smoke root is already claimed or terminal")
  if (dirty()) provenance_stop("clean committed estimator tree required")
  preflight_paths <- c("fixture.rds", "root-receipt.rds", "session-info.rds",
    "time-estimate.md")
  if (identical(paper, "paper1")) preflight_paths <- c(preflight_paths, "mesh.rds")
  require_verdict(bfgs_smoke_validate_manifest(root, preflight_paths))
  receipt <- tryCatch(readRDS(file.path(root, "root-receipt.rds")),
    error = function(e) provenance_stop(conditionMessage(e)))
  z <- make()
  fit_control <- fit_control_object()
  paper2_evidence <- NULL
  if (identical(paper, "paper1")) {
    paper2_evidence <- bfgs_smoke_validate_paper2_prerequisite(
      paper2_ledger_path, current_commit, list(
        runner_md5 = hash_file(core_runner_file),
        core_runner_md5 = hash_file(core_runner_file),
        fixture_md5 = hash_file(file.path(base, "g2h-360cell-fixture.R")),
        design_md5 = hash_file(design_file),
        source_md5 = c(
          fit_multi = hash_file(file.path(pkg, "R", "fit-multi.R")),
          isdm_fit = hash_file(file.path(pkg, "R", "isdm-developer-fit.R")),
          tmb = hash_file(file.path(pkg, "src", "gllvmTMB.cpp")),
          bfgs_contract = hash_file(contract_file), dll = z$dll$md5
        ), dll_path = normalizePath(z$dll$path, mustWork = TRUE),
        control_md5 = hash_object(fit_control)
      )
    )
    require_verdict(paper2_evidence)
  }
  observed <- c(
    fit_multi = hash_file(file.path(pkg, "R", "fit-multi.R")),
    isdm_fit = hash_file(file.path(pkg, "R", "isdm-developer-fit.R")),
    tmb = hash_file(file.path(pkg, "src", "gllvmTMB.cpp")),
    bfgs_contract = hash_file(contract_file), dll = z$dll$md5
  )
  expected_receipt <- list(
    schema = paste0(source_gate, "_PREFLIGHT_V1"), source_gate = source_gate,
    root = expected_root, commit = current_commit, seed = expected_seed,
    dimensions = expected_dimensions, n_rows = nrow(z$fixture$rows),
    runner_md5 = hash_file(script), core_runner_md5 = hash_file(core_runner_file),
    fixture_md5 = hash_file(fixture_file), design_md5 = hash_file(design_file),
    source_md5 = observed, dll_path = normalizePath(z$dll$path, mustWork = TRUE),
    session_info_md5 = hash_file(file.path(root, "session-info.rds")),
    time_estimate_md5 = hash_file(file.path(root, "time-estimate.md")),
    control_md5 = hash_object(fit_control),
    paper2_terminal_status = if (is.null(paper2_evidence)) NA_character_ else
      paper2_evidence$ledger$status,
    paper2_terminal_md5 = if (is.null(paper2_evidence)) NA_character_ else
      paper2_evidence$md5
  )
  require_verdict(bfgs_smoke_validate_receipt(receipt, expected_receipt))
  fixture_ok <- identical(z$fixture, readRDS(file.path(root, "fixture.rds"))) &&
    (!identical(paper, "paper1") ||
      identical(z$mesh, readRDS(file.path(root, "mesh.rds"))))
  if (!fixture_ok) provenance_stop("preflight fixture or mesh drift")

  ledger_path <- file.path(root, "all-attempt-ledger.rds")
  marker_path <- file.path(root, "attempt-started.rds")
  entry_path <- file.path(root, "bfgs-entered.rds")
  claim_path <- file.path(root, ".attempt-started.claim")
  parent_pid <- as.integer(Sys.getpid())
  timestamp <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
  attempt_marker <- list(
    schema = paste0(source_gate, "_ATTEMPT_STARTED_V1"), source_gate = source_gate,
    root = expected_root, commit = current_commit,
    receipt_md5 = hash_file(file.path(root, "root-receipt.rds")),
    claim = ".attempt-started.claim",
    claimed_at = timestamp(), started_at = timestamp(), parent_pid = parent_pid
  )
  ledger <- list(
    schema = paste0(source_gate, "_ALL_ATTEMPT_V2"), status = "ATTEMPT_STARTED",
    reason = "attempt_started", terminal = FALSE, receipt = receipt,
    attempt_marker = attempt_marker, bfgs_entry = NULL, signature = NULL,
    raw = NULL, continuation_source = NULL, bfgs = NULL,
    fit_control = fit_control, control_md5 = hash_object(fit_control),
    covariance_hash = NA_character_, order_hash = NA_character_,
    checks = stats::setNames(as.list(rep(FALSE, 6L)), .bfgs_smoke_check_names),
    warnings = character(), error = NA_character_,
    timing = list(fit_elapsed_s = NA_real_), peak_rss_kb = NA_real_
  )
  warnings <- character()
  claimed <- FALSE
  sealed <- FALSE
  normalise_fallback <- function(error) {
    if (!file.exists(file.path(root, "fit.rds")))
      ledger$timing$fit_elapsed_s <<- NA_real_
    if (!file.exists(entry_path)) ledger$bfgs_entry <<- NULL
    entered <- !is.null(ledger$bfgs_entry)
    ledger$status <<- if (inherits(error, "bfgs_provenance_error"))
      "INVALID_PROVENANCE" else "BFGS_INFRASTRUCTURE_HOLD"
    ledger$reason <<- if (inherits(error, "bfgs_provenance_error"))
      "provenance_failure" else "runner_unwind"
    ledger$error <<- conditionMessage(error)
    ledger$bfgs <<- NULL
    ledger$covariance_hash <<- NA_character_
    if (!entered) {
      ledger$signature <<- NULL
      ledger$raw <<- NULL
      ledger$continuation_source <<- NULL
      ledger$order_hash <<- NA_character_
    }
    ledger$checks <<- list(
      provenance = identical(ledger$status, "BFGS_INFRASTRUCTURE_HOLD"),
      preflight = TRUE, attempt_claimed = TRUE,
      fit_available = !is.na(ledger$timing$fit_elapsed_s),
      bfgs_entered = entered, terminal_evidence = FALSE
    )
    ledger$terminal <<- TRUE
    invisible(ledger)
  }
  terminal_paths <- function() {
    paths <- c(preflight_paths, "attempt-started.rds", "all-attempt-ledger.rds")
    if (file.exists(file.path(root, "fit.rds"))) paths <- c(paths, "fit.rds")
    if (!is.null(ledger$bfgs_entry)) paths <- c(paths, "bfgs-entered.rds")
    paths
  }
  seal <- function() {
    if (!isTRUE(ledger$terminal))
      normalise_fallback(simpleError("runner ended before terminal record"))
    if (!is.null(ledger$bfgs)) {
      evidence <- bfgs_smoke_recompute_result(ledger$bfgs)
      if (!identical(evidence$valid, TRUE))
        normalise_fallback(simpleError(evidence$reason))
    }
    ledger$warnings <<- unique(warnings)
    ledger$peak_rss_kb <<- as.double(peak_rss_kb())
    in_memory <- bfgs_smoke_validate_terminal_ledger(
      ledger, source_gate, current_commit
    )
    if (!identical(in_memory$valid, TRUE)) {
      normalise_fallback(simpleError(in_memory$reason))
      ledger$warnings <<- unique(warnings)
      ledger$peak_rss_kb <<- as.double(peak_rss_kb())
      in_memory <- bfgs_smoke_validate_terminal_ledger(
        ledger, source_gate, current_commit
      )
      if (!identical(in_memory$valid, TRUE)) stop(in_memory$reason, call. = FALSE)
    }
    atomic_rds(ledger, ledger_path)
    manifest(root, terminal_paths())
    disk <- tryCatch(readRDS(ledger_path), error = function(e) NULL)
    verdict <- bfgs_smoke_validate_terminal_ledger(
      disk, source_gate, current_commit, root
    )
    if (!identical(verdict$valid, TRUE)) stop(verdict$reason, call. = FALSE)
    sealed <<- TRUE
    disk
  }
  on.exit({
    if (claimed && !sealed) {
      if (!file.exists(marker_path)) atomic_rds(attempt_marker, marker_path)
      seal()
    }
  }, add = TRUE)
  setTimeLimit(elapsed = 1800, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf, transient = FALSE), add = TRUE)
  if (!dir.create(claim_path, showWarnings = FALSE))
    provenance_stop("attempt claim already exists")
  claimed <- TRUE
  atomic_rds(attempt_marker, marker_path)

  tryCatch({
    started <- proc.time()[["elapsed"]]
    fit_args <- list(z$fixture$rows, z$fixture$X, z$fixture$B, d = 1L,
      control = fit_control, silent = TRUE, .internal_continuation = FALSE)
    if (identical(paper, "paper1")) {
      fit_args$mesh <- z$mesh
      fit_args$spatial <- TRUE
    }
    fit <- withCallingHandlers(do.call(.gll_isdm_fit, fit_args),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      })
    ledger$timing$fit_elapsed_s <- as.double(proc.time()[["elapsed"]] - started)
    atomic_rds(fit, file.path(root, "fit.rds"))
    selected_raw <- select_initial_nlminb(fit)
    par <- selected_raw$parameter_vector
    gradient <- selected_raw$gradient
    raw_objective <- selected_raw$objective
    labels <- names(par)
    ids <- paste0(labels, "[", seq_along(par), "]")
    provenance_hashes <- list(
      warm_restart_provenance = hash_object(selected_raw$warm_restart_provenance),
      isdm_polish_provenance = hash_object(selected_raw$isdm_polish_provenance),
      restart_history = hash_object(selected_raw$restart_history),
      start_provenance = hash_object(selected_raw$start_provenance),
      selection_source = hash_object(selected_raw$selection_source)
    )
    ledger$continuation_source <- c(selected_raw,
      list(provenance_hashes = provenance_hashes))
    signature <- list(
      objective = hash_object(list(fn = "tmb_obj$fn", value = raw_objective,
        dll = z$dll$md5)),
      gradient = hash_object(list(gr = "tmb_obj$gr", exact = TRUE, value = gradient)),
      parameter_order = hash_object(list(labels = labels, ids = ids)),
      map = hash_object(fit$tmb_map), data = hash_object(fit$tmb_data),
      random = hash_object(fit$random), bounds = "unconstrained_transformed_scale",
      scale = "package_internal_unconstrained", controls = hash_object(list(
        starting_fit = list(full_control = fit_control), method = "BFGS",
        control = list(maxit = 500L, reltol = 1e-12, trace = 0L, REPORT = 1L))),
      starts = hash_object(list(parameter_vector = par,
        selection_source = selected_raw$selection_source,
        provenance_hashes = provenance_hashes)),
      selection = "isdm_polish_provenance_raw_initial_nlminb",
      source_gate = source_gate
    )
    raw_state <- list(
      optimizer = "nlminb", convergence = selected_raw$convergence,
      pd_hessian = selected_raw$pd_hessian,
      boundary_flags = selected_raw$boundary_flags, is_isdm = TRUE,
      aghq = FALSE, ridge = FALSE,
      retry_enabled = !isTRUE(selected_raw$internal_continuation_disabled),
      profile_enabled = FALSE, source_gate = source_gate
    )
    ledger$signature <- signature
    ledger$raw <- list(parameter_vector = par, gradient = gradient,
      objective = raw_objective, raw_state = raw_state,
      selection_source = selected_raw$selection_source)
    ledger$order_hash <- hash_object(list(labels = labels, ids = ids))
    ledger$bfgs_entry <- list(
      schema = paste0(source_gate, "_BFGS_ENTERED_V1"), source_gate = source_gate,
      root = expected_root, commit = current_commit,
      attempt_marker_md5 = hash_file(marker_path), entered_at = timestamp(),
      parent_pid = parent_pid, parameter_order_hash = ledger$order_hash
    )
    atomic_rds(ledger$bfgs_entry, entry_path)
    ledger$bfgs <- .gllvmTMB_isdm_bfgs_exact_gradient_continuation(
      fit$tmb_obj, par, raw_objective, signature, raw_state,
      curvature_fn = curvature_callback(fit, labels)
    )
    evidence <- bfgs_smoke_recompute_result(ledger$bfgs)
    if (!identical(evidence$valid, TRUE)) stop(evidence$reason, call. = FALSE)
    ledger$status <- evidence$status
    ledger$reason <- evidence$result_reason
    ledger$signature <- ledger$bfgs$signature
    ledger$raw <- ledger$bfgs$raw
    ledger$order_hash <- evidence$order_hash
    ledger$covariance_hash <- evidence$covariance_hash
    ledger$error <- if (ledger$status %in% c("BFGS_INFRASTRUCTURE_HOLD",
      "BFGS_OPTIMIZER_ERROR", "BFGS_CURVATURE_UNAVAILABLE"))
      ledger$bfgs$reason else NA_character_
    ledger$checks <- stats::setNames(as.list(rep(TRUE, 6L)),
      .bfgs_smoke_check_names)
    ledger$terminal <- TRUE
  }, error = function(e) normalise_fallback(e))
  terminal <- seal()
  cat(terminal$status, "\n")
}
main()
