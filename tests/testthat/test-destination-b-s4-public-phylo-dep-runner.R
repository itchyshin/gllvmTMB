test_that("S4 public phylo_dep receipt runner is present", {
  expect_true(file.exists(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R")))
})

test_that("S4 runner selects its own immutable build seal", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)
  repository <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  expect_true(is.function(environment$s4_public_phylo_dep_s4_seal_path))
  expect_true(is.function(environment$s4_public_phylo_dep_read_s4_seal))
  expect_true(is.function(environment$s4_public_phylo_dep_s4_seal_sha256))
  expect_true(is.function(environment$s4_public_phylo_dep_validate_s4_runtime_root))
  expect_match(
    environment$s4_public_phylo_dep_s4_seal_path(repository),
    "destination-b-s4-phylo-dep-build-seal.json$"
  )
  seal <- environment$s4_public_phylo_dep_read_s4_seal(repository)
  expect_identical(environment$s4_public_phylo_dep_s4_seal_sha256(),
                   "a16bf7ecae725c8e3fb7282c7ae6b63b7f648cf052da8f46556a1ff7b1d61d9e")
  expect_identical(seal$binary_identity$source_dll$sha256,
                   "eba1d3c5d5c26303f0e730a87ee70a627eb508c35f9419610fad08e37ccbb2f8")
  payload <- jsonlite::read_json(environment$s4_public_phylo_dep_s4_seal_path(repository), simplifyVector = FALSE)
  payload$source_snapshot$selected_source[[1L]]$sha256 <- paste(rep("0", 64), collapse = "")
  expect_error(environment$s4_public_phylo_dep_validate_s4_seal_payload(payload), "selected-source hash mismatch")
  payload <- jsonlite::read_json(environment$s4_public_phylo_dep_s4_seal_path(repository), simplifyVector = FALSE)
  payload$source_snapshot$commit <- paste(rep("0", 40), collapse = "")
  expect_error(environment$s4_public_phylo_dep_validate_s4_seal_payload(payload), "source commit mismatch")
  alternate <- tempfile(fileext = ".json")
  withr::defer(unlink(alternate))
  file.copy(environment$s4_public_phylo_dep_s4_seal_path(repository), alternate)
  expect_error(environment$s4_public_phylo_dep_read_s4_seal(repository, alternate), "canonical path")
})

s4_runtime_git <- function(root, args) {
  output <- system2("git", c("-C", root, args), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(output, "status"))) stop(paste(output, collapse = "\n"))
  trimws(output)
}

s4_runtime_root <- function() {
  root <- tempfile("s4-runtime-root-")
  dir.create(root)
  s4_runtime_git(root, c("init", "-q"))
  s4_runtime_git(root, c("config", "user.email", "s4@example.test"))
  s4_runtime_git(root, c("config", "user.name", "S4 test"))
  dir.create(file.path(root, "R"))
  writeLines("adapter <- function() 1", file.path(root, "R", "adapter.R"))
  s4_runtime_git(root, c("add", "R/adapter.R"))
  s4_runtime_git(root, c("commit", "-q", "-m", shQuote("archive root")))
  list(root = root, commit = s4_runtime_git(root, c("rev-parse", "HEAD")),
       branch = s4_runtime_git(root, c("symbolic-ref", "--short", "HEAD")))
}

test_that("S4 runtime root permits only clean descendant runner and docs changes", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)
  runtime <- s4_runtime_root()
  withr::defer(unlink(runtime$root, recursive = TRUE))
  dir.create(file.path(runtime$root, "docs"))
  writeLines("later runner documentation", file.path(runtime$root, "docs", "runner.md"))
  s4_runtime_git(runtime$root, c("add", "docs/runner.md"))
  s4_runtime_git(runtime$root, c("commit", "-q", "-m", shQuote("later runner docs")))
  seal <- list(source_snapshot = list(commit = runtime$commit))
  accepted <- environment$s4_public_phylo_dep_validate_s4_runtime_root(runtime$root, seal, runtime$commit)
  expect_identical(accepted$archive_root_commit, runtime$commit)
  expect_false(identical(accepted$runtime_commit, runtime$commit))
})

test_that("S4 runtime root rejects dirty, non-descendant, and package-source drift", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)
  runtime <- s4_runtime_root()
  withr::defer(unlink(runtime$root, recursive = TRUE))
  seal <- list(source_snapshot = list(commit = runtime$commit))
  writeLines("uncommitted", file.path(runtime$root, "dirty.txt"))
  expect_error(environment$s4_public_phylo_dep_validate_s4_runtime_root(runtime$root, seal, runtime$commit), "must be clean")
  unlink(file.path(runtime$root, "dirty.txt"))
  writeLines("adapter <- function() 2", file.path(runtime$root, "R", "adapter.R"))
  s4_runtime_git(runtime$root, c("add", "R/adapter.R"))
  s4_runtime_git(runtime$root, c("commit", "-q", "-m", shQuote("package drift")))
  expect_error(environment$s4_public_phylo_dep_validate_s4_runtime_root(runtime$root, seal, runtime$commit), "package source drift")
  s4_runtime_git(runtime$root, c("checkout", "-q", runtime$commit))
  s4_runtime_git(runtime$root, c("checkout", "-qb", "other"))
  writeLines("other branch", file.path(runtime$root, "other.txt"))
  s4_runtime_git(runtime$root, c("add", "other.txt"))
  s4_runtime_git(runtime$root, c("commit", "-q", "-m", shQuote("other branch")))
  other <- s4_runtime_git(runtime$root, c("rev-parse", "HEAD"))
  s4_runtime_git(runtime$root, c("checkout", "-q", runtime$branch))
  writeLines("master branch", file.path(runtime$root, "master.txt"))
  s4_runtime_git(runtime$root, c("add", "master.txt"))
  s4_runtime_git(runtime$root, c("commit", "-q", "-m", shQuote("master branch")))
  expect_error(environment$s4_public_phylo_dep_validate_s4_runtime_root(runtime$root, list(source_snapshot = list(commit = other)), other), "not a descendant")
})

test_that("S4 public phylo_dep receipt runner uses ASCII Julia string literals", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  withr::local_options(useFancyQuotes = TRUE)
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)
  literal <- environment$s4_public_phylo_dep_julia_literal(tempdir())
  expect_identical(literal, paste0('"', normalizePath(tempdir()), '"'))
  expect_false(grepl("[\u201c\u201d]", literal))
  code <- paste0("import Pkg; Pkg.activate(", literal, "); println(\"ok\")")
  args <- environment$s4_public_phylo_dep_julia_args(code)
  expect_identical(args[1:3], c("--startup-file=no", "--project", "-e"))
  expect_identical(args[[4L]], shQuote(code))
})

test_that("S4 runner retains a write-once failed-attempt diagnostic before refusal", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)

  receipt_path <- tempfile("s4-passed-receipt-", fileext = ".json")
  reservation <- environment$s4_public_phylo_dep_reserve_failed_diagnostic_path(receipt_path)
  failed_path <- reservation$path
  withr::defer(unlink(c(receipt_path, reservation$namespace), recursive = TRUE))
  tab <- data.frame(
    context = c("S4 public phylo_dep", "S4 public phylo_dep"),
    test = c("generic engine remains closed", "paired endpoints"),
    failed = c(0L, 1L), skipped = c(0L, 0L), error = c(0L, 0L), warning = c(0L, 0L),
    stringsAsFactors = FALSE
  )
  raw_output <- c("testthat raw line 1", "testthat raw line 2")
  provenance <- list(
    sealed_build = list(path = "/sealed.json", sha256 = "seal-sha"),
    r_runtime = list(root = "/r", commit = "r-commit"),
    gllvm_runtime = list(root = "/gllvm", commit = "g-commit"),
    julia_probe = list(executable = "/julia", executable_sha256 = "julia-sha"),
    selected_test_expressions = c(generic = "test_that('generic', {})", live = "test_that('live', {})")
  )

  expect_error(
    environment$s4_public_phylo_dep_retain_failed_attempt(
      tab = tab, raw_output = raw_output, reporter_details = list(list(message = "synthetic expectation failure")),
      provenance = provenance, receipt_path = receipt_path, failed_path = failed_path
    ),
    "did not pass cleanly"
  )
  expect_false(file.exists(receipt_path))
  expect_true(file.exists(failed_path))
  diagnostic <- jsonlite::read_json(failed_path, simplifyVector = FALSE)
  expect_identical(diagnostic$status, "failed_test_attempt_not_a_receipt")
  expect_identical(diagnostic$raw_output, as.list(raw_output))
  expect_identical(diagnostic$raw_output_sha256, digest::digest(paste(raw_output, collapse = "\n"), algo = "sha256"))
  expect_identical(diagnostic$test_tab$test, as.list(tab$test))
  expect_identical(diagnostic$test_tab$failed, as.list(as.integer(tab$failed)))
  expect_identical(diagnostic$test_counts$failed, 1L)
  expect_identical(diagnostic$source$sealed_build$sha256, "seal-sha")
  expect_identical(diagnostic$source$r_runtime$commit, "r-commit")
  expect_identical(diagnostic$source$gllvm_runtime$commit, "g-commit")
  expect_identical(diagnostic$source$julia_probe$executable_sha256, "julia-sha")
  expect_identical(diagnostic$source$selected_test_expressions, as.list(provenance$selected_test_expressions))
  expect_identical(diagnostic$reporter_details[[1L]]$message, "synthetic expectation failure")
  expect_match(diagnostic$raw_output_information_gap, "omit expectation condition details")
  first_bytes <- readBin(failed_path, what = "raw", n = file.info(failed_path)$size)
  expect_error(
    environment$s4_public_phylo_dep_retain_failed_attempt(
      tab = tab, raw_output = raw_output, reporter_details = list(), provenance = provenance,
      receipt_path = receipt_path, failed_path = failed_path
    ),
    "refusing to overwrite existing S4 failed-attempt diagnostic"
  )
  expect_identical(readBin(failed_path, what = "raw", n = file.info(failed_path)$size), first_bytes)
})

test_that("S4 failed-attempt diagnostic normalizes captured conditions before writing", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)

  receipt_path <- tempfile("s4-condition-receipt-", fileext = ".json")
  reservation <- environment$s4_public_phylo_dep_reserve_failed_diagnostic_path(receipt_path)
  failed_path <- reservation$path
  withr::defer(unlink(c(receipt_path, reservation$namespace), recursive = TRUE))
  tab <- data.frame(
    context = c("S4 public phylo_dep", "S4 public phylo_dep"),
    test = c("generic engine remains closed", "paired endpoints"),
    failed = c(0L, 1L), skipped = c(0L, 0L), error = c(0L, 0L), warning = c(0L, 0L),
    stringsAsFactors = FALSE
  )
  captured <- structure(
    list(message = "synthetic captured condition", call = quote(synthetic_s4_failure())),
    class = c("synthetic_s4_condition", "error", "condition")
  )
  raw_output <- "unchanged raw testthat output"
  provenance <- list(
    sealed_build = list(path = "/sealed.json", sha256 = "seal-sha"),
    r_runtime = list(root = "/r", commit = "r-commit"),
    gllvm_runtime = list(root = "/gllvm", commit = "g-commit"),
    julia_probe = list(executable = "/julia", executable_sha256 = "julia-sha"),
    selected_test_expressions = c(generic = "test_that('generic', {})", live = "test_that('live', {})")
  )

  expect_error(
    environment$s4_public_phylo_dep_retain_failed_attempt(
      tab = tab,
      raw_output = raw_output,
      reporter_details = list(list(expectations = list(captured))),
      provenance = provenance,
      receipt_path = receipt_path,
      failed_path = failed_path
    ),
    "did not pass cleanly"
  )
  diagnostic <- jsonlite::read_json(failed_path, simplifyVector = FALSE)
  detail <- diagnostic$reporter_details[[1L]]$expectations[[1L]]
  expect_identical(diagnostic$raw_output, as.list(raw_output))
  expect_identical(detail$message, "synthetic captured condition")
  expect_identical(detail$class, as.list(class(captured)))
  expect_identical(detail$call, "synthetic_s4_failure()")
  expect_length(detail$backtrace, 0L)
  expect_false(inherits(detail, "condition"))
  expect_false(file.exists(receipt_path))
  first_bytes <- readBin(failed_path, what = "raw", n = file.info(failed_path)$size)
  expect_error(
    environment$s4_public_phylo_dep_retain_failed_attempt(
      tab = tab,
      raw_output = raw_output,
      reporter_details = list(list(expectations = list(captured))),
      provenance = provenance,
      receipt_path = receipt_path,
      failed_path = failed_path
    ),
    "refusing to overwrite existing S4 failed-attempt diagnostic"
  )
  expect_identical(readBin(failed_path, what = "raw", n = file.info(failed_path)$size), first_bytes)
})

test_that("S4 runner pre-reserves a failure namespace without colliding with a receipt", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)

  receipt_path <- tempfile("s4-receipt-", fileext = ".json")
  legacy_sibling_receipt <- file.path(
    dirname(receipt_path),
    paste0(tools::file_path_sans_ext(basename(receipt_path)), "-FAILED.json")
  )
  jsonlite::write_json(list(status = "passed"), legacy_sibling_receipt, auto_unbox = TRUE)
  withr::defer(unlink(c(receipt_path, legacy_sibling_receipt), recursive = TRUE))

  reservation <- environment$s4_public_phylo_dep_reserve_failed_diagnostic_path(receipt_path)
  withr::defer(unlink(reservation$namespace, recursive = TRUE))
  expect_true(dir.exists(reservation$namespace))
  expect_false(file.exists(reservation$path))
  expect_false(identical(reservation$path, legacy_sibling_receipt))
  expect_error(
    environment$s4_public_phylo_dep_reserve_failed_diagnostic_path(receipt_path),
    "already reserved"
  )
})

test_that("S4 public phylo_dep receipt refuses malformed endpoints and duplicate output", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)
  targets <- environment$s4_public_phylo_dep_targets()
  payload <- list(target_names = targets, native_lower = seq_along(targets), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  expect_identical(environment$s4_public_phylo_dep_validate_endpoints(payload)$target_names, targets)
  payload$target_names[7] <- "wrong"
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(payload), "target/order mismatch")
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(list(target_names = targets)), "dangling endpoint output")
  ordered <- list(target_names = targets, native_lower = seq_along(targets), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  ordered$native_upper[1] <- ordered$native_lower[1]
  ordered$julia_upper[1] <- ordered$julia_lower[1]
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(ordered), "ordered endpoints")
  expect_true(is.function(environment$s4_public_phylo_dep_validate_embedded_julia_runtime))
  malformed <- list(target_names = targets, native_lower = seq_along(targets), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  malformed$target_names[2] <- malformed$target_names[1]
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(malformed), "target/order mismatch")
  malformed <- list(target_names = targets, native_lower = seq_along(targets)[-1], native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(malformed), "target/order mismatch")
  malformed <- list(target_names = targets, native_lower = c(NA_real_, 2:7), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(malformed), "target/order mismatch")
  malformed <- list(target_names = targets, native_lower = seq_along(targets), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets) + 1, julia_upper = seq_along(targets) + 2)
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(malformed), "tolerance exceeded")
  path <- tempfile(fileext = ".json")
  withr::defer(unlink(path))
  expect_identical(environment$s4_public_phylo_dep_write_once(list(ok = TRUE), path), path)
  expect_error(environment$s4_public_phylo_dep_write_once(list(ok = FALSE), path), "refusing to overwrite")
  cat("S4_PUBLIC_PHYLO_DEP_RUNNER_CONTRACT_PASS\n")
})
