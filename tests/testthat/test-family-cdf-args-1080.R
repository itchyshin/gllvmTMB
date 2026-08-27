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
