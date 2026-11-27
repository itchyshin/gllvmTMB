## Regression for #2002: select_lv(fit) must not surface a raw missing d_max error.

test_that("select_lv() refuses a gllvmTMB fit with the formula/data/d_max workflow (#2002)", {
  fit <- structure(list(), class = c("gllvmTMB_multi", "gllvmTMB"))
  expect_error(
    select_lv(fit),
    class = "gllvmTMB_select_lv_bad_args",
    regexp = "not an S3 method.+d_max"
  )
})