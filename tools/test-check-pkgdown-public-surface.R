#!/usr/bin/env Rscript

checker <- normalizePath("tools/check-pkgdown-public-surface.R", mustWork = TRUE)

make_site <- function() {
  root <- tempfile("pkgdown-public-surface-")
  dir.create(file.path(root, "articles"), recursive = TRUE)
  writeLines("<html><body><h1>Home</h1></body></html>", file.path(root, "index.html"))
  writeLines("<html><body><h1>Guide</h1></body></html>", file.path(root, "articles", "gllvmTMB.html"))
  writeLines("<html><body><h1>Limits</h1></body></html>", file.path(root, "articles", "current-limits.html"))
  writeLines("{}", file.path(root, "search.json"))
  writeLines("<urlset/>", file.path(root, "sitemap.xml"))
  writeLines("# Site", file.path(root, "llms.txt"))
  root
}

run_checker <- function(site) {
  suppressWarnings(system2("Rscript", c(checker, site), stdout = TRUE, stderr = TRUE))
}

site <- make_site()
on.exit(unlink(site, recursive = TRUE, force = TRUE), add = TRUE)
status <- attr(run_checker(site), "status")
stopifnot(is.null(status) || status == 0L)

writeLines(
  "<html><body><p>This implementation lane closes PR #456.</p></body></html>",
  file.path(site, "articles", "gllvmTMB.html")
)
status <- attr(run_checker(site), "status")
stopifnot(!is.null(status) && status != 0L)

cat("PKGDOWN PUBLIC SURFACE TEST PASS\n")
