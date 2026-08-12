#!/usr/bin/env Rscript
# Build a source archive, install it into an isolated library, and run exactly
# one AA-03 smoke attempt. This is deliberately separate from frozen v4: v4
# rejects caller-selected cells so its held-cell accounting cannot be bypassed.

args <- commandArgs(trailingOnly = TRUE)
value <- function(flag) {
  hit <- match(flag, args)
  if (is.na(hit) || hit == length(args)) {
    stop("Required: ", flag, " VALUE", call. = FALSE)
  }
  args[[hit + 1L]]
}
if (length(args) != 2L || !identical(args[[1L]], "--output")) {
  stop("Usage: launch-smoke.R --output DIRECTORY", call. = FALSE)
}

script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                            value = TRUE)[1L])
script_arg <- gsub("~+~", " ", script_arg, fixed = TRUE)
repo <- normalizePath(file.path(dirname(normalizePath(script_arg, mustWork = TRUE)),
                                "../../.."), mustWork = TRUE)
output <- normalizePath(value("--output"), mustWork = FALSE)
if (file.exists(output) || startsWith(output, paste0(repo, .Platform$file.sep))) {
  stop("AA-03 smoke output must be a new directory outside the repository.",
       call. = FALSE)
}
dir.create(output, recursive = TRUE)
archive_dir <- file.path(output, "source")
source_dir <- file.path(output, "extracted")
library_dir <- file.path(output, "library")
dir.create(archive_dir)
dir.create(source_dir)
dir.create(library_dir)

old_wd <- setwd(archive_dir)
on.exit(setwd(old_wd), add = TRUE)
status <- system2("R", c("CMD", "build", "--no-build-vignettes", "--no-manual",
                          shQuote(repo)), stdout = TRUE, stderr = TRUE)
archives <- list.files(archive_dir, pattern = "^gllvmTMB_[0-9][^/]*\\.tar\\.gz$",
                       full.names = TRUE)
if (!identical(attr(status, "status"), NULL) || length(archives) != 1L) {
  stop("AA-03 smoke could not build its source archive.", call. = FALSE)
}
archive <- normalizePath(archives[[1L]], mustWork = TRUE)
hash_command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else
  if (nzchar(Sys.which("shasum"))) "shasum" else ""
if (!nzchar(hash_command)) stop("No SHA-256 command is available.", call. = FALSE)
hash_args <- if (identical(hash_command, "shasum")) c("-a", "256", shQuote(archive)) else shQuote(archive)
hash_line <- system2(hash_command, hash_args, stdout = TRUE, stderr = TRUE)
archive_sha <- substr(hash_line[[1L]], 1L, 64L)
if (!grepl("^[0-9a-f]{64}$", archive_sha)) {
  stop("AA-03 smoke could not hash its source archive.", call. = FALSE)
}

status <- system2("tar", c("-xf", shQuote(archive), "-C", shQuote(source_dir)))
source_root <- normalizePath(file.path(source_dir, "gllvmTMB"), mustWork = TRUE)
status <- system2("R", c("CMD", "INSTALL", "--library", shQuote(library_dir),
                          shQuote(source_root)), stdout = TRUE, stderr = TRUE)
if (!identical(attr(status, "status"), NULL)) {
  stop("AA-03 smoke could not install its source archive.", call. = FALSE)
}

runner <- file.path(source_root, "inst", "sim", "cran07-aa03", "run-smoke.R")
status <- system2("Rscript", c("--vanilla", shQuote(runner),
                                "--output", shQuote(output),
                                "--source-archive", shQuote(archive),
                                "--source-archive-sha", archive_sha,
                                "--library", shQuote(library_dir)),
                  stdout = TRUE, stderr = TRUE)
writeLines(status, file.path(output, "launcher.log"))
if (!identical(attr(status, "status"), NULL)) {
  stop("AA-03 smoke runner failed; see launcher.log.", call. = FALSE)
}
cat("aa03_smoke=PASS\n")
cat("source_archive_sha256=", archive_sha, "\n", sep = "")
