## tweedie(p = ...) fixes the Tweedie power a priori (1 < p < 2), mirroring
## student(df = ...). The power, dispersion, and any random-effect variance sit
## on a shared ridge, so fixing p is the standard stabilisation. Implemented as a
## per-trait pin of logit_p_tweedie = qlogis(p - 1) (mapped off).
##
## NOTE: fixing p does NOT unlock tweedie random SLOPES -- an empirical check
## (docs/dev-log/after-task/2026-07-12-re-surface-arc-start.md) found the ~44%
## slope-variance over-estimate persists with p fixed, so tweedie stays off the
## random-slope allowlist. This feature is for tweedie intercept / fixed-effect
## fits.

test_that("tweedie(p = ...) validates the power argument", {
  expect_error(tweedie(p = 2.5), "strictly between 1 and 2")
  expect_error(tweedie(p = 1), "strictly between 1 and 2")
  expect_error(tweedie(p = c(1.5, 1.6)), "strictly between 1 and 2")
  expect_silent(tweedie(p = 1.5))
  expect_null(tweedie()$p)
  expect_equal(tweedie(p = 1.6)$p, 1.6)
})

test_that("tweedie(p = ...) pins logit_p_tweedie (mapped off); free p is estimated", {
  testthat::skip_on_cran()
  set.seed(3); n <- 300L
  df <- data.frame(trait = factor(rep(c("t1", "t2"), each = n)),
                   unit = factor(rep(seq_len(n), 2)), x = stats::rnorm(2 * n))
  df$value <- tweedie::rtweedie(2 * n, mu = exp(0.3 + 0.2 * df$x), phi = 1.4, power = 1.6)
  fix <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + x, data = df, unit = "unit", family = tweedie(p = 1.6))))
  free <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + x, data = df, unit = "unit", family = tweedie())))
  expect_equal(fix$opt$convergence, 0L)
  ## p pinned -> logit_p_tweedie fully mapped off (present in env$map, all-NA).
  expect_true(all(is.na(as.integer(fix$tmb_obj$env$map$logit_p_tweedie))))
  ## free -> logit_p_tweedie is estimable. TMB represents a FREE parameter by
  ## OMITTING it from env$map (NULL), not by listing it non-NA; so "mapped off"
  ## means a present-and-all-NA map entry, and NULL means free. The old check
  ## `all(is.na(as.integer(NULL)))` was vacuously TRUE and thus fragile.
  free_map <- free$tmb_obj$env$map$logit_p_tweedie
  expect_false(!is.null(free_map) && all(is.na(as.integer(free_map))))
  expect_true("logit_p_tweedie" %in% names(free$tmb_obj$env$par))
})
