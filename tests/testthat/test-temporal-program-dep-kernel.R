.temporal_dep_kernel_fixture <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data, as.numeric(factor(trait)) + .08 * occasion +
    c(s1 = -.2, s2 = .1, s3 = .25)[series] + c(m1 = -.03, m2 = .03)[measurement])
  K <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L, 3L,
    byrow = TRUE, dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  list(data = data, K = K)
}

.temporal_dep_kernel_unpack <- function(theta, n_trait) {
  out <- matrix(0, n_trait, n_trait)
  cursor <- 1L
  for (column in seq_len(n_trait)) {
    out[column, column] <- theta[[cursor]]
    cursor <- cursor + 1L
  }
  for (column in seq_len(n_trait - 1L)) {
    for (row in (column + 1L):n_trait) {
      out[row, column] <- theta[[cursor]]
      cursor <- cursor + 1L
    }
  }
  stopifnot(cursor == length(theta) + 1L)
  out
}

.temporal_dep_kernel_dense_nll <- function(fit, fixed, K, product = FALSE) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  correlation <- ((1 - 1e-6) * tanh(par$theta_temporal_time))^
    abs(outer(pair$time, pair$time, `-`))
  correlation[outer(pair$series, pair$series, `!=`)] <- 0
  temporal <- tcrossprod(.temporal_dep_kernel_unpack(
    par$theta_temporal_rr, td$n_traits))
  kernel <- diag(par$theta_rr_phy, nrow = td$n_traits)
  kernel <- tcrossprod(kernel)
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

test_that("replicated temporal_dep plus one labelled kernel_indep is admitted", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_identical(fit$temporal$mode, "dep")
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_equal(fit$kernel_levels$name, "fixed_kernel")
})

test_that("replicated temporal_dep-kernel likelihood and gradients equal an independent additive oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
      replicate = measurement) + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(.45 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_rr"] <- c(.55, .45, .5, .08, -.12, .1)
  fixed[names(fixed) == "theta_rr_phy"] <- c(.3, .4, .5)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.25)

  expect_equal(as.numeric(fit$tmb_obj$fn(fixed)),
    .temporal_dep_kernel_dense_nll(fit, fixed, fx$K), tolerance = 2e-6)
  expect_gt(abs(.temporal_dep_kernel_dense_nll(fit, fixed, fx$K) -
    .temporal_dep_kernel_dense_nll(fit, fixed, fx$K, product = TRUE)), 1e-3)
  for (index in c(match("theta_temporal_time", names(fixed)),
                  which(names(fixed) == "theta_temporal_rr")[[5L]],
                  which(names(fixed) == "theta_rr_phy")[[2L]])) {
    h <- 1e-5
    plus <- fixed; plus[[index]] <- plus[[index]] + h
    minus <- fixed; minus[[index]] <- minus[[index]] - h
    gradient <- (.temporal_dep_kernel_dense_nll(fit, plus, fx$K) -
      .temporal_dep_kernel_dense_nll(fit, minus, fx$K)) / (2 * h)
    expect_equal(fit$tmb_obj$gr(fixed)[[index]], gradient,
      tolerance = 3e-5, info = names(fixed)[[index]])
  }
})

test_that("replicated temporal_dep-kernel unconditional simulation has additive moments", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
      replicate = measurement) + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  rows <- fit$data
  find_row <- function(series, occasion, measurement, trait) {
    which(as.character(rows$series) == series & rows$occasion == occasion &
      as.character(rows$measurement) == measurement &
      as.character(rows$trait) == trait)
  }
  i1 <- find_row("s1", 1, "m1", "t1")
  i_time <- find_row("s1", 2, "m1", "t2")
  i_rep <- find_row("s1", 1, "m2", "t2")
  i_source <- find_row("s2", 1, "m1", "t1")
  Lambda_time <- .temporal_dep_kernel_unpack(par$theta_temporal_rr,
    fit$tmb_data$n_traits)
  Sigma_time <- tcrossprod(Lambda_time)
  Lambda_kernel <- diag(par$theta_rr_phy, nrow = fit$tmb_data$n_traits)
  Sigma_kernel <- tcrossprod(Lambda_kernel)
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  expected <- c(
    time_cross_trait = phi * Sigma_time[1L, 2L] + fx$K[1L, 1L] * Sigma_kernel[1L, 2L],
    replicate_cross_trait = Sigma_time[1L, 2L] + fx$K[1L, 1L] * Sigma_kernel[1L, 2L],
    source_same_trait = fx$K[1L, 2L] * Sigma_kernel[1L, 1L]
  )
  draw <- simulate(fit, nsim = 2000L, seed = 2609162L)
  observed <- c(
    time_cross_trait = cov(draw[i1, ], draw[i_time, ]),
    replicate_cross_trait = cov(draw[i1, ], draw[i_rep, ]),
    source_same_trait = cov(draw[i1, ], draw[i_source, ])
  )
  variance <- apply(draw[c(i1, i_time, i_rep, i_source), , drop = FALSE], 1L, var)
  se <- c(
    time_cross_trait = sqrt((variance[[1L]] * variance[[2L]] +
      expected[[1L]]^2) / 1999),
    replicate_cross_trait = sqrt((variance[[1L]] * variance[[3L]] +
      expected[[2L]]^2) / 1999),
    source_same_trait = sqrt((variance[[1L]] * variance[[4L]] +
      expected[[3L]]^2) / 1999)
  )
  simultaneous_bound <- qnorm(1 - .05 / (2 * length(expected))) * se
  expect_true(all(abs(observed - expected) <= simultaneous_bound),
    info = paste(capture.output(rbind(observed, expected, simultaneous_bound)), collapse = "\n"))
})

test_that("replicated temporal_dep-kernel preserves identity through wide parsing and update", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  long_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
      replicate = measurement) + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  key <- unique(fx$data[c("series", "occasion", "measurement")])
  wide <- key[order(key$series, key$occasion, key$measurement), , drop = FALSE]
  for (trait in paste0("t", 1:3)) {
    values <- fx$data[fx$data$trait == trait,
      c("series", "occasion", "measurement", "value")]
    values <- values[order(values$series, values$occasion, values$measurement), , drop = FALSE]
    wide[[sub("t", "y", trait)]] <- values$value
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 + temporal_dep(1 | series, time = occasion,
      replicate = measurement) + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = wide, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  replay <- suppressWarnings(update(long_fit))
  replacement <- fx$data
  replacement$value <- replacement$value + .01
  refit <- suppressWarnings(update(long_fit, data = replacement))

  expect_equal(unname(as.matrix(extract_temporal(long_fit)$pair_index)),
    unname(as.matrix(extract_temporal(wide_fit)$pair_index)))
  expect_equal(wide_fit$kernel_levels$name, long_fit$kernel_levels$name)
  expect_equal(unname(extract_temporal(wide_fit)$loading),
    unname(wide_fit$report$Lambda_temporal), tolerance = 1e-8)
  expect_equal(rownames(extract_temporal(wide_fit)$loading), c("y1", "y2", "y3"))
  expect_s3_class(replay, "gllvmTMB_multi")
  expect_identical(replay$temporal$mode, "dep")
  expect_equal(replay$kernel_levels$name, "fixed_kernel")
  expect_s3_class(refit, "gllvmTMB_multi")
  expect_equal(nrow(extract_temporal(refit)$pair_index),
    nrow(extract_temporal(long_fit)$pair_index))
})

test_that("replicated temporal_dep-kernel fences unsupported inference routes", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
      replicate = measurement) + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_error(forecast_temporal(fit, fx$data), "currently supports.*temporal_indep")
  expect_error(profile_temporal(fit), "supports Gaussian.*temporal_indep")
  expect_error(bootstrap_temporal(fit, n_boot = 2L), "supports Gaussian.*temporal_indep")
  expect_error(compare_temporal(first = fit, second = fit),
    "qualified temporal-kernel comparison requires.*temporal_indep")
  expect_error(confint(fit), "not available.*temporal")
  expect_error(bootstrap_Sigma(fit, n_boot = 2L), "not available.*temporal")
})
