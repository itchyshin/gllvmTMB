test_that("bootstrap_temporal retains deterministic replicated temporal-kernel refits", {
  skip_if_not_installed("TMB")
  d <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  set.seed(2609131L)
  d$value <- as.numeric(factor(d$trait)) + .1 * d$occasion + stats::rnorm(nrow(d), sd = .08)
  K <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L, 3L,
    byrow = TRUE, dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  fit <- suppressWarnings(gllvmTMB(
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
  skip_if(!is.finite(fit$opt$objective), "fixture did not converge to a finite objective")

  first <- bootstrap_temporal(fit, n_boot = 1L, seed = 2609132L)
  second <- bootstrap_temporal(fit, n_boot = 1L, seed = 2609132L)
  expect_named(first, c("replicate", "seed", "convergence", "objective", "time_estimate", "error"))
  expect_equal(first$replicate, 1L)
  expect_true(is.finite(first$seed))
  expect_true(is.finite(first$objective) || nzchar(first$error))
  expect_equal(first, second, tolerance = 1e-10)
})
