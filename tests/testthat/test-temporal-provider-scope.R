test_that("the first temporal release refuses static-source combinations", {
  dat <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3, measurement = c("m1", "m2"),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  dat$value <- 0
  K <- diag(3); dimnames(K) <- list(paste0("s", 1:3), paste0("s", 1:3))
  expect_error(
    gllvmTMB(value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = K, name = "deferred_kernel"),
    data = dat, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  ), "temporal-only covariance")
})
