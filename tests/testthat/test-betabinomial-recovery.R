## Tests for the beta-binomial response family added to the multivariate
## engine.
##
## DGP:  p_it ~ Beta(mu_it * phi, (1 - mu_it) * phi);  y_it | p_it ~ Binom(N, p_it)
##       mu_it = invlogit(b_t)
## Fit:  family = betabinomial()
##
## Biological motivation: beta-binomial is the standard family for
## overdispersed binomial data such as parasite prevalence, infection rates,
## and behavioural choice frequencies aggregated across trials. See Crawley
## (2013) The R Book (Wiley), Chapter 16, for ecological applications and
## Stoklosa et al. (2022) Methods in Ecology and Evolution 13:1199-1212 for
## modern beta-binomial GLMM use cases.

test_that("betabinomial family converges and recovers trait intercepts + phi", {
  skip_on_cran()
  set.seed(2025)
  n_ind <- 200
  Tn    <- 4
  trait_names <- letters[seq_len(Tn)]
  ## Logit-scale intercepts
  mu_true  <- c(-1.0, -0.4, 0.4, 1.0)
  phi_true <- 3.0      # moderate overdispersion (Stoklosa et al. 2022)
  N        <- 10L      # trials per row

  succ <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    p_t      <- stats::plogis(mu_true[t])
    p_random <- stats::rbeta(n_ind, p_t * phi_true, (1 - p_t) * phi_true)
    succ[, t] <- stats::rbinom(n_ind, size = N, prob = p_random)
  }
  fail <- N - succ

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    succ       = as.vector(t(succ)),
    fail       = as.vector(t(fail))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df,
    unit   = "individual",
    family = betabinomial()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 8L)

  ## Trait intercepts on the logit scale should match mu_true
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.30)

  ## Per-trait phi should land in [phi/3, 3*phi]
  phi_hat <- as.numeric(fit$report$phi_betabinom)
  expect_equal(length(phi_hat), Tn)
  expect_true(all(phi_hat > phi_true / 3 & phi_hat < 3 * phi_true))
})

test_that("betabinomial logLik agrees with glmmTMB::betabinomial() at the obs-likelihood level", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")
  set.seed(123)
  n_ind <- 250
  Tn    <- 2
  mu_true  <- c(-0.5, 0.5)
  phi_true <- 3.0
  N        <- 10L

  succ <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    p_t      <- stats::plogis(mu_true[t])
    p_random <- stats::rbeta(n_ind, p_t * phi_true, (1 - p_t) * phi_true)
    succ[, t] <- stats::rbinom(n_ind, size = N, prob = p_random)
  }
  fail <- N - succ

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), n_ind), levels = c("a", "b")),
    succ       = as.vector(t(succ)),
    fail       = as.vector(t(fail))
  )

  fit_g <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df, unit = "individual", family = betabinomial()
  )))

  fit_a <- glmmTMB::glmmTMB(cbind(succ, fail) ~ 1 + (1 | individual),
                            data = df[df$trait == "a", ],
                            family = glmmTMB::betabinomial())
  fit_b <- glmmTMB::glmmTMB(cbind(succ, fail) ~ 1 + (1 | individual),
                            data = df[df$trait == "b", ],
                            family = glmmTMB::betabinomial())

  ll_gllvm   <- -fit_g$opt$objective
  ll_glmmTMB <- as.numeric(stats::logLik(fit_a)) + as.numeric(stats::logLik(fit_b))
  rel_err    <- abs(ll_gllvm - ll_glmmTMB) / abs(ll_glmmTMB)
  expect_lt(rel_err, 0.05)
})

test_that("betabinomial rejects non-logit link", {
  expect_error(
    suppressMessages(gllvmTMB(
      data.frame(individual = 1:10, trait = "a",
                 succ = rbinom(10, 5, 0.3), fail = 5L - rbinom(10, 5, 0.3)) |>
        (\(d) { d$individual <- factor(d$individual); d$trait <- factor(d$trait); d })(),
      formula = cbind(succ, fail) ~ 0 + trait + latent(0 + trait | individual, d = 1),
      unit = "individual",
      family = betabinomial(link = "cloglog")
    )),
    regexp = "logit link"
  )
})
