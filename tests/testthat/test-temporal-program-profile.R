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
  expect_gt(max(trace[[2L]]), fit$opt$objective)
  constrained <- profile_temporal(fit, ystep = .1, ytol = 1,
    parm.range = fit$opt$par[[theta_index]] + c(-.01, .01))
  expect_true(all(is.na(constrained[c("lower", "upper")])))
  expect_error(profile_temporal(fit, lincomb = c(1, rep(0, length(fit$opt$par) - 1L))),
    "lincomb.*not supported")
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
  expect_gt(max(trace[[2L]]), fit$opt$objective)

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

test_that("profile_temporal profiles the qualified temporal-dependent phylogenetic objective", {
  skip_if_not_installed("TMB")
  d <- expand.grid(series = paste0("sp", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260944L); d$value <- stats::rnorm(nrow(d))
  Cphy <- matrix(c(1, .35, .15, .10, .35, 1, .25, .20,
    .15, .25, 1, .40, .10, .20, .40, 1), 4L, 4L, byrow = TRUE,
    dimnames = list(paste0("sp", 1:4), paste0("sp", 1:4)))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    phylo_indep(0 + trait | series, vcv = Cphy), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- profile_temporal(fit, ystep = .25, ytol = 1)
  theta_index <- match("theta_temporal_time", names(fit$opt$par))
  trace <- TMB::tmbprofile(fit$tmb_obj, name = theta_index,
    ystep = .25, ytol = 1, trace = FALSE)
  at_mle <- which.min(abs(trace[[1L]] - fit$opt$par[[theta_index]]))
  expect_named(out, c("estimate", "lower", "upper"))
  expect_equal(out[["estimate"]],
    (1 - 1e-6) * tanh(fit$opt$par[[theta_index]]), tolerance = 1e-10)
  expect_equal(trace[[2L]][[at_mle]], fit$opt$objective, tolerance = 1e-8)
  expect_gt(max(trace[[2L]]), fit$opt$objective)

  fit_ou <- fit; fit_ou$temporal$structure <- "ou"
  expect_error(profile_temporal(fit_ou, ystep = .25, ytol = 1),
    "qualified temporal-kernel, temporal-dependent phylogenetic")
})

test_that("profile_temporal profiles the qualified temporal-dependent animal objective", {
  skip_if_not_installed("TMB")
  d <- expand.grid(series = paste0("a", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260963L); d$value <- stats::rnorm(nrow(d))
  A <- matrix(c(1, .35, .15, .10, .35, 1, .25, .20,
    .15, .25, 1, .40, .10, .20, .40, 1), 4L, 4L, byrow = TRUE,
    dimnames = list(paste0("a", 1:4), paste0("a", 1:4)))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    animal_indep(0 + trait | series, A = A), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- profile_temporal(fit, ystep = .25, ytol = 1)
  theta_index <- match("theta_temporal_time", names(fit$opt$par))
  trace <- TMB::tmbprofile(fit$tmb_obj, name = theta_index,
    ystep = .25, ytol = 1, trace = FALSE)
  at_mle <- which.min(abs(trace[[1L]] - fit$opt$par[[theta_index]]))
  expect_equal(out[["estimate"]],
    (1 - 1e-6) * tanh(fit$opt$par[[theta_index]]), tolerance = 1e-10)
  expect_equal(trace[[2L]][[at_mle]], fit$opt$objective, tolerance = 1e-8)
  expect_gt(max(trace[[2L]]), fit$opt$objective)
  fit_ou <- fit; fit_ou$temporal$structure <- "ou"
  expect_error(profile_temporal(fit_ou, ystep = .25, ytol = 1),
    "qualified temporal-kernel, temporal-dependent phylogenetic or animal")
})

test_that("profile_temporal profiles the qualified rank-one temporal-animal objective", {
  skip_if_not_installed("TMB")
  d <- expand.grid(series = paste0("s", 1:3), occasion = 1:3, measurement = c("m1", "m2"), trait = paste0("t", 1:3))
  set.seed(260955L); d$value <- stats::rnorm(nrow(d))
  A <- matrix(c(1,.3,.1,.3,1,.2,.1,.2,1), 3, dimnames = list(paste0("s",1:3), paste0("s",1:3)))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion, replicate = measurement, d = 1, unique = FALSE) + animal_indep(0 + trait | series, A = A), data = d, unit = "series", cluster = "series", family = gaussian(), silent = TRUE, control = gllvmTMBcontrol(se = FALSE)))
  out <- profile_temporal(fit, ystep = .25, ytol = 1)
  theta_index <- match("theta_temporal_time", names(fit$opt$par))
  trace <- TMB::tmbprofile(fit$tmb_obj, name = theta_index,
    ystep = .25, ytol = 1, trace = FALSE)
  at_mle <- which.min(abs(trace[[1L]] - fit$opt$par[[theta_index]]))
  expect_equal(out[["estimate"]],
    (1 - 1e-6) * tanh(fit$opt$par[[theta_index]]), tolerance = 1e-10)
  expect_equal(trace[[2L]][[at_mle]], fit$opt$objective, tolerance = 1e-8)
  expect_gt(max(trace[[2L]]), fit$opt$objective)
})

test_that("profile_temporal closes the qualified rank-one temporal-spatial objective at the direct MLE", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")
  key <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), KEEP.OUT.ATTRS = FALSE)
  loc <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    KEEP.OUT.ATTRS = FALSE)
  loc$lon <- c(0, 1, .2, .8, .4, .6, .3, .7, .5)
  loc$lat <- c(0, 0, 1, 1, .8, .2, .7, .3, .5)
  key <- merge(key, loc, by = c("series", "occasion"), sort = FALSE)
  d <- key[rep(seq_len(nrow(key)), each = 3L), , drop = FALSE]
  d$trait <- rep(paste0("t", 1:3), nrow(key))
  set.seed(260956L)
  d$value <- stats::rnorm(nrow(d))
  mesh <- make_mesh(d, c("lon", "lat"), cutoff = .05)
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion,
      replicate = measurement, d = 1, unique = FALSE) +
    spatial_indep(0 + trait | coords, mesh = mesh), data = d,
    unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- profile_temporal(fit, ystep = .25, ytol = 1)
  theta_index <- match("theta_temporal_time", names(fit$opt$par))
  trace <- TMB::tmbprofile(fit$tmb_obj, name = theta_index,
    ystep = .25, ytol = 1, trace = FALSE)
  at_mle <- which.min(abs(trace[[1L]] - fit$opt$par[[theta_index]]))
  expect_equal(out[["estimate"]],
    (1 - 1e-6) * tanh(fit$opt$par[[theta_index]]), tolerance = 1e-10)
  expect_equal(trace[[2L]][[at_mle]], fit$opt$objective, tolerance = 1e-8)
  expect_gt(max(trace[[2L]]), fit$opt$objective)
})
