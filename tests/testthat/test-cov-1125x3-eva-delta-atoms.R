test_that(".eva_delta_log_density() is vectorised over eta columns", {
  y <- c(1, 0)
  eta <- matrix(c(0, -1, 0.5, -0.5), nrow = 2, ncol = 2)
  gauss <- gllvmTMB:::.eva_delta_log_density(y, c(1, 1), eta, 0L, 1)
  expect_length(gauss, length(y) * ncol(eta))
  pois <- gllvmTMB:::.eva_delta_log_density(y, c(1, 1), eta, 2L, 1)
  expect_true(all(is.finite(pois)))
})

test_that(".eva_delta_curvature() matches closed forms", {
  mu <- c(0, 1)
  bin <- gllvmTMB:::.eva_delta_curvature(c(5, 5), mu, 1L, 1)
  p <- stats::plogis(mu)
  expect_equal(bin, -5 * p * (1 - p))
  pois <- gllvmTMB:::.eva_delta_curvature(c(1, 1), mu, 2L, 1)
  expect_equal(pois, -exp(mu))
})

test_that(".eva_delta_surrogate() combines log density and curvature", {
  y <- 3
  mu <- 0.2
  v <- 0.1
  s <- gllvmTMB:::.eva_delta_surrogate(y, 1L, mu, v, 2L, gaussian_sd = 1)
  expect_true(is.finite(s))
})

test_that(".eva_delta_i() validates family code", {
  expect_error(
    gllvmTMB:::.eva_delta_i(1, 1, 0, 0.1, family = 9L),
    "family must be"
  )
})

test_that(".eva_delta_i() validates vector lengths", {
  expect_error(
    gllvmTMB:::.eva_delta_i(c(1, 2), 1, 0, 0.1, family = 2L),
    "equal length"
  )
})

test_that(".eva_delta_summary() summarises a finite delta vector", {
  delta <- c(-0.01, 0.02, -0.5, 0.001)
  s <- gllvmTMB:::.eva_delta_summary(delta)
  expect_equal(s$n, 4L)
  expect_true(is.finite(s$max_abs))
  expect_equal(s$which_max, 3L)
  expect_true(all(c("top_decile_share", "n_for_half") %in% names(s)))
})

test_that(".eva_delta_summary() rejects non-finite input", {
  expect_error(
    gllvmTMB:::.eva_delta_summary(c(NA, 1)),
    "finite numeric"
  )
})