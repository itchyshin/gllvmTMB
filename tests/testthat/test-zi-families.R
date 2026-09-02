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

test_that("aghq DECLINES (does not error/refuse) for zi_poisson/zi_nbinom2/zi_binomial, with a reason-specific warning (R3/S2)", {
  skip_on_cran()
  set.seed(26)
  n_site <- 20L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 2), rpois(n_site, 3))
  )
  ## R3 (2026-09-02 review): AGHQ DECLINES to a plain Laplace fit here --
  ## it does not error/refuse, unlike integration = "va" and
  ## estimator = "mspl". This is consistent with AGHQ's existing
  ## architecture: every OTHER ineligible model (e.g. multinomial rows,
  ## one clause above this one in R/fit-multi.R) declines the same way,
  ## none error. NEWS/Design 02/03/register previously (incorrectly)
  ## called this a "refusal" -- corrected.
  ##
  ## CI fix (2026-09-02, second review): the decline warning is
  ## `cli_warn(.frequency = "once", .frequency_id =
  ## "gllvmTMB-aghq-ineligible")`, which fires AT MOST ONCE PER R SESSION
  ## across the ENTIRE test suite, not just this file -- `rlang` tracks it
  ## in `warning_freq_env`, keyed by `.frequency_id`, independent of which
  ## test triggered it first. Under `R CMD check` (one process for the
  ## whole suite) some OTHER test elsewhere routinely exercises this exact
  ## decline path first (any AGHQ-ineligible fit shares the same id, e.g.
  ## a `latent()`-with-default-Psi + `aghq` fit for an unrelated family),
  ## so by the time this file's own test ran, the warning was already
  ## silent -- reproduced: `expect_warning()` saw `w <- NULL`. Locally,
  ## `testthat::test_file()` on this file ALONE never hits that (this is
  ## the first and only trigger in an isolated process), which is why it
  ## passed there and failed only under the full suite.
  ##
  ## Fixed two ways: (1) `rlang::reset_warning_verbosity()` clears this
  ## file's OWN prior use of the id (defence in depth against reordering
  ## within the file) and, more importantly, makes this test not depend on
  ## whether anything ELSE in the session already consumed it -- resetting
  ## the id is a documented rlang/cli mechanism (`?rlang::reset_warning_verbosity`),
  ## not a private hack, and it only clears state cli itself owns; (2) the
  ## PRIMARY assertions are now structural (`fit$aghq$used`, `fit$aghq$reason`),
  ## which do not depend on the warning firing at all -- the warning-text
  ## checks are additional, not load-bearing, per the review's own
  ## instruction not to rely solely on a warning.
  rlang::reset_warning_verbosity("gllvmTMB-aghq-ineligible")
  w <- NULL
  fit <- withCallingHandlers(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat, family = zi_poisson(), unit = "site",
      control = gllvmTMBcontrol(aghq = 5L, se = FALSE)
    ),
    warning = function(cond) {
      if (is.null(w) && grepl("AGHQ did not run", conditionMessage(cond))) {
        w <<- cond
      }
      invokeRestart("muffleWarning")
    }
  )
  ## Structural assertions -- true regardless of whether the once-per-
  ## session warning fired (deterministic even if the reset above ever
  ## stops working, e.g. a future rlang change).
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_false(isTRUE(fit$aghq$used))
  expect_match(fit$aghq$reason, "zero-inflated")
  ## Warning-text assertions -- should hold given the reset above; failing
  ## HERE (with the structural checks above still green) would mean the
  ## reset itself stopped working, not that AGHQ started erroring.
  expect_false(is.null(w), info = "the once-per-session AGHQ decline warning did not fire even after rlang::reset_warning_verbosity()")
  if (!is.null(w)) {
    expect_match(conditionMessage(w), "not yet supported by AGHQ")
    ## Regression guard: the OLD action line named unique = FALSE, which
    ## this fit already used -- must not appear for the zi reason.
    expect_false(grepl("Use.*latent.*unique = FALSE", conditionMessage(w)))
  }
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

## ---------------------------------------------------------------------
## Review fixes (2026-09-02 Opus verification, dev/gapclose/arcD/D1-report.md
## "Review fixes" section has the full findings table).
## ---------------------------------------------------------------------

## R1: predictive_check(type = "rootogram") previously refused zi_poisson/
## zi_nbinom2 outright (R/predictive-diagnostics.R's count_rows filter
## never included fid 17/18). The rootogram is draws-based (simulate() vs
## observed), and simulate() already drew the mixture correctly, so the
## fix is the filter alone.
test_that("rootogram works on zi_poisson and its zero bar reflects the mixture, not the naive count-only expectation", {
  skip_on_cran()
  set.seed(41)
  n_site <- 60L
  ## A high structural-zero trait so the "mixture zero bar > naive Poisson
  ## zero bar" contrast is unambiguous.
  pi_true <- 0.5
  mu_true <- 3
  y <- rpois(n_site, mu_true) * rbinom(n_site, 1L, 1 - pi_true)
  dat <- data.frame(
    site  = factor(seq_len(n_site)),
    trait = factor(rep(1, n_site)),
    y     = y
  )
  ## Needs >= 2 trait levels for `0 + trait` model.matrix(); pad with a
  ## second, unrelated zi_poisson trait so this stays a pure zi_poisson fit.
  dat2 <- rbind(
    dat,
    data.frame(site = dat$site, trait = factor(rep(2, n_site)),
               y = rpois(n_site, 4))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait, data = dat2, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)

  p_root <- predictive_check(
    fit, type = "rootogram", ndraws = 30L, seed = 42L, max_count = 8L
  )
  expect_s3_class(p_root, "ggplot")
  root_meta <- attr(p_root, "gllvmTMB_diagnostic")
  expect_true(all(root_meta$data$family == "zi_poisson"))
  expect_silent(ggplot2::ggplot_build(p_root))

  ## The zero bar's "expected" (simulated-mean) count must exceed a naive
  ## Poisson-only expectation at the fitted mu for trait 1 -- i.e. the
  ## rootogram's expected zero count reflects zi + (1-zi)*exp(-mu), not
  ## just exp(-mu). trait 1 is the high-zi trait built above.
  zero_row <- root_meta$data[
    root_meta$data$trait == "1" & root_meta$data$count_label == "0",
  ]
  expect_equal(nrow(zero_row), 1L)
  tid1 <- which(levels(dat2$trait) == "1") - 1L
  mu1 <- exp(fit$report$eta[fit$tmb_data$trait_id == tid1][1])
  naive_zero_expected <- n_site * dpois(0, mu1)
  expect_gt(zero_row$expected, naive_zero_expected * 1.5)
})

## R2: extract_Sigma(link_residual = "auto") (the default) previously fell
## through link_residual_per_trait()'s terminal `else` for fid 17/18/19,
## returning NA with a warning -- unlike every other admitted family.
test_that("extract_Sigma() reports a finite link residual for zi_poisson/zi_nbinom2/zi_binomial, no warning", {
  skip_on_cran()
  set.seed(43)
  n_site <- 60L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 3) * rbinom(n_site, 1, 0.7), rpois(n_site, 2) * rbinom(n_site, 1, 0.8))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_no_warning(sig <- suppressMessages(extract_Sigma(fit, link_residual = "auto")))
  expect_true(all(is.finite(diag(sig$Sigma))))
})

## S1: predict(type = "response") on newdata, via the per-row-family
## branch (.gllvmTMB_newdata_family_ids(), the branch every MIXED-family
## fit's newdata prediction must take, since mixed fits require a family
## column), previously did not apply (1 - zi) and returned the naive
## count-only mean for zi_* rows.
test_that("predict(type = 'response') on newdata applies (1 - zi) for a mixed zi_poisson/poisson fit", {
  skip_on_cran()
  set.seed(44)
  n_site <- 40L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 3) * rbinom(n_site, 1, 0.6), rpois(n_site, 2))
  )
  dat$family <- ifelse(dat$trait == "1", "zi_poisson", "poisson")
  famlist <- list(zi_poisson = zi_poisson(), poisson = poisson())
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait, data = dat, family = famlist, trait = "trait", unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  nd <- data.frame(
    site = factor(1, levels = levels(dat$site)),
    trait = factor("1", levels = levels(dat$trait)),
    family = "zi_poisson"
  )
  pr <- predict(fit, newdata = nd, type = "response")
  tid1 <- which(levels(dat$trait) == "1") - 1L
  eta1 <- fit$report$eta[fit$tmb_data$trait_id == tid1][1]
  mu1 <- exp(eta1)
  zi1 <- fit$report$zi[1]
  expect_equal(pr$est[1], (1 - zi1) * mu1, tolerance = 1e-6)
  ## Regression guard: this used to equal the NAIVE mu (no (1-zi) factor).
  expect_false(isTRUE(all.equal(pr$est[1], mu1, tolerance = 1e-6)))
})

## R4: check_gllvmTMB() previously had NO detector for a runaway per-trait
## NB2 dispersion (phi -> Poisson boundary); a fit with a 2.66e6 phi against
## a true 6 reported ZERO non-PASS rows. New boundary_phi_nbinom2_<trait>
## row, WARN when phi >= phi_nbinom2_ceiling_thresh (default 1e4).
test_that("check_gllvmTMB() flags a phi_nbinom2 runaway at the numerical ceiling", {
  skip_on_cran()
  chk_ok <- gllvmTMB:::.gllvmTMB_check_row(
    "boundary_phi_nbinom2_x", "PASS", "5", "1e4", "", ""
  )
  expect_true("component" %in% names(chk_ok))

  set.seed(303)
  n_site <- 400L
  n_trait <- 6L
  beta_true <- c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)
  lambda_true <- c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35)
  pi_true <- c(0.1, 0.2, 0.3, 0.4, 0.15, 0.25)
  phi_true <- c(4, 5, 3, 6, 4, 5)
  u <- rnorm(n_site)
  eta <- outer(u, lambda_true) + matrix(beta_true, n_site, n_trait, byrow = TRUE)
  mu <- exp(eta)
  z <- matrix(rbinom(n_site * n_trait, 1, rep(1 - pi_true, each = n_site)), n_site, n_trait)
  Y <- matrix(
    rnbinom(n_site * n_trait, mu = as.vector(mu), size = rep(phi_true, each = n_site)),
    n_site, n_trait
  ) * z
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), n_trait)),
    trait = factor(rep(seq_len(n_trait), each = n_site)),
    y     = as.vector(Y)
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat, family = zi_nbinom2(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  chk <- check_gllvmTMB(fit)
  phi_rows <- chk[grepl("^boundary_phi_nbinom2_", chk$component), ]
  expect_equal(nrow(phi_rows), 6L)
  ## This exact seed reproduces a real runaway (trait 4, phi_hat ~ 2.66e6
  ## against true 6) -- at least one WARN is expected, not a tautology.
  expect_true(any(phi_rows$status == "WARN"))
})
