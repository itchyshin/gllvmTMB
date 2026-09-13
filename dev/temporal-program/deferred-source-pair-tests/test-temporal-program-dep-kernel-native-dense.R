test_that("temporal_dep kernel native likelihood agrees with an independent dense oracle at fitted and kernel-perturbed points", {
  skip_if_not_installed("TMB")
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-native-dense.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  source(script, local = TRUE)
  skip_if_not(.temporal_dep_kernel_native_dense_has_helpers(),
    "requires an installed or loaded gllvmTMB namespace with temporal formula helpers")
  expect_true(is.function(.temporal_dep_kernel_native_dense_helper("temporal_dep")))
  expect_true(is.function(.temporal_dep_kernel_native_dense_helper("kernel_indep")))

  diagnostic <- temporal_dep_kernel_native_dense_diagnostic()
  records <- diagnostic$records
  expect_identical(names(records), c("fitted", paste0("kernel_", 1:3, "_plus_0.075")))
  expect_match(diagnostic$contract, "no solver or recovery claim", fixed = TRUE)

  for (record in records) {
    expect_true(is.finite(record$native_nll))
    expect_true(is.finite(record$dense_nll))
    ## The dense expression includes the full Gaussian normalising constant.
    expect_true(record$nll_error < 3e-6, info = record$point)
    expect_identical(names(record$native_gradient), record$labels)
    expect_identical(names(record$dense_gradient), record$labels)
    expect_true(all(is.finite(record$native_gradient)))
    expect_true(all(is.finite(record$dense_gradient)))
    expect_true(max(record$gradient_error) < 5e-5, info = paste(
      record$point, record$labels[[which.max(record$gradient_error)]]
    ))
  }

  ## The control is a distinct, wrong product covariance, so agreement cannot
  ## be obtained by silently substituting a source-by-time interaction.
  expect_gt(abs(records$fitted$dense_nll - records$fitted$product_control_nll), 1e-3)
})

test_that("native-dense diagnostic labels every active fixed coordinate", {
  skip_if_not_installed("TMB")
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-native-dense.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  source(script, local = TRUE)
  skip_if_not(.temporal_dep_kernel_native_dense_has_helpers(),
    "requires an installed or loaded gllvmTMB namespace with temporal formula helpers")

  diagnostic <- temporal_dep_kernel_native_dense_diagnostic()
  labels <- diagnostic$records$fitted$labels
  expect_true(all(c("b_fix[1]", "theta_temporal_time[1]",
    "theta_temporal_rr[1]", "theta_rr_phy[1]", "log_sigma_eps[1]") %in% labels))
  expect_identical(labels, .temporal_dep_kernel_native_dense_labels(
    diagnostic$records$fitted$fixed
  ))
})
