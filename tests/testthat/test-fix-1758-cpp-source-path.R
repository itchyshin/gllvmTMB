## Regression guard for #1758: R CMD check places sources at
## ../../00_pkg_src/gllvmTMB/src/ (two levels up from testthat). The pre-fix
## candidate list used only the three-level 00_pkg_src path and ../../src,
## so the ad-safe-clamps scan skipped silently under check.

test_that("gllvmTMB.cpp resolver lists two-level 00_pkg_src (#1758)", {
  candidates <- gllvmTMB_cpp_source_candidates()
  two_level <- testthat::test_path(
    "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
  )
  expect_true(two_level %in% candidates)
})

test_that("gllvmTMB.cpp resolver does not miss the R CMD check tree (#1758)", {
  legacy_only <- c(
    testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    )
  )
  check_two <- testthat::test_path(
    "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
  )
  dev_two <- testthat::test_path("..", "..", "src", "gllvmTMB.cpp")
  if (file.exists(check_two) && !file.exists(dev_two)) {
    expect_length(legacy_only[file.exists(legacy_only)], 0L)
    expect_true(file.exists(gllvmTMB_cpp_source_path()))
  } else {
    expect_true(file.exists(gllvmTMB_cpp_source_path()))
  }
})
