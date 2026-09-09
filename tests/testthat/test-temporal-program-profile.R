test_that("profile_temporal profiles the direct transformed time parameter", {
  d <- expand.grid(series = c("a", "b", "c"), occasion = 1:4,
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE)
  set.seed(260909L)
  d$value <- as.numeric(factor(d$trait)) + stats::rnorm(nrow(d))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = d, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  out <- profile_temporal(fit, ystep = .25, ytol = 1)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_named(out, c("estimate", "lower", "upper"))
  expect_equal(out[["estimate"]], (1 - 1e-6) * tanh(par$theta_temporal_time),
    tolerance = 1e-10)
  expect_error(profile_temporal(update(fit,
    formula = value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion))),
    "temporal_indep")
})
