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

test_that("S3b native-pair provenance helpers bind copied DLL bytes, not a temporary path", {
  runner_environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s3b-native-pairs-isolated.R"), local = runner_environment)

  source_path <- tempfile("s3b-source-dll-")
  copied_path <- tempfile("s3b-loaded-dll-")
  different_path <- tempfile("s3b-other-dll-")
  withr::defer(unlink(c(source_path, copied_path, different_path)))
  writeBin(charToRaw("authenticated shared object"), source_path)
  writeBin(readBin(source_path, what = "raw", n = file.info(source_path)$size), copied_path)
  writeBin(charToRaw("different shared object"), different_path)

  binding <- runner_environment$s3b_native_pairs_validate_loaded_dll(
    copied_path, source_path
  )
  expect_identical(binding$loaded_path, normalizePath(copied_path))
  expect_identical(binding$source_path, normalizePath(source_path))
  expect_error(
    runner_environment$s3b_native_pairs_validate_loaded_dll(different_path, source_path),
    "does not match the authenticated source binary"
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
  writeLines("first", file.path(temporary_repository, "first.txt"))
  writeLines("second", file.path(temporary_repository, "second.txt"))
  system2("git", c("-C", temporary_repository, "add", "first.txt", "second.txt"))
  system2("git", c(
    "-C", temporary_repository,
    "-c", "user.name=TestRunner", "-c", "user.email=test@example.invalid",
    "commit", "--quiet", "-m", "initial"
  ))

  expect_silent(
    runner_environment$s3b_native_pairs_require_clean_git(temporary_repository, "temporary source")
  )
  writeLines("changed first", file.path(temporary_repository, "first.txt"))
  writeLines("changed second", file.path(temporary_repository, "second.txt"))
  system2("git", c("-C", temporary_repository, "add", "first.txt", "second.txt"))
  system2("git", c(
    "-C", temporary_repository,
    "-c", "user.name=TestRunner", "-c", "user.email=test@example.invalid",
    "commit", "--quiet", "-m", "two-files"
  ))

  expect_identical(
    runner_environment$s3b_native_pairs_git_stdout(
      c("-C", temporary_repository, "diff", "--name-only", shQuote("HEAD~..HEAD")), "two-file diff"
    ),
    c("first.txt", "second.txt")
  )
})
