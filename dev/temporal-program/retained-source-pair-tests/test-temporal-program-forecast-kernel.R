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
  temporal_sigma <- diag(exp(2 * par$theta_temporal_diag), nrow = length(trait_levels))
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
