bfgs_signature_fixture <- function() {
  nms <- gllvmTMB:::.gllvmTMB_isdm_g3_signature_names
  ans <- as.list(stats::setNames(paste0("sealed-", nms), nms))
  ans$source_gate <- "BFGS_EXACT_GRADIENT_UNIT"
  ans
}

bfgs_raw_state_fixture <- function() {
  list(
    optimizer = "nlminb", convergence = 0L, pd_hessian = FALSE,
    boundary_flags = character(), is_isdm = TRUE, aghq = FALSE,
    ridge = FALSE, retry_enabled = FALSE, profile_enabled = FALSE,
    source_gate = "BFGS_EXACT_GRADIENT_UNIT"
  )
}

bfgs_curvature_record <- function(theta, positional_ids, covariance,
                                  available = TRUE, pd_hess = TRUE,
                                  reason = "available", error = NA_character_) {
  covariance <- as.matrix(covariance)
  dimnames(covariance) <- list(positional_ids, positional_ids)
  list(
    available = available, reason = reason,
    par.fixed = if (available) theta else NULL,
    cov.fixed = if (available) covariance else NULL,
    pdHess = if (available) pd_hess else NA,
    positional_ids = positional_ids, error = error
  )
}

bfgs_quadratic_fixture <- function() {
  hessian <- diag(c(2, 5, 9))
  gradient <- c(0.004, 0.002, 0.001)
  par <- drop(solve(hessian, gradient))
  names(par) <- c("beta", "theta", "theta")
  obj <- list(
    fn = function(theta) drop(crossprod(theta, hessian %*% theta) / 2),
    gr = function(theta) drop(hessian %*% theta)
  )
  list(
    obj = obj, par = par, gradient = gradient, hessian = hessian,
    covariance = solve(hessian), objective = obj$fn(par)
  )
}

bfgs_v2_receipt <- function(contract, root, control = list(n_init = 1L,
    .internal_continuation = FALSE), commit = strrep("a", 40L)) {
  hash <- function(letter) strrep(letter, 32L)
  list(
    schema = "BFGS_P2_S6_C360_R3_V4_PREFLIGHT_V1",
    source_gate = "BFGS_P2_S6_C360_R3_V4", root = normalizePath(root,
      mustWork = TRUE), commit = commit, seed = 86302L,
    dimensions = c(S = 6L, C = 360L, r = 3L, b = 1L, d = 1L),
    n_rows = 8640L, runner_md5 = hash("1"), core_runner_md5 = hash("2"),
    fixture_md5 = hash("3"), design_md5 = hash("4"),
    source_md5 = c(fit_multi = hash("5"), isdm_fit = hash("6"),
      tmb = hash("7"), bfgs_contract = hash("8"), dll = hash("0")),
    dll_path = "/sealed/gllvmTMB.so", session_info_md5 = hash("9"),
    time_estimate_md5 = hash("a"),
    control_md5 = contract$.bfgs_smoke_hash_object(control),
    paper2_terminal_status = NA_character_, paper2_terminal_md5 = NA_character_
  )
}

bfgs_v2_marker <- function(contract, receipt, md5 = NULL) {
  list(schema = paste0(receipt$source_gate, "_ATTEMPT_STARTED_V1"),
    source_gate = receipt$source_gate, root = receipt$root, commit = receipt$commit,
    receipt_md5 = if (is.null(md5)) contract$.bfgs_smoke_hash_object(receipt) else md5,
    claim = ".attempt-started.claim", claimed_at = "2026-08-14 00:00:00.000000",
    started_at = "2026-08-14 00:00:00.000001", parent_pid = 1L)
}

bfgs_v2_fallback_ledger <- function(contract, root, status = "INVALID_PROVENANCE",
    reason = "provenance_failure") {
  control <- list(n_init = 1L, .internal_continuation = FALSE)
  receipt <- bfgs_v2_receipt(contract, root, control)
  marker <- bfgs_v2_marker(contract, receipt)
  checks <- list(provenance = identical(status, "BFGS_INFRASTRUCTURE_HOLD"),
    preflight = TRUE, attempt_claimed = TRUE, fit_available = FALSE,
    bfgs_entered = FALSE, terminal_evidence = FALSE)
  list(schema = paste0(receipt$source_gate, "_ALL_ATTEMPT_V2"), status = status,
    reason = reason, terminal = TRUE, receipt = receipt, attempt_marker = marker,
    bfgs_entry = NULL, signature = NULL, raw = NULL, continuation_source = NULL,
    bfgs = NULL, fit_control = control,
    control_md5 = contract$.bfgs_smoke_hash_object(control),
    covariance_hash = NA_character_, order_hash = NA_character_, checks = checks,
    warnings = character(), error = "synthetic terminal fallback",
    timing = list(fit_elapsed_s = NA_real_), peak_rss_kb = NA_real_)
}

bfgs_v2_materialize <- function(contract, ledger, fit = NULL) {
  if (is.null(fit)) fit <- attr(ledger, "bfgs_fixture_fit", exact = TRUE)
  attr(ledger, "bfgs_fixture_fit") <- NULL
  root <- ledger$receipt$root
  saveRDS(ledger$receipt, file.path(root, "root-receipt.rds"), version = 3)
  ledger$attempt_marker$receipt_md5 <- unname(tools::md5sum(
    file.path(root, "root-receipt.rds")
  ))[[1L]]
  saveRDS(ledger$attempt_marker, file.path(root, "attempt-started.rds"), version = 3)
  if (!is.null(ledger$bfgs_entry)) {
    ledger$bfgs_entry$attempt_marker_md5 <- unname(tools::md5sum(
      file.path(root, "attempt-started.rds")
    ))[[1L]]
  }
  claim <- file.path(root, ".attempt-started.claim")
  if (!dir.exists(claim)) dir.create(claim)
  if (!file.exists(file.path(root, "fixture.rds")))
    saveRDS(list(fixture = TRUE), file.path(root, "fixture.rds"), version = 3)
  if (!file.exists(file.path(root, "session-info.rds")))
    saveRDS(list(session = TRUE), file.path(root, "session-info.rds"), version = 3)
  if (!file.exists(file.path(root, "time-estimate.md")))
    writeLines("Estimated wall clock: 5-20 minutes.", file.path(root, "time-estimate.md"))
  if (!is.null(fit)) saveRDS(fit, file.path(root, "fit.rds"), version = 3)
  if (!is.null(ledger$bfgs_entry)) {
    saveRDS(ledger$bfgs_entry, file.path(root, "bfgs-entered.rds"), version = 3)
  }
  saveRDS(ledger, file.path(root, "all-attempt-ledger.rds"), version = 3)
  paths <- sort(setdiff(list.files(root, all.files = TRUE, no.. = TRUE),
    c("file-manifest.csv", ".attempt-started.claim")))
  utils::write.csv(data.frame(path = paths,
    md5 = unname(tools::md5sum(file.path(root, paths))), stringsAsFactors = FALSE),
    file.path(root, "file-manifest.csv"), row.names = FALSE)
  ledger
}

bfgs_v2_normal_ledger <- function(contract, root, live = FALSE) {
  control <- list(n_init = 1L, .internal_continuation = FALSE)
  saveRDS(list(fixture = TRUE), file.path(root, "fixture.rds"), version = 3)
  saveRDS(list(session = TRUE), file.path(root, "session-info.rds"), version = 3)
  writeLines("Estimated wall clock: 5-20 minutes.", file.path(root, "time-estimate.md"))
  if (!isTRUE(live))
    writeLines("synthetic sealed DLL", file.path(root, "gllvmTMB.so"))
  receipt <- bfgs_v2_receipt(contract, root, control)
  if (isTRUE(live)) {
    pkg <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
    control <- gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0,
      se = TRUE, aghq = FALSE, warn_runaway = TRUE)
    control$.internal_continuation <- FALSE
    runner <- file.path(pkg, "dev", "isdm-package-recovery",
      "run-bfgs-paper2-smoke.R")
    paths <- c(runner = runner, core_runner = runner,
      fixture = file.path(pkg, "dev", "isdm-package-recovery",
        "g2h-360cell-fixture.R"),
      design = file.path(pkg, "dev", "isdm-package-recovery",
        "2026-08-14-bfgs-exact-gradient-continuation-design.md"),
      fit_multi = file.path(pkg, "R", "fit-multi.R"),
      isdm_fit = file.path(pkg, "R", "isdm-developer-fit.R"),
      tmb = file.path(pkg, "src", "gllvmTMB.cpp"),
      bfgs_contract = file.path(pkg, "dev", "isdm-package-recovery",
        "bfgs-smoke-contract.R"), dll = file.path(pkg, "src", "gllvmTMB.so"))
    md5 <- as.character(tools::md5sum(paths))
    names(md5) <- names(paths)
    receipt <- bfgs_v2_receipt(contract, root, control,
      commit = system2("git", c("-C", shQuote(pkg), "rev-parse", "HEAD"),
        stdout = TRUE)[[1L]])
    receipt$runner_md5 <- md5[["runner"]]
    receipt$core_runner_md5 <- md5[["core_runner"]]
    receipt$fixture_md5 <- md5[["fixture"]]
    receipt$design_md5 <- md5[["design"]]
    receipt$source_md5 <- c(fit_multi = md5[["fit_multi"]],
      isdm_fit = md5[["isdm_fit"]], tmb = md5[["tmb"]],
      bfgs_contract = md5[["bfgs_contract"]], dll = md5[["dll"]])
    receipt$dll_path <- normalizePath(paths[["dll"]], mustWork = TRUE)
  }
  if (!isTRUE(live)) {
    receipt$dll_path <- normalizePath(file.path(root, "gllvmTMB.so"), mustWork = TRUE)
    receipt$source_md5[["dll"]] <- unname(tools::md5sum(receipt$dll_path))[[1L]]
  }
  receipt$session_info_md5 <- unname(tools::md5sum(
    file.path(root, "session-info.rds")
  ))[[1L]]
  receipt$time_estimate_md5 <- unname(tools::md5sum(
    file.path(root, "time-estimate.md")
  ))[[1L]]
  x <- bfgs_quadratic_fixture()
  labels <- names(x$par)
  ids <- paste0(labels, "[", seq_along(labels), "]")
  raw_gradient <- stats::setNames(as.double(x$gradient), labels)
  polish_raw <- list(parameter_vector = x$par, objective = x$objective,
    gradient = raw_gradient)
  continuation <- list(
    selection_source = "fit$isdm_polish_provenance$raw",
    parameter_vector = x$par, objective = x$objective, gradient = raw_gradient,
    convergence = 0L, pd_hessian = FALSE, boundary_flags = character(),
    objective_replay_error = 0, gradient_replay_relative_error = 0,
    gradient_replay_relative_tolerance = 1e-8,
    internal_continuation_disabled = TRUE,
    warm_restart_provenance = list(attempted = FALSE),
    isdm_polish_provenance = list(raw = polish_raw),
    restart_history = data.frame(restart = 1L),
    start_provenance = list(source = "sealed"), provenance_hashes = NULL
  )
  continuation$provenance_hashes <- list(
    warm_restart_provenance = contract$.bfgs_smoke_hash_object(
      continuation$warm_restart_provenance),
    isdm_polish_provenance = contract$.bfgs_smoke_hash_object(
      continuation$isdm_polish_provenance),
    restart_history = contract$.bfgs_smoke_hash_object(continuation$restart_history),
    start_provenance = contract$.bfgs_smoke_hash_object(continuation$start_provenance),
    selection_source = contract$.bfgs_smoke_hash_object(continuation$selection_source)
  )
  fit <- list(warm_restart_provenance = continuation$warm_restart_provenance,
    isdm_polish_provenance = continuation$isdm_polish_provenance,
    restart_history = continuation$restart_history,
    start_provenance = continuation$start_provenance,
    tmb_map = list(sealed = "map"), tmb_data = list(sealed = "data"),
    random = c("sealed_random"))
  order_hash <- contract$.bfgs_smoke_hash_object(list(labels = labels, ids = ids))
  signature <- list(
    objective = contract$.bfgs_smoke_hash_object(list(fn = "tmb_obj$fn",
      value = x$objective, dll = receipt$source_md5[["dll"]])),
    gradient = contract$.bfgs_smoke_hash_object(list(gr = "tmb_obj$gr",
      exact = TRUE, value = raw_gradient)), parameter_order = order_hash,
    map = contract$.bfgs_smoke_hash_object(fit$tmb_map),
    data = contract$.bfgs_smoke_hash_object(fit$tmb_data),
    random = contract$.bfgs_smoke_hash_object(fit$random),
    bounds = "unconstrained_transformed_scale", scale = "package_internal_unconstrained",
    controls = contract$.bfgs_smoke_hash_object(list(
      starting_fit = list(full_control = control), method = "BFGS",
      control = list(maxit = 500L, reltol = 1e-12, trace = 0L, REPORT = 1L))),
    starts = contract$.bfgs_smoke_hash_object(list(parameter_vector = x$par,
      selection_source = continuation$selection_source,
      provenance_hashes = continuation$provenance_hashes)),
    selection = "isdm_polish_provenance_raw_initial_nlminb",
    source_gate = receipt$source_gate
  )
  raw_state <- bfgs_raw_state_fixture()
  raw_state$source_gate <- receipt$source_gate
  bfgs <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, x$par, x$objective, signature, raw_state,
    function(theta, positional_ids) bfgs_curvature_record(theta, positional_ids,
      x$covariance)
  )
  marker <- bfgs_v2_marker(contract, receipt, md5 = strrep("0", 32L))
  entry <- list(schema = paste0(receipt$source_gate, "_BFGS_ENTERED_V1"),
    source_gate = receipt$source_gate, root = receipt$root, commit = receipt$commit,
    attempt_marker_md5 = strrep("0", 32L),
    entered_at = "2026-08-14 00:00:01.000000", parent_pid = marker$parent_pid,
    parameter_order_hash = order_hash)
  list(
    schema = paste0(receipt$source_gate, "_ALL_ATTEMPT_V2"), status = bfgs$status,
    reason = bfgs$reason, terminal = TRUE, receipt = receipt,
    attempt_marker = marker, bfgs_entry = entry, signature = signature,
    raw = bfgs$raw,
    continuation_source = continuation, bfgs = bfgs, fit_control = control,
    control_md5 = contract$.bfgs_smoke_hash_object(control),
    covariance_hash = contract$.bfgs_smoke_hash_object(bfgs$curvature$covariance),
    order_hash = order_hash,
    checks = stats::setNames(as.list(rep(TRUE, 6L)), c(
      "provenance", "preflight", "attempt_claimed", "fit_available",
      "bfgs_entered", "terminal_evidence")),
    warnings = character(), error = NA_character_,
    timing = list(fit_elapsed_s = 1), peak_rss_kb = 1
  ) -> ledger
  attr(ledger, "bfgs_fixture_fit") <- fit
  ledger
}
