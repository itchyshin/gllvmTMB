## Replacement-smoke receipt contract: pure no-fit checks only.

project_file <- function(...) {
  file.path(normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE), ...)
}

test_that("Paper 1 replacement fixture matches the independent two-field engine", {
  isdm_dev_path()  # skips when dev/ did not ship in the built package
  e <- new.env(parent = globalenv())
  source(project_file("dev", "isdm-package-recovery", "spatial-isdm-gate-b-smoke-fixture.R"), local = e)
  fx <- e$spatial_isdm_gate_b_make_fixture()

  expect_identical(fx$truth$seed, 86202L)
  expect_identical(fx$truth$constants$field_correlation, 0)
  expect_false(identical(unname(fx$truth$field_draw_seeds[["ecological"]]),
                        unname(fx$truth$field_draw_seeds[["gbif_bias"]])))
  expect_identical(fx$truth$n_species, 3L)
  expect_identical(fx$truth$n_cell, 360L)
  expect_identical(fx$truth$n_visit, 3L)
  expect_equal(nrow(fx$rows), 4320L)
  expect_true(all(is.na(fx$B[fx$rows$source == "survey", 1L])))
})

test_that("receipt maps both spatial truths to their distinct fit outputs", {
  isdm_dev_path()  # skips when dev/ did not ship in the built package
  runner <- paste(readLines(project_file("dev", "isdm-package-recovery",
    "run-spatial-isdm-gate-b-smoke.R"), warn = FALSE), collapse = "\n")
  expect_match(runner, 'truth = "shared_Sigma", output = "Sigma_spde_slope_intercept"')
  expect_match(runner, 'truth = "bias_Sigma", output = "Sigma_spde_slope_slope"')
  expect_match(runner, 'field_outputs <- list\\(ecological = fit\\$report\\$Sigma_spde_slope_intercept')
  expect_match(runner, "extractor_truth_map = source_map\\$extractor_truth_map")
  expect_match(runner, "preflight and smoke require a clean committed estimator tree")
})

test_that("terminal all-attempt ledger has every required field even on a fit error", {
  isdm_dev_path()  # skips when dev/ did not ship in the built package
  e <- new.env(parent = globalenv())
  source(project_file("dev", "isdm-package-recovery", "spatial-isdm-gate-b-smoke-fixture.R"), local = e)
  ledger <- e$spatial_isdm_gate_b_new_ledger(
    "paper1-spatial-b2-86202",
    source_map = list(shared_mesh_range_rank = TRUE),
    versions = list(R = "test", package = "test", commit = "test")
  )
  ledger$status <- "FIT_ERROR"
  ledger$fit_error <- "intentional no-fit failure"
  ledger$terminal <- TRUE
  ledger$finished_at <- "2026-08-13T00:00:00"

  expect_silent(e$spatial_isdm_gate_b_validate_terminal_ledger(ledger))
  expect_identical(names(ledger), e$spatial_isdm_gate_b_required_ledger_fields())
  expect_error(e$spatial_isdm_gate_b_validate_terminal_ledger(ledger[-1L]), "invalid terminal")
})

test_that("replacement runner finalizes before optional telemetry", {
  isdm_dev_path()  # skips when dev/ did not ship in the built package
  runner <- paste(readLines(project_file("dev", "isdm-package-recovery",
    "run-spatial-isdm-gate-b-smoke.R"), warn = FALSE), collapse = "\n")
  ledger_write <- regexpr('saveRDS\\(ledger, file.path\\(root, "all-attempt-ledger.rds"\\)\\)', runner)
  telemetry_write <- regexpr('saveRDS\\(telemetry, file.path\\(root, "telemetry.rds"\\)\\)', runner)
  expect_gt(as.integer(ledger_write), 0L)
  expect_gt(as.integer(telemetry_write), as.integer(ledger_write))
  expect_match(runner, "on.exit\\(finalise\\(\\), add = TRUE\\)")
  expect_match(runner, "this immutable root has already consumed its one Gate-B smoke attempt")
})
