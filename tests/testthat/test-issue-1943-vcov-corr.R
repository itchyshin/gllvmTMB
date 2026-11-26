## Issue #1943: vcov(fit, corr = TRUE) must return correlations, not covariance.

test_that("#1943 vcov(..., corr = TRUE) returns a correlation matrix", {
  skip_on_cran()
  set.seed(26)
  Tn <- 3L
  d <- 2L
  n <- 32L
  Lam <- matrix(stats::rnorm(Tn * d, sd = 0.4), Tn, d)
  U <- matrix(stats::rnorm(n * Tn), n, Tn) %*% t(chol(Lam %*% t(Lam) + diag(0.25, Tn)))
  df <- expand.grid(trait_idx = seq_len(Tn), unit = seq_len(n))
  df$site <- factor(df$unit)
  df$trait <- factor(paste0("t", df$trait_idx), levels = paste0("t", seq_len(Tn)))
  df$value <- stats::rpois(nrow(df), lambda = exp(0.3 + U[cbind(df$unit, df$trait_idx)]))
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df, unit = "site", family = stats::poisson()
  ))
  V <- vcov(fit)
  C <- vcov(fit, corr = TRUE)

  expect_false(identical(V, C))
  expect_identical(dimnames(C), dimnames(V))
  free <- stats::complete.cases(diag(C))
  expect_equal(unname(diag(C)[free]), rep(1, sum(free)), tolerance = 1e-6)
  expect_equal(C, stats::cov2cor(V), tolerance = 1e-8, ignore_attr = TRUE)
})