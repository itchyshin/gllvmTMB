## Tests for the lognormal response family added to the multivariate engine.
## DGP:  log(y_i) ~ Normal(mu_t + lambda_t' u_i, sigma_eps^2)
## Fit:  family = lognormal()
## Recovery: trait intercepts mu_t and the implied trait covariance Lambda Lambda^T

test_that("lognormal family fits and recovers trait intercepts at modest n", {
  set.seed(2025)
  n_ind <- 200
  Tn    <- 3
  trait_names <- c("a", "b", "c")
  Lambda <- matrix(c(0.5, 0.3, -0.2,
                     0.0, 0.6,  0.4),
                   nrow = Tn, ncol = 2)
  mu_true     <- c(1.0, -0.5, 0.3)
  sigma_eps_t <- 0.3

  u <- matrix(rnorm(n_ind * 2), n_ind, 2)
  log_y <- matrix(rep(mu_true, each = n_ind), n_ind, Tn) +
           u %*% t(Lambda) +
           matrix(rnorm(n_ind * Tn, sd = sigma_eps_t), n_ind, Tn)
  y <- exp(log_y)

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2),
    data   = df,
    site   = "individual",
    family = lognormal()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 3L)

  # Trait intercepts should match mu_true within a couple of SE
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.15)
})

test_that("lognormal errors on non-positive y (sanity)", {
  set.seed(1)
  df <- data.frame(
    individual = factor(rep(1:20, each = 2)),
    trait      = factor(rep(c("a", "b"), 20)),
    value      = c(rep(c(1.0, -0.5), 20))   # contains negatives -> log() => NaN
  )
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      data = df, site = "individual", family = lognormal()
    ))),
    regexp = "."   # anything; the engine should fail rather than silently fit
  )
})

test_that("lognormal rejects non-log link", {
  expect_error(
    suppressMessages(gllvmTMB(
      data.frame(individual = 1:10, trait = "a", value = exp(rnorm(10))) |>
        (\(d) { d$individual <- factor(d$individual); d$trait <- factor(d$trait); d })() ,
      formula = value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      site = "individual",
      family = lognormal(link = "identity")
    )),
    regexp = "log link"
  )
})
