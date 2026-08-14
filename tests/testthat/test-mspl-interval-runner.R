runner_path <- test_path(
  "..", "..", "inst", "sim", "lane-b-uncertainty",
  "run-mspl-interval-feasibility.R"
)

run_interval_cli <- function(arguments, error_on_status = TRUE) {
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", runner_path, arguments), stdout = TRUE, stderr = TRUE,
    env = "GLLVM_TMB_PILOT_SOURCE=true"
  ))
  if (error_on_status && !is.null(attr(output, "status"))) {
    stop(paste(output, collapse = "\n"), call. = FALSE)
  }
  output
}

test_that("private MSPL interval runner freezes the exact bootstrap contract", {
  runner <- paste(readLines(runner_path), collapse = "\n")
  expect_match(runner, "lane-b-mspl-interval-v1-2026-08-14")
  expect_match(runner, "1814000000L.*case\\$case_number.*10000L")
  expect_match(runner, "check_simulate_unconditional")
  expect_match(runner, "condition_on_RE = FALSE")
  expect_match(runner, "estimator_id == 1L")
  expect_match(runner, "type = 7L")
  expect_match(runner, "minimum_usable")
  expect_match(runner, "0.1 \\* width")
  expect_match(runner, "36,000 target rows")
  expect_false(grepl("confint\\(|bootstrap_Sigma\\(", runner))
})

test_that("private MSPL interval manifest is 12 cases with fixed identities", {
  root <- tempfile("mspl-interval-manifest-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  run_interval_cli(c(
    "prepare", "--root", root, "--campaign-id", "test-campaign",
    "--source-sha", "test-source", "--n-bootstrap", "1",
    "--shard-size", "1", "--clusters", "local", "--mcse-reps", "20"
  ))
  manifest <- utils::read.csv(
    file.path(root, "manifest.csv"), stringsAsFactors = FALSE
  )
  expect_equal(nrow(manifest), 12L)
  expect_setequal(manifest$regime, c(
    "baseline", "low_prevalence", "high_prevalence", "strong_signal"
  ))
  expect_setequal(manifest$link, c("logit", "probit", "cloglog"))
  expect_equal(as.vector(table(manifest$regime)), rep(3L, 4L))
  expect_equal(as.vector(table(manifest$link)), rep(4L, 3L))
  expect_identical(manifest$case_id, sprintf("C%03d", seq_len(12L)))
  expect_true(all(manifest$assigned_cluster == "local"))
  expect_true(all(manifest$minimum_usable == 1L))
})

test_that("private MSPL bootstrap smoke retains three penalised target rows", {
  root <- tempfile("mspl-interval-smoke-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  run_interval_cli(c(
    "prepare", "--root", root, "--campaign-id", "test-smoke",
    "--source-sha", "test-source", "--n-bootstrap", "1",
    "--shard-size", "1", "--clusters", "local", "--mcse-reps", "20"
  ))
  run_interval_cli(c(
    "run", "--root", root, "--case-id", "C001", "--shard-id", "1",
    "--cluster", "local"
  ))
  receipt <- utils::read.csv(
    file.path(root, "raw", "C001-shard-001.csv"), stringsAsFactors = FALSE
  )
  expect_equal(nrow(receipt), 3L)
  expect_identical(receipt$target, 1:3)
  expect_true(all(receipt$unconditional_redraw))
  expect_true(all(receipt$status == "ok"))
  expect_true(all(receipt$convergence == 0L))
  expect_true(all(receipt$estimator_id == 1L))
  expect_true(all(is.finite(receipt$estimate)))
  expect_true(all(is.finite(receipt$objective)))
  expect_identical(receipt$seed, rep(1814010001L, 3L))
})

test_that("private MSPL interval aggregation enforces exact keys and provenance", {
  root <- tempfile("mspl-interval-summary-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  run_interval_cli(c(
    "prepare", "--root", root, "--campaign-id", "test-summary",
    "--source-sha", "test-source", "--n-bootstrap", "20",
    "--shard-size", "20", "--clusters", "local", "--mcse-reps", "50"
  ))
  manifest <- utils::read.csv(
    file.path(root, "manifest.csv"), stringsAsFactors = FALSE
  )
  receipt <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    x <- expand.grid(
      bootstrap_rep_id = seq_len(20L), target = seq_len(3L),
      stringsAsFactors = FALSE
    )
    x$manifest_version <- manifest$manifest_version[[i]]
    x$campaign_id <- manifest$campaign_id[[i]]
    x$source_sha <- manifest$source_sha[[i]]
    x$cluster <- manifest$assigned_cluster[[i]]
    x$case_id <- manifest$case_id[[i]]
    x$case_number <- manifest$case_number[[i]]
    x$regime <- manifest$regime[[i]]
    x$link <- manifest$link[[i]]
    x$target_name <- sprintf("b_fix[%d]", x$target)
    x$estimate <- x$target + stats::qnorm((x$bootstrap_rep_id - 0.5) / 20)
    x$status <- "ok"
    x$convergence <- 0L
    x$objective <- 1
    x$estimator_id <- 1L
    x$unconditional_redraw <- TRUE
    x$seed <- 1814000000L + i * 10000L + x$bootstrap_rep_id
    x$message <- ""
    x$runtime_fingerprint <- "test"
    x$elapsed_seconds <- 0.1
    x
  }))
  utils::write.csv(
    receipt, file.path(root, "raw", "synthetic.csv"), row.names = FALSE
  )
  run_interval_cli(c("summarise", "--root", root))
  summary <- utils::read.csv(
    file.path(root, "summary.csv"), stringsAsFactors = FALSE
  )
  expect_equal(nrow(summary), 36L)
  expect_true(all(summary$attempted == 20L))
  expect_true(all(summary$usable == 20L))
  expect_true(all(is.finite(summary$lower)))
  expect_true(all(is.finite(summary$upper)))

  receipt$source_sha[[1L]] <- "stale"
  utils::write.csv(
    receipt, file.path(root, "raw", "synthetic.csv"), row.names = FALSE
  )
  output <- run_interval_cli(
    c("summarise", "--root", root), error_on_status = FALSE
  )
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "provenance")
})
