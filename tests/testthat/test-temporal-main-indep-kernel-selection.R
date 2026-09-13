test_that("compare_temporal reports stored AIC quantities for qualified temporal-kernel candidates", {
  skip_if_not_installed("TMB")
  d <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  set.seed(2609133L)
  d$value <- as.numeric(factor(d$trait)) + .1 * d$occasion + stats::rnorm(nrow(d), sd = .08)
  series <- paste0("s", 1:3)
  K1 <- diag(3L); dimnames(K1) <- list(series, series)
  K2 <- matrix(c(1, .3, .1, .3, 1, .2, .1, .2, 1), 3L, 3L,
    byrow = TRUE, dimnames = list(series, series))
  fit_with <- function(K) suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion,
        replicate = measurement) +
      kernel_indep(series, K = K, name = "fixed_kernel"),
    data = d, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L
    )
  ))
  diagonal <- fit_with(K1); correlated <- fit_with(K2)
  skip_if(!is.finite(diagonal$opt$objective) || !is.finite(correlated$opt$objective),
    "fixture did not converge to finite objectives")

  out <- compare_temporal(diagonal = diagonal, correlated = correlated)
  expect_equal(out$model, c("diagonal", "correlated"))
  expect_equal(out$logLik, c(-diagonal$opt$objective, -correlated$opt$objective), tolerance = 1e-10)
  expect_equal(out$df, c(length(diagonal$opt$par), length(correlated$opt$par)))
  expect_equal(out$AIC, c(stats::AIC(diagonal), stats::AIC(correlated)), tolerance = 1e-10)
  expect_equal(out$convergence, c(diagonal$opt$convergence, correlated$opt$convergence))
})
