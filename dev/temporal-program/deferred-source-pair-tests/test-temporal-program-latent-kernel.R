.temporal_latent_kernel_fixture <- function() {
  dat <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  dat$value <- with(dat, as.numeric(factor(trait)) + .1 * occasion +
    c(s1 = -.2, s2 = .1, s3 = .25)[series] +
    c(m1 = -.03, m2 = .03)[measurement])
  K <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L, 3L,
    byrow = TRUE, dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  list(data = dat, K = K)
}

.temporal_latent_kernel_fit <- function(fx) {
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion,
        replicate = measurement, d = 1, unique = FALSE) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L
    )
  ))
}

.temporal_latent_kernel_dense_nll <- function(fit, fixed, K) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  same_series <- outer(pair$series, pair$series, `==`)
  lag <- abs(outer(pair$time, pair$time, `-`))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  R_time <- phi^lag
  R_time[!same_series] <- 0
  lambda <- as.numeric(par$theta_temporal_rr)
  Sigma_time <- tcrossprod(lambda)
  Sigma_kernel <- diag(par$theta_rr_phy[seq_len(td$n_traits)]^2, td$n_traits)
  V <- R_time[state, state] * Sigma_time[trait, trait] +
    K[source, source] * Sigma_kernel[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_latent_kernel_diagonal_time_nll <- function(fit, fixed, K) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  same_series <- outer(pair$series, pair$series, `==`)
  lag <- abs(outer(pair$time, pair$time, `-`))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  R_time <- phi^lag
  R_time[!same_series] <- 0
  lambda <- as.numeric(par$theta_temporal_rr)
  Sigma_time <- diag(lambda^2, td$n_traits)
  Sigma_kernel <- diag(par$theta_rr_phy[seq_len(td$n_traits)]^2, td$n_traits)
  V <- R_time[state, state] * Sigma_time[trait, trait] +
    K[source, source] * Sigma_kernel[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_latent_kernel_product_nll <- function(fit, fixed, K) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  same_series <- outer(pair$series, pair$series, `==`)
  lag <- abs(outer(pair$time, pair$time, `-`))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  R_time <- phi^lag
  R_time[!same_series] <- 0
  Sigma_time <- tcrossprod(as.numeric(par$theta_temporal_rr))
  ## Deliberately wrong: this is a kernel-by-time interaction, not two
  ## independent additive fields.
  V <- R_time[state, state] * K[source, source] * Sigma_time[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

test_that("replicated rank-one temporal latent plus one labelled kernel is admitted", {
  skip_if_not_installed("TMB")
  fx <- .temporal_latent_kernel_fixture()
  fit <- .temporal_latent_kernel_fit(fx)

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$temporal$mode, "latent")
  expect_false(isTRUE(fit$temporal$unique))
  expect_equal(fit$kernel_levels$name, "fixed_kernel")
})

test_that("rank-one temporal-kernel likelihood and every active derivative equal a dense oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_latent_kernel_fixture()
  fit <- .temporal_latent_kernel_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_rr"] <- c(.25, .4, .6)
  fixed[names(fixed) == "theta_rr_phy"] <- c(.3, .45, .55)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)

  for (phi in c(-.55, 0, .55)) {
    fixed[names(fixed) == "theta_temporal_time"] <- atanh(phi / (1 - 1e-6))
    expect_equal(as.numeric(fit$tmb_obj$fn(fixed)),
      .temporal_latent_kernel_dense_nll(fit, fixed, fx$K), tolerance = 2e-6)
    expect_gt(abs(.temporal_latent_kernel_dense_nll(fit, fixed, fx$K) -
      .temporal_latent_kernel_diagonal_time_nll(fit, fixed, fx$K)), 1e-3)
    expect_gt(abs(.temporal_latent_kernel_dense_nll(fit, fixed, fx$K) -
      .temporal_latent_kernel_product_nll(fit, fixed, fx$K)), 1e-3)
    for (index in seq_along(fixed)) {
      h <- 1e-5
      plus <- fixed; plus[[index]] <- plus[[index]] + h
      minus <- fixed; minus[[index]] <- minus[[index]] - h
      central <- (.temporal_latent_kernel_dense_nll(fit, plus, fx$K) -
        .temporal_latent_kernel_dense_nll(fit, minus, fx$K)) / (2 * h)
      expect_equal(fit$tmb_obj$gr(fixed)[[index]], central,
        tolerance = 2e-5, info = paste(names(fixed)[[index]], "phi", phi))
    }
  }
})

test_that("rank-one temporal-kernel preserves labels through wide syntax, simulation, and update", {
  skip_if_not_installed("TMB")
  fx <- .temporal_latent_kernel_fixture()
  long_fit <- .temporal_latent_kernel_fit(fx)
  wide_key <- unique(fx$data[c("series", "occasion", "measurement")])
  wide <- wide_key[order(wide_key$series, wide_key$occasion, wide_key$measurement), , drop = FALSE]
  for (j in 1:3) {
    sub <- fx$data[fx$data$trait == paste0("t", j), c("series", "occasion", "measurement", "value")]
    sub <- sub[order(sub$series, sub$occasion, sub$measurement), , drop = FALSE]
    wide[[paste0("y", j)]] <- sub$value
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_latent(1 | series, time = occasion, replicate = measurement,
        d = 1, unique = FALSE) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = wide, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_equal(unname(as.matrix(extract_temporal(long_fit)$pair_index)),
    unname(as.matrix(extract_temporal(wide_fit)$pair_index)))
  expect_equal(wide_fit$kernel_levels$name, "fixed_kernel")
  permuted <- fx
  permuted$K <- fx$K[c("s3", "s1", "s2"), c("s3", "s1", "s2")]
  permuted$data <- fx$data[rev(seq_len(nrow(fx$data))), , drop = FALSE]
  permuted_fit <- .temporal_latent_kernel_fit(permuted)
  expect_equal(permuted_fit$opt$objective, long_fit$opt$objective, tolerance = 1e-6)
  expect_equal(unname(as.matrix(extract_temporal(permuted_fit)$pair_index)),
    unname(as.matrix(extract_temporal(long_fit)$pair_index)))
  scores <- getLV(long_fit)
  expect_identical(rownames(scores), extract_temporal(long_fit)$pair_index$pair_id)
  expect_true(is.data.frame(attr(scores, "temporal_index")))

  rows <- long_fit$data
  find_row <- function(series, occasion, measurement, trait) {
    which(as.character(rows$series) == series & rows$occasion == occasion &
      as.character(rows$measurement) == measurement & as.character(rows$trait) == trait)
  }
  i1 <- find_row("s1", 1, "m1", "t1")
  i_time <- find_row("s1", 2, "m1", "t1")
  i_trait <- find_row("s1", 1, "m1", "t2")
  i_source <- find_row("s2", 1, "m1", "t1")
  par <- long_fit$tmb_obj$env$parList(long_fit$opt$par)
  lambda <- as.numeric(par$theta_temporal_rr)
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  kernel_var <- par$theta_rr_phy[[1L]]^2
  expected <- c(
    time = phi * lambda[[1L]]^2 + fx$K[1L, 1L] * kernel_var,
    cross_trait = lambda[[1L]] * lambda[[2L]],
    source = fx$K[1L, 2L] * kernel_var
  )
  draw <- simulate(long_fit, nsim = 1500L, seed = 2609228L)
  observed <- c(
    time = cov(draw[i1, ], draw[i_time, ]),
    cross_trait = cov(draw[i1, ], draw[i_trait, ]),
    source = cov(draw[i1, ], draw[i_source, ])
  )
  vars <- apply(draw[c(i1, i_time, i_trait, i_source), , drop = FALSE], 1L, var)
  se <- c(
    time = sqrt((vars[[1L]] * vars[[2L]] + expected[[1L]]^2) / 1499),
    cross_trait = sqrt((vars[[1L]] * vars[[3L]] + expected[[2L]]^2) / 1499),
    source = sqrt((vars[[1L]] * vars[[4L]] + expected[[3L]]^2) / 1499)
  )
  ## This is a fixed 99% familywise Gaussian Monte Carlo bound for the three
  ## selected moments, rather than a stochastic 95% pass/fail threshold.
  bound <- qnorm(1 - .01 / (2 * length(expected))) * se
  expect_true(all(abs(observed - expected) <= bound),
    info = paste(capture.output(rbind(observed, expected, bound)), collapse = "\n"))

  replay <- suppressWarnings(update(long_fit))
  expect_identical(replay$temporal$mode, "latent")
  expect_false(isTRUE(replay$temporal$unique))
  expect_equal(replay$kernel_levels$name, "fixed_kernel")
})

test_that("rank-one temporal latent kernel pairing refuses unqualified variants", {
  fx <- .temporal_latent_kernel_fixture()
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
        d = 1, unique = TRUE) + kernel_indep(series, K = fx$K),
    data = fx$data, unit = "series", family = gaussian(), silent = TRUE
  )), "cannot be combined")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
        d = 1, unique = FALSE, structure = "ou") + kernel_indep(series, K = fx$K),
    data = fx$data, unit = "series", family = gaussian(), silent = TRUE
  )), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
        d = 1, unique = FALSE) + kernel_indep(series, K = fx$K) +
      indep(0 + trait | series),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "cannot include an ordinary covariance term")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
        d = 1, unique = FALSE) + kernel_indep(series, K = fx$K) + (1 | series),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "cannot include an ordinary covariance term")
  even_time <- fx$data
  even_time$occasion <- 2L * even_time$occasion
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
        d = 1, unique = FALSE) + kernel_indep(series, K = fx$K),
    data = even_time, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires an odd within-series time lag")
})
