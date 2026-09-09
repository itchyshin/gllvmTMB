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
  expect_named(out, c("replicate", "convergence", "objective", "time_estimate", "error"))
  expect_true(all(is.finite(out$objective) | nzchar(out$error)))
  expect_error(bootstrap_temporal(update(fit, formula = value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion)), 1L), "temporal_indep")
})
