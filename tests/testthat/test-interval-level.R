## Invalid confidence levels must abort by argument name.
## The three sites named in itchyshin/gllvmTMB#1383: tidy(),
## confint(method = "wald"), and extract_correlations(method = "fisher-z").
## A classed stub is enough; these tests never fit a model.

stub_gllvmTMB_fit <- function() {
  structure(list(), class = "gllvmTMB_multi")
}

expect_named_level_error <- function(expr, arg) {
  err <- expect_error(expr, class = "rlang_error")
  msg <- conditionMessage(err)
  expect_match(msg, arg, fixed = TRUE)
  expect_match(msg, "between 0 and 1")
}

test_that("tidy(conf.int = TRUE) rejects an invalid conf.level by name", {
  fit <- stub_gllvmTMB_fit()
  expect_named_level_error(
    tidy(fit, "fixed", conf.int = TRUE, conf.level = 95),
    "conf.level"
  )
  expect_named_level_error(
    tidy(fit, "fixed", conf.int = TRUE, conf.level = -0.2),
    "conf.level"
  )
  expect_named_level_error(
    tidy(fit, "fixed", conf.int = TRUE, conf.level = NA_real_),
    "conf.level"
  )
  expect_named_level_error(
    tidy(fit, "fixed", conf.int = TRUE, conf.level = "0.95"),
    "conf.level"
  )
})

test_that("confint(method = 'wald') rejects an invalid level by name", {
  fit <- stub_gllvmTMB_fit()
  expect_named_level_error(
    confint(fit, method = "wald", level = 95),
    "level"
  )
  expect_named_level_error(
    confint(fit, method = "wald", level = -0.2),
    "level"
  )
  expect_named_level_error(
    confint(fit, method = "wald", level = NA_real_),
    "level"
  )
  expect_named_level_error(
    confint(fit, method = "wald", level = "0.95"),
    "level"
  )
})

test_that("extract_correlations(method = 'fisher-z') rejects an invalid level by name", {
  fit <- stub_gllvmTMB_fit()
  expect_named_level_error(
    extract_correlations(fit, method = "fisher-z", level = 95),
    "level"
  )
  expect_named_level_error(
    extract_correlations(fit, method = "fisher-z", level = -0.2),
    "level"
  )
  expect_named_level_error(
    extract_correlations(fit, method = "fisher-z", level = NA_real_),
    "level"
  )
  expect_named_level_error(
    extract_correlations(fit, method = "fisher-z", level = "0.95"),
    "level"
  )
})
