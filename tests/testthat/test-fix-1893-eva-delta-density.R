test_that(".eva_delta_log_density() matrix eta is n_obs by quadrature (#1893)", {
  y <- c(0L, 2L, 5L)
  n_obs <- length(y)
  H <- 4L
  eta <- matrix(runif(n_obs * H, -1, 1), nrow = n_obs, ncol = H)

  for (family in c(0L, 1L, 2L)) {
    gaussian_sd <- if (family == 0L) 1.2 else 1
    n_trials <- if (family == 1L) rep(5L, n_obs) else rep(1L, n_obs)
    ell <- .eva_delta_log_density(y, n_trials, eta, family, gaussian_sd)
    expect_true(is.matrix(ell))
    expect_identical(dim(ell), c(n_obs, H))
    expect_equal(length(ell), n_obs * H)
    weights <- rep(1 / H, H)
    expect_length(drop(ell %*% weights), n_obs)
  }
})