receipt_dir <- testthat::test_path("..", "..", "dev", "isdm-requalification",
                                  "diagnostic-rescue")
source(file.path(receipt_dir, "verify-remote-receipt.R"), local = TRUE)
source(file.path(receipt_dir, "summarise-independent.R"), local = TRUE)

.receipt_test_plan <- function() {
  non_native <- rep(seq_len(8L), each = 2L)
  non <- data.frame(
    task_id = 1:16, slice = "nonspatial", native_task_id = non_native,
    seed = 1000L + non_native, n_sources = rep(c(2L, 3L), each = 8L),
    overlap = rep(rep(c("full", "weak"), each = 2L), 4L),
    n_cells = rep(c(150L, 810L), each = 4L, times = 2L),
    variant = rep(c("baseline", "rep3"), 8L),
    sentinel_class = "paired_min_pair", stringsAsFactors = FALSE
  )
  spatial_native <- rep(101:112, each = 3L)
  classes <- rep(rep(c("converged_pd", "converged_nonpd",
                       "nonconverged_nonpd"), each = 3L), 4L)
  spatial <- data.frame(
    task_id = 17:52, slice = "spatial", native_task_id = spatial_native,
    seed = 2000L + spatial_native,
    n_sources = rep(c(2L, 3L), each = 18L),
    overlap = rep(c("full", "weak"), each = 9L, times = 2L), n_cells = 810L,
    variant = rep(c("default", "bfgs_continuation", "nlminb5"), 12L),
    sentinel_class = classes, stringsAsFactors = FALSE
  )
  rbind(non, spatial)
}

.receipt_test_curvature <- function() list(
  available = TRUE, joint_precision = list(available = TRUE),
  attribution = list(
    ranking_agrees = FALSE,
    relative = list(smallest_algebraic = list(block_mass = data.frame(
      block = c("b_fix", "other"), n = c(2L, 2L), M = c(.6, .4),
      A = c(.3, .2), N = c(.6, .4), stringsAsFactors = FALSE
    )))
  )
)

.receipt_test_record <- function(task) {
  spatial <- identical(task$slice[[1L]], "spatial")
  list(
    schema = "isdm-identifiability-diagnostic-v1",
    task_id = as.integer(task$task_id[[1L]]), task = as.list(task),
    status = "fit_returned", disposition_source = "worker",
    source_sha = .receipt_sha, source_tree = .receipt_tree,
    harness_manifest_sha256 = strrep("a", 64L), optimizer_entered = TRUE,
    diagnostics = list(convergence = if (spatial) 1L else 0L,
                       pd_hessian = !spatial, fresh_objective = 10,
                       max_gradient = .1),
    curvature = .receipt_test_curvature(),
    metrics = if (spatial) list(
      heldout = list(correlation = .9, normalized_rmse = .4)
    ) else list(
      fixed = list(correlation = .8, normalized_rmse = .6),
      shared = list(correlation = .8, normalized_rmse = .6),
      full = list(correlation = .8, normalized_rmse = .6),
      Sigma_relative_frobenius = .2,
      Psi_relative_error = c(sp1 = .3, sp2 = .2, sp3 = .2)
    )
  )
}

.receipt_test_run <- function(root) {
  plan <- .receipt_test_plan()
  saveRDS(plan, file.path(root, "plan.rds"))
  dir.create(file.path(root, "output", "attempts"), recursive = TRUE)
  dir.create(file.path(root, "output", "started"), recursive = TRUE)
  for (i in seq_len(nrow(plan))) {
    leaf <- sprintf("task-%06d.rds", plan$task_id[[i]])
    saveRDS(.receipt_test_record(plan[i, , drop = FALSE]),
            file.path(root, "output", "attempts", leaf))
    saveRDS(list(task_id = plan$task_id[[i]], status = "started"),
            file.path(root, "output", "started", leaf))
  }
  plan
}

.receipt_test_manifest <- function(bundle) {
  files <- sort(list.files(bundle, recursive = TRUE, all.files = TRUE,
                           no.. = TRUE, include.dirs = FALSE))
  files <- setdiff(files, "MANIFEST.sha256")
  hashes <- vapply(file.path(bundle, files), .receipt_hash, character(1L))
  writeLines(sprintf("%s  %s", hashes, files),
             file.path(bundle, "MANIFEST.sha256"))
}

test_that("pure reader retains all denominators and yields MIXED without a signal", {
  root <- withr::local_tempdir()
  plan <- .receipt_test_run(root)
  summary <- isdm_diag_independent_summary(file.path(root, "plan.rds"),
                                           file.path(root, "output"))
  expect_identical(summary$denominators$planned, 52L)
  expect_identical(summary$denominators$started, 52L)
  expect_identical(summary$denominators$terminal, 52L)
  expect_identical(unname(summary$denominators$status["fit_returned"]), 52L)
  expect_identical(summary$denominators$nonspatial_pairs_available, 8L)
  expect_identical(summary$denominators$spatial_ineligible_planned, 8L)
  expect_false(any(summary$signals))
  expect_identical(summary$next_action, "MIXED")
  expect_equal(nrow(plan), 52L)
})

test_that("pure reader rejects a missing or duplicate disposition", {
  root <- withr::local_tempdir()
  .receipt_test_run(root)
  unlink(file.path(root, "output", "attempts", "task-000052.rds"))
  expect_error(isdm_diag_independent_summary(file.path(root, "plan.rds"),
                                             file.path(root, "output")),
               "exactly one per planned task")
})

test_that("bundle manifest rejects corruption, extras, and unsafe rows", {
  bundle <- withr::local_tempdir()
  writeLines("alpha", file.path(bundle, "one.txt"))
  .receipt_test_manifest(bundle)
  expect_silent(isdm_diag_verify_bundle_manifest(bundle))

  writeLines("changed", file.path(bundle, "one.txt"))
  expect_error(isdm_diag_verify_bundle_manifest(bundle),
               class = "isdm_diag_receipt_hash_mismatch")
  writeLines("alpha", file.path(bundle, "one.txt"))
  .receipt_test_manifest(bundle)
  writeLines("extra", file.path(bundle, "extra.txt"))
  expect_error(isdm_diag_verify_bundle_manifest(bundle), "exact file set")

  unlink(file.path(bundle, "extra.txt"))
  .receipt_test_manifest(bundle)
  lines <- readLines(file.path(bundle, "MANIFEST.sha256"))
  writeLines(c(lines, paste0(strrep("0", 64L), "  ../escape")),
             file.path(bundle, "MANIFEST.sha256"))
  expect_error(isdm_diag_verify_bundle_manifest(bundle), "unsafe paths")
})

test_that("retained summary must reproduce exactly from raw records", {
  evidence <- withr::local_tempdir()
  bundle <- file.path(evidence, "experiment")
  dir.create(bundle)
  .receipt_test_run(bundle)
  summary <- isdm_diag_independent_summary(file.path(bundle, "plan.rds"),
                                           file.path(bundle, "output"))
  saveRDS(summary, file.path(bundle, "independent-summary.rds"), version = 3)
  .receipt_test_manifest(bundle)
  observed <- .receipt_verify_summary(evidence)
  expect_identical(observed, summary)
  summary$next_action <- "REPLICATION_SIGNAL"
  saveRDS(summary, file.path(bundle, "independent-summary.rds"), version = 3)
  .receipt_test_manifest(bundle)
  expect_error(.receipt_verify_summary(evidence), "not reproduced exactly")
})
