test_that("compare_temporal preserves ML/AIC semantics without an LRT", {
  d <- expand.grid(series = c("a", "b", "c"), occasion = 1:3,
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE)
  set.seed(260911L); d$value <- stats::rnorm(nrow(d))
  ar1 <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, structure = "ar1"),
    data = d, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  ou <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, structure = "ou"),
    data = d, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- compare_temporal(ar1 = ar1, ou = ou)
  expect_named(out, c("model", "logLik", "df", "AIC", "convergence"))
  expect_true(all(is.finite(out$AIC)))
  expect_equal(out$logLik, c(-ar1$opt$objective, -ou$opt$objective), tolerance = 1e-12)
  expect_equal(out$df, c(length(ar1$opt$par), length(ou$opt$par)))
  expect_equal(out$AIC, -2 * out$logLik + 2 * out$df, tolerance = 1e-12)
  expect_false("p.value" %in% names(out))
})
