test_that("chibar2_pvalue() is monotone non-increasing in LRT", {
  p1 <- chibar2_pvalue(1, 1)
  p2 <- chibar2_pvalue(5, 1)
  p3 <- chibar2_pvalue(10, 1)
  expect_gt(p1, p2)
  expect_gt(p2, p3)
})

test_that("chibar2_pvalue() respects mixture weights for q = 2", {
  lrt <- 4
  manual <- sum(choose(2, 1:2) * 2^(-2) * stats::pchisq(lrt, 1:2, lower.tail = FALSE))
  expect_equal(chibar2_pvalue(lrt, 2), manual)
})

test_that("variance_lrt() propagates negative log-likelihood difference", {
  out <- variance_lrt(-5, -8, n_boundary = 1L)
  expect_equal(out$LRT, 6)
})

test_that("variance_lrt() accepts negative log-likelihoods", {
  out <- variance_lrt(-100.1, -102.7, n_boundary = 3L)
  expect_true(is.finite(out$pvalue))
  expect_equal(out$n_boundary, 3L)
  expect_true(out$pvalue >= 0 && out$pvalue <= 1)
  expect_true(is.finite(out$LRT))
})