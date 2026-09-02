result <- devtools::test(filter = "isdm-response-information", stop_on_failure = TRUE)
if (any(vapply(result, function(x) !is.null(x$failed) && x$failed > 0L, logical(1L)))) {
  stop("response-information tests failed")
}
cat("response information tests passed\n")
