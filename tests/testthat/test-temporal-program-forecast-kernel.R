.temporal_kernel_forecast_fixture <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data,
    as.numeric(factor(trait)) + .12 * occasion +
      c(s1 = -.3, s2 = .1, s3 = .25)[series] +
      c(m1 = -.04, m2 = .04)[measurement])
  K <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L, 3L,
    byrow = TRUE, dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion,
        replicate = measurement) +
      kernel_indep(series, K = K, name = "fixed_kernel"),
    data = data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  list(data = data, K = K, fit = fit)
}

.temporal_kernel_forecast_dense_covariance <- function(fit, left, right = left) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  trait_levels <- levels(fit$data[[fit$trait_col]])
  trait_left <- match(as.character(left[[fit$trait_col]]), trait_levels)
  trait_right <- match(as.character(right[[fit$trait_col]]), trait_levels)
  series_left <- as.character(left[[fit$temporal$series_col]])
  series_right <- as.character(right[[fit$temporal$series_col]])
  time_left <- as.numeric(left[[fit$temporal$time_col]])
  time_right <- as.numeric(right[[fit$temporal$time_col]])
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal <- outer(series_left, series_right, "==") *
    phi^abs(outer(time_left, time_right, "-"))
  temporal_sigma <- if (identical(fit$temporal$mode, "latent")) {
    tcrossprod(as.numeric(par$theta_temporal_rr))
  } else diag(exp(2 * par$theta_temporal_diag), nrow = length(trait_levels))
  source_left <- match(series_left, rownames(fit$kernel_matrices$fixed_kernel))
  source_right <- match(series_right, colnames(fit$kernel_matrices$fixed_kernel))
  kernel_sigma <- diag(par$theta_rr_phy^2, nrow = length(trait_levels))
  out <- temporal * temporal_sigma[trait_left, trait_right] +
    fit$kernel_matrices$fixed_kernel[source_left, source_right] *
      kernel_sigma[trait_left, trait_right]
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

.temporal_kernel_forecast_product_covariance <- function(fit, left, right = left) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  trait_levels <- levels(fit$data[[fit$trait_col]])
  trait_left <- match(as.character(left[[fit$trait_col]]), trait_levels)
  trait_right <- match(as.character(right[[fit$trait_col]]), trait_levels)
  series_left <- as.character(left[[fit$temporal$series_col]])
  series_right <- as.character(right[[fit$temporal$series_col]])
  time_left <- as.numeric(left[[fit$temporal$time_col]])
  time_right <- as.numeric(right[[fit$temporal$time_col]])
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  source_left <- match(series_left, rownames(fit$kernel_matrices$fixed_kernel))
  source_right <- match(series_right, colnames(fit$kernel_matrices$fixed_kernel))
  out <- outer(series_left, series_right, "==") * phi^abs(outer(time_left, time_right, "-")) *
    fit$kernel_matrices$fixed_kernel[source_left, source_right] *
    diag(exp(2 * par$theta_temporal_diag), nrow = length(trait_levels))[trait_left, trait_right]
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

test_that("replicated temporal-kernel forecasts match additive dense conditioning", {
  skip_if_not_installed("TMB")
  fx <- .temporal_kernel_forecast_fixture()
  fx$fit$opt$par[match("theta_temporal_time", names(fx$fit$opt$par))] <-
    atanh(.55 / (1 - 1e-6))
  fx$fit$opt$par[which(names(fx$fit$opt$par) == "theta_rr_phy")] <-
    c(.25, .4, .6)
  future <- expand.grid(series = paste0("s", 1:3), occasion = c(5L, 6L),
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  observed <- forecast_temporal(fx$fit, future, se.fit = TRUE)
  all_rows <- rbind(fx$data[, names(future)], future)
  V <- .temporal_kernel_forecast_dense_covariance(fx$fit, all_rows)
  n_observed <- nrow(fx$data)
  Voo <- V[seq_len(n_observed), seq_len(n_observed), drop = FALSE]
  Von <- V[seq_len(n_observed), n_observed + seq_len(nrow(future)), drop = FALSE]
  Vnn <- V[n_observed + seq_len(nrow(future)), n_observed + seq_len(nrow(future)), drop = FALSE]
  beta <- gllvmTMB:::.gllvmTMB_b_fix_values(fx$fit)
  Xo <- fx$fit$tmb_data$X_fix
  Xn <- stats::model.matrix(stats::delete.response(stats::terms(fx$fit$formula)), future)
  solved <- solve(Voo, cbind(fx$data$value - drop(Xo %*% beta), Von))
  expected_mean <- drop(Xn %*% beta + t(Von) %*% solved[, 1L])
  expected_variance <- diag(Vnn - t(Von) %*% solved[, -1L, drop = FALSE])
  expect_equal(observed$est, unname(expected_mean), tolerance = 1e-8)
  expect_equal(observed$se.fit, unname(sqrt(pmax(expected_variance, 0))), tolerance = 1e-8)
  expect_gt(max(abs(V - .temporal_kernel_forecast_product_covariance(fx$fit, all_rows))), 1e-3)

  fx$fit$opt$par[match("theta_temporal_time", names(fx$fit$opt$par))] <-
    atanh(-.55 / (1 - 1e-6))
  negative <- forecast_temporal(fx$fit, future)
  negative_V <- .temporal_kernel_forecast_dense_covariance(fx$fit, all_rows)
  negative_Voo <- negative_V[seq_len(n_observed), seq_len(n_observed), drop = FALSE]
  negative_Von <- negative_V[seq_len(n_observed), n_observed + seq_len(nrow(future)), drop = FALSE]
  negative_mean <- drop(Xn %*% beta + t(negative_Von) %*%
    solve(negative_Voo, fx$data$value - drop(Xo %*% beta)))
  expect_equal(negative$est, unname(negative_mean), tolerance = 1e-8)
})

test_that("replicated temporal-kernel forecasts validate future measurement panels and row order", {
  skip_if_not_installed("TMB")
  fx <- .temporal_kernel_forecast_fixture()
  future <- expand.grid(series = paste0("s", 1:3), occasion = 5L,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  reference <- forecast_temporal(fx$fit, future, se.fit = TRUE)
  set.seed(260941L)
  shuffled <- future[sample.int(nrow(future)), , drop = FALSE]
  reordered <- forecast_temporal(fx$fit, shuffled, se.fit = TRUE)
  key <- c("series", "occasion", "measurement", "trait")
  index <- match(do.call(paste, c(shuffled[key], sep = "\r")),
    do.call(paste, c(future[key], sep = "\r")))
  expect_equal(reordered$est, reference$est[index], tolerance = 1e-8)
  expect_equal(reordered$se.fit, reference$se.fit[index], tolerance = 1e-8)
  expect_error(forecast_temporal(fx$fit, future[, setdiff(names(future), "measurement")]),
    "missing required temporal column")
  expect_error(forecast_temporal(fx$fit, future[-1L, , drop = FALSE]), "complete trait panel")
  expect_error(forecast_temporal(fx$fit, transform(future, series = "new")), "existing series")
})

test_that("rank-one temporal-kernel forecasts match the dense conditioning oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_kernel_forecast_fixture()
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
      d = 1, unique = FALSE) + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)))
  fit$opt$par[match("theta_temporal_time", names(fit$opt$par))] <- atanh(.5 / (1 - 1e-6))
  fit$opt$par[which(names(fit$opt$par) == "theta_temporal_rr")] <- c(.7, -.4, .25)
  future <- expand.grid(series = paste0("s", 1:3), occasion = 5L,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE)
  got <- forecast_temporal(fit, future, se.fit = TRUE)
  all_rows <- rbind(fx$data[, names(future)], future); n <- nrow(fx$data)
  V <- .temporal_kernel_forecast_dense_covariance(fit, all_rows)
  beta <- gllvmTMB:::.gllvmTMB_b_fix_values(fit)
  Xn <- stats::model.matrix(stats::delete.response(stats::terms(fit$formula)), future)
  solved <- solve(V[seq_len(n), seq_len(n)], cbind(fx$data$value - drop(fit$tmb_data$X_fix %*% beta), V[seq_len(n), n + seq_len(nrow(future))]))
  expect_equal(got$est, unname(drop(Xn %*% beta + t(V[seq_len(n), n + seq_len(nrow(future))]) %*% solved[, 1L])), tolerance = 1e-8)
  expect_equal(got$se.fit, unname(sqrt(pmax(diag(V[n + seq_len(nrow(future)), n + seq_len(nrow(future))] - t(V[seq_len(n), n + seq_len(nrow(future))]) %*% solved[, -1L, drop = FALSE]), 0))), tolerance = 1e-8)
})

.temporal_animal_forecast_fixture <- function() {
  data <- expand.grid(
    series = paste0("s", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data, as.numeric(factor(trait)) + .1 * occasion +
    c(s1 = -.2, s2 = .1, s3 = .25, s4 = -.1)[series] +
    c(m1 = -.03, m2 = .03)[measurement])
  A <- matrix(c(1, 0, .5, .5, 0, 1, .5, .5, .5, .5, 1, .5, .5, .5, .5, 1),
    4L, 4L, byrow = TRUE, dimnames = list(paste0("s", 1:4), paste0("s", 1:4)))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion,
        replicate = measurement, d = 1, unique = FALSE) +
      animal_indep(0 + trait | series, A = A),
    data = data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  list(data = data, A = A, fit = fit)
}

.temporal_animal_forecast_dense_covariance <- function(fit, left, right = left) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  traits <- levels(fit$data[[fit$trait_col]])
  trait_left <- match(as.character(left[[fit$trait_col]]), traits)
  trait_right <- match(as.character(right[[fit$trait_col]]), traits)
  series_left <- as.character(left[[fit$temporal$series_col]])
  series_right <- as.character(right[[fit$temporal$series_col]])
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal <- outer(series_left, series_right, "==") *
    phi^abs(outer(as.numeric(left[[fit$temporal$time_col]]),
      as.numeric(right[[fit$temporal$time_col]]), "-"))
  lambda <- as.numeric(par$theta_temporal_rr)
  temporal_sigma <- tcrossprod(lambda)
  animal_left <- match(series_left, rownames(fit$phylo_vcv))
  animal_right <- match(series_right, colnames(fit$phylo_vcv))
  animal_sigma <- diag(par$theta_rr_phy^2, nrow = length(traits))
  out <- temporal * temporal_sigma[trait_left, trait_right] +
    fit$phylo_vcv[animal_left, animal_right] * animal_sigma[trait_left, trait_right]
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

test_that("rank-one temporal-animal forecasts match additive dense conditioning", {
  skip_if_not_installed("TMB")
  fx <- .temporal_animal_forecast_fixture()
  fx$fit$opt$par[match("theta_temporal_time", names(fx$fit$opt$par))] <-
    atanh(.55 / (1 - 1e-6))
  fx$fit$opt$par[which(names(fx$fit$opt$par) == "theta_temporal_rr")] <- c(.7, -.4, .25)
  fx$fit$opt$par[which(names(fx$fit$opt$par) == "theta_rr_phy")] <- c(.2, .35, .5)
  future <- expand.grid(series = paste0("s", 1:4), occasion = c(5L, 6L),
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  observed <- forecast_temporal(fx$fit, future, se.fit = TRUE)
  all_rows <- rbind(fx$data[, names(future)], future)
  V <- .temporal_animal_forecast_dense_covariance(fx$fit, all_rows)
  n_observed <- nrow(fx$data)
  Voo <- V[seq_len(n_observed), seq_len(n_observed), drop = FALSE]
  Von <- V[seq_len(n_observed), n_observed + seq_len(nrow(future)), drop = FALSE]
  Vnn <- V[n_observed + seq_len(nrow(future)), n_observed + seq_len(nrow(future)), drop = FALSE]
  beta <- gllvmTMB:::.gllvmTMB_b_fix_values(fx$fit)
  Xn <- stats::model.matrix(stats::delete.response(stats::terms(fx$fit$formula)), future)
  solved <- solve(Voo, cbind(fx$data$value - drop(fx$fit$tmb_data$X_fix %*% beta), Von))
  expect_equal(observed$est, unname(drop(Xn %*% beta + t(Von) %*% solved[, 1L])), tolerance = 1e-8)
  expect_equal(observed$se.fit, unname(sqrt(pmax(diag(Vnn - t(Von) %*% solved[, -1L, drop = FALSE]), 0))), tolerance = 1e-8)
  product <- outer(as.character(all_rows$series), as.character(all_rows$series), "==") *
    ((1 - 1e-6) * tanh(fx$fit$tmb_obj$env$parList(fx$fit$opt$par)$theta_temporal_time))^
      abs(outer(all_rows$occasion, all_rows$occasion, "-")) *
    fx$A[match(all_rows$series, rownames(fx$A)), match(all_rows$series, colnames(fx$A))]
  expect_gt(max(abs(V - product * tcrossprod(c(.7, -.4, .25))[match(all_rows$trait, paste0("t", 1:3)), match(all_rows$trait, paste0("t", 1:3))])), 1e-3)

  fx$fit$opt$par[match("theta_temporal_time", names(fx$fit$opt$par))] <-
    atanh(-.55 / (1 - 1e-6))
  negative <- forecast_temporal(fx$fit, future)
  negative_V <- .temporal_animal_forecast_dense_covariance(fx$fit, all_rows)
  negative_mean <- drop(Xn %*% beta + negative_V[n_observed + seq_len(nrow(future)), seq_len(n_observed), drop = FALSE] %*%
    solve(negative_V[seq_len(n_observed), seq_len(n_observed), drop = FALSE], fx$data$value - drop(fx$fit$tmb_data$X_fix %*% beta)))
  expect_equal(negative$est, unname(negative_mean), tolerance = 1e-8)

  set.seed(260942L)
  shuffled <- future[sample.int(nrow(future)), , drop = FALSE]
  reordered <- forecast_temporal(fx$fit, shuffled, se.fit = TRUE)
  reference <- forecast_temporal(fx$fit, future, se.fit = TRUE)
  key <- c("series", "occasion", "measurement", "trait")
  index <- match(do.call(paste, c(shuffled[key], sep = "\r")), do.call(paste, c(future[key], sep = "\r")))
  expect_equal(reordered$est, reference$est[index], tolerance = 1e-8)
  expect_equal(reordered$se.fit, reference$se.fit[index], tolerance = 1e-8)
})

.temporal_spatial_forecast_fixture <- function() {
  key <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  location <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  location$lon <- c(0, 1, .2, .8, .4, .6, .3, .7, .5)
  location$lat <- c(0, 0, 1, 1, .8, .2, .7, .3, .5)
  key <- merge(key, location, by = c("series", "occasion"), sort = FALSE)
  data <- key[rep(seq_len(nrow(key)), each = 3L), , drop = FALSE]
  data$trait <- rep(paste0("t", 1:3), nrow(key))
  data$value <- with(data, as.numeric(factor(trait)) + .1 * occasion +
    c(s1 = -.2, s2 = .1, s3 = .25)[series] + c(m1 = -.03, m2 = .03)[measurement])
  mesh <- make_mesh(data, c("lon", "lat"), cutoff = .05)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion,
        replicate = measurement, d = 1, unique = FALSE) +
      spatial_indep(0 + trait | coords, mesh = mesh),
    data = data, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  list(data = data, fit = fit)
}

.temporal_spatial_forecast_dense_covariance <- function(fit, left, right = left) {
  par <- fit$tmb_obj$env$parList(fit$opt$par); td <- fit$tmb_data
  traits <- levels(fit$data[[fit$trait_col]])
  trait_left <- match(as.character(left[[fit$trait_col]]), traits)
  trait_right <- match(as.character(right[[fit$trait_col]]), traits)
  series_left <- as.character(left[[fit$temporal$series_col]])
  series_right <- as.character(right[[fit$temporal$series_col]])
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal <- outer(series_left, series_right, "==") *
    phi^abs(outer(as.numeric(left[[fit$temporal$time_col]]),
      as.numeric(right[[fit$temporal$time_col]]), "-"))
  P_left <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(left[, fit$mesh$xy_cols, drop = FALSE])))
  P_right <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(right[, fit$mesh$xy_cols, drop = FALSE])))
  kappa <- exp(par$log_kappa_spde)
  Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) + as.matrix(td$spde_M2)
  spatial <- P_left %*% solve(Q) %*% t(P_right)
  out <- temporal * tcrossprod(as.numeric(par$theta_temporal_rr))[trait_left, trait_right] +
    spatial * diag(exp(-2 * par$log_tau_spde), nrow = length(traits))[trait_left, trait_right]
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

test_that("rank-one temporal-spatial forecasts match additive dense conditioning", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_spatial_forecast_fixture()
  fx$fit$opt$par[match("theta_temporal_time", names(fx$fit$opt$par))] <- atanh(.5 / (1 - 1e-6))
  fx$fit$opt$par[which(names(fx$fit$opt$par) == "theta_temporal_rr")] <- c(.7, -.4, .25)
  fx$fit$opt$par[which(names(fx$fit$opt$par) == "log_tau_spde")] <- log(c(1.1, .9, 1.2))
  future <- expand.grid(series = paste0("s", 1:3), occasion = 4L,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE)
  location <- unique(fx$data[c("series", "lon", "lat")])
  location <- location[!duplicated(location$series), , drop = FALSE]
  location$occasion <- 4L
  future <- merge(future, location, by = c("series", "occasion"), sort = FALSE)
  observed <- forecast_temporal(fx$fit, future, se.fit = TRUE)
  all_rows <- rbind(fx$data[, names(future)], future)
  V <- .temporal_spatial_forecast_dense_covariance(fx$fit, all_rows)
  n_observed <- nrow(fx$data); ix_observed <- seq_len(n_observed); ix_future <- n_observed + seq_len(nrow(future))
  beta <- gllvmTMB:::.gllvmTMB_b_fix_values(fx$fit)
  Xn <- stats::model.matrix(stats::delete.response(stats::terms(fx$fit$formula)), future)
  solved <- solve(V[ix_observed, ix_observed], cbind(fx$data$value - drop(fx$fit$tmb_data$X_fix %*% beta), V[ix_observed, ix_future]))
  expect_equal(observed$est, unname(drop(Xn %*% beta + t(V[ix_observed, ix_future]) %*% solved[, 1L])), tolerance = 1e-8)
  expect_equal(observed$se.fit, unname(sqrt(pmax(diag(V[ix_future, ix_future] - t(V[ix_observed, ix_future]) %*% solved[, -1L, drop = FALSE]), 0))), tolerance = 1e-8)
  product <- outer(as.character(all_rows$series), as.character(all_rows$series), "==") *
    ((1 - 1e-6) * tanh(fx$fit$tmb_obj$env$parList(fx$fit$opt$par)$theta_temporal_time))^
      abs(outer(all_rows$occasion, all_rows$occasion, "-")) *
    .temporal_spatial_forecast_dense_covariance(fx$fit, all_rows)
  expect_gt(max(abs(V - product)), 1e-3)

  fx$fit$opt$par[match("theta_temporal_time", names(fx$fit$opt$par))] <- atanh(-.5 / (1 - 1e-6))
  negative <- forecast_temporal(fx$fit, future)
  negative_V <- .temporal_spatial_forecast_dense_covariance(fx$fit, all_rows)
  negative_mean <- drop(Xn %*% beta + negative_V[ix_future, ix_observed] %*%
    solve(negative_V[ix_observed, ix_observed], fx$data$value - drop(fx$fit$tmb_data$X_fix %*% beta)))
  expect_equal(negative$est, unname(negative_mean), tolerance = 1e-8)

  set.seed(260943L)
  shuffled <- future[sample.int(nrow(future)), , drop = FALSE]
  reference <- forecast_temporal(fx$fit, future, se.fit = TRUE)
  reordered <- forecast_temporal(fx$fit, shuffled, se.fit = TRUE)
  key <- c("series", "occasion", "measurement", "trait")
  index <- match(do.call(paste, c(shuffled[key], sep = "\r")), do.call(paste, c(future[key], sep = "\r")))
  expect_equal(reordered$est, reference$est[index], tolerance = 1e-8)
  expect_equal(reordered$se.fit, reference$se.fit[index], tolerance = 1e-8)
  expect_error(forecast_temporal(fx$fit, future[, setdiff(names(future), "lon")]), "coordinate columns")
  trait_mismatch <- future
  trait_mismatch$lon[trait_mismatch$trait == "t2"] <- trait_mismatch$lon[trait_mismatch$trait == "t2"] + .1
  expect_error(forecast_temporal(fx$fit, trait_mismatch), "shared spatial coordinate")
  replicate_mismatch <- future
  replicate_mismatch$lat[replicate_mismatch$measurement == "m2"] <- replicate_mismatch$lat[replicate_mismatch$measurement == "m2"] + .1
  expect_error(forecast_temporal(fx$fit, replicate_mismatch), "shared spatial coordinate")
})
