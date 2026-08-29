campaign_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "campaign.R"
)
source(campaign_path, local = TRUE, chdir = TRUE)
summary_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "summarise.R"
)
source(summary_path, local = TRUE, chdir = TRUE)

.mock_identity <- function() list(
  source_sha = "approved", source_tree = "tree", worktree_status = character(),
  source_hashes = c(a = "hash"), package_path = "/package",
  library_paths = "/library",
  package_version = "0.0.0", package_hashes = c(DESCRIPTION = "packagehash"),
  dll_path = "/dll", dll_sha256 = "dllhash"
)

.mock_contract <- function(source_sha = "approved") {
  identity <- .mock_identity()
  identity$source_sha <- source_sha
  ci <- list(
    schema = "isdm-ci-receipt-v1", verified = TRUE, conclusion = "success",
    head_sha = source_sha,
    run_url = "https://github.com/example/gllvmTMB/actions/runs/1",
    platform_conclusions = c(linux = "success", macos = "success",
                             windows = "success")
  )
  install <- c(list(schema = "isdm-install-receipt-v1"), identity[c(
    "source_sha", "source_tree", "package_path", "package_version",
    "package_hashes", "dll_path", "dll_sha256"
  )])
  c(identity, list(schema = "isdm-source-contract-v2", ci_receipt = ci,
                   install_receipt = install, ci_url = ci$run_url,
                   ci_conclusion = ci$conclusion))
}

.mock_prepare <- function(task) list(
  task = task, fixture = list(truth = list(beta = 1)), formula = value ~ 1
)

test_that("campaign runner retains a started and successful terminal record", {
  root <- tempfile("isdm-campaign-")
  record <- isdm_run_task(
    "ordinary", 1L, root, expected_sha = "approved", expected_tree = "tree",
    source_contract = .mock_contract(),
    identity_fn = .mock_identity, prepare_fn = .mock_prepare,
    fit_fn = function(prepared) list(
      diagnostics = list(convergence = 0L), estimate = list(beta = 1),
      truth = c(prepared$fixture$truth, list(fixed = c(beta = 1))),
      design = list(mock = TRUE)
    )
  )
  expect_identical(record$status, "fit_returned")
  expect_true(file.exists(file.path(root, "started", "task-000001.rds")))
  expect_true(file.exists(file.path(root, "attempts", "task-000001.rds")))
  expect_identical(readRDS(file.path(root, "started", "task-000001.rds"))$status,
                   "started")
  expect_identical(sum(names(record) == "truth"), 1L)
  expect_identical(record$truth$fixed, c(beta = 1))
})

test_that("SHA-256 hashing handles workspace paths containing spaces", {
  root <- tempfile("isdm hash space ")
  dir.create(root)
  paths <- file.path(root, c("first file", "second file"))
  Map(writeLines, c("one", "two"), paths)
  hashes <- isdm_sha256(paths)
  expect_identical(names(hashes), normalizePath(paths))
  expect_true(all(grepl("^[[:xdigit:]]{64}$", hashes)))
})

test_that("the retained pre-run plan dispatches every registered route", {
  plan <- isdm_prerun_plan()
  tasks <- lapply(plan$task_id, function(id) isdm_campaign_task("prerun", id))
  expect_identical(vapply(tasks, function(x) x$programme[[1L]], character(1L)),
                   plan$programme)
  expect_true(all(plan$programme %in% c("ordinary", "attack", "spatial", "interval")))
})

test_that("source mismatch is terminal unavailable and never fitted", {
  root <- tempfile("isdm-campaign-")
  called <- FALSE
  record <- isdm_run_task(
    "ordinary", 1L, root, expected_sha = "different", expected_tree = "tree",
    source_contract = .mock_contract("different"),
    identity_fn = .mock_identity, prepare_fn = .mock_prepare,
    fit_fn = function(prepared) { called <<- TRUE }
  )
  expect_false(called)
  expect_identical(record$status, "unavailable")
  expect_true("isdm_source_unavailable" %in% record$error_class)

  plan <- isdm_point_plan("ordinary")[1L, , drop = FALSE]
  ledger <- isdm_attempt_ledger(
    root, plan, source_contract = .mock_contract("different")
  )
  denominators <- isdm_denominators(ledger)
  expect_true(ledger$terminal)
  expect_identical(ledger$status, "unavailable")
  expect_false(ledger$eligible)
  expect_identical(denominators$unavailable, 1L)
})

test_that("fixture or environment failure is retained as unavailable", {
  root <- tempfile("isdm-campaign-")
  record <- isdm_run_task(
    "ordinary", 1L, root, expected_sha = "approved", expected_tree = "tree",
    source_contract = .mock_contract(),
    identity_fn = .mock_identity,
    prepare_fn = function(task) stop(structure(
      list(message = "fmesher unavailable", call = NULL),
      class = c("mock_environment_unavailable", "error", "condition"))),
    fit_fn = function(prepared) stop("must not run")
  )
  expect_identical(record$status, "unavailable")
  expect_true("mock_environment_unavailable" %in% record$error_class)
})

test_that("identity collection failure still creates started and terminal receipts", {
  root <- tempfile("isdm-campaign-")
  record <- isdm_run_task(
    "ordinary", 1L, root, source_contract = .mock_contract(),
    identity_fn = function() stop("git unavailable"),
    prepare_fn = .mock_prepare,
    fit_fn = function(prepared) stop("must not run")
  )
  expect_identical(record$status, "unavailable")
  expect_true(file.exists(file.path(root, "started", "task-000001.rds")))
  expect_true(file.exists(file.path(root, "attempts", "task-000001.rds")))
  expect_identical(record$error_message, "git unavailable")
})

test_that("corrupt or unqualified source contracts are retained as unavailable", {
  root <- tempfile("isdm-campaign-")
  corrupt <- tempfile(fileext = ".rds")
  writeLines("not an RDS", corrupt)
  withr::local_envvar(ISDM_SOURCE_CONTRACT_RDS = corrupt)
  record <- isdm_run_task(
    "ordinary", 1L, root, identity_fn = .mock_identity,
    prepare_fn = .mock_prepare, fit_fn = function(prepared) stop("must not run")
  )
  expect_identical(record$status, "unavailable")
  expect_true(file.exists(file.path(root, "started", "task-000001.rds")))
  expect_true(file.exists(file.path(root, "attempts", "task-000001.rds")))

  root2 <- tempfile("isdm-campaign-")
  record2 <- isdm_run_task(
    "ordinary", 1L, root2, source_contract = .mock_identity(),
    identity_fn = .mock_identity, prepare_fn = .mock_prepare,
    fit_fn = function(prepared) stop("must not run")
  )
  expect_identical(record2$status, "unavailable")
  expect_true("isdm_source_contract_invalid" %in% record2$error_class)

  root3 <- tempfile("isdm-campaign-")
  wrong_type <- tempfile(fileext = ".rds")
  saveRDS("bad", wrong_type)
  withr::local_envvar(ISDM_SOURCE_CONTRACT_RDS = wrong_type)
  record3 <- isdm_run_task(
    "ordinary", 1L, root3, identity_fn = .mock_identity,
    prepare_fn = .mock_prepare, fit_fn = function(prepared) stop("must not run")
  )
  expect_identical(record3$status, "unavailable")
  expect_true(file.exists(file.path(root3, "attempts", "task-000001.rds")))
  expect_true("isdm_source_contract_invalid" %in% record3$error_class)
})

test_that("missing or malformed CI URLs cannot qualify a source contract", {
  for (bad_url in list(NA_character_, "", "not-a-url")) {
    root <- tempfile("isdm-campaign-")
    called <- FALSE
    contract <- .mock_contract()
    contract$ci_url <- bad_url
    record <- isdm_run_task(
      "ordinary", 1L, root, source_contract = contract,
      identity_fn = .mock_identity, prepare_fn = .mock_prepare,
      fit_fn = function(prepared) { called <<- TRUE }
    )
    expect_false(called)
    expect_identical(record$status, "unavailable")
    expect_true("isdm_source_contract_invalid" %in% record$error_class)
  }
})

test_that("changed source hashes stop an otherwise matching SHA and tree", {
  root <- tempfile("isdm-campaign-")
  changed <- .mock_identity()
  changed$source_hashes[[1L]] <- "changed"
  record <- isdm_run_task(
    "ordinary", 1L, root, source_contract = .mock_contract(),
    identity_fn = function() changed, prepare_fn = .mock_prepare,
    fit_fn = function(prepared) stop("must not run")
  )
  expect_identical(record$status, "unavailable")
  expect_true("isdm_source_unavailable" %in% record$error_class)
})

test_that("fit errors retain truth, identity, and terminal error", {
  root <- tempfile("isdm-campaign-")
  record <- isdm_run_task(
    "ordinary", 1L, root, expected_sha = "approved", expected_tree = "tree",
    source_contract = .mock_contract(),
    identity_fn = .mock_identity, prepare_fn = .mock_prepare,
    fit_fn = function(prepared) stop(structure(
      list(message = "optimizer failed", call = NULL),
      class = c("mock_fit_error", "error", "condition")))
  )
  expect_identical(record$status, "error")
  expect_true("mock_fit_error" %in% record$error_class)
  expect_identical(record$truth$beta, 1)
  expect_identical(record$source_sha, "approved")
})

test_that("controlled interrupts receive their own terminal status", {
  root <- tempfile("isdm-campaign-")
  record <- isdm_run_task(
    "ordinary", 1L, root, expected_sha = "approved", expected_tree = "tree",
    source_contract = .mock_contract(),
    identity_fn = .mock_identity, prepare_fn = .mock_prepare,
    fit_fn = function(prepared) stop(structure(
      list(message = "user interrupt", call = NULL),
      class = c("interrupt", "condition")))
  )
  expect_identical(record$status, "interrupted")
  expect_true("interrupt" %in% record$error_class)
})

test_that("fit warnings are retained in terminal records", {
  root <- tempfile("isdm-campaign-")
  record <- isdm_run_task(
    "ordinary", 1L, root, source_contract = .mock_contract(),
    identity_fn = .mock_identity, prepare_fn = .mock_prepare,
    fit_fn = function(prepared) {
      warning("weak support diagnostic")
      list(diagnostics = list(), estimate = list(), truth = list(), design = list())
    }
  )
  expect_identical(record$warnings, "weak support diagnostic")
})

test_that("production runner refuses replacement attempts", {
  root <- tempfile("isdm-campaign-")
  run <- function() isdm_run_task(
    "ordinary", 1L, root, expected_sha = "approved", expected_tree = "tree",
    source_contract = .mock_contract(),
    identity_fn = .mock_identity, prepare_fn = .mock_prepare,
    fit_fn = function(prepared) list(diagnostics = list(), estimate = list(),
                                     truth = list(), design = list())
  )
  expect_no_error(run())
  expect_error(run(), class = "isdm_attempt_already_exists")
})

test_that("tiny mixed-law fixture fits and extracts only through public routes", {
  skip_if_not_installed("TMB")
  task <- isdm_point_plan("ordinary")[1L, , drop = FALSE]
  task$n_cells <- 60L
  prepared <- isdm_prepare_task(task)
  result <- isdm_fit_public_task(prepared)
  expect_identical(result$diagnostics$convergence, 0L)
  expect_true(is.finite(result$diagnostics$objective))
  expect_true(all(is.finite(result$estimate$fixed)))
  expect_true(all(is.finite(result$estimate$Sigma)))
  expect_true(all(is.finite(result$estimate$Psi)))
  expect_equal(length(result$estimate$surface), 60L * 3L)
})

test_that("tiny public spatial route exercises the typed out-of-hull oracle", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")
  task <- isdm_point_plan("spatial")[1L, , drop = FALSE]
  task$n_cells <- 64L
  result <- isdm_fit_public_task(isdm_prepare_task(task))
  expect_identical(result$diagnostics$convergence, 0L)
  expect_lte(result$estimate$training_identity_error, 1e-10)
  expect_true(result$estimate$out_of_hull_warning_ok)
  expect_true(all(is.finite(result$estimate$heldout_surface)))
})
