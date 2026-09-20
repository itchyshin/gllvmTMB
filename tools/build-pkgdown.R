#!/usr/bin/env Rscript

# Build the public site from a disposable copy of the package source. pkgdown
# 2.2.0 turns every root Markdown file into a public page, including project
# instructions that belong in the repository but not on the reader site.

source_dir <- normalizePath(".", mustWork = TRUE)
required <- file.path(source_dir, c("DESCRIPTION", "_pkgdown.yml"))
if (!all(file.exists(required))) {
  stop("Run this script from the gllvmTMB repository root.", call. = FALSE)
}

private_root_files <- c(
  "AGENTS.md",
  "CLAUDE.md",
  "CONTRIBUTING.md",
  "ROADMAP.md"
)

stage_parent <- tempfile("gllvmtmb-pkgdown-")
stage_dir <- file.path(stage_parent, "gllvmTMB")
dir.create(stage_dir, recursive = TRUE)
on.exit(unlink(stage_parent, recursive = TRUE, force = TRUE), add = TRUE)

entries <- list.files(
  source_dir,
  all.files = TRUE,
  no.. = TRUE,
  full.names = TRUE
)
excluded_entries <- c(private_root_files, ".git", ".Rproj.user", "pkgdown-site")
entries <- entries[!basename(entries) %in% excluded_entries]

copied <- file.copy(
  entries,
  stage_dir,
  recursive = TRUE,
  copy.mode = TRUE,
  copy.date = TRUE
)
if (!all(copied)) {
  stop(
    "Could not create the temporary source copy for the pkgdown build.",
    call. = FALSE
  )
}

if (any(file.exists(file.path(stage_dir, private_root_files)))) {
  stop("A private root Markdown file leaked into the staged source.", call. = FALSE)
}

site_dir <- file.path(source_dir, "pkgdown-site")
if (dir.exists(site_dir)) {
  unlink(site_dir, recursive = TRUE, force = TRUE)
}
pkgdown::build_site(
  pkg = stage_dir,
  override = list(destination = site_dir),
  # The staged copy is intentionally built in pkgdown's normal isolated
  # process.  This avoids inheriting the caller's session and renders the
  # complete site, including reference pages and articles.
  devel = FALSE,
  new_process = TRUE,
  install = TRUE,
  quiet = FALSE
)
