summary_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "summarise.R"
)
if (!file.exists(summary_path)) {
  test_that("developer-only iSDM summary source is available", {
    skip("dev/isdm-requalification is absent from the built package")
  })
} else {
source(summary_path, local = TRUE, chdir = TRUE)

test_that("denominators preserve errors, interruptions, and unavailability", {
  ledger <- data.frame(
    attempted = c(TRUE, TRUE, TRUE, TRUE, FALSE),
    terminal = c(TRUE, TRUE, FALSE, TRUE, FALSE),
    eligible = c(TRUE, FALSE, FALSE, FALSE, FALSE),
    status = c("fit_returned", "error", "interrupted_missing_terminal",
               "unavailable", "planned_not_started")
  )
  out <- isdm_denominators(ledger)
  expect_identical(out$planned, 5L)
  expect_identical(out$started, 4L)
  expect_identical(out$terminal, 3L)
  expect_identical(out$eligible, 1L)
  expect_identical(out$error, 1L)
  expect_identical(out$interrupted, 1L)
  expect_identical(out$unavailable, 1L)
})

test_that("all-attempt rates never select only successful fits", {
  expect_equal(isdm_rate_all_attempts(c(TRUE, TRUE, NA, FALSE), 5L), 0.4)
})

test_that("target availability requires fit, truth binding, and finite values", {
  good <- list(status = "fit_returned", estimate = list(beta = c(a = 1)),
               truth = list(beta = c(a = 1.1)),
               diagnostics = list(convergence = 0L, objective = 1,
                                  pd_hessian = TRUE))
  expect_true(isdm_target_available(good, "beta"))
  bad <- good; bad$estimate$beta[] <- NA_real_
  expect_false(isdm_target_available(bad, "beta"))
  bad <- good; bad$status <- "error"
  expect_false(isdm_target_available(bad, "beta"))
})

test_that("rotation-invariant covariance and centered surface metrics are exact", {
  truth <- diag(c(1, 2, 3))
  expect_equal(isdm_relative_frobenius(truth, truth), 0)
  surface <- c(1, 2, 3, 4, 5, 6)
  metric <- isdm_centered_surface_metrics(surface + rep(c(10, -5), each = 3),
                                          surface, rep(c("a", "b"), each = 3))
  expect_true(all(abs(metric$correlation - 1) < 1e-12))
  expect_true(all(metric$nrmse < 1e-12))
})

test_that("Wilson coverage is species-wise and order-statistic transforms commute", {
  interval <- isdm_wilson_interval(570L, 600L, confidence = 0.90)
  expect_true(interval[[1L]] >= 0.92)
  expect_true(interval[[2L]] <= 0.98)
  draws <- seq(-3, 3, length.out = 1000L)
  expect_lte(isdm_interval_transform_identity(draws, exp), 1e-12)
  expect_lte(isdm_interval_transform_identity(
    draws, function(x) -expm1(-exp(x))), 1e-12)
})

.summary_identity <- list(
  source_sha = "approved", source_tree = "tree", worktree_status = character(),
  source_hashes = c(a = "hash"), package_path = "/package",
  library_paths = "/library", package_version = "0.0.0",
  package_hashes = c(DESCRIPTION = "packagehash"),
  dll_path = "/dll", dll_sha256 = "dllhash"
)
.summary_ci <- list(
  schema = "isdm-ci-receipt-v1", verified = TRUE, conclusion = "success",
  head_sha = "approved",
  run_url = "https://github.com/example/gllvmTMB/actions/runs/1",
  platform_conclusions = c(linux = "success", macos = "success",
                           windows = "success")
)
.summary_install <- c(list(schema = "isdm-install-receipt-v1"),
                      .summary_identity[c(
                        "source_sha", "source_tree", "package_path",
                        "package_version", "package_hashes", "dll_path",
                        "dll_sha256"
                      )])
.summary_contract <- c(.summary_identity, list(
  schema = "isdm-source-contract-v2", ci_receipt = .summary_ci,
  install_receipt = .summary_install, ci_url = .summary_ci$run_url,
  ci_conclusion = "success"
))

.with_summary_identity <- function(record) c(
  record,
  .summary_contract[c("source_sha", "source_tree", "worktree_status",
                      "source_hashes", "package_path", "library_paths",
                      "package_version", "package_hashes", "dll_path",
                      "dll_sha256")],
  list(expected_identity = .summary_contract)
)

.passing_ordinary_record <- function(task) .with_summary_identity(list(
  schema = ISDM_RECEIPT_SCHEMA,
  task_id = task$task_id[[1L]], programme = task$programme[[1L]],
  seed = task$seed[[1L]],
  task_spec = as.list(task[1L, , drop = FALSE]), status = "fit_returned",
  failure_phase = "fit",
  diagnostics = list(convergence = 0L, objective = 1, pd_hessian = TRUE),
  estimate = list(
    fixed = stats::setNames(rep(0, length(isdm_expected_fixed_targets(
      task$n_sources[[1L]]))), isdm_expected_fixed_targets(task$n_sources[[1L]])),
    Sigma = structure(diag(c(1, 2, 3)),
                      dimnames = list(paste0("sp", 1:3), paste0("sp", 1:3))),
    Psi = structure(diag(c(0.2, 0.3, 0.4)),
                    dimnames = list(paste0("sp", 1:3), paste0("sp", 1:3))),
    surface = c(1, 2, 3, 2, 4, 6)
  ),
  truth = list(
    fixed = stats::setNames(rep(0, length(isdm_expected_fixed_targets(
      task$n_sources[[1L]]))), isdm_expected_fixed_targets(task$n_sources[[1L]])),
    Sigma = structure(diag(c(1, 2, 3)),
                      dimnames = list(paste0("sp", 1:3), paste0("sp", 1:3))),
    Psi = structure(diag(c(0.2, 0.3, 0.4)),
                    dimnames = list(paste0("sp", 1:3), paste0("sp", 1:3))),
    surface = c(1, 2, 3, 2, 4, 6),
    surface_trait = rep(c("sp1", "sp2"), each = 3)
  )
))

test_that("ordinary adjudication separates promotion and stress denominators", {
  ordinary_plan <- isdm_point_plan("ordinary")
  attack_plan <- isdm_point_plan("attack")
  attack_plan$pair_id <- NA_integer_
  attack_plan$structure_seed <- attack_plan$seed
  plan <- rbind(ordinary_plan, attack_plan[names(ordinary_plan)])
  records <- lapply(seq_len(nrow(plan)), function(i)
    .passing_ordinary_record(plan[i, , drop = FALSE]))
  verdict <- isdm_adjudicate_ordinary(records, source_contract = .summary_contract)
  expect_identical(verdict$verdict, "PASS")
  expect_identical(verdict$coefficients$planned[
    verdict$coefficients$target == "isdm_source:source3:bias_x"], 800L)
  expect_identical(verdict$stress$n, 200L)
  expect_false(verdict$stress$promotion_eligible)
  expect_equal(verdict$stress$convergence_rate, 1)
  expect_equal(verdict$stress$surface_median_correlation, 1)

  records[[1L]]$estimate$fixed[["traitsp1"]] <- NA_real_
  strict <- isdm_frozen_gates()$ordinary
  strict$target_availability_min <- 1
  expect_identical(isdm_adjudicate_ordinary(
    records, strict, source_contract = .summary_contract
  )$verdict, "FAIL")
})

.passing_spatial_record <- function(task) .with_summary_identity(list(
  schema = ISDM_RECEIPT_SCHEMA,
  task_id = task$task_id[[1L]], seed = task$seed[[1L]],
  task_spec = as.list(task[1L, , drop = FALSE]),
  programme = "spatial", status = "fit_returned",
  failure_phase = "fit",
  diagnostics = list(convergence = 0L, objective = 1, pd_hessian = TRUE),
  estimate = list(
    heldout_surface = c(1, 2, 3, 2, 4, 6),
    training_identity_error = 0,
    source_dispatch_error = 0,
    zero_offset_ok = TRUE,
    out_of_hull_warning_ok = TRUE
  ),
  truth = list(
    heldout_surface = c(1, 2, 3, 2, 4, 6),
    heldout_group = rep(c("sp1.source1", "sp2.source1"), each = 3)
  )
))

test_that("spatial adjudication requires every deterministic oracle", {
  plan <- isdm_point_plan("spatial")
  records <- lapply(seq_len(nrow(plan)), function(i)
    .passing_spatial_record(plan[i, , drop = FALSE]))
  expect_identical(isdm_adjudicate_spatial(
    records, source_contract = .summary_contract
  )$verdict, "PASS")
  records[[1L]]$estimate$training_identity_error <- 1e-3
  expect_identical(isdm_adjudicate_spatial(
    records, source_contract = .summary_contract
  )$verdict, "FAIL")
})

test_that("duplicate tasks or wrong registered seeds cannot satisfy completeness", {
  plan <- isdm_point_plan("spatial")
  records <- lapply(seq_len(nrow(plan)), function(i)
    .passing_spatial_record(plan[i, , drop = FALSE]))
  records[[1L]]$seed <- records[[1L]]$seed + 1L
  expect_false(isdm_adjudicate_spatial(
    records, source_contract = .summary_contract
  )$complete)
  records[[1L]] <- records[[2L]]
  expect_false(isdm_adjudicate_spatial(
    records, source_contract = .summary_contract
  )$complete)
})

test_that("identity-free or mixed-pin records cannot satisfy completeness", {
  plan <- isdm_point_plan("spatial")
  records <- lapply(seq_len(nrow(plan)), function(i)
    .passing_spatial_record(plan[i, , drop = FALSE]))
  identity_free <- records
  identity_free[[1L]]$expected_identity <- NULL
  expect_false(isdm_adjudicate_spatial(
    identity_free, source_contract = .summary_contract
  )$complete)
  records[[1L]]$source_sha <- "different"
  expect_false(isdm_adjudicate_spatial(
    records, source_contract = .summary_contract
  )$complete)

  identity_only <- .summary_identity
  identity_only$expected_identity <- identity_only
  expect_false(isdm_records_match_plan(
    records, plan, source_contract = identity_only
  ))
})

test_that("eligible denominator requires a provenance-valid terminal", {
  plan <- isdm_point_plan("spatial")[1L, , drop = FALSE]
  record <- .passing_spatial_record(plan)
  record$expected_identity <- NULL
  root <- tempfile("isdm-summary-")
  dir.create(file.path(root, "attempts"), recursive = TRUE)
  saveRDS(record, file.path(root, "attempts", "task-001801.rds"))
  ledger <- isdm_attempt_ledger(root, plan, source_contract = .summary_contract)
  expect_false(ledger$terminal)
  expect_identical(ledger$status, "invalid_terminal")
  expect_false(ledger$eligible)
})
}
