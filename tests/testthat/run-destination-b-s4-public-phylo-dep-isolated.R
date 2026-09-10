#!/usr/bin/env Rscript

# One write-once receipt for the closed public S4 formula cell.  It deliberately
# reuses the existing adapter and test mathematics; it never dispatches through
# the generic `engine = "julia"` route.

s4_public_phylo_dep_targets <- function() c(
  "beta[1]", "beta[2]", "phylo_cov[1,1]", "phylo_cov[2,1]",
  "phylo_cov[2,2]", "residual_var_shared[1]", "residual_var_shared[2]"
)

s4_public_phylo_dep_expected_s4_source_commit <- function() "8889d8a4d2d88e1cfd60f7b644eb79e71a7346f4"
s4_public_phylo_dep_s4_seal_sha256 <- function() "a16bf7ecae725c8e3fb7282c7ae6b63b7f648cf052da8f46556a1ff7b1d61d9e"
s4_public_phylo_dep_expected_s4_selected_source <- function() c(
  "R/julia-bridge.R" = "cb3b5cd2f7017deeaea664c593da95e044a2a4592128212e6176fe3f39a2c9a2",
  "tests/testthat/test-julia-phylo-rr-bridge.R" = "409961775de390c48eb7b2185f808e4091298c7febbdfe4b058ef370e3632f72"
)

s4_public_phylo_dep_s4_seal_path <- function(root = getwd()) {
  normalizePath(file.path(root, "docs", "dev-log", "artifacts",
                          "2026-09-10-destination-b-s4-phylo-dep-build-seal",
                          "destination-b-s4-phylo-dep-build-seal.json"), mustWork = TRUE)
}

s4_public_phylo_dep_dll_identity <- function(path) {
  path <- normalizePath(path, mustWork = TRUE)
  uuid_output <- system2("dwarfdump", c("--uuid", path), stdout = TRUE, stderr = TRUE)
  uuid <- sub("^UUID: ([^ ]+).*", "\\1", uuid_output[grepl("^UUID: ", uuid_output)])
  if (!identical(length(uuid), 1L) || !grepl("^[0-9A-F-]{36}$", uuid)) {
    stop("S4 build artifact has no usable Mach-O UUID", call. = FALSE)
  }
  list(path = path, sha256 = digest::digest(file = path, algo = "sha256"),
       uuid = uuid, bytes = unname(file.info(path)$size))
}

s4_public_phylo_dep_validate_s4_seal_payload <- function(seal) {
  required <- c("kind", "schema", "status", "source_snapshot", "build", "binary_identity", "contract")
  if (!all(required %in% names(seal)) || !identical(seal$kind, "destination_b_s4_phylo_dep_build_seal") || !identical(seal$schema, 1L) || !identical(seal$status, "sealed_build_only_no_fit_or_receipt") || !isTRUE(seal$contract$require_exact_archive_and_selected_source) || !isTRUE(seal$contract$require_exact_s4_build_artifact) || !identical(seal$contract$allow_source_rebuild_as_qualification, FALSE)) {
    stop("S4 build seal has an invalid contract", call. = FALSE)
  }
  if (!identical(seal$source_snapshot$commit, s4_public_phylo_dep_expected_s4_source_commit())) {
    stop("S4 build seal source commit mismatch", call. = FALSE)
  }
  selected <- vapply(seal$source_snapshot$selected_source, function(entry) entry$sha256, character(1))
  names(selected) <- vapply(seal$source_snapshot$selected_source, function(entry) entry$path, character(1))
  if (!identical(selected, s4_public_phylo_dep_expected_s4_selected_source())) {
    stop("S4 build seal selected-source hash mismatch", call. = FALSE)
  }
  invisible(seal)
}

s4_public_phylo_dep_validate_s4_runtime_root <- function(source_root, seal, expected_commit = s4_public_phylo_dep_expected_s4_source_commit()) {
  source_root <- normalizePath(source_root, mustWork = TRUE)
  if (!identical(seal$source_snapshot$commit, expected_commit)) {
    stop("S4 build seal runtime root does not match its archive root", call. = FALSE)
  }
  dirty <- s4_public_phylo_dep_git(c("-C", source_root, "status", "--porcelain"), "S4 runtime root status")
  if (length(dirty) && any(nzchar(dirty))) stop("S4 runtime root must be clean", call. = FALSE)
  ancestry <- suppressWarnings(system2("git", c("-C", source_root, "merge-base", "--is-ancestor", expected_commit, "HEAD"), stdout = TRUE, stderr = TRUE))
  status <- attr(ancestry, "status")
  if (!is.null(status) && identical(as.integer(status), 1L)) stop("S4 runtime root is not a descendant of the archive root", call. = FALSE)
  if (!is.null(status)) stop("S4 runtime root ancestry check failed: ", paste(ancestry, collapse = "\n"), call. = FALSE)
  changed <- s4_public_phylo_dep_git(c("-C", source_root, "diff", "--name-only", paste0(expected_commit, "..HEAD"), "--", "R", "src", "DESCRIPTION"), "S4 runtime root package-source diff")
  if (length(changed) && any(nzchar(changed))) stop("S4 runtime root package source drift", call. = FALSE)
  list(root = source_root, archive_root_commit = expected_commit,
       runtime_commit = s4_public_phylo_dep_git(c("-C", source_root, "rev-parse", "HEAD"), "S4 runtime root commit"))
}

s4_public_phylo_dep_read_s4_seal <- function(source_root, seal_path = s4_public_phylo_dep_s4_seal_path(source_root)) {
  source_root <- normalizePath(source_root, mustWork = TRUE)
  canonical_path <- s4_public_phylo_dep_s4_seal_path(source_root)
  seal_path <- normalizePath(seal_path, mustWork = TRUE)
  if (!identical(seal_path, canonical_path)) stop("S4 build seal must use its canonical path", call. = FALSE)
  if (!identical(digest::digest(file = seal_path, algo = "sha256"), s4_public_phylo_dep_s4_seal_sha256())) stop("S4 build seal bytes do not match the pinned seal", call. = FALSE)
  seal <- jsonlite::read_json(seal_path, simplifyVector = FALSE)
  s4_public_phylo_dep_validate_s4_seal_payload(seal)
  archive <- file.path(source_root, seal$source_snapshot$archive$path)
  if (!file.exists(archive) || !identical(digest::digest(file = archive, algo = "sha256"), seal$source_snapshot$archive$sha256) || !identical(unname(file.info(archive)$size), as.numeric(seal$source_snapshot$archive$bytes))) {
    stop("S4 build seal source archive identity mismatch", call. = FALSE)
  }
  for (entry in seal$source_snapshot$selected_source) {
    path <- file.path(source_root, entry$path)
    if (!file.exists(path) || !identical(digest::digest(file = path, algo = "sha256"), entry$sha256)) {
      stop("S4 build seal selected source identity mismatch", call. = FALSE)
    }
  }
  source_dll <- s4_public_phylo_dep_dll_identity(file.path(source_root, seal$binary_identity$source_dll$path))
  expected_source <- seal$binary_identity$source_dll
  if (!identical(source_dll$sha256, expected_source$sha256) || !identical(source_dll$uuid, expected_source$uuid) || !identical(as.numeric(source_dll$bytes), as.numeric(expected_source$bytes))) {
    stop("S4 build seal source DLL identity mismatch", call. = FALSE)
  }
  seal$binary_identity$source_dll$path <- source_dll$path
  seal$isolated_library <- normalizePath(file.path(source_root, seal$build$isolated_library$path), mustWork = TRUE)
  seal
}

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

s4_public_phylo_dep_validate_embedded_julia_runtime <- function(active_project, package_root, project) {
  expected_active <- normalizePath(file.path(project, "Project.toml"), mustWork = TRUE)
  if (is.null(active_project) || is.null(package_root) || !identical(normalizePath(active_project, mustWork = TRUE), expected_active) || !identical(normalizePath(package_root, mustWork = TRUE), normalizePath(project, mustWork = TRUE))) stop("endpoint runtime did not attest the configured Julia active project and GLLVM package root", call. = FALSE)
  list(active_project = expected_active, package_root = normalizePath(project, mustWork = TRUE))
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

s4_public_phylo_dep_failed_diagnostic_path <- function(receipt_path) {
  receipt_path <- normalizePath(receipt_path, mustWork = FALSE)
  file.path(
    dirname(receipt_path),
    paste0(tools::file_path_sans_ext(basename(receipt_path)), "-FAILED.json")
  )
}

s4_public_phylo_dep_write_failed_diagnostic_once <- function(payload, path, receipt_path) {
  path <- normalizePath(path, mustWork = FALSE)
  receipt_path <- normalizePath(receipt_path, mustWork = FALSE)
  if (identical(path, receipt_path)) {
    stop("S4 failed-attempt diagnostic must not use the receipt path", call. = FALSE)
  }
  if (file.exists(path)) {
    stop("refusing to overwrite existing S4 failed-attempt diagnostic", call. = FALSE)
  }
  directory <- dirname(path)
  if (!dir.exists(directory)) stop("S4 failed-attempt diagnostic directory does not exist", call. = FALSE)
  temporary <- tempfile(pattern = paste0(".", basename(path), "."), tmpdir = directory)
  on.exit(unlink(temporary), add = TRUE)
  jsonlite::write_json(payload, temporary, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  if (!file.link(temporary, path)) {
    stop("refusing to overwrite existing S4 failed-attempt diagnostic", call. = FALSE)
  }
  invisible(path)
}

s4_public_phylo_dep_reporter_details <- function(results) {
  lapply(results, function(test) {
    list(
      file = test$file,
      context = test$context,
      test = test$test,
      expectations = lapply(test$results, function(expectation) {
        call <- if (inherits(expectation, "condition")) conditionCall(expectation) else NULL
        list(
          class = class(expectation),
          message = if (inherits(expectation, "condition")) conditionMessage(expectation) else expectation$message,
          call = if (is.null(call)) NULL else paste(deparse(call), collapse = "\n"),
          backtrace = if (is.null(expectation$trace)) NULL else paste(capture.output(print(expectation$trace)), collapse = "\n")
        )
      })
    )
  })
}

s4_public_phylo_dep_retain_failed_attempt <- function(tab, raw_output, reporter_details, provenance, receipt_path) {
  failed_path <- s4_public_phylo_dep_failed_diagnostic_path(receipt_path)
  provenance$selected_test_expressions <- as.list(provenance$selected_test_expressions)
  counts <- vapply(c("failed", "skipped", "error", "warning"), function(name) {
    if (!name %in% names(tab)) 0L else sum(as.integer(tab[[name]]), na.rm = TRUE)
  }, integer(1))
  dirty <- nrow(tab) != 2L || sum(counts) != 0L
  if (!dirty) return(invisible(NULL))
  payload <- list(
    kind = "destination_b_s4_public_phylo_dep_failed_attempt",
    schema = 1L,
    status = "failed_test_attempt_not_a_receipt",
    receipt_path = normalizePath(receipt_path, mustWork = FALSE),
    source = provenance,
    selected_test_count = nrow(tab),
    test_counts = as.list(counts),
    test_tab = as.list(tab),
    raw_output = as.list(raw_output),
    raw_output_sha256 = digest::digest(paste(raw_output, collapse = "\n"), algo = "sha256"),
    raw_output_information_gap = "Raw capture.output lines are retained unchanged. ListReporter raw output can omit expectation condition details; available condition message, call, and backtrace data are retained separately in reporter_details.",
    reporter_details = reporter_details
  )
  s4_public_phylo_dep_write_failed_diagnostic_once(payload, failed_path, receipt_path)
  stop("S4 public phylo_dep test pair did not pass cleanly; failed-attempt diagnostic retained at ", failed_path, call. = FALSE)
}

s4_public_phylo_dep_julia_literal <- function(path) {
  ## `dQuote()` follows R's user-facing fancy-quote option, whereas this value
  ## is embedded in Julia source passed through a shell. JSON string syntax is
  ## valid Julia syntax and is always ASCII-quoted.
  as.character(jsonlite::toJSON(normalizePath(path, mustWork = TRUE), auto_unbox = TRUE))
}

s4_public_phylo_dep_julia_args <- function(code) {
  c("--startup-file=no", "--project", "-e", shQuote(code))
}

s4_public_phylo_dep_clean_julia_probe <- function(project, environment, julia_home) {
  julia <- file.path(normalizePath(julia_home, mustWork = TRUE), "julia")
  if (!file.exists(julia)) julia <- file.path(normalizePath(julia_home, mustWork = TRUE), "bin", "julia")
  if (!file.exists(julia)) stop("GLLVM_S4_JULIA_HOME does not identify a Julia executable", call. = FALSE)
  code <- sprintf("import Pkg; Pkg.activate(%s); using LogExpFunctions; isdefined(LogExpFunctions, :loglogistic) || error(\"missing loglogistic\"); using GLLVM; println(\"S4_JULIA_ENVIRONMENT_CLEAN\"); println(\"S4_ACTIVE_PROJECT=\" * Base.active_project()); println(\"S4_PACKAGE_ROOT=\" * Base.pkgdir(GLLVM))", s4_public_phylo_dep_julia_literal(environment))
  output <- system2(julia, s4_public_phylo_dep_julia_args(code), stdout = TRUE, stderr = TRUE)
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
  for (package in c("digest", "jsonlite", "testthat")) if (!requireNamespace(package, quietly = TRUE)) stop(package, " is required", call. = FALSE)
  project <- normalizePath(Sys.getenv("GLLVM_DESTINATION_B_PROJECT"), mustWork = TRUE)
  environment <- normalizePath(Sys.getenv("GLLVM_S4_JULIA_ENV"), mustWork = TRUE)
  if (!file.exists(file.path(project, "Project.toml")) || !file.exists(file.path(environment, "Project.toml"))) stop("S4 Julia project/environment is invalid", call. = FALSE)
  receipt_path <- normalizePath(dirname(Sys.getenv("GLLVM_S4_RECEIPT_PATH")), mustWork = TRUE)
  receipt_path <- file.path(receipt_path, basename(Sys.getenv("GLLVM_S4_RECEIPT_PATH")))
  if (file.exists(receipt_path)) stop("refusing to overwrite existing S4 public phylo_dep receipt", call. = FALSE)
  r_before <- s4_public_phylo_dep_snapshot(getwd(), "gllvmTMB source")
  julia_before <- s4_public_phylo_dep_snapshot(project, "GLLVM.jl source")
  s4_seal <- s4_public_phylo_dep_read_s4_seal(getwd())
  runtime_root <- s4_public_phylo_dep_validate_s4_runtime_root(getwd(), s4_seal)
  clean_probe <- s4_public_phylo_dep_clean_julia_probe(project, environment, Sys.getenv("GLLVM_S4_JULIA_HOME"))
  if ("gllvmTMB" %in% loadedNamespaces()) stop("S4 sealed load requires no preloaded gllvmTMB namespace", call. = FALSE)
  library("gllvmTMB", lib.loc = s4_seal$isolated_library, character.only = TRUE)
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
  reporter_results <- reporter$get_results()
  tab <- as.data.frame(reporter_results)
  selected_test_expressions <- text[c(generic, live)]
  names(selected_test_expressions) <- c("generic_engine_closed", "paired_endpoint_formula")
  s4_public_phylo_dep_retain_failed_attempt(
    tab = tab,
    raw_output = raw_output,
    reporter_details = s4_public_phylo_dep_reporter_details(reporter_results),
    provenance = list(
      sealed_build = list(
        path = s4_public_phylo_dep_s4_seal_path(getwd()),
        sha256 = s4_public_phylo_dep_s4_seal_sha256(),
        source_archive_sha256 = s4_seal$source_snapshot$archive$sha256,
        source_commit = s4_seal$source_snapshot$commit,
        binary_identity = s4_seal$binary_identity
      ),
      r_runtime = list(snapshot = r_before, validated_runtime_root = runtime_root),
      gllvm_runtime = julia_before,
      julia_probe = clean_probe,
      runner_identity = list(
        path = normalizePath("tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R", mustWork = TRUE),
        sha256 = digest::digest(file = "tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R", algo = "sha256")
      ),
      selected_test_expressions = selected_test_expressions
    ),
    receipt_path = receipt_path
  )
  raw <- get0(".s4_public_phylo_dep_receipt", envir = globalenv(), inherits = FALSE)
  embedded_julia <- s4_public_phylo_dep_validate_embedded_julia_runtime(raw$embedded_julia_active_project, raw$embedded_julia_package_root, project)
  endpoints <- s4_public_phylo_dep_validate_endpoints(raw)
  dll <- s4_seal$binary_identity$source_dll$path
  loaded_dll <- getLoadedDLLs()[["gllvmTMB"]][["path"]]
  if (is.null(loaded_dll)) stop("gllvmTMB DLL is not loaded from this source", call. = FALSE)
  loaded_dll <- normalizePath(loaded_dll, mustWork = TRUE)
  loaded_identity <- s4_public_phylo_dep_dll_identity(loaded_dll)
  expected_loaded <- s4_seal$binary_identity$loaded_dll
  if (!identical(loaded_identity$sha256, expected_loaded$sha256) || !identical(loaded_identity$uuid, expected_loaded$uuid) || !identical(as.numeric(loaded_identity$bytes), as.numeric(expected_loaded$bytes))) stop("loaded R DLL does not match S4 build seal", call. = FALSE)
  r_after <- s4_public_phylo_dep_snapshot(getwd(), "gllvmTMB source")
  julia_after <- s4_public_phylo_dep_snapshot(project, "GLLVM.jl source")
  if (!identical(r_before, r_after) || !identical(julia_before, julia_after)) stop("source changed while S4 public phylo_dep evidence was being retained", call. = FALSE)
  result <- list(kind = "destination_b_s4_public_phylo_dep", status = "passed_experimental_postfit_only", scope = "Gaussian p=2, three-tip, shared-residual public formula cell; generic engine remains closed", source = list(s4_build_seal_path = s4_public_phylo_dep_s4_seal_path(getwd()), s4_source_archive_sha256 = s4_seal$source_snapshot$archive$sha256, s4_archive_build_root_commit = s4_seal$source_snapshot$commit, r_runtime_root = runtime_root, r_commit = r_before$commit, r_source_clean_and_stable = TRUE, r_shared_object_source = s4_seal$binary_identity$source_dll, r_shared_object_loaded = loaded_identity, gllvm_julia_commit = julia_before$commit, gllvm_julia_source_clean_and_stable = TRUE, fixture_sha256 = raw$fixture_sha256, julia = clean_probe, embedded_julia_runtime = embedded_julia), endpoint_pairs = endpoints, test_output_sha256 = digest::digest(paste(raw_output, collapse = "\n"), algo = "sha256"), runner_sha256 = digest::digest(file = "tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R", algo = "sha256"), generic_engine_closed = TRUE)
  s4_public_phylo_dep_write_once(result, receipt_path)
  cat("S4_PUBLIC_PHYLO_DEP_RECEIPT ", receipt_path, "\n", sep = "")
}

if (!identical(Sys.getenv("GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY"), "1")) s4_public_phylo_dep_main()
