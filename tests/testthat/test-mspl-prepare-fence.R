## Poisson / nbinom1 / nbinom2 are intentionally absent: after the
## planned public door, estimator="mspl" must not be required to fail
## with the old family-fence message. See
## test-mspl-poisson-public-door.R and
## test-zz-mspl-nbinom-se-feasibility.R. This file keeps beta and
## Tweedie behind class gllvmTMB_mspl_unsupported.
##
## #1014 keeps Tweedie/Beta planned registry rows but does NOT open
## the public door: Tweedie live MSPL hangs; Beta Jeffreys atom
## returns status 1 on the 8x3 cell.

test_that("LA-MSPL prepare still rejects beta and Tweedie", {
  n_site <- 8L
  n_trait <- 3L
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site))
  )
  form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
  cases <- list(
    tweedie = list(family = tweedie(), y = rep(c(0.5, 1, 2), length.out = nrow(dat))),
    beta = list(family = Beta(), y = rep(c(0.2, 0.5, 0.8), length.out = nrow(dat)))
  )

  for (family_name in names(cases)) {
    case <- cases[[family_name]]
    dat$y <- case$y
    expect_error(
      gllvmTMB(
        form,
        data = dat,
        family = case$family,
        estimator = "mspl"
      ),
      "supports a single gaussian, bernoulli, Poisson, nbinom1, or nbinom2 response family only",
      class = "gllvmTMB_mspl_unsupported",
      info = family_name
    )
  }
})
