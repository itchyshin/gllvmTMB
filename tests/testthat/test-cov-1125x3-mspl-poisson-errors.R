test_that(".gllvmTMB_mspl_poisson_event_count() floors at 1", {
  expect_equal(gllvmTMB:::.gllvmTMB_mspl_poisson_event_count(c(0, 0)), 1)
  expect_equal(gllvmTMB:::.gllvmTMB_mspl_poisson_event_count(c(2, 3)), 5)
})

test_that(".gllvmTMB_mspl_poisson_rate() errors on non-positive p_free", {
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_poisson_rate(0, 10),
    "positive p_free"
  )
})

test_that(".gllvmTMB_mspl_poisson_loading_atom() checks ybar length", {
  Lam <- matrix(1, 2, 1)
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_poisson_loading_atom(Lam, c(1)),
    "ybar length"
  )
})

test_that(".gllvmTMB_mspl_poisson_jeffreys() returns finite penalty", {
  X <- matrix(c(1, 1, 0, 1), ncol = 2)
  eta <- c(0, 0.5)
  val <- gllvmTMB:::.gllvmTMB_mspl_poisson_jeffreys(X, eta)
  expect_true(is.finite(val))
})