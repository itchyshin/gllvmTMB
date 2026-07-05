test_that("TMB likelihood probability clamps avoid AD-driven ternary branches", {
  cpp_candidates <- c(
    testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    file.path("src", "gllvmTMB.cpp"),
    file.path("..", "src", "gllvmTMB.cpp"),
    file.path("..", "..", "src", "gllvmTMB.cpp")
  )
  cpp_path <- cpp_candidates[file.exists(cpp_candidates)][1L]
  testthat::skip_if(
    is.na(cpp_path),
    "gllvmTMB.cpp source file is not available in this installed-package test context."
  )
  cpp <- paste(readLines(cpp_path, warn = FALSE), collapse = "\n")

  expect_match(cpp, "Type gll_clamp\\(Type x, Type lower, Type upper\\)")
  expect_match(cpp, "p = gll_clamp\\(p, tiny, Type\\(1\\.0\\) - tiny\\);")
  expect_match(
    cpp,
    "y_safe = gll_clamp\\(y_safe, tiny_y, Type\\(1\\.0\\) - tiny_y\\);"
  )
  expect_match(cpp, "p_k = CppAD::CondExpLt\\(p_k, tiny_p, tiny_p, p_k\\);")

  expect_no_match(cpp, "p = \\(p < tiny\\)")
  expect_no_match(cpp, "y_safe = \\(y_safe < tiny_y\\)")
  expect_no_match(cpp, "p_k = \\(p_k < tiny_p\\)")
})
