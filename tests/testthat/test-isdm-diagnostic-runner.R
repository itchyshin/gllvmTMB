diag_dir <- testthat::test_path("..", "..", "dev", "isdm-requalification",
                               "diagnostic-rescue")
if (!file.exists(file.path(diag_dir, "record.R"))) {
  test_that("developer-only iSDM diagnostic runner is available", {
    skip("dev/isdm-requalification/diagnostic-rescue is absent from build")
  })
} else {
source(file.path(diag_dir, "record.R"), local = TRUE)

test_that("installed manifest hash is canonical across data-frame metadata", {
  manifest <- data.frame(
    path = c("libs/gllvmTMB.so", "DESCRIPTION", "Meta/package.rds",
             "R/gllvmTMB.rdb", "help/aliases.rds"),
    sha256 = vapply(letters[1:5], function(x) strrep(x, 64L), character(1L)),
    stringsAsFactors = FALSE
  )
  reordered <- manifest[5:1, , drop = FALSE]
  row.names(reordered) <- paste0("linux-", 5:1)

  expect_identical(diagnostic_manifest_hash(manifest),
                   diagnostic_manifest_hash(reordered))

  old_collate <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old_collate), add = TRUE)
  expect_false(is.na(Sys.setlocale("LC_COLLATE", "C")))
  c_hash <- diagnostic_manifest_hash(manifest)
  utf_locale <- c("en_US.UTF-8", "en_CA.UTF-8", "C.UTF-8")
  utf_locale <- utf_locale[vapply(utf_locale, function(x) {
    value <- suppressWarnings(Sys.setlocale("LC_COLLATE", x))
    !is.na(value) && nzchar(value) && value != "C"
  }, logical(1L))]
  skip_if(!length(utf_locale), "no UTF-8 collation locale is available")
  suppressWarnings(Sys.setlocale("LC_COLLATE", utf_locale[[1L]]))
  expect_identical(diagnostic_manifest_hash(manifest), c_hash)
})

.runner_test_env <- function() {
  env <- new.env(parent = globalenv())
  runner <- normalizePath(file.path(diag_dir, "runner.R"), mustWork = TRUE)
  withr::local_envvar(ISDM_DIAG_RUNNER_FILE = runner)
  sys.source(runner, envir = env)
  env$diagnostic_verify_runtime_identity <- function(qualification) invisible(TRUE)
  env
}

test_that("Psi normalization preserves a named square matrix", {
  runner <- file.path(diag_dir, "runner.R")
  text <- readLines(runner, warn = FALSE)
  start <- grep("^diagnostic_psi_matrix <-", text)
  end <- start + which(grepl("^}$", text[(start + 1L):length(text)]))[1L]
  eval(parse(text = text[start:end]))
  truth <- diag(c(0.2, 0.3), 2L)
  dimnames(truth) <- list(c("a", "b"), c("a", "b"))
  expect_identical(diagnostic_psi_matrix(c(0.1, 0.4), truth),
                   structure(diag(c(0.1, 0.4)), dimnames = dimnames(truth)))
  expect_identical(diagnostic_psi_matrix(diag(c(0.1, 0.4)), truth),
                   structure(diag(c(0.1, 0.4)), dimnames = dimnames(truth)))
})

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
  expect_identical(dispositions[[2L]]$optimizer_entered, FALSE)
  expect_identical(dispositions[[3L]]$optimizer_entered, FALSE)
  expect_error(diagnostic_write_terminal(terminal, out),
               class = "isdm_diagnostic_record_exists")
})

test_that("coordinator retains unknown optimizer entry for a killed started task", {
  out <- withr::local_tempdir()
  qualification <- list(source_sha = "sha", source_tree = "tree",
                        harness_manifest_sha256 = "hash")
  plan <- data.frame(task_id = 1L, slice = "x")
  diagnostic_write_started(plan, out, qualification)
  diagnostic_reconcile(plan, out, qualification, "killed")
  disposition <- diagnostic_terminal_dispositions(plan, out)[[1L]]
  expect_identical(disposition$status, "interrupted")
  expect_true(is.na(disposition$optimizer_entered))
})

test_that("public-call failure retains tri-state optimizer evidence", {
  env <- .runner_test_env()
  out <- withr::local_tempdir()
  task <- data.frame(task_id = 1L, slice = "x")
  qualification <- list(source_sha = "sha", source_tree = "tree",
                        harness_manifest_sha256 = "hash")
  result <- env$diagnostic_run_one(
    task, out, qualification,
    function(mark_public, mark_returned) {
      mark_public()
      stop("parser or builder failed")
    }
  )
  expect_identical(result$record$status, "error")
  expect_identical(result$record$public_fit_call_entered, TRUE)
  expect_true(is.na(result$record$optimizer_entered))
  expect_identical(result$record$fit_status, "not_returned")
  expect_identical(result$record$extraction_status, "not_attempted")
})

test_that("post-fit extraction failure preserves returned fit evidence", {
  env <- .runner_test_env()
  out <- withr::local_tempdir()
  task <- data.frame(task_id = 1L, slice = "x")
  qualification <- list(source_sha = "sha", source_tree = "tree",
                        harness_manifest_sha256 = "hash")
  fit <- list(opt = list(convergence = 0L, objective = 1),
              sd_report = list(pdHess = TRUE),
              restart_history = data.frame(restart = 1L),
              start_provenance = list())
  result <- env$diagnostic_run_one(
    task, out, qualification,
    function(mark_public, mark_returned) {
      mark_public()
      mark_returned(fit)
      stop("diagnostic extraction failed")
    }
  )
  expect_identical(result$record$status, "fit_returned")
  expect_identical(result$record$optimizer_entered, TRUE)
  expect_identical(result$record$fit_status, "returned")
  expect_identical(result$record$extraction_status, "error")
  expect_match(result$record$error_message, "diagnostic extraction failed")
})

test_that("coordinator reconciliation is idempotent", {
  out <- withr::local_tempdir()
  qualification <- list(source_sha = "sha", source_tree = "tree",
                        harness_manifest_sha256 = "hash")
  plan <- data.frame(task_id = 1L, slice = "x")
  first <- diagnostic_reconcile(plan, out, qualification, "first")
  Sys.sleep(1)
  second <- diagnostic_reconcile(plan, out, qualification, "second")
  expect_identical(first$reconciled, 1L)
  expect_identical(second$reconciled, 0L)
  expect_length(diagnostic_terminal_dispositions(plan, out), 1L)
})

test_that("watchdog terminates a command process group", {
  skip_if(Sys.which("python3") == "", "python3 unavailable")
  pid_file <- tempfile()
  child <- tempfile(fileext = ".sh")
  writeLines(c("#!/usr/bin/env bash", "sleep 20 &", paste0("echo $! > ",
    shQuote(pid_file)), "wait"), child)
  Sys.chmod(child, "0755")
  watchdog <- file.path(diag_dir, "watchdog.sh")
  out <- suppressWarnings(system2("bash", c(watchdog, "1", "bash", child),
                                  stdout = TRUE, stderr = TRUE))
  expect_equal(as.integer(attr(out, "status")), 124L)
  expect_true(any(grepl("DIAGNOSTIC_WATCHDOG_FIRED", out, fixed = TRUE)))
  pid <- scan(pid_file, what = integer(), quiet = TRUE)
  alive <- system2("kill", c("-0", pid), stdout = FALSE, stderr = FALSE)
  expect_false(identical(as.integer(alive), 0L))
})

test_that("watchdog cleans children after TERM, INT, and HUP", {
  skip_if(Sys.which("python3") == "", "python3 unavailable")
  verifier <- file.path(diag_dir, "watchdog-signal-test.py")
  watchdog <- file.path(diag_dir, "watchdog.py")
  out <- system2("python3", c(verifier, watchdog), stdout = TRUE, stderr = TRUE)
  expect_true(any(grepl("DIAGNOSTIC_WATCHDOG_SIGNALS_VERIFIED", out,
                        fixed = TRUE)))
})

test_that("launcher setup failure reconciles every opened identity", {
  skip_if(Sys.which("bash") == "", "bash unavailable")
  root <- withr::local_tempdir()
  packet <- file.path(root, "packet")
  dir.create(packet)
  plan_path <- file.path(root, "plan.rds")
  qualification <- file.path(root, "qualification.rds")
  output <- file.path(root, "output")
  saveRDS(data.frame(task_id = 1:4), plan_path)
  saveRDS(list(schema = "test"), qualification)
  writeLines(c(
    "a <- commandArgs(TRUE)",
    "if (a[[4]] != '-') saveRDS(list(run_kind=a[[3]]), a[[4]])"
  ), file.path(packet, "launch-preflight.R"))
  writeLines("quit(status=1L)", file.path(packet, "command-index.R"))
  writeLines(c(
    "a <- commandArgs(TRUE)",
    "dir.create(file.path(a[[2]], 'attempts'), recursive=TRUE, showWarnings=FALSE)",
    "p <- readRDS(a[[1]])",
    "for (id in p$task_id) saveRDS(list(task_id=id, status='unavailable'), file.path(a[[2]], 'attempts', sprintf('task-%06d.rds', id)))",
    "cat('RECONCILED', nrow(p), '\\n')"
  ), file.path(packet, "reconcile.R"))
  writeLines(c(
    "a <- commandArgs(TRUE)",
    "saveRDS(list(status=as.integer(a[[2]])), a[[4]])"
  ), file.path(packet, "write-launch-terminal.R"))
  launcher <- file.path(diag_dir, "remote-launch.sh")
  result <- suppressWarnings(system2(
    "bash", c(launcher, packet, plan_path, output, qualification, "1", "smoke"),
    stdout = TRUE, stderr = TRUE
  ))
  expect_identical(as.integer(attr(result, "status")), 4L)
  expect_true(file.exists(file.path(output, "launch-start.rds")))
  expect_true(file.exists(file.path(output, "launch-terminal.rds")))
  attempts <- list.files(file.path(output, "attempts"), pattern = "[.]rds$")
  expect_length(attempts, 4L)
  expect_match(paste(readLines(file.path(output, "logs", "reconciliation.log")),
                     collapse = " "), "RECONCILED 4")
})
}
