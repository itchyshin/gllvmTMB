.temporal_dep_spatial_fixture <- function() {
  key <- expand.grid(series = paste0("s", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  loc <- expand.grid(series = paste0("s", 1:4), occasion = 1:4,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  loc$lon <- c(0, 1, 0, 1, .2, .8, .3, .7, .1, .9, .4, .6, .25, .75, .45, .55)
  loc$lat <- c(0, 0, 1, 1, .8, .2, .7, .3, .4, .6, .9, .1, .25, .75, .55, .45)
  key <- merge(key, loc, by = c("series", "occasion"), sort = FALSE)
  data <- key[rep(seq_len(nrow(key)), each = 3L), , drop = FALSE]
  data$trait <- rep(paste0("t", 1:3), nrow(key))
  data$value <- with(data, as.numeric(factor(trait)) + .1 * occasion +
    c(s1 = -.2, s2 = .15, s3 = .05, s4 = .3)[series] +
    c(m1 = -.03, m2 = .03)[measurement])
  list(data = data, mesh = make_mesh(data, c("lon", "lat"), cutoff = .05))
}

.temporal_dep_spatial_fit <- function(fx) suppressWarnings(gllvmTMB(
  value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      spatial_indep(0 + trait | coords, mesh = fx$mesh),
  data = fx$data, unit = "series", family = gaussian(), silent = TRUE,
  control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
    optimizer_passes = 2L)
))

.temporal_dep_spatial_unpack <- function(theta, n_trait) {
  out <- matrix(0, n_trait, n_trait); cursor <- 1L
  for (column in seq_len(n_trait)) {
    out[column, column] <- theta[[cursor]]; cursor <- cursor + 1L
  }
  for (column in seq_len(n_trait - 1L)) for (row in (column + 1L):n_trait) {
    out[row, column] <- theta[[cursor]]; cursor <- cursor + 1L
  }
  stopifnot(cursor == length(theta) + 1L); out
}

.temporal_dep_spatial_dense_nll <- function(fit, fixed, product = FALSE) {
  par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data
  pair <- fit$temporal$pair_table
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Ktime <- phi^abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  R_all <- phi^abs(outer(pair$time, pair$time, `-`))
  kappa <- exp(par$log_kappa_spde)
  Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) + as.matrix(td$spde_M2)
  ## Rebuild the projection from the stored mesh and the public coordinates.
  ## This must agree with the engine projection but is not copied from it.
  P <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(fit$data[, fit$mesh$xy_cols, drop = FALSE])))
  Kspace <- P %*% solve(Q) %*% t(P)
  state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L
  Sigma_time <- tcrossprod(.temporal_dep_spatial_unpack(par$theta_temporal_rr, td$n_traits))
  Sigma_space <- diag(exp(-2 * par$log_tau_spde), td$n_traits)
  V <- if (product) {
    ## Deliberately wrong evolving space-time interaction. It retains spatial
    ## covariance across every series instead of adding one static spatial field.
    R_all[state, state] * Kspace * Sigma_time[trait, trait]
  } else Ktime[state, state] * Sigma_time[trait, trait] + Kspace * Sigma_space[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix); L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_dep_spatial_forecast_covariance <- function(fit, left, right = left) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  traits <- levels(fit$data[[fit$trait_col]])
  left_trait <- match(as.character(left[[fit$trait_col]]), traits)
  right_trait <- match(as.character(right[[fit$trait_col]]), traits)
  left_series <- as.character(left[[fit$temporal$series_col]])
  right_series <- as.character(right[[fit$temporal$series_col]])
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal <- outer(left_series, right_series, "==") *
    phi^abs(outer(as.numeric(left[[fit$temporal$time_col]]),
      as.numeric(right[[fit$temporal$time_col]]), "-"))
  loading <- .temporal_dep_spatial_unpack(par$theta_temporal_rr, length(traits))
  P_left <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(left[, fit$mesh$xy_cols, drop = FALSE])))
  P_right <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(right[, fit$mesh$xy_cols, drop = FALSE])))
  ## Rebuild the finite-element matrices from the mesh rather than borrowing
  ## the production TMB data block.
  fem <- fmesher::fm_fem(fit$mesh$mesh, order = 2)
  kappa <- exp(par$log_kappa_spde)
  Q <- kappa^4 * as.matrix(fem$c0) + 2 * kappa^2 * as.matrix(fem$g1) + as.matrix(fem$g2)
  spatial <- P_left %*% solve(Q) %*% t(P_right)
  out <- temporal * tcrossprod(loading)[left_trait, right_trait] +
    spatial * diag(exp(-2 * par$log_tau_spde), nrow = length(traits))[left_trait, right_trait]
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

test_that("rank-full temporal dependent plus fixed spatial indep is admitted", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_dep_spatial_fixture(); fit <- .temporal_dep_spatial_fit(fx)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$temporal$mode, "dep")
  expect_identical(fit$temporal$d, 0L)
  expect_true(all(c("z_temporal", "omega_spde") %in% fit$random))
  rebuilt <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(fit$data[, fit$mesh$xy_cols, drop = FALSE])))
  expect_equal(rebuilt, as.matrix(fit$tmb_data$A_proj), tolerance = 1e-12)
})

test_that("temporal-dependent-spatial likelihood and active gradient equal the dense oracle", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_dep_spatial_fixture(); fit <- .temporal_dep_spatial_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_rr"] <- c(.55, .45, .50, .08, -.12, .10)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)
  fixed[names(fixed) == "log_tau_spde"] <- log(c(1.1, .9, 1.2))
  fixed[names(fixed) == "log_kappa_spde"] <- log(2)
  for (phi in c(-.55, 0, .55)) {
    fixed[names(fixed) == "theta_temporal_time"] <- atanh(phi / (1 - 1e-6))
    par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data; pair <- fit$temporal$pair_table
    state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L
    phi_actual <- (1 - 1e-6) * tanh(par$theta_temporal_time)
    Ktime <- phi_actual^abs(outer(pair$time, pair$time, `-`))
    Ktime[outer(pair$series, pair$series, `!=`)] <- 0
    R_all <- phi_actual^abs(outer(pair$time, pair$time, `-`))
    P <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
      loc = as.matrix(fit$data[, fit$mesh$xy_cols, drop = FALSE])))
    kappa <- exp(par$log_kappa_spde)
    Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) + as.matrix(td$spde_M2)
    Kspace <- P %*% solve(Q) %*% t(P)
    Sigma_time <- tcrossprod(.temporal_dep_spatial_unpack(par$theta_temporal_rr, td$n_traits))
    Sigma_space <- diag(exp(-2 * par$log_tau_spde), td$n_traits)
    oracle <- .temporal_dep_spatial_dense_nll(fit, fixed)
    expect_equal(as.numeric(fit$tmb_obj$fn(fixed)), oracle, tolerance = 2e-6)
    product <- .temporal_dep_spatial_dense_nll(fit, fixed, product = TRUE)
    cross_series <- which(td$site_id != td$site_id[[1L]] & td$trait_id != td$trait_id[[1L]] &
      pair$time[state] == pair$time[[state[[1L]]]])[[1L]]
    expect_equal(Ktime[state[[1L]], state[[cross_series]]] * Sigma_time[trait[[1L]], trait[[cross_series]]] +
      Kspace[1L, cross_series] * Sigma_space[trait[[1L]], trait[[cross_series]]], 0, tolerance = 1e-12)
    expect_gt(abs(R_all[state[[1L]], state[[cross_series]]] * Kspace[1L, cross_series] *
      Sigma_time[trait[[1L]], trait[[cross_series]]]), 1e-8)
    expect_gt(abs(oracle - product), 1e-3)
    for (i in seq_along(fixed)) {
      h <- 1e-5; plus <- fixed; minus <- fixed; plus[[i]] <- plus[[i]] + h; minus[[i]] <- minus[[i]] - h
      central <- (.temporal_dep_spatial_dense_nll(fit, plus) - .temporal_dep_spatial_dense_nll(fit, minus)) / (2 * h)
      expect_equal(fit$tmb_obj$gr(fixed)[[i]], central, tolerance = 3e-5,
        info = paste(names(fixed)[[i]], "phi", phi))
    }
  }
})

test_that("temporal-dependent-spatial simulation redraws both independent fields", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_dep_spatial_fixture(); fit <- .temporal_dep_spatial_fit(fx)
  draw <- simulate(fit, nsim = 1000L, seed = 2609261L)
  expect_equal(dim(draw), c(nrow(fx$data), 1000L))
  td <- fit$tmb_data; pair <- fit$temporal$pair_table; state <- td$temporal_state_id + 1L
  trait_one <- which(td$trait_id == 0L); i <- trait_one[[1L]]
  same_series_later <- trait_one[td$site_id[trait_one] == td$site_id[[i]] & state[trait_one] != state[[i]]][[1L]]
  other_series <- trait_one[td$site_id[trait_one] != td$site_id[[i]]][[1L]]
  cross_trait <- which(td$site_id == td$site_id[[i]] & state == state[[i]] & td$trait_id == 1L)[[1L]]
  cross_trait_lag <- which(td$site_id == td$site_id[[i]] & state != state[[i]] &
    td$trait_id == 1L)[[1L]]
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Ktime <- phi^abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  P <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(fit$data[, fit$mesh$xy_cols, drop = FALSE])))
  kappa <- exp(par$log_kappa_spde)
  Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) + as.matrix(td$spde_M2)
  Kspace <- P %*% solve(Q) %*% t(P)
  Sigma_time <- tcrossprod(.temporal_dep_spatial_unpack(par$theta_temporal_rr, td$n_traits))
  tau <- exp(-par$log_tau_spde)
  eps <- exp(par$log_sigma_eps[[1L]])
  expected_covariance <- function(a, b) {
    temporal <- Ktime[state[[a]], state[[b]]] *
      Sigma_time[td$trait_id[[a]] + 1L, td$trait_id[[b]] + 1L]
    spatial <- if (td$trait_id[[a]] == td$trait_id[[b]]) Kspace[a, b] * tau[[td$trait_id[[a]] + 1L]]^2 else 0
    temporal + spatial
  }
  expected_variance <- function(a) expected_covariance(a, a) + eps^2
  for (j in c(same_series_later, other_series, cross_trait, cross_trait_lag)) {
    expected <- expected_covariance(i, j)
    mcse <- sqrt((expected_variance(i) * expected_variance(j) + expected^2) / (ncol(draw) - 1L))
    expect_lte(abs(stats::cov(draw[i, ], draw[j, ]) - expected), 5 * mcse)
  }
  expected_mean <- drop(td$X_fix %*% par$b_fix)
  for (a in c(i, same_series_later, other_series, cross_trait, cross_trait_lag))
    expect_lte(abs(mean(draw[a, ]) - expected_mean[[a]]), 5 * sqrt(expected_variance(a) / ncol(draw)))
  conditional <- simulate(fit, nsim = 1000L, seed = 11L, condition_on_RE = TRUE)
  expect_equal(dim(conditional), c(nrow(fx$data), 1000L))
  expect_equal(rowMeans(conditional), as.numeric(fit$report$eta), tolerance = .04)
})


test_that("temporal-dependent-spatial pairing refuses unqualified variants", {
  skip_if_not_installed("fmesher")
  fx <- .temporal_dep_spatial_fixture()
  base <- value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
    replicate = measurement) + spatial_indep(0 + trait | coords, mesh = fx$mesh)
  expect_error(suppressWarnings(gllvmTMB(update(base, . ~ . + temporal_latent(0 + trait | series,
    time = occasion, replicate = measurement, d = 1, unique = TRUE)), data = fx$data,
    unit = "series", family = gaussian(), silent = TRUE)), "Only one temporal")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion, replicate = measurement, structure = "ou") + spatial_indep(0 + trait | coords, mesh = fx$mesh), data = fx$data, unit = "series", family = gaussian(), silent = TRUE)), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion, replicate = measurement) + spatial_indep(0 + trait | coords, mesh = fx$mesh) + indep(0 + trait | series), data = fx$data, unit = "series", family = gaussian(), silent = TRUE)), "cannot include an ordinary covariance term")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion, replicate = measurement) + spatial_indep(0 + trait + (0 + trait):occasion | coords, mesh = fx$mesh), data = fx$data, unit = "series", family = gaussian(), silent = TRUE)), "requires an intercept-only")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | series,
    time = occasion, replicate = measurement) + spatial_dep(0 + trait | coords, mesh = fx$mesh),
    data = fx$data, unit = "series", family = gaussian(), silent = TRUE)), "current temporal provider")
  mismatched <- fx$data
  mismatched$lon[mismatched$series == "s1" & mismatched$occasion == 1L &
    mismatched$trait == "t2"] <- .37
  expect_error(suppressWarnings(gllvmTMB(base, data = mismatched, unit = "series",
    family = gaussian(), silent = TRUE)), "one shared spatial coordinate pair")
  even <- fx$data; even$occasion <- 2L * even$occasion
  expect_error(suppressWarnings(gllvmTMB(base, data = even, unit = "series", family = gaussian(), silent = TRUE)), "requires an odd within-series time lag")
})

test_that("temporal-dependent-spatial long and wide calls preserve state labels and replay", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_dep_spatial_fixture(); long_fit <- .temporal_dep_spatial_fit(fx)
  wide <- unique(fx$data[c("series", "occasion", "measurement", "lon", "lat")])
  wide <- wide[order(wide$series, wide$occasion, wide$measurement), , drop = FALSE]
  for (j in 1:3) {
    sub <- fx$data[fx$data$trait == paste0("t", j), c("series", "occasion", "measurement", "value")]
    sub <- sub[order(sub$series, sub$occasion, sub$measurement), , drop = FALSE]
    wide[[paste0("y", j)]] <- sub$value
  }
  ## Reusing the mesh from an unsorted long fixture is safe because fitting
  ## rebuilds its projection on the actual expanded wide rows.
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_dep(1 | series, time = occasion, replicate = measurement) +
      spatial_indep(1 | coords, mesh = fx$mesh),
    data = wide, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_s3_class(wide_fit, "gllvmTMB_multi")
  wide_projection <- as.matrix(fmesher::fm_basis(wide_fit$mesh$mesh,
    loc = as.matrix(wide_fit$data[, wide_fit$mesh$xy_cols, drop = FALSE])))
  expect_equal(as.matrix(wide_fit$tmb_data$A_proj), wide_projection, tolerance = 1e-12)
  wide_fixed <- wide_fit$opt$par
  expect_identical(names(wide_fixed), names(long_fit$opt$par))
  expect_equal(wide_fit$tmb_obj$fn(long_fit$opt$par),
    long_fit$tmb_obj$fn(long_fit$opt$par), tolerance = 2e-6)
  expect_equal(as.numeric(wide_fit$tmb_obj$fn(wide_fixed)),
    .temporal_dep_spatial_dense_nll(wide_fit, wide_fixed), tolerance = 2e-6)
  expect_equal(unname(as.matrix(extract_temporal(wide_fit)$pair_index)),
    unname(as.matrix(extract_temporal(long_fit)$pair_index)))
  expect_identical(rownames(extract_temporal(wide_fit)$loading), c("y1", "y2", "y3"))
  replay <- suppressWarnings(update(wide_fit))
  expect_s3_class(replay, "gllvmTMB_multi")
  expect_equal(extract_temporal(replay)$pair_index, extract_temporal(wide_fit)$pair_index)
  shuffled <- fx; set.seed(260932L); shuffled$data <- shuffled$data[sample(nrow(shuffled$data)), ]
  shuffled_fit <- .temporal_dep_spatial_fit(shuffled)
  expect_identical(names(shuffled_fit$opt$par), names(long_fit$opt$par))
  expect_equal(shuffled_fit$tmb_obj$fn(long_fit$opt$par),
    long_fit$tmb_obj$fn(long_fit$opt$par), tolerance = 2e-6)
})

test_that("temporal-dependent-spatial lifecycle routes condition on the additive covariance", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_dep_spatial_fixture(); fit <- .temporal_dep_spatial_fit(fx)
  par <- fit$opt$par
  par[match("theta_temporal_time", names(par))] <- atanh(.45 / (1 - 1e-6))
  par[which(names(par) == "theta_temporal_rr")] <- c(.7, .6, .5, .1, -.08, .06)
  par[which(names(par) == "log_tau_spde")] <- log(c(1.1, .9, 1.2))
  fit$opt$par <- par
  future <- expand.grid(series = paste0("s", 1:4), occasion = 5L,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  location <- unique(fx$data[c("series", "lon", "lat")])
  location <- location[!duplicated(location$series), , drop = FALSE]
  location$occasion <- 5L
  future <- merge(future, location, by = c("series", "occasion"), sort = FALSE)
  observed <- forecast_temporal(fit, future, se.fit = TRUE)
  all_rows <- rbind(fx$data[, names(future)], future)
  V <- .temporal_dep_spatial_forecast_covariance(fit, all_rows)
  n_observed <- nrow(fx$data); obs <- seq_len(n_observed); future_i <- n_observed + seq_len(nrow(future))
  beta <- gllvmTMB:::.gllvmTMB_b_fix_values(fit)
  X_new <- stats::model.matrix(stats::delete.response(stats::terms(fit$formula)), future)
  solved <- solve(V[obs, obs], cbind(fx$data$value - drop(fit$tmb_data$X_fix %*% beta), V[obs, future_i]))
  expected <- drop(X_new %*% beta + t(V[obs, future_i]) %*% solved[, 1L])
  expected_se <- sqrt(pmax(diag(V[future_i, future_i] - t(V[obs, future_i]) %*% solved[, -1L, drop = FALSE]), 0))
  expect_equal(observed$est, unname(expected), tolerance = 1e-8)
  expect_equal(observed$se.fit, unname(expected_se), tolerance = 1e-8)
  product <- outer(as.character(all_rows$series), as.character(all_rows$series), "==") *
    ((1 - 1e-6) * tanh(fit$tmb_obj$env$parList(par)$theta_temporal_time))^
      abs(outer(all_rows$occasion, all_rows$occasion, "-")) * V
  expect_gt(max(abs(V - product)), 1e-3)
  fit$opt$par[match("theta_temporal_time", names(par))] <- atanh(-.45 / (1 - 1e-6))
  negative <- forecast_temporal(fit, future)
  negative_V <- .temporal_dep_spatial_forecast_covariance(fit, all_rows)
  negative_expected <- drop(X_new %*% beta + negative_V[future_i, obs] %*%
    solve(negative_V[obs, obs], fx$data$value - drop(fit$tmb_data$X_fix %*% beta)))
  expect_equal(negative$est, unname(negative_expected), tolerance = 1e-8)
  mismatch <- future
  mismatch$lon[mismatch$trait == "t2"] <- mismatch$lon[mismatch$trait == "t2"] + .1
  expect_error(forecast_temporal(fit, mismatch), "shared spatial coordinate")
  theta <- fit$opt$par[[match("theta_temporal_time", names(fit$opt$par))]]
  profile <- profile_temporal(fit, ystep = .1, ytol = 1,
    parm.range = theta + c(-.01, .01))
  expect_equal(profile[["estimate"]], (1 - 1e-6) * tanh(fit$tmb_obj$env$parList(fit$opt$par)$theta_temporal_time), tolerance = 1e-10)
  boot <- bootstrap_temporal(fit, n_boot = 1L, seed = 260974L)
  expect_true(is.finite(boot$objective[[1L]]), info = boot$error[[1L]])
})
