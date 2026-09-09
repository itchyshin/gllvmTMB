test_that("S3b native-pair runner binds the complete frozen-to-HEAD path contract", {
  runner_environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s3b-native-pairs-isolated.R"), local = runner_environment)

  expected_paths <- c(
    "NAMESPACE",
    "R/julia-bridge.R",
    "docs/dev-log/after-task/2026-09-09-destination-b-s3b-r-adapter.md",
    "docs/dev-log/after-task/2026-09-09-destination-b-s3b-receipt-hardening.md",
    "docs/dev-log/after-task/2026-09-09-destination-b-s4-interval-reader-repair.md",
    "docs/dev-log/after-task/2026-09-09-destination-b-s4-tree-public-wrapper.md",
    "docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt.json",
    "docs/dev-log/artifacts/2026-09-09-destination-b-s4-tree-public-workflow-receipt.json",
    "docs/dev-log/check-log.md",
    "man/gllvm_julia_phylo_rr.Rd",
    "tests/testthat/run-destination-b-s3b-native-pairs-isolated.R",
    "tests/testthat/test-destination-b-s3b-native-pairs-runner.R",
    "tests/testthat/test-julia-phylo-rr-bridge.R",
    "vignettes/articles/current-limits.Rmd"
  )

  expect_identical(runner_environment$s3b_native_pairs_allowed_changed_paths(), expected_paths)
  expect_silent(runner_environment$s3b_native_pairs_validate_changed_paths(expected_paths))
  expect_error(
    runner_environment$s3b_native_pairs_validate_changed_paths(c(expected_paths, "R/unapproved.R")),
    "outside the approved bridge/test scope"
  )
})

test_that("S3b native-pair receipt output is write-once", {
  runner_environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s3b-native-pairs-isolated.R"), local = runner_environment)

  receipt_path <- tempfile(fileext = ".json")
  withr::defer(unlink(receipt_path))
  first_payload <- list(version = 1L, status = "first")
  second_payload <- list(version = 2L, status = "second")

  expect_identical(
    runner_environment$s3b_native_pairs_write_receipt_once(first_payload, receipt_path),
    receipt_path
  )
  first_bytes <- readBin(receipt_path, what = "raw", n = file.info(receipt_path)$size)
  expect_error(
    runner_environment$s3b_native_pairs_write_receipt_once(second_payload, receipt_path),
    "refusing to overwrite existing S3b receipt"
  )
  expect_identical(
    readBin(receipt_path, what = "raw", n = file.info(receipt_path)$size),
    first_bytes
  )
})

test_that("S3b native-pair provenance helpers reject a mismatched loaded DLL", {
  runner_environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s3b-native-pairs-isolated.R"), local = runner_environment)

  expected_path <- normalizePath(testthat::test_path(".."), mustWork = TRUE)
  actual_path <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)

  expect_error(
    runner_environment$s3b_native_pairs_validate_loaded_path(
      actual_path, expected_path, "loaded gllvmTMB DLL"
    ),
    "does not match the expected source path"
  )
  expect_silent(
    runner_environment$s3b_native_pairs_validate_loaded_path(
      expected_path, expected_path, "loaded gllvmTMB DLL"
    )
  )
})

test_that("S3b native-pair receipt paths stay in the controlled artifact directory", {
  runner_environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s3b-native-pairs-isolated.R"), local = runner_environment)

  artifact_directory <- normalizePath(testthat::test_path("..", "..", "docs", "dev-log", "artifacts"), mustWork = TRUE)
  controlled_path <- file.path(artifact_directory, "controlled-s3b-receipt.json")

  expect_identical(
    runner_environment$s3b_native_pairs_receipt_path(controlled_path, artifact_directory),
    controlled_path
  )
  expect_error(
    runner_environment$s3b_native_pairs_receipt_path(tempfile(fileext = ".json"), artifact_directory),
    "must be under the controlled artifact directory"
  )
})

test_that("S3b native-pair source snapshots reject a changed source", {
  runner_environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s3b-native-pairs-isolated.R"), local = runner_environment)

  before <- list(root = "/source", commit = "first")
  after <- list(root = "/source", commit = "second")

  expect_error(
    runner_environment$s3b_native_pairs_validate_stable_snapshot(before, after, "GLLVM.jl source"),
    "changed while S3b evidence was being retained"
  )
  expect_silent(
    runner_environment$s3b_native_pairs_validate_stable_snapshot(before, before, "GLLVM.jl source")
  )
})

test_that("S3b native-pair source snapshots reject untracked files", {
  runner_environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s3b-native-pairs-isolated.R"), local = runner_environment)

  temporary_repository <- tempfile("s3b-dirty-source-")
  dir.create(temporary_repository)
  withr::defer(unlink(temporary_repository, recursive = TRUE))
  system2("git", c("init", "--quiet", temporary_repository))
  writeLines("untracked", file.path(temporary_repository, "evidence-drift.txt"))

  expect_error(
    runner_environment$s3b_native_pairs_require_clean_git(temporary_repository, "temporary source"),
    "temporary source must be clean"
  )
})

test_that("S3b native-pair source snapshots accept a clean repository", {
  runner_environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s3b-native-pairs-isolated.R"), local = runner_environment)

  temporary_repository <- tempfile("s3b-clean-source-")
  dir.create(temporary_repository)
  withr::defer(unlink(temporary_repository, recursive = TRUE))
  system2("git", c("init", "--quiet", temporary_repository))
  writeLines("tracked", file.path(temporary_repository, "tracked.txt"))
  system2("git", c("-C", temporary_repository, "add", "tracked.txt"))
  system2("git", c(
    "-C", temporary_repository,
    "-c", "user.name=TestRunner", "-c", "user.email=test@example.invalid",
    "commit", "--quiet", "-m", "initial"
  ))

  expect_silent(
    runner_environment$s3b_native_pairs_require_clean_git(temporary_repository, "temporary source")
  )
})
