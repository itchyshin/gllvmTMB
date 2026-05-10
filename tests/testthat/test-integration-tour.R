# End-to-end integration tour: exercises every public gllvmTMB function
# in one shot on a small simulated dataset. Acts as a smoke test for any
# regression in the public API.

test_that("integration: simulate -> fit -> all extractors -> predict -> simulate", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites               = 60,
    n_species             = 12,
    n_traits              = 4,
    mean_species_per_site = 6,
    Lambda_B              = matrix(c(1.0, 0.7, -0.3, 0.5,
                                     0.3, -0.5, 0.8, 0.2),
                                   nrow = 4, ncol = 2),
    S_B                   = c(0.3, 0.3, 0.3, 0.3),
    Lambda_W              = matrix(c(0.6, 0.3, -0.2, 0.4), nrow = 4, ncol = 1),
    S_W                   = c(0.4, 0.4, 0.4, 0.4),
    seed                  = 2025
  )

  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            latent(0 + trait | site, d = 2) + unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = sim$data
  )

  ## Class + convergence
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)

  ## Print + summary + logLik
  expect_output(print(fit), "Stacked-trait gllvmTMB fit")
  s <- summary(fit)
  expect_s3_class(s, "summary.gllvmTMB_multi")
  ll <- stats::logLik(fit)
  expect_equal(attr(ll, "df"), length(fit$opt$par))

  ## Tidy
  td_fix <- tidy(fit, "fixed", conf.int = TRUE)
  expect_true(all(c("estimate", "std.error", "conf.low", "conf.high") %in%
                  names(td_fix)))
  td_rp <- tidy(fit, "ran_pars")
  expect_true(nrow(td_rp) > 0)

  ## Predict (training + newdata, both with and without RE)
  p_train <- predict(fit)
  expect_equal(nrow(p_train), nrow(sim$data))
  suppressMessages({
    p_new_re <- predict(fit, newdata = head(sim$data, 4))
    p_new_fx <- predict(fit, newdata = head(sim$data, 4), re_form = ~ 0)
  })
  expect_equal(nrow(p_new_re), 4)
  expect_true(any(abs(p_new_re$est - p_new_fx$est) > 1e-6))

  ## Simulate
  y_sim <- simulate(fit, nsim = 2, seed = 7)
  expect_equal(dim(y_sim), c(nrow(sim$data), 2L))

  ## Extractors
  B <- extract_Sigma_B(fit); expect_named(B, c("Sigma_B", "R_B"))
  W <- extract_Sigma_W(fit); expect_named(W, c("Sigma_W", "R_W"))
  icc <- extract_ICC_site(fit)
  expect_length(icc, 4)
  expect_true(all(icc > 0 & icc < 1))
  c_B <- extract_communality(fit, "B")
  expect_length(c_B, 4); expect_true(all(c_B > 0 & c_B <= 1))
  ord <- extract_ordination(fit, "B")
  expect_equal(ncol(ord$scores), 2)

  ## Sanity (just ensure no error and returns named list)
  flags <- capture.output(s_flags <- sanity_multi(fit))
  expect_true("converged" %in% names(s_flags))
})
