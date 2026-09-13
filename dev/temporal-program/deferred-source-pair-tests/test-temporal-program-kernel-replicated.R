.temporal_kernel_rep_fixture <- function() {
  base <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  base$value <- with(base,
    as.numeric(factor(trait)) + .12 * occasion +
      c(s1 = -.3, s2 = .1, s3 = .25)[series] +
      c(m1 = -.04, m2 = .04)[measurement])
  K <- matrix(c(
    1, .35, .15,
    .35, 1, .25,
    .15, .25, 1
  ), 3L, 3L, byrow = TRUE,
  dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  list(data = base, K = K)
}

.temporal_kernel_rep_fit <- function(fx) {
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion,
        replicate = measurement) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L
    )
  ))
}

.temporal_kernel_rep_dense_nll <- function(fit, fixed, K) {
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
  Sigma_time <- diag(exp(2 * par$theta_temporal_diag), nrow = td$n_traits)
  Lambda_kernel <- diag(par$theta_rr_phy, nrow = td$n_traits)
  Sigma_kernel <- tcrossprod(Lambda_kernel)
  V <- R_time[state, state] * Sigma_time[trait, trait] +
    K[source, source] * Sigma_kernel[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) +
    2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_kernel_rep_product_nll <- function(fit, fixed, K) {
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
  Sigma_time <- diag(exp(2 * par$theta_temporal_diag), nrow = td$n_traits)
  ## This deliberately wrong product is a source-by-time interaction, not the
  ## additive static-kernel plus temporal-process model under test.
  V <- R_time[state, state] * K[source, source] * Sigma_time[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) +
    2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

test_that("replicated temporal_indep plus one labelled kernel_indep is admitted", {
  skip_if_not_installed("TMB")
  fx <- .temporal_kernel_rep_fixture()
  fit <- .temporal_kernel_rep_fit(fx)

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_identical(fit$temporal$workflow, "replicated")
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_equal(fit$kernel_levels$name, "fixed_kernel")
  expect_equal(nrow(fit$optimizer_pass_history), 2L)
  expect_equal(fit$optimizer_pass_history$pass, 1:2)
  expect_true(isTRUE(fit$optimizer_pass_history$accepted[[2L]]))
  expect_equal(fit$opt$convergence, 0L)
  expect_error(gllvmTMBcontrol(optimizer_passes = 2L, integration = "va"),
    "requires native Laplace")
  expect_error(gllvmTMBcontrol(optimizer_passes = 2L, aghq = 3L),
    "requires native Laplace")
  expect_error(gllvmTMB(
    value ~ 0 + trait, data = fx$data, unit = "series", family = gaussian(),
    engine = "julia", control = gllvmTMBcontrol(optimizer_passes = 2L)
  ), "requires the native TMB Laplace engine")
})

test_that("replicated temporal-kernel likelihood and gradients equal a dense additive oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_kernel_rep_fixture()
  fit <- .temporal_kernel_rep_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(-.55 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(.35, .45, .55))
  fixed[names(fixed) == "theta_rr_phy"] <- c(.25, .4, .6)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)

  expect_equal(as.numeric(fit$tmb_obj$fn(fixed)),
    .temporal_kernel_rep_dense_nll(fit, fixed, fx$K), tolerance = 2e-6)
  expect_gt(abs(.temporal_kernel_rep_dense_nll(fit, fixed, fx$K) -
    .temporal_kernel_rep_product_nll(fit, fixed, fx$K)), 1e-3)
  for (index in c(match("theta_temporal_time", names(fixed)),
                  which(names(fixed) == "theta_rr_phy")[[2L]])) {
    h <- 1e-5
    plus <- fixed; plus[[index]] <- plus[[index]] + h
    minus <- fixed; minus[[index]] <- minus[[index]] - h
    dense_gradient <- (.temporal_kernel_rep_dense_nll(fit, plus, fx$K) -
      .temporal_kernel_rep_dense_nll(fit, minus, fx$K)) / (2 * h)
    expect_equal(fit$tmb_obj$gr(fixed)[[index]], dense_gradient,
      tolerance = 2e-5, info = names(fixed)[[index]])
  }
})

test_that("replicated temporal-kernel long and wide calls preserve temporal and kernel identity", {
  skip_if_not_installed("TMB")
  fx <- .temporal_kernel_rep_fixture()
  long_fit <- .temporal_kernel_rep_fit(fx)
  wide_key <- unique(fx$data[c("series", "occasion", "measurement")])
  wide <- wide_key[order(wide_key$series, wide_key$occasion, wide_key$measurement), , drop = FALSE]
  for (j in 1:3) {
    sub <- fx$data[fx$data$trait == paste0("t", j), c("series", "occasion", "measurement", "value")]
    sub <- sub[order(sub$series, sub$occasion, sub$measurement), , drop = FALSE]
    wide[[paste0("y", j)]] <- sub$value
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_indep(1 | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = wide, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_equal(unname(as.matrix(extract_temporal(long_fit)$pair_index)),
    unname(as.matrix(extract_temporal(wide_fit)$pair_index)))
  expect_equal(wide_fit$kernel_levels$name, long_fit$kernel_levels$name)
  expect_identical(wide_fit$temporal$workflow, "replicated")
  expect_equal(long_fit$report$Lambda_phy,
    long_fit$tmb_obj$report()$Lambda_phy, tolerance = 1e-8)
})

test_that("kernel source-pair admission rejects unreplicated and deferred OU/non-diagonal cells", {
  fx <- .temporal_kernel_rep_fixture()
  unreplicated <- fx$data[fx$data$measurement == "m1", , drop = FALSE]
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = unreplicated, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires a replicated panel")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion, replicate = measurement,
        structure = "ou") +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_dep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "cannot be combined")
})

test_that("replicated temporal-kernel unconditional simulation has additive moments", {
  skip_if_not_installed("TMB")
  fx <- .temporal_kernel_rep_fixture()
  fit <- .temporal_kernel_rep_fit(fx)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  rows <- fit$data
  find_row <- function(series, occasion, measurement, trait) {
    which(as.character(rows$series) == series & rows$occasion == occasion &
      as.character(rows$measurement) == measurement &
      as.character(rows$trait) == trait)
  }
  i1 <- find_row("s1", 1, "m1", "t1")
  i_time <- find_row("s1", 2, "m1", "t1")
  i_rep <- find_row("s1", 1, "m2", "t1")
  i_source <- find_row("s2", 1, "m1", "t1")
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal_variance <- exp(2 * par$theta_temporal_diag[[1L]])
  kernel_variance <- fit$report$Lambda_phy[1L, 1L]^2
  expected <- c(
    time = phi * temporal_variance + fx$K[1L, 1L] * kernel_variance,
    replicate = temporal_variance + fx$K[1L, 1L] * kernel_variance,
    source = fx$K[1L, 2L] * kernel_variance
  )
  draw <- simulate(fit, nsim = 2000L, seed = 2609161L)
  observed <- c(
    time = cov(draw[i1, ], draw[i_time, ]),
    replicate = cov(draw[i1, ], draw[i_rep, ]),
    source = cov(draw[i1, ], draw[i_source, ])
  )
  variance <- apply(draw[c(i1, i_time, i_rep, i_source), , drop = FALSE], 1L, var)
  se <- c(
    time = sqrt((variance[[1L]] * variance[[2L]] + expected[["time"]]^2) / 1999),
    replicate = sqrt((variance[[1L]] * variance[[3L]] + expected[["replicate"]]^2) / 1999),
    source = sqrt((variance[[1L]] * variance[[4L]] + expected[["source"]]^2) / 1999)
  )
  simultaneous_bound <- qnorm(1 - .05 / (2 * length(expected))) * se
  expect_true(all(abs(observed - expected) <= simultaneous_bound),
    info = paste(capture.output(rbind(observed, expected, simultaneous_bound)), collapse = "\n"))
})

test_that("replicated temporal-kernel update replays the saved public call", {
  skip_if_not_installed("TMB")
  fx <- .temporal_kernel_rep_fixture()
  fit <- .temporal_kernel_rep_fit(fx)
  replay <- suppressWarnings(update(fit))
  replacement <- fx$data
  replacement$value <- replacement$value + .01
  refit <- suppressWarnings(update(fit, data = replacement))

  expect_s3_class(replay, "gllvmTMB_multi")
  expect_true(isTRUE(replay$temporal$active))
  expect_identical(replay$temporal$workflow, "replicated")
  expect_equal(replay$kernel_levels$name, "fixed_kernel")
  expect_equal(replay$optimizer_pass_history,
    fit$optimizer_pass_history, tolerance = 1e-7)
  expect_s3_class(refit, "gllvmTMB_multi")
  expect_equal(nrow(extract_temporal(refit)$pair_index),
    nrow(extract_temporal(fit)$pair_index))
})
