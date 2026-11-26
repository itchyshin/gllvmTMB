## Regression coverage for #1900: stats::model.frame / terms / model.matrix on fits.

.gllvm_1900_fit <- function() {
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

test_that("#1900: model.frame(fit) matches manual formula + data", {
  fit <- .gllvm_1900_fit()
  ref <- stats::model.frame(fit$formula, data = fit$data)
  out <- stats::model.frame(fit)
  expect_s3_class(out, "data.frame")
  expect_equal(out, ref)
  expect_equal(nrow(out), 84L)
})

test_that("#1900: terms(fit) and model.matrix(fit) match the training frame", {
  fit <- .gllvm_1900_fit()
  mf <- stats::model.frame(fit$formula, data = fit$data)
  expect_equal(stats::terms(fit), stats::terms(mf))
  expect_equal(
    stats::model.matrix(fit),
    stats::model.matrix(stats::terms(mf), mf)
  )
})