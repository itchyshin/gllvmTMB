test_that("Paper 1 G3 smoke runner is fresh-seed, bounded, and one-shot", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery", "run-g3-paper1-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, "86301L", fixed = TRUE)
  expect_match(text, "elapsed = 900", fixed = TRUE)
  expect_match(text, "G3_P1_S3_C360_R3_V1", fixed = TRUE)
  expect_match(text, "all-attempt-ledger.rds", fixed = TRUE)
  expect_false(grepl("profile_theta\\(|nlminb\\(|TMB::MakeADFun\\(|Totoro|DRAC", text))
  expect_true(is.expression(parse(path)))
})

test_that("Paper 1 G3 runner seals marginal-curvature provenance fail closed", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "run-g3-paper1-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  ledger_start <- regexpr("ledger <- list\\(", text)[[1L]]
  receipt_read <- regexpr('readRDS(file.path(root, "root-receipt.rds"))',
    text, fixed = TRUE)[[1L]]
  fit_start <- regexpr("fit <- tryCatch", text, fixed = TRUE)[[1L]]
  expect_gt(ledger_start, 0L)
  expect_gt(receipt_read, ledger_start)
  expect_gt(fit_start, receipt_read)
  expect_match(text, "curvature_callback", fixed = TRUE)
  expect_match(text, "sdreport_cov_fixed", fixed = TRUE)
  expect_match(text, "current_source_md5", fixed = TRUE)
  expect_match(text, "estimator source or DLL identity drift", fixed = TRUE)
  expect_match(text, "clean_tree()", fixed = TRUE)
  expect_match(text, ".gllvmTMB_isdm_g3_full_vector_trials", fixed = TRUE)
  expect_match(text, "INVALID_PROVENANCE", fixed = TRUE)
  expect_match(text, "RUNNER_ERROR", fixed = TRUE)
  expect_match(text, "setTimeLimit", fixed = TRUE)
  expect_match(text, "terminal = FALSE", fixed = TRUE)
  expect_match(text, 'file.exists(file.path(root, "all-attempt-ledger.rds"))',
    fixed = TRUE)
  expect_match(text, "smoke requires one untouched immutable preflight", fixed = TRUE)
  expect_match(text, 'saveRDS(ledger, file.path(root, "all-attempt-ledger.rds"))',
    fixed = TRUE)
  expect_false(grepl("\\$he\\(", text))
})

test_that("Paper 1 G3 runner has no retry, profile, remote, or relaxed gate", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "run-g3-paper1-smoke.R")
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
