fail <- function(...) stop(sprintf(...), call. = FALSE)
assert <- function(ok, ...) if (!isTRUE(ok)) fail(...)
read_all <- function(paths) paste(vapply(paths, function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}, character(1L)), collapse = "\n")
run_tests <- function(filter) {
  devtools::test(filter = filter, stop_on_failure = TRUE)
  invisible(TRUE)
}
