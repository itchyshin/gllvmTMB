bfgs_contract_env <- function() {
  env <- new.env(parent = baseenv())
  sys.source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "bfgs-smoke-contract.R"
  ), envir = env)
  env
}

bfgs_receipt_fixture <- function(paper1 = FALSE) {
  hash <- function(letter) paste(rep(letter, 32L), collapse = "")
  ans <- list(
    schema = "BFGS_P2_S6_C360_R3_V3_PREFLIGHT_V1",
    source_gate = "BFGS_P2_S6_C360_R3_V3",
    root = "/sealed/results/BFGS_P2_S6_C360_R3_V3",
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
    ans$schema <- "BFGS_P1_S3_C360_R3_V3_PREFLIGHT_V1"
    ans$source_gate <- "BFGS_P1_S3_C360_R3_V3"
    ans$root <- "/sealed/results/BFGS_P1_S3_C360_R3_V3"
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
    source_gate = "BFGS_P2_S6_C360_R3_V3",
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

test_that("attempt marker or terminal ledger consumes a BFGS root without mutation", {
  contract <- bfgs_contract_env()
  root <- withr::local_tempdir()
  expect_identical(contract$bfgs_smoke_consumed_state(root), list(
    consumed = FALSE, reason = "fresh_root",
    terminal_ledger_exists = FALSE, attempt_marker_exists = FALSE
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
  both <- contract$bfgs_smoke_consumed_state(root)
  expect_true(both$consumed)
  expect_identical(both$reason, "attempt_marker_and_terminal_ledger_exist")
})

test_that("terminal ledger taxonomy is exact and infrastructure is not optimizer error", {
  contract <- bfgs_contract_env()
  commit <- strrep("a", 40L)
  statuses <- c(
    "INVALID_PROVENANCE", "BFGS_INFRASTRUCTURE_HOLD",
    "BFGS_RAW_INELIGIBLE", "BFGS_OPTIMIZER_ERROR",
    "BFGS_CURVATURE_UNAVAILABLE", "BFGS_CURVATURE_INVALID",
    "BFGS_NO_NUMERICAL_ADMISSION", "BFGS_NUMERICAL_ADMISSION"
  )
  for (status in statuses) {
    verdict <- contract$bfgs_smoke_validate_terminal_ledger(
      bfgs_terminal_ledger_fixture(status = status),
      "BFGS_P2_S6_C360_R3_V3", commit
    )
    expect_true(verdict$valid, info = status)
  }
  expect_false(contract$bfgs_smoke_validate_terminal_ledger(
    bfgs_terminal_ledger_fixture(status = "ATTEMPT_STARTED"),
    "BFGS_P2_S6_C360_R3_V3", commit
  )$valid)
  nonterminal <- bfgs_terminal_ledger_fixture()
  nonterminal$terminal <- FALSE
  expect_false(contract$bfgs_smoke_validate_terminal_ledger(
    nonterminal, "BFGS_P2_S6_C360_R3_V3", commit
  )$valid)
  wrong_commit <- bfgs_terminal_ledger_fixture()
  wrong_commit$receipt$commit <- strrep("b", 40L)
  expect_false(contract$bfgs_smoke_validate_terminal_ledger(
    wrong_commit, "BFGS_P2_S6_C360_R3_V3", commit
  )$valid)
})

test_that("Paper 1 accepts only a full manifested Paper 2 algorithm attempt", {
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
  signature <- list(source_gate = "BFGS_P2_S6_C360_R3_V3")
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
})

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
      runner = "run-bfgs-paper2-smoke.R", gate = "BFGS_P2_S6_C360_R3_V3",
      marker = "BFGS_P2_RUNNER_VALIDATION_PASS (no fit)"
    ),
    paper1 = list(
      runner = "run-bfgs-paper1-smoke.R", gate = "BFGS_P1_S3_C360_R3_V3",
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
