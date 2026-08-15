## Poisson LA-MSPL SE feasibility pin (availability only).
## Public se=TRUE must still withhold sdreport(). Registry stays planned.
## Internal pin names Q_P and Q_0 separately. Not exported. Not admitted.

.mspl_se_pois_dat <- function() {
  n_site <- 8L
  n_trait <- 3L
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = rep(0:3, length.out = n_site * n_trait)
  )
}

.mspl_se_pois_fit <- function() {
  dat <- .mspl_se_pois_dat()
  gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat,
    family = stats::poisson(),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = TRUE, warn_runaway = FALSE
    )
  )
}

test_that("Poisson MSPL registry stays planned while se=TRUE is withheld", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "poisson",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  expect_false(is.null(row))
  expect_identical(row$status, "planned")
  expect_false(identical(row$status, "admitted"))
  expect_match(row$notes, "not admitted")
  expect_match(row$notes, "not covered")

  fit <- .mspl_se_pois_fit()
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$mspl$registry_status, "planned")
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_match(fit$sdreport_error, "withheld")
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(standard_errors(fit), class = "gllvmTMB_mspl_inference_unsupported")
})

test_that("internal Poisson curvature pin names both tapes and stays unexported", {
  expect_false(
    "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
  )
  fit <- .mspl_se_pois_fit()
  pin <- gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit)
  expect_type(pin, "list")
  expect_identical(pin$family, "poisson")
  expect_identical(pin$link, "log")
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
  expect_false(identical(
    pin$penalised$estimator_id,
    pin$penalty_off$estimator_id
  ))
  expect_false(isTRUE(all.equal(pin$penalised$nll, pin$penalty_off$nll)))
})
