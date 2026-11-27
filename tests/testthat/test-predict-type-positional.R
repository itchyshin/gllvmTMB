## Issue #1988: predict(fit, "link") must not be parsed as newdata.

test_that("predict() errors clearly when type is passed as the second positional argument", {
  skip_on_cran()
  set.seed(1127)
  df <- data.frame(
    unit = factor(rep(1:12, each = 2)),
    trait = factor(rep(c("t1", "t2"), 12)),
    value = stats::rpois(24, 2)
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(1 | unit, d = 1, unique = FALSE),
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_error(
    predict(fit, "link"),
    class = "gllvmTMB_predict_type_positional"
  )
  expect_error(
    predict(fit, "link"),
    "type = "
  )
  expect_error(
    predict(fit, "response"),
    class = "gllvmTMB_predict_type_positional"
  )
  expect_s3_class(predict(fit, type = "link"), "data.frame")
})