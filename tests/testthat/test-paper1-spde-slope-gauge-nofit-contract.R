spde_slope_gauge_nofit_contract_env <- function() {
  env <- new.env(parent = baseenv())
  source(
    testthat::test_path(
      "..",
      "..",
      "dev",
      "isdm-package-recovery",
      "spde-slope-gauge-contract.R"
    ),
    local = env
  )
  source(
    testthat::test_path(
      "..",
      "..",
      "dev",
      "isdm-package-recovery",
      "spde-slope-gauge-nofit-contract.R"
    ),
    local = env
  )
  env
}

spde_slope_gauge_nofit_fixture <- function(contract) {
  root <- tempfile("spde-slope-gauge-nofit-")
  dir.create(root)
  root <- normalizePath(root)
  dir.create(file.path(root, ".attempt-started.claim"))
  order <- contract$spde_slope_gauge_raw_order()
  theta <- stats::setNames(as.double(seq_len(22L)) / 10, order)
  theta[20:22] <- c(0.2, -0.1, 0.3)
  state <- list(
    schema = "SYNTHETIC_STATE_V1",
    objective = 1.25,
    theta = theta,
    gradient = stats::setNames(rep(0, 22L), order),
    convergence = 0L,
    covariance = list(),
    start_provenance = list(),
    restart_history = data.frame(x = 1),
    warm_restart_provenance = list(),
    isdm_polish_provenance = list(),
    parameters = list(),
    map = list(),
    data = list(),
    random = "g_spde_slope",
    block_labels = rep("theta", 22L),
    parameter_order = order
  )
  historical_contract <- tempfile("spde-slope-gauge-historical-contract-")
  writeLines("synthetic historical V3 contract", historical_contract)
  receipt <- list(
    schema = "SYNTHETIC_RECEIPT_V1",
    source_gate = "SYNTHETIC",
    root = root,
    commit = "synthetic-commit",
    consumed_v2 = list(),
    runner_md5 = paste0(rep("1", 32), collapse = ""),
    contract_md5 = unname(tools::md5sum(historical_contract))[[1L]],
    design_md5 = paste0(rep("3", 32), collapse = "")
  )
  saveRDS(list(terminal = TRUE), file.path(root, "all-attempt-ledger.rds"))
  saveRDS(list(started = TRUE), file.path(root, "attempt-started.rds"))
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  saveRDS(list(session = TRUE), file.path(root, "session-info.rds"))
  saveRDS(state, file.path(root, "v2-materialized-state.rds"))
  writeLines("synthetic no-fit estimate", file.path(root, "time-estimate.md"))
  declared <- c(
    "all-attempt-ledger.rds",
    "attempt-started.rds",
    "root-receipt.rds",
    "session-info.rds",
    "time-estimate.md",
    "v2-materialized-state.rds"
  )
  hashes <- unname(tools::md5sum(file.path(root, declared)))
  utils::write.csv(
    data.frame(path = declared, md5 = hashes),
    file.path(root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  files <- c(
    stats::setNames(hashes, declared),
    "file-manifest.csv" = unname(tools::md5sum(file.path(
      root,
      "file-manifest.csv"
    ))[[1L]])
  )
  locked <- list(
    root = root,
    commit = "synthetic-commit",
    files = files,
    directories = ".attempt-started.claim",
    receipt_schema = "SYNTHETIC_RECEIPT_V1",
    state_schema = "SYNTHETIC_STATE_V1",
    historical_contract_path = historical_contract,
    historical_contract_md5 = unname(tools::md5sum(historical_contract))[[1L]]
  )
  list(
    root = root,
    locked = locked,
    state = state,
    historical_contract = historical_contract
  )
}

spde_slope_gauge_nofit_refresh_manifest <- function(fixture) {
  declared <- setdiff(names(fixture$locked$files), "file-manifest.csv")
  hashes <- unname(tools::md5sum(file.path(fixture$root, declared)))
  utils::write.csv(
    data.frame(path = declared, md5 = hashes),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  fixture$locked$files[declared] <- hashes
  fixture$locked$files[["file-manifest.csv"]] <-
    unname(tools::md5sum(file.path(fixture$root, "file-manifest.csv"))[[1L]])
  fixture
}

spde_slope_gauge_nofit_v1_forensic_fixture <- function() {
  root <- normalizePath(
    tempfile("spde-slope-gauge-v1-forensic-"),
    mustWork = FALSE
  )
  dir.create(root)
  dir.create(file.path(root, ".attempt-started.claim"))
  saveRDS(list(child = TRUE), file.path(root, "child-receipt.rds"))
  saveRDS(
    list(nofit = "retained-but-inadmissible"),
    file.path(root, "no-fit-result.rds")
  )
  writeLines("retained V1 materializer", file.path(root, "materializer.R"))
  saveRDS(list(session = TRUE), file.path(root, "session-info.rds"))
  writeLines("retained V1 time estimate", file.path(root, "time-estimate.md"))
  declared <- c(
    "child-receipt.rds",
    "no-fit-result.rds",
    "materializer.R",
    "root-receipt.rds",
    "session-info.rds",
    "time-estimate.md"
  )
  receipt <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_ROOT_V1",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1",
    root = root,
    commit = "v1-forensic-commit",
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    reason = "child_evidence_invalid",
    predecessor = list(),
    sources = character(),
    dll = list(path = NA_character_, md5 = NA_character_),
    controls = list(),
    parent_stage = list(),
    process = list(),
    child_result_md5 = unname(tools::md5sum(file.path(
      root,
      "no-fit-result.rds"
    ))[[1L]]),
    time_estimate_md5 = unname(tools::md5sum(file.path(
      root,
      "time-estimate.md"
    ))[[1L]])
  )
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  hashes <- unname(tools::md5sum(file.path(root, declared)))
  utils::write.csv(
    data.frame(path = declared, md5 = hashes),
    file.path(root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  files <- c(
    stats::setNames(hashes, declared),
    "file-manifest.csv" = unname(tools::md5sum(file.path(
      root,
      "file-manifest.csv"
    ))[[1L]])
  )
  locked <- list(
    root = root,
    commit = "v1-forensic-commit",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1",
    receipt_schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_ROOT_V1",
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    reason = "child_evidence_invalid",
    files = files,
    directories = ".attempt-started.claim"
  )
  list(root = root, locked = locked)
}

spde_slope_gauge_nofit_refresh_v1_forensic_lock <- function(fixture) {
  declared <- setdiff(names(fixture$locked$files), "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
    ),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  fixture$locked$files <- unname(tools::md5sum(file.path(
    fixture$root,
    names(fixture$locked$files)
  )))
  names(fixture$locked$files) <- c(declared, "file-manifest.csv")
  fixture
}

test_that("the no-fit predecessor byte gate accepts a complete regular synthetic packet", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  verdict <- contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root,
    fixture$locked
  )
  expect_true(verdict$valid)
  expect_identical(verdict$reason, "predecessor_bytes_valid")
  expect_identical(verdict$root, fixture$root)
  expect_identical(verdict$commit, fixture$locked$commit)
  expect_identical(verdict$state, fixture$state)
  expect_identical(
    verdict$state_md5,
    fixture$locked$files[["v2-materialized-state.rds"]]
  )
})

test_that("V2 locks the complete V1 forensic packet without reusing its values", {
  contract <- spde_slope_gauge_nofit_contract_env()
  v1 <- spde_slope_gauge_nofit_v1_forensic_fixture()
  on.exit(unlink(v1$root, recursive = TRUE), add = TRUE)
  verdict <- contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
    v1$root,
    v1$locked
  )
  expect_true(verdict$valid)
  expect_identical(verdict$reason, "v1_forensic_terminal_valid")
  expect_identical(verdict$files, v1$locked$files)
  expect_false("nofit" %in% names(verdict))

  writeLines("extra", file.path(v1$root, ".attempt-started.claim", "extra.txt"))
  expect_identical(
    contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
      v1$root,
      v1$locked
    )$reason,
    "v1_forensic_packet_bytes_invalid"
  )
})

test_that("V2 rejects missing, substituted, symlinked, and wrong-root V1 packets", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v1_forensic_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  validate <- function() {
    contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
      fixture$root,
      fixture$locked
    )
  }
  unlink(file.path(fixture$root, "session-info.rds"))
  expect_identical(validate()$reason, "v1_forensic_packet_bytes_invalid")

  replacement <- spde_slope_gauge_nofit_v1_forensic_fixture()
  on.exit(unlink(replacement$root, recursive = TRUE), add = TRUE)
  writeLines("substituted", file.path(replacement$root, "materializer.R"))
  expect_identical(
    contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
      replacement$root,
      replacement$locked
    )$reason,
    "v1_forensic_packet_bytes_invalid"
  )

  link_packet <- spde_slope_gauge_nofit_v1_forensic_fixture()
  on.exit(unlink(link_packet$root, recursive = TRUE), add = TRUE)
  target <- tempfile("spde-slope-gauge-v1-link-")
  on.exit(unlink(target), add = TRUE)
  writeLines("retained V1 time estimate", target)
  path <- file.path(link_packet$root, "time-estimate.md")
  unlink(path)
  if (file.symlink(target, path)) {
    expect_identical(
      contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
        link_packet$root,
        link_packet$locked
      )$reason,
      "v1_forensic_packet_bytes_invalid"
    )
  } else {
    skip("symlinks unavailable on this platform")
  }

  wrong <- fixture$locked
  wrong$root <- tempfile("wrong-v1-forensic-root-")
  expect_identical(
    contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
      fixture$root,
      wrong
    )$reason,
    "v1_forensic_root_invalid"
  )
})

test_that("V2 reaches V1 receipt semantics after coherent synthetic rehashing", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v1_forensic_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$reason <- "forged_terminal_reason"
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  fixture <- spde_slope_gauge_nofit_refresh_v1_forensic_lock(fixture)
  expect_identical(
    contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
      fixture$root,
      fixture$locked
    )$reason,
    "v1_forensic_receipt_invalid"
  )
})

test_that("V2 rejects a symlinked V1 claim directory", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v1_forensic_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  target <- tempfile("spde-slope-gauge-v1-claim-link-")
  dir.create(target)
  on.exit(unlink(target, recursive = TRUE), add = TRUE)
  claim <- file.path(fixture$root, ".attempt-started.claim")
  unlink(claim, recursive = TRUE)
  if (!file.symlink(target, claim)) {
    skip("directory symlinks unavailable on this platform")
  }
  expect_identical(
    contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
      fixture$root,
      fixture$locked
    )$reason,
    "v1_forensic_packet_bytes_invalid"
  )
})

test_that("V2 rejects the literal V1 two-field V3 projection", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  predecessor <- contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root,
    fixture$locked
  )
  full <- predecessor[c("root", "commit", "receipt", "state_md5")]
  expect_true(contract$.spde_slope_gauge_nofit_v2_v3_projection_ok(
    full,
    predecessor
  ))
  expect_false(contract$.spde_slope_gauge_nofit_v2_v3_projection_ok(
    predecessor[c("receipt", "state_md5")],
    predecessor
  ))
  forged <- predecessor
  forged$receipt <- list(forged = TRUE)
  expect_false(contract$.spde_slope_gauge_nofit_v2_v3_projection_ok(
    full,
    forged
  ))
})

test_that("the no-fit predecessor gate rejects stale manifests, extra files, and state order drift", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)

  writeLines("extra", file.path(fixture$root, "extra.txt"))
  expect_identical(
    contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      fixture$root,
      fixture$locked
    )$reason,
    "predecessor_packet_bytes_invalid"
  )
  unlink(file.path(fixture$root, "extra.txt"))

  writeLines(
    "not empty",
    file.path(fixture$root, ".attempt-started.claim", "extra.txt")
  )
  expect_identical(
    contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      fixture$root,
      fixture$locked
    )$reason,
    "predecessor_packet_bytes_invalid"
  )
  unlink(file.path(fixture$root, ".attempt-started.claim", "extra.txt"))

  state <- readRDS(file.path(fixture$root, "v2-materialized-state.rds"))
  state$theta <- stats::setNames(state$theta, rev(names(state$theta)))
  saveRDS(state, file.path(fixture$root, "v2-materialized-state.rds"))
  fixture <- spde_slope_gauge_nofit_refresh_manifest(fixture)
  expect_identical(
    contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      fixture$root,
      fixture$locked
    )$reason,
    "predecessor_receipt_or_state_invalid"
  )
})

test_that("the no-fit predecessor gate reaches manifest semantics after coordinated packet bytes", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  manifest <- utils::read.csv(
    file.path(fixture$root, "file-manifest.csv"),
    stringsAsFactors = FALSE
  )
  manifest <- manifest[rev(seq_len(nrow(manifest))), , drop = FALSE]
  utils::write.csv(
    manifest,
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  fixture$locked$files[["file-manifest.csv"]] <-
    unname(tools::md5sum(file.path(fixture$root, "file-manifest.csv"))[[1L]])
  expect_identical(
    contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      fixture$root,
      fixture$locked
    )$reason,
    "predecessor_packet_bytes_invalid"
  )
})

test_that("the no-fit predecessor gate rejects missing or nonempty claim directories", {
  contract <- spde_slope_gauge_nofit_contract_env()
  missing <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(missing$root, recursive = TRUE), add = TRUE)
  unlink(file.path(missing$root, ".attempt-started.claim"), recursive = TRUE)
  expect_identical(
    contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      missing$root,
      missing$locked
    )$reason,
    "predecessor_packet_bytes_invalid"
  )

  nonempty <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(nonempty$root, recursive = TRUE), add = TRUE)
  writeLines(
    "unexpected",
    file.path(nonempty$root, ".attempt-started.claim", "nested.txt")
  )
  expect_identical(
    contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      nonempty$root,
      nonempty$locked
    )$reason,
    "predecessor_packet_bytes_invalid"
  )
})

test_that("the no-fit predecessor gate rejects a symlinked packet member", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  target <- tempfile("spde-slope-gauge-symlink-target-")
  on.exit(unlink(target), add = TRUE)
  writeLines("synthetic no-fit estimate", target)
  path <- file.path(fixture$root, "time-estimate.md")
  unlink(path)
  if (!file.symlink(target, path)) {
    skip("symlinks unavailable on this platform")
  }
  expect_identical(
    contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      fixture$root,
      fixture$locked
    )$reason,
    "predecessor_packet_bytes_invalid"
  )
})

test_that("the no-fit predecessor gate rejects a symlinked claim directory", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  target <- tempfile("spde-slope-gauge-claim-target-")
  dir.create(target)
  on.exit(unlink(target, recursive = TRUE), add = TRUE)
  path <- file.path(fixture$root, ".attempt-started.claim")
  unlink(path, recursive = TRUE)
  if (!file.symlink(target, path)) {
    skip("directory symlinks unavailable on this platform")
  }
  expect_identical(
    contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      fixture$root,
      fixture$locked
    )$reason,
    "predecessor_packet_bytes_invalid"
  )
})

test_that("a verified fresh object bridges an unnamed TMB gradient to strict callback evidence", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  state <- fixture$state
  state$schema <- contract$spde_slope_gauge_nofit_locked_predecessor()$state_schema
  dll_path <- tempfile("spde-slope-gauge-dll-")
  on.exit(unlink(dll_path), add = TRUE)
  writeLines("synthetic DLL bytes", dll_path)
  dll_md5 <- unname(tools::md5sum(dll_path))[[1L]]
  object <- list(
    par = stats::setNames(rep(0, 22L), state$block_labels),
    fn = function(theta) {
      fixture$state$objective + sum((theta - fixture$state$theta)^2)
    },
    gr = function(theta) unname(2 * (theta - fixture$state$theta))
  )
  state$objective <- object$fn(state$theta)
  state$gradient <- stats::setNames(object$gr(state$theta), names(state$theta))
  callbacks <- contract$spde_slope_gauge_nofit_wrap_object_callbacks(
    object,
    state,
    1L,
    dll_path,
    dll_md5
  )
  verdict <- contract$spde_slope_gauge_validate_no_fit_state(
    state[c("theta", "objective", "gradient")],
    callbacks$objective_fn,
    callbacks$gradient_fn
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
  expect_identical(callbacks$object_id, 1L)
  expect_identical(
    callbacks$parameter_order,
    contract$spde_slope_gauge_raw_order()
  )
  audit <- callbacks$evaluation_audit()
  expect_length(audit$objective, 45L)
  expect_length(audit$gradient, 1L)
  expect_identical(audit$gradient[[1L]]$supplied_names, NULL)
  expect_identical(audit$gradient[[1L]]$raw_gradient, unname(state$gradient))
  expect_identical(
    names(audit$gradient[[1L]]$input),
    contract$spde_slope_gauge_raw_order()
  )
})

test_that("the fresh-object bridge rejects wrong object or supplied gradient order", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  state <- fixture$state
  state$schema <- contract$spde_slope_gauge_nofit_locked_predecessor()$state_schema
  dll_path <- tempfile("spde-slope-gauge-dll-")
  on.exit(unlink(dll_path), add = TRUE)
  writeLines("synthetic DLL bytes", dll_path)
  dll_md5 <- unname(tools::md5sum(dll_path))[[1L]]
  good <- list(
    par = stats::setNames(rep(0, 22L), state$block_labels),
    fn = function(theta) 0,
    gr = function(theta) {
      stats::setNames(rep(0, 22L), rev(contract$spde_slope_gauge_raw_order()))
    }
  )
  callbacks <- contract$spde_slope_gauge_nofit_wrap_object_callbacks(
    good,
    state,
    1L,
    dll_path,
    dll_md5
  )
  expect_error(
    callbacks$gradient_fn(state$theta),
    "noncanonical positional order"
  )
  bad_object <- good
  names(bad_object$par)[[1L]] <- "wrong_block"
  expect_error(
    contract$spde_slope_gauge_nofit_wrap_object_callbacks(
      bad_object,
      state,
      1L,
      dll_path,
      dll_md5
    ),
    "object callback bridge evidence"
  )
})

spde_slope_gauge_nofit_gate_fixture <- function(contract) {
  predecessor <- spde_slope_gauge_nofit_fixture(contract)
  predecessor$state$schema <- predecessor$locked$state_schema
  saveRDS(
    predecessor$state,
    file.path(predecessor$root, "v2-materialized-state.rds")
  )
  predecessor <- spde_slope_gauge_nofit_refresh_manifest(predecessor)
  root <- tempfile("spde-slope-gauge-gate-")
  dir.create(root)
  root <- normalizePath(root)
  source_dir <- tempfile("spde-slope-gauge-gate-sources-")
  dir.create(source_dir)
  source_names <- c(
    "child_runner",
    "pure_contract",
    "nofit_contract",
    "historical_contract",
    "design",
    "materializer"
  )
  source_paths <- file.path(source_dir, paste0(source_names, ".txt"))
  names(source_paths) <- source_names
  for (path in source_paths) {
    writeLines(basename(path), path)
  }
  source_paths[[
    "historical_contract"
  ]] <- predecessor$locked$historical_contract_path
  dll <- tempfile("spde-slope-gauge-gate-dll-")
  writeLines("synthetic DLL", dll)
  state <- predecessor$state
  object <- list(
    par = stats::setNames(rep(0, 22L), state$block_labels),
    fn = function(theta) state$objective + sum((theta - state$theta)^2),
    gr = function(theta) unname(2 * (theta - state$theta))
  )
  state$objective <- object$fn(state$theta)
  state$gradient <- stats::setNames(object$gr(state$theta), names(state$theta))
  saveRDS(state, file.path(predecessor$root, "v2-materialized-state.rds"))
  predecessor <- spde_slope_gauge_nofit_refresh_manifest(predecessor)
  callbacks <- contract$spde_slope_gauge_nofit_wrap_object_callbacks(
    object,
    state,
    1L,
    dll,
    unname(tools::md5sum(dll))[[1L]],
    predecessor$locked
  )
  nofit <- contract$spde_slope_gauge_validate_no_fit_state(
    state[c("theta", "objective", "gradient")],
    callbacks$objective_fn,
    callbacks$gradient_fn
  )
  predecessor_verdict <- contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    predecessor$root,
    predecessor$locked
  )
  child <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_CHILD_V1",
    parent_pid = 1001L,
    child_pid = 1002L,
    started_at = "2026-08-15 00:00:00 UTC",
    deadline_s = 1800,
    status = "SPDE_SLOPE_GAUGE_NOFIT_VALID",
    reason = nofit$reason,
    predecessor = c(
      predecessor_verdict[c("root", "commit", "receipt", "state_md5")],
      list(
        historical_reason = "closeout_recomputed",
        post_replay_gc = TRUE
      )
    ),
    dll = list(
      path = normalizePath(dll),
      md5 = unname(tools::md5sum(dll))[[1L]]
    ),
    object = list(
      created = 1L,
      released = 1L,
      block_labels = callbacks$block_labels,
      parameter_order = callbacks$parameter_order
    ),
    nofit = nofit,
    callback_audit = callbacks$evaluation_audit(),
    error = NA_character_,
    ended_at = "2026-08-15 00:00:01 UTC",
    elapsed_s = 1
  )
  dir.create(file.path(root, ".attempt-started.claim"))
  saveRDS(child, file.path(root, "no-fit-result.rds"))
  parent_stage <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_PARENT_STAGE_V1",
    gate_base = dirname(root),
    stage = file.path(
      dirname(root),
      ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-synthetic"
    ),
    parent_pid = 1001L,
    child_output = file.path(
      dirname(root),
      ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-synthetic",
      "child-result.rds"
    )
  )
  process <- list(
    schema = contract$.spde_slope_gauge_nofit_process_schema(),
    command = R.home("bin/Rscript"),
    arguments = c(
      "--vanilla",
      source_paths[["child_runner"]],
      "child",
      parent_stage$child_output,
      "1001"
    ),
    parent_pid = 1001L,
    child_pid = 1002L,
    started_at = "2026-08-15 00:00:00 UTC",
    ended_at = "2026-08-15 00:00:01 UTC",
    elapsed_s = 1,
    deadline_s = 1800,
    timed_out = FALSE,
    exit_status = 0L,
    signal = NA_character_,
    stdout_md5 = paste0(rep("a", 32L), collapse = ""),
    stderr_md5 = paste0(rep("b", 32L), collapse = ""),
    child_result_md5 = unname(tools::md5sum(file.path(
      root,
      "no-fit-result.rds"
    ))[[1L]])
  )
  saveRDS(process, file.path(root, "child-receipt.rds"))
  file.copy(source_paths[["materializer"]], file.path(root, "materializer.R"))
  saveRDS(list(session = TRUE), file.path(root, "session-info.rds"))
  writeLines("synthetic time estimate", file.path(root, "time-estimate.md"))
  receipt <- list(
    schema = contract$.spde_slope_gauge_nofit_gate_schema(),
    gate = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1",
    root = root,
    commit = "synthetic-commit",
    status = child$status,
    reason = child$reason,
    predecessor = predecessor_verdict[c("receipt", "state_md5")],
    sources = stats::setNames(
      unname(tools::md5sum(source_paths)),
      names(source_paths)
    ),
    dll = child$dll,
    controls = contract$spde_slope_gauge_no_fit_controls(),
    parent_stage = parent_stage,
    process = process,
    child_result_md5 = process$child_result_md5,
    time_estimate_md5 = unname(tools::md5sum(file.path(
      root,
      "time-estimate.md"
    ))[[1L]])
  )
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  files <- contract$.spde_slope_gauge_nofit_gate_files(TRUE)
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(root, declared)))
    ),
    file.path(root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  list(
    root = root,
    predecessor = predecessor,
    source_dir = source_dir,
    source_paths = source_paths,
    dll = dll,
    child = child
  )
}

test_that("a complete no-fit gate root is independently bound to retained child evidence", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(unlink(fixture$dll), add = TRUE)
  verdict <- contract$spde_slope_gauge_nofit_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    fixture$predecessor$locked,
    commit = "synthetic-commit"
  )
  expect_true(verdict$valid)
  expect_identical(verdict$reason, "nofit_gate_root_valid")
  expect_identical(verdict$child, fixture$child)
})

test_that("the V2 child requires both the complete V1 closeout and V3 receipt projection", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  v1 <- spde_slope_gauge_nofit_v1_forensic_fixture()
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir, v1$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(unlink(fixture$dll), add = TRUE)
  v1_verdict <- contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
    v1$root,
    v1$locked
  )
  v3_verdict <- contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$predecessor$root,
    fixture$predecessor$locked
  )
  child <- fixture$child
  child$schema <- "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_CHILD_V1"
  child <- append(
    child,
    list(stage = "complete"),
    after = which(names(child) == "reason")
  )
  child$predecessor <- c(
    v3_verdict[c("root", "commit", "receipt", "state_md5")],
    list(
      v1_forensic = v1_verdict[c(
        "root",
        "commit",
        "receipt",
        "files",
        "status",
        "terminal_reason"
      )],
      historical_reason = "closeout_recomputed",
      post_replay_gc = TRUE
    )
  )
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    child$dll
  ))
  child$predecessor$receipt <- list(forged = TRUE)
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    child$dll
  ))
})

test_that("V2 retains only exact pre-object infrastructure evidence", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  v1 <- spde_slope_gauge_nofit_v1_forensic_fixture()
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir, v1$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(unlink(fixture$dll), add = TRUE)
  v1_verdict <- contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
    v1$root,
    v1$locked
  )
  v3_verdict <- contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$predecessor$root,
    fixture$predecessor$locked
  )
  child <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_CHILD_V1",
    parent_pid = 1001L,
    child_pid = 1002L,
    started_at = "2026-08-15 00:00:00 UTC",
    deadline_s = 1800,
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    reason = "v1_forensic_invalid",
    stage = "v1_forensic",
    predecessor = NULL,
    dll = NULL,
    object = list(created = 0L, released = 0L),
    nofit = NULL,
    callback_audit = NULL,
    error = "DLL identity did not validate",
    ended_at = "2026-08-15 00:00:01 UTC",
    elapsed_s = 1
  )
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$reason <- "time_limit_exceeded"
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$stage <- "historical"
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$reason <- "dll_identity_failure"
  child$stage <- "dll"
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$predecessor <- c(
    v3_verdict[c("root", "commit", "receipt", "state_md5")],
    list(
      v1_forensic = v1_verdict[c(
        "root",
        "commit",
        "receipt",
        "files",
        "status",
        "terminal_reason"
      )],
      historical_reason = NA_character_,
      post_replay_gc = FALSE
    )
  )
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$dll <- list(path = "forged", md5 = "forged")
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))

  child$reason <- "historical_v3_replay_failure"
  child$stage <- "historical"
  child$dll <- fixture$child$dll
  child$predecessor <- c(
    v3_verdict[c("root", "commit", "receipt", "state_md5")],
    list(
      v1_forensic = v1_verdict[c(
        "root",
        "commit",
        "receipt",
        "files",
        "status",
        "terminal_reason"
      )],
      historical_reason = NA_character_,
      post_replay_gc = FALSE
    )
  )
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$nofit <- list(forged = TRUE)
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))

  child["nofit"] <- list(NULL)
  child$reason <- "time_limit_exceeded"
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))

  child$predecessor$historical_reason <- "closeout_recomputed"
  child$predecessor$post_replay_gc <- TRUE
  child$reason <- "fresh_object_unavailable"
  child$stage <- "factory"
  child$object <- list(created = 0L, released = 0L)
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$object <- list(created = 1L, released = 1L)
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$object <- list(created = 0L, released = 0L)
  child$reason <- "time_limit_exceeded"
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$object <- list(created = -1L, released = 0L)
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))

  child$reason <- "callback_or_finite_difference_failure"
  child$stage <- "callback"
  child$object <- list(created = 1L, released = 1L)
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$callback_audit <- list(forged = TRUE)
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))

  child["callback_audit"] <- list(NULL)
  child$reason <- "time_limit_exceeded"
  child$stage <- "callback"
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))

  child$stage <- "release"
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$object <- list(created = 1L, released = 0L)
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))

  child$reason <- "object_release_failure"
  child$object <- list(created = 1L, released = 0L)
  expect_true(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
  child$object <- list(created = 1L, released = 1L)
  expect_false(contract$.spde_slope_gauge_nofit_v2_child_ok(
    child,
    v1_verdict,
    v3_verdict,
    fixture$child$dll
  ))
})

test_that("the gate root rejects a forged process launch, source commit, or evidence-HOLD relabel", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll, fixture$predecessor$historical_contract)),
    add = TRUE
  )
  validate <- function(commit = "synthetic-commit") {
    contract$spde_slope_gauge_nofit_validate_gate_root(
      fixture$root,
      fixture$source_paths,
      fixture$predecessor$locked,
      commit = commit
    )
  }
  expect_false(validate("wrong-commit")$valid)
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$arguments[[5L]] <- "9999"
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$process <- process
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  files <- contract$.spde_slope_gauge_nofit_gate_files(TRUE)
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
    ),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  expect_false(validate()$valid)
  process$arguments[[5L]] <- "1001"
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt$status <- "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  receipt$reason <- "child_evidence_invalid"
  receipt$dll <- list(path = NA_character_, md5 = NA_character_)
  receipt$process <- process
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
    ),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  expect_false(validate()$valid)
})

test_that("the no-fit gate root rejects coordinated manifest, child, and retained-materializer tampering", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(unlink(fixture$dll), add = TRUE)
  validate <- function() {
    contract$spde_slope_gauge_nofit_validate_gate_root(
      fixture$root,
      fixture$source_paths,
      fixture$predecessor$locked,
      commit = "synthetic-commit"
    )
  }
  refresh_root_manifest <- function() {
    files <- contract$.spde_slope_gauge_nofit_gate_files(TRUE)
    declared <- setdiff(files, "file-manifest.csv")
    utils::write.csv(
      data.frame(
        path = declared,
        md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
      ),
      file.path(fixture$root, "file-manifest.csv"),
      row.names = FALSE,
      quote = TRUE
    )
  }
  writeLines(
    "tampered retained materializer",
    file.path(fixture$root, "materializer.R")
  )
  refresh_root_manifest()
  expect_identical(validate()$reason, "nofit_gate_evidence_invalid")
  file.copy(
    fixture$source_paths[["materializer"]],
    file.path(fixture$root, "materializer.R"),
    overwrite = TRUE
  )
  refresh_root_manifest()
  child <- readRDS(file.path(fixture$root, "no-fit-result.rds"))
  child$callback_audit$gradient[[1L]]$named_gradient <- unname(
    child$nofit$raw_gradient
  )
  saveRDS(child, file.path(fixture$root, "no-fit-result.rds"))
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$child_result_md5 <- unname(tools::md5sum(file.path(
    fixture$root,
    "no-fit-result.rds"
  ))[[1L]])
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$process <- process
  receipt$child_result_md5 <- process$child_result_md5
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  files <- contract$.spde_slope_gauge_nofit_gate_files(TRUE)
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
    ),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  expect_identical(validate()$reason, "nofit_gate_evidence_invalid")
  receipt$status <- "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  receipt$reason <- "child_evidence_invalid"
  receipt$dll <- list(path = NA_character_, md5 = NA_character_)
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  refresh_root_manifest()
  expect_true(validate()$valid)
  expect_identical(
    validate()$receipt$status,
    "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  )
  process$timed_out <- TRUE
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt$process <- process
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  refresh_root_manifest()
  expect_false(validate()$valid)
})

test_that("a reporting pre-factory child can seal only its typed infrastructure boundary", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(unlink(fixture$dll), add = TRUE)
  child <- readRDS(file.path(fixture$root, "no-fit-result.rds"))
  child$status <- "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  child$reason <- "predecessor_bytes_invalid"
  child["predecessor"] <- list(NULL)
  child["dll"] <- list(NULL)
  child$object <- list(created = 0L, released = 0L)
  child["nofit"] <- list(NULL)
  child["callback_audit"] <- list(NULL)
  child$error <- "predecessor packet bytes are invalid"
  saveRDS(child, file.path(fixture$root, "no-fit-result.rds"))
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$child_result_md5 <- unname(tools::md5sum(file.path(
    fixture$root,
    "no-fit-result.rds"
  ))[[1L]])
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$status <- child$status
  receipt$reason <- child$reason
  receipt$dll <- list(path = NA_character_, md5 = NA_character_)
  receipt$process <- process
  receipt$child_result_md5 <- process$child_result_md5
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  files <- contract$.spde_slope_gauge_nofit_gate_files(TRUE)
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
    ),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  verdict <- contract$spde_slope_gauge_nofit_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    fixture$predecessor$locked,
    commit = "synthetic-commit"
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
  expect_identical(verdict$receipt$reason, "predecessor_bytes_invalid")
})

test_that("a zero-exit child with missing output seals only the non-reporting infrastructure boundary", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll, fixture$predecessor$historical_contract)),
    add = TRUE
  )
  unlink(file.path(fixture$root, "no-fit-result.rds"))
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$child_pid <- NA_integer_
  process$child_result_md5 <- NA_character_
  process$timed_out <- FALSE
  process$exit_status <- 0L
  process$signal <- NA_character_
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$status <- "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  receipt$reason <- "child_process_no_result"
  receipt$dll <- list(path = NA_character_, md5 = NA_character_)
  receipt$process <- process
  receipt$child_result_md5 <- NA_character_
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  files <- contract$.spde_slope_gauge_nofit_gate_files(FALSE)
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
    ),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  verdict <- contract$spde_slope_gauge_nofit_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    fixture$predecessor$locked,
    commit = "synthetic-commit"
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
  expect_identical(verdict$receipt$reason, "child_process_no_result")
})

test_that("the gate root independently recomputes the complete transformed replay", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(unlink(fixture$dll), add = TRUE)
  child <- readRDS(file.path(fixture$root, "no-fit-result.rds"))
  child$nofit$raw_gradient[[1L]] <- child$nofit$raw_gradient[[1L]] + 0.25
  child$nofit$transformed_gradient <- contract$spde_slope_gauge_full_chain_gradient(
    child$nofit$phi,
    child$nofit$raw_gradient
  )
  child$callback_audit$gradient[[1L]]$raw_gradient <- unname(
    child$nofit$raw_gradient
  )
  child$callback_audit$gradient[[1L]]$named_gradient <- child$nofit$raw_gradient
  saveRDS(child, file.path(fixture$root, "no-fit-result.rds"))
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$child_result_md5 <- unname(tools::md5sum(file.path(
    fixture$root,
    "no-fit-result.rds"
  ))[[1L]])
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$process <- process
  receipt$child_result_md5 <- process$child_result_md5
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  files <- contract$.spde_slope_gauge_nofit_gate_files(TRUE)
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
    ),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  verdict <- contract$spde_slope_gauge_nofit_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    fixture$predecessor$locked,
    commit = "synthetic-commit"
  )
  expect_false(verdict$valid)
  expect_false(verdict$checks[["child"]])
})

test_that("a non-reporting child seals only its observed process boundary", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$predecessor$root, fixture$source_dir),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(unlink(fixture$dll), add = TRUE)
  unlink(file.path(fixture$root, "no-fit-result.rds"))
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$child_pid <- NA_integer_
  process$exit_status <- 139L
  process$child_result_md5 <- NA_character_
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$status <- "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  receipt$reason <- "child_process_no_result"
  receipt$dll <- list(path = NA_character_, md5 = NA_character_)
  receipt$process <- process
  receipt$child_result_md5 <- NA_character_
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  files <- contract$.spde_slope_gauge_nofit_gate_files(FALSE)
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(fixture$root, declared)))
    ),
    file.path(fixture$root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  verdict <- contract$spde_slope_gauge_nofit_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    fixture$predecessor$locked,
    commit = "synthetic-commit"
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
  expect_null(verdict$child)
  expect_identical(verdict$receipt$reason, "child_process_no_result")
})

spde_slope_gauge_nofit_v2_gate_fixture <- function(contract) {
  v1 <- spde_slope_gauge_nofit_v1_forensic_fixture()
  v3 <- spde_slope_gauge_nofit_fixture(contract)
  root <- tempfile(
    ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-",
    tmpdir = dirname(tempfile())
  )
  dir.create(root)
  root <- normalizePath(root, mustWork = TRUE)
  source_dir <- testthat::test_path("..", "..", "dev", "isdm-package-recovery")
  source_paths <- c(
    child_runner = file.path(
      source_dir,
      "run-paper1-spde-slope-gauge-nofit-v2.R"
    ),
    pure_contract = file.path(source_dir, "spde-slope-gauge-contract.R"),
    nofit_contract = file.path(source_dir, "spde-slope-gauge-nofit-contract.R"),
    historical_contract = v3$locked$historical_contract_path,
    design = file.path(
      source_dir,
      "2026-08-15-paper1-spde-slope-gauge-coordinate-design.md"
    ),
    materializer = file.path(
      source_dir,
      "materialize-paper1-spde-slope-gauge-nofit-v2-gate.R"
    )
  )
  dll <- tempfile("spde-slope-gauge-v2-dll-")
  writeLines("synthetic V2 DLL", dll)
  dll <- list(
    path = normalizePath(dll),
    md5 = unname(tools::md5sum(dll))[[1L]]
  )
  v1_verdict <- contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
    v1$root,
    v1$locked
  )
  v3_verdict <- contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    v3$root,
    v3$locked
  )
  parent_pid <- 31001L
  child <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_CHILD_V1",
    parent_pid = parent_pid,
    child_pid = 31002L,
    started_at = "2026-08-15 00:00:00 UTC",
    deadline_s = 1800,
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    reason = "historical_v3_replay_failure",
    stage = "historical",
    predecessor = c(
      v3_verdict[c("root", "commit", "receipt", "state_md5")],
      list(
        v1_forensic = v1_verdict[c(
          "root",
          "commit",
          "receipt",
          "files",
          "status",
          "terminal_reason"
        )],
        historical_reason = NA_character_,
        post_replay_gc = FALSE
      )
    ),
    dll = dll,
    object = list(created = 0L, released = 0L),
    nofit = NULL,
    callback_audit = NULL,
    error = "synthetic historical replay failure",
    ended_at = "2026-08-15 00:00:01 UTC",
    elapsed_s = 1
  )
  saveRDS(child, file.path(root, "no-fit-result.rds"))
  stage <- file.path(
    dirname(root),
    ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-synthetic"
  )
  parent_stage <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_PARENT_STAGE_V1",
    gate_base = dirname(root),
    stage = stage,
    parent_pid = parent_pid,
    child_output = file.path(stage, "child-result.rds")
  )
  writeLines("synthetic V2 child stdout", file.path(root, "child-stdout.txt"))
  writeLines("synthetic V2 child stderr", file.path(root, "child-stderr.txt"))
  process <- list(
    schema = contract$.spde_slope_gauge_nofit_v2_process_schema(),
    command = R.home("bin/Rscript"),
    arguments = c(
      "--vanilla",
      source_paths[["child_runner"]],
      "child",
      parent_stage$child_output,
      as.character(parent_pid)
    ),
    parent_pid = parent_pid,
    child_pid = child$child_pid,
    observed_child_pid = child$child_pid,
    started_at = child$started_at,
    ended_at = child$ended_at,
    elapsed_s = 1,
    deadline_s = 1800,
    timed_out = FALSE,
    exit_status = 0L,
    signal = NA_character_,
    stdout_md5 = unname(tools::md5sum(file.path(
      root,
      "child-stdout.txt"
    ))[[1L]]),
    stderr_md5 = unname(tools::md5sum(file.path(
      root,
      "child-stderr.txt"
    ))[[1L]]),
    child_result_md5 = unname(tools::md5sum(file.path(
      root,
      "no-fit-result.rds"
    ))[[1L]])
  )
  saveRDS(process, file.path(root, "child-receipt.rds"))
  file.copy(source_paths[["materializer"]], file.path(root, "materializer.R"))
  saveRDS(list(session = "synthetic V2"), file.path(root, "session-info.rds"))
  writeLines(
    "synthetic V2 no-fit time estimate",
    file.path(root, "time-estimate.md")
  )
  receipt <- list(
    schema = contract$.spde_slope_gauge_nofit_v2_gate_schema(),
    gate = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2",
    root = root,
    commit = "synthetic-v2-commit",
    status = child$status,
    reason = child$reason,
    predecessors = contract$.spde_slope_gauge_nofit_v2_predecessor_projection(
      v1_verdict,
      v3_verdict
    ),
    sources = stats::setNames(
      unname(tools::md5sum(source_paths)),
      names(source_paths)
    ),
    dll = dll,
    controls = contract$spde_slope_gauge_no_fit_controls(),
    parent_stage = parent_stage,
    process = process,
    child_result_md5 = process$child_result_md5,
    unvalidated_child_md5 = NA_character_,
    seal_failure = NA_character_,
    time_estimate_md5 = unname(tools::md5sum(file.path(
      root,
      "time-estimate.md"
    ))[[1L]])
  )
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  dir.create(file.path(root, ".attempt-started.claim"))
  files <- contract$.spde_slope_gauge_nofit_v2_gate_files(TRUE)
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(root, declared)))
    ),
    file.path(root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  list(
    root = root,
    source_paths = source_paths,
    v1 = v1,
    v3 = v3,
    dll_path = dll$path,
    child = child
  )
}

spde_slope_gauge_nofit_v2_refresh_manifest <- function(contract, root) {
  files <- contract$.spde_slope_gauge_nofit_v2_gate_files(
    file.exists(file.path(root, "no-fit-result.rds")),
    file.exists(file.path(root, "unvalidated-child-result.rds"))
  )
  declared <- setdiff(files, "file-manifest.csv")
  utils::write.csv(
    data.frame(
      path = declared,
      md5 = unname(tools::md5sum(file.path(root, declared)))
    ),
    file.path(root, "file-manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}

spde_slope_gauge_nofit_v2_contract_materializer_env <- function() {
  path <- testthat::test_path(
    "..",
    "..",
    "dev",
    "isdm-package-recovery",
    "materialize-paper1-spde-slope-gauge-nofit-v2-gate.R"
  )
  old_source <- Sys.getenv(
    "SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY",
    unset = NA_character_
  )
  old_path <- Sys.getenv(
    "SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH",
    unset = NA_character_
  )
  Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY = "1")
  Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH = path)
  on.exit(
    {
      if (is.na(old_source)) {
        Sys.unsetenv("SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY")
      } else {
        Sys.setenv(
          SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY = old_source
        )
      }
      if (is.na(old_path)) {
        Sys.unsetenv("SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH")
      } else {
        Sys.setenv(SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH = old_path)
      }
    },
    add = TRUE
  )
  env <- new.env(parent = globalenv())
  source(path, local = env)
  env
}

test_that("the V2 parent validator accepts a complete infrastructure packet", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v2_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$v1$root, fixture$v3$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll_path, fixture$v3$historical_contract)),
    add = TRUE
  )
  verdict <- contract$spde_slope_gauge_nofit_v2_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    commit = "synthetic-v2-commit",
    v1_locked = fixture$v1$locked,
    v3_locked = fixture$v3$locked,
    expected_root = fixture$root
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
  expect_identical(verdict$reason, "v2_gate_root_valid")
})

test_that("the V2 parent validator accepts a fully validated sibling staging packet", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v2_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$v1$root, fixture$v3$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll_path, fixture$v3$historical_contract)),
    add = TRUE
  )
  final_root <- file.path(
    normalizePath(dirname(fixture$root), mustWork = TRUE),
    "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-sealed"
  )
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$root <- final_root
  receipt$parent_stage$stage <- fixture$root
  receipt$parent_stage$child_output <- file.path(
    fixture$root,
    "child-result.rds"
  )
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$arguments[[4L]] <- receipt$parent_stage$child_output
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt$process <- process
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  spde_slope_gauge_nofit_v2_refresh_manifest(contract, fixture$root)
  verdict <- contract$spde_slope_gauge_nofit_v2_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    commit = "synthetic-v2-commit",
    v1_locked = fixture$v1$locked,
    v3_locked = fixture$v3$locked,
    expected_root = final_root
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
})

test_that("the V2 parent validator seals a non-reporting child from observed process evidence", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v2_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$v1$root, fixture$v3$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll_path, fixture$v3$historical_contract)),
    add = TRUE
  )
  unlink(file.path(fixture$root, "no-fit-result.rds"))
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$child_pid <- NA_integer_
  process$exit_status <- 139L
  process$child_result_md5 <- NA_character_
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$status <- "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  receipt$reason <- "child_process_no_result"
  receipt$dll <- list(path = NA_character_, md5 = NA_character_)
  receipt$process <- process
  receipt$child_result_md5 <- NA_character_
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  spde_slope_gauge_nofit_v2_refresh_manifest(contract, fixture$root)
  verdict <- contract$spde_slope_gauge_nofit_v2_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    commit = "synthetic-v2-commit",
    v1_locked = fixture$v1$locked,
    v3_locked = fixture$v3$locked,
    expected_root = fixture$root
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
  expect_null(verdict$child)
  expect_identical(verdict$receipt$reason, "child_process_no_result")
})

test_that("the V2 parent validator seals unvalidated child bytes as a forensic terminal", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v2_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$v1$root, fixture$v3$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll_path, fixture$v3$historical_contract)),
    add = TRUE
  )
  validated <- file.path(fixture$root, "no-fit-result.rds")
  unvalidated <- file.path(fixture$root, "unvalidated-child-result.rds")
  expect_true(file.rename(validated, unvalidated))
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$child_pid <- NA_integer_
  process$child_result_md5 <- NA_character_
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$status <- "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  receipt$reason <- "parent_seal_failure"
  receipt$dll <- list(path = NA_character_, md5 = NA_character_)
  receipt$process <- process
  receipt$child_result_md5 <- NA_character_
  receipt$unvalidated_child_md5 <- unname(tools::md5sum(unvalidated))[[1L]]
  receipt$seal_failure <- "synthetic parent receipt write failure"
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  spde_slope_gauge_nofit_v2_refresh_manifest(contract, fixture$root)
  verdict <- contract$spde_slope_gauge_nofit_v2_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    commit = "synthetic-v2-commit",
    v1_locked = fixture$v1$locked,
    v3_locked = fixture$v3$locked,
    expected_root = fixture$root
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
  expect_null(verdict$child)
  expect_identical(verdict$receipt$reason, "parent_seal_failure")
})

test_that("the V2 parent validator retains a no-result parent sealing failure", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v2_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$v1$root, fixture$v3$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll_path, fixture$v3$historical_contract)),
    add = TRUE
  )
  unlink(file.path(fixture$root, "no-fit-result.rds"))
  process <- readRDS(file.path(fixture$root, "child-receipt.rds"))
  process$child_pid <- NA_integer_
  process$observed_child_pid <- NA_integer_
  process$exit_status <- NA_integer_
  process$child_result_md5 <- NA_character_
  saveRDS(process, file.path(fixture$root, "child-receipt.rds"))
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$status <- "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  receipt$reason <- "parent_seal_failure"
  receipt$dll <- list(path = NA_character_, md5 = NA_character_)
  receipt$process <- process
  receipt$child_result_md5 <- NA_character_
  receipt$unvalidated_child_md5 <- NA_character_
  receipt$seal_failure <- "synthetic receipt-write failure"
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  spde_slope_gauge_nofit_v2_refresh_manifest(contract, fixture$root)
  verdict <- contract$spde_slope_gauge_nofit_v2_validate_gate_root(
    fixture$root,
    fixture$source_paths,
    commit = "synthetic-v2-commit",
    v1_locked = fixture$v1$locked,
    v3_locked = fixture$v3$locked,
    expected_root = fixture$root
  )
  expect_true(
    verdict$valid,
    info = paste(names(verdict$checks)[!verdict$checks], collapse = ", ")
  )
  expect_null(verdict$child)
  expect_identical(verdict$receipt$reason, "parent_seal_failure")
  expect_identical(
    verdict$receipt$seal_failure,
    "synthetic receipt-write failure"
  )
})

test_that("the production V2 forensic sealer satisfies the real validator", {
  contract <- spde_slope_gauge_nofit_contract_env()
  materializer <- spde_slope_gauge_nofit_v2_contract_materializer_env()
  seal_one <- function(retain_child_bytes) {
    fixture <- spde_slope_gauge_nofit_v2_gate_fixture(contract)
    on.exit(
      unlink(
        c(fixture$root, fixture$v1$root, fixture$v3$root),
        recursive = TRUE
      ),
      add = TRUE
    )
    on.exit(
      unlink(c(fixture$dll_path, fixture$v3$historical_contract)),
      add = TRUE
    )
    if (!isTRUE(retain_child_bytes)) {
      unlink(file.path(fixture$root, "no-fit-result.rds"))
    }
    receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
    token <- receipt$parent_stage
    v1 <- contract$spde_slope_gauge_nofit_v2_validate_v1_forensic(
      fixture$v1$root,
      fixture$v1$locked
    )
    v3 <- contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
      fixture$v3$root,
      fixture$v3$locked
    )
    sealed <- materializer$.spde_slope_gauge_nofit_v2_forensic_seal(
      fixture$root,
      fixture$root,
      fixture$source_paths,
      commit = "synthetic-v2-commit",
      v1 = v1,
      v3 = v3,
      token = token,
      child_run = list(
        process = NULL,
        child = NULL,
        output = token$child_output
      ),
      seal_failure = if (isTRUE(retain_child_bytes)) {
        "synthetic post-rename retained-child failure"
      } else {
        "synthetic post-rename no-child failure"
      },
      validator = contract$spde_slope_gauge_nofit_v2_validate_gate_root,
      v1_locked = fixture$v1$locked,
      v3_locked = fixture$v3$locked
    )
    expect_true(
      sealed$valid,
      info = paste(names(sealed$checks)[!sealed$checks], collapse = ", ")
    )
    expect_identical(sealed$receipt$reason, "parent_seal_failure")
    expect_identical(
      file.exists(file.path(fixture$root, "unvalidated-child-result.rds")),
      isTRUE(retain_child_bytes)
    )
  }
  seal_one(FALSE)
  seal_one(TRUE)
})

test_that("the V2 parent validator rejects coordinated source and predecessor tampering", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_v2_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$v1$root, fixture$v3$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll_path, fixture$v3$historical_contract)),
    add = TRUE
  )
  validate <- function() {
    contract$spde_slope_gauge_nofit_v2_validate_gate_root(
      fixture$root,
      fixture$source_paths,
      commit = "synthetic-v2-commit",
      v1_locked = fixture$v1$locked,
      v3_locked = fixture$v3$locked,
      expected_root = fixture$root
    )
  }
  receipt <- readRDS(file.path(fixture$root, "root-receipt.rds"))
  receipt$predecessors$v1_forensic$receipt <- list(forged = TRUE)
  saveRDS(receipt, file.path(fixture$root, "root-receipt.rds"))
  spde_slope_gauge_nofit_v2_refresh_manifest(contract, fixture$root)
  expect_false(validate()$valid)

  fixture <- spde_slope_gauge_nofit_v2_gate_fixture(contract)
  on.exit(
    unlink(
      c(fixture$root, fixture$v1$root, fixture$v3$root),
      recursive = TRUE
    ),
    add = TRUE
  )
  on.exit(
    unlink(c(fixture$dll_path, fixture$v3$historical_contract)),
    add = TRUE
  )
  writeLines("tampered materializer", file.path(fixture$root, "materializer.R"))
  spde_slope_gauge_nofit_v2_refresh_manifest(contract, fixture$root)
  expect_false(validate()$valid)
})
