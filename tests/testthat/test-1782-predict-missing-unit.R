## #1782: predict(newdata) without the unit column returned the fixed-effects
## prediction and still informed that rr_B and diag_B had been re-added.
## This test fails on main because that call succeeds.

.fit_1782 <- function() {
  set.seed(1)
  d <- expand.grid(
    unit = factor(1:12),
    trait = factor(paste0("t", 1:3)),
    KEEP.OUT.ATTRS = FALSE
  )
  d$y <- stats::rnorm(nrow(d))
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d, trait = "trait", unit = "unit",
    family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L, laplace_auto_refit = FALSE),
    silent = TRUE
  )))
  list(d = d, fit = fit)
}

test_that("#1782 predict() stops when newdata omits the unit column", {
  sim <- .fit_1782()
  d <- sim$d
  fit <- sim$fit
  nd_miss <- d[, c("trait", "y"), drop = FALSE]

  expect_error(
    predict(fit, newdata = nd_miss),
    "unit column",
    class = "gllvmTMB_predict_newdata_unit_missing"
  )
  expect_error(
    predict(fit, newdata = nd_miss),
    "re_form",
    class = "gllvmTMB_predict_newdata_unit_missing"
  )

  p0 <- predict(fit, newdata = nd_miss, re_form = ~0)
  p_fx <- predict(fit, newdata = d, re_form = ~0)
  expect_equal(p0$est, p_fx$est, tolerance = 1e-8)

  p_nd <- suppressMessages(predict(fit, newdata = d))
  expect_true(max(abs(p_nd$est - p_fx$est)) > 1e-6)
})

test_that("#1782 an unseen unit level is not the missing-column error", {
  sim <- .fit_1782()
  nd_unseen <- sim$d[1, , drop = FALSE]
  nd_unseen$unit <- "99"
  p_unseen <- suppressMessages(predict(sim$fit, newdata = nd_unseen))
  expect_s3_class(p_unseen, "data.frame")
  expect_equal(nrow(p_unseen), 1L)
})
