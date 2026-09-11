test_that("retained curvature sources the independent block oracle and preserves literal dimensions", {
  skip_if_not_installed("TMB")
  oracle <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-dep-kernel-retained-curvature.R"), mustWork = FALSE)
  skip_if_not(file.exists(oracle) && file.exists(script))
  pkgload::load_all(normalizePath(testthat::test_path("..", "..")), quiet = TRUE,
    export_all = FALSE)
  source(oracle, local = TRUE)
  source(script, local = TRUE)
  old_wd <- setwd(normalizePath(testthat::test_path("..", "..")))
  on.exit(setwd(old_wd), add = TRUE)
  .temporal_dep_kernel_retained_curvature_source()

  fixture <- .temporal_dep_kernel_retained_fixture(2609221L, n_series = 3L, n_time = 4L)
  fit <- .temporal_dep_kernel_retained_fit(fixture)
  fixed <- .temporal_dep_kernel_retained_curvature_truth_point(fit, fixture)
  point <- .temporal_dep_kernel_retained_curvature_point(fit, fixture, fixed, "truth")
  expect_equal(
    .temporal_dep_kernel_retained_block_nll(fit, fixed, fixture),
    .temporal_dep_kernel_retained_literal_dense_nll(fit, fixed, fixture), tolerance = 2e-7
  )
  expect_identical(dim(point$observed_information), c(10L, 10L))
  expect_identical(names(point$curvature), c(paste0("kernel_", 1:3),
    "theta_temporal_time", paste0("theta_temporal_rr_", 1:6)))
  expect_true(all(point$coordinate_kind[1:3] == "log_variance"))
  expect_true(all(is.finite(point$gradient)))
  expect_true(all(is.finite(point$observed_information)))
  expect_true(is.finite(point$information_condition) || is.infinite(point$information_condition))
  if (isTRUE(point$information_positive_definite)) {
    expect_identical(dimnames(point$parameter_correlation), dimnames(point$observed_information))
    expect_equal(point$parameter_correlation, t(point$parameter_correlation), tolerance = 1e-12)
  }
})

test_that("retained curvature refuses foreign seeds and has a raw-q zero fallback", {
  oracle <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-dep-kernel-retained-curvature.R"), mustWork = FALSE)
  skip_if_not(file.exists(oracle) && file.exists(script))
  source(oracle, local = TRUE)
  source(script, local = TRUE)
  old_wd <- setwd(normalizePath(testthat::test_path("..", "..")))
  on.exit(setwd(old_wd), add = TRUE)
  .temporal_dep_kernel_retained_curvature_source()
  expect_error(.temporal_dep_kernel_retained_curvature_seed(2609224L), "exactly frozen")
  expect_error(temporal_dep_kernel_retained_curvature(2609221L), "exactly frozen seeds")
  expect_error(temporal_dep_kernel_retained_curvature(n_series = 3L, n_time = 4L),
    "requires n_series = 80L and n_time = 16L")
  fixed <- c(rep(0, 3L), 0, 0, rep(0, 6L), c(0, .2, -.3))
  names(fixed) <- c(rep("b_fix", 3L), "log_sigma_eps", "theta_temporal_time",
    rep("theta_temporal_rr", 6L), rep("theta_rr_phy", 3L))
  fit <- structure(list(opt = list(par = fixed), tmb_obj = list(env = list(parList = function(x) list()))),
    class = "mock")
  coordinates <- .temporal_dep_kernel_retained_curvature_coordinates(fit, fixed)
  expect_identical(coordinates$kind[["kernel_1"]], "raw_q_at_zero")
  expect_identical(coordinates$kind[["kernel_2"]], "log_variance")
  expect_equal(unname(.temporal_dep_kernel_retained_curvature_native(fixed, coordinates,
    coordinates$values)[coordinates$native_index[["kernel_1"]]]), 0)
})

test_that("retained full curvature is opt-in", {
  skip_if_not_installed("TMB")
  skip_if_not(identical(Sys.getenv("GLLVM_TMB_RUN_RETAINED_CURVATURE"), "true"),
    "set GLLVM_TMB_RUN_RETAINED_CURVATURE=true to run all three retained seeds")
  oracle <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-dep-kernel-retained-curvature.R"), mustWork = FALSE)
  pkgload::load_all(normalizePath(testthat::test_path("..", "..")), quiet = TRUE,
    export_all = FALSE)
  source(oracle, local = TRUE); source(script, local = TRUE)
  report <- temporal_dep_kernel_retained_curvature()
  expect_identical(report$seed, 2609221:2609223)
  expect_true(all(vapply(report$reports, function(x) {
    all(vapply(x[c("truth", "rehydrated")], function(y) all(is.finite(y$curvature)), logical(1)))
  }, logical(1))))
  expect_true(all(vapply(report$reports, function(x) !is.null(x$receipt), logical(1))))
})

test_that("curvature RDS wrapper requires exact dimensions and atomically validates receipt identity", {
  oracle <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-dep-kernel-retained-curvature.R"), mustWork = FALSE)
  skip_if_not(file.exists(oracle) && file.exists(script))
  source(oracle, local = TRUE); source(script, local = TRUE)
  expected <- data.frame(seed = 2609221L, phi = .6, terminal = "success")
  observed <- expected
  receipt_identity <- list(frozen_seed = 2609221L, rehydrated_seed = 2609221L,
    frozen_phi = .6, rehydrated_phi = .6, terminal = "success")
  report <- list(schema_version = "temporal-dep-kernel-retained-curvature-v1", seed = 2609221L,
    n_series = 80L, n_time = 16L, n_observation = 7680L,
    receipt_identity = receipt_identity,
    report = list(seed = 2609221L, receipt = list(expected = expected, observed = observed)))
  identity <- .temporal_dep_kernel_retained_curvature_output_identity(report)
  expect_identical(identity$frozen_seed, 2609221L)
  expect_identical(identity$rehydrated_seed, 2609221L)
  bad <- report; bad$n_observation <- 1L
  expect_error(.temporal_dep_kernel_retained_curvature_output_identity(bad), "exact retained")
  out <- tempfile("retained-curvature-rds-")
  dir.create(out)
  target <- file.path(out, "dep-kernel-retained-curvature-v1.rds")
  .temporal_dep_kernel_retained_curvature_write_rds(report, target)
  expect_true(file.exists(target))
  expect_identical(readRDS(target)$n_observation, 7680L)
  expect_error(.temporal_dep_kernel_retained_curvature_write_rds(report, target), "new path")
  invalid_target <- file.path(out, "invalid-dep-kernel-retained-curvature-v1.rds")
  expect_error(.temporal_dep_kernel_retained_curvature_write_rds(bad, invalid_target), "exact retained")
  expect_false(file.exists(invalid_target))
})
