test_that("variance_lrt() validates log-likelihood inputs", {
  expect_error(
    variance_lrt(ll_full = NA, ll_reduced = -2),
    class = "gllvmTMB_variance_lrt_bad_loglik"
  )
  expect_error(
    variance_lrt(ll_full = -1, ll_reduced = c(-2, -3)),
    class = "gllvmTMB_variance_lrt_bad_loglik"
  )
})

test_that("variance_lrt() returns LRT and boundary p-value", {
  out <- variance_lrt(-10, -12, n_boundary = 2L)
  expect_equal(out$LRT, 4)
  expect_equal(out$n_boundary, 2L)
  expect_true(out$pvalue > 0 && out$pvalue < 1)
})

test_that("chibar2_pvalue() mixture is below naive chi-square for q > 1", {
  lrt <- 8
  naive <- stats::pchisq(lrt, df = 3, lower.tail = FALSE)
  cb <- chibar2_pvalue(lrt, 3)
  expect_lt(cb, naive)
  expect_true(cb > 0)
})