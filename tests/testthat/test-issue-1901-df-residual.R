## Regression coverage for #1901: df.residual() on gllvmTMB_multi Laplace fits.

.gllvm_1901_fit <- function() {
  skip_if_not_installed("TMB")
  set.seed(1126L)
  d <- simulate_site_trait(
    n_sites = 28,
    n_species = 1,
    n_traits = 3,
    mean_species_per_site = 1,
    n_predictors = 1,
    seed = 1126L
  )$data
  ctrl <- gllvmTMBcontrol(loading_ridge = Inf)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + env_1 + indep(1 | site),
    data = d,
    unit = "site",
    family = gaussian(),
    control = ctrl
  )))
  expect_identical(fit$opt$convergence, 0L)
  fit
}

test_that("#1901: df.residual(fit) is nobs(fit) - attr(logLik(fit), 'df')", {
  fit <- .gllvm_1901_fit()
  ll <- stats::logLik(fit)
  dfr <- stats::df.residual(fit)
  expect_type(dfr, "double")
  expect_length(dfr, 1L)
  expect_false(is.na(dfr))
  expect_equal(dfr, stats::nobs(fit) - attr(ll, "df"))
  expect_true(is.finite(stats::deviance(fit)))
})