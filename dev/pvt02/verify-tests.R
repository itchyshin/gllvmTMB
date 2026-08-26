script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script_path), "..", ".."))
results <- testthat::test_file(
  file.path(root, "tests", "testthat", "test-pvt02-contract.R"),
  reporter = "summary"
)
failed <- vapply(results, function(x) {
  inherits(x, "expectation_failure") || inherits(x, "expectation_error")
}, logical(1))
if (any(failed)) {
  stop("PVT-02 focused testthat failure")
}
cat("PVT02_TESTS_PASS\n")
