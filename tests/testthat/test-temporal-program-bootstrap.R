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

test_that("bootstrap_temporal replays the qualified temporal-dependent phylogenetic pair", {
  skip_if_not_installed("TMB")
  d <- expand.grid(series = paste0("sp", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260946L); d$value <- stats::rnorm(nrow(d))
  Cphy <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L, 3L,
    dimnames = list(paste0("sp", 1:3), paste0("sp", 1:3)))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    phylo_indep(0 + trait | series, vcv = Cphy), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- bootstrap_temporal(fit, n_boot = 2L, seed = 260947L)
  again <- bootstrap_temporal(fit, n_boot = 2L, seed = 260947L)
  expect_equal(out$replicate, 1:2)
  expect_equal(out$seed, again$seed)
  expect_equal(out$time_estimate, again$time_estimate, tolerance = 1e-10)
  expect_true(all(is.finite(out$objective) | nzchar(out$error)))
})

test_that("bootstrap_temporal replays the qualified temporal-dependent tree input", {
  skip_if_not_installed("TMB"); skip_if_not_installed("ape")
  d <- expand.grid(series = paste0("sp", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260948L); d$value <- stats::rnorm(nrow(d))
  set.seed(260949L); tree <- ape::rcoal(3L); tree$tip.label <- paste0("sp", 1:3)
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    phylo_indep(0 + trait | series, tree = tree), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- bootstrap_temporal(fit, n_boot = 1L, seed = 260950L)
  expect_equal(out$replicate, 1L)
  expect_true(is.finite(out$objective[[1L]]) || nzchar(out$error[[1L]]))
})

test_that("bootstrap_temporal replays the qualified rank-one temporal-animal pair", {
  skip_if_not_installed("TMB")
  d <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260951L); d$value <- stats::rnorm(nrow(d))
  A <- matrix(c(1, .3, .1, .3, 1, .2, .1, .2, 1), 3L,
    dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion,
      replicate = measurement, d = 1, unique = FALSE) +
    animal_indep(0 + trait | series, A = A), data = d,
    unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)))
  out <- bootstrap_temporal(fit, n_boot = 2L, seed = 260952L)
  again <- bootstrap_temporal(fit, n_boot = 2L, seed = 260952L)
  expect_equal(out$replicate, 1:2)
  expect_equal(out$seed, again$seed)
  expect_equal(out$time_estimate, again$time_estimate, tolerance = 1e-10)
  expect_true(all(is.finite(out$objective) | nzchar(out$error)))
})
