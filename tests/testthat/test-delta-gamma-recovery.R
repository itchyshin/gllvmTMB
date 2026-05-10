## Tests for the delta_gamma (hurdle) response family added to the
## multivariate engine.
##
## DGP: y_it has an exact zero point mass + Gamma positive part:
##   p_pres(it) = invlogit(eta_it);  presence ~ Bernoulli(p_pres)
##   pos | presence = 1: y_it ~ Gamma(shape = 1/phi^2, scale = exp(eta) * phi^2)
##   so E(y | pres) = exp(eta), CV(y | pres) = phi.
## Fit: family = delta_gamma()
##
## Biological motivation: delta-gamma is a fisheries / survey biomass
## family for non-negative continuous data with an exact zero point
## mass plus a Gamma positive part. Reference: Lo, Jacobson & Squire
## (1992) Can. J. Fish. Aquat. Sci. 49:2515-2526 (delta-Gamma in fisheries
## CPUE). Maunder & Punt (2004) Fish. Res. 70:141-159 also covers
## the delta-Gamma flavour as an alternative to delta-lognormal.
##
## Implementation note (shared predictor): same caveat as delta_lognormal
## -- presence rate AND positive-component mean both depend on the same
## eta. The trait intercepts must be picked so that the implied presence
## rates are not too close to 1 (no zeros to estimate the Bernoulli
## component) or too close to 0 (no positives to estimate Gamma).

test_that("delta_gamma converges and recovers trait intercepts + per-trait phi", {
  skip_on_cran()
  set.seed(2025)
  n_ind <- 400
  Tn    <- 3
  trait_names <- letters[seq_len(Tn)]
  ## Pick eta so p_pres in [0.62, 0.88] -> ~12-38% zeros, plus a healthy
  ## Gamma positive part to estimate phi.
  mu_true  <- c(0.5, 1.0, 2.0)
  phi_true <- 1.0   # CV = 1 -> shape = 1 -> Exponential

  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    eta_t <- mu_true[t]
    p_t   <- 1 / (1 + exp(-eta_t))
    pres  <- stats::rbinom(n_ind, 1, p_t)
    shape <- 1 / phi_true^2
    scale <- exp(eta_t) * phi_true^2
    pos   <- stats::rgamma(n_ind, shape = shape, scale = scale)
    y[, t] <- pres * pos
  }

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  expect_true(any(df$value == 0))
  expect_true(any(df$value > 0))
  expect_true(all(df$value >= 0))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df,
    site   = "individual",
    family = delta_gamma()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 13L)

  ## Trait intercepts on the link scale.
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.30)

  ## Per-trait phi (Gamma CV) close to truth.
  phi_hat <- as.numeric(fit$report$phi_gamma_delta)
  expect_equal(length(phi_hat), Tn)
  expect_true(all(phi_hat > 0.5 * phi_true & phi_hat < 2 * phi_true))

  ## Empirical presence rate close to fitted invlogit(eta).
  emp_pres <- mean(df$value > 0)
  fit_pres <- mean(1 / (1 + exp(-fit$report$eta)))
  expect_lt(abs(emp_pres - fit_pres), 0.05)
})

test_that("delta_gamma rejects negative response", {
  df <- data.frame(
    individual = factor(rep(1:5, each = 2)),
    trait      = factor(rep(c("a", "b"), 5), levels = c("a", "b")),
    value      = c(0, 1.2, 2.4, 0, -0.5, 1.0, 0.5, 0.8, 0, 1.5)
  )
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      data = df, site = "individual", family = delta_gamma()
    )),
    regexp = "non-negative"
  )
})

test_that("delta_gamma accepts string entry family = 'delta_gamma'", {
  skip_on_cran()
  set.seed(7)
  n_ind <- 80
  Tn <- 2
  trait_names <- c("a", "b")
  mu_true <- c(0.5, 1.0)
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    eta_t <- mu_true[t]
    p_t <- 1 / (1 + exp(-eta_t))
    pres <- stats::rbinom(n_ind, 1, p_t)
    pos  <- stats::rgamma(n_ind, shape = 1, scale = exp(eta_t))
    y[, t] <- pres * pos
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df, site = "individual", family = "delta_gamma"
  )))
  expect_equal(fit$tmb_data$family_id_vec[1], 13L)
})

test_that("delta_gamma poisson-link parameterisation is rejected", {
  expect_error(
    suppressMessages(gllvmTMB(
      data.frame(individual = factor(1:10),
                 trait      = factor(rep("a", 10)),
                 value      = c(rep(0, 3), runif(7, 0.1, 5))),
      formula = value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      site = "individual",
      family = delta_gamma(type = "poisson-link")
    )),
    regexp = "standard"
  )
})
