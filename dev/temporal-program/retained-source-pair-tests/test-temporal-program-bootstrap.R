# Retained developer-only temporal source-pair fixture.
# It is intentionally outside tests/testthat because the public grammar
# defers temporal combinations with other covariance sources.

test_that("bootstrap_temporal replays the qualified temporal-kernel source pair", {
  d <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260916L); d$value <- stats::rnorm(nrow(d))
  K <- diag(3L); dimnames(K) <- list(paste0("s", 1:3), paste0("s", 1:3))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "bootstrap_kernel"), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- bootstrap_temporal(fit, n_boot = 2L, seed = 260918L)
  again <- bootstrap_temporal(fit, n_boot = 2L, seed = 260918L)
  expect_equal(out$replicate, 1:2)
  expect_equal(out$seed, again$seed)
  expect_equal(out$time_estimate, again$time_estimate, tolerance = 1e-10)
  expect_true(all(is.finite(out$objective) | nzchar(out$error)))

  phylo_fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
    phylo_indep(0 + trait | series, vcv = K), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  expect_error(bootstrap_temporal(phylo_fit, n_boot = 1L), "kernel_indep")

  dep_fit <- suppressWarnings(update(fit, formula = value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "bootstrap_kernel")))
  expect_error(bootstrap_temporal(dep_fit, n_boot = 1L), "temporal_indep")
})
