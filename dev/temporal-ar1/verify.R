#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !args %in% c("parser", "oracle", "methods", "recovery", "regression")) {
  stop("Usage: Rscript --vanilla dev/temporal-ar1/verify.R {parser|oracle|methods|recovery|regression}", call. = FALSE)
}

## The repository root is deliberately the current directory for every ledger
## call, so its behavior is independent of Rscript's source-file metadata.
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run temporal verification from the repository root.", call. = FALSE)
}

fixtures <- switch(args,
  parser = "tests/testthat/test-temporal-ar1-parser.R",
  oracle = "tests/testthat/test-temporal-ar1-oracles.R",
  methods = "tests/testthat/test-temporal-ar1-methods.R"
)
if (args %in% c("recovery", "regression")) fixtures <- NULL
run_fixture <- function(path) {
  if (!file.exists(path)) stop(sprintf("Missing required temporal fixture: %s", path), call. = FALSE)
  results <- testthat::test_file(path, reporter = "silent")
  summary <- as.data.frame(results)
  if (!nrow(summary) || sum(summary$nb) == 0L) stop("Temporal verification ran zero assertions.", call. = FALSE)
  if (any(summary$skipped) || any(summary$failed > 0L) || any(summary$error) || any(summary$warning > 0L)) {
    stop("Temporal verification contains skipped, failed, errored, or warning results.", call. = FALSE)
  }
  if (sum(summary$passed) == 0L) stop("Temporal verification ran no passing assertions.", call. = FALSE)
}

devtools::load_all(root, quiet = TRUE)
if (args %in% c("parser", "oracle", "methods")) {
  fixture_override <- Sys.getenv("TEMPORAL_VERIFY_FIXTURE", unset = "")
  fixture_path <- if (nzchar(fixture_override)) {
    if (grepl("^/", fixture_override)) fixture_override else file.path(root, fixture_override)
  } else file.path(root, fixtures)
  run_fixture(fixture_path)
} else if (identical(args, "recovery")) {
  status <- system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", "dev/temporal-ar1/run-recovery.R"))
  if (!identical(status, 0L)) stop("Temporal recovery fixture failed its preregistered criteria.", call. = FALSE)
} else {
  ## This fixture covers the named ordinary-provider contracts without relying
  ## on the wider test files' intentional platform skips and informational
  ## warnings: this runner treats either as absent acceptance evidence.
  regression_files <- "tests/testthat/test-temporal-ar1-regressions.R"
  for (path in file.path(root, regression_files)) run_fixture(path)
  pkgdown::check_pkgdown()
  rmarkdown::render(file.path(root, "vignettes/articles/temporal-ar1.Rmd"),
    output_dir = tempdir(), quiet = TRUE)
}

marker <- switch(args,
  parser = "TEMPORAL_PARSER_PASS",
  oracle = "TEMPORAL_ORACLE_PASS",
  methods = "TEMPORAL_METHODS_PASS",
  recovery = "TEMPORAL_RECOVERY_PASS",
  regression = "TEMPORAL_REGRESSION_PASS"
)
cat(marker, "\n", sep = "")
