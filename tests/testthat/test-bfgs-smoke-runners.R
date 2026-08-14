test_that("BFGS paper runners are bounded, immutable, and provenance-first", {
  p1 <- testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "run-bfgs-paper1-smoke.R")
  p2 <- testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "run-bfgs-paper2-smoke.R")
  p1_text <- paste(readLines(p1, warn = FALSE), collapse = "\n")
  p2_text <- paste(readLines(p2, warn = FALSE), collapse = "\n")

  expect_match(p1_text, 'GLLVM_BFGS_SMOKE_PAPER = "paper1"', fixed = TRUE)
  expect_match(p1_text, 'run-bfgs-paper2-smoke.R', fixed = TRUE)
  expect_match(p2_text, 'paper <- Sys.getenv("GLLVM_BFGS_SMOKE_PAPER"', fixed = TRUE)
  expect_match(p2_text, "BFGS_P1_S3_C360_R3_V1", fixed = TRUE)
  expect_match(p2_text, "BFGS_P2_S6_C360_R3_V1", fixed = TRUE)
  expect_match(p2_text, "elapsed = 1800", fixed = TRUE)
  expect_match(p2_text, "Expected wall clock: 5-20 minutes", fixed = TRUE)
  expect_match(p2_text, "all-attempt-ledger.rds", fixed = TRUE)
  expect_match(p2_text, 'mode <- value("mode", "validate")', fixed = TRUE)
  expect_match(p2_text, "RUNNER_VALIDATION_PASS (no fit)", fixed = TRUE)
  expect_match(p2_text, 'source(contract_file, local = TRUE)', fixed = TRUE)
  validation_start <- regexpr('if (identical(mode, "validate"))', p2_text,
    fixed = TRUE)[[1L]]
  preflight_start <- regexpr('if (identical(mode, "preflight"))', p2_text,
    fixed = TRUE)[[1L]]
  expect_gt(validation_start, 0L)
  expect_gt(preflight_start, validation_start)
  validation_block <- substr(p2_text, validation_start, preflight_start - 1L)
  expect_false(grepl(".gll_isdm_fit", validation_block, fixed = TRUE))
  expect_match(validation_block, 'quit(save = "no")', fixed = TRUE)
  expect_match(p2_text, "smoke requires one untouched immutable preflight",
    fixed = TRUE)
  expect_match(p2_text, "identical(root, expected_root)", fixed = TRUE)
  expect_match(p2_text, "root = expected_root", fixed = TRUE)
  expect_true(is.expression(parse(p1)))
  expect_true(is.expression(parse(p2)))
})

test_that("BFGS runner records terminal provenance before optimizer entry", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "run-bfgs-paper2-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  ledger_start <- regexpr("ledger <- list\\(", text)[[1L]]
  receipt_read <- regexpr('readRDS(file.path(root, "root-receipt.rds"))',
    text, fixed = TRUE)[[1L]]
  fit_start <- regexpr("fit <- withCallingHandlers", text, fixed = TRUE)[[1L]]

  expect_gt(ledger_start, 0L)
  expect_gt(receipt_read, ledger_start)
  expect_gt(fit_start, receipt_read)
  expect_match(text, "if (dirty()) provenance_stop", fixed = TRUE)
  expect_match(text, "core_runner_md5", fixed = TRUE)
  expect_match(text, "design_md5", fixed = TRUE)
  expect_match(text, "source_md5", fixed = TRUE)
  expect_match(text, "bfgs_contract = hash_file(contract_file)", fixed = TRUE)
  expect_match(text, "dll_path", fixed = TRUE)
  expect_match(text, "session_info_md5", fixed = TRUE)
  expect_match(text, "time_estimate_md5", fixed = TRUE)
  expect_match(text, "control_md5", fixed = TRUE)
  expect_match(text, "bfgs_smoke_validate_receipt", fixed = TRUE)
  expect_match(text, "bfgs_smoke_validate_manifest", fixed = TRUE)
  expect_match(text, "bfgs_smoke_consumed_state", fixed = TRUE)
  expect_match(text, "bfgs_smoke_validate_terminal_ledger", fixed = TRUE)
  expect_match(text, "bfgs_smoke_validate_paper2_prerequisite", fixed = TRUE)
  expect_match(text, "paper2_terminal_status", fixed = TRUE)
  expect_match(text, "paper2_terminal_md5", fixed = TRUE)
  expect_match(text, "select_initial_nlminb(fit)", fixed = TRUE)
  expect_match(text, "fit$isdm_polish_provenance$raw", fixed = TRUE)
  expect_match(text, "G2I_INTERNAL_ISDM_POLISH_V1", fixed = TRUE)
  expect_match(text, "nrow(history) == 1L", fixed = TRUE)
  expect_match(text, "warm_restart_provenance", fixed = TRUE)
  expect_match(text, "identical(warm$warm_restart_attempted, FALSE)",
    fixed = TRUE)
  expect_match(text, "identical(warm$warm_restart_accepted, FALSE)",
    fixed = TRUE)
  expect_match(text, "identical(polish$attempted, FALSE)", fixed = TRUE)
  expect_match(text, "identical(polish$accepted, FALSE)", fixed = TRUE)
  expect_match(text, "restart_history", fixed = TRUE)
  expect_match(text, "gradient_replay_relative_tolerance <- 1e-8", fixed = TRUE)
  expect_false(grepl("par <- fit$opt$par", text, fixed = TRUE))
  expect_match(text, "INVALID_PROVENANCE", fixed = TRUE)
  expect_match(text, "BFGS_OPTIMIZER_ERROR", fixed = TRUE)
  expect_match(text, "BFGS_INFRASTRUCTURE_HOLD", fixed = TRUE)
  expect_match(text, "BFGS_CURVATURE_UNAVAILABLE", fixed = TRUE)
  expect_match(text, "saveRDS(ledger, ledger_path)", fixed = TRUE)
  expect_match(text, "ledger$terminal <<- TRUE", fixed = TRUE)
  expect_match(text, ".internal_continuation = FALSE", fixed = TRUE)
})

test_that("BFGS runners expose no retry, profile, G3, remote, or relaxed path", {
  paths <- c(
    testthat::test_path("..", "..", "dev", "isdm-package-recovery",
      "run-bfgs-paper1-smoke.R"),
    testthat::test_path("..", "..", "dev", "isdm-package-recovery",
      "run-bfgs-paper2-smoke.R")
  )
  text <- paste(unlist(lapply(paths, readLines, warn = FALSE)), collapse = "\n")
  forbidden <- c(
    "profile_theta\\(", "(^|[[:space:]{;(])nlminb\\(", "TMB::MakeADFun\\(",
    "retry_enabled[[:space:]]*=[[:space:]]*TRUE",
    "profile_enabled[[:space:]]*=[[:space:]]*TRUE",
    "\\.gllvmTMB_isdm_g3_", "alpha_grid[[:space:]]*=",
    "raw_gradient_gate[[:space:]]*=", "health_gradient_gate[[:space:]]*=",
    "condition_limit[[:space:]]*=",
    "ssh[[:space:]]", "sbatch[[:space:]]", "Totoro", "DRAC",
    "run[-_ ]?campaign", "campaign[-_ ]?runner"
  )
  for (pattern in forbidden) {
    expect_false(grepl(pattern, text, ignore.case = TRUE), info = pattern)
  }
  helper_hits <- gregexpr(
    ".gllvmTMB_isdm_bfgs_exact_gradient_continuation", text, fixed = TRUE
  )[[1L]]
  expect_false(identical(helper_hits, -1L))
  expect_length(helper_hits, 1L)
  expect_match(text, "n_init = 1L", fixed = TRUE)
  expect_match(text, "init_jitter = 0", fixed = TRUE)
  expect_match(text, "aghq = FALSE", fixed = TRUE)
})
