diag_dir <- testthat::test_path("..", "..", "dev", "isdm-requalification",
                               "diagnostic-rescue")
source(file.path(diag_dir, "record.R"), local = TRUE)

test_that("diagnostic records are immutable and reconciled once", {
  out <- withr::local_tempdir()
  qualification <- list(source_sha = "sha", source_tree = "tree",
                        harness_manifest_sha256 = "hash")
  plan <- data.frame(task_id = 1:3, slice = "x")
  started <- diagnostic_write_started(plan[1, , drop = FALSE], out, qualification)
  terminal <- diagnostic_terminal_record(started, "fit_returned", 1,
                                         optimizer_entered = TRUE)
  diagnostic_write_terminal(terminal, out)
  receipt <- diagnostic_reconcile(plan, out, qualification, "test stop")
  expect_equal(receipt$reconciled, 2L)
  dispositions <- diagnostic_terminal_dispositions(plan, out)
  expect_equal(vapply(dispositions, `[[`, character(1), "status"),
               c("fit_returned", "unavailable", "unavailable"))
  expect_error(diagnostic_write_terminal(terminal, out),
               class = "isdm_diagnostic_record_exists")
})

test_that("duplicate coordinator dispositions fail closed", {
  out <- withr::local_tempdir()
  qualification <- list(source_sha = "sha", source_tree = "tree",
                        harness_manifest_sha256 = "hash")
  plan <- data.frame(task_id = 1L, slice = "x")
  diagnostic_reconcile(plan, out, qualification, "first")
  Sys.sleep(1)
  diagnostic_reconcile(plan, out, qualification, "second")
  expect_error(diagnostic_terminal_dispositions(plan, out),
               class = "isdm_diagnostic_disposition_error")
})

test_that("watchdog terminates a command process group", {
  skip_if(Sys.which("python3") == "", "python3 unavailable")
  pid_file <- tempfile()
  child <- tempfile(fileext = ".sh")
  writeLines(c("#!/usr/bin/env bash", "sleep 20 &", paste0("echo $! > ",
    shQuote(pid_file)), "wait"), child)
  Sys.chmod(child, "0755")
  watchdog <- file.path(diag_dir, "watchdog.sh")
  out <- system2("bash", c(watchdog, "1", "bash", child),
                 stdout = TRUE, stderr = TRUE)
  expect_equal(as.integer(attr(out, "status")), 124L)
  expect_true(any(grepl("DIAGNOSTIC_WATCHDOG_FIRED", out, fixed = TRUE)))
  pid <- scan(pid_file, what = integer(), quiet = TRUE)
  alive <- system2("kill", c("-0", pid), stdout = FALSE, stderr = FALSE)
  expect_false(identical(as.integer(alive), 0L))
})
