## Issue #1356: count and binomial families need an early response-support
## check. A negative y used to surface only as "All 1 restarts failed."; a
## non-integer y fitted silently for poisson/nbinom2 and binomial. zi_*,
## censored and truncated families already reject both. Sibling gaps closed
## here: nbinom1 (same count support), betabinomial (same integrality as
## binomial), tweedie (y >= 0; continuous, so non-integers stay valid).

sim_1356 <- function(n = 40L, p = 4L, seed = 1L) {
  set.seed(seed)
  d <- expand.grid(
    unit = factor(seq_len(n)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  z <- stats::rnorm(n)
  eta <- 0.5 + 0.4 * c(1, 0.7, -0.5, 0.3)[as.integer(d$trait)] *
    z[as.integer(d$unit)]
  d$value <- stats::rpois(nrow(d), exp(eta))
  d
}

sim_1356_bin <- function(n = 40L, p = 4L, seed = 1L) {
  d <- sim_1356(n = n, p = p, seed = seed)
  z <- stats::rnorm(n)
  set.seed(seed)
  eta <- 0.5 + 0.4 * c(1, 0.7, -0.5, 0.3)[as.integer(d$trait)] *
    z[as.integer(d$unit)]
  d$value <- stats::rbinom(nrow(d), 1L, stats::plogis(eta))
  d
}

fit_1356 <- function(dat, family, weights = NULL) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, unit = "unit", trait = "trait", family = family,
    weights = weights,
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

test_that("#1356 poisson() and nbinom2() abort on a negative response", {
  dat <- sim_1356()
  dat$value[1] <- -1
  expect_error(fit_1356(dat, poisson()), "poisson.*non-negative integer")
  expect_error(fit_1356(dat, nbinom2()), "nbinom2.*non-negative integer")
})

test_that("#1356 poisson() and nbinom2() abort on a non-integer response", {
  dat <- sim_1356()
  dat$value <- dat$value + 0.5
  expect_error(fit_1356(dat, poisson()), "poisson.*non-negative integer")
  expect_error(fit_1356(dat, nbinom2()), "nbinom2.*non-negative integer")
})

test_that("#1356 the abort is the support check, not a failed-restart message", {
  dat <- sim_1356()
  dat$value[1] <- -1
  err <- tryCatch(fit_1356(dat, poisson()), error = function(e) e)
  expect_false(inherits(err, "gllvmTMB_all_restarts_failed"))
  expect_match(conditionMessage(err), "Round or recode")
})

test_that("#1356 valid counts still fit with poisson() and nbinom2()", {
  skip_on_cran()
  dat <- sim_1356()
  fp <- fit_1356(dat, poisson())
  expect_equal(fp$opt$convergence, 0L)
  fn <- fit_1356(dat, nbinom2())
  expect_true(is.finite(as.numeric(logLik(fn))))
})

test_that("#1356 binomial() aborts on a negative or non-integer response", {
  dat <- sim_1356_bin()
  dat$value[1] <- -1
  expect_error(fit_1356(dat, binomial()), "Binomial rows.*non-negative integer")
  dat <- sim_1356_bin()
  dat$value[1:5] <- 0.5
  expect_error(fit_1356(dat, binomial()), "Binomial rows.*non-negative integer")
})

test_that("#1356 binomial() refuses a proportion plus weights", {
  dat <- sim_1356_bin()
  dat$n <- 10L
  dat$value <- dat$value / dat$n
  err <- tryCatch(fit_1356(dat, binomial(), weights = dat$n), error = function(e) e)
  expect_false(inherits(err, "gllvmTMB_all_restarts_failed"))
  expect_match(conditionMessage(err), "non-negative integer")
  expect_match(conditionMessage(err), "proportion")
})

test_that("#1356 binomial() still fits integer successes", {
  skip_on_cran()
  dat <- sim_1356_bin()
  fb <- fit_1356(dat, binomial())
  expect_equal(fb$opt$convergence, 0L)
})

test_that("#1356 nbinom1() has the same count support as poisson()/nbinom2()", {
  dat <- sim_1356()
  dat$value[1] <- -1
  expect_error(fit_1356(dat, nbinom1()), "nbinom1.*non-negative integer")
  dat <- sim_1356()
  dat$value <- dat$value + 0.5
  expect_error(fit_1356(dat, nbinom1()), "nbinom1.*non-negative integer")
})

test_that("#1356 betabinomial() aborts on a non-integer response", {
  dat <- sim_1356_bin()
  dat$value[1:5] <- 0.5
  expect_error(fit_1356(dat, betabinomial()), "Beta-binomial rows.*non-negative integer")
  dat <- sim_1356_bin()
  dat$value[1] <- -1
  expect_error(fit_1356(dat, betabinomial()), "Beta-binomial rows.*non-negative integer")
})

test_that("#1356 tweedie() aborts on a negative response", {
  dat <- sim_1356()
  dat$value <- pmax(dat$value + 0.25, 0.25)
  dat$value[1] <- -1
  err <- tryCatch(fit_1356(dat, tweedie()), error = function(e) e)
  expect_false(inherits(err, "gllvmTMB_all_restarts_failed"))
  expect_match(conditionMessage(err), "tweedie.*non-negative")
})
