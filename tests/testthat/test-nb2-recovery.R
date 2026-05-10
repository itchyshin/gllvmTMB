## Tests for the NB2 (negative binomial type 2) response family added to the
## multivariate engine.
##
## DGP:  y_it ~ NB2(mu_it, phi);  mu_it = exp(b_t + x_i * beta_t);  Var(y) = mu + mu^2 / phi
## Fit:  family = nbinom2()
##
## Biological motivation: NB2 is the canonical overdispersed-count family in
## ecology — see Ver Hoef & Boveng (2007) Ecology 88:2766–2772 (NB2 vs.
## quasi-Poisson default for ecological count overdispersion) and
## Lindén & Mäntyniemi (2011) Ecology 92:1414–1421 (NB2 for fish counts).

test_that("nbinom2 family converges and recovers trait intercepts + phi", {
  skip_on_cran()
  set.seed(2025)
  ## Increase n per trait so the empirical variance reliably exceeds the
  ## Poisson floor; otherwise small-sample underdispersion can push phi -> Inf.
  n_ind <- 300
  Tn    <- 5
  trait_names <- letters[seq_len(Tn)]
  mu_true  <- c(1.0, 1.5, 0.5, 2.0, 1.2)
  phi_true <- 2.0           # moderate overdispersion (Ver Hoef & Boveng 2007)

  y <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- rnbinom(n_ind, mu = exp(mu_true[t]), size = phi_true)

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df,
    site   = "individual",
    family = nbinom2()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 5L)

  ## Trait intercepts on the log scale should match mu_true
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.30)

  ## Per-trait phi mean should land in [phi/3, 3*phi]; individual traits at
  ## n=300 typically recover within ~50%.
  phi_hat <- as.numeric(fit$report$phi_nbinom2)
  expect_equal(length(phi_hat), Tn)
  expect_gt(mean(phi_hat), phi_true / 3)
  expect_lt(mean(phi_hat), 3 * phi_true)
})

test_that("nbinom2 logLik agrees with glmmTMB::nbinom2() at the obs-likelihood level", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")
  set.seed(123)
  n_ind <- 200
  Tn    <- 2
  mu_true  <- c(1.0, 1.5)
  phi_true <- 2.0
  y <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- rnbinom(n_ind, mu = exp(mu_true[t]), size = phi_true)

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), n_ind), levels = c("a", "b")),
    value      = as.vector(t(y))
  )

  ## gllvmTMB fit (multi engine, requires a covstruct -- we use a tiny
  ## per-trait `unique()` whose variance is driven near 0 so it does not
  ## change the marginal observation likelihood materially).
  fit_g <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df, site = "individual", family = nbinom2()
  )))

  ## glmmTMB per-trait fits (independent intercept + per-trait phi) +
  ## a per-individual random intercept. Sum log-liks across traits.
  fit_a <- glmmTMB::glmmTMB(value ~ 1 + (1 | individual), data = df[df$trait == "a", ],
                            family = glmmTMB::nbinom2())
  fit_b <- glmmTMB::glmmTMB(value ~ 1 + (1 | individual), data = df[df$trait == "b", ],
                            family = glmmTMB::nbinom2())

  ## With small RE, the order-of-magnitude logLik should match. We test
  ## relative agreement of <1% rather than exact (RE structures differ).
  ll_gllvm  <- -fit_g$opt$objective
  ll_glmmTMB <- as.numeric(stats::logLik(fit_a)) + as.numeric(stats::logLik(fit_b))
  rel_err <- abs(ll_gllvm - ll_glmmTMB) / abs(ll_glmmTMB)
  expect_lt(rel_err, 0.01)
})

test_that("nbinom2 rejects non-log link", {
  expect_error(
    suppressMessages(gllvmTMB(
      data.frame(individual = 1:10, trait = "a", value = rpois(10, 3)) |>
        (\(d) { d$individual <- factor(d$individual); d$trait <- factor(d$trait); d })(),
      formula = value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      site = "individual",
      family = nbinom2(link = "identity")
    )),
    regexp = "log link"
  )
})
