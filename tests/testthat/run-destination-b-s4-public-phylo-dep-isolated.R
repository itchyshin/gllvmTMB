#!/usr/bin/env Rscript

# One write-once receipt for the closed public S4 formula cell.  It deliberately
# reuses the existing adapter and test mathematics; it never dispatches through
# the generic `engine = "julia"` route.

s4_public_phylo_dep_targets <- function() c(
  "beta[1]", "beta[2]", "phylo_cov[1,1]", "phylo_cov[2,1]",
  "phylo_cov[2,2]", "residual_var_shared[1]", "residual_var_shared[2]"
)

s4_public_phylo_dep_known_manifest_sha256 <- function() "1c4844db1a58c6b978494668cbf9b9e789792103a15cbf52e866a87836090b57"
s4_public_phylo_dep_known_shared_object_sha256 <- function() "64f70caad53a235b62c35947ce62617589abc07c5092c77591b208322c84cb2b"

s4_public_phylo_dep_validate_endpoints <- function(payload, tolerance = 1e-4) {
  targets <- s4_public_phylo_dep_targets()
  required <- c("target_names", "native_lower", "native_upper", "julia_lower", "julia_upper")
  if (!all(required %in% names(payload))) stop("S4 public phylo_dep receipt has dangling endpoint output", call. = FALSE)
  values <- lapply(required[-1L], function(field) as.numeric(payload[[field]]))
  if (!identical(as.character(payload$target_names), targets) || any(vapply(values, length, integer(1)) != length(targets)) || any(vapply(values, function(x) any(!is.finite(x)), logical(1)))) stop("S4 public phylo_dep receipt has target/order mismatch", call. = FALSE)
  if (any(values[[1L]] >= values[[2L]]) || any(values[[3L]] >= values[[4L]])) stop("S4 public phylo_dep receipt has unordered endpoints", call. = FALSE)
  deltas <- pmax(abs(values[[1L]] - values[[3L]]), abs(values[[2L]] - values[[4L]]))
  if (any(deltas > tolerance)) stop("S4 public phylo_dep endpoint tolerance exceeded", call. = FALSE)
  list(target_names = targets, native_lower = values[[1L]], native_upper = values[[2L]], julia_lower = values[[3L]], julia_upper = values[[4L]], maximum_absolute_delta = max(deltas), tolerance = tolerance)
}

s4_public_phylo_dep_git <- function(args, label) {
  output <- system2("git", args, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(output, "status"))) stop(label, " failed: ", paste(output, collapse = "\n"), call. = FALSE)
  trimws(output)
}

s4_public_phylo_dep_snapshot <- function(path, label) {
  path <- normalizePath(path, mustWork = TRUE)
  dirty <- s4_public_phylo_dep_git(c("-C", path, "status", "--porcelain"), paste(label, "status"))
  if (length(dirty) && any(nzchar(dirty))) stop(label, " must be clean before retaining evidence", call. = FALSE)
  list(root = path, commit = s4_public_phylo_dep_git(c("-C", path, "rev-parse", "HEAD"), paste(label, "commit")))
}

s4_public_phylo_dep_validate_frozen_manifest <- function(manifest, source_root, manifest_path = NULL) {
  expected_commit <- "b4d5fee64def88bc768dda1f1f77c29b295edd86"
  required <- c("kind", "frozen_reference_commit", "source_archive_sha256", "shared_object_sha256")
  if (!all(required %in% names(manifest)) || !identical(manifest$kind, "destination_b_frozen_r_binary_build") || !identical(manifest$frozen_reference_commit, expected_commit) || !identical(manifest$source_archive_sha256, "0c2f4323eb9fb19acccf039b8d57b4dd6bda82e2aa8b4a7bb712f36a64b022bc") || !identical(manifest$shared_object_sha256, s4_public_phylo_dep_known_shared_object_sha256())) stop("frozen R build manifest does not bind the known source archive and DLL", call. = FALSE)
  if (!is.null(manifest_path) && !identical(digest::digest(file = manifest_path, algo = "sha256"), s4_public_phylo_dep_known_manifest_sha256())) stop("frozen R build manifest bytes do not match the known manifest", call. = FALSE)
  s4_public_phylo_dep_git(c("-C", normalizePath(source_root, mustWork = TRUE), "merge-base", "--is-ancestor", expected_commit, "HEAD"), "frozen R source ancestry")
  invisible(manifest)
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
  code <- sprintf("import Pkg; Pkg.activate(%s); using LogExpFunctions; isdefined(LogExpFunctions, :loglogistic) || error(\"missing loglogistic\"); using GLLVM; println(\"S4_JULIA_ENVIRONMENT_CLEAN\"); println(\"S4_ACTIVE_PROJECT=\" * Base.active_project()); println(\"S4_PACKAGE_ROOT=\" * Base.pkgdir(GLLVM))", dQuote(normalizePath(environment, mustWork = TRUE)))
  output <- system2(julia, c("--startup-file=no", "--project", "-e", code), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(output, "status")) || !any(grepl("S4_JULIA_ENVIRONMENT_CLEAN", output, fixed = TRUE)) || any(grepl("LogExpFunctions.*(Error|error|precompile)|loglogistic not defined", output))) stop("Julia environment is not qualified: LogExpFunctions extension load was not clean", call. = FALSE)
  active <- sub("^S4_ACTIVE_PROJECT=", "", output[grepl("^S4_ACTIVE_PROJECT=", output)])
  package_root <- sub("^S4_PACKAGE_ROOT=", "", output[grepl("^S4_PACKAGE_ROOT=", output)])
  if (!identical(length(active), 1L) || !identical(length(package_root), 1L) || !identical(normalizePath(package_root, mustWork = TRUE), normalizePath(project, mustWork = TRUE))) stop("Julia environment did not load the requested GLLVM project", call. = FALSE)
  list(executable = normalizePath(julia), executable_sha256 = digest::digest(file = julia, algo = "sha256"), active_project = normalizePath(active, mustWork = TRUE), package_root = normalizePath(package_root, mustWork = TRUE), environment = normalizePath(environment, mustWork = TRUE), output_sha256 = digest::digest(paste(output, collapse = "\n"), algo = "sha256"))
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
  r_before <- s4_public_phylo_dep_snapshot(getwd(), "gllvmTMB source")
  julia_before <- s4_public_phylo_dep_snapshot(project, "GLLVM.jl source")
  s4_public_phylo_dep_validate_frozen_manifest(frozen_manifest, getwd(), frozen_manifest_path)
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
  if (is.null(raw$embedded_julia_active_project) || is.null(raw$embedded_julia_package_root) || !identical(normalizePath(raw$embedded_julia_package_root, mustWork = TRUE), project)) stop("endpoint runtime did not attest the requested GLLVM package root", call. = FALSE)
  endpoints <- s4_public_phylo_dep_validate_endpoints(raw)
  dll <- normalizePath(file.path(getwd(), "src", "gllvmTMB.so"), mustWork = TRUE)
  loaded_dll <- getLoadedDLLs()[["gllvmTMB"]][["path"]]
  if (is.null(loaded_dll)) stop("gllvmTMB DLL is not loaded from this source", call. = FALSE)
  loaded_dll <- normalizePath(loaded_dll, mustWork = TRUE)
  if (!identical(digest::digest(file = dll, algo = "sha256"), s4_public_phylo_dep_known_shared_object_sha256()) || !identical(digest::digest(file = loaded_dll, algo = "sha256"), s4_public_phylo_dep_known_shared_object_sha256())) stop("loaded R DLL does not match frozen build manifest", call. = FALSE)
  r_after <- s4_public_phylo_dep_snapshot(getwd(), "gllvmTMB source")
  julia_after <- s4_public_phylo_dep_snapshot(project, "GLLVM.jl source")
  if (!identical(r_before, r_after) || !identical(julia_before, julia_after)) stop("source changed while S4 public phylo_dep evidence was being retained", call. = FALSE)
  result <- list(kind = "destination_b_s4_public_phylo_dep", status = "passed_experimental_postfit_only", scope = "Gaussian p=2, three-tip, shared-residual public formula cell; generic engine remains closed", source = list(frozen_reference_commit = frozen_manifest$frozen_reference_commit, frozen_source_archive_sha256 = frozen_manifest$source_archive_sha256, frozen_build_manifest_sha256 = digest::digest(file = frozen_manifest_path, algo = "sha256"), r_commit = r_before$commit, r_source_clean_and_stable = TRUE, r_shared_object_source_path = dll, r_shared_object_loaded_path = loaded_dll, r_shared_object_sha256 = digest::digest(file = dll, algo = "sha256"), gllvm_julia_commit = julia_before$commit, gllvm_julia_source_clean_and_stable = TRUE, fixture_sha256 = raw$fixture_sha256, julia = clean_probe), endpoint_pairs = endpoints, test_output_sha256 = digest::digest(paste(raw_output, collapse = "\n"), algo = "sha256"), runner_sha256 = digest::digest(file = "tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R", algo = "sha256"), generic_engine_closed = TRUE)
  s4_public_phylo_dep_write_once(result, receipt_path)
  cat("S4_PUBLIC_PHYLO_DEP_RECEIPT ", receipt_path, "\n", sep = "")
}

if (!identical(Sys.getenv("GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY"), "1")) s4_public_phylo_dep_main()
