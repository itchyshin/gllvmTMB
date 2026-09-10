#!/usr/bin/env Rscript
# Detached v4 launcher: verify the bound payload, extract it freshly, build and
# install into an isolated library, then invoke the in-payload runner.

args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit)) default else {
    if (hit == length(args)) stop(flag, " requires a value.", call. = FALSE)
    args[[hit + 1L]]
  }
}
if (any(c("--source-archive", "--source-receipt", "--expected-sha",
          "--source-archive-sha", "--load-all") %in% args)) {
  stop("The detached v4 launcher does not accept caller-selected source identity.",
       call. = FALSE)
}

launcher_command_token <- grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]
script_arg <- sub("^--file=", "", launcher_command_token)
script_arg <- gsub("~+~", " ", script_arg, fixed = TRUE)
launcher <- normalizePath(script_arg, mustWork = TRUE)
control_repo <- normalizePath(file.path(dirname(launcher), "../../.."),
                              mustWork = TRUE)
receipt_rel <- "docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/source-archive-binding.csv"
manifest_rel <- "docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/source-payload-manifest.csv"
sha_rel <- "docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/SHA256SUMS"
launcher_rel <- "inst/sim/cran07-v4/launch-bound-source.R"
envelope_rel <- c(receipt_rel, manifest_rel, sha_rel, launcher_rel)
binding_fields <- c(
  "receipt_id", "status", "source_archive_file", "source_archive_path",
  "sha256", "source_payload_manifest_file",
  "source_payload_manifest_sha256", "source_payload_member_count",
  "sha_ledger_file", "sha_ledger_sha256",
  "launcher_file", "launcher_sha256", "launch_authorized")
manifest_fields <- c("path", "type", "mode", "bytes", "sha256")
authority_id <- "cran07-v4-simulation-authority-v1"
authority_paths <- c(
  "/private/tmp/gllvmtmb-cran07-v4-authority/launch-authority.csv",
  "/home/snakagaw/hsq_work/gllvmtmb-cran07-v4-20260808/authority/launch-authority.csv"
)
authority_fields <- c(
  "authority_id", "status", "scope", "receipt_id",
  "source_archive_file", "source_archive_sha256",
  "source_payload_manifest_file", "source_payload_manifest_sha256",
  "sha_ledger_file", "sha_ledger_sha256",
  "launcher_file", "launcher_sha256",
  "simulation_authorized", "release_authorized",
  "version_change_authorized", "publication_authorized",
  "cran_submission_authorized")

sha256_file <- function(path) {
  path <- normalizePath(path, mustWork = TRUE)
  if (nzchar(Sys.which("sha256sum"))) {
    ans <- system2("sha256sum", shQuote(path), stdout = TRUE, stderr = TRUE)
  } else if (nzchar(Sys.which("shasum"))) {
    ans <- system2("shasum", c("-a", "256", shQuote(path)),
                   stdout = TRUE, stderr = TRUE)
  } else stop("No SHA-256 command is available.", call. = FALSE)
  hash <- substr(ans[[1L]], 1L, 64L)
  if (!grepl("^[0-9a-f]{64}$", hash)) stop("Could not hash ", path,
                                             call. = FALSE)
  hash
}
sha256_files <- function(paths) {
  paths <- normalizePath(paths, mustWork = TRUE)
  command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else
    if (nzchar(Sys.which("shasum"))) "shasum" else ""
  if (!nzchar(command)) stop("No SHA-256 command is available.", call. = FALSE)
  prefix <- if (identical(command, "shasum")) c("-a", "256") else character()
  chunks <- split(seq_along(paths), ceiling(seq_along(paths) / 100L))
  answers <- lapply(chunks, function(index) {
    ans <- system2(command, c(prefix, shQuote(paths[index])),
                   stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(ans, "status")) || length(ans) != length(index)) {
      stop("Could not hash a complete extracted-payload batch.", call. = FALSE)
    }
    ans
  })
  ans <- unlist(answers, use.names = FALSE)
  hashes <- substr(ans, 1L, 64L)
  if (length(hashes) != length(paths) ||
      any(!grepl("^[0-9a-f]{64}$", hashes))) {
    stop("Could not hash the complete extracted payload.", call. = FALSE)
  }
  unname(hashes)
}
read_authority <- function() {
  links <- Sys.readlink(authority_paths)
  present <- authority_paths[
    file.exists(authority_paths) | (!is.na(links) & nzchar(links))]
  if (length(present) != 1L) {
    stop("Exactly one fixed external v4 campaign-authority record must exist.",
         call. = FALSE)
  }
  if (nzchar(Sys.readlink(present))) {
    stop("External v4 campaign authority cannot be a symbolic link.",
         call. = FALSE)
  }
  parent <- dirname(present)
  parent_info <- file.info(parent)
  parent_mode <- sprintf("%04o", as.integer(parent_info$mode))
  if (!dir.exists(parent) || nzchar(Sys.readlink(parent)) ||
      !identical(parent_mode, "0555")) {
    stop("External v4 campaign-authority directory must be a fixed non-symlink 0555 directory.",
         call. = FALSE)
  }
  info <- file.info(present)
  if (!file_test("-f", present) || is.na(info$size) || info$isdir ||
      info$size <= 0 ||
      !identical(sprintf("%04o", as.integer(info$mode)), "0444")) {
    stop("External v4 campaign authority must be one nonempty, read-only regular file.",
         call. = FALSE)
  }
  path <- normalizePath(present, mustWork = TRUE)
  authority <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (nrow(authority) != 1L || !identical(names(authority), authority_fields) ||
      anyNA(authority) ||
      !identical(authority$authority_id[[1L]], authority_id) ||
      !identical(authority$status[[1L]], "AUTHORIZED") ||
      !identical(authority$scope[[1L]], "simulation_execution_only") ||
      !identical(authority$receipt_id[[1L]],
                 "cran07-v4-source-archive-binding-v1") ||
      any(!grepl("^[0-9a-f]{64}$", unlist(authority[c(
        "source_archive_sha256", "source_payload_manifest_sha256",
        "sha_ledger_sha256", "launcher_sha256")], use.names = FALSE))) ||
      !is.logical(authority$simulation_authorized) ||
      !identical(authority$simulation_authorized[[1L]], TRUE) ||
      !is.logical(authority$release_authorized) ||
      !identical(authority$release_authorized[[1L]], FALSE) ||
      !is.logical(authority$version_change_authorized) ||
      !identical(authority$version_change_authorized[[1L]], FALSE) ||
      !is.logical(authority$publication_authorized) ||
      !identical(authority$publication_authorized[[1L]], FALSE) ||
      !is.logical(authority$cran_submission_authorized) ||
      !identical(authority$cran_submission_authorized[[1L]], FALSE)) {
    stop("External v4 campaign authority is malformed or exceeds simulation-only scope.",
         call. = FALSE)
  }
  attr(authority, "path") <- path
  attr(authority, "sha256") <- sha256_file(path)
  authority
}
validate_authority <- function(authority, receipt) {
  pairs <- c(
    receipt_id = "receipt_id",
    source_archive_file = "source_archive_file",
    sha256 = "source_archive_sha256",
    source_payload_manifest_file = "source_payload_manifest_file",
    source_payload_manifest_sha256 = "source_payload_manifest_sha256",
    sha_ledger_file = "sha_ledger_file",
    sha_ledger_sha256 = "sha_ledger_sha256",
    launcher_file = "launcher_file",
    launcher_sha256 = "launcher_sha256"
  )
  matches <- vapply(names(pairs), function(receipt_name)
    identical(receipt[[receipt_name]][[1L]],
              authority[[pairs[[receipt_name]]]][[1L]]), logical(1L))
  if (!all(matches) ||
      !identical(sha256_file(launcher), authority$launcher_sha256[[1L]])) {
    stop("External v4 authority does not authenticate the bound receipt and launcher.",
         call. = FALSE)
  }
  invisible(TRUE)
}
read_manifest <- function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE,
    colClasses = c(path = "character", type = "character", mode = "character",
                   bytes = "numeric", sha256 = "character"))
  if (!nrow(x) || !identical(names(x), manifest_fields) || anyNA(x) ||
      anyDuplicated(x$path) ||
      !identical(x$path, sort(x$path, method = "radix")) ||
      any(x$type != "file") || any(!x$mode %in% c("0644", "0755")) ||
      any(!grepl("^[0-9a-f]{64}$", x$sha256)) ||
      any(startsWith(x$path, "/")) ||
      any(vapply(strsplit(x$path, "/", fixed = TRUE),
                 function(z) any(z == ".."), logical(1L)))) {
    stop("Detached payload manifest is unsafe or malformed.", call. = FALSE)
  }
  x
}
verify_tree <- function(root, manifest) {
  root <- normalizePath(root, mustWork = TRUE)
  observed <- list.files(root, recursive = TRUE, all.files = TRUE,
                         include.dirs = FALSE, no.. = TRUE)
  observed <- gsub("\\\\", "/", observed)
  observed <- sort(setdiff(observed, envelope_rel), method = "radix")
  if (!identical(observed, manifest$path)) {
    stop("Freshly extracted source inventory differs from the bound manifest.",
         call. = FALSE)
  }
  files <- file.path(root, manifest$path)
  info <- file.info(files)
  if (anyNA(info$size) || any(info$isdir) || any(nzchar(Sys.readlink(files))) ||
      !identical(as.numeric(info$size), as.numeric(manifest$bytes)) ||
      !identical(sprintf("%04o", as.integer(info$mode)), manifest$mode) ||
      !identical(sha256_files(files), manifest$sha256)) {
    stop("Freshly extracted source bytes, modes, or types differ from the binding.",
         call. = FALSE)
  }
  invisible(TRUE)
}

receipt_path <- normalizePath(file.path(control_repo, receipt_rel), mustWork = TRUE)
manifest_path <- normalizePath(file.path(control_repo, manifest_rel), mustWork = TRUE)
sha_path <- normalizePath(file.path(control_repo, sha_rel), mustWork = TRUE)
receipt <- utils::read.csv(receipt_path, stringsAsFactors = FALSE)
if (nrow(receipt) != 1L || !identical(names(receipt), binding_fields) ||
    !identical(receipt$receipt_id[[1L]], "cran07-v4-source-archive-binding-v1") ||
    !identical(receipt$status[[1L]], "READY") ||
    !is.logical(receipt$launch_authorized) ||
    !identical(receipt$launch_authorized[[1L]], TRUE) ||
    !identical(receipt$launcher_file[[1L]], basename(launcher)) ||
    !identical(receipt$launcher_sha256[[1L]], sha256_file(launcher)) ||
    !identical(receipt$source_payload_manifest_file[[1L]], basename(manifest_path)) ||
    !identical(receipt$source_payload_manifest_sha256[[1L]],
        sha256_file(manifest_path)) ||
    !identical(receipt$sha_ledger_file[[1L]], basename(sha_path)) ||
    !identical(receipt$sha_ledger_sha256[[1L]], sha256_file(sha_path))) {
  stop("Detached v4 launch envelope is not canonical and READY.", call. = FALSE)
}
authority <- read_authority()
validate_authority(authority, receipt)
archive <- normalizePath(receipt$source_archive_path[[1L]], mustWork = TRUE)
if (!identical(basename(archive), receipt$source_archive_file[[1L]]) ||
    !identical(sha256_file(archive), receipt$sha256[[1L]])) {
  stop("Bound v4 source archive path, basename, or digest differs.", call. = FALSE)
}
manifest <- read_manifest(manifest_path)
if (!identical(nrow(manifest),
               as.integer(receipt$source_payload_member_count[[1L]]))) {
  stop("Bound payload member count differs from the detached manifest.",
       call. = FALSE)
}
members <- utils::untar(archive, list = TRUE)
expected_members <- file.path("gllvmTMB", manifest$path)
verbose <- system2("tar", c("-tvf", shQuote(archive)),
                   stdout = TRUE, stderr = TRUE)
if (!identical(members, expected_members) || anyDuplicated(members) ||
    !is.null(attr(verbose, "status")) || length(verbose) != length(members) ||
    any(substr(verbose, 1L, 1L) != "-")) {
  stop("Bound archive inventory/type differs from the exact payload manifest.",
       call. = FALSE)
}
if ("--verify-authority-only" %in% args) {
  cat("v4_external_authority=PASS\n")
  cat("authority_sha256=", attr(authority, "sha256"), "\n", sep = "")
  cat("source_archive_sha256=", receipt$sha256[[1L]], "\n", sep = "")
  quit(save = "no", status = 0L)
}

campaign <- value("--campaign")
stage <- value("--stage")
output <- value("--output")
task_manifest <- value("--manifest")
launch_root_arg <- value("--launch-root")
if (any(vapply(list(campaign, stage, output, task_manifest, launch_root_arg),
                   is.null, logical(1L)))) {
  stop("Required: --campaign ID --stage smoke|pilot|production --output DIR --manifest CSV --launch-root DIR",
       call. = FALSE)
}
if (!stage %in% c("smoke", "pilot", "production")) {
  stop("Unknown v4 stage.", call. = FALSE)
}
launch_root <- normalizePath(launch_root_arg, mustWork = FALSE)
if (file.exists(launch_root) ||
    startsWith(launch_root, paste0(control_repo, .Platform$file.sep))) {
  stop("Launch root must be a new directory outside the control repository.",
       call. = FALSE)
}
dir.create(launch_root, recursive = TRUE)
source_parent <- file.path(launch_root, "source")
dir.create(source_parent)
status <- system2("tar", c("-xf", shQuote(archive), "-C", shQuote(source_parent)))
if (!identical(status, 0L)) stop("Bound source extraction failed.", call. = FALSE)
source_root <- normalizePath(file.path(source_parent, "gllvmTMB"), mustWork = TRUE)
verify_tree(source_root, manifest)

for (rel in envelope_rel) {
  from <- file.path(control_repo, rel)
  to <- file.path(source_root, rel)
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(from, to, overwrite = FALSE, copy.mode = TRUE, copy.date = TRUE)) {
    stop("Could not install detached envelope file into fresh source: ", rel,
         call. = FALSE)
  }
}
verify_tree(source_root, manifest)

old_wd <- setwd(source_root); on.exit(setwd(old_wd), add = TRUE)
sha_status <- if (nzchar(Sys.which("sha256sum")))
  system2("sha256sum", c("-c", shQuote(sha_path))) else
  system2("shasum", c("-a", "256", "-c", shQuote(sha_path)))
setwd(old_wd)
if (!identical(sha_status, 0L)) stop("Detached v4 SHA ledger failed.", call. = FALSE)

build_dir <- file.path(launch_root, "build")
library_dir <- file.path(launch_root, "library")
dir.create(build_dir); dir.create(library_dir)
build_log <- file.path(launch_root, "R-CMD-build.log")
old_wd <- setwd(build_dir)
build_status <- system2(file.path(R.home("bin"), "R"),
  c("CMD", "build", "--no-build-vignettes", "--no-manual",
    shQuote(source_root)), stdout = build_log, stderr = build_log)
setwd(old_wd)
source_tarballs <- list.files(build_dir, pattern = "^gllvmTMB_.*\\.tar\\.gz$",
                              full.names = TRUE)
if (!identical(build_status, 0L) || length(source_tarballs) != 1L) {
  stop("Fresh bound-source R CMD build failed; see ", build_log, call. = FALSE)
}
install_log <- file.path(launch_root, "R-CMD-install.log")
install_status <- system2(file.path(R.home("bin"), "R"),
  c("CMD", "INSTALL", paste0("--library=", shQuote(library_dir)), "--preclean",
    shQuote(source_tarballs[[1L]])), stdout = install_log, stderr = install_log)
if (!identical(install_status, 0L)) {
  stop("Fresh bound-source R CMD install failed; see ", install_log, call. = FALSE)
}
verify_tree(source_root, manifest)

runner <- file.path(source_root, "inst/sim/cran07-v4/run-batch.R")
runner_args <- c("--campaign", campaign, "--stage", stage, "--output", output,
                 "--manifest", task_manifest)
pilot_gate <- value("--pilot-gate")
if (!is.null(pilot_gate)) runner_args <- c(runner_args, "--pilot-gate", pilot_gate)
runner_library_path <- paste(unique(c(library_dir, .libPaths())),
                             collapse = .Platform$path.sep)
runner_env <- c(
  paste0("R_LIBS_USER=", shQuote(runner_library_path)),
  paste0("GLLVMTMB_V4_LAUNCH_PARENT_PID=", Sys.getpid()),
  paste0("GLLVMTMB_V4_LAUNCHER_PATH=", shQuote(launcher)),
  paste0("GLLVMTMB_V4_LAUNCHER_COMMAND_TOKEN=",
         shQuote(launcher_command_token)),
  paste0("GLLVMTMB_V4_BOUND_SOURCE_SHA=", shQuote(receipt$sha256[[1L]])),
  paste0("GLLVMTMB_V4_BOUND_LIBRARY=", shQuote(library_dir)),
  paste0("GLLVMTMB_V4_LAUNCHER_SHA=", shQuote(receipt$launcher_sha256[[1L]])),
  paste0("GLLVMTMB_V4_AUTHORITY_SHA=", shQuote(attr(authority, "sha256"))))
runner_status <- system2(file.path(R.home("bin"), "Rscript"),
  c("--vanilla", shQuote(runner), shQuote(runner_args)), env = runner_env)
if (!identical(runner_status, 0L)) {
  stop("Bound v4 runner failed; see the detached-launcher output.",
       call. = FALSE)
}

launch_receipt <- data.frame(
  campaign_id = campaign, stage = stage,
  source_archive_sha256 = receipt$sha256[[1L]],
  source_payload_manifest_sha256 = receipt$source_payload_manifest_sha256[[1L]],
  external_authority_id = authority$authority_id[[1L]],
  external_authority_sha256 = attr(authority, "sha256"),
  launcher_sha256 = receipt$launcher_sha256[[1L]],
  source_root = source_root,
  isolated_library = normalizePath(library_dir, mustWork = TRUE),
  installed_package = normalizePath(file.path(library_dir, "gllvmTMB"),
                                    mustWork = TRUE),
  runner_exit_status = runner_status,
  stringsAsFactors = FALSE)
utils::write.csv(launch_receipt, file.path(launch_root, "launch-receipt.csv"),
                 row.names = FALSE)
cat("bound_source_launch=PASS\n")
cat("launch_root=", launch_root, "\n", sep = "")
cat("source_archive_sha256=", receipt$sha256[[1L]], "\n", sep = "")
