record_path <- testthat::test_path("..", "..", "dev", "isdm-requalification",
                                   "response-information", "records.R")
contract_path <- testthat::test_path("..", "..", "dev", "isdm-requalification",
                                     "response-information", "contract.R")
if (!file.exists(record_path) || !file.exists(contract_path)) {
  test_that("response-information record sources are available", {
    skip("developer-only response-information sources are absent")
  })
} else {
  source(contract_path, local = TRUE)
  source(record_path, local = TRUE)
  test_that("each task has immutable started and terminal receipt paths", {
    task <- isdm_respinfo_plan()[1L, , drop = FALSE]
    qualification <- list(source_sha = "abc", source_tree = "def",
                          harness_manifest_sha256 = "ghi")
    output <- tempfile("repdisc-records-")
    started <- isdm_respinfo_write_started(task, output, qualification)
    terminal <- isdm_respinfo_terminal_record(started, "unavailable", 0,
      condition = simpleError("no package"))
    expect_silent(isdm_respinfo_write_terminal(terminal, output))
    expect_error(isdm_respinfo_write_terminal(terminal, output),
                 class = "isdm_respinfo_receipt_exists")
    expect_identical(readRDS(file.path(output, "started", isdm_respinfo_leaf(1L)))$task_id, 1L)
    expect_identical(readRDS(file.path(output, "attempts", isdm_respinfo_leaf(1L)))$status,
                     "unavailable")
  })
}

test_that("malformed terminal receipts are rejected before writing", {
  task <- isdm_respinfo_plan()[1L, , drop = FALSE]
  qualification <- list(source_sha = "abc", source_tree = "def", harness_manifest_sha256 = "ghi")
  started <- isdm_respinfo_started_record(task, qualification)
  terminal <- isdm_respinfo_terminal_record(started, "error", 0, condition = simpleError("x"))
  terminal$task_id <- 99L
  expect_error(isdm_respinfo_validate_terminal_record(terminal),
               class = "isdm_respinfo_terminal_invalid")
})

test_that("coordinator dispositions fill only identities without worker terminals", {
  plan <- isdm_respinfo_plan()
  output <- tempfile("response-information-coordinator-")
  qualification <- list(source_sha = "abc", source_tree = "def", harness_manifest_sha256 = "ghi")
  first <- plan[1L, , drop = FALSE]
  started <- isdm_respinfo_write_started(first, output, qualification)
  worker <- isdm_respinfo_terminal_record(started, "fit_returned", 1, payload = list(raw = list(ok = TRUE)), optimizer_entered = TRUE)
  isdm_respinfo_write_terminal(worker, output)
  receipt <- isdm_respinfo_reconcile(plan, output, qualification)
  expect_equal(receipt$worker_terminal, 1L)
  terminal <- isdm_respinfo_terminal_dispositions(plan, output)
  expect_equal(length(terminal), 800L)
  expect_identical(terminal[[1L]]$disposition_source, "worker")
  expect_identical(terminal[[2L]]$disposition_source, "coordinator")
})
