#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
site_dir <- if (length(args)) args[[1L]] else "pkgdown-site"
site_dir <- normalizePath(site_dir, mustWork = TRUE)

private_stems <- c("AGENTS", "CLAUDE", "CONTRIBUTING", "ROADMAP")
private_pages <- paste0(private_stems, ".html")
leaked_pages <- private_pages[file.exists(file.path(site_dir, private_pages))]
if (length(leaked_pages)) {
  stop(
    "Private root pages were generated: ",
    paste(leaked_pages, collapse = ", "),
    call. = FALSE
  )
}

required_pages <- c(
  "index.html",
  file.path("articles", "gllvmTMB.html"),
  file.path("articles", "current-limits.html")
)
missing_pages <- required_pages[!file.exists(file.path(site_dir, required_pages))]
if (length(missing_pages)) {
  stop(
    "Expected reader pages are missing: ",
    paste(missing_pages, collapse = ", "),
    call. = FALSE
  )
}

required_indexes <- c("search.json", "sitemap.xml", "llms.txt")
missing_indexes <- required_indexes[
  !file.exists(file.path(site_dir, required_indexes))
]
if (length(missing_indexes)) {
  stop(
    "Expected site indexes are missing: ",
    paste(missing_indexes, collapse = ", "),
    call. = FALSE
  )
}

html_files <- list.files(
  site_dir,
  pattern = "[.]html$",
  recursive = TRUE,
  full.names = TRUE
)
files_to_scan <- c(html_files, file.path(site_dir, required_indexes))
private_target <- paste0("(?i)(?:^|[/\"'])", paste(private_pages, collapse = "|"))

leaks <- vapply(files_to_scan, function(path) {
  any(grepl(private_target, readLines(path, warn = FALSE), perl = TRUE))
}, logical(1))
if (any(leaks)) {
  stop(
    "Private page links leaked into generated site files: ",
    paste(sub(paste0("^", site_dir, "/"), "", files_to_scan[leaks]), collapse = ", "),
    call. = FALSE
  )
}

cat("PKGDOWN PUBLIC SURFACE PASS\n")
