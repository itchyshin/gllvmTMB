args <- commandArgs(trailingOnly = TRUE)
allowed <- c("parser", "oracle", "methods", "recovery", "regression", "self-test")
if (length(args) != 1L || !args %in% allowed) {
  stop("Usage: Rscript --vanilla dev/temporal-sixth-source/verify.R {parser|oracle|methods|recovery|regression|self-test}", call. = FALSE)
}

.temporal_sixth_require_fixture <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Missing required temporal-sixth-source verifier input: %s", path), call. = FALSE)
  }
  invisible(path)
}

.temporal_sixth_assert_test_results <- function(result, fixture) {
  summary <- as.data.frame(result)
  required <- c("failed", "error", "warning", "skipped")
  if (!all(required %in% names(summary)) || nrow(summary) == 0L) {
    stop(sprintf("Temporal sixth-source verifier ran zero assertions for: %s", fixture), call. = FALSE)
  }
  if (any(summary$failed > 0L | summary$error > 0L |
          summary$warning > 0L | summary$skipped)) {
    stop(sprintf("Temporal sixth-source verifier contains skipped, failed, errored, or warning results: %s", fixture), call. = FALSE)
  }
  invisible(summary)
}

.temporal_sixth_expect_reject <- function(expr, label) {
  rejected <- inherits(try(force(expr), silent = TRUE), "try-error")
  if (!rejected) stop(sprintf("Verifier self-test did not reject %s.", label), call. = FALSE)
  invisible(TRUE)
}

if (identical(args, "self-test")) {
  .temporal_sixth_expect_reject(
    .temporal_sixth_require_fixture(file.path(tempdir(), "missing-temporal-fixture.R")),
    "a missing fixture"
  )
  base <- data.frame(failed = 0L, error = 0L, warning = 0L, skipped = FALSE)
  .temporal_sixth_expect_reject(
    .temporal_sixth_assert_test_results(base[FALSE, , drop = FALSE], "self-test"),
    "zero assertions"
  )
  for (field in c("failed", "error", "warning", "skipped")) {
    bad <- base
    bad[[field]] <- if (identical(field, "skipped")) TRUE else 1L
    .temporal_sixth_expect_reject(
      .temporal_sixth_assert_test_results(bad, "self-test"),
      paste0("a ", field, " result")
    )
  }
  cat("TEMPORAL_SIXTH_SELF-TEST_PASS\n")
  quit(save = "no", status = 0L)
}
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run temporal verification from the repository root.", call. = FALSE)
}
files <- switch(args,
  parser = "tests/testthat/test-temporal-sixth-source-api.R",
  oracle = "tests/testthat/test-temporal-sixth-source-oracles.R",
  methods = "tests/testthat/test-temporal-sixth-source-engine.R",
  recovery = "dev/temporal-sixth-source/run-recovery.R",
  regression = "tests/testthat/test-temporal-sixth-source-regressions.R"
)
fixture <- file.path(root, files)
.temporal_sixth_require_fixture(fixture)
if (args %in% c("recovery")) {
  status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", files, "verify"))
  if (!identical(status, 0L)) stop("Temporal sixth-source recovery failed.", call. = FALSE)
} else {
  ## `test_file()` does not load the development package itself.  Loading here
  ## keeps this runner executable from a clean R process and avoids the old
  ## false-positive path where missing exported temporal constructors became
  ## test errors that this script failed to inspect.
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  result <- testthat::test_file(fixture, reporter = "silent")
  .temporal_sixth_assert_test_results(result, fixture)
}
cat(sprintf("TEMPORAL_SIXTH_%s_PASS\n", toupper(args)))
