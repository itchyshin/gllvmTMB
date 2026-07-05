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
    "censored_poisson", "truncated_nbinom1"
  ) %in% names(family_enum)))
})
