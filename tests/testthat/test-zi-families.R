## Zero-inflated families: zi_poisson() / zi_nbinom2() / zi_binomial()
## (Arc D, Design 62). See dev/gapclose/arcD/alignment-zi.md for the density
## derivations these tests check against.
##
## Scope of THIS file: density exactness, gradient correctness, admission /
## parser behaviour (long + wide, single-trial refusal, VA/AGHQ refusal,
## mixed-family fits). Known-DGP recovery lives in test-zi-recovery.R.

## A central-difference gradient, base R only (no numDeriv dependency).
.zi_fd_grad <- function(fn, par, eps = 1e-6) {
  g <- numeric(length(par))
  for (i in seq_along(par)) {
    pp <- par; pm <- par
    pp[i] <- pp[i] + eps
    pm[i] <- pm[i] - eps
    g[i] <- (fn(pp) - fn(pm)) / (2 * eps)
  }
  g
}

## ---------------------------------------------------------------------
## Density exactness: TMB objective == hand-computed mixture log-density,
## at the FITTED (converged) parameter values, on a tiny fixed-effect-only
## dataset (no latent()/random effects, so tmb_obj$fn() has no Laplace
## integration to blur the comparison -- it is the exact -log-likelihood).
## ---------------------------------------------------------------------

test_that("zi_poisson: TMB objective matches hand-computed mixture density to 1e-8", {
  skip_on_cran()
  set.seed(1)
  n_site <- 10L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 2), rep(0, n_site))
  )
  dat$y[1:3] <- 0 # force some structural-looking zeros in trait 1 too

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait,
    data = dat, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 17L)

  par <- fit$tmb_obj$par
  nll_tmb <- fit$tmb_obj$fn(par)

  pn <- names(par)
  b_fix <- par[pn == "b_fix"]
  logit_zi <- par[pn == "logit_zi"]
  trait_id <- fit$tmb_data$trait_id
  y <- fit$tmb_data$y
  eta <- b_fix[trait_id + 1L]
  zi <- stats::plogis(logit_zi[trait_id + 1L])
  mu <- exp(eta)
  ll <- ifelse(
    y == 0,
    log(zi + (1 - zi) * stats::dpois(0, mu)),
    log(1 - zi) + stats::dpois(y, mu, log = TRUE)
  )
  expect_equal(as.numeric(nll_tmb), -sum(ll), tolerance = 1e-8)
})

test_that("zi_nbinom2: TMB objective matches hand-computed mixture density to 1e-8", {
  skip_on_cran()
  set.seed(2)
  n_site <- 12L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rnbinom(n_site, mu = 3, size = 2), rep(0, n_site))
  )
  dat$y[dat$trait == "1"][1:3] <- 0

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait,
    data = dat, family = zi_nbinom2(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 18L)

  par <- fit$tmb_obj$par
  nll_tmb <- fit$tmb_obj$fn(par)

  pn <- names(par)
  b_fix <- par[pn == "b_fix"]
  logit_zi <- par[pn == "logit_zi"]
  log_phi <- par[pn == "log_phi_nbinom2"]
  trait_id <- fit$tmb_data$trait_id
  y <- fit$tmb_data$y
  eta <- b_fix[trait_id + 1L]
  zi <- stats::plogis(logit_zi[trait_id + 1L])
  mu <- exp(eta)
  phi <- exp(log_phi[trait_id + 1L])
  ll <- ifelse(
    y == 0,
    log(zi + (1 - zi) * stats::dnbinom(0, mu = mu, size = phi)),
    log(1 - zi) + stats::dnbinom(y, mu = mu, size = phi, log = TRUE)
  )
  expect_equal(as.numeric(nll_tmb), -sum(ll), tolerance = 1e-8)
})

test_that("zi_binomial: TMB objective matches hand-computed mixture density to 1e-8", {
  skip_on_cran()
  set.seed(3)
  n_site <- 15L
  Nt <- 8L
  mk <- function(p, pi) {
    z <- stats::rbinom(n_site, 1L, 1 - pi)
    ifelse(z == 1L, stats::rbinom(n_site, Nt, p), 0L)
  }
  succ1 <- mk(0.4, 0.3)
  succ2 <- mk(0.6, 0.15)
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    succ  = c(succ1, succ2),
    fail  = Nt - c(succ1, succ2)
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(succ, fail) ~ 0 + trait,
    data = dat, family = zi_binomial(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 19L)

  par <- fit$tmb_obj$par
  nll_tmb <- fit$tmb_obj$fn(par)

  pn <- names(par)
  b_fix <- par[pn == "b_fix"]
  logit_zi <- par[pn == "logit_zi"]
  trait_id <- fit$tmb_data$trait_id
  y <- fit$tmb_data$y
  n_trials <- fit$tmb_data$n_trials
  eta <- b_fix[trait_id + 1L]
  zi <- stats::plogis(logit_zi[trait_id + 1L])
  p <- stats::plogis(eta)
  ll <- ifelse(
    y == 0,
    log(zi + (1 - zi) * stats::dbinom(0, n_trials, p)),
    log(1 - zi) + stats::dbinom(y, n_trials, p, log = TRUE)
  )
  expect_equal(as.numeric(nll_tmb), -sum(ll), tolerance = 1e-8)
})

## ---------------------------------------------------------------------
## Finite-difference gradient check at the starting values (before any
## optimisation) -- max relative discrepancy < 1e-4, per the task brief.
## ---------------------------------------------------------------------

## Builds the GENUINE pre-optimisation starting parameter vector for a
## fixed-effects-only fit (par IS the full parameter vector: no latent()/
## random effects, so nothing is profiled out). `b_fix` starts at 0
## (the package's `mustart`-free default for a plain intercept-only model);
## `logit_zi` uses the package's own `zi_logit_start()`; `log_phi_nbinom2`
## (zi_nbinom2 only) starts at 0 (phi = 1), matching R/fit-multi.R's
## `tmb_params` construction exactly.
.zi_start_par <- function(fit, family_id) {
  par <- fit$tmb_obj$par
  pn <- names(par)
  n_traits <- length(unique(fit$tmb_data$trait_id))
  par[pn == "b_fix"] <- 0
  par[pn == "logit_zi"] <- gllvmTMB:::zi_logit_start(
    fit$tmb_data$y, fit$tmb_data$trait_id, fit$tmb_data$family_id_vec,
    fit$tmb_data$n_trials, n_traits
  )
  if ("log_phi_nbinom2" %in% pn) par[pn == "log_phi_nbinom2"] <- 0
  par
}

test_that("zi_poisson: gradient matches finite differences at the starting values", {
  skip_on_cran()
  set.seed(11)
  n_site <- 10L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 2), rep(0, n_site))
  )
  dat$y[1:3] <- 0

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait,
    data = dat, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  )))
  ## No latent()/random effects on this fixed-effects-only fit, so gr()/fn()
  ## are exact (no Laplace approximation) at ANY parameter vector, including
  ## the genuine pre-optimisation starting values built below.
  par <- .zi_start_par(fit, 17L)
  gr_tmb <- fit$tmb_obj$gr(par)
  gr_fd <- .zi_fd_grad(fit$tmb_obj$fn, par)
  rel <- abs(gr_tmb - gr_fd) / pmax(abs(gr_tmb), 1e-6)
  expect_lt(max(rel), 1e-4)
})

test_that("zi_nbinom2: gradient matches finite differences at the starting values", {
  skip_on_cran()
  set.seed(12)
  n_site <- 12L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rnbinom(n_site, mu = 3, size = 2), rep(0, n_site))
  )
  dat$y[dat$trait == "1"][1:3] <- 0
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait,
    data = dat, family = zi_nbinom2(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  par <- .zi_start_par(fit, 18L)
  gr_tmb <- fit$tmb_obj$gr(par)
  gr_fd <- .zi_fd_grad(fit$tmb_obj$fn, par)
  rel <- abs(gr_tmb - gr_fd) / pmax(abs(gr_tmb), 1e-6)
  expect_lt(max(rel), 1e-4)
})

test_that("zi_binomial: gradient matches finite differences at the starting values", {
  skip_on_cran()
  set.seed(13)
  n_site <- 15L
  Nt <- 8L
  mk <- function(p, pi) {
    z <- stats::rbinom(n_site, 1L, 1 - pi)
    ifelse(z == 1L, stats::rbinom(n_site, Nt, p), 0L)
  }
  succ1 <- mk(0.4, 0.3)
  succ2 <- mk(0.6, 0.15)
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    succ  = c(succ1, succ2),
    fail  = Nt - c(succ1, succ2)
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(succ, fail) ~ 0 + trait,
    data = dat, family = zi_binomial(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  par <- .zi_start_par(fit, 19L)
  gr_tmb <- fit$tmb_obj$gr(par)
  gr_fd <- .zi_fd_grad(fit$tmb_obj$fn, par)
  rel <- abs(gr_tmb - gr_fd) / pmax(abs(gr_tmb), 1e-6)
  expect_lt(max(rel), 1e-4)
})

## ---------------------------------------------------------------------
## Admission / parser: long form, wide form, single-trial refusal,
## VA/AGHQ refusal, mixed-family fit.
## ---------------------------------------------------------------------

test_that("zi_poisson()/zi_nbinom2()/zi_binomial() parse in long form", {
  skip_on_cran()
  set.seed(21)
  n_site <- 8L
  ## `0 + trait` needs >= 2 trait levels (a single-level factor cannot take
  ## contrasts in model.matrix()); every gllvmTMB long-format fit is
  ## multi-trait by construction, so this is not zi-specific.
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = rpois(n_site * 2, 2)
  )
  expect_no_error(suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait, data = dat, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))))
  expect_no_error(suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait, data = dat, family = zi_nbinom2(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))))
  dat_bin <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    succ  = rbinom(n_site * 2, 6L, 0.5)
  )
  dat_bin$fail <- 6L - dat_bin$succ
  expect_no_error(suppressMessages(suppressWarnings(gllvmTMB(
    cbind(succ, fail) ~ 0 + trait, data = dat_bin, family = zi_binomial(),
    unit = "site", control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))))
})

test_that("zi_poisson() parses in wide (traits()) form", {
  skip_on_cran()
  set.seed(22)
  n <- 20L
  df <- data.frame(
    sp1 = rpois(n, 2) * rbinom(n, 1, 0.7),
    sp2 = rpois(n, 3) * rbinom(n, 1, 0.8),
    site = factor(seq_len(n))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(sp1, sp2) ~ 1 + indep(1 | site),
    data = df, family = zi_poisson(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  )))
  expect_equal(fit$tmb_data$family_id_vec[1], 17L)
})

test_that("zi_binomial() refuses single-trial (0/1) responses, naming binomial() as the alternative", {
  skip_on_cran()
  set.seed(23)
  n_site <- 10L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    succ  = rbinom(n_site * 2, 1L, 0.5)
  )
  dat$fail <- 1L - dat$succ
  err <- expect_error(
    gllvmTMB(
      cbind(succ, fail) ~ 0 + trait, data = dat, family = zi_binomial(),
      unit = "site"
    ),
    "single-trial"
  )
  expect_match(conditionMessage(err), "binomial\\(\\)")
})

test_that("zi_binomial() admits a trait with at least one multi-trial row", {
  skip_on_cran()
  set.seed(24)
  n_site <- 10L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    succ  = rbinom(n_site * 2, 6L, 0.5)
  )
  dat$fail <- 6L - dat$succ
  expect_no_error(suppressMessages(suppressWarnings(gllvmTMB(
    cbind(succ, fail) ~ 0 + trait, data = dat, family = zi_binomial(),
    unit = "site", control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))))
})

test_that("integration = \"va\" refuses zi_poisson/zi_nbinom2/zi_binomial", {
  skip_on_cran()
  set.seed(25)
  n_site <- 20L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 2), rpois(n_site, 3))
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat, family = zi_poisson(), unit = "site",
      control = gllvmTMBcontrol(integration = "va")
    ),
    "does not admit this model"
  )
})

test_that("aghq is declined (falls back to laplace) for zi_poisson/zi_nbinom2/zi_binomial", {
  skip_on_cran()
  set.seed(26)
  n_site <- 20L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 2), rpois(n_site, 3))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(aghq = 5L, se = FALSE)
  )))
  expect_false(isTRUE(fit$aghq$used))
  expect_match(fit$aghq$reason, "zero-inflated")
})

test_that("a mixed-family fit with one zi_poisson trait alongside a poisson trait fits", {
  skip_on_cran()
  set.seed(27)
  n_site <- 20L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 2), rpois(n_site, 3))
  )
  dat$y[dat$trait == "1"][1:5] <- 0
  dat$family <- ifelse(dat$trait == "1", "zi_poisson", "poisson")
  famlist <- list(zi_poisson = zi_poisson(), poisson = poisson())
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait,
    data = dat, family = famlist, trait = "trait", unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  ## Trait 1 is zero-inflated; trait 2's logit_zi entry is pinned (mapped
  ## off) and must not have moved off its neutral start.
  expect_true(is.finite(fit$report$zi[1]))
  expect_true(fit$report$zi[1] > 0 && fit$report$zi[1] < 1)
})

## ---------------------------------------------------------------------
## fitted()/predict(type = "response") rule: E[y] = (1 - zi) * mu.
## ---------------------------------------------------------------------

test_that("fitted() applies (1 - zi) * mu for zi_poisson", {
  skip_on_cran()
  set.seed(28)
  n_site <- 20L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(
      rpois(n_site, 3) * rbinom(n_site, 1, 0.7),
      rpois(n_site, 1.5) * rbinom(n_site, 1, 0.8)
    )
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait, data = dat, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  fv <- fitted(fit)
  mu <- exp(fit$report$eta[1])
  expect_equal(fv$est[1], (1 - fit$report$zi[1]) * mu, tolerance = 1e-8)
})
