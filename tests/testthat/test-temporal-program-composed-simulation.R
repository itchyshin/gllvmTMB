.temporal_program_composed_fixture <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  data$unit_obs <- paste(data$series, data$occasion)
  data$value <- with(data, as.numeric(factor(trait)) + occasion / 10)
  data
}

test_that("unconditional temporal simulation redraws temporal and ordinary tiers", {
  data <- .temporal_program_composed_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      indep(0 + trait | series) + indep(0 + trait | unit_obs),
    data = data, unit = "series", unit_obs = "unit_obs",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  local_mocked_bindings(rnorm = function(n, ...) rep.int(0, n), .package = "stats")
  local_mocked_bindings(
    .draw_y_per_family = function(fit, eta) eta,
    .package = "gllvmTMB"
  )

  draw <- simulate(fit, nsim = 1L, condition_on_RE = FALSE)
  expected <- as.numeric(fit$tmb_data$X_fix %*%
    gllvmTMB:::.gllvmTMB_b_fix_values(fit)) +
    gllvmTMB:::.gllvmTMB_offset_vec(fit)

  expect_equal(drop(draw), expected, tolerance = 1e-12)
})

test_that("conditional temporal simulation retains the full fitted predictor", {
  data <- .temporal_program_composed_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      indep(0 + trait | series) + indep(0 + trait | unit_obs),
    data = data, unit = "series", unit_obs = "unit_obs",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  local_mocked_bindings(rnorm = function(n, ...) rep.int(0, n), .package = "stats")
  local_mocked_bindings(
    .draw_y_per_family = function(fit, eta) eta,
    .package = "gllvmTMB"
  )

  draw <- simulate(fit, nsim = 1L, condition_on_RE = TRUE)

  expect_equal(drop(draw), as.numeric(fit$report$eta), tolerance = 1e-12)
})

.temporal_program_composed_covariance <- function(fit) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  pair <- fit$temporal$pair_table
  same_series <- outer(pair$series, pair$series, FUN = "==")
  lag <- abs(outer(pair$time, pair$time, "-"))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  trait_diagonal <- function(variance) {
    outer(trait, trait, function(i, j) ifelse(i == j, variance[i], 0))
  }
  temporal_correlation <- phi^lag
  temporal_correlation[!same_series] <- 0
  covariance <- temporal_correlation[state, state] *
    trait_diagonal(exp(2 * par$theta_temporal_diag))
  site <- td$site_id + 1L
  unit_obs <- td$site_species_id + 1L
  covariance <- covariance +
    outer(site, site, FUN = "==") *
      trait_diagonal(as.numeric(fit$report$sd_B)^2) +
    outer(unit_obs, unit_obs, FUN = "==") *
      trait_diagonal(as.numeric(fit$report$sd_W)^2)
  diag(covariance) <- diag(covariance) + exp(2 * par$log_sigma_eps[[1L]])
  covariance
}

test_that("composed temporal simulation matches independent Gaussian moments", {
  data <- .temporal_program_composed_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      indep(0 + trait | series) + indep(0 + trait | unit_obs),
    data = data, unit = "series", unit_obs = "unit_obs",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  draws <- simulate(fit, nsim = 10000L, seed = 260909L,
    condition_on_RE = FALSE)
  sampled <- stats::cov(t(draws))
  expected <- .temporal_program_composed_covariance(fit)
  selected <- list(
    c(1L, 1L),       # marginal variance
    c(1L, 4L),       # same series, distinct occasion
    c(1L, 2L),       # distinct series, stable-unit component only
    c(1L, 10L)       # distinct trait, independent covariance modes
  )
  n_draw <- ncol(draws)
  for (ij in selected) {
    i <- ij[[1L]]; j <- ij[[2L]]
    mc_se <- sqrt((expected[i, i] * expected[j, j] + expected[i, j]^2) /
      (n_draw - 1L))
    expect_true(abs(sampled[i, j] - expected[i, j]) <= 4.2 * mc_se,
      info = paste("entry", i, j))
  }
})
