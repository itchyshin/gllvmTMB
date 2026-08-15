spde_slope_gauge_tr_smoke_contract_env <- function() {
  env <- new.env(parent = baseenv())
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-contract.R"
  ), local = env)
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-trust-region-contract.R"
  ), local = env)
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-trust-region-adapter.R"
  ), local = env)
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-trust-region-smoke-contract.R"
  ), local = env)
  env
}

spde_slope_gauge_tr_smoke_ledger <- function(contract, status = "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION") {
  checks <- if (identical(status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")) {
    c(predecessor = TRUE, infrastructure = TRUE, numerical = TRUE, terminal_evidence = FALSE)
  } else {
    c(predecessor = TRUE, infrastructure = FALSE, numerical = FALSE, terminal_evidence = FALSE)
  }
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ALL_ATTEMPT_V1",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1",
    root = "/sealed/root",
    commit = paste(rep("a", 40L), collapse = ""),
    terminal = TRUE,
    receipt = list(schema = "receipt"),
    marker = list(schema = "marker"),
    worker = if (identical(status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")) list(schema = "worker") else NULL,
    v3_live_child = NULL,
    processes = list(v3_live = NULL, worker = NULL),
    predecessor = list(schema = "predecessor"),
    controls = list(schema = "controls"),
    trust_region = if (identical(status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")) list(schema = "result") else NULL,
    checks = checks,
    status = status,
    reason = if (identical(status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION"))
      "selected_candidate_passed_all_gates" else "worker_callback_unavailable",
    error = if (identical(status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")) NA_character_ else "mock error",
    timing = list(total_s = 1)
  )
}

spde_slope_gauge_tr_smoke_callbacks <- function(contract) {
  raw_order <- contract$spde_slope_gauge_raw_order()
  phi_order <- contract$spde_slope_gauge_phi_order()
  theta <- stats::setNames(seq(-0.8, 0.8, length.out = 22L), raw_order)
  theta[20:22] <- c(0.2, -0.1, 0.3)
  phi0 <- contract$spde_slope_gauge_phi_from_theta(theta)
  target <- phi0
  target[1:3] <- target[1:3] + c(0.025, -0.02, 0.01)
  evaluate <- function(phi) {
    phi <- stats::setNames(as.double(phi), phi_order)
    gradient <- phi - target
    raw_gradient <- stats::setNames(
      drop(solve(t(contract$spde_slope_gauge_full_jacobian(phi)), gradient)), raw_order
    )
    list(
      objective = as.double(0.5 * sum((phi - target)^2)),
      raw_theta = contract$spde_slope_gauge_theta_from_phi(phi),
      raw_gradient = raw_gradient
    )
  }
  covariance <- function(raw_theta) {
    covariance <- diag(22L)
    dimnames(covariance) <- list(raw_order, raw_order)
    list(par.fixed = raw_theta, cov.fixed = covariance, pdHess = TRUE)
  }
  list(phi0 = phi0, evaluate = evaluate, covariance = covariance)
}

spde_slope_gauge_tr_smoke_process <- function() {
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PROCESS_V1",
    command = "/usr/bin/Rscript",
    arguments = c("--vanilla", "runner.R", "child", "child-result.rds", "101"),
    parent_pid = 101L,
    child_pid = 102L,
    started_at = "2026-08-15 12:00:00 UTC",
    ended_at = "2026-08-15 12:00:01 UTC",
    elapsed_s = 1,
    deadline_s = 1800L,
    timed_out = FALSE,
    exit_status = 0L,
    signal = NA_character_,
    stdout_md5 = NA_character_,
    stderr_md5 = NA_character_,
    child_result_md5 = "0123456789abcdef0123456789abcdef"
  )
}

spde_slope_gauge_tr_smoke_predecessor_packet <- function(contract) {
  root <- tempfile("spde-slope-gauge-tr-predecessor-")
  dir.create(root)
  root <- normalizePath(root, mustWork = TRUE)
  files <- c(
    "all-attempt-ledger.rds", "attempt-started.rds", "file-manifest.csv",
    "root-receipt.rds", "session-info.rds", "time-estimate.md", "v2-materialized-state.rds"
  )
  order <- contract$spde_slope_gauge_raw_order()
  state <- list(
    schema = "MSPDE_P1_S3_C360_R3_V3_MATERIALIZED_V2_STATE_V1",
    objective = 1.0,
    theta = stats::setNames(seq(-0.8, 0.8, length.out = 22L), order),
    gradient = stats::setNames(rep(0, 22L), order),
    convergence = 0L,
    covariance = list(),
    start_provenance = list(),
    restart_history = data.frame(),
    warm_restart_provenance = list(),
    isdm_polish_provenance = list(),
    parameters = list(),
    map = list(),
    data = list(),
    random = c("s_B", "g_spde_slope"),
    block_labels = order,
    parameter_order = order
  )
  receipt <- list(
    schema = "MSPDE_P1_S3_C360_R3_V3_CLOSEOUT_PREFLIGHT_V1",
    source_gate = "fixture", root = root,
    commit = paste(rep("a", 40L), collapse = ""), consumed_v2 = list(),
    runner_md5 = paste(rep("1", 32L), collapse = ""),
    contract_md5 = paste(rep("2", 32L), collapse = ""),
    design_md5 = paste(rep("3", 32L), collapse = "")
  )
  saveRDS(list(), file.path(root, "all-attempt-ledger.rds"))
  saveRDS(list(), file.path(root, "attempt-started.rds"))
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  saveRDS(list(), file.path(root, "session-info.rds"))
  saveRDS(state, file.path(root, "v2-materialized-state.rds"))
  writeLines("fixture", file.path(root, "time-estimate.md"))
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(data.frame(
    path = declared,
    md5 = unname(tools::md5sum(file.path(root, declared))),
    stringsAsFactors = FALSE
  ), file.path(root, "file-manifest.csv"), row.names = FALSE, quote = TRUE)
  dir.create(file.path(root, ".attempt-started.claim"))
  locked <- list(
    root = root,
    commit = receipt$commit,
    files = tools::md5sum(file.path(root, files)),
    directory = ".attempt-started.claim",
    receipt_schema = receipt$schema,
    state_schema = state$schema
  )
  names(locked$files) <- files
  list(root = root, locked = locked, state = state)
}

spde_slope_gauge_tr_smoke_worker <- function(result, predecessor = list(root = "/sealed/v3")) {
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_CHILD_V1",
    parent_pid = 101L,
    child_pid = 102L,
    started_at = "2026-08-15 12:00:00 UTC",
    ended_at = "2026-08-15 12:00:01 UTC",
    elapsed_s = 1,
    predecessor = predecessor,
    state_md5 = "0123456789abcdef0123456789abcdef",
    dll = list(path = "/sealed/gllvmTMB.so", md5 = "fedcba9876543210fedcba9876543210"),
    object = list(created = 1L, released = 1L),
    nofit = list(valid = TRUE),
    sign_orbit = list(valid = TRUE),
    trust_region = result,
    audit = list(),
    status = result$status,
    reason = result$reason,
    stage = "complete",
    completed_stage = "complete",
    error = NA_character_
  )
}

test_that("normal terminal and indexed fallback projections have exact retained slots", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  normal <- spde_slope_gauge_tr_smoke_ledger(contract)
  fallback_input <- normal
  fallback_input$status <- "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"
  fallback_input$reason <- "worker_callback_unavailable"
  fallback_input$error <- "mock error"
  fallback_input$checks <- c(predecessor = TRUE, infrastructure = FALSE, numerical = FALSE, terminal_evidence = FALSE)
  fallback_input["worker"] <- list(NULL)
  fallback_input["trust_region"] <- list(NULL)
  fallback <- contract$spde_slope_gauge_trust_region_normalise_fallback(
    fallback_input, "worker_callback_unavailable", "mock error"
  )

  expect_true(contract$spde_slope_gauge_trust_region_validate_terminal_ledger(normal)$valid)
  expect_true(contract$spde_slope_gauge_trust_region_validate_terminal_ledger(fallback)$valid)
  expect_identical(names(fallback), contract$spde_slope_gauge_trust_region_terminal_fields())
  expect_null(fallback$worker)
  expect_null(fallback$trust_region)
  expect_identical(fallback$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")
})

test_that("process receipts bind the exact command, arguments, and parent-child pair", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  process <- spde_slope_gauge_tr_smoke_process()
  arguments <- c("--vanilla", "runner.R", "child", "child-result.rds", "101")
  expect_true(contract$spde_slope_gauge_trust_region_validate_process_receipt(
    process, "/usr/bin/Rscript", arguments, 101L, 102L
  ))
  process$arguments[[5L]] <- "999"
  expect_false(contract$spde_slope_gauge_trust_region_validate_process_receipt(
    process, "/usr/bin/Rscript", arguments, 101L, 102L
  ))
  process <- spde_slope_gauge_tr_smoke_process()
  process$timed_out <- TRUE
  expect_false(contract$spde_slope_gauge_trust_region_validate_process_receipt(
    process, "/usr/bin/Rscript", arguments, 101L, 102L
  ))
})

test_that("the disposable V3 live-child receipt binds the exact predecessor and DLL", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  dll <- tempfile("spde-slope-gauge-tr-dll-")
  writeLines("fixture DLL", dll)
  on.exit(unlink(dll), add = TRUE)
  expected_dll <- list(
    path = normalizePath(dll, mustWork = TRUE),
    md5 = unname(tools::md5sum(dll))[[1L]]
  )
  predecessor <- list(root = "/sealed/v3", commit = paste(rep("a", 40L), collapse = ""))
  child <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_V3_LIVE_CHILD_V1",
    parent_pid = 101L,
    child_pid = 102L,
    started_at = "2026-08-15 12:00:00 UTC",
    ended_at = "2026-08-15 12:00:01 UTC",
    elapsed_s = 1,
    status = "GAUGE_TRUST_REGION_V3_LIVE_VALID",
    reason = "closeout_recomputed",
    predecessor = predecessor,
    dll = expected_dll,
    error = NA_character_
  )
  expect_true(contract$spde_slope_gauge_trust_region_v3_live_child_ok(
    child, predecessor, expected_dll
  ))
  child$predecessor$commit <- paste(rep("b", 40L), collapse = "")
  expect_false(contract$spde_slope_gauge_trust_region_v3_live_child_ok(
    child, predecessor, expected_dll
  ))
})

test_that("component deletion cannot impersonate a typed fallback", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  fallback <- spde_slope_gauge_tr_smoke_ledger(
    contract, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"
  )
  fallback$worker <- NULL
  fallback$trust_region <- NULL
  fallback$trust_region <- NULL

  verdict <- contract$spde_slope_gauge_trust_region_validate_terminal_ledger(fallback)
  expect_false(verdict$valid)
  expect_identical(verdict$reason, "terminal_ledger_schema_invalid")
})

test_that("the terminal commit is one exact hexadecimal SHA-1", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  ledger <- spde_slope_gauge_tr_smoke_ledger(contract)
  ledger$commit <- "not-a-commit"
  verdict <- contract$spde_slope_gauge_trust_region_validate_terminal_ledger(ledger)

  expect_false(verdict$valid)
  expect_identical(verdict$reason, "terminal_ledger_schema_invalid")
})

test_that("normal terminal evidence must reproduce the embedded trust-region result", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  callbacks <- spde_slope_gauge_tr_smoke_callbacks(contract)
  result <- contract$spde_slope_gauge_trust_region(
    callbacks$phi0, callbacks$evaluate, callbacks$covariance
  )
  ledger <- spde_slope_gauge_tr_smoke_ledger(contract)
  ledger$trust_region <- result
  ledger$worker <- spde_slope_gauge_tr_smoke_worker(result, ledger$predecessor)
  tampered <- ledger
  tampered$trust_region$selected$evaluation$raw_gradient[[1L]] <-
    tampered$trust_region$selected$evaluation$raw_gradient[[1L]] + 1e-4

  accepted <- contract$spde_slope_gauge_trust_region_validate_terminal_evidence(
    ledger, callbacks$phi0, callbacks$evaluate, callbacks$covariance
  )
  rejected <- contract$spde_slope_gauge_trust_region_validate_terminal_evidence(
    tampered, callbacks$phi0, callbacks$evaluate, callbacks$covariance
  )
  expect_true(accepted$valid)
  expect_identical(accepted$reason, "terminal_numerical_admission_recomputed")
  expect_false(rejected$valid)
  expect_identical(rejected$reason, "terminal_evidence_recomputation_failed")
})

test_that("a complete no-candidate trace seals as a recomputed numerical non-admission", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  callbacks <- spde_slope_gauge_tr_smoke_callbacks(contract)
  no_candidate_covariance <- function(raw_theta) {
    covariance <- diag(22L)
    dimnames(covariance) <- list(
      contract$spde_slope_gauge_raw_order(), contract$spde_slope_gauge_raw_order()
    )
    list(par.fixed = raw_theta, cov.fixed = covariance, pdHess = FALSE)
  }
  result <- contract$spde_slope_gauge_trust_region(
    callbacks$phi0, callbacks$evaluate, no_candidate_covariance
  )
  ledger <- spde_slope_gauge_tr_smoke_ledger(contract)
  ledger["trust_region"] <- list(result)
  ledger["checks"] <- list(c(
    predecessor = TRUE, infrastructure = TRUE, numerical = FALSE, terminal_evidence = FALSE
  ))
  ledger["status"] <- list("GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE")
  ledger["reason"] <- list(result$reason)
  ledger["worker"] <- list(spde_slope_gauge_tr_smoke_worker(result, ledger$predecessor))

  verdict <- contract$spde_slope_gauge_trust_region_validate_terminal_evidence(
    ledger, callbacks$phi0, callbacks$evaluate, no_candidate_covariance
  )
  expect_identical(result$status, "GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE")
  expect_true(verdict$valid)
  expect_identical(verdict$reason, "terminal_nonadmission_recomputed")
})

test_that("worker receipts retain only the evidence completed at their declared stage", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  callbacks <- spde_slope_gauge_tr_smoke_callbacks(contract)
  result <- contract$spde_slope_gauge_trust_region(
    callbacks$phi0, callbacks$evaluate, callbacks$covariance
  )
  predecessor <- list(root = "/sealed/v3")
  complete <- spde_slope_gauge_tr_smoke_worker(result, predecessor)
  expect_true(contract$spde_slope_gauge_trust_region_worker_ok(complete, predecessor))

  release_failure <- complete
  release_failure$status <- "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"
  release_failure$reason <- "object_release_failure"
  release_failure$stage <- "release"
  release_failure$completed_stage <- "audit"
  release_failure$error <- "release failed"
  release_failure$object$released <- 0L
  expect_true(contract$spde_slope_gauge_trust_region_worker_ok(release_failure, predecessor))

  sign_failure <- complete
  sign_failure$status <- "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"
  sign_failure$reason <- "sign_orbit_invariance_failed"
  sign_failure$stage <- "sign"
  sign_failure$completed_stage <- "no_fit"
  sign_failure$error <- "sign orbit failed"
  sign_failure$sign_orbit <- list(valid = FALSE)
  sign_failure["trust_region"] <- list(NULL)
  sign_failure["audit"] <- list(NULL)
  expect_true(contract$spde_slope_gauge_trust_region_worker_ok(sign_failure, predecessor))

  forged_predecessor <- release_failure
  forged_predecessor$predecessor <- NULL
  expect_false(contract$spde_slope_gauge_trust_region_worker_ok(forged_predecessor, predecessor))
  forged_count <- complete
  forged_count$object$released <- 0L
  expect_false(contract$spde_slope_gauge_trust_region_worker_ok(forged_count, predecessor))

  callback_failure <- complete
  callback_failure$status <- "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"
  callback_failure$reason <- "callback_or_trust_region_failure"
  callback_failure$stage <- "trust_region"
  callback_failure$completed_stage <- "callback_adapter"
  callback_failure$error <- "callback failed"
  callback_failure["trust_region"] <- list(NULL)
  callback_failure["audit"] <- list(NULL)
  expect_true(contract$spde_slope_gauge_trust_region_worker_ok(callback_failure, predecessor))

  forged_prefix <- callback_failure
  forged_prefix$completed_stage <- "audit"
  expect_false(contract$spde_slope_gauge_trust_region_worker_ok(forged_prefix, predecessor))
})

test_that("terminal evidence replays the retained callback audit without constructing an object", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  raw_order <- contract$spde_slope_gauge_raw_order()
  theta <- stats::setNames(seq(-0.8, 0.8, length.out = 22L), raw_order)
  theta[20:22] <- c(0.2, -0.1, 0.3)
  object <- list(
    par = theta,
    fn = function(x) as.double(sum(x * x)),
    gr = function(x) unname(2 * x)
  )
  adapter <- contract$spde_slope_gauge_trust_region_callback_adapter(
    object, 1L, "/sealed/gllvmTMB.so", "7797c4674e4758fca2da27151e5c2508",
    function(object, raw_theta) {
      covariance <- diag(22L)
      dimnames(covariance) <- list(raw_order, raw_order)
      list(par.fixed = raw_theta, cov.fixed = covariance, pdHess = TRUE)
    }
  )
  phi0 <- contract$spde_slope_gauge_phi_from_theta(theta)
  result <- contract$spde_slope_gauge_trust_region(phi0, adapter$evaluate, adapter$covariance)
  predecessor <- list(root = "/sealed/v3")
  worker <- spde_slope_gauge_tr_smoke_worker(result, predecessor)
  worker$dll <- list(path = "/sealed/gllvmTMB.so", md5 = "7797c4674e4758fca2da27151e5c2508")
  worker$audit <- adapter$audit()
  ledger <- spde_slope_gauge_tr_smoke_ledger(contract, result$status)
  ledger$worker <- worker
  ledger$predecessor <- predecessor
  ledger$trust_region <- result
  ledger$status <- result$status
  ledger$reason <- result$reason
  ledger$error <- NA_character_
  ledger$checks <- stats::setNames(
    c(TRUE, !identical(result$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"),
      identical(result$status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION"), FALSE),
    contract$spde_slope_gauge_trust_region_checks()
  )

  verdict <- contract$spde_slope_gauge_trust_region_validate_terminal_evidence(ledger)
  expect_true(verdict$valid)
  expect_match(verdict$reason, "recomputed$")

  ledger$worker$audit$gradient[[1L]]$raw_values[[1L]] <-
    ledger$worker$audit$gradient[[1L]]$raw_values[[1L]] + 1e-4
  tampered <- contract$spde_slope_gauge_trust_region_validate_terminal_evidence(ledger)
  expect_false(tampered$valid)

  evidence_hold <- ledger
  evidence_hold$status <- contract$spde_slope_gauge_trust_region_terminal_evidence_hold()
  evidence_hold$reason <- "terminal_evidence_inconsistent"
  evidence_hold$error <- "retained callback audit differs from the result"
  evidence_hold$checks <- c(
    predecessor = TRUE, infrastructure = FALSE, numerical = FALSE, terminal_evidence = FALSE
  )
  held <- contract$spde_slope_gauge_trust_region_validate_terminal_evidence(evidence_hold)
  expect_true(held$valid)
  expect_identical(held$reason, "terminal_evidence_hold_valid")

  relabelled <- spde_slope_gauge_tr_smoke_ledger(contract, result$status)
  relabelled$worker <- worker
  relabelled$predecessor <- predecessor
  relabelled$trust_region <- result
  relabelled$status <- contract$spde_slope_gauge_trust_region_terminal_evidence_hold()
  relabelled$reason <- "terminal_evidence_inconsistent"
  relabelled$error <- "forged evidence hold"
  relabelled$checks <- c(
    predecessor = TRUE, infrastructure = FALSE, numerical = FALSE, terminal_evidence = FALSE
  )
  rejected_relabel <- contract$spde_slope_gauge_trust_region_validate_terminal_evidence(relabelled)
  expect_false(rejected_relabel$valid)
  expect_identical(rejected_relabel$reason, "terminal_evidence_hold_not_forced_by_evidence")

  nested <- evidence_hold
  nested$worker$status <- contract$spde_slope_gauge_trust_region_terminal_evidence_hold()
  nested_verdict <- contract$spde_slope_gauge_trust_region_validate_terminal_evidence(nested)
  expect_false(nested_verdict$valid)
  expect_identical(nested_verdict$reason, "terminal_evidence_hold_nested")
})

test_that("manifest validation rejects extra files and a nonempty claim directory", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  root <- tempfile("spde-slope-gauge-tr-smoke-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  files <- c("control.rds", "root-receipt.rds", "file-manifest.csv")
  saveRDS(list(control = TRUE), file.path(root, "control.rds"))
  saveRDS(list(receipt = TRUE), file.path(root, "root-receipt.rds"))
  dir.create(file.path(root, ".attempt-started.claim"))
  manifest <- data.frame(
    path = files[-3L],
    md5 = unname(tools::md5sum(file.path(root, files[-3L]))),
    stringsAsFactors = FALSE
  )
  utils::write.csv(manifest, file.path(root, "file-manifest.csv"), row.names = FALSE)

  expect_true(contract$spde_slope_gauge_trust_region_manifest_ok(
    root, files, ".attempt-started.claim"
  ))
  writeLines("extra", file.path(root, "extra.txt"))
  expect_false(contract$spde_slope_gauge_trust_region_manifest_ok(
    root, files, ".attempt-started.claim"
  ))
  unlink(file.path(root, "extra.txt"))
  writeLines("nested", file.path(root, ".attempt-started.claim", "nested.txt"))
  expect_false(contract$spde_slope_gauge_trust_region_manifest_ok(
    root, files, ".attempt-started.claim"
  ))
})

test_that("the complete predecessor packet is byte- and state-schema-bound", {
  contract <- spde_slope_gauge_tr_smoke_contract_env()
  fixture <- spde_slope_gauge_tr_smoke_predecessor_packet(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)

  accepted <- contract$spde_slope_gauge_trust_region_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )
  expect_true(accepted$valid)
  expect_identical(accepted$reason, "predecessor_bytes_valid")

  state <- fixture$state
  names(state$theta) <- rev(names(state$theta))
  saveRDS(state, file.path(fixture$root, "v2-materialized-state.rds"))
  declared <- setdiff(names(fixture$locked$files), "file-manifest.csv")
  fixture$locked$files[["v2-materialized-state.rds"]] <-
    unname(tools::md5sum(file.path(fixture$root, "v2-materialized-state.rds")))[[1L]]
  utils::write.csv(data.frame(
    path = declared,
    md5 = unname(fixture$locked$files[declared]),
    stringsAsFactors = FALSE
  ), file.path(fixture$root, "file-manifest.csv"), row.names = FALSE, quote = TRUE)
  fixture$locked$files[["file-manifest.csv"]] <-
    unname(tools::md5sum(file.path(fixture$root, "file-manifest.csv")))[[1L]]
  state_tamper <- contract$spde_slope_gauge_trust_region_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )
  expect_false(state_tamper$valid)
  expect_identical(state_tamper$reason, "predecessor_receipt_or_state_invalid")

  writeLines("nested", file.path(fixture$root, ".attempt-started.claim", "nested.txt"))
  claim_tamper <- contract$spde_slope_gauge_trust_region_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )
  expect_false(claim_tamper$valid)
  expect_identical(claim_tamper$reason, "predecessor_packet_bytes_invalid")
})
