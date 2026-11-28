test_that("safe_deparse() collapses language to one string", {
  x <- quote(latent(0 + trait | site, d = 2))
  out <- gllvmTMB:::safe_deparse(x)
  expect_type(out, "character")
  expect_length(out, 1L)
  expect_match(out, "latent")
})

test_that("extract_call_name() truncates overlong call text", {
  long_call <- call("foo", rep(letters, 50))
  out <- gllvmTMB:::extract_call_name(long_call, max_width = 20L)
  expect_lte(nchar(out), 22L)
  expect_true(grepl("\\.\\.\\.$", out))
})

test_that("extract_call_name() accepts bare symbols", {
  expect_equal(gllvmTMB:::extract_call_name(quote(trait)), "trait")
})

test_that("ggplot2_installed() is a logical scalar", {
  out <- gllvmTMB:::ggplot2_installed()
  expect_type(out, "logical")
  expect_length(out, 1L)
  expect_false(is.na(out))
  expect_identical(out, requireNamespace("ggplot2", quietly = TRUE))
})