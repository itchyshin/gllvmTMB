test_that("R2 q = 1/q = 2 fixed-coordinate references satisfy their identities", {
  skip_on_cran()
  source(test_path("helper-aghq-o3.R"))

  results <- o3_r2_run_default()

  for (result in results) {
    expect_equal(result$convergence, 0L)
    expect_lt(abs(result$laplace_difference), 1e-6)
    expect_lt(result$terminal_difference, 1e-4)
    expect_lte(max(abs(result$permutation_unit)), 1e-10)
    expect_lte(max(abs(result$permutation_row)), 1e-10)
    expect_true(all(result$diagnostics$chol_ok))
    expect_true(all(is.finite(result$diagnostics$min_eigen)))
    expect_gt(min(result$diagnostics$min_eigen), 0)
    expect_lte(result$max_condition, 1e8)
  }
})

test_that("R2 receipt writer emits an interpretable local-only evidence bundle", {
  skip_on_cran()
  source(test_path("helper-aghq-o3.R"))

  result <- o3_r2_run_fixture("baseline_q1", 1L, 20260719L)
  out <- tempfile("aghq-r2-receipt-")
  receipt <- o3_r2_write_receipt(list(result), out)
  expect_true(all(file.exists(file.path(out, c(
    "manifest.csv", "unit_diagnostics.csv", "fixture_summary.csv", "truth.rds", "README.md"
  )))))
  expect_identical(receipt$fixture_summary$status, "pass")
  expect_identical(receipt$condition_reject$status, "condition_exceeds_limit")
  manifest <- utils::read.csv(file.path(out, "manifest.csv"), stringsAsFactors = FALSE)
  expect_true(all(c("tmb_version", "node_vector") %in% names(manifest)))
  expect_true(all(is.finite(receipt$fixture_summary$fit_gradient_norm)))
  expect_true(all(receipt$fixture_summary$fit_gradient_norm >= 0))
  expect_match(
    manifest$condition_parameters[manifest$fixture_id == "condition_reject_q2"],
    "Lambda=\\(\\(50000,0\\),\\(50000,1\\)\\)"
  )
  diagnostics <- utils::read.csv(file.path(out, "unit_diagnostics.csv"), stringsAsFactors = FALSE)
  expect_true("condition_reject_q2" %in% diagnostics$fixture_id)
  truth <- readRDS(file.path(out, "truth.rds"))
  expect_identical(truth$condition_reject_q2$y, c(50, 50))
  expect_equal(truth$condition_reject_q2$loading[1, 1], 50000)
})

test_that("R2 receipt writer rejects q >= 3", {
  source(test_path("helper-aghq-o3.R"))

  result <- o3_r2_run_fixture("baseline_q1", 1L, 20260719L)
  result$q <- 3L
  expect_error(
    o3_r2_write_receipt(list(result), tempfile("aghq-r2-q3-")),
    "q = 1 or q = 2"
  )
  expect_error(
    o3_r2_run_fixture("forbidden_q3", 3L, 20260726L),
    "q %in% 1:2"
  )
})

test_that("R2 rejects a finite q = 2 condition-threshold fixture before quadrature", {
  source(test_path("helper-aghq-o3.R"))

  guard <- o3_r2_condition_reject()
  expect_identical(guard$status, "condition_exceeds_limit")
  expect_true(isTRUE(guard$chol_ok))
  expect_true(is.finite(guard$min_eigen))
  expect_gt(guard$min_eigen, 0)
  expect_gt(guard$condition, 1e8)
})
