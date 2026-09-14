.temporal_latent_spatial_fixture <- function() {
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

.temporal_latent_spatial_fit <- function(fx) suppressWarnings(gllvmTMB(
  value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
      d = 1, unique = FALSE) + spatial_indep(0 + trait | coords, mesh = fx$mesh),
  data = fx$data, unit = "series", family = gaussian(), silent = TRUE,
  control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
    optimizer_passes = 2L)
))

.temporal_latent_spatial_dense_nll <- function(fit, fixed, product = FALSE) {
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
  Sigma_time <- tcrossprod(as.numeric(par$theta_temporal_rr))
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

test_that("rank-one temporal latent plus fixed spatial indep is admitted", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_latent_spatial_fixture(); fit <- .temporal_latent_spatial_fit(fx)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$temporal$mode, "latent")
  expect_false(isTRUE(fit$temporal$unique))
  expect_true(all(c("z_temporal", "omega_spde") %in% fit$random))
  rebuilt <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(fit$data[, fit$mesh$xy_cols, drop = FALSE])))
  expect_equal(rebuilt, as.matrix(fit$tmb_data$A_proj), tolerance = 1e-12)
})

test_that("rank-one temporal-spatial likelihood and active gradient equal the dense oracle", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_latent_spatial_fixture(); fit <- .temporal_latent_spatial_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_rr"] <- c(.25, .4, .6)
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
    Sigma_time <- tcrossprod(as.numeric(par$theta_temporal_rr))
    Sigma_space <- diag(exp(-2 * par$log_tau_spde), td$n_traits)
    oracle <- .temporal_latent_spatial_dense_nll(fit, fixed)
    expect_equal(as.numeric(fit$tmb_obj$fn(fixed)), oracle, tolerance = 2e-6)
    product <- .temporal_latent_spatial_dense_nll(fit, fixed, product = TRUE)
    cross_series <- which(td$site_id != td$site_id[[1L]] & td$trait_id != td$trait_id[[1L]] &
      pair$time[state] == pair$time[[state[[1L]]]])[[1L]]
    expect_equal(Ktime[state[[1L]], state[[cross_series]]] * Sigma_time[trait[[1L]], trait[[cross_series]]] +
      Kspace[1L, cross_series] * Sigma_space[trait[[1L]], trait[[cross_series]]], 0, tolerance = 1e-12)
    expect_gt(abs(R_all[state[[1L]], state[[cross_series]]] * Kspace[1L, cross_series] *
      Sigma_time[trait[[1L]], trait[[cross_series]]]), 1e-8)
    expect_gt(abs(oracle - product), 1e-3)
    for (i in seq_along(fixed)) {
      h <- 1e-5; plus <- fixed; minus <- fixed; plus[[i]] <- plus[[i]] + h; minus[[i]] <- minus[[i]] - h
      central <- (.temporal_latent_spatial_dense_nll(fit, plus) - .temporal_latent_spatial_dense_nll(fit, minus)) / (2 * h)
      expect_equal(fit$tmb_obj$gr(fixed)[[i]], central, tolerance = 3e-5,
        info = paste(names(fixed)[[i]], "phi", phi))
    }
  }
})

test_that("rank-one temporal-spatial simulation redraws both independent fields", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_latent_spatial_fixture(); fit <- .temporal_latent_spatial_fit(fx)
  draw <- simulate(fit, nsim = 1000L, seed = 2609261L)
  expect_equal(dim(draw), c(nrow(fx$data), 1000L))
  td <- fit$tmb_data; pair <- fit$temporal$pair_table; state <- td$temporal_state_id + 1L
  trait_one <- which(td$trait_id == 0L); i <- trait_one[[1L]]
  same_series_later <- trait_one[td$site_id[trait_one] == td$site_id[[i]] & state[trait_one] != state[[i]]][[1L]]
  other_series <- trait_one[td$site_id[trait_one] != td$site_id[[i]]][[1L]]
  cross_trait <- which(td$site_id == td$site_id[[i]] & state == state[[i]] & td$trait_id == 1L)[[1L]]
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Ktime <- phi^abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  P <- as.matrix(fmesher::fm_basis(fit$mesh$mesh,
    loc = as.matrix(fit$data[, fit$mesh$xy_cols, drop = FALSE])))
  kappa <- exp(par$log_kappa_spde)
  Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) + as.matrix(td$spde_M2)
  Kspace <- P %*% solve(Q) %*% t(P)
  lambda <- as.numeric(par$theta_temporal_rr)
  tau <- exp(-par$log_tau_spde)
  eps <- exp(par$log_sigma_eps[[1L]])
  expected_covariance <- function(a, b) {
    temporal <- Ktime[state[[a]], state[[b]]] * lambda[[td$trait_id[[a]] + 1L]] * lambda[[td$trait_id[[b]] + 1L]]
    spatial <- if (td$trait_id[[a]] == td$trait_id[[b]]) Kspace[a, b] * tau[[td$trait_id[[a]] + 1L]]^2 else 0
    temporal + spatial
  }
  expected_variance <- function(a) expected_covariance(a, a) + eps^2
  for (j in c(same_series_later, other_series, cross_trait)) {
    expected <- expected_covariance(i, j)
    mcse <- sqrt((expected_variance(i) * expected_variance(j) + expected^2) / (ncol(draw) - 1L))
    expect_lte(abs(stats::cov(draw[i, ], draw[j, ]) - expected), 5 * mcse)
  }
  expected_mean <- drop(td$X_fix %*% par$b_fix)
  for (a in c(i, same_series_later, other_series, cross_trait))
    expect_lte(abs(mean(draw[a, ]) - expected_mean[[a]]), 5 * sqrt(expected_variance(a) / ncol(draw)))
  expect_equal(dim(simulate(fit, nsim = 2L, seed = 11L, condition_on_RE = TRUE)), c(nrow(fx$data), 2L))
})


test_that("rank-one temporal-spatial pairing refuses unqualified variants", {
  skip_if_not_installed("fmesher")
  fx <- .temporal_latent_spatial_fixture()
  base <- value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion,
    replicate = measurement, d = 1, unique = FALSE) + spatial_indep(0 + trait | coords, mesh = fx$mesh)
  expect_error(suppressWarnings(gllvmTMB(update(base, . ~ . - temporal_latent(0 + trait | series, time = occasion, replicate = measurement, d = 1, unique = FALSE) + temporal_latent(0 + trait | series, time = occasion, replicate = measurement, d = 1, unique = TRUE)), data = fx$data, unit = "series", family = gaussian(), silent = TRUE)), "cannot be combined")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion, replicate = measurement, d = 1, unique = FALSE, structure = "ou") + spatial_indep(0 + trait | coords, mesh = fx$mesh), data = fx$data, unit = "series", family = gaussian(), silent = TRUE)), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion, replicate = measurement, d = 1, unique = FALSE) + spatial_indep(0 + trait | coords, mesh = fx$mesh) + indep(0 + trait | series), data = fx$data, unit = "series", family = gaussian(), silent = TRUE)), "cannot include an ordinary covariance term")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion, replicate = measurement, d = 1, unique = FALSE) + spatial_indep(0 + trait + (0 + trait):occasion | coords, mesh = fx$mesh), data = fx$data, unit = "series", family = gaussian(), silent = TRUE)), "requires an intercept-only")
  mismatched <- fx$data
  mismatched$lon[mismatched$series == "s1" & mismatched$occasion == 1L &
    mismatched$trait == "t2"] <- .37
  expect_error(suppressWarnings(gllvmTMB(base, data = mismatched, unit = "series",
    family = gaussian(), silent = TRUE)), "one shared spatial coordinate pair")
  even <- fx$data; even$occasion <- 2L * even$occasion
  expect_error(suppressWarnings(gllvmTMB(base, data = even, unit = "series", family = gaussian(), silent = TRUE)), "requires an odd within-series time lag")
})

test_that("rank-one temporal-spatial long and wide calls preserve state labels and replay", {
  skip_if_not_installed("TMB"); skip_if_not_installed("fmesher")
  fx <- .temporal_latent_spatial_fixture(); long_fit <- .temporal_latent_spatial_fit(fx)
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
      temporal_latent(1 | series, time = occasion, replicate = measurement,
        d = 1, unique = FALSE) + spatial_indep(1 | coords, mesh = fx$mesh),
    data = wide, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_s3_class(wide_fit, "gllvmTMB_multi")
  wide_projection <- as.matrix(fmesher::fm_basis(wide_fit$mesh$mesh,
    loc = as.matrix(wide_fit$data[, wide_fit$mesh$xy_cols, drop = FALSE])))
  expect_equal(as.matrix(wide_fit$tmb_data$A_proj), wide_projection, tolerance = 1e-12)
  wide_fixed <- wide_fit$opt$par
  expect_equal(as.numeric(wide_fit$tmb_obj$fn(wide_fixed)),
    .temporal_latent_spatial_dense_nll(wide_fit, wide_fixed), tolerance = 2e-6)
  expect_equal(unname(as.matrix(extract_temporal(wide_fit)$pair_index)),
    unname(as.matrix(extract_temporal(long_fit)$pair_index)))
  expect_identical(rownames(getLV(wide_fit)), extract_temporal(wide_fit)$pair_index$pair_id)
  expect_s3_class(suppressWarnings(update(wide_fit)), "gllvmTMB_multi")
})
