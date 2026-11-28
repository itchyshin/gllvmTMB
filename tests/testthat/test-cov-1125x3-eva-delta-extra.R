test_that(".eva_delta_i() returns finite deltas for Poisson rows", {
  delta <- gllvmTMB:::.eva_delta_i(
    y = c(2, 0),
    n_trials = c(1, 1),
    mu = c(0.1, -0.2),
    v = c(0.05, 0.05),
    family = 2L,
    H = 5L
  )
  expect_length(delta, 2L)
  expect_true(all(is.finite(delta)))
})

test_that(".eva_delta_log_density() handles binomial rows", {
  eta <- matrix(c(0, 0.5), ncol = 1)
  ll <- gllvmTMB:::.eva_delta_log_density(
    y = c(1, 3),
    n_trials = c(5, 5),
    eta = eta,
    family = 1L,
    gaussian_sd = 1
  )
  expect_true(all(is.finite(ll)))
})

test_that(".eva_delta_summary() quantiles cover requested probs", {
  s <- gllvmTMB:::.eva_delta_summary(seq(-3, 3, length.out = 30))
  expect_length(s$quantiles, 5L)
  expect_true(all(is.finite(s$quantiles)))
})

test_that(".eva_delta_curvature() is negative for Gaussian rows", {
  curv <- gllvmTMB:::.eva_delta_curvature(
    n_trials = 1,
    mu = c(0, 1),
    family = 0L,
    gaussian_sd = 2
  )
  expect_true(all(curv < 0))
})