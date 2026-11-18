## #1403: ordinary (non-temporal) fits have no `call`, so
## `update()` must not fall through to `stats::update.default()`.
## `simulate()` must reject invalid `nsim` before any draw.

.ordinary_fit <- function() {
  structure(list(temporal = list(active = FALSE)), class = "gllvmTMB_multi")
}

test_that("update() tells ordinary fits to refit instead of asking for a call component", {
  fit <- .ordinary_fit()
  expect_error(
    update(fit, family = stats::gaussian()),
    regexp = "only supported for temporal"
  )
  err <- tryCatch(
    update(fit, family = stats::gaussian()),
    error = function(e) conditionMessage(e)
  )
  expect_false(grepl("need an object with call component", err, fixed = TRUE))
})

test_that("simulate() rejects invalid nsim before any draw", {
  fit <- .ordinary_fit()
  expect_error(simulate(fit, nsim = -1), regexp = "nsim")
  expect_error(simulate(fit, nsim = 0), regexp = "nsim")
  expect_error(simulate(fit, nsim = NA_real_), regexp = "nsim")
  expect_error(simulate(fit, nsim = 2.7), regexp = "nsim")
})
