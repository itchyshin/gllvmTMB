.temporal_main_kernel_forecast_fixture <- function(phi = -.45) {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data,
    as.numeric(factor(trait)) + .11 * occasion +
      c(s1 = -.25, s2 = .05, s3 = .2)[series] +
      c(m1 = -.03, m2 = .03)[measurement]
  )
  kernel <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L,
    dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion,
        replicate = measurement) +
      kernel_indep(series, K = kernel, name = "forecast_kernel"),
    data = data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L
    )
  ))
  time_index <- match("theta_temporal_time", names(fit$opt$par))
  fit$opt$par[[time_index]] <- atanh(phi / (1 - 1e-6))
  fit$opt$par[names(fit$opt$par) == "theta_temporal_diag"] <- log(c(.35, .45, .55))
  fit$opt$par[names(fit$opt$par) == "theta_rr_phy"] <- c(.25, .4, .6)
  fit$opt$par[names(fit$opt$par) == "log_sigma_eps"] <- log(.3)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  list(data = data, kernel = kernel, fit = fit, par = par)
}

.temporal_main_kernel_forecast_covariance <- function(fit, par, kernel, left,
                                                       right = left) {
  traits <- levels(fit$data[[fit$trait_col]])
  left_trait <- match(as.character(left$trait), traits)
  right_trait <- match(as.character(right$trait), traits)
  same_series <- outer(as.character(left$series), as.character(right$series), `==`)
  lag <- abs(outer(as.numeric(left$occasion), as.numeric(right$occasion), `-`))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal <- phi^lag
  temporal[!same_series] <- 0
  temporal_variance <- exp(2 * par$theta_temporal_diag)
  kernel_variance <- par$theta_rr_phy^2
  temporal_entry <- outer(left_trait, right_trait,
    Vectorize(function(i, j) if (i == j) temporal_variance[[i]] else 0))
  kernel_variance_entry <- outer(left_trait, right_trait,
    Vectorize(function(i, j) if (i == j) kernel_variance[[i]] else 0))
  kernel_entry <- outer(as.character(left$series), as.character(right$series),
    Vectorize(function(a, b) kernel[a, b]))
  out <- temporal * temporal_entry + kernel_entry * kernel_variance_entry
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

.temporal_main_kernel_forecast_product_covariance <- function(fit, par, kernel,
                                                               left, right = left) {
  traits <- levels(fit$data[[fit$trait_col]])
  left_trait <- match(as.character(left$trait), traits)
  right_trait <- match(as.character(right$trait), traits)
  same_series <- outer(as.character(left$series), as.character(right$series), `==`)
  lag <- abs(outer(as.numeric(left$occasion), as.numeric(right$occasion), `-`))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal <- phi^lag
  temporal[!same_series] <- 0
  temporal_variance <- exp(2 * par$theta_temporal_diag)
  temporal_entry <- outer(left_trait, right_trait,
    Vectorize(function(i, j) if (i == j) temporal_variance[[i]] else 0))
  kernel_entry <- outer(as.character(left$series), as.character(right$series),
    Vectorize(function(a, b) kernel[a, b]))
  out <- temporal * kernel_entry * temporal_entry
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

.temporal_main_kernel_forecast_expected <- function(fx, future, covariance =
                                                       .temporal_main_kernel_forecast_covariance) {
  fit <- fx$fit
  par <- fx$par
  future_model <- gllvmTMB:::.gllvmTMB_restore_newdata_factor_levels(future, fit$data)
  fixed_observed <- as.numeric(fit$tmb_data$X_fix %*% par$b_fix)
  fixed_future <- as.numeric(stats::model.matrix(
    stats::delete.response(stats::terms(fit$formula)), future_model
  ) %*% par$b_fix)
  observed_covariance <- covariance(fit, par, fx$kernel, fx$data)
  future_covariance <- covariance(fit, par, fx$kernel, future)
  cross_covariance <- covariance(fit, par, fx$kernel, fx$data, future)
  solution <- solve(observed_covariance, cbind(fx$data$value - fixed_observed,
    cross_covariance))
  list(
    est = fixed_future + drop(crossprod(cross_covariance, solution[, 1L])),
    se = sqrt(pmax(diag(future_covariance -
      crossprod(cross_covariance, solution[, -1L, drop = FALSE])), 0))
  )
}

test_that("replicated temporal_indep plus kernel forecast matches dense Gaussian conditioning", {
  skip_if_not_installed("TMB")
  fx <- .temporal_main_kernel_forecast_fixture(phi = -.45)
  future <- expand.grid(series = c("s1", "s2", "s3"), occasion = 5L,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  future <- future[c(9L, 1L, 15L, 3L, 18L, 4L, 12L, 6L, 10L, 2L, 16L, 5L, 13L, 7L, 17L, 8L, 14L, 11L), ]
  expected <- .temporal_main_kernel_forecast_expected(fx, future)
  wrong_product <- .temporal_main_kernel_forecast_expected(fx, future,
    .temporal_main_kernel_forecast_product_covariance)

  out <- forecast_temporal(fx$fit, future, se.fit = TRUE)
  expect_identical(as.character(out$series), future$series)
  expect_identical(out$occasion, future$occasion)
  expect_identical(out$measurement, future$measurement)
  expect_identical(as.character(out$trait), future$trait)
  expect_equal(out$est, expected$est, tolerance = 1e-8)
  expect_equal(out$se.fit, expected$se, tolerance = 1e-8)
  expect_gt(max(abs(out$est - wrong_product$est)), 1e-4)
})

test_that("replicated temporal_indep plus kernel forecast has the positive-AR1 dense limit", {
  skip_if_not_installed("TMB")
  fx <- .temporal_main_kernel_forecast_fixture(phi = .45)
  future <- expand.grid(series = c("s1", "s2"), occasion = 5L,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  expected <- .temporal_main_kernel_forecast_expected(fx, future)
  out <- forecast_temporal(fx$fit, future, se.fit = TRUE)
  expect_equal(out$est, expected$est, tolerance = 1e-8)
  expect_equal(out$se.fit, expected$se, tolerance = 1e-8)
})

test_that("replicated temporal_indep plus kernel forecast rejects incomplete or non-future panels", {
  skip_if_not_installed("TMB")
  fx <- .temporal_main_kernel_forecast_fixture()
  future <- expand.grid(series = "s1", occasion = 5L, measurement = c("m1", "m2"),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  expect_error(forecast_temporal(fx$fit, future[-1L, , drop = FALSE]), "complete trait panel")
  expect_error(forecast_temporal(fx$fit, transform(future, occasion = 4L)), "strictly after")
})
