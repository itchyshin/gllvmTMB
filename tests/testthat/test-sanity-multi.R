# Tests for sanity_multi() and the RE-aware predict().

test_that("sanity_multi() reports the expected fields", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 60, n_species = 12, n_traits = 3,
    mean_species_per_site = 5,
    Lambda_B = matrix(c(0.8, 0.5, -0.2, 0.2, -0.4, 0.6),
                      nrow = 3, ncol = 2),
    S_B = c(0.3, 0.3, 0.3),
    seed = 2025
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = sim$data
  )
  flags <- capture.output(out <- sanity_multi(fit))
  expect_true(out$converged)
  expect_true(is.finite(out$max_gradient))
  expect_true(is.logical(out$pd_hessian))
  expect_true("rr_B_min_loading" %in% names(out))
})

test_that("predict() with re_form ~ . differs from re_form ~ 0", {
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2), nrow = 3, ncol = 1),
    S_B = c(0.3, 0.3, 0.3),
    seed = 1
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site),
    data = sim$data
  )
  nd <- head(sim$data, 6)

  suppressMessages({
    p_re <- predict(fit, newdata = nd)              # re_form = ~ .
    p_fx <- predict(fit, newdata = nd, re_form = ~ 0)
  })
  ## RE-augmented predictions should differ from fixed-only on most rows.
  expect_true(any(abs(p_re$est - p_fx$est) > 1e-6))
})
