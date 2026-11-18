## Poisson / nbinom1 / nbinom2 / Beta are intentionally absent: after
## the planned public door, estimator="mspl" must not be required to
## fail with the old family-fence message. See
## test-mspl-poisson-public-door.R, test-mspl-beta-public-door.R, and
## test-zz-mspl-nbinom-se-feasibility.R. This file keeps Tweedie
## behind class gllvmTMB_mspl_unsupported (#1047 hang-fix not on main).
##
## Beta family id 7 is the planned door. The Jeffreys atom is the FCN
## K_bb (phi^2) form; V8 status 1 is OK_MP_CERTIFIED. Not admitted.

test_that("LA-MSPL prepare still rejects Tweedie", {
  n_site <- 8L
  n_trait <- 3L
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = rep(c(0.5, 1, 2), length.out = n_site * n_trait)
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = tweedie(),
      estimator = "mspl"
    ),
    "supports a single gaussian, bernoulli, Poisson, nbinom1, nbinom2, or Beta response family only",
    class = "gllvmTMB_mspl_unsupported"
  )
})
