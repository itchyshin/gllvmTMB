#!/usr/bin/env Rscript

# One write-once receipt for the closed public S4 formula cell.  It deliberately
# reuses the existing adapter and test mathematics; it never dispatches through
# the generic `engine = "julia"` route.

s4_public_phylo_dep_targets <- function() c(
  "beta[1]", "beta[2]", "phylo_cov[1,1]", "phylo_cov[2,1]",
  "phylo_cov[2,2]", "residual_var_shared[1]", "residual_var_shared[2]"
)

s4_public_phylo_dep_validate_endpoints <- function(payload, tolerance = 1e-4) {
  targets <- s4_public_phylo_dep_targets()
  required <- c("target_names", "native_lower", "native_upper", "julia_lower", "julia_upper")
  if (!all(required %in% names(payload))) stop("S4 public phylo_dep receipt has dangling endpoint output", call. = FALSE)
  values <- lapply(required[-1L], function(field) as.numeric(payload[[field]]))
  if (!identical(as.character(payload$target_names), targets) || any(vapply(values, length, integer(1)) != length(targets)) || any(vapply(values, function(x) any(!is.finite(x)), logical(1)))) stop("S4 public phylo_dep receipt has target/order mismatch", call. = FALSE)
  deltas <- pmax(abs(values[[1L]] - values[[3L]]), abs(values[[2L]] - values[[4L]]))
  if (any(deltas > tolerance)) stop("S4 public phylo_dep endpoint tolerance exceeded", call. = FALSE)
  list(target_names = targets, native_lower = values[[1L]], native_upper = values[[2L]], julia_lower = values[[3L]], julia_upper = values[[4L]], maximum_absolute_delta = max(deltas), tolerance = tolerance)
}

s4_public_phylo_dep_write_once <- function(payload, path) {
  if (file.exists(path)) stop("refusing to overwrite existing S4 public phylo_dep receipt", call. = FALSE)
  directory <- dirname(path)
  if (!dir.exists(directory)) stop("S4 public phylo_dep receipt directory does not exist", call. = FALSE)
  temporary <- tempfile(pattern = paste0(".", basename(path), "."), tmpdir = directory)
  on.exit(unlink(temporary), add = TRUE)
  jsonlite::write_json(payload, temporary, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  if (!file.link(temporary, path)) stop("refusing to overwrite existing S4 public phylo_dep receipt", call. = FALSE)
  invisible(path)
}

s4_public_phylo_dep_clean_julia_probe <- function(project, environment, julia_home) {
  julia <- file.path(normalizePath(julia_home, mustWork = TRUE), "julia")
  if (!file.exists(julia)) julia <- file.path(normalizePath(julia_home, mustWork = TRUE), "bin", "julia")
  if (!file.exists(julia)) stop("GLLVM_S4_JULIA_HOME does not identify a Julia executable", call. = FALSE)
  code <- sprintf("import Pkg; Pkg.activate(%s); using LogExpFunctions; isdefined(LogExpFunctions, :loglogistic) || error(\"missing loglogistic\"); using GLLVM; println(\"S4_JULIA_ENVIRONMENT_CLEAN\")", dQuote(normalizePath(environment, mustWork = TRUE)))
  output <- system2(julia, c("--startup-file=no", "--project", "-e", code), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(output, "status")) || !any(grepl("S4_JULIA_ENVIRONMENT_CLEAN", output, fixed = TRUE)) || any(grepl("LogExpFunctions.*(Error|error|precompile)|loglogistic not defined", output))) stop("Julia environment is not qualified: LogExpFunctions extension load was not clean", call. = FALSE)
  list(executable = normalizePath(julia), executable_sha256 = digest::digest(file = julia, algo = "sha256"), project = normalizePath(project, mustWork = TRUE), environment = normalizePath(environment, mustWork = TRUE), output_sha256 = digest::digest(paste(output, collapse = "\n"), algo = "sha256"))
}

s4_public_phylo_dep_main <- function() {
  required <- c("GLLVM_S4_LIVE_FORMULA_TESTS", "GLLVM_DESTINATION_B_PROJECT", "GLLVM_S4_JULIA_HOME", "GLLVM_S4_JULIA_ENV", "GLLVM_S4_RECEIPT_PATH")
  missing <- required[!nzchar(Sys.getenv(required, unset = ""))]
  if (length(missing)) stop("missing required environment variable(s): ", paste(missing, collapse = ", "), call. = FALSE)
  if (!identical(Sys.getenv("GLLVM_S4_LIVE_FORMULA_TESTS"), "1")) stop("GLLVM_S4_LIVE_FORMULA_TESTS must equal 1", call. = FALSE)
  for (package in c("digest", "jsonlite", "pkgload", "testthat")) if (!requireNamespace(package, quietly = TRUE)) stop(package, " is required", call. = FALSE)
  project <- normalizePath(Sys.getenv("GLLVM_DESTINATION_B_PROJECT"), mustWork = TRUE)
  environment <- normalizePath(Sys.getenv("GLLVM_S4_JULIA_ENV"), mustWork = TRUE)
  if (!file.exists(file.path(project, "Project.toml")) || !file.exists(file.path(environment, "Project.toml"))) stop("S4 Julia project/environment is invalid", call. = FALSE)
  receipt_path <- normalizePath(dirname(Sys.getenv("GLLVM_S4_RECEIPT_PATH")), mustWork = TRUE)
  receipt_path <- file.path(receipt_path, basename(Sys.getenv("GLLVM_S4_RECEIPT_PATH")))
  if (file.exists(receipt_path)) stop("refusing to overwrite existing S4 public phylo_dep receipt", call. = FALSE)
  frozen_manifest_path <- normalizePath(file.path(getwd(), "docs", "dev-log", "artifacts", "2026-09-09-destination-b-frozen-r-binary-build-manifest.json"), mustWork = TRUE)
  frozen_manifest <- jsonlite::read_json(frozen_manifest_path, simplifyVector = TRUE)
  if (!identical(frozen_manifest$kind, "destination_b_frozen_r_binary_build") || !identical(frozen_manifest$frozen_reference_commit, "b4d5fee64def88bc768dda1f1f77c29b295edd86") || !grepl("^[[:xdigit:]]{64}$", frozen_manifest$source_archive_sha256) || !grepl("^[[:xdigit:]]{64}$", frozen_manifest$shared_object_sha256)) stop("frozen R build manifest does not bind the required source/build/DLL", call. = FALSE)
  clean_probe <- s4_public_phylo_dep_clean_julia_probe(project, environment, Sys.getenv("GLLVM_S4_JULIA_HOME"))
  pkgload::load_all(".", quiet = TRUE, compile = FALSE)
  expressions <- parse(file = "tests/testthat/test-julia-phylo-rr-bridge.R")
  text <- vapply(expressions, function(x) paste(deparse(x), collapse = "\n"), character(1))
  live <- grep("S4 public phylo_dep formula retains paired transformed-Wald endpoints", text, fixed = TRUE)
  generic <- grep("generic engine remains closed for the public phylo_dep formula", text, fixed = TRUE)
  if (!identical(length(live), 1L) || !identical(length(generic), 1L)) stop("S4 public phylo_dep runner cannot locate its exact test pair", call. = FALSE)
  if (exists(".s4_public_phylo_dep_receipt", envir = globalenv(), inherits = FALSE)) {
    rm(list = ".s4_public_phylo_dep_receipt", envir = globalenv())
  }
  reporter <- testthat::ListReporter$new()
  raw_output <- capture.output(testthat::with_reporter(reporter, { reporter$start_file("destination-b-s4-public-phylo-dep-isolated"); for (i in c(generic, live)) testthat:::test_code(expressions[[i]], globalenv()); reporter$end_context_if_started(); reporter$end_file() }), type = "output")
  tab <- as.data.frame(reporter$get_results())
  if (nrow(tab) != 2L || sum(tab$failed) + sum(tab$skipped) + sum(tab$error) + sum(tab$warning) != 0L) stop("S4 public phylo_dep test pair did not pass cleanly", call. = FALSE)
  raw <- get0(".s4_public_phylo_dep_receipt", envir = globalenv(), inherits = FALSE)
  endpoints <- s4_public_phylo_dep_validate_endpoints(raw)
  dll <- normalizePath(file.path(getwd(), "src", "gllvmTMB.so"), mustWork = TRUE)
  if (!identical(digest::digest(file = dll, algo = "sha256"), frozen_manifest$shared_object_sha256)) stop("loaded R DLL does not match frozen build manifest", call. = FALSE)
  result <- list(kind = "destination_b_s4_public_phylo_dep", status = "passed_experimental_postfit_only", scope = "Gaussian p=2, three-tip, shared-residual public formula cell; generic engine remains closed", source = list(frozen_reference_commit = frozen_manifest$frozen_reference_commit, frozen_source_archive_sha256 = frozen_manifest$source_archive_sha256, frozen_build_manifest_sha256 = digest::digest(file = frozen_manifest_path, algo = "sha256"), r_commit = system2("git", c("rev-parse", "HEAD"), stdout = TRUE), r_shared_object_sha256 = digest::digest(file = dll, algo = "sha256"), gllvm_julia_commit = system2("git", c("-C", project, "rev-parse", "HEAD"), stdout = TRUE), fixture_sha256 = raw$fixture_sha256, julia = clean_probe), endpoint_pairs = endpoints, test_output_sha256 = digest::digest(paste(raw_output, collapse = "\n"), algo = "sha256"), runner_sha256 = digest::digest(file = "tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R", algo = "sha256"), generic_engine_closed = TRUE)
  s4_public_phylo_dep_write_once(result, receipt_path)
  cat("S4_PUBLIC_PHYLO_DEP_RECEIPT ", receipt_path, "\n", sep = "")
}

if (!identical(Sys.getenv("GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY"), "1")) s4_public_phylo_dep_main()
