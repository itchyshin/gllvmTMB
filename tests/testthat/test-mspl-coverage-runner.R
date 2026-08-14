runner_path <- test_path("..", "..", "inst", "sim", "lane-b-uncertainty",
  "run-mspl-coverage-calibration.R"
)

run_coverage_cli <- function(arguments, error_on_status = TRUE) {
  output <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", runner_path, arguments), stdout = TRUE, stderr = TRUE
  ))
  if (error_on_status && !is.null(attr(output, "status"))) {
    stop(paste(output, collapse = "\n"), call. = FALSE)
  }
  output
}

write_synthetic_shards <- function(root, manifest, retained_failure = FALSE) {
  for (i in seq_len(nrow(manifest))) {
    case <- manifest[i, , drop = FALSE]
    boot <- expand.grid(outer_id = seq_len(case$n_outer), attempt_id = seq_len(case$bootstrap_reps),
      stringsAsFactors = FALSE)
    boot$manifest_version <- case$manifest_version
    boot$campaign_id <- case$campaign_id
    boot$source_sha <- case$source_sha
    boot$cluster <- case$assigned_cluster
    boot$case_id <- case$case_id
    boot$case_number <- case$case_number
    boot$regime <- case$regime
    boot$link <- case$link
    boot$shard_id <- 1L
    boot$runtime_fingerprint <- "test"
    boot$seed <- case$seed_base + 1000000L + (boot$outer_id - 1L) * 500L + boot$attempt_id
    boot$status <- "ok"
    boot$convergence <- 0L
    boot$objective <- 1
    boot$estimator_id <- 1L
    boot$unconditional_redraw <- TRUE
    boot$b_fix_1 <- -0.5 + case$beta_shift + ifelse(boot$attempt_id == 1L, -0.5, 0.5)
    boot$b_fix_2 <- 0.1 + case$beta_shift + ifelse(boot$attempt_id == 1L, -0.5, 0.5)
    boot$b_fix_3 <- 0.55 + case$beta_shift + ifelse(boot$attempt_id == 1L, -0.5, 0.5)
    boot$elapsed_seconds <- 0.01
    boot$message <- ""
    boot$objective_role <- "penalised_bootstrap_refit_estimator_id_1"
    if (retained_failure && i == 1L) {
      boot$status[[1L]] <- "refit_error"
      boot$convergence[[1L]] <- NA_integer_
      boot$estimator_id[[1L]] <- NA_integer_
      boot$unconditional_redraw[[1L]] <- TRUE
      boot$b_fix_1[[1L]] <- NA_real_
      boot$b_fix_2[[1L]] <- NA_real_
      boot$b_fix_3[[1L]] <- NA_real_
    }
    outer <- data.frame(
      manifest_version = case$manifest_version, campaign_id = case$campaign_id,
      source_sha = case$source_sha, cluster = case$assigned_cluster,
      case_id = case$case_id, case_number = case$case_number, regime = case$regime,
      link = case$link, outer_id = seq_len(case$n_outer), shard_id = 1L,
      runtime_fingerprint = "test", seed = case$seed_base + seq_len(case$n_outer),
      status = "ok", convergence = 0L, objective = 1, estimator_id = 1L,
      b_fix_1 = -0.5 + case$beta_shift, b_fix_2 = 0.1 + case$beta_shift,
      b_fix_3 = 0.55 + case$beta_shift, elapsed_seconds = 0.01, message = "",
      objective_role = "penalised_outer_mspl_estimator_id_1",
      stringsAsFactors = FALSE
    )
    endpoints <- expand.grid(outer_id = seq_len(case$n_outer),
      method = c("profile", "wald", "bootstrap"), target = 1:3,
      stringsAsFactors = FALSE
    )
    endpoints$manifest_version <- case$manifest_version
    endpoints$campaign_id <- case$campaign_id
    endpoints$source_sha <- case$source_sha
    endpoints$cluster <- case$assigned_cluster
    endpoints$case_id <- case$case_id
    endpoints$case_number <- case$case_number
    endpoints$regime <- case$regime
    endpoints$link <- case$link
    endpoints$shard_id <- 1L
    endpoints$runtime_fingerprint <- "test"
    endpoints$target_name <- sprintf("b_fix[%d]", endpoints$target)
    endpoints$truth <- c(-0.5, 0.1, 0.55)[endpoints$target] + case$beta_shift
    endpoints$estimate <- endpoints$truth
    endpoints$lower <- endpoints$truth - 1
    endpoints$upper <- endpoints$truth + 1
    endpoints$status <- "ok"
    endpoints$available <- TRUE
    endpoints$covers <- TRUE
    endpoints$objective_role <- c(
      profile = "penalised_profile_nuisance_reoptimised",
      wald = "penalty_off_likelihood_curvature_at_penalised_mspl_estimate",
      bootstrap = "unconditional_parametric_percentile_refit_estimator_id_1"
    )[endpoints$method]
    endpoints$elapsed_seconds <- 0.01
    endpoints$message <- ""
    endpoints$message[endpoints$method == "profile"] <- "centre=matched; lower=crossed; upper=crossed"
    bootstrap_rows <- endpoints$method == "bootstrap"
    for (j in which(bootstrap_rows)) {
      attempts <- boot[boot$outer_id == endpoints$outer_id[[j]], , drop = FALSE]
      values <- attempts[[paste0("b_fix_", endpoints$target[[j]])]][attempts$status == "ok"]
      bounds <- stats::quantile(values, c(0.025, 0.975), type = 7L, names = FALSE)
      endpoints$lower[[j]] <- bounds[[1L]]
      endpoints$upper[[j]] <- bounds[[2L]]
    }
    if (retained_failure && i == 1L) {
      unavailable <- endpoints$method == "profile" & endpoints$target == 1L & endpoints$outer_id == 1L
      endpoints$status[unavailable] <- "profile_matched_truncated_crossed"
      endpoints$available[unavailable] <- FALSE
      endpoints$covers[unavailable] <- FALSE
      endpoints$lower[unavailable] <- NA_real_
      endpoints$upper[unavailable] <- NA_real_
      endpoints$message[unavailable] <- "centre=matched; lower=truncated; upper=crossed"
      bootstrap_unavailable <- endpoints$method == "bootstrap" & endpoints$outer_id == 1L
      endpoints$status[bootstrap_unavailable] <- "insufficient_usable_bootstrap"
      endpoints$available[bootstrap_unavailable] <- FALSE
      endpoints$covers[bootstrap_unavailable] <- FALSE
    }
    profile_rows <- endpoints$method == "profile" & endpoints$status == "ok"
    profile_traces <- do.call(rbind, lapply(which(profile_rows), function(j) {
      lower_bracket <- endpoints$lower[[j]] + c(-0.00005, 0.00005)
      upper_bracket <- endpoints$upper[[j]] + c(-0.00005, 0.00005)
      criterion <- stats::qchisq(0.95, df = 1L) / 2
      data.frame(
        manifest_version = endpoints$manifest_version[[j]], campaign_id = endpoints$campaign_id[[j]],
        source_sha = endpoints$source_sha[[j]], cluster = endpoints$cluster[[j]],
        case_id = endpoints$case_id[[j]], case_number = endpoints$case_number[[j]],
        regime = endpoints$regime[[j]], link = endpoints$link[[j]], outer_id = endpoints$outer_id[[j]],
        shard_id = endpoints$shard_id[[j]], runtime_fingerprint = "test", method = "profile",
        target = endpoints$target[[j]], target_name = endpoints$target_name[[j]],
        objective_role = "penalised_profile_nuisance_reoptimised",
        threshold = criterion,
        lower_bracket_1 = lower_bracket[[1L]], lower_bracket_2 = lower_bracket[[2L]],
        upper_bracket_1 = upper_bracket[[1L]], upper_bracket_2 = upper_bracket[[2L]],
        bracket_tolerance = 1.25e-4,
        target_value = c(endpoints$estimate[[j]], lower_bracket, upper_bracket),
        objective_delta = c(0, criterion - 0.1, criterion + 0.1,
          criterion - 0.1, criterion + 0.1), finite = TRUE,
        convergence = 0L, nuisance_reoptimized = TRUE,
        side = c("centre", "lower", "lower", "upper", "upper"),
        stage = c("centre", "refinement", "refinement", "refinement", "refinement"),
        stringsAsFactors = FALSE
      )
    }))
    saveRDS(list(schema_version = "gate0-shard-v1", outer_fits = outer, bootstrap_attempts = boot,
      endpoints = endpoints, profile_traces = profile_traces),
      file.path(root, "shards", sprintf("%s-shard-001.rds", case$case_id)), compress = "gzip"
    )
  }
}

test_that("Gate 0 coverage runner freezes the approved private contract", {
  runner <- paste(readLines(runner_path), collapse = "\n")
  expect_match(runner, "lane-b-mspl-coverage-gate0-v1-2026-08-14")
  expect_match(runner, "n_outer = 1000L")
  expect_match(runner, "bootstrap_reps = 500L")
  expect_match(runner, "minimum_usable_bootstrap")
  expect_match(runner, "coverage_wilson_level = 0.90")
  expect_match(runner, "coverage_equivalence_lower = 0.92")
  expect_match(runner, "coverage_equivalence_upper = 0.98")
  expect_match(runner, "wald_min_available = 500L")
  expect_match(runner, "outer_per_shard = 10L")
  expect_match(runner, "rep\\(\\\"nibi\\\", 6L\\)")
  expect_match(runner, "rep\\(\\\"narval\\\", 4L\\)")
  expect_match(runner, "rep\\(\\\"rorqual\\\", 2L\\)")
  expect_match(runner, "condition_on_RE = FALSE")
  expect_match(runner, "wilson_interval")
  expect_match(runner, "penalty_off_likelihood_curvature_at_penalised_mspl_estimate")
  expect_false(grepl("objective_role = wald$objective_role", runner, fixed = TRUE))
  expect_match(runner, "array-map.tsv")
  expect_match(runner, "estimate = outer_estimates\\[\\[target\\]\\]")
  expect_false(grepl("confint\\(", runner))
})

test_that("Gate 0 seeds are disjoint at frozen boundary keys", {
  runner_env <- new.env(parent = globalenv())
  withr::local_envvar(MSPL_COVERAGE_SOURCE_ONLY = "true")
  sys.source(runner_path, envir = runner_env)
  manifest <- runner_env$manifest_table(
    campaign_id = "seed-test", source_sha = "seed-sha"
  )
  first <- manifest[1L, , drop = FALSE]
  last <- manifest[12L, , drop = FALSE]
  boundary <- c(
    runner_env$outer_seed(first, 1L), runner_env$outer_seed(first, 1000L),
    runner_env$bootstrap_seed(first, 1L, 1L), runner_env$bootstrap_seed(first, 1000L, 500L),
    runner_env$outer_seed(last, 1L), runner_env$outer_seed(last, 1000L),
    runner_env$bootstrap_seed(last, 1L, 1L), runner_env$bootstrap_seed(last, 1000L, 500L)
  )
  expect_equal(length(unique(boundary)), length(boundary))
  expect_lte(max(boundary), .Machine$integer.max)
})

test_that("Gate 0 bootstrap failure rows receive explicit attempt identity", {
  runner_env <- new.env(parent = globalenv())
  withr::local_envvar(MSPL_COVERAGE_SOURCE_ONLY = "true")
  sys.source(runner_path, envir = runner_env)
  case <- runner_env$manifest_table(campaign_id = "failure-test", source_sha = "sha")[1L, , drop = FALSE]
  seed <- runner_env$bootstrap_seed(case, 1L, 2L)
  row <- runner_env$bootstrap_failure_row(
    case, "local", 1L, 1L, "test", 2L, seed, "refit_error", "forced",
    redraw = TRUE, elapsed_seconds = 0.1
  )
  expect_identical(row$attempt_id, 2L)
  expect_identical(row$seed, seed)
  expect_identical(row$status, "refit_error")
  expect_true(row$unconditional_redraw)
})

test_that("Gate 0 smoke manifest freezes one case per link for one cluster", {
  root <- tempfile("mspl-coverage-smoke-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  run_coverage_cli(c("smoke-manifest", "--root", root, "--campaign-id", "smoke",
    "--source-sha", "sha", "--cluster", "nibi"
  ))
  manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(manifest), 3L)
  expect_setequal(manifest$link, c("logit", "probit", "cloglog"))
  expect_true(all(manifest$regime == "baseline"))
  expect_true(all(manifest$assigned_cluster == "nibi"))
  expect_true(all(manifest$n_outer == 1L))
  expect_true(all(manifest$bootstrap_reps == 2L))
  expect_true(file.exists(file.path(root, "array-map.tsv")))
  array_map <- utils::read.delim(file.path(root, "array-map.tsv"), check.names = FALSE)
  expect_identical(names(array_map), c("array_index", "case_id", "shard_id"))
  expect_identical(array_map$array_index, 1:3)
  expect_equal(nrow(array_map), 3L)
  write_synthetic_shards(root, manifest)
  expect_silent(run_coverage_cli(c("aggregate-smoke", "--root", root)))
  expect_equal(nrow(utils::read.csv(file.path(root, "outer-fit-rows.csv"))), 3L)
  expect_equal(nrow(utils::read.csv(file.path(root, "endpoint-rows.csv"))), 27L)
  expect_equal(nrow(utils::read.csv(file.path(root, "bootstrap-attempts-wide.csv"))), 6L)
  expect_true(any(grepl("calibration_gate_eligible: FALSE", readLines(file.path(root, "receipt.txt"), warn = FALSE), fixed = TRUE)))
})

test_that("Gate 0 keeps production manifest settings frozen", {
  root <- tempfile("mspl-coverage-bootstrap-bound-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  output <- run_coverage_cli(c("manifest", "--root", root, "--campaign-id", "bound",
    "--source-sha", "sha", "--n-outer", "1"
  ), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "frozen")
  output <- run_coverage_cli(c("manifest", "--root", root, "--campaign-id", "bound",
    "--source-sha", "sha", "--availability-min", "0.94"
  ), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "frozen")
  output <- run_coverage_cli(c("test-manifest", "--root", root, "--campaign-id", "bound",
    "--source-sha", "sha", "--bootstrap-reps", "501"
  ), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "1..500")
  expect_silent(run_coverage_cli(c("manifest", "--root", root, "--campaign-id", "production",
    "--source-sha", "sha"
  )))
  production <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  pre_run <- utils::read.delim(file.path(root, "pre-run-array-map.tsv"), check.names = FALSE)
  expect_true(all(production$n_outer == 1000L & production$bootstrap_reps == 500L &
    production$outer_per_shard == 10L & production$minimum_usable_bootstrap == 475L))
  expect_identical(names(pre_run), c("array_index", "case_id", "shard_id"))
  expect_identical(pre_run$array_index, 1:12)
  expect_identical(pre_run$case_id, production$case_id)
  expect_identical(pre_run$shard_id, rep(1L, 12L))

  runner_env <- new.env(parent = globalenv())
  withr::local_envvar(MSPL_COVERAGE_SOURCE_ONLY = "true")
  sys.source(runner_path, envir = runner_env)
  tampered <- production
  tampered$n_outer[[1L]] <- 999L
  expect_error(
    runner_env$write_manifest(tempfile("tampered-production-"), tampered),
    "Production manifest cardinalities"
  )
})

test_that("Gate 0 aggregator accepts exact synthetic keys and retains failures", {
  root <- tempfile("mspl-coverage-accept-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  run_coverage_cli(c("test-manifest", "--root", root, "--campaign-id", "test", "--source-sha", "sha",
    "--n-outer", "2", "--bootstrap-reps", "2", "--outer-per-shard", "2", "--clusters", paste(rep("local", 12L), collapse = ",")
  ))
  manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  expect_true(file.exists(file.path(root, "array-map.tsv")))
  write_synthetic_shards(root, manifest, retained_failure = TRUE)
  output <- run_coverage_cli(c("aggregate", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "not valid for this aggregation mode")
  expect_silent(run_coverage_cli(c("aggregate-test", "--root", root)))
  summary <- utils::read.csv(file.path(root, "summary.csv"), stringsAsFactors = FALSE)
  boot <- utils::read.csv(file.path(root, "bootstrap-attempts-wide.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(summary), 108L)
  expect_equal(nrow(boot), 48L)
  expect_identical(boot$status[[1L]], "refit_error")
  expect_true(any(summary$method == "bootstrap" & summary$available_outer == 2L))
  expect_true(all(is.finite(summary$unconditional_wilson_lower)))
  expect_true(all(c("bias_mcse", "rmse_mcse", "mean_width_mcse", "mean_runtime_mcse") %in%
    names(summary)))
  profile <- summary[summary$case_id == "C001" & summary$method == "profile" & summary$target == 1L, ]
  expect_equal(profile$unconditional_coverage, 0.5)
  expect_equal(profile$conditional_coverage, 1)
  expect_false(profile$coverage_gate)
  expect_false(profile$availability_gate)
  expect_true(any(grepl("calibration_gate_eligible: FALSE", readLines(file.path(root, "receipt.txt"), warn = FALSE), fixed = TRUE)))
})

test_that("Gate 0 aggregator rejects duplicate keys, missing shards, and stale SHA", {
  root <- tempfile("mspl-coverage-reject-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  run_coverage_cli(c("test-manifest", "--root", root, "--campaign-id", "test", "--source-sha", "sha",
    "--n-outer", "1", "--bootstrap-reps", "2", "--outer-per-shard", "1", "--clusters", paste(rep("local", 12L), collapse = ",")
  ))
  manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  write_synthetic_shards(root, manifest)
  path <- file.path(root, "shards", "C001-shard-001.rds")
  shard <- readRDS(path)
  shard$bootstrap_attempts <- rbind(shard$bootstrap_attempts, shard$bootstrap_attempts[1L, ])
  saveRDS(shard, path, compress = "gzip")
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "Bootstrap attempt keys")

  write_synthetic_shards(root, manifest)
  unlink(path)
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "Compressed shard set")

  write_synthetic_shards(root, manifest)
  shard <- readRDS(path)
  shard$endpoints$source_sha[[1L]] <- "stale"
  saveRDS(shard, path, compress = "gzip")
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "source SHA")

  write_synthetic_shards(root, manifest)
  shard <- readRDS(path)
  shard$bootstrap_attempts$seed[[1L]] <- shard$outer_fits$seed[[1L]]
  saveRDS(shard, path, compress = "gzip")
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "seeds")

  write_synthetic_shards(root, manifest)
  shard <- readRDS(path)
  shard$outer_fits$status[[1L]] <- "outer_penalised_objective_mismatch"
  saveRDS(shard, path, compress = "gzip")
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "falsely available endpoint")

  write_synthetic_shards(root, manifest)
  shard <- readRDS(path)
  bootstrap_endpoint <- which(shard$endpoints$method == "bootstrap")[1L]
  shard$endpoints$lower[[bootstrap_endpoint]] <- shard$endpoints$lower[[bootstrap_endpoint]] + 0.1
  saveRDS(shard, path, compress = "gzip")
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "type-7 attempts")

  write_synthetic_shards(root, manifest)
  shard <- readRDS(path)
  profile_trace <- shard$profile_traces$side == "lower" & shard$profile_traces$stage == "refinement"
  shard$profile_traces <- shard$profile_traces[!profile_trace, , drop = FALSE]
  saveRDS(shard, path, compress = "gzip")
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "profile endpoint")

  write_synthetic_shards(root, manifest)
  shard <- readRDS(path)
  shard$profile_traces$threshold[[1L]] <- 1
  saveRDS(shard, path, compress = "gzip")
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "chi-square 95%")

  write_synthetic_shards(root, manifest)
  downgraded <- manifest
  downgraded$manifest_version[[1L]] <- "unknown-version"
  utils::write.csv(downgraded, file.path(root, "manifest.csv"), row.names = FALSE)
  output <- run_coverage_cli(c("aggregate-test", "--root", root), error_on_status = FALSE)
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "unknown, mixed")
})
