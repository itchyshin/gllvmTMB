test_that("retained temporal-dep kernel block oracle equals a literal dense small fixture", {
  skip_if_not_installed("TMB")
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  pkgload::load_all(normalizePath(testthat::test_path("..", "..")), quiet = TRUE,
    export_all = FALSE)
  source(script, local = TRUE)

  fixture <- .temporal_dep_kernel_retained_fixture(2609221L, n_series = 3L, n_time = 4L)
  fit <- .temporal_dep_kernel_retained_fit(fixture)
  fixed <- fit$opt$par
  fixed[which(names(fixed) == "theta_temporal_time")] <- atanh(.45 / (1 - 1e-6))
  fixed[which(names(fixed) == "theta_temporal_rr")] <- c(.55, .45, .5, .08, -.12, .1)
  fixed[which(names(fixed) == "theta_rr_phy")] <- c(.3, .4, .5)
  fixed[which(names(fixed) == "log_sigma_eps")] <- log(.25)

  block <- .temporal_dep_kernel_retained_block_nll(fit, fixed, fixture)
  literal <- .temporal_dep_kernel_retained_literal_dense_nll(fit, fixed, fixture)
  expect_equal(block, literal, tolerance = 2e-7)
  expect_gt(abs(block - .temporal_dep_kernel_retained_literal_dense_nll(
    fit, fixed, fixture, product_control = TRUE
  )), 1e-3)
  expect_false(grepl("simulate\\s*\\(", paste(readLines(script, warn = FALSE), collapse = "\n")))
})

test_that("retained oracle labels every free native coordinate and preserves its no-intervention boundary", {
  skip_if_not_installed("TMB")
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  pkgload::load_all(normalizePath(testthat::test_path("..", "..")), quiet = TRUE,
    export_all = FALSE)
  source(script, local = TRUE)

  fixture <- .temporal_dep_kernel_retained_fixture(2609221L, n_series = 3L, n_time = 4L)
  fit <- .temporal_dep_kernel_retained_fit(fixture)
  labels <- .temporal_dep_kernel_retained_labels(fit$opt$par)
  gradient <- .temporal_dep_kernel_retained_central_gradient(fit, fit$opt$par, fixture)
  expect_identical(names(gradient), labels)
  expect_true(all(is.finite(gradient)))
  expect_true(all(c("b_fix[1]", "theta_temporal_time[1]", "theta_temporal_rr[1]",
    "theta_rr_phy[1]", "log_sigma_eps[1]") %in% labels))
  expect_match(paste(readLines(script, warn = FALSE), collapse = "\n"),
    "no optimiser intervention, recovery, or calibration claim", fixed = TRUE)
})

test_that("retained oracle CLI fails closed for missing versioned new output paths", {
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  source(script, local = TRUE)
  expect_error(.temporal_dep_kernel_retained_cli(character()), "usage")
  expect_error(.temporal_dep_kernel_retained_cli(c("--one=2609221",
    "--csv=/tmp/plain.csv", "--rds=/tmp/plain.rds")), "usage")
  csv <- tempfile("dep-kernel-retained-oracle-v1-", fileext = ".csv")
  rds <- tempfile("dep-kernel-retained-oracle-v1-", fileext = ".rds")
  file.create(csv); file.create(rds)
  expect_error(.temporal_dep_kernel_retained_cli(c("--one=2609221",
    paste0("--csv=", csv), paste0("--rds=", rds))), "must be new")
  expect_error(.temporal_dep_kernel_retained_cli(c("--one=2609224",
    "--csv=/tmp/dep-kernel-retained-oracle-v1.csv",
    "--rds=/tmp/dep-kernel-retained-oracle-v1.rds")), "frozen seed")
})

test_that("retained oracle refuses non-frozen public seeds and records non-comparable runtime", {
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  source(script, local = TRUE)
  expect_error(temporal_dep_kernel_retained_oracle(2609224L), "exactly frozen seeds")
  runtime <- .temporal_dep_kernel_retained_runtime(4.5, 7.25)
  expect_false(runtime$comparable)
  expect_equal(runtime$frozen_elapsed_seconds, 4.5)
  expect_equal(runtime$rehydrated_elapsed_seconds, 7.25)
  expect_error(.temporal_dep_kernel_retained_runtime(-1, 1), "finite and nonnegative")
  expect_error(.temporal_dep_kernel_retained_runtime(1, NA_real_), "finite and nonnegative")
})

test_that("retained oracle writes paired versioned output transactionally", {
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  source(script, local = TRUE)
  out <- tempfile("retained-oracle-pair-")
  dir.create(out)
  csv <- file.path(out, "dep-kernel-retained-oracle-v1.csv")
  rds <- file.path(out, "dep-kernel-retained-oracle-v1.rds")
  table <- data.frame(schema_version = "temporal-dep-kernel-retained-oracle-v1",
    value = 1, stringsAsFactors = FALSE)
  report <- list(schema_version = "temporal-dep-kernel-retained-oracle-v1")
  paths <- .temporal_dep_kernel_retained_write_pair(table, report, csv, rds)
  expect_identical(unname(paths), c(csv, rds))
  expect_true(file.exists(csv) && file.exists(rds))
  expect_identical(readRDS(rds)$schema_version, report$schema_version)
  expect_error(.temporal_dep_kernel_retained_write_pair(table, report, csv, rds),
    "new files")
  bad_csv <- file.path(out, "bad-dep-kernel-retained-oracle-v1.csv")
  bad_rds <- file.path(out, "bad-dep-kernel-retained-oracle-v1.rds")
  expect_error(.temporal_dep_kernel_retained_write_pair(table, list(), bad_csv, bad_rds),
    "versioned report")
  expect_false(file.exists(bad_csv) || file.exists(bad_rds))
})

test_that("opt-in retained seed rehydrates the frozen receipt and agrees with native derivatives", {
  skip_if_not_installed("TMB")
  skip_if_not(identical(Sys.getenv("GLLVM_TMB_RUN_RETAINED_ORACLE"), "true"),
    "set GLLVM_TMB_RUN_RETAINED_ORACLE=true to run the 80-series retained fixture")
  script <- normalizePath(testthat::test_path("..", "..", "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R"), mustWork = FALSE)
  skip_if_not(file.exists(script))
  pkgload::load_all(normalizePath(testthat::test_path("..", "..")), quiet = TRUE,
    export_all = FALSE)
  source(script, local = TRUE)

  report <- temporal_dep_kernel_retained_oracle(2609221L)
  expect_identical(report$schema_version, "temporal-dep-kernel-retained-oracle-v1")
  expect_false(is.null(report$receipt))
  expect_identical(names(report$records), c("fitted", "kernel_1_plus_0.075",
    "kernel_2_plus_0.075"))
  expect_true(all(vapply(report$records, function(x) x$nll_error < 1e-6, logical(1))))
  expect_true(all(vapply(report$records, function(x) max(x$gradient_error) < 5e-5,
    logical(1))))
})
