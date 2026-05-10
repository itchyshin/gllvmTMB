## Tests for the Beta response family added to the multivariate engine.
##
## DGP:  y_it ~ Beta(mu_it * phi, (1 - mu_it) * phi);  mu_it = invlogit(b_t)
## Fit:  family = Beta()
##
## Biological motivation: the Beta family is the standard family for
## proportion-on-(0,1) data such as plant cover, habitat suitability, and
## disease prevalence on a continuous scale. See Damgaard (2009) Journal of
## Vegetation Science 20:991-1000 (Beta regression for plant cover) and
## Hovick et al. (2012) Conservation Biology 26:1049-1057 (Beta for habitat
## suitability indices).

test_that("Beta family converges and recovers trait intercepts + phi", {
  skip_on_cran()
  set.seed(2025)
  n_ind <- 200
  Tn    <- 4
  trait_names <- letters[seq_len(Tn)]
  ## Logit-scale intercepts -> mu in [0.27, 0.73] (avoid degenerate boundaries)
  mu_true  <- c(-1.0, -0.4, 0.4, 1.0)
  phi_true <- 5.0      # moderate concentration (Smithson & Verkuilen 2006)

  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    p_t <- stats::plogis(mu_true[t])
    y[, t] <- stats::rbeta(n_ind, p_t * phi_true, (1 - p_t) * phi_true)
  }

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  ## Sanity: y is strictly inside (0, 1)
  expect_true(all(df$value > 0 & df$value < 1))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df,
    unit   = "individual",
    family = Beta()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 7L)

  ## Trait intercepts on the logit scale should match mu_true
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.20)

  ## Per-trait phi should land in [phi/3, 3*phi]
  phi_hat <- as.numeric(fit$report$phi_beta)
  expect_equal(length(phi_hat), Tn)
  expect_true(all(phi_hat > phi_true / 3 & phi_hat < 3 * phi_true))
})

test_that("Beta logLik agrees with glmmTMB::beta_family() at the obs-likelihood level", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")
  set.seed(123)
  n_ind <- 250
  Tn    <- 2
  mu_true  <- c(-0.5, 0.5)
  phi_true <- 5.0
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    p_t <- stats::plogis(mu_true[t])
    y[, t] <- stats::rbeta(n_ind, p_t * phi_true, (1 - p_t) * phi_true)
  }

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), n_ind), levels = c("a", "b")),
    value      = as.vector(t(y))
  )

  fit_g <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df, unit = "individual", family = Beta()
  )))

  ## Per-trait glmmTMB Beta fits with a per-individual RE (mirrors the
  ## per-trait latent-rank-1 structure roughly).
  fit_a <- glmmTMB::glmmTMB(value ~ 1 + (1 | individual), data = df[df$trait == "a", ],
                            family = glmmTMB::beta_family())
  fit_b <- glmmTMB::glmmTMB(value ~ 1 + (1 | individual), data = df[df$trait == "b", ],
                            family = glmmTMB::beta_family())

  ll_gllvm   <- -fit_g$opt$objective
  ll_glmmTMB <- as.numeric(stats::logLik(fit_a)) + as.numeric(stats::logLik(fit_b))
  rel_err    <- abs(ll_gllvm - ll_glmmTMB) / abs(ll_glmmTMB)
  expect_lt(rel_err, 0.05)
})

test_that("Beta rejects non-logit link", {
  expect_error(
    suppressMessages(gllvmTMB(
      data.frame(individual = 1:10, trait = "a",
                 value = stats::rbeta(10, 2, 2)) |>
        (\(d) { d$individual <- factor(d$individual); d$trait <- factor(d$trait); d })(),
      formula = value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      unit = "individual",
      family = Beta(link = "probit")
    )),
    regexp = "logit link|not available"
  )
})
