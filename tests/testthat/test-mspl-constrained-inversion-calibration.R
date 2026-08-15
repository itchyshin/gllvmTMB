test_that("private MSPL constrained-inversion calibration contract is frozen", {
  runner <- testthat::test_path(
    "..", "..", "inst", "sim", "lane-b-uncertainty",
    "run-mspl-constrained-inversion-calibration.R"
  )
  expect_true(file.exists(runner))
  output <- system2("Rscript", c("--vanilla", runner, "validate"), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))

  root <- tempfile("mspl-constrained-inversion-manifest-")
  output <- system2("Rscript", c("--vanilla", runner, "manifest", "--root", root,
    "--campaign-id", "local-contract", "--source-sha", "abc123"), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))
  manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  expect_identical(nrow(manifest), 12L)
  expect_true(all(manifest$n_outer == 1000L))
  expect_true(all(manifest$bootstrap_reps == 499L))
  expect_true(all(manifest$outer_per_shard == 1L))
  expect_true(all(manifest$minimum_usable_bootstrap == 499L))
  expect_identical(nrow(utils::read.delim(file.path(root, "array-map.tsv"))), 12000L)
  pre_run_map <- utils::read.delim(file.path(root, "pre-run-array-map.tsv"))
  expect_identical(nrow(pre_run_map), 12L)
  expect_identical(pre_run_map$array_index, seq.int(1L, 11001L, by = 1000L))

  for (i in seq_len(nrow(manifest))) {
    endpoint <- expand.grid(target = seq_len(3L), grid_id = seq_len(5L))
    endpoint <- endpoint[order(endpoint$target, endpoint$grid_id), , drop = FALSE]
    endpoint <- data.frame(
      case_id = manifest$case_id[[i]], outer_id = 1L, target = endpoint$target,
      grid_id = endpoint$grid_id, target_value = 0, truth = 0,
      constrained_status = "ok", constrained_message = "", estimator_id = 1L,
      objective_source = "fit$tmb_obj (penalised LA-MSPL)", observed_statistic = 0,
      usable_refits = 499L, p_value = 1, test_status = "ok"
    )
    attempts <- endpoint[rep(seq_len(nrow(endpoint)), each = 499L),
      c("case_id", "outer_id", "target", "grid_id")]
    attempts$replicate <- rep(seq_len(499L), times = nrow(endpoint))
    attempts$status <- "ok"
    attempts$message <- ""
    attempts$estimate <- 0
    attempts$statistic <- 0
    saveRDS(list(
      schema_version = "mspl-constrained-inversion-shard-v1",
      case_id = manifest$case_id[[i]], shard_id = 1L,
      cluster = manifest$assigned_cluster[[i]], source_sha = manifest$source_sha[[i]],
      campaign_id = manifest$campaign_id[[i]], endpoints = endpoint, attempts = attempts
    ), file.path(root, "shards", sprintf("%s-shard-0001.rds", manifest$case_id[[i]])))
  }
  output <- system2("Rscript", c("--vanilla", runner, "aggregate-prerun", "--root", root),
    stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))
  aggregate <- readRDS(file.path(root, "prerun-summary.rds"))
  expect_identical(aggregate$summary$endpoint_rows, 180L)
  expect_identical(aggregate$summary$attempt_rows, 89820L)
  expect_identical(aggregate$summary$endpoint_tests_ok, 180L)

  smoke_root <- tempfile("mspl-constrained-inversion-smoke-")
  smoke_env <- c("GLLVM_TMB_PILOT_SOURCE=true", "MSPL_INVERSION_TEST_MODE=true")
  output <- system2("Rscript", c("--vanilla", runner, "manifest", "--root", smoke_root,
    "--campaign-id", "local-smoke", "--source-sha", "abc123"), env = smoke_env,
    stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))
  output <- system2("Rscript", c("--vanilla", runner, "run-shard", "--root", smoke_root,
    "--case-id", "C001", "--shard-id", "1", "--cluster", "nibi"), env = smoke_env,
    stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))
  shard <- readRDS(file.path(smoke_root, "shards", "C001-shard-0001.rds"))
  expect_identical(nrow(shard$endpoints), 15L)
  expect_identical(nrow(shard$attempts), 30L)
  expect_true(all(shard$endpoints$constrained_status == "ok"))
  expect_true(all(shard$attempts$status == "ok"))
})
