## Poisson / nbinom / Tweedie / Beta are intentionally absent: after
## the planned public door, estimator="mspl" must not be required to
## fail with the old family-fence message. This file keeps Gamma and
## lognormal behind class gllvmTMB_mspl_unsupported.

test_that("LA-MSPL prepare still rejects Gamma and lognormal", {
  n_site <- 8L
  n_trait <- 3L
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site))
  )
  form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
  cases <- list(
    Gamma = list(family = stats::Gamma(link = "log"), y = rep(c(0.5, 1, 2), length.out = nrow(dat))),
    lognormal = list(family = lognormal(), y = rep(c(0.5, 1, 2), length.out = nrow(dat)))
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
      "supports a single gaussian, bernoulli, Poisson, nbinom1, nbinom2, Tweedie, or Beta response family only",
      class = "gllvmTMB_mspl_unsupported",
      info = family_name
    )
  }
})
