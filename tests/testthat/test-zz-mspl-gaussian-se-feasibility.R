## Gaussian-identity LA-MSPL SE feasibility pin (availability only).
## Public se=TRUE must still withhold sdreport(). The internal pin
## names Q_P and Q_0 separately. Not exported. Not calibrated.
## Identity only. Do not weaken these tests to go green.
##
## Named test-zz-* so it runs after test-va-all-family-light-fits.R.
## CI #979 failed twice on that file's delta_lognormal_log health gate
## (healthy_starts 2 < 3) only when these optimHess pins ran first.
## The VA suite is not this lane; do not edit it.
## Binomial SE tests are PROTECTED — do not edit them from this file.

.mspl_se_gauss_dat <- function() {
  set.seed(88082L)
  n_site <- 8L
  n_trait <- 3L
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- stats::rnorm(n_site)
  Lambda <- c(0.8, -0.55, 0.35)
  beta <- c(-0.4, 0.1, 0.5)
  psi <- c(0.55, 0.70, 0.40)
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * Lambda[as.integer(trait)]
  data.frame(
    site = site,
    trait = trait,
    y = eta + stats::rnorm(length(eta), sd = sqrt(psi[as.integer(trait)]))
  )
}

.mspl_se_gauss_fit <- function() {
  dat <- .mspl_se_gauss_dat()
  gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = TRUE),
    data = dat,
    family = stats::gaussian(link = "identity"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = TRUE, warn_runaway = FALSE
    )
  )
}

test_that("public se=TRUE still withholds sdreport on Gaussian-identity MSPL", {
  fit <- .mspl_se_gauss_fit()
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$mspl$family, "gaussian")
  expect_identical(fit$mspl$registry_status, "admitted")
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_false(isTRUE(fit$mspl$inference$calibrated))
  expect_match(fit$sdreport_error, "withheld")
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(standard_errors(fit), class = "gllvmTMB_mspl_inference_unsupported")
})

test_that("internal Gaussian-identity curvature pin names both tapes and is unexported", {
  expect_false(
    "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
  )
  fit <- .mspl_se_gauss_fit()
  ## Expected RED: .gllvmTMB_mspl_curvature_pin() is still fenced to
  ## Bernoulli logit and Poisson log. A 10-line sidecar cannot override
  ## that fence without editing R/mspl-curvature-pin.R (this file is
  ## the door, not a silent pass).
  pin <- gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit)
  expect_type(pin, "list")
  expect_identical(pin$family, "gaussian")
  expect_identical(pin$link, "identity")
  expect_true(isTRUE(pin$public_se_withheld))
  expect_identical(pin$penalised$tape, "Q_P")
  expect_identical(pin$penalised$estimator_id, 1L)
  expect_identical(pin$penalty_off$tape, "Q_0")
  expect_identical(pin$penalty_off$estimator_id, 2L)
  expect_true(isTRUE(pin$penalty_off$evaluated_not_optimised))
  expect_false(isTRUE(pin$penalised$repaired))
  expect_false(isTRUE(pin$penalty_off$repaired))
  expect_true(
    pin$penalised$status %in% c("available", "non_pd", "nonfinite", "error")
  )
  expect_true(
    pin$penalty_off$status %in% c("available", "non_pd", "nonfinite", "error")
  )
  ## Poison a silent Q_P / Q_0 swap.
  expect_false(identical(
    pin$penalised$estimator_id,
    pin$penalty_off$estimator_id
  ))
  expect_false(isTRUE(all.equal(pin$penalised$nll, pin$penalty_off$nll)))
})
