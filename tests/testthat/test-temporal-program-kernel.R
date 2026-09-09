.temporal_program_kernel_fixture <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3,
    trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data,
    as.numeric(factor(trait)) + 0.15 * occasion +
      c(s1 = -0.3, s2 = 0.1, s3 = 0.25)[series])
  K <- matrix(c(
    1.0, 0.35, 0.15,
    0.35, 1.0, 0.25,
    0.15, 0.25, 1.0
  ), 3L, 3L, byrow = TRUE,
  dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  list(data = data, K = K)
}

.temporal_program_kernel_dense_nll <- function(fit, fixed, K) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  kernel_level <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  same_series <- outer(pair$series, pair$series, FUN = "==")
  lag <- abs(outer(pair$time, pair$time, "-"))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal_correlation <- phi^lag
  temporal_correlation[!same_series] <- 0
  temporal_variance <- exp(2 * par$theta_temporal_diag)
  kernel_loading <- diag(par$theta_rr_phy, nrow = length(temporal_variance))
  kernel_covariance <- tcrossprod(kernel_loading)
  covariance <-
    temporal_correlation[state, state] *
      diag(temporal_variance)[trait, trait] +
    K[kernel_level, kernel_level] * kernel_covariance[trait, trait]
  diag(covariance) <- diag(covariance) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  chol_covariance <- chol(covariance)
  0.5 * (length(residual) * log(2 * pi) +
    2 * sum(log(diag(chol_covariance))) +
    sum(backsolve(chol_covariance, residual, transpose = TRUE)^2))
}

test_that("one temporal source combines additively with one labelled kernel", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_kernel_fixture()

  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      kernel_indep(series, K = fx$K, name = "static_kernel"),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_true(isTRUE(fit$use$kernel))
  expect_equal(fit$kernel_levels$name, "static_kernel")
})

test_that("temporal plus kernel_indep matches an independent dense likelihood", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_kernel_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      kernel_indep(series, K = fx$K, name = "static_kernel"),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(0.1, -0.15, 0.2)
  fixed[names(fixed) == "theta_temporal_time"] <-
    atanh(0.55 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(0.35, 0.45, 0.55))
  fixed[names(fixed) == "theta_rr_phy"] <- c(0.25, 0.40, 0.60)
  fixed[names(fixed) == "log_sigma_eps"] <- log(0.3)

  expect_equal(
    as.numeric(fit$tmb_obj$fn(fixed)),
    .temporal_program_kernel_dense_nll(fit, fixed, fx$K),
    tolerance = 2e-6
  )
  for (index in c(
    match("theta_temporal_time", names(fixed)),
    which(names(fixed) == "theta_rr_phy")[[2L]]
  )) {
    h <- 1e-5
    plus <- fixed; plus[[index]] <- plus[[index]] + h
    minus <- fixed; minus[[index]] <- minus[[index]] - h
    dense_gradient <-
      (.temporal_program_kernel_dense_nll(fit, plus, fx$K) -
       .temporal_program_kernel_dense_nll(fit, minus, fx$K)) / (2 * h)
    expect_equal(fit$tmb_obj$gr(fixed)[[index]], dense_gradient,
      tolerance = 2e-5, info = names(fixed)[[index]])
  }
})

test_that("the admitted temporal-kernel cell preserves long and wide identity", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_kernel_fixture()
  long_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      kernel_indep(series, K = fx$K, name = "static_kernel"),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  wide <- unique(fx$data[c("series", "occasion")])
  for (trait_name in paste0("t", 1:3)) {
    wide[[sub("t", "y", trait_name)]] <-
      fx$data$value[fx$data$trait == trait_name]
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_indep(1 | series, time = occasion) +
      kernel_indep(series, K = fx$K, name = "static_kernel"),
    data = wide, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_identical(wide_fit$temporal$mode, "indep")
  expect_equal(
    unname(as.matrix(extract_temporal(long_fit)$pair_index)),
    unname(as.matrix(extract_temporal(wide_fit)$pair_index))
  )
  expect_equal(wide_fit$kernel_levels$name, long_fit$kernel_levels$name)
  expect_equal(wide_fit$tmb_data$use_temporal, long_fit$tmb_data$use_temporal)
})

test_that("the admitted covariance is additive, not a source-by-time product", {
  fx <- .temporal_program_kernel_fixture()
  series <- rep(seq_len(3), each = 3L)
  occasion <- rep(seq_len(3), times = 3L)
  temporal_component <- outer(series, series, FUN = "==") *
    0.55^abs(outer(occasion, occasion, "-"))
  kernel_component <- fx$K[series, series]
  additive <- temporal_component + kernel_component
  product <- temporal_component * kernel_component
  expect_gt(max(abs(additive - product)), 1e-3)
})

test_that("unvalidated temporal-plus-kernel cells remain refused", {
  fx <- .temporal_program_kernel_fixture()
  expect_error(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      kernel_dep(series, K = fx$K, name = "static_kernel"),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE
  ), "currently supports only.*kernel_indep")
})
