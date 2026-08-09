#!/usr/bin/env Rscript
# Build the exact v4 source payload. The canonical binding receipt and its
# SHA ledger are a detached launch envelope and are deliberately not embedded.

args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit)) default else {
    if (hit == length(args)) stop(flag, " requires a value.", call. = FALSE)
    args[[hit + 1L]]
  }
}

output <- value("--output")
manifest_output <- value("--manifest-output")
if (is.null(output) || is.null(manifest_output)) {
  stop("Required: --output ARCHIVE --manifest-output CSV", call. = FALSE)
}
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_arg <- gsub("~+~", " ", script_arg, fixed = TRUE)
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
output_dir <- normalizePath(dirname(output), mustWork = TRUE)
output_abs <- file.path(output_dir, basename(output))
manifest_output_dir <- normalizePath(dirname(manifest_output), mustWork = TRUE)
manifest_output_abs <- file.path(manifest_output_dir, basename(manifest_output))
if (file.exists(output_abs)) stop("Refusing to overwrite source archive: ", output_abs,
                                  call. = FALSE)
if (file.exists(manifest_output_abs)) {
  stop("Refusing to overwrite payload manifest: ", manifest_output_abs,
       call. = FALSE)
}
if (startsWith(output_abs, paste0(repo, .Platform$file.sep)) ||
    startsWith(manifest_output_abs, paste0(repo, .Platform$file.sep))) {
  stop("V4 source archives and generated manifests must be written outside the repository.",
       call. = FALSE)
}

detached <- c(
  "docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/source-archive-binding.csv",
  "docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/source-payload-manifest.csv",
  "inst/sim/cran07-v4/launch-bound-source.R",
  "docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/SHA256SUMS")
required_detached <- setdiff(detached,
  "docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/source-payload-manifest.csv")
old_collate <- Sys.getlocale("LC_COLLATE")
on.exit(suppressWarnings(Sys.setlocale("LC_COLLATE", old_collate)), add = TRUE)
if (is.na(suppressWarnings(Sys.setlocale("LC_COLLATE", "C")))) {
  stop("Could not fix LC_COLLATE=C for canonical payload ordering.", call. = FALSE)
}
paths <- system2("git", c("-C", shQuote(repo), "ls-files", "-co",
                           "--exclude-standard"), stdout = TRUE)
paths <- sort(unique(enc2utf8(paths)))
has_parent_component <- vapply(strsplit(paths, "/", fixed = TRUE),
                               function(x) any(x == ".."), logical(1L))
has_line_break <- vapply(paths, function(x)
  any(charToRaw(x) %in% as.raw(c(10L, 13L))), logical(1L))
if (!length(paths)) stop("Git payload inventory is empty.", call. = FALSE)
if (anyNA(paths) || any(!nzchar(paths)) || any(has_line_break)) {
  stop("Git payload inventory contains an empty or control-character path.",
       call. = FALSE)
}
if (any(startsWith(paths, "/")) || any(has_parent_component)) {
  stop("Git payload inventory contains an absolute or parent-relative path.",
       call. = FALSE)
}
missing_envelope <- setdiff(required_detached, paths)
if (length(missing_envelope)) {
  stop("Git payload inventory lacks detached envelope file(s): ",
       paste(missing_envelope, collapse = ", "), call. = FALSE)
}
payload <- setdiff(paths, detached)
source_paths <- file.path(repo, payload)
if (any(!file.exists(source_paths)) || any(dir.exists(source_paths)) ||
    any(nzchar(Sys.readlink(source_paths)))) {
  stop("V4 payload must contain existing regular files and no symbolic links.",
       call. = FALSE)
}

stage <- tempfile("cran07-v4-source-")
stage_root <- file.path(stage, "gllvmTMB")
dir.create(stage_root, recursive = TRUE)
on.exit(unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
for (i in seq_along(payload)) {
  destination <- file.path(stage_root, payload[[i]])
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source_paths[[i]], destination, copy.mode = FALSE,
                 copy.date = FALSE)) {
    stop("Could not stage source payload file: ", payload[[i]], call. = FALSE)
  }
  Sys.chmod(destination,
            if (file.access(source_paths[[i]], mode = 1L) == 0L) "0755" else "0644")
}
fixed_time <- as.POSIXct("2026-08-08 00:00:00", tz = "UTC")
staged_files <- file.path(stage_root, payload)
Sys.setFileTime(staged_files, fixed_time)

hash_files <- function(files) {
  command <- if (nzchar(Sys.which("shasum"))) "shasum" else
    if (nzchar(Sys.which("sha256sum"))) "sha256sum" else ""
  if (!nzchar(command)) stop("No SHA-256 command is available.", call. = FALSE)
  prefix <- if (identical(command, "shasum")) c("-a", "256") else character()
  ans <- system2(command, c(prefix, shQuote(files)), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(ans, "status")) || length(ans) != length(files)) {
    stop("Could not hash every staged payload file.", call. = FALSE)
  }
  hashes <- substr(ans, 1L, 64L)
  if (any(!grepl("^[0-9a-f]{64}$", hashes))) {
    stop("Could not parse every staged payload SHA-256.", call. = FALSE)
  }
  unname(hashes)
}
staged_info <- file.info(staged_files)
payload_manifest <- data.frame(
  path = payload,
  type = "file",
  mode = sprintf("%04o", as.integer(staged_info$mode)),
  bytes = as.numeric(staged_info$size),
  sha256 = hash_files(staged_files),
  stringsAsFactors = FALSE)
utils::write.csv(payload_manifest, manifest_output_abs, row.names = FALSE,
                 quote = TRUE, na = "")

member_file <- tempfile("cran07-v4-members-", fileext = ".txt")
on.exit(unlink(member_file, force = TRUE), add = TRUE)
members <- file.path("gllvmTMB", payload)
writeLines(members, member_file, useBytes = TRUE)
tar_args <- c("-cf", shQuote(output_abs), "--format", "ustar", "--uid", "0",
              "--gid", "0", "--uname", "root", "--gname", "root",
              "--no-xattrs", "-C", shQuote(stage), "-T", shQuote(member_file))
tar_version <- system2("tar", "--version", stdout = TRUE, stderr = TRUE)
if (!length(tar_version) ||
    !grepl("^bsdtar 3\\.5\\.3 ", tar_version[[1L]])) {
  stop("Frozen v4 archive creation requires bsdtar 3.5.3.", call. = FALSE)
}
status <- system2("tar", tar_args, env = "COPYFILE_DISABLE=1")
if (!identical(status, 0L) || !file.exists(output_abs) ||
    file.info(output_abs)$size <= 0) {
  stop("Metadata-controlled source archive creation failed.", call. = FALSE)
}
observed <- utils::untar(output_abs, list = TRUE)
if (!identical(observed, members) || any(file.path("gllvmTMB", detached) %in% observed)) {
  stop("Source archive member inventory differs from the sorted payload.",
       call. = FALSE)
}

hash_command <- if (nzchar(Sys.which("shasum"))) "shasum" else "sha256sum"
hash_args <- if (identical(hash_command, "shasum"))
  c("-a", "256", shQuote(output_abs)) else shQuote(output_abs)
hash_line <- system2(hash_command, hash_args, stdout = TRUE)
sha256 <- strsplit(hash_line[[1L]], "[[:space:]]+")[[1L]][[1L]]
if (!grepl("^[0-9a-f]{64}$", sha256)) stop("Could not derive archive SHA-256.",
                                             call. = FALSE)
manifest_hash_line <- system2(hash_command,
  if (identical(hash_command, "shasum"))
    c("-a", "256", shQuote(manifest_output_abs)) else shQuote(manifest_output_abs),
  stdout = TRUE)
manifest_sha256 <- strsplit(manifest_hash_line[[1L]],
                            "[[:space:]]+")[[1L]][[1L]]
if (!grepl("^[0-9a-f]{64}$", manifest_sha256)) {
  stop("Could not derive payload-manifest SHA-256.", call. = FALSE)
}
cat("source_archive_path=", output_abs, "\n", sep = "")
cat("source_archive_sha256=", sha256, "\n", sep = "")
cat("source_archive_payload_files=", length(payload), "\n", sep = "")
cat("source_payload_manifest_path=", manifest_output_abs, "\n", sep = "")
cat("source_payload_manifest_sha256=", manifest_sha256, "\n", sep = "")
cat("detached_envelope_files=", paste(detached, collapse = ","), "\n", sep = "")
