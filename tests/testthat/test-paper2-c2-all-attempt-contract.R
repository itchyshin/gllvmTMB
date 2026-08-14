## Paper 2 C2 Tier-1 contract: all rows are hand-built and no model is invoked.
test_that("C2 retains the fixed cells and the S=6 negative record", {
  env <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "dev", "isdm-package-recovery", "paper2-c2-all-attempt-contract.R"), local = env)
  cells <- env$paper2_c2_cells()
  expect_identical(cells$S, c(6L, 20L, 60L))
  expect_true(all(cells$R == 20L))
  retained <- env$paper2_c2_retained_s6()
  expect_silent(env$paper2_c2_validate_retained_s6(retained))
  expect_false(retained$numerical_admission)
  expect_false(retained$psi_pass)
  expect_false(env$paper2_c2_metric_pass(retained$metrics))
})
test_that("C2 preserves all-attempt denominators and separates A from P", {
  env <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "dev", "isdm-package-recovery", "paper2-c2-all-attempt-contract.R"), local = env)
  metrics <- list(beta = 0.1, gamma = 0.1, map_correlation = 0.8, shared_covariance = 0.2, psi_variance = 0.1)
  attempts <- lapply(seq_len(20L), function(i) env$paper2_c2_attempt(
    paste0("a", i), numerical_admission = i %% 2L == 0L, psi_pass = i %% 3L == 0L,
    metrics = metrics, first_failure = if (i %% 2L == 0L) NA_character_ else "nonadmission"
  ))
  summary <- env$paper2_c2_summarise(attempts)
  expect_identical(summary$denominator, 20L)
  expect_identical(sum(summary$A_by_P), 20L)
  expect_identical(unname(summary$atomic[["numerical_admission"]]), 10L)
  unavailable <- env$paper2_c2_attempt("bad", FALSE, FALSE, metrics,
    status = "UNAVAILABLE", available = FALSE, first_failure = "error")
  expect_silent(env$paper2_c2_validate_attempt(unavailable))
  expect_error(env$paper2_c2_summarise(attempts[-1L]), "denominator")
  expect_error(env$paper2_c2_summarise("not-a-list"), "denominator")
})
test_that("C2 receipt is immutable and points to the frozen design", {
  env <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "dev", "isdm-package-recovery", "paper2-c2-all-attempt-contract.R"), local = env)
  retained <- env$paper2_c2_retained_s6()
  receipt <- list(
    schema = "PAPER2_C2_NO_FIT_RECEIPT_V1", frozen_cells = env$paper2_c2_cells(),
    retained_s6 = retained, retained_s6_summary = env$paper2_c2_summarise(list(retained), 1L),
    historical_provenance = list(seed = 86122L, S = 6L, C = 360L, r = 3L, b = 1L, d = 1L,
      retained_commit = "57613984ddf844194326c3829ae97aab28ba3a35",
      historical_fixture_sha256 = "701ba79e88a354c7285ac4786d9464b3b8b31edf8789e5fb71ed1f887bee9969"), current_contract_md5 = rep("test", 3L),
    scope = "private_no_fit_contract_only"
  )
  expect_silent(env$paper2_c2_validate_receipt(receipt))
  receipt$scope <- "fit"
  expect_error(env$paper2_c2_validate_receipt(receipt), "scope")
  receipt$scope <- "private_no_fit_contract_only"
  receipt$historical_provenance$historical_fixture_sha256 <- strrep("a", 64L)
  expect_error(env$paper2_c2_validate_receipt(receipt), "provenance")
})
test_that("C2 helpers have no model-execution path", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery", "paper2-c2-all-attempt-contract.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_false(grepl("MakeADFun\\(|\\.gll_isdm_fit\\(|nlminb\\(|optim\\(|profile\\(", text))
})
