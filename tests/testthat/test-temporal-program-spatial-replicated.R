.temporal_spatial_rep_fixture <- function() {
  key <- expand.grid(
    series = paste0("s", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  key$lon <- c(0, 1, 0, 1, .2, .8, .3, .7, .1, .9, .4, .6, .25, .75, .45, .55)[
    match(paste(key$series, key$occasion), paste(rep(paste0("s", 1:4), each = 4), rep(1:4, 4)))]
  key$lat <- c(0, 0, 1, 1, .8, .2, .7, .3, .4, .6, .9, .1, .25, .75, .55, .45)[
    match(paste(key$series, key$occasion), paste(rep(paste0("s", 1:4), each = 4), rep(1:4, 4)))]
  data <- key[rep(seq_len(nrow(key)), each = 3L), , drop = FALSE]
  data$trait <- rep(paste0("t", 1:3), nrow(key))
  data$value <- with(data, as.numeric(factor(trait)) + .1 * occasion +
    c(s1 = -.2, s2 = .15, s3 = .05, s4 = .3)[series] +
    c(m1 = -.03, m2 = .03)[measurement])
  list(data = data, mesh = make_mesh(data, c("lon", "lat"), cutoff = .05))
}

.temporal_spatial_rep_fit <- function(fx) {
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      spatial_indep(0 + trait | coords, mesh = fx$mesh),
    data = fx$data, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
}

.temporal_spatial_rep_dense_nll <- function(fit, fixed, product = FALSE) {
  par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data
  pair <- fit$temporal$pair_table
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Ktime <- phi ^ abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  kappa <- exp(par$log_kappa_spde)
  Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) +
    as.matrix(td$spde_M2)
  Kspace <- as.matrix(td$A_proj) %*% solve(Q) %*% t(as.matrix(td$A_proj))
  state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L
  temporal_var <- diag(exp(2 * par$theta_temporal_diag), td$n_traits)
  spatial_var <- diag(exp(-2 * par$log_tau_spde), td$n_traits)
  V <- if (product) {
    Ktime[state, state] * Kspace * temporal_var[trait, trait]
  } else {
    Ktime[state, state] * temporal_var[trait, trait] +
      Kspace * spatial_var[trait, trait]
  }
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix); L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_spatial_rep_dense_cov <- function(fit, fixed) {
  par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data
  pair <- fit$temporal$pair_table
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Ktime <- phi ^ abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  kappa <- exp(par$log_kappa_spde)
  Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) +
    as.matrix(td$spde_M2)
  Kspace <- as.matrix(td$A_proj) %*% solve(Q) %*% t(as.matrix(td$A_proj))
  state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L
  V <- Ktime[state, state] * diag(exp(2 * par$theta_temporal_diag), td$n_traits)[trait, trait] +
    Kspace * diag(exp(-2 * par$log_tau_spde), td$n_traits)[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  V
}

test_that("replicated AR1 temporal_indep plus fixed spatial_indep is admitted", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_spatial_rep_fixture(); fit <- .temporal_spatial_rep_fit(fx)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active)); expect_identical(fit$temporal$workflow, "replicated")
  expect_true(isTRUE(fit$use$spde)); expect_true(all(c("q_temporal", "omega_spde") %in% fit$random))
})

test_that("replicated temporal-spatial likelihood and gradient equal a dense additive oracle", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_spatial_rep_fixture(); fit <- .temporal_spatial_rep_fit(fx); fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(.45 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(.4, .5, .6))
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)
  fixed[names(fixed) == "log_tau_spde"] <- log(c(1.1, .9, 1.2))
  fixed[names(fixed) == "log_kappa_spde"] <- log(2)
  dense <- .temporal_spatial_rep_dense_nll(fit, fixed)
  expect_equal(as.numeric(fit$tmb_obj$fn(fixed)), dense, tolerance = 2e-6)
  expect_gt(abs(dense - .temporal_spatial_rep_dense_nll(fit, fixed, product = TRUE)), 1e-3)
  i <- match("theta_temporal_time", names(fixed)); h <- 1e-5
  plus <- fixed; plus[[i]] <- plus[[i]] + h; minus <- fixed; minus[[i]] <- minus[[i]] - h
  central <- (.temporal_spatial_rep_dense_nll(fit, plus) - .temporal_spatial_rep_dense_nll(fit, minus)) / (2 * h)
  expect_equal(fit$tmb_obj$gr(fixed)[[i]], central, tolerance = 3e-5)
})

test_that("independent temporal-spatial cells enforce their specific bounds", {
  skip_if_not_installed("fmesher")
  fx <- .temporal_spatial_rep_fixture(); unrep <- fx$data[fx$data$measurement == "m1", , drop = FALSE]
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion) +
      spatial_indep(0 + trait | coords, mesh = fx$mesh),
    data = unrep, unit = "series", family = gaussian(), silent = TRUE
  )), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion, replicate = measurement, structure = "ou") +
      spatial_indep(0 + trait | coords, mesh = fx$mesh),
    data = fx$data, unit = "series", family = gaussian(), silent = TRUE
  )), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      spatial_dep(0 + trait | coords, mesh = fx$mesh),
    data = fx$data, unit = "series", family = gaussian(), silent = TRUE
  )), "cannot be combined")
})

test_that("temporal-spatial trajectories with proportional lag and distance are refused", {
  skip_if_not_installed("fmesher")
  key <- expand.grid(series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  key$lon <- key$occasion; key$lat <- as.numeric(factor(key$series))
  data <- key[rep(seq_len(nrow(key)), each = 3L), , drop = FALSE]
  data$trait <- rep(paste0("t", 1:3), nrow(key)); data$value <- stats::rnorm(nrow(data))
  mesh <- make_mesh(data, c("lon", "lat"), cutoff = .05)
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      spatial_indep(0 + trait | coords, mesh = mesh),
    data = data, unit = "series", family = gaussian(), silent = TRUE
  )), "bases are proportional")
})

test_that("replicated temporal-spatial calls replay from wide syntax", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher"); skip_if_not_installed("tidyr")
  fx <- .temporal_spatial_rep_fixture()
  wide <- unique(fx$data[c("series", "occasion", "measurement", "lon", "lat")])
  for (trait in paste0("t", 1:3)) {
    wide[[sub("t", "y", trait)]] <- fx$data$value[fx$data$trait == trait]
  }
  long_fit <- .temporal_spatial_rep_fit(fx)
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_indep(1 | series, time = occasion, replicate = measurement) +
      spatial_indep(1 | coords, mesh = fx$mesh),
    data = wide, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_s3_class(wide_fit, "gllvmTMB_multi")
  expect_true(isTRUE(wide_fit$temporal$active))
  expect_equal(unname(as.matrix(extract_temporal(wide_fit)$pair_index)),
    unname(as.matrix(extract_temporal(long_fit)$pair_index)))
  expect_s3_class(suppressWarnings(update(wide_fit)), "gllvmTMB_multi")
})

test_that("unconditional simulation redraws the admitted temporal-spatial SPDE field", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_spatial_rep_fixture(); fit <- .temporal_spatial_rep_fit(fx)
  draws <- simulate(fit, nsim = 1200, seed = 90210)
  expect_equal(dim(draws), c(nrow(fx$data), 1200L))

  V <- .temporal_spatial_rep_dense_cov(fit, fit$opt$par)
  td <- fit$tmb_data
  trait_one <- which(td$trait_id == 0L)
  state <- td$temporal_state_id + 1L
  i <- trait_one[[1L]]
  same_series_later <- trait_one[td$site_id[trait_one] == td$site_id[[i]] &
    state[trait_one] != state[[i]]][[1L]]
  other_series <- trait_one[td$site_id[trait_one] != td$site_id[[i]]][[1L]]
  chosen <- c(i, same_series_later, other_series)
  empirical <- stats::cov(t(draws[chosen, , drop = FALSE]))
  pairs <- rbind(c(1L, 2L), c(1L, 3L))
  critical <- stats::qnorm(1 - .05 / (2 * nrow(pairs)))
  for (row in seq_len(nrow(pairs))) {
    a <- chosen[[pairs[row, 1L]]]; b <- chosen[[pairs[row, 2L]]]
    se <- sqrt((V[a, a] * V[b, b] + V[a, b]^2) / (ncol(draws) - 1L))
    expect_lte(abs(empirical[pairs[row, 1L], pairs[row, 2L]] - V[a, b]), critical * se)
  }
  expect_equal(dim(simulate(fit, nsim = 2, seed = 11, condition_on_RE = TRUE)),
    c(nrow(fx$data), 2L))
})
