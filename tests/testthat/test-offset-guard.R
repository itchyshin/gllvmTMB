## `offset()` in a top-level formula must not be silently ignored.
##
## The lv sub-formula has rejected offsets since R/lv-predictor.R:156 ("Offset
## handling for latent-score means has not been derived"), and the design docs
## list offsets among the terms that still reject. The top-level fixed-effect
## formula never received the equivalent guard, so `offset(x)` was accepted and
## then dropped by model.matrix() -- the user got a different model from the one
## they wrote, with no error and no warning. Measured before the fix: logLik
## identical with and without a *varying* offset, difference exactly 0.
##
## These tests are deliberately cheap and un-gated: the failure they guard is
## silent, so it must be caught on an ordinary run.

.og_data <- function(n = 30, seed = 4) {
  set.seed(seed)
  d <- data.frame(site = factor(seq_len(n)), z = rnorm(n))
  d$t1 <- 0.4 + 0.7 * d$z + rnorm(n, sd = 0.4)
  d$t2 <- -0.2 + 0.3 * d$z + rnorm(n, sd = 0.5)
  # A VARYING offset. A constant one would be absorbed by the intercept, so a
  # test built on one would pass even if the offset were ignored.
  d$offv <- rnorm(n, 0, 3)
  d
}

test_that("offset() in a wide traits() formula is rejected, not ignored", {
  d <- .og_data()
  expect_error(
    gllvmTMB(
      traits(t1, t2) ~ 1 + z + offset(offv),
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    "offset"
  )
})

test_that("offset() in a long-format formula is rejected, not ignored", {
  d <- .og_data()
  long <- data.frame(
    site  = rep(d$site, 2L),
    trait = factor(rep(c("t1", "t2"), each = nrow(d))),
    z     = rep(d$z, 2L),
    offv  = rep(d$offv, 2L),
    value = c(d$t1, d$t2)
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + offset(offv),
      data = long, trait = "trait", unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    "offset"
  )
})

test_that("the rejection message points the user somewhere", {
  d <- .og_data()
  err <- tryCatch(
    gllvmTMB(
      traits(t1, t2) ~ 1 + z + offset(offv),
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    error = function(e) conditionMessage(e)
  )
  # It must say offsets are not supported, not merely that something failed.
  expect_match(err, "offset", ignore.case = TRUE)
  expect_match(err, "not (yet )?support|not implemented|cannot", ignore.case = TRUE)
})

test_that("a formula with no offset still fits (the guard is not over-broad)", {
  d <- .og_data()
  expect_no_error(
    suppressMessages(gllvmTMB(
      traits(t1, t2) ~ 1 + z,
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ))
  )
  # A variable merely NAMED offv is not an offset() call and must be unaffected.
  expect_no_error(
    suppressMessages(gllvmTMB(
      traits(t1, t2) ~ 1 + offv,
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ))
  )
})

test_that("the pre-existing lv offset guard keeps its own message", {
  # R/lv-predictor.R:156 owns this case. The new top-level guard must not
  # intercept it and replace a specific diagnosis with a generic one.
  d <- .og_data()
  err <- tryCatch(
    gllvmTMB(
      traits(t1, t2) ~ 1 + latent(0 + trait | site, d = 1, lv = ~ offset(z)),
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "lv", ignore.case = TRUE)
})
