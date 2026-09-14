# Retained developer-only temporal source-pair fixture.
# It is intentionally outside tests/testthat because the public grammar
# defers temporal combinations with other covariance sources.

test_that("compare_temporal compares only matching qualified temporal-kernel candidates", {
  d <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260912L); d$value <- stats::rnorm(nrow(d))
  K <- diag(3L); dimnames(K) <- list(paste0("s", 1:3), paste0("s", 1:3))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "selection_kernel"), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  second <- suppressWarnings(update(fit))
  out <- compare_temporal(left = fit, right = second)
  expect_named(out, c("model", "logLik", "df", "AIC", "convergence"))
  expect_equal(out$AIC, -2 * out$logLik + 2 * out$df, tolerance = 1e-12)
  expect_false("p.value" %in% names(out))

  phylo <- suppressWarnings(update(fit, formula = value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
    phylo_indep(0 + trait | series, vcv = K)))
  expect_error(compare_temporal(left = fit, right = phylo), "matching qualified")
  dep <- suppressWarnings(update(fit, formula = value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "selection_kernel")))
  expect_error(compare_temporal(left = fit, right = dep), "requires replicated Gaussian AR1")

  K_other <- K; K_other[1L, 2L] <- K_other[2L, 1L] <- .1
  other_kernel <- suppressWarnings(update(fit, formula = value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K_other, name = "other_kernel")))
  expect_error(compare_temporal(left = fit, right = other_kernel), "same labelled kernel")
})
