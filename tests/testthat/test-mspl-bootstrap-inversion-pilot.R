test_that("private MSPL constrained-bootstrap inversion pilot has a fixed finite smoke contract", {
  runner <- testthat::test_path(
    "..", "..", "inst", "sim", "lane-b-uncertainty",
    "run-mspl-bootstrap-inversion-pilot.R"
  )
  expect_true(file.exists(runner))
  expect_error(
    system2("Rscript", c("--vanilla", runner, "validate"),
      stdout = TRUE, stderr = TRUE),
    NA
  )

  root <- tempfile("mspl-inversion-smoke-")
  output <- system2("Rscript", c("--vanilla", runner, "smoke", "--output", root),
    env = c("GLLVM_TMB_PILOT_SOURCE=true"), stdout = TRUE, stderr = TRUE
  )
  expect_null(attr(output, "status"))
  receipt <- readRDS(file.path(root, "receipt.rds"))
  expect_identical(receipt$kind, "private_mspl_constrained_bootstrap_test_inversion_pilot_v1")
  expect_identical(receipt$mode, "smoke")
  expect_identical(receipt$public_fence, "unchanged")
  expect_match(receipt$claim_boundary, "not calibrated coverage")
  expect_identical(nrow(receipt$trace), 6L)
  expect_identical(nrow(receipt$attempts), 12L)
  expect_true(all(is.finite(receipt$trace$p_value)))
  expect_true(all(receipt$trace$constrained_status %in% c("ok", "optimizer_failed", "nonfinite", "state_construction_failed")))
  expect_true(all(receipt$attempts$status %in% c("ok", "simulate_error", "refit_error", "refit_optimizer_failed", "objective_identity_failed")))
  expect_true(all(receipt$trace$constrained_status != "ok" | receipt$trace$estimator_id == 1L))
  expect_true(all(receipt$trace$constrained_status != "ok" |
    receipt$trace$objective_source == "fit$tmb_obj (penalised LA-MSPL)"))
})
