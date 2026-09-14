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

.temporal_dep_kernel_fit <- function(fx) {
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L
    )
  ))
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
  fit <- .temporal_dep_kernel_fit(fx)

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_identical(fit$temporal$mode, "dep")
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(all(c("z_temporal", "g_phy") %in% fit$random))
  expect_false("q_temporal" %in% fit$random)
  expect_equal(fit$kernel_levels$name, "fixed_kernel")
})

test_that("replicated temporal_dep-kernel likelihood and gradients equal an independent additive oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  fit <- .temporal_dep_kernel_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_rr"] <- c(.55, .45, .5, .08, -.12, .1)
  fixed[names(fixed) == "theta_rr_phy"] <- c(.3, .4, .5)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.25)
  expect_false(any(names(fixed) %in% c("theta_temporal_diag", "q_temporal")))
  for (phi in c(-.55, 0, .55)) {
    fixed[names(fixed) == "theta_temporal_time"] <- atanh(phi / (1 - 1e-6))
    expect_equal(as.numeric(fit$tmb_obj$fn(fixed)),
      .temporal_dep_kernel_dense_nll(fit, fixed, fx$K), tolerance = 2e-6)
    expect_gt(abs(.temporal_dep_kernel_dense_nll(fit, fixed, fx$K) -
      .temporal_dep_kernel_dense_nll(fit, fixed, fx$K, product = TRUE)), 1e-3)
    for (index in seq_along(fixed)) {
      h <- 1e-5
      plus <- fixed; plus[[index]] <- plus[[index]] + h
      minus <- fixed; minus[[index]] <- minus[[index]] - h
      gradient <- (.temporal_dep_kernel_dense_nll(fit, plus, fx$K) -
        .temporal_dep_kernel_dense_nll(fit, minus, fx$K)) / (2 * h)
      expect_equal(fit$tmb_obj$gr(fixed)[[index]], gradient,
        tolerance = 3e-5, info = paste(names(fixed)[[index]], "phi", phi))
    }
  }
})

test_that("temporal_dep-kernel preserves labels through wide syntax, simulation, and update", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  long_fit <- .temporal_dep_kernel_fit(fx)
  wide_key <- unique(fx$data[c("series", "occasion", "measurement")])
  wide <- wide_key[order(wide_key$series, wide_key$occasion, wide_key$measurement), , drop = FALSE]
  for (j in 1:3) {
    sub <- fx$data[fx$data$trait == paste0("t", j), c("series", "occasion", "measurement", "value")]
    sub <- sub[order(sub$series, sub$occasion, sub$measurement), , drop = FALSE]
    wide[[paste0("y", j)]] <- sub$value
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_dep(1 | series, time = occasion, replicate = measurement) +
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
  permuted_fit <- .temporal_dep_kernel_fit(permuted)
  expect_equal(permuted_fit$opt$objective, long_fit$opt$objective, tolerance = 1e-6)
  expect_equal(unname(as.matrix(extract_temporal(permuted_fit)$pair_index)),
    unname(as.matrix(extract_temporal(long_fit)$pair_index)))
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
  Sigma_time <- tcrossprod(.temporal_dep_kernel_unpack(
    par$theta_temporal_rr, long_fit$tmb_data$n_traits))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  kernel_var <- par$theta_rr_phy[[1L]]^2
  expected <- c(
    time = phi * Sigma_time[1L, 1L] + fx$K[1L, 1L] * kernel_var,
    cross_trait = Sigma_time[1L, 2L],
    source = fx$K[1L, 2L] * kernel_var
  )
  draw <- simulate(long_fit, nsim = 1500L, seed = 2609229L)
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
  bound <- qnorm(1 - .01 / (2 * length(expected))) * se
  expect_true(all(abs(observed - expected) <= bound),
    info = paste(capture.output(rbind(observed, expected, bound)), collapse = "\n"))

  replay <- suppressWarnings(update(long_fit))
  expect_identical(replay$temporal$mode, "dep")
  expect_equal(replay$kernel_levels$name, "fixed_kernel")
})

test_that("temporal_dep-kernel pairing refuses ordinary covariance and even-only lags", {
  fx <- .temporal_dep_kernel_fixture()
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel") +
      indep(0 + trait | series),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "cannot include an ordinary covariance term")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel") + (1 | series),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "cannot include an ordinary covariance term")
  even_time <- fx$data
  even_time$occasion <- 2L * even_time$occasion
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
      replicate = measurement) + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = even_time, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires an odd within-series time lag")
})
