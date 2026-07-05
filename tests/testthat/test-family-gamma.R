## Tests for the Gamma response family added to the multivariate engine.
## DGP:  y_i ~ Gamma(shape, scale) with E(y) = mu = exp(eta)
## Fit:  family = Gamma(link = "log")
## Recovery: trait intercepts mu_t (on the log scale) and phi_gamma shape

test_that("Gamma(link='log') fits and recovers trait intercepts at modest n", {
  set.seed(2025)
  n_ind <- 200
  Tn    <- 3
  trait_names <- c("a", "b", "c")
  Lambda <- matrix(c(0.4, 0.2, -0.1,
                     0.0, 0.3,  0.2),
                   nrow = Tn, ncol = 2)
  mu_eta_true <- c(0.5, -0.5, 1.0)   # log-scale intercepts
  cv_true     <- 0.30                 # gamma CV; shape = 1/cv^2 ~ 11.1

  u <- matrix(rnorm(n_ind * 2), n_ind, 2)
  log_mu <- matrix(rep(mu_eta_true, each = n_ind), n_ind, Tn) +
            u %*% t(Lambda)
  mu     <- exp(log_mu)

  shape <- 1 / cv_true^2
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    y[, t] <- rgamma(n_ind, shape = shape, scale = mu[, t] / shape)
  }

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2, unique = FALSE),
    data   = df,
    site   = "individual",
    family = Gamma(link = "log")
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 4L)

  # Trait intercepts on the log scale should match mu_eta_true
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_eta_true)), 0.15)

  # Gamma shape is per trait; CV = 1 / sqrt(phi_gamma).
  phi_hat <- as.numeric(fit$report$phi_gamma)
  expect_equal(length(phi_hat), Tn)
  cv_hat <- 1 / sqrt(phi_hat)
  expect_lt(max(abs(cv_hat - cv_true)), 0.05)
})

test_that("Gamma dispersion is decoupled from Gaussian sigma_eps in mixed fits", {
  set.seed(622)
  n <- 180
  sigma_g <- 0.20
  shape_gamma <- 9
  df <- data.frame(
    individual = factor(rep(seq_len(n), each = 2L)),
    trait = factor(rep(c("gaussian", "gamma"), n),
                   levels = c("gaussian", "gamma")),
    family = factor(rep(c("g", "gm"), n), levels = c("g", "gm")),
    value = NA_real_
  )
  is_g <- df$family == "g"
  mu_g <- 1.5
  mu_gamma <- 2.0
  df$value[is_g] <- stats::rnorm(sum(is_g), mean = mu_g, sd = sigma_g)
  df$value[!is_g] <- stats::rgamma(
    sum(!is_g),
    shape = shape_gamma,
    scale = mu_gamma / shape_gamma
  )

  family_list <- list(g = gaussian(), gm = Gamma(link = "log"))
  attr(family_list, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait,
    data = df,
    site = "individual",
    family = family_list,
    control = gllvmTMBcontrol(se = FALSE)
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(any(fit$tmb_data$family_id_vec == 0L))
  expect_true(any(fit$tmb_data$family_id_vec == 4L))
  expect_true(is.finite(fit$report$sigma_eps))
  expect_equal(length(fit$report$phi_gamma), 2L)

  sigma_hat <- as.numeric(fit$report$sigma_eps)
  gamma_shape_hat <- as.numeric(fit$report$phi_gamma)[2L]
  gamma_cv_hat <- 1 / sqrt(gamma_shape_hat)

  expect_lt(abs(sigma_hat - sigma_g), 0.08)
  expect_lt(abs(gamma_cv_hat - 1 / sqrt(shape_gamma)), 0.08)
  expect_gt(abs(sigma_hat - gamma_cv_hat), 0.05)
})

test_that("Gamma errors on default inverse link (must use log)", {
  set.seed(1)
  df <- data.frame(
    individual = factor(rep(1:20, each = 2)),
    trait      = factor(rep(c("a", "b"), 20)),
    value      = rgamma(40, shape = 5, scale = 1)
  )
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
      data = df, site = "individual", family = Gamma()
    ))),
    regexp = "log link"
  )
})

test_that("Gamma errors on non-positive observed y", {
  set.seed(2)
  df <- data.frame(
    individual = factor(rep(1:20, each = 2)),
    trait      = factor(rep(c("a", "b"), 20)),
    value      = rep(c(1.0, 0.0), 20)
  )
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
      data = df, site = "individual", family = Gamma(link = "log")
    ))),
    regexp = "strictly positive"
  )
})
