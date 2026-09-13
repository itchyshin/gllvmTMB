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
