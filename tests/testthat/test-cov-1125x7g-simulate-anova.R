## Coverage (cursor-cloud-1125x7g): simulate_unit_trait(), anova step classifier.

test_that("simulate_unit_trait returns long data and truth", {
  sim <- simulate_unit_trait(n_units = 4L, n_obs_per_unit = 2L, n_traits = 3L, seed = 7L)
  expect_type(sim, "list")
  expect_s3_class(sim$data, "data.frame")
  expect_equal(nrow(sim$data), 4L * 2L * 3L)
  expect_true(all(c("unit", "observation", "trait", "value") %in% names(sim$data)))
  expect_length(sim$truth$alpha, 3L)
})

test_that("simulate_unit_trait honours reduced-rank loadings", {
  Lam <- matrix(c(0.5, 0.1, -0.2), nrow = 3, ncol = 1)
  sim <- simulate_unit_trait(
    n_units = 6L, n_obs_per_unit = 2L, n_traits = 3L,
    Lambda_B = Lam, psi_B = c(0.2, 0.3, 0.1), seed = 2L
  )
  expect_equal(dim(sim$truth$Lambda_B), c(3L, 1L))
  expect_gt(stats::var(sim$data$value), 0)
})

test_that("simulate_unit_trait rejects wrong alpha length", {
  expect_error(
    simulate_unit_trait(n_units = 2L, n_traits = 3L, alpha = 1:2),
    "length"
  )
})

test_that(".gllvmTMB_anova_classify_step labels fixed-effect expansion", {
  prev <- list(use = list(), X_fix_names = "a", d_B = 1L)
  curr <- list(use = list(), X_fix_names = c("a", "b"), d_B = 1L, n_traits = 2L)
  step <- gllvmTMB:::.gllvmTMB_anova_classify_step(prev, curr)
  expect_equal(step$kind, "fixed")
})

test_that(".gllvmTMB_anova_classify_step labels single rank step", {
  prev <- list(use = list(), X_fix_names = "a", d_B = 1L)
  curr <- list(use = list(), X_fix_names = "a", d_B = 2L, n_traits = 3L)
  step <- gllvmTMB:::.gllvmTMB_anova_classify_step(prev, curr)
  expect_equal(step$kind, "rank")
  expect_equal(step$delta_d, 1L)
})

test_that(".gllvmTMB_anova_classify_step refuses non-nested fixed names", {
  prev <- list(use = list(), X_fix_names = c("a", "c"), d_B = 1L)
  curr <- list(use = list(), X_fix_names = c("a", "b"), d_B = 1L, n_traits = 2L)
  expect_equal(gllvmTMB:::.gllvmTMB_anova_classify_step(prev, curr)$kind, "not_nested")
})

test_that(".gllvmTMB_anova_classify_step marks compound changes", {
  prev <- list(use = list(), X_fix_names = "a", d_B = 1L)
  curr <- list(use = list(x = 1), X_fix_names = c("a", "b"), d_B = 2L, n_traits = 2L)
  expect_equal(gllvmTMB:::.gllvmTMB_anova_classify_step(prev, curr)$kind, "compound")
})

test_that("lognormal and gamma families expose log links", {
  expect_equal(lognormal()$link, "log")
  expect_equal(gamma_mix()$link, "log")
  expect_equal(lognormal_mix()$link, "log")
})

test_that("delta constructors wire two arms", {
  d1 <- delta_gamma()
  expect_type(d1, "list")
  expect_true(length(d1) >= 2L)
})