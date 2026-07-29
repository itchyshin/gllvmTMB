## Fast, ALWAYS-RUN pins for the default missing-response contract.
##
## Why this file exists, and why nothing in it is heavy-gated:
## the package's proofs that the default retains every observed cell live in
## test-missing-response-traits.R / test-missing-response-gaussian.R, and every one of
## those blocks is behind skip_if_not_heavy() -- so they do not run in an ordinary
## devtools::test() or on a routine PR. The contract below is the single most
## user-visible property of the missing-data layer, so it gets a cheap guard that
## always runs. Keep these fits tiny; if one ever becomes slow, shrink it rather
## than gating it.

.cw_data <- function(n = 30, seed = 11) {
  set.seed(seed)
  d <- data.frame(site = factor(seq_len(n)), z = rnorm(n))
  d$t1 <- 0.4 + 0.7 * d$z + rnorm(n, sd = 0.4)
  d$t2 <- -0.2 + 0.3 * d$z + rnorm(n, sd = 0.5)
  d
}

.cw_fit <- function(d, ...) {
  gllvmTMB(
    traits(t1, t2) ~ 1 + z,
    data = d, unit = "site", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE),
    ...
  )
}

test_that("the default drops the missing CELL, not the whole unit", {
  d <- .cw_data()
  fit_full <- suppressMessages(.cw_fit(d))
  expect_identical(nobs(fit_full), 60L) # 30 units x 2 traits

  # One missing value in unit 1's t1. Unit 1's t2 is still observed.
  d_na <- d
  d_na$t1[1] <- NA
  fit_na <- suppressMessages(.cw_fit(d_na))

  # Cell-wise => 59. Listwise/complete-case (dropping the whole unit) => 58.
  # This is the contract: a unit keeps every trait it does have.
  expect_identical(nobs(fit_na), 59L)
})

test_that("the default reports the dropped cells at call time", {
  d <- .cw_data()
  d$t1[1] <- NA
  d$t2[2] <- NA

  msgs <- character(0)
  withCallingHandlers(
    .cw_fit(d),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  # The user must be told something was dropped, and how much.
  hit <- grep("dropp", msgs, ignore.case = TRUE, value = TRUE)
  expect_gt(length(hit), 0L)
  expect_match(paste(hit, collapse = " "), "2", fixed = TRUE)
  # The message says "cell" -- it must not describe this as dropping rows/units.
  expect_match(paste(hit, collapse = " "), "cell", ignore.case = TRUE)
})

test_that("response='include' reaches the same optimum as the default 'drop'", {
  # The repo pins this for Gaussian wide only, behind the heavy gate. This is the
  # cheap always-on version: masking and omitting the same cells must agree.
  d <- .cw_data()
  d$t1[1:2] <- NA
  d$t2[3] <- NA

  fit_drop <- suppressMessages(.cw_fit(d, missing = miss_control(response = "drop")))
  fit_inc  <- suppressMessages(.cw_fit(d, missing = miss_control(response = "include")))

  expect_equal(
    as.numeric(stats::logLik(fit_drop)),
    as.numeric(stats::logLik(fit_inc)),
    tolerance = 1e-6
  )
  # Both fits are informed by exactly the observed cells.
  expect_identical(nobs(fit_drop), nobs(fit_inc))
})

test_that("exactly one mi() term is required (scope guard is enforced)", {
  # The article scopes the modelled-missing-predictor workflow to one predictor.
  # Nothing in the missing-data test files pinned that guard, so a refactor could
  # silently drop it and turn a documented boundary into an overclaim.
  set.seed(3)
  n <- 40
  d <- data.frame(site = factor(seq_len(n)), z = rnorm(n))
  d$x1 <- 0.5 * d$z + rnorm(n, sd = 0.6)
  d$x2 <- -0.3 * d$z + rnorm(n, sd = 0.6)
  d$t1 <- 0.4 + 0.6 * d$x1 + 0.2 * d$x2 + rnorm(n, sd = 0.4)
  d$t2 <- -0.2 + 0.3 * d$x1 - 0.4 * d$x2 + rnorm(n, sd = 0.5)
  d$x1[1:4] <- NA
  d$x2[5:8] <- NA

  expect_error(
    gllvmTMB(
      traits(t1, t2) ~ 1 + mi(x1) + mi(x2),
      data = d, unit = "site", family = gaussian(),
      impute = list(x1 = x1 ~ z, x2 = x2 ~ z),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    "exactly one"
  )
})
