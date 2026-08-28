runner_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "runner.R"
)
source(runner_path, local = TRUE)

test_that("retained records are atomic and never overwritten", {
  root <- tempfile("isdm-requalification-")
  path <- file.path(root, "attempts", "task-000001.rds")
  expect_no_error(isdm_atomic_save(list(status = "terminal"), path))
  expect_error(isdm_atomic_save(list(status = "replacement"), path),
               class = "isdm_attempt_already_exists")
  expect_identical(readRDS(path)$status, "terminal")
})

test_that("an exclusive target lock rejects a concurrent duplicate writer", {
  root <- tempfile("isdm-requalification-")
  path <- file.path(root, "attempts", "task-000001.rds")
  dir.create(paste0(path, ".lock"), recursive = TRUE)
  expect_error(isdm_atomic_save(list(status = "duplicate"), path),
               class = "isdm_attempt_write_locked")
  expect_false(file.exists(path))
})

test_that("started records without a terminal record remain interrupted", {
  root <- tempfile("isdm-requalification-")
  isdm_atomic_save(
    list(schema = ISDM_RECEIPT_SCHEMA, task_id = 1L, status = "started"),
    file.path(root, "started", "task-000001.rds")
  )
  ledger <- isdm_reconcile_attempts(root, planned_task_ids = 1:2)
  expect_identical(ledger$status,
                   c("interrupted_missing_terminal", "planned_not_started"))
  expect_identical(ledger$attempted, c(TRUE, FALSE))
  expect_identical(ledger$terminal, c(FALSE, FALSE))
})

test_that("success, errors, and unavailable attempts use one terminal schema", {
  base <- list(task_id = 7L, seed = 202608286L, source_sha = "abc",
               source_tree = "def", started_at = "2026-08-28 UTC")
  ok <- isdm_terminal_record(base, status = "fit_returned",
                             runtime_s = 1, payload = list(objective = 1.2))
  err <- isdm_terminal_record(base, status = "error", runtime_s = 0.2,
                              condition = simpleError("fit failed"))
  unavailable <- isdm_terminal_record(
    base, status = "unavailable", runtime_s = 0,
    condition = structure(simpleError("source mismatch"),
                          class = c("isdm_source_unavailable", "error", "condition"))
  )
  for (record in list(ok, err, unavailable)) {
    expect_identical(record$schema, ISDM_RECEIPT_SCHEMA)
    expect_true(all(c("task_id", "seed", "source_sha", "source_tree",
                      "started_at", "finished_at", "runtime_s", "status") %in%
                    names(record)))
  }
  expect_identical(err$error_message, "fit failed")
  expect_true("isdm_source_unavailable" %in% unavailable$error_class)
})

test_that("all terminal outcomes remain in the all-attempt denominator", {
  root <- tempfile("isdm-requalification-")
  for (task_id in 1:3) {
    base <- list(task_id = task_id, seed = task_id, source_sha = "abc",
                 source_tree = "def", started_at = "2026-08-28 UTC")
    isdm_atomic_save(base,
                     file.path(root, "started", sprintf("task-%06d.rds", task_id)))
    status <- c("fit_returned", "error", "unavailable")[[task_id]]
    isdm_atomic_save(
      isdm_terminal_record(base, status = status, runtime_s = task_id),
      file.path(root, "attempts", sprintf("task-%06d.rds", task_id))
    )
  }
  ledger <- isdm_reconcile_attempts(root, planned_task_ids = 1:4)
  expect_equal(sum(ledger$attempted), 3L)
  expect_equal(sum(ledger$terminal), 3L)
  expect_equal(sum(ledger$status == "fit_returned"), 1L)
  expect_equal(sum(ledger$status == "error"), 1L)
  expect_equal(sum(ledger$status == "unavailable"), 1L)
  expect_equal(sum(ledger$status == "planned_not_started"), 1L)
})

test_that("unreadable or schema-mismatched files do not count as terminal", {
  root <- tempfile("isdm-requalification-")
  dir.create(file.path(root, "attempts"), recursive = TRUE)
  saveRDS(list(schema = "wrong", task_id = 1L, seed = 1L,
               status = "fit_returned"),
          file.path(root, "attempts", "task-000001.rds"))
  ledger <- isdm_reconcile_attempts(root, 1L)
  expect_true(ledger$attempted)
  expect_false(ledger$terminal)
  expect_identical(ledger$status, "invalid_terminal")

  saveRDS(list(schema = ISDM_RECEIPT_SCHEMA, task_id = 1L, seed = 1L),
          file.path(root, "attempts", "task-000001.rds"))
  expect_no_error(ledger <- isdm_reconcile_attempts(root, 1L))
  expect_false(ledger$terminal)
  expect_identical(ledger$status, "invalid_terminal")
})

test_that("a terminal record with the wrong registered seed is invalid", {
  root <- tempfile("isdm-requalification-")
  dir.create(file.path(root, "attempts"), recursive = TRUE)
  saveRDS(list(schema = ISDM_RECEIPT_SCHEMA, task_id = 1L, seed = 99L,
               status = "fit_returned"),
          file.path(root, "attempts", "task-000001.rds"))
  ledger <- isdm_reconcile_attempts(root, 1L, planned_seeds = 1L)
  expect_false(ledger$terminal)
  expect_identical(ledger$status, "invalid_terminal")
})

test_that("tampered structural pairing fields invalidate a terminal record", {
  plan <- data.frame(task_id = 1L, programme = "ordinary", n_sources = 2L,
                     overlap = "full", n_cells = 150L, rep = 1L, seed = 10L,
                     pair_id = 1L, structure_seed = 202700001L)
  record <- list(schema = ISDM_RECEIPT_SCHEMA, task_id = 1L, seed = 10L,
                 status = "fit_returned", task_spec = as.list(plan[1, ]))
  record$task_spec$structure_seed <- 999L
  expect_false(.isdm_terminal_valid(record, 1L, 10L, as.list(plan[1, ])))
})
