## #1982: single-trial binomial fits map every `s_B` row off (`diag_B_skip`),
## so `predict(newdata)` must not reshape an empty `s_B` slice into an all-NA
## matrix. Training-row `report$eta` and in-sample `predict()` stay finite.

.skip_predict_binomial_spatial_1982 <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("fmesher")
}

.binomial_single_trial_spatial_fit_1982 <- function() {
  set.seed(1127)
  sim <- simulate_site_trait(
    n_sites = 24, n_species = 1, n_traits = 2,
    mean_species_per_site = 1, n_predictors = 0,
    alpha = rep(0, 2), beta = matrix(0, 2, 0),
    sigma2_eps = 0.1, spatial_range = 0.25, sigma2_spa = rep(0.3, 2),
    seed = 1127
  )
  df <- sim$data
  df$value <- stats::rbinom(nrow(df), 1, stats::plogis(df$value))
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.08, extend = 0.15)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      spatial_latent(0 + trait | coords, d = 1) +
      latent(0 + trait | site, d = 1),
    data = df, mesh = mesh, unit = "site", family = binomial(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE, n_init = 2L)
  ))
  list(fit = fit, df = df)
}

test_that("#1982 spatial single-trial binomial: predict(newdata=training) matches in-sample link scale", {
  .skip_predict_binomial_spatial_1982()
  fx <- .binomial_single_trial_spatial_fit_1982()
  fit <- fx$fit
  df <- fx$df
  testthat::expect_true(isTRUE(fit$fit_health$converged))
  testthat::expect_true(isTRUE(all(fit$tmb_data$diag_B_skip == 1L)))

  pr_in <- predict(fit, type = "link")
  pr_new <- suppressMessages(predict(fit, newdata = df, type = "link"))
  testthat::expect_equal(sum(is.na(pr_in$est)), 0L)
  testthat::expect_equal(sum(is.na(pr_new$est)), 0L)
  testthat::expect_equal(pr_new$est, pr_in$est, tolerance = 1e-8)
  testthat::expect_equal(
    max(abs(as.numeric(pr_new$est) - fit$report$eta)),
    0,
    tolerance = 1e-8
  )
})

test_that("#1982 non-spatial single-trial binomial: predict(newdata=training) matches in-sample", {
  testthat::skip_on_cran()
  set.seed(2711)
  sim <- simulate_site_trait(
    n_sites = 20, n_species = 1, n_traits = 2,
    mean_species_per_site = 1, n_predictors = 0,
    seed = 2711
  )
  df <- sim$data
  df$value <- stats::rbinom(nrow(df), 1, stats::plogis(df$value))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = df, unit = "site", family = binomial(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))
  testthat::expect_true(isTRUE(all(fit$tmb_data$diag_B_skip == 1L)))
  pr_in <- predict(fit, type = "link")$est
  pr_new <- suppressMessages(predict(fit, newdata = df, type = "link"))$est
  testthat::expect_false(anyNA(pr_new))
  testthat::expect_equal(pr_new, pr_in, tolerance = 1e-8)
})