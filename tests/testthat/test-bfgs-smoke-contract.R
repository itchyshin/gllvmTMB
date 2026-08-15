bfgs_contract_env <- function() {
  env <- new.env(parent = baseenv())
  sys.source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "bfgs-smoke-contract.R"
  ), envir = env)
  env$gllvmTMBcontrol <- gllvmTMB::gllvmTMBcontrol
  env
}

bfgs_receipt_fixture <- function(paper1 = FALSE) {
  hash <- function(letter) paste(rep(letter, 32L), collapse = "")
  ans <- list(
    schema = "BFGS_P2_S6_C360_R3_V5_PREFLIGHT_V1",
    source_gate = "BFGS_P2_S6_C360_R3_V5",
    root = "/sealed/results/BFGS_P2_S6_C360_R3_V5",
    commit = paste(rep("a", 40L), collapse = ""), seed = 86302L,
    dimensions = c(S = 6L, C = 360L, r = 3L, b = 1L, d = 1L),
    n_rows = 8640L,
    runner_md5 = hash("1"), core_runner_md5 = hash("2"),
    fixture_md5 = hash("3"), design_md5 = hash("4"),
    source_md5 = c(
      fit_multi = hash("5"), isdm_fit = hash("6"),
      tmb = hash("7"), bfgs_contract = hash("8"), dll = hash("0")
    ),
    dll_path = "/sealed/gllvmTMB.so", session_info_md5 = hash("9"),
    time_estimate_md5 = hash("a"), control_md5 = hash("b"),
    paper2_terminal_status = NA_character_, paper2_terminal_md5 = NA_character_
  )
  if (paper1) {
    ans$schema <- "BFGS_P1_S3_C360_R3_V5_PREFLIGHT_V1"
    ans$source_gate <- "BFGS_P1_S3_C360_R3_V5"
    ans$root <- "/sealed/results/BFGS_P1_S3_C360_R3_V5"
    ans$seed <- 86301L
    ans$dimensions <- c(S = 3L, C = 360L, r = 3L, b = 1L, d = 1L)
    ans$n_rows <- 4320L
    ans$paper2_terminal_status <- "BFGS_NUMERICAL_ADMISSION"
    ans$paper2_terminal_md5 <- hash("c")
  }
  ans
}

bfgs_terminal_ledger_fixture <- function(
    status = "BFGS_NUMERICAL_ADMISSION",
    source_gate = "BFGS_P2_S6_C360_R3_V5",
    commit = paste(rep("a", 40L), collapse = "")) {
  list(
    schema = paste0(source_gate, "_ALL_ATTEMPT_V1"), status = status,
    terminal = TRUE, receipt = list(source_gate = source_gate, commit = commit),
    error = NA_character_
  )
}

test_that("BFGS receipts require exact schema, types, values, and paper order", {
  contract <- bfgs_contract_env()
  expected <- bfgs_receipt_fixture()
  expect_identical(
    contract$bfgs_smoke_validate_receipt(expected, expected),
    list(valid = TRUE, reason = "receipt_valid")
  )

  changes <- list(
    names = function(x) { names(x)[1L] <- "wrong_schema"; x },
    seed_type = function(x) { x$seed <- as.numeric(x$seed); x },
    dimensions_order = function(x) { x$dimensions <- x$dimensions[c(2, 1, 3)]; x },
    source_hash = function(x) { x$source_md5[[1L]] <- "not-an-md5"; x },
    dll_path = function(x) { x$dll_path <- ""; x },
    session = function(x) { x$session_info_md5 <- strrep("0", 32L); x },
    time = function(x) { x$time_estimate_md5 <- strrep("0", 32L); x },
    control = function(x) { x$control_md5 <- strrep("0", 32L); x },
    rows = function(x) { x$n_rows <- 0L; x }
  )
  for (label in names(changes)) {
    observed <- changes[[label]](expected)
    expect_false(
      contract$bfgs_smoke_validate_receipt(observed, expected)$valid,
      info = label
    )
  }

  paper1 <- bfgs_receipt_fixture(paper1 = TRUE)
  expect_true(contract$bfgs_smoke_validate_receipt(paper1, paper1)$valid)
  missing_paper2_status <- paper1
  missing_paper2_status$paper2_terminal_status <- NULL
  expect_false(contract$bfgs_smoke_validate_receipt(
    missing_paper2_status, missing_paper2_status
  )$valid)
  tampered_paper2_hash <- paper1
  tampered_paper2_hash$paper2_terminal_md5 <- strrep("d", 32L)
  expect_false(contract$bfgs_smoke_validate_receipt(
    tampered_paper2_hash, paper1
  )$valid)
})

test_that("exact TMB gradient order accepts positional output but rejects drift", {
  contract <- bfgs_contract_env()
  theta <- c(beta = 0, log_sigma = 1)
  expect_true(contract$bfgs_smoke_gradient_order_ok(c(0.1, 0.2), theta))
  expect_true(contract$bfgs_smoke_gradient_order_ok(
    c(beta = 0.1, log_sigma = 0.2), theta
  ))
  expect_false(contract$bfgs_smoke_gradient_order_ok(
    c(log_sigma = 0.1, beta = 0.2), theta
  ))
  expect_false(contract$bfgs_smoke_gradient_order_ok(0.1, theta))
})

test_that("BFGS independent recomputation accepts evidence and rejects coordinated drift", {
  contract <- bfgs_contract_env()
  x <- bfgs_quadratic_fixture()
  out <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(),
    function(theta, ids) bfgs_curvature_record(theta, ids, x$covariance)
  )
  accepted <- contract$bfgs_smoke_recompute_result(out)
  expect_true(accepted$valid, info = accepted$reason)
  attacks <- list(
    raw_gradient_order = function(x) { x$raw$gradient <- x$raw$gradient[c(2, 1, 3)]; x },
    optimizer_parameter_order = function(x) { x$optimizer$par <- x$optimizer$par[c(2, 1, 3)]; x },
    candidate_gradient_order = function(x) { x$candidate$gradient <- x$candidate$gradient[c(2, 1, 3)]; x },
    malformed_convergence = function(x) { x$optimizer$convergence <- 0.5; x },
    candidate_objective = function(x) { x$candidate$objective <- x$candidate$objective + 1; x },
    covariance = function(x) { x$curvature$covariance[1, 1] <- 2; x }
  )
  for (label in names(attacks)) {
    expect_false(contract$bfgs_smoke_recompute_result(attacks[[label]](out))$valid,
      info = label)
  }
})

test_that("BFGS manifest validation detects file, schema, and hash tampering", {
  contract <- bfgs_contract_env()
  root <- withr::local_tempdir()
  writeLines("sealed session", file.path(root, "session-info.rds"))
  writeLines("sealed time", file.path(root, "time-estimate.md"))
  writeLines("sealed receipt", file.path(root, "root-receipt.rds"))
  paths <- c("root-receipt.rds", "session-info.rds", "time-estimate.md")
  write_manifest <- function() {
    utils::write.csv(data.frame(
      path = paths,
      md5 = unname(tools::md5sum(file.path(root, paths))),
      stringsAsFactors = FALSE
    ), file.path(root, "file-manifest.csv"), row.names = FALSE)
  }
  write_manifest()

  expect_true(contract$bfgs_smoke_validate_manifest(root, paths)$valid)
  writeLines("tampered session", file.path(root, "session-info.rds"))
  expect_identical(
    contract$bfgs_smoke_validate_manifest(root, paths)$reason,
    "manifest_hash_mismatch"
  )
  writeLines("sealed session", file.path(root, "session-info.rds"))
  write_manifest()
  writeLines("unmanifested", file.path(root, "extra.txt"))
  expect_identical(
    contract$bfgs_smoke_validate_manifest(root, paths)$reason,
    "manifest_file_set_mismatch"
  )
  unlink(file.path(root, "extra.txt"))
  expect_identical(
    contract$bfgs_smoke_validate_manifest(root, paths[-1L])$reason,
    "manifest_expected_paths_mismatch"
  )
  bad <- utils::read.csv(file.path(root, "file-manifest.csv"),
    stringsAsFactors = FALSE)
  bad$path[[1L]] <- "../escape"
  utils::write.csv(bad, file.path(root, "file-manifest.csv"), row.names = FALSE)
  expect_identical(
    contract$bfgs_smoke_validate_manifest(root)$reason,
    "manifest_schema_invalid"
  )
})

test_that("BFGS manifest inventory rejects symlinks, nested files, and nonempty claims", {
  skip_if(.Platform$OS.type == "windows", "symlink semantics are platform-specific")
  contract <- bfgs_contract_env()
  root <- withr::local_tempdir()
  writeLines("receipt", file.path(root, "root-receipt.rds"))
  paths <- "root-receipt.rds"
  write_manifest <- function() utils::write.csv(data.frame(path = paths,
    md5 = unname(tools::md5sum(file.path(root, paths)))),
    file.path(root, "file-manifest.csv"), row.names = FALSE)
  write_manifest()
  expect_true(contract$bfgs_smoke_validate_manifest(root, paths)$valid)
  expect_true(file.symlink(file.path(root, "root-receipt.rds"),
    file.path(root, "linked.rds")))
  expect_identical(contract$bfgs_smoke_validate_manifest(root, paths)$reason,
    "manifest_file_type_invalid")
  unlink(file.path(root, "linked.rds"))
  dir.create(file.path(root, "nested"))
  writeLines("hidden", file.path(root, "nested", "payload"))
  expect_identical(contract$bfgs_smoke_validate_manifest(root, paths)$reason,
    "manifest_directory_set_mismatch")
  unlink(file.path(root, "nested"), recursive = TRUE)
  dir.create(file.path(root, ".attempt-started.claim"))
  expect_true(contract$bfgs_smoke_validate_manifest(root, paths,
    expected_dirs = ".attempt-started.claim")$valid)
  writeLines("nested", file.path(root, ".attempt-started.claim", "payload"))
  expect_identical(contract$bfgs_smoke_validate_manifest(root, paths,
    expected_dirs = ".attempt-started.claim")$reason,
    "manifest_directory_set_mismatch")
})

test_that("attempt marker or terminal ledger consumes a BFGS root without mutation", {
  contract <- bfgs_contract_env()
  root <- withr::local_tempdir()
  expect_identical(contract$bfgs_smoke_consumed_state(root), list(
    consumed = FALSE, reason = "fresh_root",
    terminal_ledger_exists = FALSE, attempt_marker_exists = FALSE,
    attempt_claim_exists = FALSE
  ))
  saveRDS(list(status = "OPTIMIZER_ENTERED"),
    file.path(root, "attempt-started.rds"))
  before <- list.files(root, all.files = TRUE, no.. = TRUE)
  attempted <- contract$bfgs_smoke_consumed_state(root)
  expect_true(attempted$consumed)
  expect_identical(attempted$reason, "attempt_marker_exists")
  expect_identical(list.files(root, all.files = TRUE, no.. = TRUE), before)
  saveRDS(bfgs_terminal_ledger_fixture(),
    file.path(root, "all-attempt-ledger.rds"))
  expect_true(dir.create(file.path(root, ".attempt-started.claim")))
  both <- contract$bfgs_smoke_consumed_state(root)
  expect_true(both$consumed)
  expect_identical(both$reason, "attempt_marker_and_terminal_ledger_exist")
})

test_that("V2 terminal ledgers distinguish early and fallback terminal shapes", {
  contract <- bfgs_contract_env()
  commit <- strrep("a", 40L)
  for (case in list(
      early = c("INVALID_PROVENANCE", "provenance_failure"),
      fallback = c("BFGS_INFRASTRUCTURE_HOLD", "runner_unwind"))) {
    root <- withr::local_tempdir()
    ledger <- bfgs_v2_fallback_ledger(contract, root, case[[1L]], case[[2L]])
    ledger <- bfgs_v2_materialize(contract, ledger)
    accepted <- contract$bfgs_smoke_validate_terminal_ledger(
      ledger, ledger$receipt$source_gate, commit
    )
    expect_true(accepted$valid, info = accepted$reason)
    attacks <- list(
      status = function(x) { x$status <- "BFGS_OPTIMIZER_ERROR"; x },
      checks = function(x) { x$checks$terminal_evidence <- TRUE; x },
      reason = function(x) { x$reason <- "forged"; x },
      marker = function(x) { x$attempt_marker$claim <- "forged"; x }
    )
    for (label in names(attacks)) {
      expect_false(contract$bfgs_smoke_validate_terminal_ledger(
        attacks[[label]](ledger), ledger$receipt$source_gate, commit
      )$valid, info = paste(case[[1L]], label))
    }
  }
})

test_that("post-entry fallback preserves every typed NULL ledger slot", {
  contract <- bfgs_contract_env()
  root <- withr::local_tempdir()
  ledger <- bfgs_v2_normal_ledger(contract, root)
  fit <- attr(ledger, "bfgs_fixture_fit", exact = TRUE)
  attr(ledger, "bfgs_fixture_fit") <- NULL

  prefix <- ledger$continuation_source
  ledger$raw <- list(
    parameter_vector = prefix$parameter_vector,
    gradient = prefix$gradient,
    objective = prefix$objective,
    raw_state = list(
      optimizer = "nlminb", convergence = prefix$convergence,
      pd_hessian = prefix$pd_hessian,
      boundary_flags = prefix$boundary_flags, is_isdm = TRUE,
      aghq = FALSE, ridge = FALSE,
      retry_enabled = !isTRUE(prefix$internal_continuation_disabled),
      profile_enabled = FALSE, source_gate = ledger$receipt$source_gate
    ),
    selection_source = prefix$selection_source
  )
  ledger <- contract$.bfgs_smoke_normalise_fallback(
    ledger, simpleError("synthetic post-entry runner error"),
    fit_available = TRUE, entry_available = TRUE
  )
  ledger <- bfgs_v2_materialize(contract, ledger, fit)

  accepted <- contract$bfgs_smoke_validate_terminal_ledger(
    ledger, ledger$receipt$source_gate, ledger$receipt$commit
  )
  expect_true(accepted$valid, info = accepted$reason)

  deleted <- ledger
  deleted$bfgs <- NULL
  expect_false(contract$bfgs_smoke_validate_terminal_ledger(
    deleted, deleted$receipt$source_gate, deleted$receipt$commit
  )$valid)

  early <- bfgs_v2_fallback_ledger(contract, withr::local_tempdir())
  early <- contract$.bfgs_smoke_normalise_fallback(
    early, simpleError("synthetic pre-entry runner error"),
    fit_available = FALSE, entry_available = FALSE
  )
  expect_identical(names(early), contract$.bfgs_smoke_ledger_names)
  expect_null(early$bfgs_entry)
  expect_null(early$signature)
  expect_null(early$raw)
  expect_null(early$continuation_source)
})

test_that("BFGS entry evidence requires a claimed marker and immutable order hash", {
  contract <- bfgs_contract_env()
  root <- withr::local_tempdir()
  ledger <- bfgs_v2_fallback_ledger(contract, root)
  receipt_md5 <- strrep("2", 32L)
  marker <- bfgs_v2_marker(contract, ledger$receipt, md5 = receipt_md5)
  order_hash <- contract$.bfgs_smoke_hash_object(list(
    labels = "beta", ids = "beta[1]"
  ))
  entry <- list(schema = paste0(marker$source_gate, "_BFGS_ENTERED_V1"),
    source_gate = marker$source_gate, root = marker$root, commit = marker$commit,
    attempt_marker_md5 = strrep("3", 32L),
    entered_at = "2026-08-14 00:00:01.000000", parent_pid = marker$parent_pid,
    parameter_order_hash = order_hash)
  accepted <- contract$bfgs_smoke_validate_bfgs_entry(
    entry, marker, order_hash, strrep("3", 32L)
  )
  expect_true(accepted$valid, info = accepted$reason)
  for (attack in list(
      marker_hash = function(x) { x$attempt_marker_md5 <- strrep("0", 32L); x },
      order = function(x) { x$parameter_order_hash <- strrep("1", 32L); x },
      parent = function(x) { x$parent_pid <- 2L; x })) {
    expect_false(contract$bfgs_smoke_validate_bfgs_entry(
      attack(entry), marker, order_hash, strrep("3", 32L)
    )$valid)
  }
})

test_that("normal V2 terminal evidence is recomputed before a Paper 2 prerequisite", {
  contract <- bfgs_contract_env()
  root <- withr::local_tempdir()
  ledger <- bfgs_v2_normal_ledger(contract, root)
  fit <- attr(ledger, "bfgs_fixture_fit", exact = TRUE)
  ledger <- bfgs_v2_materialize(contract, ledger, fit)
  commit <- ledger$receipt$commit
  normal <- contract$bfgs_smoke_validate_terminal_ledger(
    ledger, ledger$receipt$source_gate, commit
  )
  expect_true(normal$valid, info = normal$reason)
  expect_true(isTRUE(ledger$bfgs$optimizer_entered))

  attacks <- list(
    pre_helper_entry = function(x) { x$bfgs$optimizer_entered <- FALSE; x },
    raw_ineligible_entry = function(x) {
      x$bfgs$status <- "BFGS_RAW_INELIGIBLE"
      x$bfgs$reason <- "raw_gradient_gate"
      x
    },
    receipt_control = function(x) { x$receipt$control_md5 <- strrep("e", 32L); x },
    ledger_control = function(x) { x$control_md5 <- strrep("d", 32L); x },
    manifest_coordinated = function(x) {
      writeLines("coordinated drift", file.path(root, "session-info.rds"))
      paths <- sort(setdiff(list.files(root, all.files = TRUE, no.. = TRUE),
        c("file-manifest.csv", ".attempt-started.claim")))
      utils::write.csv(data.frame(path = paths,
        md5 = unname(tools::md5sum(file.path(root, paths)))),
        file.path(root, "file-manifest.csv"), row.names = FALSE)
      x
    }
  )
  for (label in names(attacks)) {
    candidate <- attacks[[label]](ledger)
    expect_false(contract$bfgs_smoke_validate_terminal_ledger(
      candidate, candidate$receipt$source_gate, commit,
      if (identical(label, "manifest_coordinated")) root else NULL
    )$valid, info = label)
  }
})

test_that("a live-root V2 terminal is the only accepted Paper 2 prerequisite", {
  contract <- bfgs_contract_env()
  pkg <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  results <- file.path(pkg, "dev", "isdm-package-recovery", "results")
  dir.create(results, recursive = TRUE, showWarnings = FALSE)
  root <- tempfile("test-bfgs-p2-", tmpdir = results)
  dir.create(root)
  withr::defer(unlink(root, recursive = TRUE))
  ledger <- bfgs_v2_normal_ledger(contract, root, live = TRUE)
  fit <- attr(ledger, "bfgs_fixture_fit", exact = TRUE)
  ledger <- bfgs_v2_materialize(contract, ledger, fit)
  expected <- list(
    runner_md5 = ledger$receipt$runner_md5,
    core_runner_md5 = ledger$receipt$core_runner_md5,
    fixture_md5 = ledger$receipt$fixture_md5,
    design_md5 = ledger$receipt$design_md5,
    source_md5 = ledger$receipt$source_md5,
    dll_path = ledger$receipt$dll_path,
    control_md5 = ledger$receipt$control_md5
  )
  path <- file.path(root, "all-attempt-ledger.rds")
  accepted <- contract$bfgs_smoke_validate_paper2_prerequisite(
    path, ledger$receipt$commit, expected
  )
  expect_true(accepted$valid, info = accepted$reason)

  attacks <- list(
    raw_ineligible_pre_helper = function(x) {
      x$bfgs$optimizer_entered <- FALSE
      x
    },
    receipt_source = function(x) { x$receipt$source_md5[["fit_multi"]] <- strrep("a", 32L); x },
    receipt_dll = function(x) { x$receipt$dll_path <- "/forged/gllvmTMB.so"; x },
    receipt_control = function(x) { x$receipt$control_md5 <- strrep("b", 32L); x },
    coordinated_ledger_receipt = function(x) {
      x$receipt$source_md5[["tmb"]] <- strrep("c", 32L)
      x$source_md5 <- x$receipt$source_md5
      x
    }
  )
  for (label in names(attacks)) {
    candidate <- attacks[[label]](ledger)
    candidate <- bfgs_v2_materialize(contract, candidate, fit)
    expect_false(contract$bfgs_smoke_validate_paper2_prerequisite(
      path, candidate$receipt$commit, expected
    )$valid, info = label)
    ledger <- bfgs_v2_materialize(contract, ledger, fit)
  }
})

if (FALSE) { # superseded V1 packet retained only as a parse-time reference
  contract <- bfgs_contract_env()
  root <- withr::local_tempdir()
  path <- file.path(root, "all-attempt-ledger.rds")
  commit <- strrep("a", 40L)
  hash <- function(letter) paste(rep(letter, 32L), collapse = "")
  writeLines("dll", file.path(root, "gllvmTMB.so"))
  writeLines("session", file.path(root, "session-info.rds"))
  writeLines("estimate", file.path(root, "time-estimate.md"))
  control <- list(n_init = 1L, .internal_continuation = FALSE)
  control_md5 <- contract$.bfgs_smoke_hash_object(control)
  source_md5 <- c(
    fit_multi = hash("5"), isdm_fit = hash("6"), tmb = hash("7"),
    bfgs_contract = hash("8"),
    dll = unname(tools::md5sum(file.path(root, "gllvmTMB.so")))[[1L]]
  )
  receipt <- bfgs_receipt_fixture()
  receipt$root <- normalizePath(root, mustWork = TRUE)
  receipt$dll_path <- normalizePath(file.path(root, "gllvmTMB.so"), mustWork = TRUE)
  receipt$source_md5 <- source_md5
  receipt$session_info_md5 <- unname(tools::md5sum(
    file.path(root, "session-info.rds")
  ))[[1L]]
  receipt$time_estimate_md5 <- unname(tools::md5sum(
    file.path(root, "time-estimate.md")
  ))[[1L]]
  receipt$control_md5 <- control_md5
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  saveRDS(list(status = "OPTIMIZER_ENTERED"),
    file.path(root, "attempt-started.rds"))
  par <- c(beta = 0)
  labels <- names(par)
  ids <- paste0(labels, "[", seq_along(par), "]")
  signature <- list(source_gate = "BFGS_P2_S6_C360_R3_V5")
  continuation <- list(
    warm_restart_provenance = list(attempted = FALSE),
    isdm_polish_provenance = list(attempted = FALSE),
    restart_history = data.frame(restart = 1L),
    start_provenance = list(source = "zero_jitter"),
    selection_source = "initial_nlminb"
  )
  continuation$provenance_hashes <- list(
    warm_restart_provenance = contract$.bfgs_smoke_hash_object(
      continuation$warm_restart_provenance
    ),
    isdm_polish_provenance = contract$.bfgs_smoke_hash_object(
      continuation$isdm_polish_provenance
    ),
    restart_history = contract$.bfgs_smoke_hash_object(
      continuation$restart_history
    ),
    start_provenance = contract$.bfgs_smoke_hash_object(
      continuation$start_provenance
    ),
    selection_source = contract$.bfgs_smoke_hash_object(
      continuation$selection_source
    )
  )
  covariance <- matrix(1)
  ledger <- list(
    schema = "BFGS_P2_S6_C360_R3_V3_ALL_ATTEMPT_V1",
    status = "BFGS_NUMERICAL_ADMISSION", terminal = TRUE,
    receipt = receipt, signature = signature,
    raw = list(parameter_vector = par), continuation_source = continuation,
    bfgs = list(
      estimator = "BFGS_EXACT_GRADIENT_CONTINUATION_V1",
      status = "BFGS_NUMERICAL_ADMISSION", signature = signature,
      curvature = list(covariance = covariance)
    ),
    fit_control = control, control_md5 = control_md5,
    order_hash = contract$.bfgs_smoke_hash_object(list(labels = labels, ids = ids)),
    covariance_hash = contract$.bfgs_smoke_hash_object(covariance),
    error = NA_character_
  )
  saveRDS(ledger, path)
  write_manifest <- function() {
    paths <- sort(setdiff(
      list.files(root, recursive = TRUE, all.files = TRUE, no.. = TRUE),
      "file-manifest.csv"
    ))
    utils::write.csv(data.frame(
      path = paths, md5 = unname(tools::md5sum(file.path(root, paths))),
      stringsAsFactors = FALSE
    ), file.path(root, "file-manifest.csv"), row.names = FALSE)
  }
  write_manifest()
  expected <- list(
    runner_md5 = receipt$runner_md5,
    core_runner_md5 = receipt$core_runner_md5,
    fixture_md5 = receipt$fixture_md5, design_md5 = receipt$design_md5,
    source_md5 = source_md5, dll_path = receipt$dll_path,
    control_md5 = control_md5
  )
  accepted <- contract$bfgs_smoke_validate_paper2_prerequisite(
    path, commit, expected
  )
  expect_true(accepted$valid)
  expect_identical(accepted$ledger$status, "BFGS_NUMERICAL_ADMISSION")
  expect_true(grepl("^[[:xdigit:]]{32}$", accepted$md5))

  nonterminal <- ledger
  nonterminal$terminal <- FALSE
  saveRDS(nonterminal, path)
  write_manifest()
  expect_false(contract$bfgs_smoke_validate_paper2_prerequisite(
    path, commit, expected
  )$valid)
  saveRDS(ledger, path)
  unlink(file.path(root, "attempt-started.rds"))
  write_manifest()
  expect_false(contract$bfgs_smoke_validate_paper2_prerequisite(
    path, commit, expected
  )$valid)
  saveRDS(list(status = "OPTIMIZER_ENTERED"),
    file.path(root, "attempt-started.rds"))
  synthetic <- ledger
  synthetic$bfgs <- NULL
  saveRDS(synthetic, path)
  write_manifest()
  expect_false(contract$bfgs_smoke_validate_paper2_prerequisite(
    path, commit, expected
  )$valid)
  saveRDS(ledger, path)
  write_manifest()
  writeLines("tampered", file.path(root, "session-info.rds"))
  expect_false(contract$bfgs_smoke_validate_paper2_prerequisite(
    path, commit, expected
  )$valid)
}

test_that("Paper BFGS runners execute their validation modes without a fit", {
  skip_if_not_installed("devtools")
  rscript <- Sys.which("Rscript")
  skip_if(!nzchar(rscript), "Rscript is unavailable")
  pkg <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  base <- file.path(pkg, "dev", "isdm-package-recovery")
  commit <- system2("git", c("-C", shQuote(pkg), "rev-parse", "HEAD"),
    stdout = TRUE)[[1L]]
  cases <- list(
    paper2 = list(
      runner = "run-bfgs-paper2-smoke.R", gate = "BFGS_P2_S6_C360_R3_V5",
      marker = "BFGS_P2_RUNNER_VALIDATION_PASS (no fit)"
    ),
    paper1 = list(
      runner = "run-bfgs-paper1-smoke.R", gate = "BFGS_P1_S3_C360_R3_V5",
      marker = "BFGS_P1_RUNNER_VALIDATION_PASS (no fit)"
    )
  )
  for (case in cases) {
    output <- system2(rscript, c(
      "--vanilla", shQuote(file.path(base, case$runner)),
      "--mode=validate",
      paste0("--output=", shQuote(file.path(base, "results", case$gate))),
      paste0("--pkg=", shQuote(pkg)), paste0("--campaign-sha=", commit)
    ), stdout = TRUE, stderr = TRUE)
    expect_null(attr(output, "status"), info = case$runner)
    expect_true(any(grepl(case$marker, output, fixed = TRUE)), info = case$runner)
  }
})
