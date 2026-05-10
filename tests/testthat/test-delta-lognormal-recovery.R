## Tests for the delta_lognormal (hurdle) response family added to the
## multivariate engine.
##
## DGP: y_it has an exact zero point mass + lognormal positive part:
##   p_pres(it) = invlogit(eta_it);  presence ~ Bernoulli(p_pres)
##   pos | presence = 1: log y_it ~ Normal(eta_it, sigma_lognormal)
##   eta_it = b_t (trait intercept under shared-predictor scheme)
## Fit: family = delta_lognormal()
##
## Biological motivation: delta-lognormal is the canonical fisheries CPUE /
## survey biomass family with bycatch zeros. Reference: Maunder & Punt
## (2004) Fish. Res. 70:141-159 (delta-lognormal in fisheries CPUE
## standardisation) and Stefansson (1996) Fish. Res. 28:121-149
## (lognormal CPUE with bycatch zeros).
##
## Implementation note (shared-predictor coupling). The shared-predictor
## simplification means the trait intercept controls BOTH the presence
## rate (invlogit(eta)) AND the positive-component mean (exp(eta)). So a
## trait whose log-mean is high will also have high presence rate
## (biologically sensible: more abundant species are more often
## detected), but the test cannot independently tune p_zero and mu.
##
## Joint-MLE bias in finite samples. The Bernoulli score function wants
## logit(eta) = mean(I{y>0}); the lognormal score wants eta =
## mean(log y | y > 0). Asymptotically both converge to the truth, but
## in finite samples they pull on the same eta in slightly different
## directions, with a precision-weighted compromise as the joint MLE. We
## therefore use n_ind = 800 (rather than 200-400 used by tweedie /
## nb2 recovery tests) so the finite-sample tension is comfortably below
## the recovery tolerance of 0.20.

test_that("delta_lognormal converges and recovers trait intercepts + per-trait sigma", {
  skip_on_cran()
  set.seed(2025)
  n_ind <- 800
  Tn    <- 3
  trait_names <- letters[seq_len(Tn)]
  ## Trait intercepts on the link scale. Under the shared eta:
  ##   p_pres_t = invlogit(eta_t), mu_pos_t = exp(eta_t).
  ## With these values, p_pres_t ~ (0.73, 0.82, 0.88) -> ~12-27% zeros.
  mu_true <- c(1.0, 1.5, 2.0)
  sigma_true <- 0.7

  ## Generate one row per (individual, trait): presence ~ Bernoulli(invlogit(eta));
  ## positives ~ rlnorm(eta, sigma).
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    eta_t <- mu_true[t]
    p_t   <- 1 / (1 + exp(-eta_t))
    pres  <- stats::rbinom(n_ind, 1, p_t)
    pos   <- stats::rlnorm(n_ind, meanlog = eta_t, sdlog = sigma_true)
    y[, t] <- pres * pos
  }

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  ## Sanity: y has zeros (presence-Bernoulli component) and positives.
  expect_true(any(df$value == 0))
  expect_true(any(df$value > 0))
  expect_true(all(df$value >= 0))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df,
    site   = "individual",
    family = delta_lognormal()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 12L)

  ## Trait intercepts on the link scale.
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.20)

  ## Per-trait sigma_lognormal close to truth. Tolerance widened to 0.20
  ## (vs the typical 0.10-0.15 for marginal-MLE recovery) because the
  ## shared-predictor joint MLE is more sensitive to finite-sample
  ## variation in the Bernoulli component when implied presence rates are
  ## moderate (see header comment).
  sigma_hat <- as.numeric(fit$report$sigma_lognormal_delta)
  expect_equal(length(sigma_hat), Tn)
  expect_true(all(abs(sigma_hat - sigma_true) < 0.20))

  ## Empirical presence rate close to fitted invlogit(eta).
  emp_pres <- mean(df$value > 0)
  fit_pres <- mean(1 / (1 + exp(-fit$report$eta)))
  expect_lt(abs(emp_pres - fit_pres), 0.05)
})

test_that("delta_lognormal rejects negative response", {
  set.seed(1)
  df <- data.frame(
    individual = factor(rep(1:5, each = 2)),
    trait      = factor(rep(c("a", "b"), 5), levels = c("a", "b")),
    value      = c(0, 1.2, 2.4, 0, -0.1, 1.0, 0.5, 0.8, 0, 1.5)
  )
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      data = df, site = "individual", family = delta_lognormal()
    )),
    regexp = "non-negative"
  )
})

test_that("delta_lognormal accepts string entry family = 'delta_lognormal'", {
  skip_on_cran()
  set.seed(7)
  n_ind <- 80
  Tn <- 2
  trait_names <- c("a", "b")
  mu_true <- c(1.0, 1.5)
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    p_t <- 1 / (1 + exp(-mu_true[t]))
    pres <- stats::rbinom(n_ind, 1, p_t)
    pos  <- stats::rlnorm(n_ind, mu_true[t], 0.5)
    y[, t] <- pres * pos
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df, site = "individual", family = "delta_lognormal"
  )))
  expect_equal(fit$tmb_data$family_id_vec[1], 12L)
})

test_that("delta_lognormal poisson-link parameterisation is rejected", {
  expect_error(
    suppressMessages(gllvmTMB(
      data.frame(individual = factor(1:10),
                 trait      = factor(rep("a", 10)),
                 value      = c(rep(0, 3), runif(7, 0.1, 5))),
      formula = value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      site = "individual",
      family = delta_lognormal(type = "poisson-link")
    )),
    regexp = "standard"
  )
})
