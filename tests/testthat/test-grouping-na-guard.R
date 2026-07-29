## A missing grouping label must not be modelled as a group.
##
## Before this guard, an `NA` in the unit column or in a random-effect grouping
## column was neither dropped, reported, nor rejected. The fit still ran, `nobs`
## was unchanged -- and the answer changed: with two `NA` sites under
## `indep(1 | site)`, logLik moved -34.49161 -> -35.83823 and the parameter count
## went 6 -> 7. The missing labels were being absorbed as an extra group.
##
## README.md tells readers that missing grouping variables "still error because
## the model cannot build that row". These tests make that true.
##
## Cheap and un-gated on purpose: the failure being guarded is silent.

.gn_data <- function(n = 30, seed = 11) {
  set.seed(seed)
  d <- data.frame(
    site = factor(seq_len(n)),
    grp  = factor(rep(seq_len(5), length.out = n)),
    z    = rnorm(n)
  )
  d$t1 <- 0.4 + 0.7 * d$z + rnorm(n, sd = 0.4)
  d$t2 <- -0.2 + 0.3 * d$z + rnorm(n, sd = 0.5)
  d
}

test_that("NA in the unit column is rejected, not absorbed as a group", {
  d <- .gn_data()
  d$site[c(1, 2)] <- NA
  err <- tryCatch(
    gllvmTMB(
      traits(t1, t2) ~ 1 + z + indep(1 | site),
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    error = function(e) conditionMessage(e)
  )
  # Assert the DIAGNOSIS, not merely that something failed. An earlier draft of
  # this test accepted any error, and passed while the guard was actually
  # emitting "Invalid cli literal: `{.idcol}` starts with a dot" -- a cli
  # formatting bug in the guard itself. A test that only asks "did it error?"
  # cannot tell a good message from a broken one.
  expect_match(err, "site", fixed = TRUE)
  expect_match(err, "missing", ignore.case = TRUE)
  expect_no_match(err, "Invalid cli literal", fixed = TRUE)
})

test_that("NA in a random-effect grouping column is rejected", {
  d <- .gn_data()
  d$grp[c(3, 4)] <- NA
  expect_error(
    gllvmTMB(
      traits(t1, t2) ~ 1 + z + (1 | grp),
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    "grp|missing|NA"
  )
})

test_that("the rejection names the offending column", {
  d <- .gn_data()
  d$grp[3] <- NA
  err <- tryCatch(
    gllvmTMB(
      traits(t1, t2) ~ 1 + z + (1 | grp),
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "grp", fixed = TRUE)
})

test_that("complete grouping columns are unaffected (guard is not over-broad)", {
  d <- .gn_data()
  expect_no_error(suppressMessages(
    gllvmTMB(
      traits(t1, t2) ~ 1 + z + indep(1 | site),
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    )
  ))
  expect_no_error(suppressMessages(
    gllvmTMB(
      traits(t1, t2) ~ 1 + z + (1 | grp),
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    )
  ))
})

test_that("a missing RESPONSE is still allowed (the guard is about labels only)", {
  # Missing responses are the supported, documented case -- they must keep
  # working exactly as before. This is the regression that would matter most.
  d <- .gn_data()
  d$t1[1] <- NA
  fit <- suppressMessages(
    gllvmTMB(
      traits(t1, t2) ~ 1 + z,
      data = d, unit = "site", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    )
  )
  expect_identical(nobs(fit), 59L)
})
