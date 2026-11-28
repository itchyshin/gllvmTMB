test_that("extract_call_name() respects max_width including ellipsis (#1893)", {
  long <- paste(rep("a", 50L), collapse = "")
  out <- extract_call_name(long, max_width = 20L)
  expect_identical(nchar(out), 20L)
  expect_match(out, "\\.\\.\\.$")

  short <- extract_call_name("ab", max_width = 20L)
  expect_identical(short, "ab")

  call <- quote(latent(1 + very_long_coefficient_name | unit))
  out_call <- extract_call_name(call, max_width = 12L)
  expect_lte(nchar(out_call), 12L)
})