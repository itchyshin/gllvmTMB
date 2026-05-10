## Tests for the Tweedie compound Poisson-Gamma response family added to the
## multivariate engine.
##
## DGP:  y_it ~ Tweedie(mu_it, phi, p);  mu_it = exp(b_t);  Var(y) = phi * mu^p
## Fit:  family = tweedie()
##
## Biological motivation: Tweedie is the standard family for catch / biomass
## survey data where the response is non-negative continuous with an exact
## point mass at zero (the compound Poisson-Gamma regime, 1 < p < 2). See
## Shono (2008) Fish. Res. 93:154-162 (Tweedie GLMM for fisheries CPUE data)
## and Lecomte et al. (2013) Ecol. Model. 265:74-84 (Tweedie GLMM for
## ecological survey biomass).

test_that("tweedie family converges and recovers trait intercepts + phi + p", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  set.seed(2025)
  n_ind <- 200
  Tn    <- 4
  trait_names <- letters[seq_len(Tn)]
  mu_true  <- c(1.0, 2.0, 0.5, 1.5)   # log-scale intercepts
  phi_true <- 1.0
  p_true   <- 1.5                     # mid of the compound Poisson-Gamma regime

  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- mgcv::rTweedie(rep(exp(mu_true[t]), n_ind), p = p_true, phi = phi_true)

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  ## Sanity: y has zeros and positive continuous values (compound regime)
  expect_true(any(df$value == 0))
  expect_true(any(df$value > 0))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df,
    site   = "individual",
    family = tweedie()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 6L)

  ## Trait intercepts should match mu_true within ~0.2 on the log scale
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.20)

  ## Per-trait phi and p reasonably close to truth
  phi_hat <- as.numeric(fit$report$phi_tweedie)
  p_hat   <- as.numeric(fit$report$p_tweedie)
  expect_equal(length(phi_hat), Tn)
  expect_equal(length(p_hat),   Tn)
  expect_true(all(p_hat > 1 & p_hat < 2))
  expect_true(all(phi_hat > 0.5 * phi_true & phi_hat < 2 * phi_true))
  expect_true(all(abs(p_hat - p_true) < 0.30))
})

test_that("tweedie logLik agrees with glmmTMB::tweedie() at the obs-likelihood level", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("mgcv")
  set.seed(123)
  n_ind <- 250
  Tn    <- 2
  mu_true  <- c(1.0, 1.8)
  phi_true <- 1.0
  p_true   <- 1.5
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- mgcv::rTweedie(rep(exp(mu_true[t]), n_ind), p = p_true, phi = phi_true)

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), n_ind), levels = c("a", "b")),
    value      = as.vector(t(y))
  )

  fit_g <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df, site = "individual", family = tweedie()
  )))

  ## Per-trait glmmTMB Tweedie fits with a per-individual RE (mirrors
  ## the per-trait latent-rank-1 structure roughly).
  fit_a <- glmmTMB::glmmTMB(value ~ 1 + (1 | individual), data = df[df$trait == "a", ],
                            family = glmmTMB::tweedie())
  fit_b <- glmmTMB::glmmTMB(value ~ 1 + (1 | individual), data = df[df$trait == "b", ],
                            family = glmmTMB::tweedie())

  ll_gllvm   <- -fit_g$opt$objective
  ll_glmmTMB <- as.numeric(stats::logLik(fit_a)) + as.numeric(stats::logLik(fit_b))
  rel_err    <- abs(ll_gllvm - ll_glmmTMB) / abs(ll_glmmTMB)
  expect_lt(rel_err, 0.05)
})

test_that("tweedie rejects non-log link", {
  expect_error(
    suppressMessages(gllvmTMB(
      data.frame(individual = 1:10, trait = "a", value = c(rep(0, 3), runif(7, 0.1, 5))) |>
        (\(d) { d$individual <- factor(d$individual); d$trait <- factor(d$trait); d })(),
      formula = value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      site = "individual",
      family = tweedie(link = "identity")
    )),
    regexp = "log link"
  )
})
