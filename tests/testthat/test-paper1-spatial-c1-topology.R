## Paper 1 C1 is a Tier-1 receipt test: it reads a hand-built retained ledger.

test_that("C1 retains the spatial-only B2 maximum as Case D and NO_CANDIDATE", {
  env <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "dev", "isdm-package-recovery",
                             "paper1-spatial-c1-topology.R"), local = env)
  gradient <- c(rep(0, 19), -0.003392914, 0, 0)
  names <- c(rep("b_fix", 12), rep("theta_diag_B", 3), "log_kappa_spde",
             rep("theta_rr_spde_slope", 6))
  ledger <- list(
    schema = "SPATIAL_ISDM_GATE_B2_ALL_ATTEMPT_V1", attempt_id = "paper1-spatial-b2-86202",
    status = "FIT_RETURNED", terminal = TRUE, objective = 2467.705970,
    optimizer_code = 0L, gradient = gradient,
    gradient_by_block = list(outer = stats::setNames(gradient, names)),
    pd_hessian = TRUE, boundary_flags = character(),
    source_map = list(gbif_bias_column = "isdm_gbif", pa_gbif_field_structural_zero = TRUE,
      extractor_truth_map = list(gbif_bias = c(truth = "bias_Sigma",
                                                output = "Sigma_spde_slope_slope"))),
    field_outputs = list(), versions = list(commit = "d5c1481c")
  )
  receipt <- env$paper1_c1_receipt(ledger)
  expect_silent(env$paper1_c1_validate_receipt(receipt))
  expect_identical(receipt$maximum$index, 20L)
  expect_identical(receipt$maximum$block, "theta_rr_spde_slope")
  expect_identical(receipt$classifier$case, "D")
  expect_identical(receipt$decision$candidate, "NO_CANDIDATE")
})

test_that("C1 adversarial topology partitions Case A/C/D without a fitter", {
  env <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "dev", "isdm-package-recovery",
                             "paper1-spatial-c1-topology.R"), local = env)
  a <- env$paper1_c1_classify_topology(c(2e-4, -3e-4), c("b_fix", "theta_rr_B"),
                                        TRUE, character())
  c_case <- env$paper1_c1_classify_topology(c(2e-4, -1.5e-3), c("b_fix", "theta_rr_B"),
                                             TRUE, character())
  spatial <- env$paper1_c1_classify_topology(c(2e-4, -1.5e-3),
                                               c("b_fix", "theta_rr_spde_slope"),
                                               TRUE, character())
  tied <- env$paper1_c1_classify_topology(c(1.5e-3, -1.5e-3),
                                            c("b_fix", "theta_rr_spde_slope"),
                                            TRUE, character())
  expect_identical(a$case, "A")
  expect_identical(c_case$case, "C")
  expect_identical(spatial$case, "D")
  expect_identical(tied$case, "D")
  text <- paste(readLines(testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "paper1-spatial-c1-topology.R"), warn = FALSE), collapse = "\n")
  expect_false(grepl("MakeADFun\\(|\\.gll_isdm_fit\\(|nlminb\\(|optim\\(|profile\\(", text))
})
