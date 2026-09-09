.temporal_sixth_oracle_data <- function() {
  out <- expand.grid(
    series = c("a", "b"), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  out$elapsed <- c(0, 1.25, 4.5)[match(out$occasion, c(1L, 3L, 7L))]
  out$value <- with(out, 0.15 * as.integer(factor(trait)) +
    0.1 * occasion + as.integer(factor(series)) / 7)
  out
}

## This is deliberately not a wrapper around report(), extract_temporal(), or
## temporal simulation.  It reconstructs the public covariance directly from
## the fitted fixed parameter vector and compares that Gaussian marginal model
## with TMB's exact Laplace value for this all-Gaussian fixture.
.temporal_sixth_unpack_loading <- function(theta, n_trait, rank) {
  out <- matrix(0, n_trait, rank)
  cursor <- 1L
  for (column in seq_len(rank)) {
    out[column, column] <- theta[cursor]
    cursor <- cursor + 1L
  }
  for (column in seq_len(rank)) {
    if (column < n_trait) {
      for (row in (column + 1L):n_trait) {
        out[row, column] <- theta[cursor]
        cursor <- cursor + 1L
      }
    }
  }
  stopifnot(cursor == length(theta) + 1L)
  out
}

.temporal_sixth_dense_covariance <- function(fit, fixed, iid_psi = FALSE,
                                             ordinary = FALSE) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  pair <- fit$temporal$pair_table
  time <- pair$time
  same_series <- outer(pair$series, pair$series, FUN = "==")
  time_distance <- abs(outer(time, time, "-"))
  correlation <- if (identical(fit$temporal$structure, "ar1")) {
    ((1 - 1e-6) * tanh(par$theta_temporal_time))^time_distance
  } else {
    exp(-exp(par$theta_temporal_time) * time_distance)
  }
  correlation[!same_series] <- 0

  n_trait <- td$n_traits
  trait_covariance <- switch(fit$temporal$mode,
    indep = diag(exp(2 * par$theta_temporal_diag), n_trait),
    dep = {
      loading <- .temporal_sixth_unpack_loading(
        par$theta_temporal_rr, n_trait, n_trait
      )
      tcrossprod(loading)
    },
    latent = {
      loading <- .temporal_sixth_unpack_loading(
        par$theta_temporal_rr, n_trait, fit$temporal$d
      )
      covariance <- tcrossprod(loading)
      if (isTRUE(fit$temporal$unique)) {
        covariance <- covariance + diag(exp(2 * par$theta_temporal_diag), n_trait)
      }
      covariance
    }
  )
  covariance <- correlation[state, state] * trait_covariance[trait, trait]
  ## The retired prototype added Psi only at the same occasion.  Keeping this
  ## switch in the independent oracle gives the test an explicit wrong model
  ## to reject; production code never calls this helper.
  if (iid_psi && identical(fit$temporal$mode, "latent") &&
      isTRUE(fit$temporal$unique)) {
    loading <- .temporal_sixth_unpack_loading(
      par$theta_temporal_rr, n_trait, fit$temporal$d
    )
    covariance <- correlation[state, state] *
      tcrossprod(loading)[trait, trait]
    same_state_trait <- outer(state, state, FUN = "==") &
      outer(trait, trait, FUN = "==")
    covariance[same_state_trait] <- covariance[same_state_trait] +
      exp(2 * par$theta_temporal_diag)[trait[row(covariance)[same_state_trait]]]
  }
  if (ordinary) {
    trait_diagonal <- function(variance) {
      outer(trait, trait, function(i, j) ifelse(i == j, variance[i], 0))
    }
    site <- td$site_id + 1L
    unit_obs <- td$site_species_id + 1L
    if (isTRUE(fit$use$diag_B)) {
      covariance <- covariance + outer(site, site, FUN = "==") *
        trait_diagonal(exp(2 * par$theta_diag_B))
    }
    if (isTRUE(fit$use$diag_W)) {
      covariance <- covariance + outer(unit_obs, unit_obs, FUN = "==") *
        trait_diagonal(exp(2 * par$theta_diag_W))
    }
  }
  diag(covariance) <- diag(covariance) + exp(2 * par$log_sigma_eps[1L])
  covariance
}

.temporal_sixth_dense_nll <- function(fit, fixed, iid_psi = FALSE,
                                      ordinary = FALSE) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  covariance <- .temporal_sixth_dense_covariance(fit, fixed, iid_psi = iid_psi,
    ordinary = ordinary)
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(covariance)
  0.5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_sixth_set_oracle_parameters <- function(fit, structure, value) {
  fixed <- fit$opt$par
  fixed[names(fixed) == "theta_temporal_time"] <- if (identical(structure, "ar1")) {
    atanh(value / (1 - 1e-6))
  } else {
    log(value)
  }
  fixed[names(fixed) == "theta_temporal_rr"] <- seq_along(fixed[names(fixed) == "theta_temporal_rr"]) / 5
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(0.45, 0.55, 0.65))
  fixed[names(fixed) == "log_sigma_eps"] <- log(0.35)
  fixed
}

## The old pre-release implementation is still compiled behind the inert
## `use_temporal_B` data flag.  This fixture turns that branch on directly for
## its genuine common submodel: rank-one AR1 scores at consecutive occasions,
## no Psi, and no ordinary B/W covariance.  It is deliberately not a wrapper
## around the active temporal extractor or simulator.
.temporal_sixth_legacy_common_fixture <- function(fit) {
  data <- fit$tmb_data
  pair <- fit$temporal$pair_table
  stopifnot(
    identical(fit$temporal$mode, "latent"),
    !isTRUE(fit$temporal$unique),
    identical(fit$temporal$structure, "ar1"),
    fit$temporal$d == 1L,
    all(unlist(tapply(pair$time, pair$series, function(x) diff(sort(x)))) == 1)
  )
  ## The legacy B-tier indexed scores by a substituted site.  Recreate that
  ## private payload without changing the active fit's public data or labels.
  data$use_temporal <- 0L
  data$use_temporal_B <- 1L
  ## This is the no-IID-Psi branch of the retired code path.  The old
  ## replicated-IID correction is intentionally bypassed here because the
  ## common submodel has no Psi at all.
  data$temporal_iid_total <- 1L
  data$n_sites <- data$n_temporal_states
  data$n_site_species <- data$n_temporal_states
  data$site_id <- data$temporal_state_id
  data$site_species_id <- data$temporal_state_id
  data$use_rr_B <- 1L
  data$d_B <- 1L
  data$use_lv_B <- 0L
  data$temporal_series_id <- as.integer(factor(pair$series)) - 1L
  data$temporal_time_index <- as.integer(ave(
    pair$time, data$temporal_series_id,
    FUN = function(x) match(x, sort(x)) - 1L
  ))
  data$n_temporal_series <- length(unique(data$temporal_series_id))

  ## `tmb_params` retains the complete, shape-correct list supplied to TMB.
  ## `last.par.best` is a flattened Laplace vector and cannot safely be used
  ## as a parameter-list template after the legacy fixture changes n_sites.
  parameters <- fit$tmb_params
  parameters$theta_rr_B <- parameters$theta_temporal_rr
  parameters$z_B <- parameters$z_temporal
  parameters$theta_temporal_phi <- parameters$theta_temporal_time
  ## Build this map from the legacy fixture itself.  Reusing the active fit's
  ## map would retain factor maps sized for its two stable units after this
  ## fixture has expanded the retired B tier to six temporal states.
  map <- lapply(parameters, function(x) factor(rep(NA_integer_, length(x))))
  map$b_fix <- NULL
  map$log_sigma_eps <- NULL
  map$theta_rr_B <- NULL
  map$theta_temporal_phi <- NULL
  map$z_B <- NULL
  legacy <- TMB::MakeADFun(
    data = data, parameters = parameters, random = "z_B", map = map,
    DLL = fit$tmb_obj$env$DLL, silent = TRUE
  )
  list(object = legacy, data = data)
}

.temporal_sixth_set_legacy_common_parameters <- function(legacy, active, fixed) {
  active_par <- active$tmb_obj$env$parList(fixed)
  out <- legacy$par
  out[names(out) == "b_fix"] <- active_par$b_fix
  out[names(out) == "log_sigma_eps"] <- active_par$log_sigma_eps
  out[names(out) == "theta_rr_B"] <- active_par$theta_temporal_rr
  out[names(out) == "theta_temporal_phi"] <- active_par$theta_temporal_time
  out
}

.temporal_sixth_common_response <- function(loading, state, trait, predecessor,
                                             innovation, residual, phi) {
  score <- numeric(length(predecessor))
  for (i in seq_along(score)) {
    score[i] <- if (predecessor[i] < 0L) innovation[i] else {
      phi * score[predecessor[i] + 1L] + sqrt(1 - phi^2) * innovation[i]
    }
  }
  drop(loading[trait, 1L] * score[state] + residual)
}

test_that("all temporal cells match an independently constructed dense Gaussian NLL and gradient", {
  dat <- .temporal_sixth_oracle_data()
  specs <- list(
    list(mode = "indep", structure = "ar1", term = quote(temporal_indep(0 + trait | series, time = occasion))),
    list(mode = "dep", structure = "ar1", term = quote(temporal_dep(0 + trait | series, time = occasion))),
    list(mode = "latent", structure = "ar1", term = quote(temporal_latent(0 + trait | series, time = occasion, unique = FALSE))),
    list(mode = "latent", structure = "ar1", term = quote(temporal_latent(0 + trait | series, time = occasion, unique = TRUE))),
    list(mode = "indep", structure = "ou", term = quote(temporal_indep(0 + trait | series, time = elapsed, structure = "ou"))),
    list(mode = "dep", structure = "ou", term = quote(temporal_dep(0 + trait | series, time = elapsed, structure = "ou"))),
    list(mode = "latent", structure = "ou", term = quote(temporal_latent(0 + trait | series, time = elapsed, unique = FALSE, structure = "ou"))),
    list(mode = "latent", structure = "ou", term = quote(temporal_latent(0 + trait | series, time = elapsed, unique = TRUE, structure = "ou")))
  )
  for (spec in specs) {
    form <- as.formula(call("~", quote(value), call("+", quote(0 + trait), spec$term)))
    fit <- suppressWarnings(gllvmTMB(form, data = dat, unit = "series",
      family = gaussian(), silent = TRUE))
    values <- if (identical(spec$structure, "ar1")) c(-0.7, 0, 0.65) else 0.7
    for (value in values) {
      fixed <- .temporal_sixth_set_oracle_parameters(fit, spec$structure, value)
      native <- as.numeric(fit$tmb_obj$fn(fixed))
      dense <- .temporal_sixth_dense_nll(fit, fixed)
      expect_equal(native, dense, tolerance = 2e-6,
        info = paste(spec$mode, spec$structure, value, "dense NLL"))

      time_index <- match("theta_temporal_time", names(fixed))
      h <- 1e-5
      plus <- fixed; plus[time_index] <- plus[time_index] + h
      minus <- fixed; minus[time_index] <- minus[time_index] - h
      dense_central <- (.temporal_sixth_dense_nll(fit, plus) -
        .temporal_sixth_dense_nll(fit, minus)) / (2 * h)
      expect_equal(fit$tmb_obj$gr(fixed)[time_index], dense_central, tolerance = 2e-5,
        info = paste(spec$mode, spec$structure, value, "dense time gradient"))
    }
  }
})

test_that("the retained B-tier AR1 code matches the no-Psi common submodel", {
  ## Consecutive occasions are intentional: the retired B-tier branch did not
  ## preserve integer gaps, so this is its maximal legitimate common submodel.
  dat <- .temporal_sixth_oracle_data()
  dat$occasion <- c(1L, 2L, 3L)[match(dat$occasion, c(1L, 3L, 7L))]
  active <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion,
      d = 1, unique = FALSE),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  legacy_fixture <- .temporal_sixth_legacy_common_fixture(active)
  legacy <- legacy_fixture$object
  fixed <- .temporal_sixth_set_oracle_parameters(active, "ar1", 0.45)
  fixed[names(fixed) == "b_fix"] <- c(0.1, 0.2, 0.3)
  legacy_fixed <- .temporal_sixth_set_legacy_common_parameters(legacy, active, fixed)

  expect_equal(legacy$fn(legacy_fixed), active$tmb_obj$fn(fixed), tolerance = 2e-6)
  active_gradient <- active$tmb_obj$gr(fixed)
  legacy_gradient <- legacy$gr(legacy_fixed)
  for (name in c("b_fix", "log_sigma_eps", "theta_temporal_phi", "theta_rr_B")) {
    active_name <- switch(name,
      theta_temporal_phi = "theta_temporal_time",
      theta_rr_B = "theta_temporal_rr",
      name
    )
    expect_equal(
      legacy_gradient[names(legacy_gradient) == name],
      active_gradient[names(active_gradient) == active_name],
      tolerance = 2e-5, info = paste("common-submodel gradient", name)
    )
  }

  ## A fixed-parameter draw uses the same innovation and observation draws in
  ## the two representations.  This tests the actual linear predictor rather
  ## than calling the production temporal simulation helper.
  active_parameters <- active$tmb_obj$env$parList(fixed)
  legacy_parameters <- legacy$env$parList()
  phi <- (1 - 1e-6) * tanh(active_parameters$theta_temporal_time)
  innovations <- seq(-0.4, 0.6, length.out = active$tmb_data$n_temporal_states)
  residual <- seq(-0.2, 0.2, length.out = length(active$tmb_data$y))
  active_response <- .temporal_sixth_common_response(
    .temporal_sixth_unpack_loading(active_parameters$theta_temporal_rr, 3L, 1L),
    active$tmb_data$temporal_state_id + 1L, active$tmb_data$trait_id + 1L,
    active$tmb_data$temporal_predecessor, innovations, residual, phi
  )
  legacy_response <- .temporal_sixth_common_response(
    .temporal_sixth_unpack_loading(legacy_parameters$theta_rr_B, 3L, 1L),
    legacy_fixture$data$site_id + 1L, legacy_fixture$data$trait_id + 1L,
    c(-1L, 0L, 1L, -1L, 3L, 4L), innovations, residual, phi
  )
  expect_equal(legacy_response, active_response, tolerance = 1e-12)

  ## The native reports are the historical extractor surfaces.  The public
  ## temporal extractor must agree with the retained B-tier loading report.
  legacy_opt <- .temporal_sixth_set_legacy_common_parameters(
    legacy, active, active$opt$par
  )
  legacy$fn(legacy_opt)
  expect_equal(
    unname(extract_temporal(active)$loadings),
    unname(legacy$report()$Lambda_B),
    tolerance = 2e-6
  )
  active_scores <- extract_ordination(active, level = "unit")$scores
  legacy_scores <- t(legacy$env$parList()$z_B)
  expect_equal(unname(active_scores), unname(legacy_scores), tolerance = 2e-5)
})

test_that("dense oracle includes temporal plus ordinary unit and unit_obs covariance", {
  dat <- .temporal_sixth_oracle_data()
  dat$unit_obs <- paste(dat$series, dat$occasion)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion) +
      indep(0 + trait | series) + indep(0 + trait | unit_obs),
    data = dat, unit = "series", unit_obs = "unit_obs", family = gaussian(),
    silent = TRUE
  ))
  fixed <- .temporal_sixth_set_oracle_parameters(fit, "ar1", 0.65)
  fixed[names(fixed) == "theta_diag_B"] <- log(c(0.25, 0.35, 0.45))
  fixed[names(fixed) == "theta_diag_W"] <- log(c(0.15, 0.20, 0.30))
  native <- as.numeric(fit$tmb_obj$fn(fixed))
  dense <- .temporal_sixth_dense_nll(fit, fixed, ordinary = TRUE)
  expect_equal(native, dense, tolerance = 2e-6)
  time_index <- match("theta_temporal_time", names(fixed))
  h <- 1e-5
  plus <- fixed; plus[time_index] <- plus[time_index] + h
  minus <- fixed; minus[time_index] <- minus[time_index] - h
  dense_central <- (.temporal_sixth_dense_nll(fit, plus, ordinary = TRUE) -
    .temporal_sixth_dense_nll(fit, minus, ordinary = TRUE)) / (2 * h)
  expect_equal(fit$tmb_obj$gr(fixed)[time_index], dense_central, tolerance = 2e-5)
})

test_that("negative AR1 persistence changes sign at an odd lag", {
  dat <- .temporal_sixth_oracle_data()
  dat$occasion <- c(1L, 3L, 8L)[match(dat$occasion, c(1L, 3L, 7L))]
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  fixed <- .temporal_sixth_set_oracle_parameters(fit, "ar1", -0.7)
  covariance <- .temporal_sixth_dense_covariance(fit, fixed)
  state <- fit$tmb_data$temporal_state_id + 1L
  trait <- fit$tmb_data$trait_id + 1L
  first <- which(state == 1L & trait == 1L)
  odd_lag <- which(state == 3L & trait == 1L)
  expect_equal(fit$temporal$pair_table$time[[3L]] - fit$temporal$pair_table$time[[1L]], 7)
  expect_lt(covariance[first, odd_lag], 0)
})

test_that("OU extreme time parameters retain finite objective and gradient", {
  dat <- .temporal_sixth_oracle_data()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = elapsed,
      structure = "ou"), data = dat, unit = "series", family = gaussian(),
    silent = TRUE
  ))
  fixed <- .temporal_sixth_set_oracle_parameters(fit, "ou", 0.7)
  for (theta in c(-45, 45)) {
    extreme <- fixed
    extreme[names(extreme) == "theta_temporal_time"] <- theta
    expect_true(is.finite(fit$tmb_obj$fn(extreme)))
    expect_true(all(is.finite(fit$tmb_obj$gr(extreme))))
  }
})

test_that("temporal latent unique keeps Psi correlated across occasions", {
  dat <- .temporal_sixth_oracle_data()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion,
      unique = TRUE),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  fixed <- .temporal_sixth_set_oracle_parameters(fit, "ar1", 0.65)
  covariance <- .temporal_sixth_dense_covariance(fit, fixed)
  iid_covariance <- .temporal_sixth_dense_covariance(fit, fixed, iid_psi = TRUE)
  state <- fit$tmb_data$temporal_state_id + 1L
  trait <- fit$tmb_data$trait_id + 1L
  pair <- fit$temporal$pair_table
  target <- which(state == 1L & trait == 1L)
  later <- which(state == 2L & trait == 1L)
  expect_length(target, 1L)
  expect_length(later, 1L)
  expect_gt(abs(covariance[target, later] - iid_covariance[target, later]), 1e-4)
  expect_gt(abs(.temporal_sixth_dense_nll(fit, fixed) -
    .temporal_sixth_dense_nll(fit, fixed, iid_psi = TRUE)), 1e-4)
})
