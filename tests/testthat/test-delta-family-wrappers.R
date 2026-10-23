# Behaviour of the delta-family wrappers that the constructor-shape tests do
# not reach: deprecated Poisson-link wrappers, per-type default links,
# link validation messages, and the p_extreme control.

delta_core <- function(x) x[c("link", "type", "family")]

test_that("deprecated Poisson-link wrappers warn and match delta_*(type = 'poisson-link')", {
  lifecycle::expect_deprecated(
    gamma_old <- delta_poisson_link_gamma(),
    "delta_poisson_link_gamma"
  )
  lifecycle::expect_deprecated(
    lognormal_old <- delta_poisson_link_lognormal(),
    "delta_poisson_link_lognormal"
  )

  gamma_new <- delta_gamma(link1 = "logit", link2 = "log", type = "poisson-link")
  lognormal_new <- delta_lognormal(
    link1 = "logit", link2 = "log", type = "poisson-link"
  )

  expect_identical(delta_core(gamma_old), delta_core(gamma_new))
  expect_identical(delta_core(lognormal_old), delta_core(lognormal_new))
  expect_identical(gamma_old$type, "poisson_link_delta")
  expect_identical(lognormal_old$type, "poisson_link_delta")
  expect_identical(gamma_old$clean_name, gamma_new$clean_name)
  expect_identical(lognormal_old$clean_name, lognormal_new$clean_name)
  expect_s3_class(gamma_old, "family")
})

test_that("deprecated Poisson-link wrappers reject non-log links", {
  expect_error(
    delta_poisson_link_gamma(link1 = "logit"),
    "accepts only log links"
  )
  expect_error(
    delta_poisson_link_gamma(link2 = "identity"),
    "accepts only log links"
  )
  expect_error(
    delta_poisson_link_lognormal(link1 = "probit"),
    "accepts only log links"
  )
  expect_error(
    delta_poisson_link_lognormal(link2 = "inverse"),
    "accepts only log links"
  )
  expect_error(
    delta_poisson_link_gamma(link1 = "logit"),
    "delta_gamma(link1 = \"logit\", link2 = \"log\", type = \"poisson-link\")",
    fixed = TRUE
  )
  expect_error(
    delta_poisson_link_lognormal(link1 = "logit"),
    "delta_lognormal(link1 = \"logit\", link2 = \"log\", type = \"poisson-link\")",
    fixed = TRUE
  )
  # The abort happens before the deprecation notice is signalled.
  expect_no_warning(
    try(delta_poisson_link_gamma(link1 = "logit"), silent = TRUE)
  )
})

test_that("typed delta constructors default link1 by type", {
  constructors <- list(
    delta_gengamma = delta_gengamma,
    delta_lognormal_mix = delta_lognormal_mix
  )
  for (nm in names(constructors)) {
    f <- constructors[[nm]]
    std <- f()
    pl <- f(type = "poisson-link")
    expect_identical(std$link, c("logit", "log"), info = nm)
    expect_identical(std$type, "standard", info = nm)
    expect_identical(pl$link, c("log", "log"), info = nm)
    expect_identical(pl$type, "poisson_link_delta", info = nm)
    expect_identical(std$family, c("binomial", sub("^delta_", "", nm)),
                     info = nm)
    expect_match(std$clean_name, sprintf("^%s\\(link1 = 'logit'", nm),
                 info = nm)
    expect_match(pl$clean_name, "type = 'poisson-link'", fixed = TRUE,
                 info = nm)
  }
  expect_identical(delta_lognormal_mix()$family[[2L]], "lognormal_mix")

  # an explicit link1 overrides the type default
  expect_identical(delta_gengamma(link1 = "probit")$link[[1L]], "probit")
  expect_identical(
    delta_lognormal_mix(link1 = "cloglog", type = "poisson-link")$link,
    c("cloglog", "log")
  )
  expect_identical(delta_gengamma(link1 = log, type = "poisson-link")$link[[1L]],
                   "log")
  expect_error(delta_gengamma(type = "bogus"), "should be one of")
})

test_that("delta_truncated_nbinom1 has fixed default links", {
  fam <- delta_truncated_nbinom1()
  expect_identical(fam$link, c("logit", "log"))
  expect_identical(fam$family, c("binomial", "truncated_nbinom1"))
  expect_null(fam$type)
  expect_identical(
    fam$clean_name,
    "delta_truncated_nbinom1(link1 = 'logit', link2 = 'log')"
  )
  expect_identical(delta_truncated_nbinom1(link1 = "probit")$link[[1L]], "probit")
  expect_identical(delta_truncated_nbinom1(link1 = cloglog)$link[[1L]], "cloglog")
})

test_that("invalid links abort naming the constructor", {
  expect_error(delta_gengamma(link1 = "nonsense"),
               "delta_gengamma()", fixed = TRUE)
  expect_error(delta_gengamma(link1 = "nonsense"),
               "does not recognise link")
  expect_error(delta_gengamma(link2 = "nonsense"),
               "delta_gengamma()", fixed = TRUE)
  expect_error(delta_lognormal_mix(link1 = "nonsense"),
               "delta_lognormal_mix()", fixed = TRUE)
  expect_error(delta_lognormal_mix(link2 = "nonsense"),
               "does not recognise link")
  expect_error(delta_truncated_nbinom1(link1 = "nonsense"),
               "delta_truncated_nbinom1()", fixed = TRUE)
  expect_error(delta_truncated_nbinom1(link2 = "nonsense"),
               "delta_truncated_nbinom1()", fixed = TRUE)
  expect_error(delta_truncated_nbinom1(link1 = c("logit", "probit")),
               "requires one link name")
  expect_error(delta_gengamma(link1 = NA_character_),
               "requires one link name")
  expect_error(delta_lognormal_mix(link2 = ""),
               "requires one link name")
})

test_that("delta_lognormal_mix validates p_extreme", {
  expect_null(delta_lognormal_mix()$p_extreme)
  expect_true("p_extreme" %in% names(delta_lognormal_mix()))
  expect_identical(delta_lognormal_mix(p_extreme = 0.25)$p_extreme, 0.25)
  expect_identical(delta_lognormal_mix(p_extreme = 1L / 2L)$p_extreme, 0.5)
  for (bad in list(0, 1, -0.1, 1.5, NA_real_, Inf, c(0.1, 0.2), "0.5")) {
    expect_error(
      delta_lognormal_mix(p_extreme = bad),
      "p_extreme.*NULL or one number strictly between 0 and 1",
      info = deparse(bad)
    )
    expect_error(delta_lognormal_mix(p_extreme = bad),
                 "delta_lognormal_mix()", fixed = TRUE, info = deparse(bad))
  }
})
