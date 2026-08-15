test_that("LA-MSPL prepare rejects every Phase-4 family", {
  n_site <- 8L
  n_trait <- 3L
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site))
  )
  form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
  cases <- list(
    poisson = list(family = stats::poisson(), y = rep(0:3, length.out = nrow(dat))),
    nbinom2 = list(family = nbinom2(), y = rep(0:3, length.out = nrow(dat))),
    tweedie = list(family = tweedie(), y = rep(c(0.5, 1, 2), length.out = nrow(dat))),
    beta = list(family = Beta(), y = rep(c(0.2, 0.5, 0.8), length.out = nrow(dat))),
    nbinom1 = list(family = nbinom1(), y = rep(0:3, length.out = nrow(dat)))
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
      "supports a single binomial or gaussian response family only",
      class = "gllvmTMB_mspl_unsupported",
      info = family_name
    )
  }
})
