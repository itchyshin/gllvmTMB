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
    "GLLVM_S3B_JULIA_HOME"
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
  receipt_path <- "docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt.json"
  frozen_reference_commit <- s3b_native_pairs_frozen_reference_commit()
  invisible(s3b_native_pairs_git_stdout(
    c("merge-base", "--is-ancestor", frozen_reference_commit, "HEAD"),
    "frozen reference ancestry"
  ))
  changed_paths <- s3b_native_pairs_git_stdout(
    c("diff", "--name-only", paste0(frozen_reference_commit, "..HEAD")),
    "frozen reference scope"
  )
  s3b_native_pairs_validate_changed_paths(changed_paths)
  tracked_status <- system2("git", c("status", "--porcelain", "--untracked-files=no"),
    stdout = TRUE, stderr = TRUE)
  tracked_status_code <- attr(tracked_status, "status")
  if (!is.null(tracked_status_code) && as.integer(tracked_status_code) != 0L) {
    stop("adapter source status git command failed", call. = FALSE)
  }
  tracked_paths <- if (length(tracked_status)) substr(tracked_status, 4L, nchar(tracked_status)) else character()
  nonreceipt_changes <- setdiff(tracked_paths, receipt_path)
  if (length(nonreceipt_changes)) {
    stop("adapter source must be tracked-clean outside its stale receipt before retaining evidence", call. = FALSE)
  }

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
  dll_path <- normalizePath(file.path(getwd(), "src", "gllvmTMB.so"), mustWork = TRUE)
  result <- list(
    kind = "destination_b_s3b_native_pairs",
    status = "passed_closed_adapter_only",
    scope = "three controlled Gaussian native phylo_rr pairs; generic engine remains closed",
    runner = "tests/testthat/run-destination-b-s3b-native-pairs-isolated.R",
    source = list(
      frozen_reference_commit = frozen_reference_commit,
      frozen_reference_is_ancestor = TRUE,
      adapter_commit = s3b_native_pairs_git_stdout(c("rev-parse", "HEAD"), "gllvmTMB revision"),
      adapter_tracked_clean_outside_receipt = TRUE,
      changed_paths_from_frozen = changed_paths,
      r_version = R.version$version.string,
      r_platform = R.version$platform,
      r_shared_object_sha256 = digest::digest(file = dll_path, algo = "sha256"),
      gllvm_julia_project_binding = "GLLVM_DESTINATION_B_PROJECT",
      gllvm_julia_commit = s3b_native_pairs_git_stdout(c("-C", shQuote(project), "rev-parse", "HEAD"), "GLLVM.jl revision")
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
