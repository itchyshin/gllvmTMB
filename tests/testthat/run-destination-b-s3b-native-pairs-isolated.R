#!/usr/bin/env Rscript

# Retain exactly the three native S3b bridge pairs (tree, sparse pedigree, and
# dense vcv). The generic `engine = "julia"` route remains deliberately closed.

s3b_native_pairs_frozen_reference_commit <- function() {
  "b4d5fee64def88bc768dda1f1f77c29b295edd86"
}

s3b_native_pairs_allowed_changed_paths <- function() {
  c(
    "NAMESPACE",
    "R/julia-bridge.R",
    "docs/dev-log/after-task/2026-09-09-destination-b-s3b-r-adapter.md",
    "docs/dev-log/after-task/2026-09-09-destination-b-s3b-receipt-hardening.md",
    "docs/dev-log/after-task/2026-09-09-destination-b-s4-interval-reader-repair.md",
    "docs/dev-log/after-task/2026-09-09-destination-b-s4-tree-public-wrapper.md",
    "docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt.json",
    "docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt-v2.json",
    "docs/dev-log/artifacts/2026-09-09-destination-b-s4-tree-public-workflow-receipt.json",
    "docs/dev-log/check-log.md",
    "man/gllvm_julia_phylo_rr.Rd",
    "tests/testthat/run-destination-b-s3b-native-pairs-isolated.R",
    "tests/testthat/test-destination-b-s3b-native-pairs-runner.R",
    "tests/testthat/test-julia-phylo-rr-bridge.R",
    "vignettes/articles/current-limits.Rmd"
  )
}

s3b_native_pairs_validate_changed_paths <- function(changed_paths) {
  unexpected_paths <- setdiff(changed_paths, s3b_native_pairs_allowed_changed_paths())
  if (length(unexpected_paths)) {
    stop("adapter source changed outside the approved bridge/test scope: ",
      paste(unexpected_paths, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

s3b_native_pairs_git_stdout <- function(args, label) {
  output <- system2("git", args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (!is.null(status) && as.integer(status) != 0L) {
    stop(sprintf("%s git command failed: %s", label, paste(output, collapse = "\n")), call. = FALSE)
  }
  trimws(output)
}

s3b_native_pairs_validate_loaded_path <- function(actual_path, expected_path, label) {
  actual_path <- normalizePath(actual_path, mustWork = TRUE)
  expected_path <- normalizePath(expected_path, mustWork = TRUE)
  if (!identical(actual_path, expected_path)) {
    stop(
      label, " does not match the expected source path: expected ", expected_path,
      "; loaded ", actual_path,
      call. = FALSE
    )
  }
  invisible(actual_path)
}

s3b_native_pairs_loaded_dll_path <- function(package = "gllvmTMB") {
  dll <- getLoadedDLLs()[[package]]
  if (is.null(dll) || !nzchar(dll[["path"]])) {
    stop("R has not loaded the expected ", package, " DLL", call. = FALSE)
  }
  normalizePath(dll[["path"]], mustWork = TRUE)
}

s3b_native_pairs_validate_loaded_dll <- function(loaded_path, source_path) {
  loaded_path <- normalizePath(loaded_path, mustWork = TRUE)
  source_path <- normalizePath(source_path, mustWork = TRUE)
  loaded_sha256 <- digest::digest(file = loaded_path, algo = "sha256")
  source_sha256 <- digest::digest(file = source_path, algo = "sha256")
  if (!identical(loaded_sha256, source_sha256)) {
    stop(
      "loaded gllvmTMB DLL does not match the authenticated source binary: ",
      "source ", source_path, "; loaded ", loaded_path,
      call. = FALSE
    )
  }
  list(
    loaded_path = loaded_path,
    source_path = source_path,
    sha256 = loaded_sha256
  )
}

s3b_native_pairs_receipt_path <- function(path, artifact_directory) {
  artifact_directory <- normalizePath(artifact_directory, mustWork = TRUE)
  supplied_directory <- normalizePath(dirname(path), mustWork = TRUE)
  if (!identical(supplied_directory, artifact_directory)) {
    stop("S3b receipt path must be under the controlled artifact directory: ",
      artifact_directory, call. = FALSE)
  }
  file.path(artifact_directory, basename(path))
}

s3b_native_pairs_require_clean_git <- function(path, label) {
  status <- s3b_native_pairs_git_stdout(
    c("-C", shQuote(normalizePath(path, mustWork = TRUE)), "status", "--porcelain"),
    paste0(label, " status")
  )
  if (length(status) && any(nzchar(status))) {
    stop(
      label, " must be clean before retaining paired evidence: ",
      paste(status[nzchar(status)], collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

s3b_native_pairs_git_snapshot <- function(path, label) {
  path <- normalizePath(path, mustWork = TRUE)
  s3b_native_pairs_require_clean_git(path, label)
  list(
    root = path,
    commit = s3b_native_pairs_git_stdout(
      c("-C", shQuote(path), "rev-parse", "HEAD"),
      paste0(label, " revision")
    )
  )
}

s3b_native_pairs_validate_stable_snapshot <- function(before, after, label) {
  if (!identical(before, after)) {
    stop(label, " changed while S3b evidence was being retained", call. = FALSE)
  }
  invisible(TRUE)
}

s3b_native_pairs_write_receipt_once <- function(result, receipt_path) {
  receipt_directory <- dirname(receipt_path)
  if (!dir.exists(receipt_directory)) {
    stop("S3b receipt directory does not exist: ", receipt_directory, call. = FALSE)
  }
  if (file.exists(receipt_path)) {
    stop("refusing to overwrite existing S3b receipt: ", receipt_path, call. = FALSE)
  }
  temporary_path <- tempfile(
    pattern = paste0(".", basename(receipt_path), "."),
    tmpdir = receipt_directory
  )
  on.exit(unlink(temporary_path), add = TRUE)
  jsonlite::write_json(result, temporary_path, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  if (!file.link(temporary_path, receipt_path)) {
    stop("refusing to overwrite existing S3b receipt: ", receipt_path, call. = FALSE)
  }
  invisible(receipt_path)
}

s3b_native_pairs_main <- function() {
  required <- c(
    "GLLVM_S3B_LIVE_ADAPTER_TESTS", "GLLVM_DESTINATION_B_PROJECT",
    "GLLVM_S3B_JULIA_HOME", "GLLVM_S3B_RECEIPT_PATH"
  )
  missing <- required[!nzchar(Sys.getenv(required, unset = ""))]
  if (length(missing)) {
    stop("missing required environment variable(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!identical(Sys.getenv("GLLVM_S3B_LIVE_ADAPTER_TESTS"), "1")) {
    stop("GLLVM_S3B_LIVE_ADAPTER_TESTS must equal 1", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required to retain the S3b receipt", call. = FALSE)
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required to bind the S3b source build", call. = FALSE)
  }

  project <- normalizePath(Sys.getenv("GLLVM_DESTINATION_B_PROJECT"), mustWork = TRUE)
  if (!file.exists(file.path(project, "Project.toml"))) {
    stop("GLLVM_DESTINATION_B_PROJECT is not a Julia project", call. = FALSE)
  }
  receipt_path <- s3b_native_pairs_receipt_path(
    Sys.getenv("GLLVM_S3B_RECEIPT_PATH"),
    file.path(getwd(), "docs", "dev-log", "artifacts")
  )
  frozen_reference_commit <- s3b_native_pairs_frozen_reference_commit()
  adapter_snapshot_before <- s3b_native_pairs_git_snapshot(getwd(), "gllvmTMB source")
  julia_snapshot_before <- s3b_native_pairs_git_snapshot(project, "GLLVM.jl source")
  invisible(s3b_native_pairs_git_stdout(
    c("merge-base", "--is-ancestor", frozen_reference_commit, "HEAD"),
    "frozen reference ancestry"
  ))
  changed_paths <- s3b_native_pairs_git_stdout(
    c("diff", "--name-only", paste0(frozen_reference_commit, "..HEAD")),
    "frozen reference scope"
  )
  s3b_native_pairs_validate_changed_paths(changed_paths)
  path <- "tests/testthat/test-julia-phylo-rr-bridge.R"
  expressions <- parse(file = path)
  printed <- vapply(expressions, function(expr) paste(deparse(expr), collapse = "\n"), character(1))
  selected <- unlist(lapply(c(
    "private S3b adapter pairs with one genuine frozen native tree fit",
    "private S3b adapter pairs with a native sparse-pedigree fit",
    "private S3b adapter transports a native R-ridged-once dense vcv"
  ), grep, x = printed, fixed = TRUE), use.names = FALSE)
  if (!identical(length(selected), 3L)) {
    stop("expected exactly the three retained native S3b pair tests", call. = FALSE)
  }

  pkgload::load_all(".", quiet = TRUE, compile = FALSE)
  expected_dll_path <- normalizePath(file.path(getwd(), "src", "gllvmTMB.so"), mustWork = TRUE)
  loaded_dll_path <- s3b_native_pairs_loaded_dll_path()
  dll_binding <- s3b_native_pairs_validate_loaded_dll(loaded_dll_path, expected_dll_path)
  reporter <- testthat::ListReporter$new()
  testthat::with_reporter(reporter, {
    reporter$start_file("destination-b-s3b-native-pairs-isolated")
    for (index in selected) testthat:::test_code(expressions[[index]], globalenv())
    reporter$end_context_if_started()
    reporter$end_file()
  })
  tab <- as.data.frame(reporter$get_results())
  failed <- sum(tab$failed)
  skipped <- sum(tab$skipped)
  errors <- sum(tab$error)
  warnings <- sum(tab$warning)
  passed <- sum(tab$passed)
  if (nrow(tab) != 3L || failed + skipped + errors + warnings != 0L) quit(status = 1L)

  receipts <- lapply(c("tree", "pedigree", "dense"), function(kind) {
    get0(paste0(".s3b_", kind, "_pair_receipt"), envir = globalenv(), inherits = FALSE)
  })
  names(receipts) <- c("tree", "sparse_pedigree", "dense_vcv")
  if (any(vapply(receipts, is.null, logical(1)))) {
    stop("a native S3b pair did not emit its receipt", call. = FALSE)
  }

  namespace_path <- normalizePath(getNamespaceInfo(asNamespace("gllvmTMB"), "path"))
  if (!identical(namespace_path, normalizePath(getwd()))) {
    stop("loaded gllvmTMB namespace is not this source checkout", call. = FALSE)
  }
  julia_active_project <- normalizePath(
    as.character(JuliaCall::julia_eval("string(Base.active_project())")),
    mustWork = TRUE
  )
  julia_package_root <- normalizePath(
    as.character(JuliaCall::julia_eval("string(Base.pkgdir(GLLVM))")),
    mustWork = TRUE
  )
  s3b_native_pairs_validate_loaded_path(
    julia_active_project, file.path(project, "Project.toml"), "active Julia project"
  )
  s3b_native_pairs_validate_loaded_path(
    julia_package_root, project, "loaded GLLVM.jl package"
  )
  adapter_snapshot_after <- s3b_native_pairs_git_snapshot(getwd(), "gllvmTMB source")
  julia_snapshot_after <- s3b_native_pairs_git_snapshot(project, "GLLVM.jl source")
  s3b_native_pairs_validate_stable_snapshot(
    adapter_snapshot_before, adapter_snapshot_after, "gllvmTMB source"
  )
  s3b_native_pairs_validate_stable_snapshot(
    julia_snapshot_before, julia_snapshot_after, "GLLVM.jl source"
  )
  runner_path <- normalizePath(
    "tests/testthat/run-destination-b-s3b-native-pairs-isolated.R", mustWork = TRUE
  )
  result <- list(
    kind = "destination_b_s3b_native_pairs",
    status = "passed_closed_adapter_only",
    scope = "three controlled Gaussian native phylo_rr pairs; generic engine remains closed",
    runner = "tests/testthat/run-destination-b-s3b-native-pairs-isolated.R",
    source = list(
      frozen_reference_commit = frozen_reference_commit,
      frozen_reference_is_ancestor = TRUE,
      adapter_commit = adapter_snapshot_before$commit,
      adapter_source_clean_and_stable = TRUE,
      changed_paths_from_frozen = changed_paths,
      r_version = R.version$version.string,
      r_platform = R.version$platform,
      r_shared_object_source_path = dll_binding$source_path,
      r_shared_object_loaded_path = dll_binding$loaded_path,
      r_shared_object_sha256 = dll_binding$sha256,
      gllvm_julia_project_path = project,
      gllvm_julia_active_project_path = julia_active_project,
      gllvm_julia_package_root = julia_package_root,
      gllvm_julia_commit = julia_snapshot_before$commit,
      gllvm_julia_source_clean_and_stable = TRUE,
      runner_sha256 = digest::digest(file = runner_path, algo = "sha256")
    ),
    tally = list(failed = failed, skipped = skipped, error = errors, warning = warnings, passed = passed),
    pairs = receipts,
    exclusions = c(
      "generic engine admission remains closed",
      "stored intervals are not yet exposed by the private adapter",
      "no recovery or coverage claim"
    )
  )
  s3b_native_pairs_write_receipt_once(result, receipt_path)
  cat(sprintf("S3B_NATIVE_PAIRS_TALLY failed=%d skipped=%d error=%d warning=%d passed=%d\n", failed, skipped, errors, warnings, passed))
  cat("S3B_NATIVE_PAIRS_RECEIPT ", receipt_path, "\n", sep = "")
}

if (!identical(Sys.getenv("GLLVM_S3B_NATIVE_PAIRS_DEFINE_ONLY"), "1")) {
  s3b_native_pairs_main()
}
