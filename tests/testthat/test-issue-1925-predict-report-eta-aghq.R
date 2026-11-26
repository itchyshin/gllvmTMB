## Issue #1925: penalised AGHQ fits stored a base-only TMB report$eta while
## predict() returned the training-row conditional predictor. Seeds without
## loading-ridge warnings are plain Laplace and already matched.

test_that("in-sample predict() matches report$eta on penalised AGHQ Poisson latent", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  set.seed(1)
  n <- 200L
  nt <- 6L
  loadings <- matrix(rnorm(nt * 2L, sd = 0.8), nrow = nt, ncol = 2L)
  z <- matrix(rnorm(n * 2L), n, 2L)
  trait_eff <- matrix(
    rep(c(0, 0.3, -0.2, 0.5, -0.5, 0), n),
    nrow = n, ncol = nt, byrow = TRUE
  )
  eta <- rowSums(z %*% t(loadings)) + rowSums(trait_eff)[rep(seq_len(n), each = nt)]
  unit <- factor(rep(seq_len(n), each = nt))
  trait <- factor(rep(paste0("t", seq_len(nt)), n))
  dat <- data.frame(
    value = rpois(n * nt, exp(eta)),
    site = unit,
    trait = trait
  )
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE),
    data = dat,
    family = poisson(),
    control = gllvmTMBcontrol(
      se = FALSE,
      aghq = 9L,
      aghq_multistart = FALSE,
      n_init = 1L,
      svd_start = FALSE
    )
  )))
  expect_true(isTRUE(fit$aghq$used))
  expect_true(isTRUE(fit$aghq$penalised))
  pr <- predict(fit)
  gap <- max(abs(as.numeric(fit$report$eta) - pr$est), na.rm = TRUE)
  expect_equal(gap, 0, tolerance = 1e-8)
})