#!/usr/bin/env Rscript

## Private LA-MSPL constrained parametric-bootstrap test-inversion calibration.
## This runner is deliberately outside public inference dispatch.  It tests a
## predeclared constrained-null procedure and retains every failed key; it does
## not activate a confidence-interval method.

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x

script_path <- sub("^--file=", "", commandArgs()[grep("^--file=", commandArgs())][[1L]])
coverage_runner <- file.path(dirname(normalizePath(script_path)), "run-mspl-coverage-calibration.R")
old_source_only <- Sys.getenv("MSPL_COVERAGE_SOURCE_ONLY", unset = NA_character_)
Sys.setenv(MSPL_COVERAGE_SOURCE_ONLY = "true")
source(coverage_runner, local = .GlobalEnv)
if (is.na(old_source_only)) Sys.unsetenv("MSPL_COVERAGE_SOURCE_ONLY") else Sys.setenv(MSPL_COVERAGE_SOURCE_ONLY = old_source_only)
args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit)) return(default)
  if (hit == length(args)) stop("Missing value for ", name, call. = FALSE)
  args[[hit + 1L]]
}

atomic_write_rds <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(".mspl-constrained-inversion-", dirname(path), fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, compress = "gzip", version = 3L)
  if (!file.rename(tmp, path)) stop("Could not atomically publish ", path, call. = FALSE)
  invisible(path)
}

atomic_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(".mspl-constrained-inversion-", dirname(path), fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(x, tmp, row.names = FALSE, na = "")
  if (!file.rename(tmp, path)) stop("Could not atomically publish ", path, call. = FALSE)
  invisible(path)
}

inversion_settings <- function() {
  if (identical(Sys.getenv("MSPL_INVERSION_TEST_MODE"), "true")) {
    return(list(
      bootstrap_reps = 2L,
      alpha = 0.05,
      grid_offsets = c(-1, -0.5, 0, 0.5, 1),
      n_outer = 1L,
      outer_per_shard = 1L,
      availability_min = 0.95,
      coverage_wilson_level = 0.90,
      coverage_equivalence_lower = 0.92,
      coverage_equivalence_upper = 0.98
    ))
  }
  list(
    bootstrap_reps = 499L,
    alpha = 0.05,
    grid_offsets = c(-1, -0.5, 0, 0.5, 1),
    n_outer = 1000L,
    outer_per_shard = 1L,
    availability_min = 0.95,
    coverage_wilson_level = 0.90,
    coverage_equivalence_lower = 0.92,
    coverage_equivalence_upper = 0.98
  )
}

validate_inversion_settings <- function(settings = inversion_settings()) {
  production <- !identical(Sys.getenv("MSPL_INVERSION_TEST_MODE"), "true")
  if (!identical(settings$alpha, 0.05) ||
      !identical(settings$grid_offsets, c(-1, -0.5, 0, 0.5, 1)) ||
      !identical(settings$outer_per_shard, 1L) ||
      (production && (!identical(settings$bootstrap_reps, 499L) || !identical(settings$n_outer, 1000L))) ||
      (!production && (!identical(settings$bootstrap_reps, 2L) || !identical(settings$n_outer, 1L)))) {
    stop("The constrained-inversion calibration settings are frozen.", call. = FALSE)
  }
  invisible(TRUE)
}

inversion_manifest <- function(campaign_id, source_sha) {
  settings <- inversion_settings()
  out <- manifest_table(
    n_outer = settings$n_outer, bootstrap_reps = settings$bootstrap_reps,
    outer_per_shard = settings$outer_per_shard, campaign_id = campaign_id,
    source_sha = source_sha, clusters = production_cluster_assignment,
    availability_min = settings$availability_min,
    coverage_wilson_level = settings$coverage_wilson_level,
    coverage_equivalence_lower = settings$coverage_equivalence_lower,
    coverage_equivalence_upper = settings$coverage_equivalence_upper,
    wald_min_available = 1L
  )
  out$manifest_version <- if (identical(Sys.getenv("MSPL_INVERSION_TEST_MODE"), "true")) {
    "lane-b-mspl-constrained-inversion-test-v1-2026-08-15"
  } else {
    "lane-b-mspl-constrained-inversion-v1-2026-08-15"
  }
  out$minimum_usable_bootstrap <- settings$bootstrap_reps
  out
}

validate_inversion_manifest <- function(manifest) {
  settings <- inversion_settings()
  expected <- inversion_manifest(manifest$campaign_id[[1L]], manifest$source_sha[[1L]])
  fixed <- setdiff(names(expected), c("campaign_id", "source_sha"))
  if (nrow(manifest) != 12L || !identical(names(manifest), names(expected)) ||
      any(manifest$campaign_id != manifest$campaign_id[[1L]]) ||
      any(manifest$source_sha != manifest$source_sha[[1L]]) ||
      !identical(manifest[fixed], expected[fixed])) {
    stop("The constrained-inversion manifest is not the frozen 12-case contract.", call. = FALSE)
  }
  expected_refits <- settings$bootstrap_reps * length(settings$grid_offsets) * 3L *
    nrow(manifest) * settings$n_outer
  if ((!identical(Sys.getenv("MSPL_INVERSION_TEST_MODE"), "true") && expected_refits != 89820000L) ||
      (identical(Sys.getenv("MSPL_INVERSION_TEST_MODE"), "true") && expected_refits != 360L)) {
    stop("The constrained-inversion refit cardinality drifted.", call. = FALSE)
  }
  invisible(TRUE)
}

write_inversion_manifest <- function(root, manifest) {
  validate_inversion_manifest(manifest)
  dir.create(file.path(root, "shards"), recursive = TRUE, showWarnings = FALSE)
  atomic_write_csv(manifest, file.path(root, "manifest.csv"))
  array_map <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) data.frame(
    array_index = seq_len(manifest$n_shards[[i]]) + sum(manifest$n_shards[seq_len(i - 1L)]),
    case_id = manifest$case_id[[i]], shard_id = seq_len(manifest$n_shards[[i]]),
    stringsAsFactors = FALSE
  )))
  atomic_write_tsv(array_map, file.path(root, "array-map.tsv"))
  ## The pre-run is its own twelve-task scheduler array.  Its task IDs must
  ## remain compact (1:12): production task IDs span 1:12000 and exceed the
  ## MaxArraySize on some DRAC clusters.
  pre_run_map <- array_map[array_map$shard_id == 1L, , drop = FALSE]
  pre_run_map$array_index <- seq_len(nrow(pre_run_map))
  atomic_write_tsv(pre_run_map, file.path(root, "pre-run-array-map.tsv"))
  invisible(manifest)
}

inversion_seed <- function(case, outer_id, target, grid_id, replicate) {
  offset <- (as.integer(outer_id) - 1L) * 3L * 5L * 499L +
    (as.integer(target) - 1L) * 5L * 499L +
    (as.integer(grid_id) - 1L) * 499L + as.integer(replicate)
  seed <- 1900000000 + (as.integer(case$case_number[[1L]]) - 1L) * 10000000 + offset
  if (!is.finite(seed) || seed < 1 || seed > .Machine$integer.max) {
    stop("The frozen constrained-inversion seed map overflowed.", call. = FALSE)
  }
  as.integer(seed)
}

fit_status <- function(fit) {
  if (inherits(fit, "error")) return(list(status = "refit_error", message = conditionMessage(fit)))
  estimator_id <- tryCatch(as.integer(fit$tmb_obj$env$data$estimator_id), error = function(e) NA_integer_)
  if (!identical(estimator_id, 1L)) return(list(status = "objective_identity_failed", message = "active estimator_id is not 1"))
  if (!identical(as.integer(fit$opt$convergence), 0L)) {
    return(list(status = "refit_optimizer_failed", message = fit$opt$message %||% ""))
  }
  list(status = "ok", message = "")
}

run_null <- function(case, data, fit, target_index, target_value, outer_id, target, grid_id) {
  settings <- inversion_settings()
  state <- gllvmTMB:::.gllvmTMB_mspl_constrained_simulation_state(
    fit, which = target_index, target = target_value
  )
  endpoint <- data.frame(
    case_id = case$case_id[[1L]], outer_id = as.integer(outer_id), target = as.integer(target),
    grid_id = as.integer(grid_id), target_value = target_value,
    truth = case_truth(case)[[target]], constrained_status = state$status,
    constrained_message = state$message %||% "", estimator_id = state$estimator_id %||% NA_integer_,
    objective_source = state$objective_source %||% NA_character_, observed_statistic = NA_real_,
    usable_refits = 0L, p_value = NA_real_, test_status = "constrained_state_failed",
    stringsAsFactors = FALSE
  )
  if (!identical(state$status, "ok") || !identical(state$estimator_id, 1L) ||
      !identical(state$objective_source, "fit$tmb_obj (penalised LA-MSPL)")) {
    return(list(endpoint = endpoint, attempts = data.frame()))
  }
  observed <- abs(fit$opt$par[[target_index]] - target_value)
  attempts <- lapply(seq_len(settings$bootstrap_reps), function(replicate) {
    draw <- tryCatch(stats::simulate(state$simulation_fit, nsim = 1L,
      seed = inversion_seed(case, outer_id, target, grid_id, replicate), condition_on_RE = FALSE), error = identity)
    if (inherits(draw, "error")) {
      return(data.frame(replicate = replicate, status = "simulate_error", message = conditionMessage(draw),
        estimate = NA_real_, statistic = NA_real_))
    }
    refit_data <- data
    refit_data$y <- as.integer(draw[, 1L])
    refit <- tryCatch(fit_mspl(refit_data, case$link[[1L]]), error = identity)
    status <- fit_status(refit)
    estimate <- if (identical(status$status, "ok")) refit$opt$par[[target_index]] else NA_real_
    data.frame(replicate = replicate, status = status$status, message = status$message,
      estimate = estimate, statistic = if (is.finite(estimate)) abs(estimate - target_value) else NA_real_)
  })
  attempts <- do.call(rbind, attempts)
  attempts$case_id <- case$case_id[[1L]]
  attempts$outer_id <- as.integer(outer_id)
  attempts$target <- as.integer(target)
  attempts$grid_id <- as.integer(grid_id)
  usable <- attempts$status == "ok" & is.finite(attempts$statistic)
  endpoint$observed_statistic <- observed
  endpoint$usable_refits <- sum(usable)
  endpoint$test_status <- if (all(usable)) "ok" else "bootstrap_refit_failed"
  if (all(usable)) {
    endpoint$p_value <- (1 + sum(attempts$statistic >= observed)) / (settings$bootstrap_reps + 1)
  }
  list(endpoint = endpoint, attempts = attempts)
}

run_outer <- function(case, outer_id) {
  data <- simulate_outer_data(case, outer_id)
  fit <- tryCatch(fit_mspl(data, case$link[[1L]]), error = identity)
  status <- fit_status(fit)
  if (!identical(status$status, "ok")) {
    rows <- do.call(rbind, lapply(seq_len(3L), function(target) do.call(rbind,
      lapply(seq_len(5L), function(grid_id) data.frame(
        case_id = case$case_id[[1L]], outer_id = as.integer(outer_id), target = target,
        grid_id = grid_id, target_value = NA_real_, truth = case_truth(case)[[target]],
        constrained_status = status$status, constrained_message = status$message,
        estimator_id = NA_integer_, objective_source = NA_character_, observed_statistic = NA_real_,
        usable_refits = 0L, p_value = NA_real_, test_status = "outer_fit_failed"
      )))))
    return(list(endpoints = rows, attempts = data.frame()))
  }
  indices <- which(names(fit$opt$par) == "b_fix")
  results <- unlist(lapply(seq_len(3L), function(target) {
    truth <- case_truth(case)[[target]]
    lapply(seq_along(inversion_settings()$grid_offsets), function(grid_id) run_null(
      case, data, fit, indices[[target]], truth + inversion_settings()$grid_offsets[[grid_id]],
      outer_id, target, grid_id
    ))
  }), recursive = FALSE)
  list(
    endpoints = do.call(rbind, lapply(results, `[[`, "endpoint")),
    attempts = do.call(rbind, lapply(results, `[[`, "attempts"))
  )
}

run_shard <- function(case, shard_id, cluster) {
  if (!identical(cluster, case$assigned_cluster[[1L]])) stop("Cluster differs from frozen manifest assignment.", call. = FALSE)
  first <- (as.integer(shard_id) - 1L) * case$outer_per_shard[[1L]] + 1L
  last <- as.integer(shard_id) * case$outer_per_shard[[1L]]
  pieces <- lapply(first:last, function(outer_id) run_outer(case, outer_id))
  list(
    schema_version = "mspl-constrained-inversion-shard-v1",
    case_id = case$case_id[[1L]], shard_id = as.integer(shard_id), cluster = cluster,
    source_sha = case$source_sha[[1L]], campaign_id = case$campaign_id[[1L]],
    endpoints = do.call(rbind, lapply(pieces, `[[`, "endpoints")),
    attempts = do.call(rbind, lapply(pieces, `[[`, "attempts"))
  )
}

validate_prerun_shards <- function(root, manifest) {
  files <- sort(list.files(file.path(root, "shards"), pattern = "\\.rds$", full.names = TRUE))
  expected <- file.path(file.path(root, "shards"), sprintf("C%03d-shard-0001.rds", seq_len(12L)))
  if (!identical(files, expected)) stop("Pre-run requires exactly the 12 immutable shard-0001 files.", call. = FALSE)
  shards <- lapply(files, readRDS)
  required <- c("schema_version", "case_id", "shard_id", "cluster", "source_sha", "campaign_id", "endpoints", "attempts")
  if (any(!vapply(shards, function(x) is.list(x) && identical(x$schema_version,
      "mspl-constrained-inversion-shard-v1") && all(required %in% names(x)), logical(1L)))) {
    stop("A constrained-inversion pre-run shard has the wrong schema.", call. = FALSE)
  }
  case_id <- vapply(shards, `[[`, character(1L), "case_id")
  if (!identical(case_id, manifest$case_id) || any(vapply(shards, `[[`, integer(1L), "shard_id") != 1L) ||
      any(vapply(shards, `[[`, character(1L), "campaign_id") != manifest$campaign_id[[1L]]) ||
      any(vapply(shards, `[[`, character(1L), "source_sha") != manifest$source_sha[[1L]]) ||
      any(vapply(seq_along(shards), function(i) shards[[i]]$cluster != manifest$assigned_cluster[[i]], logical(1L)))) {
    stop("Pre-run shard provenance disagrees with the frozen manifest.", call. = FALSE)
  }
  endpoints <- do.call(rbind, lapply(shards, `[[`, "endpoints"))
  attempts <- do.call(rbind, lapply(shards, `[[`, "attempts"))
  settings <- inversion_settings()
  endpoint_key <- paste(endpoints$case_id, endpoints$outer_id, endpoints$target, endpoints$grid_id, sep = "\r")
  attempt_key <- paste(attempts$case_id, attempts$outer_id, attempts$target, attempts$grid_id, attempts$replicate, sep = "\r")
  if (nrow(endpoints) != 180L || nrow(attempts) != 89820L || anyDuplicated(endpoint_key) || anyDuplicated(attempt_key) ||
      !identical(sort(unique(endpoint_key)), sort(do.call(c, lapply(manifest$case_id, function(case_id)
        as.vector(outer(case_id, sprintf("1\r%d\r%d", rep(seq_len(3L), each = 5L), rep(seq_len(5L), 3L)), paste, sep = "\r"))))))) {
    stop("Pre-run endpoint or attempt keys do not match the frozen contract.", call. = FALSE)
  }
  per_endpoint <- table(paste(attempts$case_id, attempts$outer_id, attempts$target, attempts$grid_id, sep = "\r"))
  if (length(per_endpoint) != nrow(endpoints) || any(per_endpoint != settings$bootstrap_reps)) {
    stop("Each constrained null must retain exactly 499 bootstrap attempts.", call. = FALSE)
  }
  list(endpoints = endpoints, attempts = attempts)
}

aggregate_prerun <- function(root) {
  manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  validate_inversion_manifest(manifest)
  receipts <- validate_prerun_shards(root, manifest)
  endpoint_ok <- receipts$endpoints$test_status == "ok" & is.finite(receipts$endpoints$p_value) &
    receipts$endpoints$usable_refits == inversion_settings()$bootstrap_reps &
    receipts$endpoints$estimator_id == 1L &
    receipts$endpoints$objective_source == "fit$tmb_obj (penalised LA-MSPL)"
  summary <- data.frame(
    endpoint_rows = nrow(receipts$endpoints), attempt_rows = nrow(receipts$attempts),
    endpoint_tests_ok = sum(endpoint_ok), endpoint_tests_failed = sum(!endpoint_ok),
    bootstrap_attempts_ok = sum(receipts$attempts$status == "ok"),
    bootstrap_attempts_failed = sum(receipts$attempts$status != "ok"),
    calibration_gate_eligible = FALSE, public_fence = "unchanged", stringsAsFactors = FALSE
  )
  atomic_write_rds(list(manifest = manifest, endpoints = receipts$endpoints,
    attempts = receipts$attempts, summary = summary), file.path(root, "prerun-summary.rds"))
  atomic_write_lines(c(
    "receipt_type: mspl-constrained-inversion-prerun-v1",
    paste("campaign_id:", manifest$campaign_id[[1L]]),
    paste("source_sha:", manifest$source_sha[[1L]]),
    paste("endpoint_rows:", summary$endpoint_rows),
    paste("bootstrap_attempt_rows:", summary$attempt_rows),
    paste("endpoint_tests_ok:", summary$endpoint_tests_ok),
    paste("endpoint_tests_failed:", summary$endpoint_tests_failed),
    paste("bootstrap_attempts_ok:", summary$bootstrap_attempts_ok),
    paste("bootstrap_attempts_failed:", summary$bootstrap_attempts_failed),
    "calibration_gate_eligible: FALSE",
    "public_fence: unchanged"
  ), file.path(root, "prerun-receipt.txt"))
  invisible(summary)
}

run_cli <- function() {
  command <- if (length(args)) args[[1L]] else ""
  if (identical(command, "validate")) return(validate_inversion_settings())
  root <- arg_value("--root")
  if (!nzchar(root %||% "")) stop("Use --root <outside-repository-root>.", call. = FALSE)
  if (identical(command, "manifest")) {
    campaign_id <- arg_value("--campaign-id")
    source_sha <- arg_value("--source-sha")
    if (!nzchar(campaign_id %||% "") || !nzchar(source_sha %||% "")) stop("manifest requires --campaign-id and --source-sha.", call. = FALSE)
    return(write_inversion_manifest(root, inversion_manifest(campaign_id, source_sha)))
  }
  if (identical(command, "run-shard")) {
    if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) devtools::load_all(quiet = TRUE) else library(gllvmTMB)
    manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
    validate_inversion_manifest(manifest)
    case <- manifest[manifest$case_id == arg_value("--case-id"), , drop = FALSE]
    shard_id <- as.integer(arg_value("--shard-id"))
    cluster <- arg_value("--cluster", "local")
    if (nrow(case) != 1L || is.na(shard_id) || shard_id < 1L || shard_id > case$n_shards[[1L]]) stop("Unknown case or shard.", call. = FALSE)
    path <- file.path(root, "shards", sprintf("%s-shard-%04d.rds", case$case_id[[1L]], shard_id))
    if (!file.exists(path)) atomic_write_rds(run_shard(case, shard_id, cluster), path)
    return(invisible(path))
  }
  if (identical(command, "aggregate-prerun")) return(aggregate_prerun(root))
  stop("Use validate, manifest, run-shard, or aggregate-prerun.", call. = FALSE)
}

if (!identical(Sys.getenv("MSPL_CONSTRAINED_INVERSION_SOURCE_ONLY"), "true")) run_cli()
