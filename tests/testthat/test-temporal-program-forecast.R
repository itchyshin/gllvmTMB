.temporal_forecast_fixture <- function(structure = c("ar1", "ou")) {
  structure <- match.arg(structure)
  data <- expand.grid(
    series = c("s1", "s2"), occasion = c(1L, 2L, 3L),
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  data$elapsed <- c(0, 1.5, 4)[match(data$occasion, c(1L, 2L, 3L))]
  data$value <- with(data, as.numeric(factor(trait)) / 4 +
    as.numeric(factor(series)) / 5 + occasion / 10)
  list(
    data = data,
    time = if (identical(structure, "ar1")) "occasion" else "elapsed",
    structure = structure
  )
}

.temporal_forecast_dense_covariance <- function(fit, data) {
  td <- fit$tmb_data
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  trait_levels <- levels(fit$data[[fit$trait_col]])
  trait <- match(as.character(data[[fit$trait_col]]), trait_levels)
  series <- as.character(data[[fit$temporal$series_col]])
  time <- as.numeric(data[[fit$temporal$time_col]])
  same_series <- outer(series, series, FUN = "==")
  gap <- abs(outer(time, time, "-"))
  correlation <- if (identical(fit$temporal$structure, "ar1")) {
    ((1 - 1e-6) * tanh(par$theta_temporal_time))^gap
  } else {
    exp(-exp(par$theta_temporal_time) * gap)
  }
  correlation[!same_series] <- 0
  sigma <- if (identical(fit$temporal$mode, "indep")) {
    diag(exp(2 * par$theta_temporal_diag), nrow = length(trait_levels))
  } else {
    lambda <- as.matrix(fit$report$Lambda_temporal)
    out <- lambda %*% t(lambda)
    if (isTRUE(fit$temporal$unique)) {
      diag(out) <- diag(out) + exp(2 * par$theta_temporal_diag)
    }
    out
  }
  correlation * sigma[trait, trait] +
    diag(as.numeric(fit$report$sigma_eps)^2, nrow(data))
}

test_that("temporal future forecasts match independent dense Gaussian conditioning", {
  fixture <- .temporal_forecast_fixture("ar1")
  data <- fixture$data
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = data, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  future <- expand.grid(
    series = c("s1", "s2"), occasion = c(4L, 5L),
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  forecast <- forecast_temporal(fit, future, se.fit = TRUE)

  all_data <- rbind(data[, c("series", "occasion", "trait")], future)
  covariance <- .temporal_forecast_dense_covariance(fit, all_data)
  n_observed <- nrow(data)
  X_observed <- stats::model.matrix(
    stats::delete.response(stats::terms(fit$formula)), data
  )
  X_future <- stats::model.matrix(
    stats::delete.response(stats::terms(fit$formula)), future
  )
  beta <- gllvmTMB:::.gllvmTMB_b_fix_values(fit)
  residual <- data$value - drop(X_observed %*% beta)
  V_oo <- covariance[seq_len(n_observed), seq_len(n_observed), drop = FALSE]
  V_on <- covariance[seq_len(n_observed), n_observed + seq_len(nrow(future)), drop = FALSE]
  V_nn <- covariance[n_observed + seq_len(nrow(future)), n_observed + seq_len(nrow(future)), drop = FALSE]
  solved <- solve(V_oo, cbind(residual, V_on))
  expected_mean <- drop(X_future %*% beta + t(V_on) %*% solved[, 1L])
  expected_variance <- diag(V_nn - t(V_on) %*% solved[, -1L, drop = FALSE])

  expect_equal(forecast$est, unname(expected_mean), tolerance = 1e-8)
  expect_equal(forecast$se.fit, sqrt(pmax(expected_variance, 0)), tolerance = 1e-8)
  expect_identical(names(forecast)[1:3], names(future)[1:3])
})

test_that("temporal future forecasts reject unsupported layouts before calculation", {
  fixture <- .temporal_forecast_fixture("ou")
  data <- fixture$data
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = elapsed,
      structure = "ou"),
    data = data, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  future <- data[data$occasion == 3L, c("series", "elapsed", "trait"), drop = FALSE]
  future$elapsed <- future$elapsed + 2
  expect_error(forecast_temporal(fit, transform(future, series = "new_series")),
    "existing series")
  expect_error(forecast_temporal(fit, transform(future, elapsed = 1)),
    "strictly after")
  expect_error(forecast_temporal(fit, future[-1L, , drop = FALSE]),
    "complete trait panel")
})

test_that("temporal forecasts preserve negative AR1 and translated OU covariance", {
  ar1 <- .temporal_forecast_fixture("ar1")
  fit_ar1 <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = ar1$data, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  future_ar1 <- expand.grid(series = c("s1", "s2"), occasion = c(4L, 5L),
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE)
  theta <- match("theta_temporal_time", names(fit_ar1$opt$par))
  fit_ar1$opt$par[theta] <- atanh(-0.6 / (1 - 1e-6))
  expected_negative <- .temporal_forecast_dense_covariance(
    fit_ar1, rbind(ar1$data[, c("series", "occasion", "trait")], future_ar1)
  )
  n <- nrow(ar1$data)
  Voo <- expected_negative[seq_len(n), seq_len(n)]
  Von <- expected_negative[seq_len(n), n + seq_len(nrow(future_ar1)), drop = FALSE]
  Xo <- fit_ar1$tmb_data$X_fix
  Xn <- stats::model.matrix(stats::delete.response(stats::terms(fit_ar1$formula)), future_ar1)
  beta <- gllvmTMB:::.gllvmTMB_b_fix_values(fit_ar1)
  expected_mean <- drop(Xn %*% beta + t(Von) %*%
    solve(Voo, ar1$data$value - drop(Xo %*% beta)))
  expect_equal(forecast_temporal(fit_ar1, future_ar1)$est,
    unname(expected_mean), tolerance = 1e-8)

  ou <- .temporal_forecast_fixture("ou")
  fit_ou <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = elapsed,
      structure = "ou"), data = ou$data, unit = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  future_ou <- ou$data[ou$data$occasion == 3L, c("series", "elapsed", "trait")]
  future_ou$elapsed <- future_ou$elapsed + 2
  shifted <- fit_ou
  shifted$data$elapsed <- shifted$data$elapsed + 100
  shifted$temporal$pair_table$time <- shifted$temporal$pair_table$time + 100
  shifted_future <- future_ou
  shifted_future$elapsed <- shifted_future$elapsed + 100
  expect_equal(forecast_temporal(fit_ou, future_ou, se.fit = TRUE)[c("est", "se.fit")],
    forecast_temporal(shifted, shifted_future, se.fit = TRUE)[c("est", "se.fit")],
    tolerance = 1e-10)
})

test_that("temporal forecasts preserve shuffled future-panel row order", {
  fixture <- .temporal_forecast_fixture("ar1")
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = fixture$data, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  future <- expand.grid(series = c("s1", "s2"), occasion = c(4L, 5L),
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  reference <- forecast_temporal(fit, future, se.fit = TRUE)
  set.seed(260927L)
  shuffled <- future[sample.int(nrow(future)), , drop = FALSE]
  observed <- forecast_temporal(fit, shuffled, se.fit = TRUE)
  key <- c("series", "occasion", "trait")
  expect_identical(as.character(observed$series), as.character(shuffled$series))
  expect_identical(observed$occasion, shuffled$occasion)
  expect_identical(as.character(observed$trait), as.character(shuffled$trait))
  expected_order <- match(do.call(paste, c(shuffled[key], sep = "\r")),
    do.call(paste, c(future[key], sep = "\r")))
  expect_equal(observed$est, reference$est[expected_order], tolerance = 1e-10)
  expect_equal(observed$se.fit, reference$se.fit[expected_order], tolerance = 1e-10)
})
