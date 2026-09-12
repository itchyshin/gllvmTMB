.temporal_ou_kernel_fixture <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$elapsed <- c(0, .4, 1.7, 4.1)[data$occasion]
  data$value <- with(data, as.numeric(factor(trait)) + .12 * elapsed +
    c(s1 = -.3, s2 = .1, s3 = .25)[series] + c(m1 = -.04, m2 = .04)[measurement])
  K <- matrix(c(
    1, .35, .15,
    .35, 1, .25,
    .15, .25, 1
  ), 3L, 3L, byrow = TRUE,
  dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  list(data = data, K = K)
}

.temporal_ou_kernel_fit <- function(fx, data = fx$data) {
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = elapsed,
        replicate = measurement, structure = "ou") +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L
    )
  ))
}

.temporal_ou_kernel_dense_nll <- function(fit, fixed, K, product = FALSE) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  correlation <- exp(-exp(par$theta_temporal_time) * abs(outer(pair$time, pair$time, `-`)))
  correlation[outer(pair$series, pair$series, `!=`)] <- 0
  temporal <- diag(exp(2 * par$theta_temporal_diag), nrow = td$n_traits)
  kernel <- tcrossprod(diag(par$theta_rr_phy, nrow = td$n_traits))
  V <- if (product) {
    correlation[state, state] * K[source, source] * temporal[trait, trait]
  } else {
    correlation[state, state] * temporal[trait, trait] +
      K[source, source] * kernel[trait, trait]
  }
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

test_that("replicated irregular-time temporal_indep plus kernel_indep is admitted", {
  skip_if_not_installed("TMB")
  fx <- .temporal_ou_kernel_fixture()
  fit <- .temporal_ou_kernel_fit(fx)

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_identical(fit$temporal$structure, "ou")
  expect_identical(fit$temporal$workflow, "replicated")
  expect_equal(fit$kernel_levels$name, "fixed_kernel")
  expect_equal(fit$opt$convergence, 0L)
})

test_that("OU temporal-kernel likelihood and gradients equal an independent dense additive oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_ou_kernel_fixture()
  fit <- .temporal_ou_kernel_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- log(.7)
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(.35, .45, .55))
  fixed[names(fixed) == "theta_rr_phy"] <- c(.25, .4, .6)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)

  expect_equal(as.numeric(fit$tmb_obj$fn(fixed)),
    .temporal_ou_kernel_dense_nll(fit, fixed, fx$K), tolerance = 2e-6)
  expect_gt(abs(.temporal_ou_kernel_dense_nll(fit, fixed, fx$K) -
    .temporal_ou_kernel_dense_nll(fit, fixed, fx$K, product = TRUE)), 1e-3)
  for (index in c(match("theta_temporal_time", names(fixed)),
                  which(names(fixed) == "theta_rr_phy")[[2L]])) {
    h <- 1e-5
    plus <- fixed; plus[[index]] <- plus[[index]] + h
    minus <- fixed; minus[[index]] <- minus[[index]] - h
    gradient <- (.temporal_ou_kernel_dense_nll(fit, plus, fx$K) -
      .temporal_ou_kernel_dense_nll(fit, minus, fx$K)) / (2 * h)
    expect_equal(fit$tmb_obj$gr(fixed)[[index]], gradient,
      tolerance = 3e-5, info = names(fixed)[[index]])
  }
})

test_that("OU temporal-kernel covariance is shift and time-unit invariant", {
  skip_if_not_installed("TMB")
  fx <- .temporal_ou_kernel_fixture()
  fit <- .temporal_ou_kernel_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "theta_temporal_time"] <- log(.7)
  shifted <- fx$data
  shifted$elapsed <- shifted$elapsed + 13.2
  shifted_fit <- .temporal_ou_kernel_fit(fx, shifted)
  shifted_fixed <- fixed
  expect_equal(.temporal_ou_kernel_dense_nll(fit, fixed, fx$K),
    .temporal_ou_kernel_dense_nll(shifted_fit, shifted_fixed, fx$K), tolerance = 1e-8)

  rescaled <- fx$data
  rescaled$elapsed <- 10 * rescaled$elapsed
  rescaled_fit <- .temporal_ou_kernel_fit(fx, rescaled)
  rescaled_fixed <- fixed
  rescaled_fixed[names(rescaled_fixed) == "theta_temporal_time"] <- log(.07)
  expect_equal(.temporal_ou_kernel_dense_nll(fit, fixed, fx$K),
    .temporal_ou_kernel_dense_nll(rescaled_fit, rescaled_fixed, fx$K), tolerance = 1e-8)
})

test_that("OU temporal-kernel unconditional simulation has additive moments", {
  skip_if_not_installed("TMB")
  fx <- .temporal_ou_kernel_fixture()
  fit <- .temporal_ou_kernel_fit(fx)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  rows <- fit$data
  find_row <- function(series, occasion, measurement, trait) {
    which(as.character(rows$series) == series & rows$occasion == occasion &
      as.character(rows$measurement) == measurement & as.character(rows$trait) == trait)
  }
  i1 <- find_row("s1", 1, "m1", "t1")
  i_time <- find_row("s1", 3, "m1", "t1")
  i_replicate <- find_row("s1", 1, "m2", "t1")
  i_source <- find_row("s2", 1, "m1", "t1")
  rate <- exp(par$theta_temporal_time[[1L]])
  temporal_variance <- exp(2 * par$theta_temporal_diag[[1L]])
  kernel_variance <- par$theta_rr_phy[[1L]]^2
  lag <- abs(fx$data$elapsed[i_time] - fx$data$elapsed[i1])
  expected <- c(
    time = exp(-rate * lag) * temporal_variance + fx$K["s1", "s1"] * kernel_variance,
    replicate = temporal_variance + fx$K["s1", "s1"] * kernel_variance,
    source = fx$K["s1", "s2"] * kernel_variance
  )
  draw <- simulate(fit, nsim = 2000L, seed = 2609361L)
  observed <- c(
    time = cov(draw[i1, ], draw[i_time, ]),
    replicate = cov(draw[i1, ], draw[i_replicate, ]),
    source = cov(draw[i1, ], draw[i_source, ])
  )
  variance <- apply(draw[c(i1, i_time, i_replicate, i_source), , drop = FALSE], 1L, var)
  se <- c(
    time = sqrt((variance[[1L]] * variance[[2L]] + expected[[1L]]^2) / 1999),
    replicate = sqrt((variance[[1L]] * variance[[3L]] + expected[[2L]]^2) / 1999),
    source = sqrt((variance[[1L]] * variance[[4L]] + expected[[3L]]^2) / 1999)
  )
  simultaneous_bound <- qnorm(1 - .05 / (2 * length(expected))) * se
  expect_true(all(abs(observed - expected) <= simultaneous_bound),
    info = paste(capture.output(rbind(observed, expected, simultaneous_bound)), collapse = "\n"))
})

test_that("OU temporal-kernel preserves identity through wide parsing and update", {
  skip_if_not_installed("TMB")
  fx <- .temporal_ou_kernel_fixture()
  long_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = elapsed,
        replicate = measurement, structure = "ou") +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  key <- unique(fx$data[c("series", "elapsed", "measurement")])
  wide <- key[order(key$series, key$elapsed, key$measurement), , drop = FALSE]
  for (trait in paste0("t", 1:3)) {
    values <- fx$data[fx$data$trait == trait,
      c("series", "elapsed", "measurement", "value")]
    values <- values[order(values$series, values$elapsed, values$measurement), , drop = FALSE]
    wide[[sub("t", "y", trait)]] <- values$value
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_indep(1 | series, time = elapsed, replicate = measurement,
        structure = "ou") + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = wide, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  replay <- suppressWarnings(update(long_fit))
  replacement <- fx$data
  replacement$value <- replacement$value + .01
  refit <- suppressWarnings(update(long_fit, data = replacement))

  expect_equal(unname(as.matrix(extract_temporal(long_fit)$pair_index)),
    unname(as.matrix(extract_temporal(wide_fit)$pair_index)))
  expect_identical(wide_fit$temporal$structure, "ou")
  expect_equal(wide_fit$kernel_levels$name, long_fit$kernel_levels$name)
  expect_s3_class(replay, "gllvmTMB_multi")
  expect_identical(replay$temporal$structure, "ou")
  expect_s3_class(refit, "gllvmTMB_multi")
  expect_equal(nrow(extract_temporal(refit)$pair_index),
    nrow(extract_temporal(long_fit)$pair_index))
})

test_that("OU source-pair admission remains limited to temporal_indep plus kernel_indep", {
  fx <- .temporal_ou_kernel_fixture()
  unreplicated <- fx$data[fx$data$measurement == "m1", , drop = FALSE]
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = elapsed,
      structure = "ou") + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = unreplicated, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires a replicated panel")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = elapsed,
      replicate = measurement, structure = "ou") +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = elapsed,
      replicate = measurement, structure = "ou") +
      phylo_indep(0 + trait | series, vcv = fx$K),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires replicated AR1")
})

test_that("OU temporal-kernel helper routes refuse before an IID algorithm runs", {
  skip_if_not_installed("TMB")
  fx <- .temporal_ou_kernel_fixture()
  fit <- .temporal_ou_kernel_fit(fx)
  future <- fx$data[fx$data$measurement == "m1", c("series", "elapsed", "trait")]

  expect_error(forecast_temporal(fit, future), "does not yet support replicated temporal panels")
  expect_error(profile_temporal(fit, ystep = .25, ytol = 1),
    "qualified temporal-kernel profile requires a replicated AR1 panel")
  expect_error(bootstrap_temporal(fit, n_boot = 1L),
    "qualified temporal-kernel bootstrap requires a replicated AR1 panel")
  expect_error(compare_temporal(left = fit, right = fit),
    "qualified temporal-kernel comparison requires replicated Gaussian AR1")
})
