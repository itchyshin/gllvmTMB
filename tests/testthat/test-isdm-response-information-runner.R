runner_path <- testthat::test_path("..", "..", "dev", "isdm-requalification",
                                   "response-information", "runner.R")
if (!file.exists(runner_path)) {
  test_that("response-information runner is available", { skip("developer-only runner is absent") })
} else {
  test_that("runner loads gllvmTMB before resolving its DLL", {
    text <- readLines(runner_path, warn = FALSE)
    loaded <- grep("library\\(gllvmTMB\\)", text)
    dll <- grep("getLoadedDLLs", text)
    expect_length(loaded, 1L)
    expect_length(dll, 1L)
    expect_lt(loaded, dll)
  })

  test_that("runner retains raw values needed by the independent scorer", {
    text <- paste(readLines(runner_path, warn = FALSE), collapse = "\n")
    expect_match(text, "baseline_data_sha256", fixed = TRUE)
    expect_match(text, "fixed_truth", fixed = TRUE)
    expect_match(text, "trait = trait", fixed = TRUE)
    expect_match(text, "runtime-identity-v1", fixed = TRUE)
  })
}
