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
}
