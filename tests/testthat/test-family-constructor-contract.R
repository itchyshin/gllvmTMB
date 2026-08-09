test_that("family constructors preserve their public signatures", {
  signatures <- list(
    Beta = c("link"), lognormal = c("link"), gengamma = c("link"),
    gamma_mix = c("link", "p_extreme"),
    lognormal_mix = c("link", "p_extreme"),
    nbinom2_mix = c("link", "p_extreme"),
    nbinom2 = c("link"), nbinom1 = c("link"),
    truncated_poisson = c("link"), truncated_nbinom2 = c("link"),
    truncated_nbinom1 = c("link"), student = c("link", "df"),
    tweedie = c("link", "p"), censored_poisson = c("link"),
    delta_gamma = c("link1", "link2", "type"),
    delta_gamma_mix = c("link1", "link2", "p_extreme"),
    delta_gengamma = c("link1", "link2", "type"),
    delta_lognormal = c("link1", "link2", "type"),
    delta_lognormal_mix = c("link1", "link2", "type", "p_extreme"),
    delta_truncated_nbinom2 = c("link1", "link2"),
    delta_truncated_nbinom1 = c("link1", "link2"),
    delta_poisson_link_gamma = c("link1", "link2"),
    delta_poisson_link_lognormal = c("link1", "link2"),
    betabinomial = c("link"), delta_beta = c("link1", "link2"),
    ordinal_probit = c("link"), multinomial = c("link", "baseline")
  )

  for (constructor in names(signatures)) {
    expect_identical(
      names(formals(get(constructor, envir = asNamespace("gllvmTMB")))),
      signatures[[constructor]],
      info = constructor
    )
  }
})

test_that("one-part constructors return the required family fields", {
  full <- list(
    Beta(), lognormal(), gengamma(), gamma_mix(), lognormal_mix(),
    nbinom2_mix(), nbinom2(), nbinom1(),
    suppressMessages(student()), tweedie(), betabinomial()
  )
  full_names <- c(
    "family", "link", "linkfun", "linkinv", "mu.eta", "valideta",
    "name", "aic", "initialize", "dev.resids"
  )
  for (family in full) {
    expect_s3_class(family, "family")
    expect_true(all(full_names %in% names(family)), info = family$family)
    eta <- c(-0.8, 0, 0.8)
    expect_equal(family$linkfun(family$linkinv(eta)), eta, tolerance = 1e-10)
    init_env <- list2env(list(y = c(-1, 0, 2)), parent = baseenv())
    eval(family$initialize, envir = init_env)
    expect_equal(init_env$mustart, c(-0.9, 0.1, 2.1))
  }

  compact <- list(
    truncated_poisson(), truncated_nbinom2(), truncated_nbinom1(),
    censored_poisson(), ordinal_probit(), multinomial()
  )
  for (family in compact) {
    expect_true(all(c("family", "link", "linkfun", "linkinv") %in% names(family)))
  }
  expect_identical(class(ordinal_probit()), c("ordinal_probit", "family"))
  expect_identical(class(multinomial()), c("multinomial", "family"))
})

test_that("links accept standard quoted, unquoted, and variable forms", {
  selected <- "probit"
  expect_identical(lognormal(link = selected)$link, "probit")
  expect_identical(nbinom2(link = log)$link, "log")
  expect_identical(Beta(link = "cloglog")$link, "cloglog")

  expect_error(nbinom2(link = "not-a-link"), "does not recognise")
  expect_error(betabinomial(link = "probit"), "supports only")
  expect_error(ordinal_probit(link = "logit"), "supports only")
  expect_error(multinomial(link = "probit"), "supports only")
})

test_that("constructor-specific controls validate and remain in the object", {
  expect_identical(gamma_mix(p_extreme = 0.2)$p_extreme, 0.2)
  expect_identical(lognormal_mix(p_extreme = 0.3)$p_extreme, 0.3)
  expect_identical(nbinom2_mix(p_extreme = 0.4)$p_extreme, 0.4)
  expect_error(gamma_mix(p_extreme = c(0.2, 0.3)), "one number")
  expect_error(gamma_mix(p_extreme = 1), "strictly between")

  expect_identical(suppressMessages(student(df = 4))$df, 4)
  expect_error(suppressMessages(student(df = 1)), "greater than 1")
  expect_identical(tweedie(p = 1.5)$p, 1.5)
  expect_error(tweedie(p = Inf), "strictly between 1 and 2")

  expect_identical(multinomial(baseline = "control")$baseline, "control")
  expect_error(multinomial(baseline = c("a", "b")), "one category")
})

test_that("delta constructors preserve component and routing metadata", {
  standard <- delta_gamma()
  expect_true(standard$delta)
  expect_identical(standard$family, c("binomial", "Gamma"))
  expect_identical(standard$link, c("logit", "log"))
  expect_identical(standard$type, "standard")
  expect_identical(
    standard$clean_name,
    "delta_gamma(link1 = 'logit', link2 = 'log')"
  )

  poisson_link <- delta_lognormal(type = "poisson-link")
  expect_identical(poisson_link$link, c("log", "log"))
  expect_identical(poisson_link$type, "poisson_link_delta")
  expect_match(poisson_link$clean_name, "type = 'poisson-link'", fixed = TRUE)

  mixture <- delta_gamma_mix(p_extreme = 0.25)
  expect_identical(mixture$family, c("binomial", "gamma_mix"))
  expect_identical(mixture$p_extreme, 0.25)
  expect_identical(mixture[[2L]]$family, "gamma_mix")

  expect_identical(
    delta_truncated_nbinom2()$family,
    c("binomial", "truncated_nbinom2")
  )
  expect_identical(delta_beta()$family, c("binomial", "Beta"))
})

test_that("zero-truncated inverse links return conditional means", {
  mu <- c(1e-8, 0.2, 2, 100)
  expect_equal(
    truncated_poisson()$linkinv(log(mu)),
    mu / stats::ppois(0, lambda = mu, lower.tail = FALSE),
    tolerance = 1e-10
  )

  phi2 <- 3
  expected2 <- mu / (1 - stats::dnbinom(0, mu = mu, size = phi2))
  expect_equal(
    truncated_nbinom2()$linkinv(log(mu), phi = phi2), expected2,
    tolerance = 1e-10
  )

  phi1 <- 0.7
  expected1 <- mu / (1 - stats::dnbinom(0, mu = mu, size = mu / phi1))
  expect_equal(
    truncated_nbinom1()$linkinv(log(mu), phi = phi1), expected1,
    tolerance = 1e-10
  )
})
