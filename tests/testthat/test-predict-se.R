# predict(..., se.fit = TRUE): conditional (fixed-effect-only) delta-method
# standard error of the linear predictor / fitted value (GAP 2, VA lane 2
# output-surface work, 2026-08-03).

test_that("predict() without se.fit is byte-identical to pre-existing behaviour", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 3, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.6, 0.4, -0.3), 3, 1),
    seed = 2025
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + latent(0 + trait | site, d = 1),
    data = sim$data
  )
  out_default <- predict(fit)
  out_explicit_false <- predict(fit, se.fit = FALSE)
  expect_identical(out_default, out_explicit_false)
  expect_false("se.fit" %in% names(out_default))
  expect_null(attr(out_default, "se.fit.scale"))
})

test_that("predict(se.fit = TRUE) returns positive, finite link-scale SEs", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 3, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.6, 0.4, -0.3), 3, 1),
    seed = 2025
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + latent(0 + trait | site, d = 1),
    data = sim$data
  )
  out <- predict(fit, se.fit = TRUE)
  expect_true("se.fit" %in% names(out))
  expect_identical(attr(out, "se.fit.scale"), "link")
  expect_true(isTRUE(attr(out, "se.fit.conditional")))
  expect_true(all(is.finite(out$se.fit)))
  expect_true(all(out$se.fit > 0))
  ## Gaussian identity link: type = "response" must equal type = "link".
  out_resp <- predict(fit, se.fit = TRUE, type = "response")
  expect_equal(out_resp$se.fit, out$se.fit)
  expect_identical(attr(out_resp, "se.fit.scale"), "response")
})

test_that("predict(se.fit = TRUE, type = 'response') scales by the inverse-link derivative for a non-identity link", {
  set.seed(11)
  sim <- simulate_site_trait(
    n_sites = 20, n_species = 3, n_traits = 2,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.3, -0.2), 2, 1),
    seed = 11
  )
  sim$data$value <- rbinom(nrow(sim$data), 1, 0.5)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1,
    data   = sim$data,
    family = binomial()
  )))
  out_link <- predict(fit, se.fit = TRUE, type = "link")
  out_resp <- predict(fit, se.fit = TRUE, type = "response")
  expect_true(all(is.finite(out_resp$se.fit)))
  expect_true(all(out_resp$se.fit >= 0))
  ## response se = link se * |dlogit^-1/deta| = link se * p(1-p); strictly
  ## smaller than the link-scale se whenever p(1-p) < 1 (always true).
  expect_true(all(out_resp$se.fit <= out_link$se.fit))
})

test_that("predict(se.fit = TRUE) errors clearly on unsupported cases", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 3, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.6, 0.4, -0.3), 3, 1),
    seed = 2025
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + latent(0 + trait | site, d = 1),
    data = sim$data
  )
  expect_error(
    predict(fit, newdata = sim$data[1:3, ], se.fit = TRUE),
    class = "gllvmTMB_predict_se_newdata_unsupported"
  )

  fit_no_se <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + latent(0 + trait | site, d = 1),
    data = sim$data,
    control = gllvmTMBcontrol(se = FALSE)
  )
  expect_error(
    predict(fit_no_se, se.fit = TRUE),
    class = "gllvmTMB_predict_se_no_sdreport"
  )

  ## REML integrates b_fix into TMB's random vector (R/fit-multi.R), so it
  ## never appears in sd_report$par.fixed -- .gllvmTMB_predict_se_link()
  ## cannot align a b_fix covariance block for it. Must fail closed with a
  ## REML-specific message, not the generic stale-sd_report one.
  fit_reml <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data, REML = TRUE
  ))
  expect_error(
    predict(fit_reml, se.fit = TRUE),
    class = "gllvmTMB_predict_se_reml_unsupported"
  )
})

test_that("predict(se.fit = TRUE) matches an independent second route (summary()'s b_fix SE) on an intercept-only design", {
  ## With no fixed-effect interaction term, each row's X_fix is an exact
  ## one-hot vector on trait, so Var(eta_i) collapses exactly to that
  ## trait's own b_fix coefficient variance -- letting this be checked
  ## against `.gllvmTMB_b_fix_se()`, the pre-existing, independently coded
  ## accessor `summary.gllvmTMB_multi()` already uses in production (it
  ## goes through `summary(sd_report, "fixed")`, a different code path
  ## from the manual `cov.fixed[idx, idx]` extraction `se.fit` uses).
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 3, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.6, 0.4, -0.3), 3, 1),
    seed = 2025
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data
  )
  out <- predict(fit, se.fit = TRUE)
  se_bfix <- gllvmTMB:::.gllvmTMB_b_fix_se(fit)
  trait_idx <- apply(fit$X_fix, 1, function(r) which(r == 1))
  expect_equal(out$se.fit, se_bfix[trait_idx], tolerance = 1e-10)
})
