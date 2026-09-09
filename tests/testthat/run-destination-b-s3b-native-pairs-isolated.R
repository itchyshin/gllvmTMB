#!/usr/bin/env Rscript

# Retain exactly the three native S3b bridge pairs (tree, sparse pedigree, and
# dense vcv).  The generic `engine = "julia"` route remains deliberately
# untouched; these are direct calls to the closed phylo_rr adapter.

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
pkgload::load_all(".", quiet = TRUE, compile = FALSE)

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

git_stdout <- function(args, label) {
  output <- system2("git", args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (!is.null(status) && as.integer(status) != 0L) {
    stop(sprintf("%s git command failed: %s", label, paste(output, collapse = "\n")), call. = FALSE)
  }
  trimws(output)
}
frozen_reference_commit <- "b4d5fee64def88bc768dda1f1f77c29b295edd86"
allowed_changed_paths <- c(
  "R/julia-bridge.R",
  "tests/testthat/test-julia-phylo-rr-bridge.R",
  "tests/testthat/run-destination-b-s3b-native-pairs-isolated.R",
  "docs/dev-log/check-log.md",
  "docs/dev-log/after-task/2026-09-09-destination-b-s3b-r-adapter.md",
  "docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt.json"
)
git_stdout(c("merge-base", "--is-ancestor", frozen_reference_commit, "HEAD"),
  "frozen reference ancestry")
changed_paths <- git_stdout(c("diff", "--name-only", paste0(frozen_reference_commit, "..HEAD")),
  "frozen reference scope")
unexpected_paths <- setdiff(changed_paths, allowed_changed_paths)
if (length(unexpected_paths)) {
  stop("adapter source changed outside the approved bridge/test scope: ",
    paste(unexpected_paths, collapse = ", "), call. = FALSE)
}
tracked_status <- git_stdout(c("status", "--porcelain", "--untracked-files=no"),
  "adapter source status")
if (length(tracked_status)) {
  stop("adapter source must be tracked-clean before retaining a receipt", call. = FALSE)
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
    adapter_commit = git_stdout(c("rev-parse", "HEAD"), "gllvmTMB revision"),
    adapter_tracked_clean = TRUE,
    changed_paths_from_frozen = changed_paths,
    r_version = R.version$version.string,
    r_platform = R.version$platform,
    r_shared_object_sha256 = digest::digest(file = dll_path, algo = "sha256"),
    gllvm_julia_project_binding = "GLLVM_DESTINATION_B_PROJECT",
    gllvm_julia_commit = git_stdout(c("-C", shQuote(project), "rev-parse", "HEAD"), "GLLVM.jl revision")
  ),
  tally = list(failed = failed, skipped = skipped, error = errors, warning = warnings, passed = passed),
  pairs = receipts,
  exclusions = c(
    "generic engine admission remains closed",
    "stored intervals are not yet exposed by the private adapter",
    "no recovery or coverage claim"
  )
)
receipt_path <- "docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt.json"
jsonlite::write_json(result, receipt_path, auto_unbox = TRUE, pretty = TRUE, digits = NA)
cat(sprintf("S3B_NATIVE_PAIRS_TALLY failed=%d skipped=%d error=%d warning=%d passed=%d\n", failed, skipped, errors, warnings, passed))
cat("S3B_NATIVE_PAIRS_RECEIPT ", receipt_path, "\n", sep = "")
