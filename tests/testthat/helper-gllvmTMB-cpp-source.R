## Resolve src/gllvmTMB.cpp under dev tree, R CMD check (00_pkg_src), and
## system.file() layouts. Candidate 2 is the checked build, where sources sit
## in <pkg>.Rcheck/00_pkg_src/ -- TWO levels up from tests/testthat (#1758).

gllvmTMB_cpp_source_candidates <- function() {
  installed <- system.file("..", "src", "gllvmTMB.cpp", package = "gllvmTMB")
  candidates <- c(
    if (nzchar(installed)) installed,
    testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    testthat::test_path(
      "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    file.path("src", "gllvmTMB.cpp"),
    file.path("..", "src", "gllvmTMB.cpp"),
    file.path("..", "..", "src", "gllvmTMB.cpp")
  )
  unique(candidates[nzchar(candidates)])
}

gllvmTMB_cpp_source_path <- function() {
  candidates <- gllvmTMB_cpp_source_candidates()
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    stop(
      "gllvmTMB.cpp source file is not available in this test context.",
      call. = FALSE
    )
  }
  found[[1L]]
}

gllvmTMB_cpp_source_text <- function() {
  paste(readLines(gllvmTMB_cpp_source_path(), warn = FALSE), collapse = "\n")
}
