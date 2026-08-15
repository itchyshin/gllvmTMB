test_that("the gauge no-fit runner has a byte-only validation mode and no optimizer path", {
  path <- testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "run-paper1-spde-slope-gauge-nofit.R"
  )
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_silent(parse(path))
  expect_match(text, "SPDE_SLOPE_GAUGE_NOFIT_PREDECESSOR_BYTES_PASS", fixed = TRUE)
  expect_match(text, "spde_slope_gauge_nofit_validate_predecessor_bytes", fixed = TRUE)
  expect_equal(length(gregexpr("TMB::MakeADFun", text, fixed = TRUE)[[1L]]), 1L)
  expect_false(grepl("dyn.unload|nlminb|stats::optim|\\.gll_isdm_fit|gllvmTMB\\(", text))
})

test_that("the isolated child validates MSPDE V3 before its one fresh object", {
  path <- testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "run-paper1-spde-slope-gauge-nofit.R"
  )
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  historical <- regexpr("mspde_smoke_validate_closeout_ledger", text, fixed = TRUE)[[1L]]
  factory <- regexpr("TMB::MakeADFun", text, fixed = TRUE)[[1L]]
  expect_gt(historical, 0L)
  expect_gt(factory, historical)
  expect_match(text, "a same-basename gllvmTMB DLL is already loaded", fixed = TRUE)
  expect_match(text, ".spde_slope_gauge_nofit_release_object", fixed = TRUE)
  expect_match(text, "evaluation_audit", fixed = TRUE)
})

spde_slope_gauge_nofit_runner_env <- function() {
  path <- testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "run-paper1-spde-slope-gauge-nofit.R"
  )
  lines <- readLines(path, warn = FALSE)
  start <- grep("^\\.spde_slope_gauge_nofit_gate_base <-", lines)[[1L]]
  end <- grep("^if \\(length\\(args\\)", lines)[[1L]] - 1L
  env <- new.env(parent = baseenv())
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-contract.R"
  ), local = env)
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-nofit-contract.R"
  ), local = env)
  eval(parse(text = lines[start:end]), envir = env)
  env
}

test_that("the production atomic child writer accepts only a fresh staged target", {
  runner <- spde_slope_gauge_nofit_runner_env()
  parent <- tempfile("spde-slope-gauge-parent-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE), add = TRUE)
  runner$script_dir <- parent
  base <- file.path(parent, "results")
  dir.create(base)
  staged <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-test")
  dir.create(staged)
  output <- file.path(staged, "child-result.rds")
  token <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_PARENT_STAGE_V1",
    gate_base = normalizePath(base), stage = normalizePath(staged), parent_pid = 1001L,
    child_output = file.path(normalizePath(staged), "child-result.rds")
  )
  saveRDS(token, file.path(staged, ".parent-stage.rds"))
  expect_silent(runner$.spde_slope_gauge_nofit_atomic_rds(list(ok = TRUE), output, 1001L))
  expect_identical(readRDS(output), list(ok = TRUE))
  expect_error(runner$.spde_slope_gauge_nofit_atomic_rds(list(ok = TRUE), output, 1001L),
    "child output path is invalid")
  expect_error(runner$.spde_slope_gauge_nofit_atomic_rds(
    list(ok = TRUE), file.path(parent, "ordinary", "child-result.rds"), 1001L
  ), "child output path is invalid")

  stale <- file.path(base, ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-stale")
  dir.create(stale)
  stale_output <- file.path(stale, "child-result.rds")
  token$stage <- normalizePath(stale)
  token$child_output <- file.path(normalizePath(stale), "child-result.rds")
  saveRDS(token, file.path(stale, ".parent-stage.rds"))
  writeLines("stale", file.path(stale, "unexpected.txt"))
  expect_error(runner$.spde_slope_gauge_nofit_atomic_rds(list(ok = TRUE), stale_output, 1001L),
    "child output path is invalid")

  science <- file.path(parent, "scientific-root", ".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-copy")
  dir.create(science, recursive = TRUE)
  science_output <- file.path(science, "child-result.rds")
  token$stage <- normalizePath(science)
  token$child_output <- file.path(normalizePath(science), "child-result.rds")
  saveRDS(token, file.path(science, ".parent-stage.rds"))
  expect_error(runner$.spde_slope_gauge_nofit_atomic_rds(list(ok = TRUE), science_output, 1001L),
    "child output path is invalid")
})

test_that("the child failure taxonomy keeps replay disagreement distinct from lifecycle failure", {
  runner <- spde_slope_gauge_nofit_runner_env()
  expect_identical(runner$.spde_slope_gauge_nofit_stage_reason("dll", "anything"),
    "dll_identity_failure")
  expect_identical(runner$.spde_slope_gauge_nofit_stage_reason("callback", "anything"),
    "callback_or_finite_difference_failure")
  expect_identical(runner$.spde_slope_gauge_nofit_stage_reason("callback", "elapsed time limit"),
    "time_limit_exceeded")
  expect_identical(runner$.spde_slope_gauge_nofit_stage_reason("release", "anything"),
    "object_release_failure")
})

test_that("the child accepts only a complete callback audit tied to its FD ledger", {
  runner <- spde_slope_gauge_nofit_runner_env()
  order <- runner$spde_slope_gauge_raw_order()
  theta <- stats::setNames(as.double(seq_len(22L)), order)
  gradient <- stats::setNames(rep(0, 22L), order)
  records <- lapply(seq_len(22L), function(i) {
    plus <- theta
    minus <- theta
    plus[[i]] <- plus[[i]] + 1e-4
    minus[[i]] <- minus[[i]] - 1e-4
    list(theta_plus = plus, theta_minus = minus,
      objective_plus = as.double(i), objective_minus = as.double(-i))
  })
  nofit <- list(raw_theta = theta, raw_gradient = gradient, objective = 0,
    finite_difference = records)
  sides <- unlist(lapply(records, function(record) list(
    list(input = record$theta_plus, value = record$objective_plus),
    list(input = record$theta_minus, value = record$objective_minus)
  )), recursive = FALSE)
  audit <- list(objective = c(list(list(input = theta, value = 0)), sides),
    gradient = list(list(input = theta, raw_gradient = unname(gradient),
      supplied_names = NULL, named_gradient = gradient)))
  expect_true(runner$.spde_slope_gauge_nofit_audit_ok(audit, nofit))
  audit$objective[[3L]]$value <- 999
  expect_false(runner$.spde_slope_gauge_nofit_audit_ok(audit, nofit))
  audit$objective[[3L]]$value <- -1
  audit$gradient[[1L]]$named_gradient <- unname(gradient)
  expect_false(runner$.spde_slope_gauge_nofit_audit_ok(audit, nofit))
  audit$gradient[[1L]]$named_gradient <- gradient
  audit$gradient[[1L]]$supplied_names <- rev(order)
  expect_false(runner$.spde_slope_gauge_nofit_audit_ok(audit, nofit))
})
