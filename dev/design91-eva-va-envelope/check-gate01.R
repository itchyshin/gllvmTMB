#!/usr/bin/env Rscript

# Mechanical Gate-0/1 verifier.  It never calls the fixture generator or gllvm.
required <- c(
  "docs/design/91-upstream-eva-va-row-support-envelope.md",
  "dev/design91-eva-va-envelope/design91-config.json",
  "dev/design91-eva-va-envelope/source-lock.json",
  "dev/design91-eva-va-envelope/telemetry-schema.json",
  "dev/design91-eva-va-envelope/design91-producer.R",
  "dev/design91-eva-va-envelope/run-smoke.R",
  "dev/design91-eva-va-envelope/fixtures/.gitkeep",
  "dev/design91-eva-va-envelope/results/smoke/.gitkeep"
)
missing <- required[!file.exists(required)]
if (length(missing)) stop("Missing required Design-91 files: ", paste(missing, collapse = ", "))
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for the static config check.")
config <- jsonlite::read_json("dev/design91-eva-va-envelope/design91-config.json", simplifyVector = TRUE)
lock <- jsonlite::read_json("dev/design91-eva-va-envelope/source-lock.json", simplifyVector = TRUE)
if (!identical(as.integer(config$q), 2L) || !identical(config$fit$methods, c("EVA", "VA"))) {
  stop("Design-91 method/rank contract is malformed.")
}
if (!identical(as.numeric(config$marginal_prevalence), c(0.25, 0.5)) ||
    !identical(as.integer(config$traits), c(30L, 60L))) stop("Row-support grid drift detected.")
sha256 <- function(path) {
  if (!file.exists(path)) stop("Locked file is missing: ", path)
  command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else if (nzchar(Sys.which("shasum"))) "shasum" else ""
  if (!nzchar(command)) stop("No SHA-256 command (sha256sum or shasum) is available.")
  args <- if (identical(command, "shasum")) c("-a", "256", path) else path
  strsplit(system2(command, args, stdout = TRUE), "[[:space:]]+")[[1L]][1L]
}
hash_checks <- c(
  lock$tarball_sha256 == sha256(lock$tarball),
  lock$producer_sha256 == sha256("dev/design91-eva-va-envelope/design91-producer.R"),
  lock$smoke_driver_sha256 == sha256("dev/design91-eva-va-envelope/run-smoke.R"),
  lock$config_sha256 == sha256("dev/design91-eva-va-envelope/design91-config.json"),
  lock$telemetry_schema_sha256 == sha256("dev/design91-eva-va-envelope/telemetry-schema.json")
)
if (!all(hash_checks)) stop("Design-91 source or implementation lock mismatch.")
smoke <- readLines("dev/design91-eva-va-envelope/run-smoke.R", warn = FALSE)
if (!any(grepl('D91_AUTHORIZE_SMOKE', smoke, fixed = TRUE))) stop("Smoke authorization guard missing.")
cat("Design 91 Gate 0/1 mechanical verification: PASS (the verifier generated no fixture and ran no model).\n")
