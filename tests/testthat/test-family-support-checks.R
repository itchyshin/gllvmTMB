## Issue #1356: plain poisson() / nbinom2() had no response-support check
## (a negative y surfaced only as "All 1 restarts failed."; a non-integer y
## fitted silently), unlike zi_poisson()/zi_nbinom2(). Scope here is poisson
## and nbinom2 only; binomial integrality is a separate ruling.

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

fit_1356 <- function(dat, family) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, unit = "unit", trait = "trait", family = family,
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

test_that("#1356 tweedie() aborts on a negative response", {
  dat <- sim_1356()
  dat$value[1] <- -1
  expect_error(
    fit_1356(dat, tweedie()),
    class = "gllvmTMB_tweedie_negative_y"
  )
})
