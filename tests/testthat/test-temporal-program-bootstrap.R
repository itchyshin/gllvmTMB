test_that("bootstrap_temporal retains every temporal simulate-refit attempt", {
  d <- expand.grid(series = c("a", "b", "c"), occasion = 1:3,
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE)
  set.seed(260910L); d$value <- stats::rnorm(nrow(d))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion), data = d,
    unit = "series", family = gaussian(), silent = TRUE,
  control = gllvmTMBcontrol(se = FALSE)))
  out <- bootstrap_temporal(fit, n_boot = 2L, seed = 7L)
  expect_equal(out$replicate, 1:2)
  expect_named(out, c("replicate", "seed", "convergence", "objective", "time_estimate", "error"))
  expect_true(all(is.finite(out$seed)))
  expect_true(all(is.finite(out$objective) | nzchar(out$error)))
  expect_error(bootstrap_temporal(update(fit, formula = value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion)), 1L), "temporal_indep")
})

test_that("bootstrap_temporal retains reproducible draw seeds and the OU scale", {
  d <- expand.grid(series = c("a", "b", "c"), elapsed = c(0, .5, 2),
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE)
  set.seed(260913L); d$value <- stats::rnorm(nrow(d))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = elapsed, structure = "ou"), data = d,
    unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- bootstrap_temporal(fit, n_boot = 2L, seed = 260914L)
  expect_named(out, c("replicate", "seed", "convergence", "objective", "time_estimate", "error"))
  again <- bootstrap_temporal(fit, n_boot = 2L, seed = 260914L)
  expect_equal(out$seed, again$seed)
  expect_equal(out$time_estimate, again$time_estimate, tolerance = 1e-10)
  expect_true(all(out$time_estimate[!nzchar(out$error)] > 0))
  set.seed(260917L); expected_next <- stats::runif(1L)
  set.seed(260917L); bootstrap_temporal(fit, n_boot = 1L, seed = 260914L)
  expect_equal(stats::runif(1L), expected_next)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_equal(gllvmTMB:::.temporal_bootstrap_time_estimate(fit, par),
    exp(par$theta_temporal_time), tolerance = 1e-12)
})
