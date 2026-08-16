test_that("Paper 2 G3 smoke runner seals provenance and failure receipts", {
  path <- isdm_dev_path("run-g3-paper2-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, "86302L", fixed = TRUE)
  expect_match(text, 'time-limit-s", "1500"', fixed = TRUE)
  expect_match(text, "setTimeLimit", fixed = TRUE)
  expect_match(text, "G3_P2_S6_C360_R3_V1", fixed = TRUE)
  expect_match(text, "G3_CURVATURE_UNAVAILABLE", fixed = TRUE)
  expect_match(text, "selected likelihood_nll does not match the G3 objective", fixed = TRUE)
  expect_match(text, "INVALID_PROVENANCE", fixed = TRUE)
  expect_match(text, "coordinate_ids", fixed = TRUE)
  expect_match(text, "is.null(names(par_fixed))", fixed = TRUE)
  expect_match(text, "current_source_md5", fixed = TRUE)
  expect_match(text, "all-attempt-ledger.rds", fixed = TRUE)
  expect_false(grepl("profile_theta\\(|nlminb\\(|TMB::MakeADFun\\(|Totoro|DRAC", text))
  expect_true(is.expression(parse(path)))
})

test_that("Paper 2 G3 runner fails closed before fitting or reusing a root", {
  path <- isdm_dev_path("run-g3-paper2-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  ledger_start <- regexpr("ledger <- list\\(", text)[[1L]]
  provenance_gate <- regexpr("g3p_compare_execution_context", text)[[1L]]
  fit_start <- regexpr("fit <- tryCatch", text, fixed = TRUE)[[1L]]
  expect_gt(ledger_start, 0L)
  expect_gt(provenance_gate, ledger_start)
  expect_gt(fit_start, provenance_gate)
  expect_match(text,
    'file.exists(file.path(root, "all-attempt-ledger.rds"))', fixed = TRUE)
  expect_match(text, "smoke requires one untouched immutable preflight", fixed = TRUE)
  expect_match(text, "INVALID_PROVENANCE", fixed = TRUE)
  expect_match(text, "selected likelihood_nll does not match the G3 objective", fixed = TRUE)
  expect_match(text, ".gllvmTMB_isdm_g3_full_vector_trials", fixed = TRUE)
  expect_match(text, "G3_CURVATURE_UNAVAILABLE", fixed = TRUE)
  expect_match(text, "RUNNER_ERROR", fixed = TRUE)
  expect_match(text, "setTimeLimit", fixed = TRUE)
  expect_match(text, "terminal = FALSE", fixed = TRUE)
  expect_match(text, "ledger$terminal <- TRUE", fixed = TRUE)
  expect_match(text, 'saveRDS(ledger, file.path(root, "all-attempt-ledger.rds"))',
    fixed = TRUE)
})

test_that("Paper 2 G3 runner has no retry, profile, campaign, remote, or relaxed gate", {
  path <- isdm_dev_path("run-g3-paper2-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  forbidden <- c(
    "profile_theta\\(", "nlminb\\(", "optim\\(", "retry_enabled[[:space:]]*=[[:space:]]*TRUE",
    "profile_enabled[[:space:]]*=[[:space:]]*TRUE", "alpha_grid[[:space:]]*=",
    "raw_gradient_gate[[:space:]]*=", "health_gradient_gate[[:space:]]*=",
    "condition_limit[[:space:]]*=", "direction_tolerance[[:space:]]*=",
    "ssh[[:space:]]", "sbatch[[:space:]]", "Totoro", "DRAC",
    "run[-_ ]?campaign", "campaign[-_ ]?runner"
  )
  for (pattern in forbidden) {
    expect_false(grepl(pattern, text, ignore.case = TRUE), info = pattern)
  }
})
