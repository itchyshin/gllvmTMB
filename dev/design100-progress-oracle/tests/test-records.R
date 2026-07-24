# Structural tests only: no fixture, objective, numerical integration, or compute.

records_path <- file.path("dev", "design100-progress-oracle", "R", "records.R")
if (!file.exists(records_path)) records_path <- file.path("..", "R", "records.R")
source(records_path)

d100_test_hash <- paste(rep("a", 64L), collapse = "")

d100_test_launch <- list(
  schema = "d100-launch-v1", record_type = "launch", task_id = "pattern-01",
  task_kind = "pattern", run_label = "private-progress-01",
  contract_hash = d100_test_hash, input_hash = d100_test_hash,
  launched_at = "2026-07-24 12:00:00 UTC", host = "test-host", parent_pid = 1L,
  mode = "RECORD_ONLY", liveness_timeout_s = 60L
)

d100_test_terminal_common <- list(
  schema = "d100-terminal-v1", record_type = "pattern", task_id = "pattern-01",
  task_kind = "pattern", run_label = "private-progress-01",
  contract_hash = d100_test_hash, input_hash = d100_test_hash,
  launch_hash = d100_test_hash, status = "PROGRESS_COMPLETE",
  reason_code = "ALL_COMPONENTS_RECORDED", started_at = "2026-07-24 12:00:00 UTC",
  finished_at = "2026-07-24 12:01:00 UTC", host = "test-host", pid = 2L,
  exit_status = 0L,
  telemetry = list(wall_time_s = 60, progress_event_count = 2L,
                   last_progress_sequence = 2L)
)

testthat::test_that("Design-100 records retain the private-scope fences", {
  source_text <- paste(readLines(records_path, warn = FALSE), collapse = "\n")
  testthat::expect_match(source_text, "COST_BENCHMARK_STOP", fixed = TRUE)
  testthat::expect_match(source_text, "d100_write_exclusive_text", fixed = TRUE)
  testthat::expect_match(source_text, "d100_run_label", fixed = TRUE)
  testthat::expect_match(source_text, "Malformed existing Design-100 progress", fixed = TRUE)
  testthat::expect_false(grepl("integrate\\s*\\(", source_text, ignore.case = TRUE))
})

testthat::test_that("launch, pattern, and component terminals have distinct required fields", {
  testthat::expect_true(d100_validate_launch(d100_test_launch))
  for (unsafe_token in c(".", "..", "../escape", "task/child", "task\\\\child")) {
    testthat::expect_false(d100_path_token(unsafe_token))
    testthat::expect_false(d100_validate_launch(within(d100_test_launch, {
      task_id <- unsafe_token
    })))
    testthat::expect_false(d100_validate_launch(within(d100_test_launch, {
      run_label <- unsafe_token
    })))
  }
  uuid_label <- within(d100_test_launch, {
    run_label <- "123e4567-e89b-12d3-a456-426614174000"
  })
  testthat::expect_false(d100_validate_launch(uuid_label))

  pattern_terminal <- c(d100_test_terminal_common, list(
    pattern_id = "P01", pattern_hash = d100_test_hash, pattern_index = 1L,
    pattern_n_obs = 12L, component_ids = "component-01",
    component_terminal_hashes = list("component-01" = d100_test_hash)
  ))
  testthat::expect_true(d100_validate_terminal(pattern_terminal))
  testthat::expect_false(d100_validate_terminal(within(pattern_terminal, rm(pattern_hash))))

  component_terminal <- d100_test_terminal_common
  component_terminal$record_type <- "component"
  component_terminal$task_id <- "component-01"
  component_terminal$task_kind <- "component"
  component_terminal$pattern_id <- "P01"
  component_terminal$component_id <- "component-01"
  component_terminal$component_kind <- "record-link"
  component_terminal$component_input_hash <- d100_test_hash
  component_terminal$attempt_index <- 1L
  component_terminal$progress_event_hashes <- list()
  component_terminal$result_hash <- d100_test_hash
  testthat::expect_true(d100_validate_terminal(component_terminal))
  testthat::expect_false(d100_validate_terminal(within(component_terminal, rm(result_hash))))
  testthat::expect_false(d100_validate_terminal(within(component_terminal, {
    run_label <- "123e4567-e89b-12d3-a456-426614174000"
  })))
})

testthat::test_that("record path helpers reject task traversal before interpolation", {
  root <- tempfile("d100-path-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  for (unsafe_token in c(".", "..", "../escape", "task/child", "task\\\\child")) {
    testthat::expect_error(d100_launch_path(root, unsafe_token), "safe Design-100 path token")
    testthat::expect_error(d100_progress_path(root, unsafe_token, 1L), "safe Design-100 path token")
    testthat::expect_error(d100_with_task_lock(root, unsafe_token, function() NULL),
                           "task id and one action")
  }
})

testthat::test_that("progress and liveness have distinct monotone record contracts", {
  first <- list(
    schema = "d100-progress-v1", record_type = "progress", task_id = "pattern-01",
    run_label = "private-progress-01", sequence = 1L, state = "progress",
    at = "2026-07-24 12:00:00 UTC", host = "test-host", pid = 2L,
    completed = 0L, total = 2L
  )
  second <- within(first, { sequence <- 2L; completed <- 1L })
  regressing <- within(second, { sequence <- 3L; completed <- 0L })
  liveness <- list(
    schema = "d100-liveness-v1", record_type = "liveness", task_id = "pattern-01",
    run_label = "private-progress-01", sequence = 1L, state = "alive",
    at = "2026-07-24 12:00:00 UTC", host = "test-host", pid = 2L
  )
  uuid_label <- within(first, {
    run_label <- "123e4567-e89b-12d3-a456-426614174000"
  })

  testthat::expect_true(d100_validate_progress_series(list(first, second)))
  testthat::expect_false(d100_validate_progress_series(list(first, second, regressing)))
  testthat::expect_true(d100_validate_liveness_event(liveness, d100_test_launch))
  testthat::expect_true(d100_validate_liveness_series(list(liveness)))
  testthat::expect_false(d100_validate_progress_event(liveness, d100_test_launch))
  testthat::expect_false(d100_validate_liveness_event(first, d100_test_launch))
  testthat::expect_false(d100_validate_progress_event(uuid_label))
  testthat::expect_true(d100_valid_status_reason(
    "COST_BENCHMARK_STOP", "COST_BENCHMARK_EXCEEDED"
  ))
})

testthat::test_that("per-task record locks fail closed on a competing writer", {
  root <- tempfile("d100-lock-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  testthat::expect_error(
    d100_with_task_lock(root, "pattern-01", function() {
      d100_with_task_lock(root, "pattern-01", function() invisible(NULL))
    }),
    "concurrent or stale"
  )
})

testthat::test_that("pattern aggregation accepts only validated component terminals", {
  oracle_path <- file.path("dev", "design100-progress-oracle", "R", "independent-oracle.R")
  if (!file.exists(oracle_path)) oracle_path <- file.path("..", "R", "independent-oracle.R")
  source(oracle_path)

  component_terminal <- d100_test_terminal_common
  component_terminal$record_type <- "component"
  component_terminal$task_id <- "component-01"
  component_terminal$task_kind <- "component"
  component_terminal$pattern_id <- "P01"
  component_terminal$component_id <- "component-01"
  component_terminal$component_kind <- "record-link"
  component_terminal$component_input_hash <- d100_test_hash
  component_terminal$attempt_index <- 1L
  component_terminal$progress_event_hashes <- list()
  component_terminal$result_hash <- d100_test_hash
  task <- d100_oracle_task_input("coordinate-01", "P01", "backend-01")

  boundary <- d100_oracle_direct_original_u_boundary(task, original_u = "declarative-only")
  testthat::expect_identical(boundary$coordinate_system, "original_u")
  aggregate <- d100_oracle_aggregate_pattern(task, list(component_terminal))
  testthat::expect_identical(aggregate$component_count, 1L)
  testthat::expect_error(
    d100_oracle_aggregate_pattern(task, list(structure(
      list(record_type = "component_terminal", is_terminal = TRUE),
      class = "d100_oracle_component_terminal"
    ))),
    "d100-terminal-v1"
  )
})
