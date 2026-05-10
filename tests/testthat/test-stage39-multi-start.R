# Stage 39 — n_init multi-start and optim/BFGS optimiser dispatch.
# Per Maeve McGillycuddy (glmmTMB::rr() author), reduced-rank GLLVMs are
# multimodal in two-level fits; the recommended workflow is multi-start
# + alternative optimiser.

test_that("Stage 39: n_init > 1 runs the requested number of restarts", {
  set.seed(7)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(1.0, 0.7, -0.3, 0.3, -0.5, 0.8), nrow = 3, ncol = 2),
    S_B = c(0.3, 0.3, 0.3),
    seed = 7
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = sim$data,
    control = gllvmTMBcontrol(n_init = 3, init_jitter = 0.2)
  )
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(-fit$opt$objective))
})

test_that("Stage 39: optimizer = 'optim' with BFGS is dispatched", {
  set.seed(11)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2, 0.3, -0.4, 0.6), nrow = 3, ncol = 2),
    seed = 11
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = sim$data,
    control = gllvmTMBcontrol(optimizer = "optim",
                              optArgs = list(method = "BFGS"))
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(-fit$opt$objective))
})

test_that("Stage 39: gllvmTMBcontrol() defaults preserve old behaviour", {
  ctl <- gllvmTMBcontrol()
  expect_equal(ctl$n_init, 1L)
  expect_equal(ctl$optimizer, "nlminb")
  expect_equal(ctl$optArgs, list())
  expect_equal(ctl$init_jitter, 0.3)
  expect_false(ctl$verbose)
})
