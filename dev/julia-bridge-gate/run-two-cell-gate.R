#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("usage: run-two-cell-gate.R ARTIFACT_ROOT", call. = FALSE)
}
artifact_root <- normalizePath(args[[1L]], mustWork = FALSE)
dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
source(file.path(dirname(script_path), "two-cell-gate-lib.R"), local = TRUE)

Sys.setenv(
  OPENBLAS_NUM_THREADS = "1",
  OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  JULIA_NUM_THREADS = "1"
)

write_terminal <- function(code, reason) {
  records <- bridge_gate_terminal_records(code, reason)
  dir.create(file.path(artifact_root, "attempts"), recursive = TRUE, showWarnings = FALSE)
  for (i in seq_len(nrow(records))) {
    saveRDS(
      list(record = records[i, , drop = FALSE], result = NULL),
      file.path(artifact_root, "attempts", paste0(records$attempt_id[i], ".rds"))
    )
  }
  utils::write.csv(records, file.path(artifact_root, "records.csv"), row.names = FALSE)
  saveRDS(list(
    outcome = code,
    fit_started = FALSE,
    thresholds_frozen = TRUE,
    replacement_attempts = 0L,
    reason = reason
  ), file.path(artifact_root, "verdict.rds"))
  records
}

contract_path <- file.path(artifact_root, "source-contract.rds")
contract_error <- tryCatch({
  if (!file.exists(contract_path)) stop("source-contract.rds is missing", call. = FALSE)
  bridge_gate_validate_source_contract(readRDS(contract_path))
  NULL
}, error = function(e) conditionMessage(e))
if (!is.null(contract_error)) {
  write_terminal("NO_RUN_SOURCE_CONTRACT", contract_error)
  quit(status = 2L)
}

fit_api <- list(
  logLik = stats::logLik,
  extract_sigma = function(fit) suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "none"
  )),
  fitted = function(fit) suppressMessages(stats::fitted(fit, type = "response")),
  convergence = function(fit, engine) {
    if (identical(engine, "tmb")) {
      identical(as.integer(fit$opt$convergence), 0L)
    } else {
      isTRUE(fit$converged)
    }
  }
)

fit_one <- function(attempt_id, fixture) {
  engine <- sub("^.*-", "", attempt_id)
  family <- switch(
    fixture$family,
    gaussian = stats::gaussian(),
    poisson = stats::poisson(),
    stop("unsupported frozen family", call. = FALSE)
  )
  fit_started <- Sys.time()
  fit <- gllvmTMB::gllvmTMB(
    stats::as.formula(fixture$formula_text),
    data = fixture$data,
    trait = "trait",
    unit = "unit",
    family = family,
    engine = engine
  )
  targets <- bridge_gate_extract_targets(fit, fixture, engine, fit_api)
  targets$attempt_id <- attempt_id
  targets$family <- fixture$family
  targets$engine <- engine
  targets$fit_started_at <- format(fit_started, tz = "UTC", usetz = TRUE)
  targets$fit_finished_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  targets$termination <- if (isTRUE(targets$converged)) "converged" else "not_converged"
  targets
}

records <- bridge_gate_execute_plan(artifact_root, fit_one)
attempt_results <- setNames(lapply(records$attempt_id, function(id) {
  readRDS(file.path(artifact_root, "attempts", paste0(id, ".rds")))$result
}), records$attempt_id)

all_completed <- all(records$status == "passed")
all_converged <- all_completed && all(vapply(attempt_results, function(x) isTRUE(x$converged), logical(1)))
pair_results <- NULL
if (all_converged) {
  pair_results <- lapply(c("gaussian", "poisson"), function(family) {
    bridge_gate_assess_pair(
      attempt_results[[paste0(family, "-tmb")]],
      attempt_results[[paste0(family, "-julia")]],
      family
    )
  })
  names(pair_results) <- c("gaussian", "poisson")
}
timed_out <- any(records$terminal_code == "STOP_30_MINUTES", na.rm = TRUE)
outcome <- if (timed_out) {
  "STOP_30_MINUTES"
} else if (all_converged && all(vapply(pair_results, `[[`, logical(1), "passed"))) {
  "BRIDGE_GATE_PASS"
} else {
  "BRIDGE_GATE_FAIL"
}
verdict <- list(
  outcome = outcome,
  fit_started = any(records$started),
  thresholds_frozen = TRUE,
  replacement_attempts = 0L,
  families = c("gaussian", "poisson"),
  invariant_only = TRUE,
  pair_results = pair_results,
  all_converged = all_converged,
  records = records
)
saveRDS(verdict, file.path(artifact_root, "verdict.rds"))
dput(verdict, file = file.path(artifact_root, "verdict.txt"))

members <- list.files(artifact_root, recursive = TRUE, all.files = FALSE)
members <- setdiff(members, "SHA256SUMS")
bridge_gate_write_manifest(artifact_root, members)
cat(outcome, "\n", sep = "")
