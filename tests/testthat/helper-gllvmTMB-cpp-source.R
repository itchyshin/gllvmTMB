## Package-root resolver for source scans (#1758, #1770).
##
## R CMD check runs tests from <pkg>.Rcheck/tests/testthat. The tarball
## sources sit in <pkg>.Rcheck/00_pkg_src/<pkg>/, two levels up from
## testthat. A second, one-level-deeper layout (installed package under
## .Rcheck, or some covr trees) needs three levels. A source checkout
## is tests/testthat -> ../.. . The first existing candidate wins.
## A missing file is an error. Do not skip: a skip under R CMD check
## hides the scan from CI.

.gllvmTMB_installed_file <- function(...) {
  if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
    return("")
  }
  out <- tryCatch(
    system.file(..., package = "gllvmTMB"),
    error = function(e) ""
  )
  if (!is.character(out) || length(out) != 1L || !nzchar(out)) {
    return("")
  }
  ## Installed R/ and man/ are not the package sources. Keep a system.file()
  ## hit only when it is a file (for example src/*.cpp with
  ## R_KEEP_PKG_SOURCE=yes).
  if (dir.exists(out)) {
    return("")
  }
  out
}

gllvmTMB_pkg_rel_roots <- function() {
  list(
    c("..", ".."),
    c("..", "..", "00_pkg_src", "gllvmTMB"),
    c("..", "..", "..", "00_pkg_src", "gllvmTMB")
  )
}

gllvmTMB_pkg_file_candidates <- function(...) {
  rel <- do.call(file.path, list(...))
  from_test <- vapply(
    gllvmTMB_pkg_rel_roots(),
    function(segs) {
      do.call(testthat::test_path, c(as.list(segs), list(...)))
    },
    character(1)
  )
  installed <- .gllvmTMB_installed_file(rel)
  ## #1758 looked beside the library as well as inside it.
  installed_parent <- .gllvmTMB_installed_file("..", rel)
  extras <- c(
    if (nzchar(installed)) installed,
    if (nzchar(installed_parent)) installed_parent,
    file.path(rel),
    file.path("..", rel),
    file.path("..", "..", rel)
  )
  unique(c(from_test, extras[nzchar(extras)]))
}

gllvmTMB_pkg_resolve <- function(candidates, what) {
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    stop(what, " is not available in this test context.", call. = FALSE)
  }
  found[[1L]]
}

gllvmTMB_pkg_file <- function(...) {
  rel <- do.call(file.path, list(...))
  gllvmTMB_pkg_resolve(
    gllvmTMB_pkg_file_candidates(...),
    paste0("Package file ", rel)
  )
}

## Same roots as gllvmTMB_pkg_file(), evaluated from an explicit testthat
## directory. The #1770 guard plants a *.Rcheck tree and calls this.
gllvmTMB_pkg_file_from <- function(testthat_dir, ...) {
  rel <- do.call(file.path, list(...))
  candidates <- vapply(
    gllvmTMB_pkg_rel_roots(),
    function(segs) {
      do.call(file.path, c(list(testthat_dir), as.list(segs), list(rel)))
    },
    character(1)
  )
  gllvmTMB_pkg_resolve(candidates, paste0("Package file ", rel))
}

gllvmTMB_cpp_source_candidates <- function() {
  historical <- .gllvmTMB_installed_file("..", "src", "gllvmTMB.cpp")
  unique(c(
    if (nzchar(historical)) historical,
    gllvmTMB_pkg_file_candidates("src", "gllvmTMB.cpp")
  ))
}

gllvmTMB_cpp_source_path <- function() {
  gllvmTMB_pkg_resolve(
    gllvmTMB_cpp_source_candidates(),
    "gllvmTMB.cpp source file"
  )
}

gllvmTMB_cpp_source_text <- function() {
  paste(readLines(gllvmTMB_cpp_source_path(), warn = FALSE), collapse = "\n")
}
