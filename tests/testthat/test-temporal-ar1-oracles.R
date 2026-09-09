.temporal_oracle_data <- function(replicated = FALSE) {
  pairs <- rbind(
    data.frame(series = "a", occasion = 1:3),
    data.frame(series = "b", occasion = 4:8)
  )
  if (replicated) {
    out <- merge(pairs, data.frame(measurement = 1:2), by = NULL)
  } else {
    out <- pairs
  }
  out <- merge(out, data.frame(trait = paste0("t", 1:3)), by = NULL)
  out$value <- with(out, 0.2 * as.integer(factor(trait)) +
    sin(occasion + as.integer(factor(series))) +
    if (replicated) 0.1 * measurement else 0) +
    seq_len(nrow(out)) / 100
  out
}

.temporal_dense_nll <- function(fit, fixed_par) {
  par_list <- fit$tmb_obj$env$parList(fixed_par)
  full_par <- fit$tmb_obj$env$last.par.best
  full_par[fit$tmb_obj$env$lfixed()] <- fixed_par
  report <- fit$tmb_obj$report(full_par)
  pair_table <- fit$temporal$pair_table[
    match(levels(fit$data[[fit$unit_col]]), fit$temporal$pair_table$pair_id),
    , drop = FALSE
  ]
  phi <- (1 - 1e-6) * tanh(par_list$theta_temporal_phi)
  C <- outer(seq_len(nrow(pair_table)), seq_len(nrow(pair_table)),
    Vectorize(function(i, j) {
      if (identical(pair_table$series[i], pair_table$series[j])) {
        phi^abs(pair_table$time[i] - pair_table$time[j])
      } else {
        0
      }
    })
  )
  trait <- fit$tmb_data$trait_id + 1L
  site <- fit$tmb_data$site_id + 1L
  covariance <- C[site, site] * tcrossprod(report$Lambda_B)[trait, trait]
  if (identical(fit$temporal$workflow, "replicated")) {
    occasion_variance <- exp(2 * par_list$theta_diag_B)[trait]
    same_pair_trait <- outer(site, site, FUN = "==") &
      outer(trait, trait, FUN = "==")
    covariance[same_pair_trait] <- covariance[same_pair_trait] +
      occasion_variance[row(covariance)[same_pair_trait]]
    diag(covariance) <- diag(covariance) + exp(2 * par_list$log_sigma_eps[1L])
  } else {
    diag(covariance) <- diag(covariance) + exp(2 * par_list$theta_diag_B)[trait]
  }
  residual <- fit$tmb_data$y - drop(fit$tmb_data$X_fix %*% par_list$b_fix)
  chol_covariance <- chol(covariance)
  0.5 * (
    length(residual) * log(2 * pi) +
      2 * sum(log(diag(chol_covariance))) +
      sum(backsolve(chol_covariance, residual, transpose = TRUE)^2)
  )
}

.temporal_fixed_phi <- function(fit, phi) {
  fixed <- fit$opt$par
  idx <- match("theta_temporal_phi", names(fixed))
  expect_false(is.na(idx))
  fixed[idx] <- atanh(phi / (1 - 1e-6))
  ## Keep this fixed-parameter oracle away from an incidental boundary fit;
  ## it tests the likelihood identity, not an optimizer's variance choice.
  fixed[names(fixed) == "theta_diag_B"] <- log(0.6)
  fixed[names(fixed) == "log_sigma_eps"] <- log(0.5)
  fixed
}

test_that("native temporal marginal likelihood matches an independent dense oracle", {
  for (replicated in c(FALSE, TRUE)) {
    dat <- .temporal_oracle_data(replicated)
    fit <- if (replicated) {
      suppressWarnings(gllvmTMB(
        value ~ 0 + trait + temporal_latent(
          0 + trait | series, time = occasion, replicate = measurement
        ), data = dat, unit = "series", family = gaussian(), silent = TRUE
      ))
    } else {
      suppressWarnings(gllvmTMB(
        value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
        data = dat, unit = "series", family = gaussian(), silent = TRUE
      ))
    }

    for (phi in c(-0.7, 0, 0.65, 0.95)) {
      fixed <- .temporal_fixed_phi(fit, phi)
      native <- as.numeric(fit$tmb_obj$fn(fixed))
      dense <- .temporal_dense_nll(fit, fixed)
      expect_equal(native, dense, tolerance = 1e-6,
        info = paste("replicated =", replicated, "phi =", phi))

      phi_idx <- match("theta_temporal_phi", names(fixed))
      h <- 1e-5
      step <- fixed
      step[phi_idx] <- step[phi_idx] + h
      up <- as.numeric(fit$tmb_obj$fn(step))
      step[phi_idx] <- step[phi_idx] - 2 * h
      down <- as.numeric(fit$tmb_obj$fn(step))
      numeric_gradient <- (up - down) / (2 * h)
      expect_equal(fit$tmb_obj$gr(fixed)[phi_idx], numeric_gradient,
        tolerance = 1e-5,
        info = paste("replicated =", replicated, "phi =", phi))
    }
  }
})

test_that("temporal oracle preserves the phi-zero and sign reductions", {
  dat <- .temporal_oracle_data(FALSE)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  zero <- .temporal_fixed_phi(fit, 0)
  full_zero <- fit$tmb_obj$env$last.par.best
  full_zero[fit$tmb_obj$env$lfixed()] <- zero
  report <- fit$tmb_obj$report(full_zero)
  pair_table <- fit$temporal$pair_table[
    match(levels(fit$data[[fit$unit_col]]), fit$temporal$pair_table$pair_id),
    , drop = FALSE
  ]
  C0 <- outer(pair_table$series, pair_table$series, FUN = "==") *
    outer(pair_table$time, pair_table$time, FUN = "==")
  expect_equal(C0, diag(nrow(pair_table)))
  expect_equal(.temporal_dense_nll(fit, zero), as.numeric(fit$tmb_obj$fn(zero)), tolerance = 1e-6)
  expect_true(all(is.finite(report$Lambda_B)))
})

test_that("temporal AR1 reductions preserve covariance and likelihood identities", {
  dat <- .temporal_oracle_data(FALSE)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  ## Regular unit-spaced positive AR1 is the OU covariance with range
  ## parameter -log(phi); this is a mathematical cross-check, not an OU API.
  positive_phi <- 0.65
  lag <- outer(0:4, 0:4, function(i, j) abs(i - j))
  expect_equal(positive_phi^lag, exp(-(-log(positive_phi)) * lag), tolerance = 1e-12)

  fixed <- .temporal_fixed_phi(fit, 0.65)
  signed <- fixed
  signed[names(signed) == "theta_rr_B"] <- -signed[names(signed) == "theta_rr_B"]
  expect_equal(fit$tmb_obj$fn(signed), fit$tmb_obj$fn(fixed), tolerance = 1e-8)

  no_loading <- fixed
  no_loading[names(no_loading) == "theta_rr_B"] <- 0
  low_phi <- .temporal_fixed_phi(fit, -0.7)
  high_phi <- .temporal_fixed_phi(fit, 0.95)
  low_phi[names(low_phi) == "theta_rr_B"] <- 0
  high_phi[names(high_phi) == "theta_rr_B"] <- 0
  expect_equal(fit$tmb_obj$fn(low_phi), fit$tmb_obj$fn(high_phi), tolerance = 1e-8)

  for (theta in c(-20, 20)) {
    boundary <- fixed
    boundary[names(boundary) == "theta_temporal_phi"] <- theta
    expect_true(is.finite(fit$tmb_obj$fn(boundary)))
    expect_true(all(is.finite(fit$tmb_obj$gr(boundary))))
  }
})
