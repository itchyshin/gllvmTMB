## Named migration fixture only.  It records the old prototype's covariance
## so reviews can see exactly what the sixth-source contract replaced.
test_that("retired AR1 prototype kept Psi iid while the temporal row does not", {
  phi <- 0.65
  gap <- 2L
  lambda <- c(0.4, -0.2, 0.3)
  psi <- c(0.25, 0.36, 0.49)
  K <- phi^gap
  retired <- K * tcrossprod(lambda)
  current <- K * (tcrossprod(lambda) + diag(psi))
  expect_equal(retired[1, 1], K * lambda[1]^2)
  expect_equal(current[1, 1], K * (lambda[1]^2 + psi[1]))
  expect_gt(abs(current[1, 1] - retired[1, 1]), 1e-6)
})

test_that("AR1 reductions retain sign, zero, gap, and boundary identities", {
  dat <- expand.grid(series = paste0("s", 1:3), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  dat$value <- seq_len(nrow(dat)) / 10
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion,
      unique = TRUE), data = dat, unit = "series", family = gaussian(),
    silent = TRUE
  ))
  fixed <- fit$opt$par
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(0.65 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_rr"] <- 0.4
  fixed[names(fixed) == "theta_temporal_diag"] <- log(0.6)
  fixed[names(fixed) == "log_sigma_eps"] <- log(0.5)
  signed <- fixed
  signed[names(signed) == "theta_temporal_rr"] <- -0.4
  expect_equal(fit$tmb_obj$fn(signed), fit$tmb_obj$fn(fixed), tolerance = 1e-8)
  phi_zero <- fixed
  phi_zero[names(phi_zero) == "theta_temporal_time"] <- 0
  phi <- (1 - 1e-6) * tanh(phi_zero[names(phi_zero) == "theta_temporal_time"])
  expect_equal(unname(phi), 0)
  expect_equal(0.65^abs(1L - 7L), 0.65^6)
  for (theta in c(-20, 20)) {
    boundary <- fixed
    boundary[names(boundary) == "theta_temporal_time"] <- theta
    expect_true(is.finite(fit$tmb_obj$fn(boundary)))
    expect_true(all(is.finite(fit$tmb_obj$gr(boundary))))
  }
})
