test_that("residuals(type = response) on Gaussian latent fit names supported types (#1956)", {
  skip_on_cran()
  set.seed(26)
  df <- data.frame(
    unit = factor(rep(sprintf("u%02d", 1:12), each = 3)),
    trait = factor(rep(paste0("t", 1:3), 12)),
    value = rnorm(36)
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(1 | unit, d = 2),
    data = df,
    unit = "unit",
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))
  expect_equal(fit$opt$convergence, 0L)
  expect_error(
    residuals(fit, type = "response"),
    "is not supported by.*residuals"
  )
  expect_error(
    residuals(fit, type = "pearson"),
    "is not supported by.*residuals"
  )
})