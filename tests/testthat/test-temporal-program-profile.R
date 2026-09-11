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
  theta_index <- match("theta_temporal_time", names(fit$opt$par))
  trace <- TMB::tmbprofile(fit$tmb_obj, name = theta_index,
    ystep = .25, ytol = 1, trace = FALSE)
  at_mle <- which.min(abs(trace[[1L]] - fit$opt$par[[theta_index]]))
  expect_named(out, c("estimate", "lower", "upper"))
  expect_equal(out[["estimate"]], (1 - 1e-6) * tanh(par$theta_temporal_time),
    tolerance = 1e-10)
  expect_equal(trace[[2L]][[at_mle]], fit$opt$objective, tolerance = 1e-8)
  expect_gt(max(trace[[2L]]), fit$opt$objective + .1)
  constrained <- profile_temporal(fit, ystep = .1, ytol = 1,
    parm.range = fit$opt$par[[theta_index]] + c(-.01, .01))
  expect_true(all(is.na(constrained[c("lower", "upper")])))
  expect_error(profile_temporal(update(fit,
    formula = value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion))),
    "temporal_indep")
})

test_that("OU temporal profiles are invariant to a time-origin shift", {
  d <- expand.grid(series = c("a", "b", "c"), elapsed = c(0, .5, 2),
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE)
  set.seed(260918L); d$value <- as.numeric(factor(d$trait)) + stats::rnorm(nrow(d))
  shifted <- d; shifted$elapsed <- shifted$elapsed + 100
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = elapsed, structure = "ou"), data = d,
    unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  shifted_fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = elapsed, structure = "ou"), data = shifted,
    unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  expect_equal(fit$opt$objective, shifted_fit$opt$objective, tolerance = 1e-8)
  expect_equal(profile_temporal(fit, ystep = .25, ytol = 1),
    profile_temporal(shifted_fit, ystep = .25, ytol = 1), tolerance = 1e-8)
})

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
