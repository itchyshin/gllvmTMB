## Tests for the Gamma response family added to the multivariate engine.
## DGP:  y_i ~ Gamma(shape, scale) with E(y) = mu = exp(eta), CV = sigma_eps
## Fit:  family = Gamma(link = "log")
## Recovery: trait intercepts mu_t (on the log scale) and sigma_eps (CV)

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
    value ~ 0 + trait + latent(0 + trait | individual, d = 2),
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

  # CV (sigma_eps) should be near the true value
  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_lt(abs(cv_hat - cv_true), 0.05)
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
      value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      data = df, site = "individual", family = Gamma()
    ))),
    regexp = "log link"
  )
})
