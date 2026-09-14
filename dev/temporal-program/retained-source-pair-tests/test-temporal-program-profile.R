# Retained developer-only temporal source-pair fixture.
# It is intentionally outside tests/testthat because the public grammar
# defers temporal combinations with other covariance sources.

test_that("profile_temporal profiles the qualified temporal-kernel marginal objective", {
  d <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260919L); d$value <- stats::rnorm(nrow(d))
  K <- diag(3L); dimnames(K) <- list(paste0("s", 1:3), paste0("s", 1:3))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "profile_kernel"), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- profile_temporal(fit, ystep = .25, ytol = 1)
  theta_index <- match("theta_temporal_time", names(fit$opt$par))
  trace <- TMB::tmbprofile(fit$tmb_obj, name = theta_index,
    ystep = .25, ytol = 1, trace = FALSE)
  at_mle <- which.min(abs(trace[[1L]] - fit$opt$par[[theta_index]]))
  expect_named(out, c("estimate", "lower", "upper"))
  expect_equal(out[["estimate"]], (1 - 1e-6) * tanh(fit$opt$par[[theta_index]]),
    tolerance = 1e-10)
  expect_equal(trace[[2L]][[at_mle]], fit$opt$objective, tolerance = 1e-8)
  expect_gt(max(trace[[2L]]), fit$opt$objective + .1)

  phylo_fit <- suppressWarnings(update(fit, formula = value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
    phylo_indep(0 + trait | series, vcv = K)))
  expect_error(profile_temporal(phylo_fit, ystep = .25, ytol = 1), "kernel_indep")
  dep_fit <- suppressWarnings(update(fit, formula = value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = K, name = "profile_kernel")))
  expect_error(profile_temporal(dep_fit, ystep = .25, ytol = 1), "temporal_indep")
})

test_that("profile_temporal profiles the bounded irregular-time OU kernel cell", {
  d <- expand.grid(series = paste0("s", 1:3), elapsed = c(0, .4, 1.7, 4.1),
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260937L); d$value <- stats::rnorm(nrow(d))
  K <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L, 3L,
    dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = elapsed, replicate = measurement,
      structure = "ou") + kernel_indep(series, K = K, name = "profile_ou_kernel"),
    data = d, unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- profile_temporal(fit, ystep = .25, ytol = 1)
  theta_index <- match("theta_temporal_time", names(fit$opt$par))
  trace <- TMB::tmbprofile(fit$tmb_obj, name = theta_index,
    ystep = .25, ytol = 1, trace = FALSE)
  at_mle <- which.min(abs(trace[[1L]] - fit$opt$par[[theta_index]]))
  expect_named(out, c("estimate", "lower", "upper"))
  expect_equal(out[["estimate"]], exp(fit$opt$par[[theta_index]]), tolerance = 1e-10)
  expect_equal(trace[[2L]][[at_mle]], fit$opt$objective, tolerance = 1e-8)

  shifted <- d; shifted$elapsed <- shifted$elapsed + 31.4
  shifted_fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = elapsed, replicate = measurement,
      structure = "ou") + kernel_indep(series, K = K, name = "profile_ou_kernel"),
    data = shifted, unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  expect_equal(profile_temporal(fit, ystep = .25, ytol = 1),
    profile_temporal(shifted_fit, ystep = .25, ytol = 1), tolerance = 1e-8)
})
