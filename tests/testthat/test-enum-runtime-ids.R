test_that("internal enum mirrors multivariate runtime ids", {
  runtime_family <- c(
    gaussian          = 0L,
    binomial          = 1L,
    poisson           = 2L,
    lognormal         = 3L,
    Gamma             = 4L,
    nbinom2           = 5L,
    tweedie           = 6L,
    Beta              = 7L,
    betabinomial      = 8L,
    student           = 9L,
    truncated_poisson = 10L,
    truncated_nbinom2 = 11L,
    delta_lognormal   = 12L,
    delta_gamma       = 13L,
    ordinal_probit    = 14L,
    nbinom1           = 15L
  )
  runtime_link <- c(logit = 0L, probit = 1L, cloglog = 2L)

  family_enum <- getFromNamespace(".valid_family", "gllvmTMB")
  link_enum <- getFromNamespace(".valid_link", "gllvmTMB")

  expect_equal(family_enum, runtime_family)
  expect_equal(link_enum, runtime_link)
  expect_false(any(c(
    "gamma_mix", "lognormal_mix", "nbinom2_mix", "gengamma",
    "censored_poisson", "truncated_nbinom1", "delta_gamma_mix",
    "delta_lognormal_mix", "delta_gengamma", "delta_truncated_nbinom1",
    "delta_truncated_nbinom2", "delta_beta"
  ) %in% names(family_enum)))
})

test_that("constructor-only families fail loud before runtime admission", {
  df <- data.frame(
    individual = factor(rep(seq_len(4), each = 2)),
    trait = factor(rep(c("a", "b"), times = 4), levels = c("a", "b")),
    value = rep(1:2, times = 4)
  )
  blocked <- list(
    gamma_mix = gamma_mix(),
    lognormal_mix = lognormal_mix(),
    nbinom2_mix = nbinom2_mix(),
    gengamma = gengamma(),
    truncated_nbinom1 = truncated_nbinom1(),
    censored_poisson = censored_poisson(),
    delta_gamma_mix = delta_gamma_mix(),
    delta_lognormal_mix = delta_lognormal_mix(),
    delta_gengamma = delta_gengamma(),
    delta_truncated_nbinom1 = delta_truncated_nbinom1(),
    delta_truncated_nbinom2 = delta_truncated_nbinom2(),
    delta_beta = delta_beta()
  )

  for (nm in names(blocked)) {
    expect_error(
      suppressMessages(suppressWarnings(gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | individual, d = 1),
        data = df,
        site = "individual",
        family = blocked[[nm]]
      ))),
      regexp = "Unsupported (delta )?family",
      info = nm
    )
  }
})
