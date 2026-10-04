test_that("sigma() refuses gllvmTMB fits instead of stats::sigma.default (#1407)", {
  fit <- structure(list(logLik = structure(function(...) -10, class = "logLik")),
                   class = "gllvmTMB_multi")
  expect_error(sigma(fit), "not defined for")
  expect_error(stats::sigma(fit), "not defined for")
})
