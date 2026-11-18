source_mixed_lv_harness <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  roots <- c(".", file.path("..", ".."), workspace)
  root <- roots[vapply(roots, function(x) {
    !is.na(x) && file.exists(file.path(x, "dev", "mixed-lv-family-wide", "00-manifest.R"))
  }, logical(1L))][1L]
  testthat::skip_if(is.na(root), "mixed-LV dev harness unavailable in source tarball")
  source(file.path(root, "dev", "mixed-lv-family-wide", "00-manifest.R"), local = parent.frame())
  source(file.path(root, "dev", "mixed-lv-family-wide", "01-run.R"), local = parent.frame())
  source(file.path(root, "dev", "mixed-lv-family-wide", "02-summarise.R"), local = parent.frame())
}

test_that("mixed-LV manifest is a bijection over the frozen programme", {
  source_mixed_lv_harness()
  cells <- mixed_lv_cells()
  expect_equal(nrow(cells), 38L)
  expect_equal(sum(cells$cell_kind == "pure"), 19L)
  expect_equal(sum(cells$cell_kind == "mixed"), 18L)
  expect_equal(sum(cells$cell_kind == "sentinel"), 1L)
  expect_equal(anyDuplicated(cells$cell_id), 0L)
  expect_equal(anyDuplicated(cells$route_key), 0L)
  expect_silent(mixed_lv_validate_manifest(cells))
  expect_error(mixed_lv_validate_manifest(rbind(cells, cells[1L, ])), "bijection|duplicate")
})

test_that("delta cells freeze the coherent shared-eta estimand before evidence", {
  source_mixed_lv_harness()
  delta <- mixed_lv_cells()[
    mixed_lv_cells()$cell_id %in% c(
      "m12-gaussian__delta-lognormal", "m13-gaussian__delta-Gamma"
    ),
  ]
  expect_equal(nrow(delta), 2L)
  expect_true(all(grepl("shared-eta", delta$contract_note, fixed = TRUE)))
  expect_true(all(grepl("occurrence log-odds", delta$contract_note, fixed = TRUE)))
  expect_true(all(grepl("positive-part log mean", delta$contract_note, fixed = TRUE)))
  expect_false(any(grepl("requires contract adjudication", delta$contract_note,
    fixed = TRUE)))
})

test_that("scientific target contract forbids rotation-dependent raw targets", {
  source_mixed_lv_harness()
  expect_equal(MIXED_LV_SCIENTIFIC_TARGETS,
    c("B_lv", "Sigma_shared", "intercept", "score_identity"))
  for (bad in c("alpha", "Lambda", "raw_alpha", "raw_Lambda", "raw_score")) {
    expect_error(mixed_lv_validate_target(bad), "rotation|forbidden|scientific target")
  }
  expect_silent(mixed_lv_validate_target("B_lv"))
  expect_silent(mixed_lv_validate_target("Sigma_shared"))
})

test_that("shared Sigma is constructed from Lambda without scoring raw Lambda", {
  source_mixed_lv_harness()
  loading <- matrix(c(0.7, -0.5, 0.3), ncol = 1L)
  expect_equal(mixed_lv_sigma_shared(loading), tcrossprod(loading))
  expect_true(all(is.finite(mixed_lv_sigma_shared(loading))))
  expect_error(mixed_lv_sigma_shared(c(1, 2)), "matrix")
})

test_that("family support health has matched positive and negative controls", {
  source_mixed_lv_harness()
  expect_true(mixed_lv_support_check(7L, c(.1, .5, .9))$ok)
  expect_false(mixed_lv_support_check(7L, c(0, .5, 1))$ok)
  expect_true(mixed_lv_support_check(10L, c(1, 2, 4))$ok)
  expect_false(mixed_lv_support_check(10L, c(0, 1, 2))$ok)
  expect_true(mixed_lv_support_check(1L, c(0, 10, 20), trials = 20L)$ok)
  expect_false(mixed_lv_support_check(1L, c(0, 21), trials = 20L)$ok)
  expect_true(mixed_lv_support_check(12L, c(0, .2, 1.1))$ok)
  expect_false(mixed_lv_support_check(12L, c(0, 0, 0))$ok)
  expect_true(mixed_lv_support_check(14L, rep(1:4, each = 2L))$ok)
  expect_false(mixed_lv_support_check(14L, c(1, 2, 3, 4))$ok)
  expect_true(mixed_lv_support_check(16L, rep(1:3, each = 2L))$ok)
  expect_false(mixed_lv_support_check(16L, c(1, 1, 2, 2))$ok)
  expect_false(mixed_lv_support_check(2L, c(0, 1.5, 2))$ok)
  expect_false(mixed_lv_support_check(3L, c(0, 1, 2))$ok)
  expect_true(mixed_lv_support_check(6L, c(0, .4, 1.2))$ok)
  expect_false(mixed_lv_support_check(6L, c(.4, 1.2))$ok)
})

test_that("production grids enforce exact mixed r200, pure r200, and selected r500", {
  source_mixed_lv_harness()
  recovery <- mixed_lv_task_grid("recovery")
  pure_recovery <- mixed_lv_task_grid("pure_recovery")
  calibration <- mixed_lv_task_grid("calibration")
  expect_equal(nrow(recovery), 3800L)
  expect_equal(length(unique(recovery$cell_id)), 19L)
  expect_equal(as.integer(table(recovery$cell_id)), rep(200L, 19L))
  expect_equal(nrow(calibration), 4000L)
  expect_equal(length(unique(calibration$cell_id)), 8L)
  expect_equal(unique(as.integer(table(calibration$cell_id))), 500L)
  expect_setequal(unique(calibration$cell_id), c(
    "m01-gaussian__binomial-logit", "m02-gaussian__poisson",
    "m05-gaussian__nbinom2", "m04-gaussian__Gamma", "m07-gaussian__Beta",
    "m14-gaussian__ordinal-probit", "m13-gaussian__delta-Gamma",
    "m16-gaussian__multinomial"))
  expect_false(any(grepl("^p", recovery$cell_id)))
  expect_equal(nrow(pure_recovery), 3800L)
  expect_equal(length(unique(pure_recovery$cell_id)), 19L)
  expect_equal(as.integer(table(pure_recovery$cell_id)), rep(200L, 19L))
  expect_true(all(grepl("^p", pure_recovery$cell_id)))
  expect_length(intersect(recovery$rep_seed, calibration$rep_seed), 0L)
  expect_length(intersect(recovery$rep_seed, pure_recovery$rep_seed), 0L)
  expect_length(intersect(pure_recovery$rep_seed, calibration$rep_seed), 0L)
  pure_sizes <- unique(pure_recovery[c("cell_id", "n_units", "n_repeats")])
  expect_true(all(pure_sizes$n_units >= 240L))
  expect_equal(pure_sizes$n_units[match("p05-nbinom2", pure_sizes$cell_id)], 300L)
  expect_equal(pure_sizes$n_units[match("p10-truncated-poisson", pure_sizes$cell_id)], 300L)
  expect_equal(pure_sizes$n_units[match("p11-truncated-nbinom2", pure_sizes$cell_id)], 300L)
  expect_equal(pure_sizes$n_units[match("p12-delta-lognormal", pure_sizes$cell_id)], 800L)
  expect_equal(pure_sizes$n_units[match("p13-delta-Gamma", pure_sizes$cell_id)], 400L)
  expect_equal(pure_sizes$n_units[match("p14-ordinal-probit", pure_sizes$cell_id)], 400L)
  expect_equal(pure_sizes$n_units[match("p16-multinomial", pure_sizes$cell_id)], 240L)
  expect_equal(pure_sizes$n_repeats[match("p16-multinomial", pure_sizes$cell_id)], 5L)
  sizes <- unique(recovery[c("cell_id", "n_units", "n_repeats")])
  expect_equal(sizes$n_units[match("m05-gaussian__nbinom2", sizes$cell_id)], 300L)
  expect_equal(sizes$n_units[match("m10-gaussian__truncated-poisson", sizes$cell_id)], 300L)
  expect_equal(sizes$n_units[match("m11-gaussian__truncated-nbinom2", sizes$cell_id)], 300L)
  expect_equal(sizes$n_units[match("m12-gaussian__delta-lognormal", sizes$cell_id)], 800L)
  expect_equal(sizes$n_units[match("m13-gaussian__delta-Gamma", sizes$cell_id)], 400L)
  expect_equal(sizes$n_units[match("m14-gaussian__ordinal-probit", sizes$cell_id)], 400L)
  expect_equal(sizes$n_units[match("m16-gaussian__multinomial", sizes$cell_id)], 240L)
  expect_equal(sizes$n_repeats[match("m16-gaussian__multinomial", sizes$cell_id)], 5L)
  expect_error(mixed_lv_task_grid("recovery", n_reps = 199L), "exactly 200")
  expect_error(mixed_lv_task_grid("pure_recovery", n_reps = 199L), "exactly 200")
  expect_error(mixed_lv_task_grid("calibration", n_reps = 499L), "exactly 500")
})

test_that("batch workers partition every retained task exactly once", {
  source_mixed_lv_harness()
  task_ids <- mixed_lv_task_grid("recovery")$task_id
  partitions <- lapply(
    seq_len(40L),
    function(worker_id) mixed_lv_partition_task_ids(task_ids, worker_id, 40L)
  )
  combined <- unlist(partitions, use.names = FALSE)
  expect_equal(length(combined), 3800L)
  expect_equal(anyDuplicated(combined), 0L)
  expect_setequal(combined, task_ids)
  expect_lte(max(lengths(partitions)) - min(lengths(partitions)), 1L)
  expect_error(mixed_lv_partition_task_ids(task_ids, 0L, 40L), "worker")
  expect_error(mixed_lv_partition_task_ids(task_ids, 1L, 0L), "worker")
})

test_that("a forked campaign can reuse one verified package load", {
  source_mixed_lv_harness()
  old <- Sys.getenv("GLLVMTMB_MIXED_LV_PACKAGE_PRELOADED", unset = NA_character_)
  on.exit({
    if (is.na(old)) Sys.unsetenv("GLLVMTMB_MIXED_LV_PACKAGE_PRELOADED") else
      Sys.setenv(GLLVMTMB_MIXED_LV_PACKAGE_PRELOADED = old)
  }, add = TRUE)
  Sys.setenv(GLLVMTMB_MIXED_LV_PACKAGE_PRELOADED = "true")
  expect_error(
    mixed_lv_load_package(namespace_loaded = function(package) FALSE),
    "namespace is not loaded"
  )
  expect_identical(
    mixed_lv_load_package(namespace_loaded = function(package) TRUE),
    "preloaded"
  )
})

test_that("tracked Totoro launchers enforce the 30-minute stop and partial collection", {
  source_mixed_lv_harness()
  root <- mixed_lv_repo_root()
  shell <- file.path(root, "dev", "mixed-lv-family-wide", "03-totoro-launch.sh")
  detached <- file.path(root, "dev", "mixed-lv-family-wide", "04-totoro-detached.sh")
  runner <- file.path(root, "dev", "mixed-lv-family-wide", "05-totoro-run.R")
  collector <- file.path(root, "dev", "mixed-lv-family-wide", "06-totoro-collect.R")
  expect_true(all(file.exists(c(shell, detached, runner, collector))))
  launch_text <- paste(readLines(shell, warn = FALSE), collapse = "\n")
  expect_match(launch_text, "MAX_WALL_SECONDS=1800", fixed = TRUE)
  expect_match(launch_text, "kill -TERM --", fixed = TRUE)
  expect_match(launch_text, "kill -KILL --", fixed = TRUE)
  expect_match(launch_text, "overrun-status", fixed = TRUE)
  expect_match(
    launch_text,
    paste0(
      "if [[ -f \"${OUTPUT_DIR}/logs/overrun-status\" ]]; then\n",
      "  wait \"${watchdog_pid}\" 2>/dev/null || true"
    ),
    fixed = TRUE
  )
  expect_match(launch_text, "06-totoro-collect.R", fixed = TRUE)
  expect_silent(parse(file = runner))
  expect_silent(parse(file = collector))
})

test_that("canary rows cannot become retained evidence", {
  source_mixed_lv_harness()
  canary <- mixed_lv_canary_grid(n_reps = 3L)
  expect_true(all(!canary$evidence_eligible))
  expect_true(all(canary$campaign_kind == "canary"))
  expect_error(mixed_lv_canary_grid(n_reps = 4L), "at most three")
  expect_error(mixed_lv_assert_evidence_rows(canary), "canary|evidence")
})

test_that("multinomial fit dispatch never forwards row weights", {
  source_mixed_lv_harness()
  expect_null(mixed_lv_fit_weights(c(0L, 16L), rep(1, 10L)))
  expect_null(mixed_lv_fit_weights(16L, rep(1, 10L)))
  expect_equal(mixed_lv_fit_weights(c(0L, 2L), 1:4), 1:4)
})

test_that("source manifest mismatch fails closed", {
  source_mixed_lv_harness()
  observed <- MIXED_LV_SOURCE_MANIFEST
  observed$observed_md5 <- observed$md5
  expect_silent(mixed_lv_validate_source_identity(
    MIXED_LV_PINNED_HEAD, observed
  ))
  expect_silent(mixed_lv_validate_source_manifest(observed))
  observed$observed_md5[[1L]] <- "bad"
  expect_error(mixed_lv_validate_source_manifest(observed), "source.*mismatch|hash")
  expect_error(mixed_lv_validate_source_identity("wrong", observed),
    "HEAD|head")
})

test_that("record reconciliation rejects a changed harness", {
  source_mixed_lv_harness()
  task <- mixed_lv_task_grid("recovery")[1L, ]
  record <- mixed_lv_attempt_stub(task, status = "fit_returned")
  record$pinned_head <- MIXED_LV_PINNED_HEAD
  record$manifest_id <- MIXED_LV_MANIFEST_ID
  record$formula_id <- MIXED_LV_FORMULA_ID
  record$source_manifest <- transform(
    MIXED_LV_SOURCE_MANIFEST,
    observed_md5 = md5
  )
  record$harness_manifest <- mixed_lv_harness_manifest()
  expect_silent(mixed_lv_validate_record_identity(list(record)))
  record$harness_manifest$md5[[1L]] <- "changed-after-campaign"
  expect_error(mixed_lv_validate_record_identity(list(record)),
    "harness|driver|identity")
})

test_that("all attempts survive reconciliation including interrupted tasks", {
  source_mixed_lv_harness()
  plan <- mixed_lv_task_grid("recovery")[1:3, ]
  records <- list(
    mixed_lv_attempt_stub(plan[1L, ], status = "fit_returned"),
    mixed_lv_attempt_stub(plan[2L, ], status = "error", failure_stage = "fit")
  )
  ledger <- mixed_lv_reconcile_attempts(plan, records)
  expect_equal(nrow(ledger), 3L)
  expect_equal(ledger$status, c("fit_returned", "error", "planned_not_started"))
  expect_equal(ledger$task_id, plan$task_id)
  expect_error(mixed_lv_reconcile_attempts(plan, c(records, records[1L])), "duplicate")
})

test_that("flat all-attempt ledgers retain every point-eligibility predicate", {
  source_mixed_lv_harness()
  task <- mixed_lv_task_grid("pure_recovery")[1L, ]
  record <- mixed_lv_attempt_stub(task, status = "fit_returned")
  record$max_gradient <- 0.012
  record$family_ids_ok <- TRUE
  record$link_pairs_ok <- TRUE
  record$diag_B_disabled <- TRUE
  record$dgp_support_ok <- TRUE
  row <- mixed_lv_record_row(record)
  expect_named(row, c(
    "task_id", "cell_id", "campaign_kind", "rep", "rep_seed",
    "evidence_eligible", "status", "failure_stage", "fit_converged",
    "point_eligible", "interval_eligible", "max_gradient", "pd_hessian",
    "family_ids_ok", "link_pairs_ok", "diag_B_disabled", "dgp_support_ok",
    "B_lv_abs_error", "Sigma_rel_frob_error", "intercept_rmse",
    "score_identity_error", "covered_all_B_lv", "runtime_s",
    "warning_count", "error_message"
  ))
  expect_equal(row$max_gradient, 0.012)
  expect_true(row$family_ids_ok)
})

test_that("interrupted and never-started tasks have distinct honest denominators", {
  source_mixed_lv_harness()
  plan <- mixed_lv_task_grid("recovery")[1:3, ]
  records <- list(mixed_lv_attempt_stub(plan[1L, ], status = "fit_returned"))
  started <- list(mixed_lv_attempt_stub(plan[2L, ], status = "started"))
  ledger <- mixed_lv_reconcile_attempts(plan, records, started)
  expect_equal(ledger$status,
    c("fit_returned", "interrupted_missing_final", "planned_not_started"))
  summary <- mixed_lv_summarise_cell(ledger, expected_reps = 3L)
  expect_equal(summary$n_planned, 3L)
  expect_equal(summary$n_attempted, 2L)
  expect_false(summary$attempt_denominator_complete)
})

test_that("an all-failure cell returns a conservative verdict instead of erroring", {
  source_mixed_lv_harness()
  rows <- data.frame(
    cell_id = rep("m01-gaussian__binomial-logit", 2L),
    campaign_kind = rep("recovery", 2L),
    status = rep("error", 2L), fit_converged = FALSE,
    point_eligible = FALSE, interval_eligible = FALSE,
    B_lv_abs_error = NA_real_, Sigma_rel_frob_error = NA_real_,
    intercept_rmse = NA_real_, score_identity_error = NA_real_,
    covered_all_B_lv = NA, stringsAsFactors = FALSE
  )
  summary <- mixed_lv_summarise_cell(rows, expected_reps = 2L)
  expect_no_error(gates <- mixed_lv_apply_gates(summary, data.frame()))
  expect_false(gates$point_verdict)
  expect_false(gates$B_bias_pass)
  expect_false(gates$score_identity_pass)
})

test_that("point and interval denominators remain distinct and MCSE is earned", {
  source_mixed_lv_harness()
  rows <- data.frame(
    cell_id = "m01-gaussian__binomial-logit", rep = 1:4,
    campaign_kind = "calibration", evidence_eligible = TRUE,
    fit_converged = c(TRUE, TRUE, TRUE, FALSE),
    point_eligible = c(TRUE, TRUE, TRUE, FALSE),
    interval_eligible = c(TRUE, FALSE, TRUE, FALSE),
    B_lv_abs_error = c(.1, .2, .3, NA),
    Sigma_rel_frob_error = c(.1, .2, .3, NA),
    intercept_rmse = c(.1, .2, .3, NA),
    covered_all_B_lv = c(TRUE, NA, FALSE, NA),
    stringsAsFactors = FALSE
  )
  out <- mixed_lv_summarise_cell(rows, expected_reps = 4L)
  expect_equal(out$n_attempted, 4L)
  expect_equal(out$n_point_eligible, 3L)
  expect_equal(out$n_interval_eligible, 2L)
  expect_equal(out$coverage, .5)
  expect_equal(out$coverage_mcse, sqrt(.5 * .5 / 2))
  expect_equal(out$fit_failure_rate, .25)
})

test_that("thresholds are immutable and applied literally", {
  source_mixed_lv_harness()
  expect_equal(MIXED_LV_THRESHOLDS$recovery_reps, 200L)
  expect_equal(MIXED_LV_THRESHOLDS$calibration_reps, 500L)
  expect_equal(MIXED_LV_THRESHOLDS$min_interval_eligible, 450L)
  expect_equal(MIXED_LV_THRESHOLDS$min_convergence_rate, .95)
  expect_equal(MIXED_LV_THRESHOLDS$min_point_availability_rate, .90)
  expect_equal(MIXED_LV_THRESHOLDS$max_abs_B_bias, .10)
  expect_equal(MIXED_LV_THRESHOLDS$max_B_rmse, .20)
  expect_equal(MIXED_LV_THRESHOLDS$max_abs_Sigma_entry_bias, .15)
  expect_equal(MIXED_LV_THRESHOLDS$max_abs_intercept_bias, .10)
  expect_equal(MIXED_LV_THRESHOLDS$coverage_band, c(.92, .98))
  expect_equal(MIXED_LV_THRESHOLDS$max_score_identity_error, 1e-8)

  cell <- data.frame(cell_id = "x", campaign_kind = "recovery",
    exact_denominator = TRUE, convergence_rate = .95,
    point_availability_rate = .90, max_score_identity_error = .999e-8)
  targets <- data.frame(cell_id = "x",
    target = c("B_lv", "Sigma_shared", "intercept"),
    target_id = c("B[1]", "S[1]", "I[1]"), n_point = 200L,
    bias = c(.10, .15, .10), rmse = c(.20, .15, .10),
    n_interval = 0L, coverage = NA_real_, coverage_mcse = NA_real_)
  gate <- mixed_lv_apply_gates(cell, targets)
  expect_true(gate$point_verdict)
  targets$bias[[1L]] <- .100001
  expect_false(mixed_lv_apply_gates(cell, targets)$B_bias_pass)
})

test_that("calibration boundaries are inclusive and fail immediately outside", {
  source_mixed_lv_harness()
  cell <- data.frame(cell_id = "x", campaign_kind = "calibration",
    exact_denominator = TRUE, convergence_rate = .95,
    point_availability_rate = .90, max_score_identity_error = 1e-8)
  targets <- data.frame(cell_id = "x",
    target = c("B_lv", "Sigma_shared", "intercept"),
    target_id = c("B[1]", "S[1]", "I[1]"), n_point = 500L,
    bias = c(.10, .15, .10), bias_mcse = 0, rmse = c(.20, .15, .10),
    rmse_mcse = 0, n_interval = c(450L, 0L, 0L),
    coverage = c(.92, NA, NA), coverage_mcse = c(.01, NA, NA),
    nominal_coverage_mcse = c(sqrt(.95 * .05 / 450), NA, NA))
  expect_true(mixed_lv_apply_gates(cell, targets)$calibration_verdict)
  targets$coverage[[1L]] <- .98
  expect_true(mixed_lv_apply_gates(cell, targets)$calibration_verdict)
  targets$n_interval[[1L]] <- 449L
  expect_false(mixed_lv_apply_gates(cell, targets)$interval_pass)
  targets$n_interval[[1L]] <- 450L; targets$coverage[[1L]] <- .919999
  expect_false(mixed_lv_apply_gates(cell, targets)$interval_pass)
  targets$coverage[[1L]] <- .980001
  expect_false(mixed_lv_apply_gates(cell, targets)$interval_pass)
  targets$coverage[[1L]] <- .95; cell$max_score_identity_error <- 1.000001e-8
  expect_false(mixed_lv_apply_gates(cell, targets)$score_identity_pass)
})

test_that("target summaries report bias and RMSE Monte Carlo error", {
  source_mixed_lv_harness()
  x <- data.frame(task_id = 1:2, cell_id = "x", campaign_kind = "recovery",
    rep = 1:2, target = "B_lv", target_id = "B[1]",
    error = c(-1, 1), covered = NA)
  s <- mixed_lv_summarise_targets(x)
  expect_equal(s$bias, 0)
  expect_equal(s$bias_mcse, 1)
  expect_equal(s$rmse, 1)
  expect_equal(s$rmse_mcse, 0)
})
