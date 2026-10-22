## Tests for `.gllvmTMB_family_cdf_args()` (R/family-cdf-args.R, issue
## #1080): the internal per-trait accessor that converts the engine-named
## dispersion quantities on `fit$report` into standard R distribution
## arguments. The accessor deliberately DUPLICATES the inline conversions
## of `.gllvmTMB_exact_rq_residuals()` (R/predictive-diagnostics.R) rather
## than refactoring that per-row loop, so these tests are the pin that
## keeps the two in agreement:
##   (a) one small REAL Gamma fit checks the accessor navigates a genuine
##       fitted object and agrees with residuals() CDF values row by row;
##   (b) a fit-shaped MOCK (no TMB fit; milliseconds) checks agreement for
##       gaussian, lognormal (shared sigma_eps), student (scale, not SD),
##       and truncated_nbinom2 (phi_truncnb2, NOT phi_nbinom2) against
##       `.gllvmTMB_exact_rq_residuals()` on the same object;
##   (c) delta_gamma (no residual branch exists) is pinned against the
##       src/gllvmTMB.cpp contract directly: shape = 1/phi^2,
##       scale = mu*phi^2, so E(y|y>0) = mu and CV(y|y>0) = phi.

## Build a fit-shaped list carrying exactly the fields the accessor and
## `.gllvmTMB_exact_rq_residuals()` read. traits: a data.frame with one
## row per trait: name, family_id, link_id, and a generator for valid y.
make_mock_fit <- function(traits, m = 6L, report = list(), seed = 42L) {
  set.seed(seed)
  Tn <- nrow(traits)
  n <- Tn * m
  trait_id0 <- rep(seq_len(Tn) - 1L, each = m)
  fid <- rep(traits$family_id, each = m)
  lid <- rep(traits$link_id, each = m)
  eta <- stats::rnorm(n, sd = 0.4)
  y <- numeric(n)
  for (t in seq_len(Tn)) {
    idx <- which(trait_id0 == t - 1L)
    y[idx] <- traits$gen[[t]](eta[idx])
  }
  dat <- data.frame(
    trait = rep(as.character(traits$name), each = m),
    stringsAsFactors = FALSE
  )
  report$eta <- eta
  list(
    tmb_data = list(
      y = y,
      n_trials = rep(1, n),
      trait_id = trait_id0,
      family_id_vec = fid,
      link_id_vec = lid
    ),
    report = report,
    data = dat,
    trait_col = "trait"
  )
}

## ---- (a) real Gamma fit: shape, scale = mu / shape -------------------------

make_small_gamma_fit <- function(seed = 108L) {
  set.seed(seed)
  n_ind <- 80L
  trait_names <- c("a", "b")
  mu_true <- c(0.3, 0.8)
  shape_true <- 5
  u <- stats::rnorm(n_ind, sd = 0.2)
  eta <- cbind(mu_true[1] + u, mu_true[2] + 0.5 * u)
  y <- matrix(
    stats::rgamma(
      n_ind * 2L,
      shape = shape_true,
      rate = shape_true / exp(as.vector(eta))
    ),
    n_ind,
    2L
  )
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = 2L)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = stats::Gamma(link = "log")
  )))
}

test_that("Gamma accessor reports the shape and agrees with exact residuals", {
  skip_on_cran()
  fit <- make_small_gamma_fit()
  expect_true(all(fit$tmb_data$family_id_vec == 4L))

  for (t in 1:2) {
    info <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, t)
    ## phi_gamma IS the shape, passed through unconverted.
    expect_identical(info$family, "Gamma")
    expect_identical(info$dist, "gamma")
    expect_equal(info$args$shape, as.numeric(fit$report$phi_gamma[t]))
    expect_match(info$note, "SHAPE")

    ## Row-level agreement with the residual branch: pgamma at the
    ## accessor's args reproduces the residuals() CDF exactly.
    rows <- which(fit$tmb_data$trait_id + 1L == t)
    eta_t <- as.numeric(fit$report$eta)[rows]
    full <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, t, eta = eta_t)
    expect_equal(full$args$scale, exp(eta_t) / full$args$shape)
    res <- stats::residuals(fit, type = "randomized_quantile", seed = 11L)
    expect_equal(
      stats::pgamma(
        as.numeric(fit$tmb_data$y)[rows],
        shape = full$args$shape,
        scale = full$args$scale
      ),
      res$cdf_lower[rows],
      tolerance = 1e-12
    )
  }
})

## ---- (b) mock fit: shared sigma_eps, student scale, phi_truncnb2 -----------

make_mixed_mock <- function() {
  traits <- data.frame(
    name = c("g", "ln", "st", "tnb"),
    family_id = c(0L, 3L, 9L, 11L),
    link_id = c(3L, 0L, 3L, 0L),
    stringsAsFactors = FALSE
  )
  traits$gen <- list(
    function(e) e + stats::rnorm(length(e), sd = 0.7),
    function(e) exp(e + stats::rnorm(length(e), sd = 0.7)),
    function(e) e + 0.8 * stats::rt(length(e), df = 5),
    function(e) pmax(1, stats::rpois(length(e), lambda = exp(e) + 1))
  )
  make_mock_fit(
    traits,
    report = list(
      sigma_eps = 0.7,
      sigma_student = c(NA, NA, 0.8, NA),
      df_student = c(NA, NA, 5, NA),
      ## Deliberately DIFFERENT values: the truncated-NB2 trait must read
      ## phi_truncnb2, never phi_nbinom2.
      phi_nbinom2 = c(99, 99, 99, 99),
      phi_truncnb2 = c(NA, NA, NA, 2.5)
    )
  )
}

test_that("legacy scalar sigma_eps remains a joint-fit fallback", {
  skip_on_cran()
  fit <- make_mixed_mock()
  g <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1)
  ln <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 2)
  expect_identical(g$dist, "norm")
  expect_identical(ln$dist, "lnorm")
  expect_equal(g$args$sd, 0.7)
  expect_equal(ln$args$sdlog, 0.7)
  expect_identical(g$args$sd, ln$args$sdlog)
  expect_match(g$note, "Gaussian|shared")
})

test_that("student accessor returns scale + df and converts to the SD", {
  skip_on_cran()
  fit <- make_mixed_mock()
  st <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 3)
  expect_identical(st$dist, "t")
  expect_equal(st$args$scale, 0.8)
  expect_equal(st$args$df, 5)
  ## sigma_student is a SCALE: SD = sigma * sqrt(df / (df - 2)).
  expect_equal(st$args$sd, 0.8 * sqrt(5 / 3))
  expect_match(st$note, "SCALE")

  ## df <= 2: the SD is undefined and must be NA, never a number.
  fit2 <- fit
  fit2$report$df_student[3] <- 2
  st2 <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit2, 3)
  expect_true(is.na(st2$args$sd))
  expect_equal(st2$args$scale, 0.8)
})

test_that("truncated_nbinom2 accessor reads phi_truncnb2, not phi_nbinom2", {
  skip_on_cran()
  fit <- make_mixed_mock()
  tnb <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 4)
  expect_equal(tnb$args$size, 2.5)
  expect_identical(tnb$report, list(phi_truncnb2 = 2.5))
  expect_match(tnb$note, "SEPARATE")
})

test_that("mock accessor args reproduce the exact-residual CDF row by row", {
  skip_on_cran()
  fit <- make_mixed_mock()
  res <- gllvmTMB:::.gllvmTMB_exact_rq_residuals(fit, seed = 7L)
  expect_true(all(res$status == "ok"))
  y <- as.numeric(fit$tmb_data$y)
  eta <- as.numeric(fit$report$eta)

  for (t in 1:4) {
    rows <- which(fit$tmb_data$trait_id + 1L == t)
    a <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, t, eta = eta[rows])
    cdf <- switch(
      as.character(a$family_id),
      "0" = stats::pnorm(y[rows], mean = a$args$mean, sd = a$args$sd),
      "3" = stats::plnorm(
        y[rows],
        meanlog = a$args$meanlog,
        sdlog = a$args$sdlog
      ),
      "9" = stats::pt(
        (y[rows] - a$args$location) / a$args$scale,
        df = a$args$df
      ),
      "11" = {
        p0 <- stats::pnbinom(0, size = a$args$size, mu = a$args$mu)
        (stats::pnbinom(y[rows], size = a$args$size, mu = a$args$mu) - p0) /
          (1 - p0)
      }
    )
    ## Continuous families: cdf_lower == cdf_upper == CDF(y). Discrete
    ## truncated NB2: compare the upper CDF (lower is CDF(y - 1), 0 at
    ## the support floor).
    expect_equal(cdf, res$cdf_upper[rows], tolerance = 1e-12)
  }
})

## ---- (c) delta_gamma: phi_gamma_delta is the CV of the positive part ------

test_that("delta_gamma accessor converts the CV to shape/scale per the engine", {
  skip_on_cran()
  traits <- data.frame(
    name = "dg",
    family_id = 13L,
    link_id = 0L,
    stringsAsFactors = FALSE
  )
  traits$gen <- list(function(e) {
    ifelse(stats::runif(length(e)) < 0.3, 0, exp(e))
  })
  cv <- 0.5
  fit <- make_mock_fit(traits, report = list(phi_gamma_delta = cv))

  dg <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1)
  expect_identical(dg$family, "delta_gamma")
  ## src/gllvmTMB.cpp fid == 13: shape = 1 / phi^2.
  expect_equal(dg$args$shape, 1 / cv^2)
  expect_match(dg$note, "CV")

  ## With eta: scale = mu * phi^2, so the implied Gamma satisfies the
  ## engine's contract E(y | y > 0) = mu and CV(y | y > 0) = phi.
  eta <- c(-0.2, 0, 0.4)
  full <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta)
  expect_equal(full$args$scale, exp(eta) * cv^2)
  expect_equal(full$args$shape * full$args$scale, exp(eta)) # mean = mu
  expect_equal(1 / sqrt(full$args$shape), cv) # CV = phi
})

## ---- (d) #1149: remaining family_id branches --------------------------------
## Each expectation is a hand computation from the documented engine
## parameterisation in src/gllvmTMB.cpp (cited per test), not a copy of the
## accessor output. Mock fits only; no TMB fit.

mock_one <- function(fid, lid = 0L, report = list(), tmb_extra = list(), gen = NULL) {
  traits <- data.frame(name = "x", family_id = fid, link_id = lid,
                       stringsAsFactors = FALSE)
  traits$gen <- list(gen %||% function(e) rep(1, length(e)))
  fit <- make_mock_fit(traits, report = report)
  fit$tmb_data[names(tmb_extra)] <- tmb_extra
  fit
}
eta_toy <- c(-0.5, 0, 0.7)

test_that("#1149 family_id 1 (binomial) prob = linkinv(eta) per link_id", {
  for (lid in 0:2) {
    fit <- mock_one(1L, lid)
    a <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
    hand <- switch(as.character(lid),
      "0" = 1 / (1 + exp(-eta_toy)),
      "1" = stats::pnorm(eta_toy),
      "2" = 1 - exp(-exp(eta_toy))
    )
    expect_identical(a$dist, "binom")
    expect_equal(a$args$prob, hand, tolerance = 1e-12)
    ## CDF reproduction with a toy size (row-level n_trials).
    expect_equal(stats::pbinom(2, size = 5, prob = a$args$prob),
                 stats::pbinom(2, size = 5, prob = hand))
  }
  ## No eta, or an unknown link: no prob.
  expect_null(gllvmTMB:::.gllvmTMB_family_cdf_args(mock_one(1L, 0L), 1)$args$prob)
  expect_null(gllvmTMB:::.gllvmTMB_family_cdf_args(mock_one(1L, 7L), 1,
                                                    eta = eta_toy)$args$prob)
})

test_that("#1149 family_id 2 (poisson) lambda = exp(eta)", {
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(mock_one(2L), 1, eta = eta_toy)
  expect_identical(a$dist, "pois")
  expect_equal(a$args$lambda, exp(eta_toy))
  expect_equal(stats::ppois(3, a$args$lambda), stats::ppois(3, exp(eta_toy)))
  expect_null(gllvmTMB:::.gllvmTMB_family_cdf_args(mock_one(2L), 1)$args$lambda)
})

test_that("#1149 family_id 5 (nbinom2) size = phi, mu = exp(eta)", {
  ## cpp fid 5: log(var - mu) = 2 log(mu) - log(phi)  =>  var = mu + mu^2/phi,
  ## which is R's nbinom(size = phi, mu).
  phi <- 3.2
  fit <- mock_one(5L, report = list(phi_nbinom2 = phi))
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
  expect_identical(a$dist, "nbinom")
  expect_equal(a$args$size, phi)
  expect_equal(a$args$mu, exp(eta_toy))
  mu <- exp(eta_toy)
  expect_equal(mu + mu^2 / a$args$size, mu + mu^2 / phi)
  ## Gamma-Poisson mixture CDF by hand: pnbinom(y; size, mu) at y = 0 is
  ## (size / (size + mu))^size.
  expect_equal(stats::pnbinom(0, size = a$args$size, mu = a$args$mu),
               (phi / (phi + mu))^phi, tolerance = 1e-12)
})

test_that("#1149 family_id 6 (tweedie) passes phi, power; mu = exp(eta)", {
  fit <- mock_one(6L, report = list(phi_tweedie = 1.7, p_tweedie = 1.4))
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
  expect_true(is.na(a$dist))
  expect_equal(a$args$phi, 1.7)
  expect_equal(a$args$power, 1.4)
  expect_equal(a$args$mu, exp(eta_toy))
  expect_true(a$args$power > 1 && a$args$power < 2)
  ## Compound Poisson-Gamma: P(y = 0) = exp(-mu^(2-p) / (phi * (2-p))).
  mu <- a$args$mu
  p0 <- exp(-mu^(2 - 1.4) / (1.7 * (2 - 1.4)))
  expect_true(all(p0 > 0 & p0 < 1))
  skip_if_not_installed("tweedie")
  expect_equal(tweedie::ptweedie(0, mu = mu[1], phi = a$args$phi, power = a$args$power),
               p0[1], tolerance = 1e-6)
})

test_that("#1149 family_id 7 (beta) mean-precision shapes", {
  ## cpp fid 7: mu = invlogit(eta), a = mu * phi, b = (1 - mu) * phi.
  phi <- 12
  fit <- mock_one(7L, report = list(phi_beta = phi))
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
  mu <- 1 / (1 + exp(-eta_toy))
  expect_identical(a$dist, "beta")
  expect_equal(a$args$shape1, mu * phi)
  expect_equal(a$args$shape2, (1 - mu) * phi)
  expect_equal(a$args$shape1 + a$args$shape2, rep(phi, 3))
  expect_equal(a$args$shape1 / (a$args$shape1 + a$args$shape2), mu)
  expect_equal(stats::pbeta(0.4, a$args$shape1, a$args$shape2),
               stats::pbeta(0.4, mu * phi, (1 - mu) * phi))
  expect_length(gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1)$args, 0L)
})

test_that("#1149 family_id 8 (beta-binomial) Beta-mixing shapes", {
  phi <- 4
  fit <- mock_one(8L, report = list(phi_betabinom = phi))
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
  mu <- 1 / (1 + exp(-eta_toy))
  expect_true(is.na(a$dist))
  expect_equal(a$args$shape1, mu * phi)
  expect_equal(a$args$shape2, (1 - mu) * phi)
  ## Beta-binomial P(Y = 0 | N = 1) = E(1 - p) = b / (a + b) = 1 - mu.
  expect_equal(a$args$shape2 / (a$args$shape1 + a$args$shape2), 1 - mu)
})

test_that("#1149 family_id 10 (zero-truncated poisson) untruncated lambda", {
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(mock_one(10L), 1, eta = eta_toy)
  expect_identical(a$dist, "pois")
  expect_equal(a$args$lambda, exp(eta_toy))
  ## Truncated CDF by hand: F(y) = (ppois(y) - e^-lambda) / (1 - e^-lambda).
  lam <- a$args$lambda
  p0 <- stats::ppois(0, lam)
  expect_equal(p0, exp(-lam))
  trunc_cdf <- (stats::ppois(2, lam) - p0) / (1 - p0)
  expect_true(all(trunc_cdf > 0 & trunc_cdf <= 1))
  expect_equal((stats::ppois(1, lam) - p0) / (1 - p0),
               lam * exp(-lam) / (1 - exp(-lam)), tolerance = 1e-12)
})

test_that("#1149 family_id 12 (delta_lognormal) sdlog and meanlog = eta", {
  fit <- mock_one(12L, report = list(sigma_lognormal_delta = 0.6))
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
  expect_identical(a$dist, "lnorm")
  expect_equal(a$args$sdlog, 0.6)
  expect_equal(a$args$meanlog, eta_toy)
  ## cpp fid 12: log y | y > 0 ~ Normal(eta, sigma): plnorm(y) = pnorm(log y).
  expect_equal(stats::plnorm(2, a$args$meanlog, a$args$sdlog),
               stats::pnorm((log(2) - eta_toy) / 0.6), tolerance = 1e-12)
  expect_match(a$note, "plogis")
})

ordinal_fit <- function(fid) {
  ## Two traits: trait 1 has 2 extra cutpoints, trait 2 has 1 (K = 4 and 3).
  traits <- data.frame(name = c("o1", "o2"), family_id = fid, link_id = 0L,
                       stringsAsFactors = FALSE)
  traits$gen <- list(function(e) rep(1, length(e)), function(e) rep(1, length(e)))
  fit <- make_mock_fit(traits, report = list(ordinal_cutpoints = c(0.8, 1.9, 1.1)))
  fit$tmb_data$n_ordinal_cuts_per_trait <- c(2L, 1L)
  fit$tmb_data$ordinal_offset_per_trait <- c(0L, 2L)
  fit
}

test_that("#1149 family_id 14 (ordinal_probit) cutpoints and pnorm(tau - eta)", {
  fit <- ordinal_fit(14L)
  a1 <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
  a2 <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 2, eta = eta_toy)
  ## tau_1 = 0 fixed; remaining cutpoints read per trait via the offsets.
  expect_equal(a1$args$cutpoints, c(0, 0.8, 1.9))
  expect_equal(a2$args$cutpoints, c(0, 1.1))
  expect_equal(a1$args$mean, eta_toy)
  expect_true(is.na(a1$dist))
  ## P(y <= k) = pnorm(tau_k - eta); the K categories sum to one.
  cdf <- outer(eta_toy, c(a1$args$cutpoints, Inf), function(e, tau) stats::pnorm(tau - e))
  expect_equal(unname(cdf[, 1]), stats::pnorm(0 - eta_toy))
  expect_equal(unname(cdf[, ncol(cdf)]), rep(1, 3))
  expect_match(a1$note, "pnorm")
})

test_that("#1149 family_id 20 (ordinal_logit) same cutpoints, logistic CDF", {
  fit <- ordinal_fit(20L)
  a1 <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
  a2 <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 2)
  expect_equal(a1$args$cutpoints, c(0, 0.8, 1.9))
  expect_equal(a2$args$cutpoints, c(0, 1.1))
  expect_equal(a1$args$mean, eta_toy)
  expect_null(a2$args$mean)
  ## P(y <= 1) = plogis(0 - eta) = 1 / (1 + exp(eta)).
  expect_equal(stats::plogis(a1$args$cutpoints[1] - a1$args$mean),
               1 / (1 + exp(eta_toy)), tolerance = 1e-12)
  expect_match(a1$note, "plogis")
})

test_that("#1149 family_id 15 (nbinom1) size = mu / phi, mu = exp(eta)", {
  ## cpp fid 15: var - mu = phi * mu = mu^2 / size  =>  size = mu / phi.
  phi <- 0.8
  fit <- mock_one(15L, report = list(phi_nbinom1 = phi))
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1, eta = eta_toy)
  mu <- exp(eta_toy)
  expect_identical(a$dist, "nbinom")
  expect_equal(a$args$mu, mu)
  expect_equal(a$args$size, mu / phi)
  expect_equal(mu + mu^2 / a$args$size, mu * (1 + phi))
  expect_equal(stats::pnbinom(0, size = a$args$size, mu = a$args$mu),
               (1 / (1 + phi))^(mu / phi), tolerance = 1e-12)
  ## Without eta the size is mean-dependent and withheld.
  expect_length(gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1)$args, 0L)
})

test_that("#1149 unsupported family_id falls through with a note", {
  a <- gllvmTMB:::.gllvmTMB_family_cdf_args(mock_one(16L), 1, eta = eta_toy)
  expect_length(a$args, 0L)
  expect_match(a$note, "No scalar CDF conversion")
})
