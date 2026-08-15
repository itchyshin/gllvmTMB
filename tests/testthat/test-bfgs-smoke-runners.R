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
  expect_match(p2_text, "BFGS_P1_S3_C360_R3_V5", fixed = TRUE)
  expect_match(p2_text, "BFGS_P2_S6_C360_R3_V5", fixed = TRUE)
  expect_match(p2_text, ".bfgs_smoke_normalise_fallback", fixed = TRUE)
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
  main_at <- regexpr("main <- function()", text, fixed = TRUE)[[1L]]
  expect_gt(main_at, 0L)
  main_text <- substr(text, main_at, nchar(text))
  ledger_start <- regexpr("ledger <- list(", main_text, fixed = TRUE)[[1L]]
  receipt_read <- regexpr('receipt <- tryCatch(readRDS(file.path(root, "root-receipt.rds"))',
    main_text, fixed = TRUE)[[1L]]
  fit_start <- regexpr("fit <- withCallingHandlers", main_text, fixed = TRUE)[[1L]]

  expect_gt(ledger_start, 0L)
  expect_lt(receipt_read, ledger_start)
  expect_gt(fit_start, ledger_start)
  expect_match(text, "if (dirty()) provenance_stop", fixed = TRUE)
  expect_match(text, "core_runner_md5", fixed = TRUE)
  expect_match(text, "design_md5", fixed = TRUE)
  expect_match(text, "source_md5", fixed = TRUE)
  expect_match(text, "bfgs_contract = hash_file(contract_file)", fixed = TRUE)
  expect_match(text, "dll_path", fixed = TRUE)
  expect_match(text, "loaded DLL content does not match the sealed source DLL",
    fixed = TRUE)
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
  expect_match(text, "bfgs_smoke_gradient_order_ok", fixed = TRUE)
  expect_false(grepl("par <- fit$opt$par", text, fixed = TRUE))
  expect_match(text, ".bfgs_smoke_normalise_fallback", fixed = TRUE)
  expect_match(text, "bfgs_smoke_recompute_result(ledger$bfgs)", fixed = TRUE)
  expect_match(text, "atomic_rds(ledger, ledger_path)", fixed = TRUE)
  expect_match(main_text,
    "disk, source_gate, current_commit, root", fixed = TRUE)
  expect_match(text, "ledger <<- .bfgs_smoke_normalise_fallback", fixed = TRUE)
  expect_match(text, ".internal_continuation = FALSE", fixed = TRUE)
})

test_that("BFGS runner uses an atomic preflight, claim, marker, and terminal lifecycle", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "run-bfgs-paper2-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  required <- c("atomic_rds <- function", "atomic_lines <- function",
    "atomic manifest rename failed", "atomic preflight root rename failed",
    "claim_path <- file.path(root, \".attempt-started.claim\")",
    "if (!dir.create(claim_path, showWarnings = FALSE))",
    "atomic_rds(attempt_marker, marker_path)",
    "on.exit({", "atomic_rds(ledger, ledger_path)",
    "disk, source_gate, current_commit, root"
  )
  for (needle in required) expect_match(text, needle, fixed = TRUE, info = needle)
  main_at <- regexpr("main <- function()", text, fixed = TRUE)[[1L]]
  expect_gt(main_at, 0L)
  main_text <- substr(text, main_at, nchar(text))
  seal_at <- regexpr("seal <- function()", main_text, fixed = TRUE)[[1L]]
  finalizer_at <- regexpr("on.exit({", main_text, fixed = TRUE)[[1L]]
  expect_true(all(c(seal_at, finalizer_at) > 0L))
  seal_text <- substr(main_text, seal_at, finalizer_at - 1L)
  lifecycle <- vapply(c(
    finalizer = "on.exit({",
    claim = "if (!dir.create(claim_path, showWarnings = FALSE))",
    marker = "claimed <- TRUE\n  atomic_rds(attempt_marker, marker_path)",
    entry = "atomic_rds(ledger$bfgs_entry, entry_path)",
    sealed_terminal = "terminal <- seal()"
  ), function(x) regexpr(x, main_text, fixed = TRUE)[[1L]], numeric(1L))
  expect_true(all(lifecycle > 0L),
    info = paste(names(lifecycle)[lifecycle < 1L], collapse = ","))
  expect_lt(lifecycle[["finalizer"]], lifecycle[["claim"]])
  expect_lt(lifecycle[["claim"]], lifecycle[["marker"]])
  expect_lt(lifecycle[["marker"]], lifecycle[["entry"]])
  expect_lt(lifecycle[["entry"]], lifecycle[["sealed_terminal"]])

  seal_steps <- vapply(c(
    recompute = "bfgs_smoke_recompute_result(ledger$bfgs)",
    in_memory = "in_memory <- bfgs_smoke_validate_terminal_ledger(",
    atomic_ledger = "atomic_rds(ledger, ledger_path)",
    manifest = "manifest(root, terminal_paths())",
    reread = "disk <- tryCatch(readRDS(ledger_path)",
    disk_validation = "disk, source_gate, current_commit, root"
  ), function(x) regexpr(x, seal_text, fixed = TRUE)[[1L]], numeric(1L))
  expect_true(all(seal_steps > 0L),
    info = paste(names(seal_steps)[seal_steps < 1L], collapse = ","))
  expect_lt(seal_steps[["recompute"]], seal_steps[["in_memory"]])
  expect_lt(seal_steps[["in_memory"]], seal_steps[["atomic_ledger"]])
  expect_lt(seal_steps[["atomic_ledger"]], seal_steps[["manifest"]])
  expect_lt(seal_steps[["manifest"]], seal_steps[["reread"]])
  expect_lt(seal_steps[["reread"]], seal_steps[["disk_validation"]])
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
