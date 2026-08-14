test_that("private MSPL uncertainty runner retains the Hessian-only campaign fence", {
  runner <- paste(
    readLines(test_path("..", "..", "inst", "sim", "lane-b-uncertainty",
                        "run-mspl-uncertainty.R")),
    collapse = "\n"
  )

  expect_match(runner, 'c\\("both", "hessian_only"\\)')
  expect_match(runner, 'profile_lower_status = "not_run"')
  expect_match(runner, "file.rename\\(tmp, out\\)")
  expect_match(runner, "Receipt set does not exactly match the frozen manifest")
  expect_match(runner, "not_run_fit_error")
})
