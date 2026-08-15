spde_slope_gauge_nofit_contract_env <- function() {
  env <- new.env(parent = baseenv())
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-contract.R"
  ), local = env)
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-nofit-contract.R"
  ), local = env)
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
    schema = "SYNTHETIC_STATE_V1", objective = 1.25, theta = theta,
    gradient = stats::setNames(rep(0, 22L), order), convergence = 0L,
    covariance = list(), start_provenance = list(), restart_history = data.frame(x = 1),
    warm_restart_provenance = list(), isdm_polish_provenance = list(),
    parameters = list(), map = list(), data = list(), random = "g_spde_slope",
    block_labels = rep("theta", 22L), parameter_order = order
  )
  receipt <- list(
    schema = "SYNTHETIC_RECEIPT_V1", source_gate = "SYNTHETIC", root = root,
    commit = "synthetic-commit", consumed_v2 = list(), runner_md5 = paste0(rep("1", 32), collapse = ""),
    contract_md5 = paste0(rep("2", 32), collapse = ""), design_md5 = paste0(rep("3", 32), collapse = "")
  )
  saveRDS(list(terminal = TRUE), file.path(root, "all-attempt-ledger.rds"))
  saveRDS(list(started = TRUE), file.path(root, "attempt-started.rds"))
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  saveRDS(list(session = TRUE), file.path(root, "session-info.rds"))
  saveRDS(state, file.path(root, "v2-materialized-state.rds"))
  writeLines("synthetic no-fit estimate", file.path(root, "time-estimate.md"))
  declared <- c(
    "all-attempt-ledger.rds", "attempt-started.rds", "root-receipt.rds",
    "session-info.rds", "time-estimate.md", "v2-materialized-state.rds"
  )
  hashes <- unname(tools::md5sum(file.path(root, declared)))
  utils::write.csv(data.frame(path = declared, md5 = hashes), file.path(root, "file-manifest.csv"),
    row.names = FALSE, quote = TRUE)
  files <- c(stats::setNames(hashes, declared),
    "file-manifest.csv" = unname(tools::md5sum(file.path(root, "file-manifest.csv"))[[1L]]))
  locked <- list(root = root, commit = "synthetic-commit", files = files,
    directories = ".attempt-started.claim",
    receipt_schema = "SYNTHETIC_RECEIPT_V1", state_schema = "SYNTHETIC_STATE_V1")
  list(root = root, locked = locked, state = state)
}

spde_slope_gauge_nofit_refresh_manifest <- function(fixture) {
  declared <- setdiff(names(fixture$locked$files), "file-manifest.csv")
  hashes <- unname(tools::md5sum(file.path(fixture$root, declared)))
  utils::write.csv(data.frame(path = declared, md5 = hashes),
    file.path(fixture$root, "file-manifest.csv"), row.names = FALSE, quote = TRUE)
  fixture$locked$files[declared] <- hashes
  fixture$locked$files[["file-manifest.csv"]] <-
    unname(tools::md5sum(file.path(fixture$root, "file-manifest.csv"))[[1L]])
  fixture
}

test_that("the no-fit predecessor byte gate accepts a complete regular synthetic packet", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  verdict <- contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )
  expect_true(verdict$valid)
  expect_identical(verdict$reason, "predecessor_bytes_valid")
  expect_identical(verdict$state, fixture$state)
  expect_identical(verdict$state_md5, fixture$locked$files[["v2-materialized-state.rds"]])
})

test_that("the no-fit predecessor gate rejects stale manifests, extra files, and state order drift", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)

  writeLines("extra", file.path(fixture$root, "extra.txt"))
  expect_identical(contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )$reason, "predecessor_packet_bytes_invalid")
  unlink(file.path(fixture$root, "extra.txt"))

  writeLines("not empty", file.path(fixture$root, ".attempt-started.claim", "extra.txt"))
  expect_identical(contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )$reason, "predecessor_packet_bytes_invalid")
  unlink(file.path(fixture$root, ".attempt-started.claim", "extra.txt"))

  state <- readRDS(file.path(fixture$root, "v2-materialized-state.rds"))
  state$theta <- stats::setNames(state$theta, rev(names(state$theta)))
  saveRDS(state, file.path(fixture$root, "v2-materialized-state.rds"))
  fixture <- spde_slope_gauge_nofit_refresh_manifest(fixture)
  expect_identical(contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )$reason, "predecessor_receipt_or_state_invalid")
})

test_that("the no-fit predecessor gate reaches manifest semantics after coordinated packet bytes", {
  contract <- spde_slope_gauge_nofit_contract_env()
  fixture <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  manifest <- utils::read.csv(file.path(fixture$root, "file-manifest.csv"), stringsAsFactors = FALSE)
  manifest <- manifest[rev(seq_len(nrow(manifest))), , drop = FALSE]
  utils::write.csv(manifest, file.path(fixture$root, "file-manifest.csv"), row.names = FALSE, quote = TRUE)
  fixture$locked$files[["file-manifest.csv"]] <-
    unname(tools::md5sum(file.path(fixture$root, "file-manifest.csv"))[[1L]])
  expect_identical(contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )$reason, "predecessor_packet_bytes_invalid")
})

test_that("the no-fit predecessor gate rejects missing or nonempty claim directories", {
  contract <- spde_slope_gauge_nofit_contract_env()
  missing <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(missing$root, recursive = TRUE), add = TRUE)
  unlink(file.path(missing$root, ".attempt-started.claim"), recursive = TRUE)
  expect_identical(contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    missing$root, missing$locked
  )$reason, "predecessor_packet_bytes_invalid")

  nonempty <- spde_slope_gauge_nofit_fixture(contract)
  on.exit(unlink(nonempty$root, recursive = TRUE), add = TRUE)
  writeLines("unexpected", file.path(nonempty$root, ".attempt-started.claim", "nested.txt"))
  expect_identical(contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    nonempty$root, nonempty$locked
  )$reason, "predecessor_packet_bytes_invalid")
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
  if (!file.symlink(target, path)) skip("symlinks unavailable on this platform")
  expect_identical(contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )$reason, "predecessor_packet_bytes_invalid")
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
  if (!file.symlink(target, path)) skip("directory symlinks unavailable on this platform")
  expect_identical(contract$spde_slope_gauge_nofit_validate_predecessor_bytes(
    fixture$root, fixture$locked
  )$reason, "predecessor_packet_bytes_invalid")
})
