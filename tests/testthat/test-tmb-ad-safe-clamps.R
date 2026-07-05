test_that("TMB likelihood probability clamps avoid AD-driven ternary branches", {
  cpp_path <- testthat::test_path("..", "..", "src", "gllvmTMB.cpp")
  if (!file.exists(cpp_path)) {
    cpp_path <- file.path("src", "gllvmTMB.cpp")
  }
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
