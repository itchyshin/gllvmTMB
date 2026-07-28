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
  ## The ordinal guard moved to the LOG scale (2026-07-28, AGHQ slice E1). The old
  ## `p_k >= 1e-12` probability floor was harmless under Laplace but BOUND at
  ## quadrature nodes once s_cond * |lambda| exceeded 1.56 at k = 9, flooring the
  ## tail instead of letting it decay. It is now a log-scale guard at log(1e-300),
  ## which cannot bind in any reachable regime. This assertion's INTENT is
  ## unchanged and is exactly what it still tests: the clamp must be an AD-safe
  ## CondExpLt, never a plain C++ ternary or comparison.
  expect_match(
    cpp,
    "logp_k = CppAD::CondExpLt\\(logp_k, log_tiny_ord, log_tiny_ord, logp_k\\);"
  )

  expect_no_match(cpp, "p = \\(p < tiny\\)")
  expect_no_match(cpp, "y_safe = \\(y_safe < tiny_y\\)")
  expect_no_match(cpp, "p_k = \\(p_k < tiny_p\\)")
})
