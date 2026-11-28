test_that("as.numeric(predict()) returns the est column (refs #1955)", {
  skip_on_cran()
  skip_if_not_installed("gllvmTMB")
  set.seed(11262631L)
  df <- data.frame(
    unit = factor(rep(sprintf("u%02d", 1:12), 3)),
    trait = factor(rep(paste0("t", 1:3), 12)),
    value = stats::rnorm(36)
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(1 | unit, d = 2),
    data = df,
    unit = "unit"
  )
  skip_if(fit$opt$convergence != 0, "fit did not converge in this environment")
  pred <- predict(fit, type = "link")
  expect_s3_class(pred, "gllvmTMB_predict")
  expect_equal(
    as.numeric(pred),
    as.numeric(pred$est),
    tolerance = 1e-10
  )
  expect_equal(as.numeric(pred), unname(fit$report$eta), tolerance = 1e-8)
})