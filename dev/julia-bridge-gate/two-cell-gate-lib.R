bridge_gate_spec <- function() {
  list(
    gllvmtmb_sha = "86e95fff170767b23980152b7d6fce9bb2207718",
    gllvmjl_sha = "00a2d7b7024b21f55cb124bee2d2e4cf8a546b40",
    gllvmtmb_tree = "4393be7730b306e310843c7621b4517cc3ad86fb",
    gllvmjl_tree = "8a243605516a0d660d703135acb0b1bd9a0e4f15",
    gllvmtmb_archive_sha256 = "03053140ff39ef0945c51577acd74a1cfd87e5733cf697c7f231fb420a67d594",
    gllvmjl_archive_sha256 = "515ae818a0c66b2dddda4306ade9643310e7531c504183e352ac598b8d1bd4b7",
    gllvmjl_project_sha256 = "bd85aa8977102a28872fa34b019dce1ad96e50171ad52907f2f34f37d06f0128",
    planned_ids = c(
      "gaussian-tmb", "gaussian-julia", "poisson-tmb", "poisson-julia"
    ),
    planned_n = 4L,
    stop_seconds = 30 * 60,
    threads = 1L,
    thresholds = list(
      gaussian = c(
        logLik_abs = 1e-4,
        covariance_relative_frobenius = 1e-5,
        correlation_max_abs = 1e-5,
        fitted_mean_max_relative = 1e-4
      ),
      poisson = c(
        logLik_abs = 1e-3,
        covariance_relative_frobenius = 1e-2,
        correlation_max_abs = 1e-2,
        fitted_mean_max_relative = 1e-2
      )
    )
  )
}

bridge_gate_fixtures <- function() {
  formula_text <- paste(
    "value ~ 0 + trait +",
    "latent(0 + trait | unit, d = 1, unique = FALSE)"
  )
  make_grid <- function() {
    out <- expand.grid(
      unit = factor(seq_len(40L)),
      trait = factor(c("t1", "t2", "t3")),
      KEEP.OUT.ATTRS = FALSE,
      stringsAsFactors = FALSE
    )
    out$trait <- factor(out$trait, levels = c("t1", "t2", "t3"))
    out
  }

  gaussian <- make_grid()
  set.seed(7L)
  gaussian$value <- stats::rnorm(nrow(gaussian))

  poisson <- make_grid()
  set.seed(202608281L)
  score <- stats::rnorm(40L)
  intercept <- c(t1 = 0.2, t2 = 0.4, t3 = 0.1)
  loading <- c(t1 = 0.5, t2 = -0.3, t3 = 0.25)
  eta <- intercept[as.character(poisson$trait)] +
    loading[as.character(poisson$trait)] * score[as.integer(poisson$unit)]
  poisson$value <- stats::rpois(nrow(poisson), lambda = exp(eta))

  list(
    gaussian = list(
      family = "gaussian", seed = 7L, rank = 1L, unique = FALSE,
      formula_text = formula_text, data = gaussian
    ),
    poisson = list(
      family = "poisson", seed = 202608281L, rank = 1L, unique = FALSE,
      formula_text = formula_text, data = poisson
    )
  )
}

bridge_gate_terminal_records <- function(code, reason) {
  spec <- bridge_gate_spec()
  parts <- strsplit(spec$planned_ids, "-", fixed = TRUE)
  data.frame(
    attempt_id = spec$planned_ids,
    family = vapply(parts, `[[`, character(1), 1L),
    engine = vapply(parts, `[[`, character(1), 2L),
    planned = TRUE,
    started = FALSE,
    status = "unavailable",
    terminal_code = rep(as.character(code), spec$planned_n),
    reason = rep(as.character(reason), spec$planned_n),
    stringsAsFactors = FALSE
  )
}

bridge_gate_assess_pair <- function(native, julia, family) {
  thresholds <- bridge_gate_spec()$thresholds[[family]]
  if (is.null(thresholds)) {
    stop("unsupported bridge-gate family: ", family, call. = FALSE)
  }
  required <- c("logLik", "Sigma", "R", "fitted_mean")
  if (!all(required %in% names(native)) || !all(required %in% names(julia))) {
    stop("both engine records must contain all invariant targets", call. = FALSE)
  }
  rel_frobenius <- function(x, y) {
    sqrt(sum((x - y)^2)) / max(sqrt(sum(x^2)), .Machine$double.eps)
  }
  max_relative <- function(x, y) {
    max(abs(x - y) / pmax(abs(x), .Machine$double.eps))
  }
  metrics <- c(
    logLik_abs = abs(native$logLik - julia$logLik),
    covariance_relative_frobenius = rel_frobenius(native$Sigma, julia$Sigma),
    correlation_max_abs = max(abs(native$R - julia$R)),
    fitted_mean_max_relative = max_relative(native$fitted_mean, julia$fitted_mean)
  )
  checks <- metrics <= thresholds[names(metrics)]
  list(metrics = metrics, thresholds = thresholds, checks = checks, passed = all(checks))
}

bridge_gate_write_manifest <- function(root, relative_paths) {
  root <- normalizePath(root, mustWork = TRUE)
  relative_paths <- sort(unique(as.character(relative_paths)))
  if (!length(relative_paths) || any(grepl("^/|(^|/)\\.\\.(/|$)", relative_paths))) {
    stop("manifest paths must be non-empty and relative to root", call. = FALSE)
  }
  absolute <- file.path(root, relative_paths)
  if (!all(file.exists(absolute))) {
    stop("cannot hash missing manifest members", call. = FALSE)
  }
  hashes <- vapply(absolute, function(path) {
    line <- system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE)
    if (length(line) != 1L || !grepl("^[0-9a-f]{64}", line)) {
      stop("shasum did not return one SHA-256 record for ", path, call. = FALSE)
    }
    substr(line, 1L, 64L)
  }, character(1))
  manifest <- file.path(root, "SHA256SUMS")
  writeLines(paste0(unname(hashes), "  ", relative_paths), manifest, useBytes = TRUE)
  manifest
}

bridge_gate_read_process_receipt <- function(path) {
  lines <- readLines(path, warn = FALSE)
  pos <- regexpr("=", lines, fixed = TRUE)
  if (!length(lines) || any(pos < 2L)) {
    stop("invalid qualification process receipt: ", path, call. = FALSE)
  }
  keys <- substr(lines, 1L, pos - 1L)
  values <- substring(lines, pos + 1L)
  if (anyDuplicated(keys)) stop("duplicate qualification receipt key", call. = FALSE)
  stats::setNames(as.list(values), keys)
}

bridge_gate_validate_process_receipts <- function(root, contract) {
  expected_versions <- c("1.12.6", "1.10.10")
  expected_paths <- c(
    "process/julia-1_12_6.receipt",
    "process/julia-1_10_10.receipt"
  )
  if (!identical(unname(contract$qualification_receipts), expected_paths) ||
      !identical(names(contract$qualification_receipts), expected_versions)) {
    stop("terminal contract does not bind both qualification receipts", call. = FALSE)
  }
  for (i in seq_along(expected_paths)) {
    path <- file.path(root, expected_paths[[i]])
    if (!file.exists(path)) stop("missing qualification process receipt", call. = FALSE)
    receipt <- bridge_gate_read_process_receipt(path)
    required <- c(
      "schema", "version", "julia_home", "julia_depot", "gllvm_path",
      "started_at", "finished_at", "direct_command", "direct_stdout",
      "direct_stderr", "direct_exit_status", "bridge_command",
      "bridge_stdout", "bridge_stderr", "bridge_exit_status", "fit_started"
    )
    if (!all(required %in% names(receipt)) ||
        !identical(receipt$schema, "bridge-source-qualification-v1") ||
        !identical(receipt$version, expected_versions[[i]]) ||
        !identical(receipt$direct_exit_status, "0") ||
        !identical(receipt$bridge_exit_status, "139") ||
        !identical(receipt$fit_started, "false")) {
      stop("qualification receipt does not prove direct eligibility and bridge exit 139", call. = FALSE)
    }
    logs <- unlist(receipt[c("direct_stdout", "direct_stderr", "bridge_stdout", "bridge_stderr")], use.names = FALSE)
    if (any(grepl("^/|(^|/)\\.\\.(/|$)", logs)) || !all(file.exists(file.path(root, logs)))) {
      stop("qualification receipt does not bind all stdout/stderr logs", call. = FALSE)
    }
    direct_text <- paste(readLines(file.path(root, receipt$direct_stdout), warn = FALSE), collapse = "\n")
    if (!grepl(paste0("JULIA_VERSION=", expected_versions[[i]]), direct_text, fixed = TRUE) ||
        !grepl("gaussian", direct_text, fixed = TRUE) ||
        !grepl("poisson", direct_text, fixed = TRUE)) {
      stop("direct GLLVM qualification log lacks frozen capabilities", call. = FALSE)
    }
  }
  TRUE
}

bridge_gate_validate_source_contract <- function(contract) {
  spec <- bridge_gate_spec()
  require_identical <- function(name, expected, label = name) {
    if (!identical(contract[[name]], expected)) {
      stop(label, " does not match the frozen source contract", call. = FALSE)
    }
  }
  if (!is.list(contract) || !contract$status %in% c("eligible", "terminal")) {
    stop("source status does not match the frozen source contract", call. = FALSE)
  }
  require_identical("gllvmtmb_sha", spec$gllvmtmb_sha, "gllvmTMB SHA")
  require_identical("gllvmtmb_tree", spec$gllvmtmb_tree, "gllvmTMB tree")
  require_identical("gllvmjl_sha", spec$gllvmjl_sha, "GLLVM.jl SHA")
  require_identical("gllvmjl_tree", spec$gllvmjl_tree, "GLLVM.jl tree")
  require_identical(
    "gllvmtmb_archive_sha256", spec$gllvmtmb_archive_sha256,
    "gllvmTMB archive SHA-256"
  )
  require_identical(
    "gllvmjl_archive_sha256", spec$gllvmjl_archive_sha256,
    "GLLVM.jl archive SHA-256"
  )
  require_identical(
    "project_sha256", spec$gllvmjl_project_sha256,
    "GLLVM.jl Project SHA-256"
  )
  hash_fields <- c("resolved_manifest_sha256", "installed_dll_sha256")
  valid_hash <- function(x) {
    is.character(x) && length(x) == 1L && grepl("^[0-9a-f]{64}$", x)
  }
  if (!all(vapply(contract[hash_fields], valid_hash, logical(1)))) {
    stop("source contract contains an invalid SHA-256 identity", call. = FALSE)
  }
  require_identical(
    "manifest_status",
    "absent_in_source_generated_at_runtime",
    "Manifest status"
  )
  if (identical(contract$status, "terminal")) {
    require_identical("terminal_code", "NO_RUN_SOURCE_CONTRACT", "terminal code")
    require_identical("fit_started", FALSE, "terminal fit-start status")
    require_identical(
      "capability_status",
      "eligible_static_runtime_embedding_failed",
      "terminal capability status"
    )
    require_identical(
      "julia_embedding_exit",
      c(`1.12.6` = 139L, `1.10.10` = 139L),
      "Julia embedding exit statuses"
    )
    receipt_hashes <- contract$qualification_receipt_sha256
    if (!is.character(receipt_hashes) ||
        !identical(names(receipt_hashes), c("1.12.6", "1.10.10")) ||
        !all(vapply(as.list(receipt_hashes), valid_hash, logical(1)))) {
      stop("terminal contract contains invalid qualification receipt hashes", call. = FALSE)
    }
    require_identical(
      "runtime_manifest_files",
      c(
        `1.12.6` = "GLLVM-Manifest-julia-1.12.6.toml",
        `1.10.10` = "GLLVM-Manifest-julia-1.10.10.toml"
      ),
      "runtime Manifest files"
    )
    runtime_hashes <- contract$runtime_manifest_sha256
    if (!is.character(runtime_hashes) ||
        !identical(names(runtime_hashes), c("1.12.6", "1.10.10")) ||
        !all(vapply(as.list(runtime_hashes), valid_hash, logical(1)))) {
      stop("terminal contract contains invalid runtime Manifest hashes", call. = FALSE)
    }
    if (!is.character(contract$reason) || length(contract$reason) != 1L || !nzchar(contract$reason)) {
      stop("terminal source contract needs a non-empty reason", call. = FALSE)
    }
    return("terminal")
  }
  require_identical("capability_status", "eligible_static_and_runtime", "capability status")
  "eligible"
}

bridge_gate_validate_denominator <- function(records) {
  spec <- bridge_gate_spec()
  if (!is.data.frame(records) || nrow(records) != spec$planned_n) {
    stop("all-attempt ledger must contain exactly four records", call. = FALSE)
  }
  required <- c("attempt_id", "planned", "started", "status")
  if (!all(required %in% names(records))) {
    stop("all-attempt ledger is missing required fields", call. = FALSE)
  }
  if (!identical(as.character(records$attempt_id), spec$planned_ids)) {
    stop("all-attempt ledger does not contain the frozen planned attempt IDs", call. = FALSE)
  }
  if (anyDuplicated(records$attempt_id) || !all(records$planned)) {
    stop("replacement or unplanned attempts are forbidden", call. = FALSE)
  }
  allowed <- c("passed", "failed", "unavailable", "interrupted", "not_started_after_abort")
  if (anyNA(records$status) || !all(records$status %in% allowed)) {
    stop("every planned attempt needs one admitted final status", call. = FALSE)
  }
  TRUE
}

bridge_gate_validate_verdict <- function(verdict) {
  required <- c("outcome", "fit_started", "thresholds_frozen", "replacement_attempts")
  if (!is.list(verdict) || !all(required %in% names(verdict))) {
    stop("verdict is missing required fields", call. = FALSE)
  }
  if (!isTRUE(verdict$thresholds_frozen) || !identical(verdict$replacement_attempts, 0L)) {
    stop("threshold retuning and replacement attempts are forbidden", call. = FALSE)
  }
  terminal <- c("NO_RUN_SOURCE_CONTRACT", "STOP_30_MINUTES")
  if (verdict$outcome %in% terminal) {
    if (isTRUE(verdict$fit_started) && identical(verdict$outcome, "NO_RUN_SOURCE_CONTRACT")) {
      stop("source-contract termination must occur before fitting", call. = FALSE)
    }
    return("terminal")
  }
  if (!verdict$outcome %in% c("BRIDGE_GATE_PASS", "BRIDGE_GATE_FAIL")) {
    stop("unknown bridge-gate outcome", call. = FALSE)
  }
  if (!isTRUE(verdict$fit_started) ||
      !identical(verdict$families, c("gaussian", "poisson"))) {
    stop("paired verdict must cover both frozen families", call. = FALSE)
  }
  if (!isTRUE(verdict$invariant_only)) {
    stop("paired verdict must use rotation-invariant targets only", call. = FALSE)
  }
  "paired"
}

bridge_gate_execute_plan <- function(
  artifact_root,
  fit_one,
  clock = Sys.time,
  stop_seconds = bridge_gate_spec()$stop_seconds
) {
  if (!is.function(fit_one) || !is.function(clock)) {
    stop("fit_one and clock must be functions", call. = FALSE)
  }
  dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
  started_dir <- file.path(artifact_root, "started")
  attempts_dir <- file.path(artifact_root, "attempts")
  dir.create(started_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(attempts_dir, recursive = TRUE, showWarnings = FALSE)

  spec <- bridge_gate_spec()
  fixtures <- bridge_gate_fixtures()
  parts <- strsplit(spec$planned_ids, "-", fixed = TRUE)
  records <- data.frame(
    attempt_id = spec$planned_ids,
    family = vapply(parts, `[[`, character(1), 1L),
    engine = vapply(parts, `[[`, character(1), 2L),
    planned = TRUE,
    started = FALSE,
    status = "not_started_after_abort",
    terminal_code = NA_character_,
    reason = NA_character_,
    runtime_seconds = NA_real_,
    stringsAsFactors = FALSE
  )
  run_started_at <- clock()
  timed_out <- FALSE

  for (i in seq_len(nrow(records))) {
    if (timed_out || as.numeric(difftime(clock(), run_started_at, units = "secs")) > stop_seconds) {
      timed_out <- TRUE
      records$terminal_code[i] <- "STOP_30_MINUTES"
      records$reason[i] <- "hard stop reached before this planned attempt started"
      saveRDS(
        list(record = records[i, , drop = FALSE], result = NULL),
        file.path(attempts_dir, paste0(records$attempt_id[i], ".rds"))
      )
      next
    }

    records$started[i] <- TRUE
    attempt_started_at <- clock()
    started_record <- list(
      attempt_id = records$attempt_id[i],
      family = records$family[i],
      engine = records$engine[i],
      started_at = format(attempt_started_at, tz = "UTC", usetz = TRUE)
    )
    saveRDS(
      started_record,
      file.path(started_dir, paste0(records$attempt_id[i], ".rds"))
    )

    result <- tryCatch(
      fit_one(records$attempt_id[i], fixtures[[records$family[i]]]),
      error = function(e) structure(list(message = conditionMessage(e)), class = "bridge_gate_error")
    )
    finished_at <- clock()
    records$runtime_seconds[i] <- as.numeric(difftime(
      finished_at, attempt_started_at, units = "secs"
    ))
    if (inherits(result, "bridge_gate_error")) {
      records$status[i] <- "failed"
      records$reason[i] <- result$message
      retained_result <- NULL
    } else {
      records$status[i] <- "passed"
      retained_result <- result
    }
    saveRDS(
      list(record = records[i, , drop = FALSE], result = retained_result),
      file.path(attempts_dir, paste0(records$attempt_id[i], ".rds"))
    )
  }

  utils::write.csv(records, file.path(artifact_root, "records.csv"), row.names = FALSE)
  bridge_gate_validate_denominator(records)
  records
}

bridge_gate_align_fitted <- function(fitted_value, fixture_data) {
  key <- paste(as.character(fixture_data$trait), as.character(fixture_data$unit), sep = "\r")
  if (is.data.frame(fitted_value)) {
    required <- c("trait", "unit", "est")
    if (!all(required %in% names(fitted_value))) {
      stop("long fitted values must contain trait, unit, and est", call. = FALSE)
    }
    source_key <- paste(
      as.character(fitted_value$trait), as.character(fitted_value$unit), sep = "\r"
    )
    idx <- match(key, source_key)
    if (anyNA(idx) || anyDuplicated(source_key)) {
      stop("long fitted values do not map one-to-one to fixture cells", call. = FALSE)
    }
    return(as.numeric(fitted_value$est[idx]))
  }
  fitted_value <- as.matrix(fitted_value)
  trait_names <- rownames(fitted_value)
  unit_names <- colnames(fitted_value)
  if (is.null(trait_names) || is.null(unit_names)) {
    stop("matrix fitted values need trait and unit dimnames", call. = FALSE)
  }
  idx_trait <- match(as.character(fixture_data$trait), trait_names)
  idx_unit <- match(as.character(fixture_data$unit), unit_names)
  if (anyNA(idx_trait) || anyNA(idx_unit)) {
    stop("matrix fitted values do not cover every fixture cell", call. = FALSE)
  }
  as.numeric(fitted_value[cbind(idx_trait, idx_unit)])
}

bridge_gate_extract_targets <- function(fit, fixture, engine, api) {
  required <- c("logLik", "extract_sigma", "fitted", "convergence")
  if (!is.list(api) || !all(vapply(api[required], is.function, logical(1)))) {
    stop("target extraction API is incomplete", call. = FALSE)
  }
  sigma <- api$extract_sigma(fit)
  out <- list(
    logLik = as.numeric(api$logLik(fit)),
    Sigma = as.matrix(sigma$Sigma),
    R = as.matrix(sigma$R),
    fitted_mean = bridge_gate_align_fitted(api$fitted(fit), fixture$data),
    converged = isTRUE(api$convergence(fit, engine))
  )
  finite_targets <- out[c("logLik", "Sigma", "R", "fitted_mean")]
  if (!all(vapply(finite_targets, function(x) length(x) > 0L && all(is.finite(x)), logical(1)))) {
    stop("fit returned a non-finite invariant target", call. = FALSE)
  }
  out
}

bridge_gate_verify_manifest <- function(root) {
  manifest <- file.path(root, "SHA256SUMS")
  lines <- readLines(manifest, warn = FALSE)
  if (!length(lines) || any(!grepl("^[0-9a-f]{64}  [^/].*$", lines))) {
    stop("invalid SHA256SUMS format", call. = FALSE)
  }
  expected <- substr(lines, 1L, 64L)
  relative <- substring(lines, 67L)
  if (anyDuplicated(relative) || any(grepl("(^|/)\\.\\.(/|$)", relative))) {
    stop("invalid or duplicate manifest member", call. = FALSE)
  }
  actual <- vapply(file.path(root, relative), function(path) {
    if (!file.exists(path)) stop("missing manifest member: ", path, call. = FALSE)
    substr(system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE), 1L, 64L)
  }, character(1))
  if (!identical(unname(actual), expected)) {
    stop("SHA256SUMS verification failed", call. = FALSE)
  }
  TRUE
}

bridge_gate_verify_artifacts <- function(root, check) {
  check <- match.arg(check, c("source", "denominator", "verdict", "manifest", "reviews", "closeout", "scope"))
  if (check == "source") {
    contract <- readRDS(file.path(root, "source-contract.rds"))
    bridge_gate_validate_source_contract(contract)
    if (identical(contract$status, "terminal")) {
      bridge_gate_validate_process_receipts(root, contract)
      actual <- vapply(file.path(root, unname(contract$qualification_receipts)), function(path) {
        substr(system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE), 1L, 64L)
      }, character(1))
      if (!identical(unname(actual), unname(contract$qualification_receipt_sha256))) {
        stop("qualification receipt SHA-256 mismatch", call. = FALSE)
      }
      manifests <- file.path(root, unname(contract$runtime_manifest_files))
      if (!all(file.exists(manifests))) stop("one or more bound runtime Manifests are missing", call. = FALSE)
      actual_manifests <- vapply(manifests, function(path) {
        substr(system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE), 1L, 64L)
      }, character(1))
      if (!identical(unname(actual_manifests), unname(contract$runtime_manifest_sha256))) {
        stop("runtime Manifest SHA-256 mismatch", call. = FALSE)
      }
    }
    return("G2_SOURCE_CONTRACT_OK")
  }
  if (check == "denominator") {
    records <- utils::read.csv(file.path(root, "records.csv"), stringsAsFactors = FALSE)
    bridge_gate_validate_denominator(records)
    attempt_paths <- file.path(root, "attempts", paste0(records$attempt_id, ".rds"))
    if (!all(file.exists(attempt_paths))) stop("one or more retained attempt records are missing", call. = FALSE)
    return("G3_DENOMINATOR_OK")
  }
  if (check == "verdict") {
    bridge_gate_validate_verdict(readRDS(file.path(root, "verdict.rds")))
    return("G4_VERDICT_OK")
  }
  if (check == "manifest") {
    bridge_gate_verify_manifest(root)
    return("G5_MANIFEST_OK")
  }
  repo_root <- normalizePath(file.path(root, "..", "..", "..", "..", ".."), mustWork = TRUE)
  if (check == "reviews") {
    review_paths <- file.path(root, "reviews", c("method.md", "scope.md", "provenance.md"))
    if (!all(file.exists(review_paths))) stop("one or more independent reviews are missing", call. = FALSE)
    review_text <- vapply(review_paths, function(path) paste(readLines(path, warn = FALSE), collapse = "\n"), character(1))
    if (!all(grepl("PASS", review_text, fixed = TRUE))) stop("every independent review must issue an explicit PASS", call. = FALSE)
    return("G6_INDEPENDENT_REVIEWS_OK")
  }
  if (check == "closeout") {
    required <- c(
      file.path(repo_root, "docs/dev-log/after-task/2026-08-28-engine-julia-two-cell-gate.md"),
      file.path(repo_root, "docs/dev-log/plan-actual/2026-08-28-engine-julia-two-cell-gate.md")
    )
    if (!all(file.exists(required))) stop("after-task or plan-actual closeout is missing", call. = FALSE)
    after <- paste(readLines(required[[1L]], warn = FALSE), collapse = "\n")
    headings <- c(
      "## 1. Goal", "## 3. Mathematical Contract", "## 5. Checks Run",
      "## 6. Tests of the Tests", "## 8. Consistency Audit",
      "## 7a. Issue Ledger", "## 10. Known Residuals",
      "## 12. Cross-Product Coverage"
    )
    if (!all(vapply(headings, function(x) grepl(x, after, fixed = TRUE), logical(1)))) {
      stop("after-task report is missing required closeout sections", call. = FALSE)
    }
    return("G7_CLOSEOUT_OK")
  }
  allowed <- c(
    "LOOP/", "dev/julia-bridge-gate/", "tests/testthat/test-julia-bridge-two-cell-gate.R",
    "docs/dev-log/artifacts/julia-bridge/two-cell-gate/",
    "docs/dev-log/after-task/2026-08-28-engine-julia-two-cell-gate.md",
    "docs/dev-log/plan-actual/2026-08-28-engine-julia-two-cell-gate.md",
    "docs/dev-log/check-log.md"
  )
  changed <- system2("git", c("-C", shQuote(repo_root), "diff", "--name-only", "origin/main"), stdout = TRUE)
  admitted <- vapply(changed, function(path) any(startsWith(path, allowed)), logical(1))
  if (length(changed) && !all(admitted)) {
    stop("scope contains an unowned changed path: ", paste(changed[!admitted], collapse = ", "), call. = FALSE)
  }
  "G8_SCOPE_BOUNDARY_OK"
}
