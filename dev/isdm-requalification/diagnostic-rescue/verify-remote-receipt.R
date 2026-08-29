## Fail-closed verifier for locally copied Totoro evidence bundles.

.receipt_file <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  script <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  candidates <- c(current,
    if (length(script) == 1L) sub("^--file=", "", script) else character(),
    file.path("dev", "isdm-requalification", "diagnostic-rescue",
              "verify-remote-receipt.R"),
    file.path("..", "..", "dev", "isdm-requalification",
              "diagnostic-rescue", "verify-remote-receipt.R"))
  current <- candidates[!is.na(candidates) & nzchar(candidates) &
                          file.exists(candidates)][[1L]]
  normalizePath(current, mustWork = TRUE)
})
.receipt_dir <- dirname(.receipt_file)

.receipt_abort <- function(message, class = "isdm_diag_receipt_invalid") {
  stop(structure(list(message = message, call = NULL),
                 class = c(class, "error", "condition")))
}
.receipt_hex <- function(x) is.character(x) && length(x) == 1L &&
  !is.na(x) && grepl("^[0-9a-fA-F]{64}$", x)
.receipt_hash <- function(path) {
  command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else "shasum"
  args <- if (command == "shasum") c("-a", "256", path) else path
  out <- system2(command, args, stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status"); if (is.null(status)) status <- 0L
  hash <- if (length(out)) tolower(sub("[[:space:]].*$", "", out[[1L]])) else ""
  if (status != 0L || !grepl("^[0-9a-f]{64}$", hash))
    .receipt_abort("SHA-256 command failed", "isdm_diag_receipt_hash_failed")
  hash
}
.receipt_object_hash <- function(object) {
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(object, path, version = 3)
  .receipt_hash(path)
}

isdm_diag_verify_bundle_manifest <- function(bundle) {
  bundle <- normalizePath(bundle, mustWork = TRUE)
  manifest <- file.path(bundle, "MANIFEST.sha256")
  if (!file.exists(manifest) || isTRUE(file.info(manifest)$isdir))
    .receipt_abort("bundle MANIFEST.sha256 is missing")
  lines <- readLines(manifest, warn = FALSE)
  match <- regexec("^([0-9A-Fa-f]{64})  ([^/].*)$", lines)
  fields <- regmatches(lines, match)
  if (!length(lines) || any(lengths(fields) != 3L))
    .receipt_abort("bundle manifest has malformed rows")
  expected <- tolower(vapply(fields, `[[`, character(1L), 2L))
  paths <- vapply(fields, `[[`, character(1L), 3L)
  if (anyDuplicated(paths) || any(paths == "MANIFEST.sha256") ||
      any(grepl("(^|/)[.]{1,2}(/|$)", paths)) || any(grepl("\\\\", paths)))
    .receipt_abort("bundle manifest has duplicate or unsafe paths")
  actual <- sort(list.files(bundle, recursive = TRUE, all.files = TRUE,
                            no.. = TRUE, include.dirs = FALSE))
  actual <- setdiff(actual, "MANIFEST.sha256")
  if (!identical(sort(paths), actual))
    .receipt_abort("bundle manifest does not enumerate the exact file set")
  full <- file.path(bundle, paths)
  if (any(file.info(full)$isdir) || any(Sys.readlink(full) != ""))
    .receipt_abort("bundle contains a directory entry or symbolic link")
  observed <- unname(vapply(full, .receipt_hash, character(1L)))
  if (!identical(observed, unname(expected)))
    .receipt_abort("bundle SHA-256 verification failed",
                   "isdm_diag_receipt_hash_mismatch")
  invisible(stats::setNames(expected, paths))
}

.receipt_evidence_root <- function() {
  configured <- Sys.getenv("ISDM_DIAG_EVIDENCE_DIR", unset = "")
  if (nzchar(configured)) configured else file.path(.receipt_dir, "evidence")
}
.receipt_read <- function(bundle, relative) {
  path <- file.path(bundle, relative)
  if (!file.exists(path)) .receipt_abort(paste("required evidence missing:", relative))
  readRDS(path)
}
.receipt_sha <- "09eca7b1eb9018958bad367be824871161a60af1"
.receipt_tree <- "fb979daa5d9a93d0804a053ff1bb00eced47ad09"

.receipt_verify_qualification_object <- function(x) {
  harness <- file.path(.receipt_dir, "HARNESS_SHA256.txt")
  required <- c("schema", "source_sha", "source_tree", "ci_run_id",
                "ci_platforms", "package_path", "installed_manifest",
                "installed_manifest_sha256", "dll_path", "dll_sha256",
                "harness_manifest_sha256", "harness_manifest_verified_n")
  if (!is.list(x) || !all(required %in% names(x)) ||
      !identical(x$schema, "isdm-diagnostic-qualification-v1") ||
      !identical(x$source_sha, .receipt_sha) ||
      !identical(x$source_tree, .receipt_tree) ||
      !identical(as.numeric(x$ci_run_id), 33272534580) ||
      !identical(unname(x$ci_platforms[c("linux", "macos", "windows")]),
                 rep("success", 3L)) ||
      !is.character(x$package_path) || length(x$package_path) != 1L ||
      is.na(x$package_path) || !nzchar(x$package_path) ||
      !is.character(x$dll_path) || length(x$dll_path) != 1L ||
      is.na(x$dll_path) || !nzchar(x$dll_path) ||
      !is.data.frame(x$installed_manifest) || !nrow(x$installed_manifest) ||
      !all(c("path", "sha256") %in% names(x$installed_manifest)) ||
      anyNA(x$installed_manifest[c("path", "sha256")]) ||
      anyDuplicated(x$installed_manifest$path) ||
      any(grepl("^/|(^|/)[.]{1,2}(/|$)|\\\\", x$installed_manifest$path)) ||
      any(!vapply(x$installed_manifest$sha256, .receipt_hex, logical(1L))) ||
      !.receipt_hex(x$installed_manifest_sha256) ||
      !identical(tolower(x$installed_manifest_sha256),
                 .receipt_object_hash(x$installed_manifest)) ||
      !.receipt_hex(x$dll_sha256) ||
      !.receipt_hex(x$harness_manifest_sha256) ||
      !file.exists(harness) ||
      !identical(tolower(x$harness_manifest_sha256), .receipt_hash(harness)) ||
      !identical(as.integer(x$harness_manifest_verified_n),
                 as.integer(length(readLines(harness, warn = FALSE))))) {
    .receipt_abort("qualification receipt differs from the frozen source/harness contract")
  }
  invisible(TRUE)
}

.receipt_verify_records <- function(plan, output, expected_n, qualification) {
  summary_file <- file.path(.receipt_dir, "summarise-independent.R")
  env <- new.env(parent = baseenv())
  sys.source(summary_file, envir = env)
  checked_plan <- env$.ind_plan(plan, expected_n)
  dispositions <- env$.ind_dispositions(checked_plan, output)
  records <- dispositions$records
  for (x in records) {
    if (!identical(x$source_sha, qualification$source_sha) ||
        !identical(x$source_tree, qualification$source_tree) ||
        !identical(x$harness_manifest_sha256,
                   qualification$harness_manifest_sha256)) {
      .receipt_abort("task receipt identity differs from qualification")
    }
  }
  list(plan = checked_plan, records = records, counts = dispositions)
}

.receipt_verify_qualification <- function(root) {
  bundle <- file.path(root, "qualification")
  isdm_diag_verify_bundle_manifest(bundle)
  qualification <- .receipt_read(bundle, "qualification.rds")
  .receipt_verify_qualification_object(qualification)
  cat("DIAGNOSTIC_REMOTE_QUALIFICATION_VERIFIED\n")
  invisible(qualification)
}

.receipt_verify_smoke <- function(root) {
  bundle <- file.path(root, "smoke")
  isdm_diag_verify_bundle_manifest(bundle)
  qualification <- .receipt_read(bundle, "qualification.rds")
  .receipt_verify_qualification_object(qualification)
  plan_path <- file.path(bundle, "plan.rds")
  records <- .receipt_verify_records(plan_path, file.path(bundle, "output"),
                                     4L, qualification)
  plan <- records$plan
  if (sum(plan$slice == "nonspatial") != 1L ||
      sum(plan$slice == "spatial") != 3L ||
      !identical(sort(as.character(plan$variant)),
                 sort(c("rep3", "default", "bfgs_continuation", "nlminb5"))) ||
      records$counts$started_n != 4L ||
      any(vapply(records$records, `[[`, character(1L), "status") != "fit_returned"))
    .receipt_abort("smoke does not retain four returned started tasks")
  non <- records$records[[which(plan$slice == "nonspatial")]]
  variants <- stats::setNames(records$records, plan$variant)
  expected_rep_seeds <- 203000000L + 2L * plan$native_task_id[plan$slice == "nonspatial"] + 0:1
  default_state <- local({
    x <- variants$default
    paste0(if (as.integer(x$diagnostics$convergence) == 0L)
      "converged" else "nonconverged",
      if (isTRUE(x$diagnostics$pd_hessian)) "_pd" else "_nonpd")
  })
  if (!isTRUE(non$rep3_baseline_byte_identical) ||
      !identical(non$design$replication, 3L) ||
      !identical(as.integer(non$design$replicate_seeds), as.integer(expected_rep_seeds)) ||
      !all(c("fixed", "shared", "full") %in% names(non$metrics)) ||
      !isTRUE(non$metrics$full_public_identity_error <= 1e-10) ||
      !isTRUE(non$metrics$sign_invariance_error <= 1e-10) ||
      !isTRUE(non$curvature$available) ||
      !identical(default_state, variants$default$production_outcome_class) ||
      !isTRUE(variants$nlminb5$first_start_equal_default) ||
      !isTRUE(variants$bfgs_continuation$continuation_copy$all_equal) ||
      !all(vapply(variants[c("default", "bfgs_continuation", "nlminb5")],
                  function(x) isTRUE(x$curvature$available), logical(1L)))) {
    .receipt_abort("smoke identity, estimand, start, or curvature checks failed")
  }
  projection <- .receipt_read(bundle, "projection.rds")
  if (!is.list(projection) ||
      !identical(projection$schema, "isdm-diagnostic-smoke-projection-v1") ||
      !identical(as.integer(projection$smoke_tasks), 4L) ||
      !is.numeric(projection$observed_wall_s) || !is.finite(projection$observed_wall_s) ||
      !is.numeric(projection$projected_wall_s) ||
      !is.finite(projection$projected_wall_s) || projection$projected_wall_s > 600) {
    .receipt_abort("smoke projection is absent, malformed, or exceeds ten minutes")
  }
  cat("DIAGNOSTIC_SMOKE_VERIFIED\n")
  invisible(records)
}

.receipt_verify_experiment <- function(root) {
  bundle <- file.path(root, "experiment")
  isdm_diag_verify_bundle_manifest(bundle)
  qualification <- .receipt_read(bundle, "qualification.rds")
  .receipt_verify_qualification_object(qualification)
  records <- .receipt_verify_records(file.path(bundle, "plan.rds"),
                                     file.path(bundle, "output"), 52L,
                                     qualification)
  if (length(records$records) != 52L ||
      !identical(sort(as.integer(records$plan$task_id)), 1:52))
    .receipt_abort("experiment does not preserve all 52 planned dispositions")
  spatial <- which(records$plan$slice == "spatial")
  for (native in unique(records$plan$native_task_id[spatial])) {
    idx <- spatial[records$plan$native_task_id[spatial] == native]
    tasks <- records$plan[idx, , drop = FALSE]
    values <- records$records[idx]
    names(values) <- tasks$variant
    default <- values$default
    if (identical(default$status, "fit_returned")) {
      state <- paste0(if (as.integer(default$diagnostics$convergence) == 0L)
        "converged" else "nonconverged",
        if (isTRUE(default$diagnostics$pd_hessian)) "_pd" else "_nonpd")
      if (!identical(state, tasks$sentinel_class[tasks$variant == "default"][[1L]]))
        .receipt_abort("a default replay changed its frozen production outcome class")
    }
    if (identical(values$nlminb5$status, "fit_returned") &&
        identical(default$status, "fit_returned") &&
        !isTRUE(values$nlminb5$first_start_equal_default))
      .receipt_abort("an nlminb5 arm does not retain default first-start equality")
    if (identical(values$bfgs_continuation$status, "fit_returned") &&
        !isTRUE(values$bfgs_continuation$continuation_copy$all_equal))
      .receipt_abort("a BFGS continuation does not retain copied-block equality")
  }
  cat("DIAGNOSTIC_52_ATTEMPTS_VERIFIED\n")
  invisible(records)
}

.receipt_verify_summary <- function(root) {
  bundle <- file.path(root, "experiment")
  isdm_diag_verify_bundle_manifest(bundle)
  source(file.path(.receipt_dir, "summarise-independent.R"), local = TRUE)
  observed <- isdm_diag_independent_summary(file.path(bundle, "plan.rds"),
                                            file.path(bundle, "output"))
  retained <- .receipt_read(bundle, "independent-summary.rds")
  if (!identical(observed, retained) ||
      !identical(observed$schema, ISDM_DIAG_SUMMARY_SCHEMA) ||
      !identical(observed$denominators$planned, 52L) ||
      !identical(observed$denominators$terminal, 52L))
    .receipt_abort("retained summary is not reproduced exactly from raw records")
  cat("DIAGNOSTIC_SUMMARY_VERIFIED\n")
  invisible(observed)
}

isdm_diag_verify_remote_receipt <- function(mode, root = .receipt_evidence_root()) {
  if (!mode %in% c("qualification", "smoke", "experiment", "summary"))
    .receipt_abort("unknown receipt verification mode")
  switch(mode, qualification = .receipt_verify_qualification(root),
         smoke = .receipt_verify_smoke(root),
         experiment = .receipt_verify_experiment(root),
         summary = .receipt_verify_summary(root))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("usage: verify-remote-receipt.R qualification|smoke|experiment|summary")
  isdm_diag_verify_remote_receipt(args[[1L]])
}
