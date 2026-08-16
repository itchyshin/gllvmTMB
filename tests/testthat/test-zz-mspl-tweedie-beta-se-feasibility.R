## Tweedie + Beta LA-MSPL SE feasibility pins (availability only).
## Public se=TRUE must still withhold sdreport(). Registry stays planned.
## Internal pin names Q_P and Q_0 separately. Not exported. Not admitted.
## Not binomial. Not public vcov. Do not weaken these tests to go green.
##
## Named test-zz-* so it runs after test-va-all-family-light-fits.R.
## See the Bernoulli twin file for the CI #979 ordering note.

.mspl_se_tb_grid <- function(y) {
  n_site <- 8L
  n_trait <- 3L
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = y
  )
}

.mspl_se_tweedie_dat <- function() {
  .mspl_se_tb_grid(rep(c(0.5, 1, 2), length.out = 24L))
}

.mspl_se_beta_dat <- function() {
  .mspl_se_tb_grid(rep(c(0.2, 0.5, 0.8), length.out = 24L))
}

.mspl_se_tb_fit <- function(dat, family) {
  gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat,
    family = family,
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L,
      init_jitter = 0,
      se = TRUE,
      warn_runaway = FALSE
    )
  )
}

.mspl_se_tweedie_fit <- function() {
  .mspl_se_tb_fit(.mspl_se_tweedie_dat(), tweedie())
}

.mspl_se_beta_fit <- function() {
  .mspl_se_tb_fit(.mspl_se_beta_dat(), Beta())
}

.mspl_se_tb_expect_planned_row <- function(row, family_name) {
  expect_false(is.null(row), info = family_name)
  if (is.null(row)) {
    return(invisible(FALSE))
  }
  expect_identical(row$status, "planned", info = family_name)
  expect_false(identical(row$status, "admitted"), info = family_name)
  expect_match(row$notes, "not admitted", info = family_name)
  expect_match(row$notes, "not covered", info = family_name)
  invisible(TRUE)
}

.mspl_se_tb_expect_public_withheld <- function(fit) {
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$mspl$registry_status, "planned")
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_false(isTRUE(fit$mspl$inference$calibrated))
  expect_match(fit$sdreport_error, "withheld")
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(
    standard_errors(fit),
    class = "gllvmTMB_mspl_inference_unsupported"
  )
}

.mspl_se_tb_expect_curvature_pin <- function(fit, family_name, link_name) {
  expect_false(
    "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
  )
  pin <- gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit)
  expect_type(pin, "list")
  expect_identical(pin$family, family_name)
  expect_identical(pin$link, link_name)
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
}

test_that("Tweedie MSPL registry stays planned while se=TRUE is withheld", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "tweedie",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  .mspl_se_tb_expect_planned_row(row, "tweedie")
  expect_no_error(fit <- .mspl_se_tweedie_fit())
  if (!exists("fit", inherits = FALSE)) {
    return(invisible())
  }
  .mspl_se_tb_expect_public_withheld(fit)
})

test_that("internal Tweedie curvature pin names both tapes and stays unexported", {
  expect_no_error(fit <- .mspl_se_tweedie_fit())
  if (!exists("fit", inherits = FALSE)) {
    return(invisible())
  }
  .mspl_se_tb_expect_curvature_pin(fit, "tweedie", "log")
})

test_that("Beta MSPL registry stays planned while se=TRUE is withheld", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "Beta",
    link = "logit",
    structure = "ordinary",
    q = 1L
  )
  .mspl_se_tb_expect_planned_row(row, "Beta")
  expect_no_error(fit <- .mspl_se_beta_fit())
  if (!exists("fit", inherits = FALSE)) {
    return(invisible())
  }
  .mspl_se_tb_expect_public_withheld(fit)
})

test_that("internal Beta curvature pin names both tapes and stays unexported", {
  expect_no_error(fit <- .mspl_se_beta_fit())
  if (!exists("fit", inherits = FALSE)) {
    return(invisible())
  }
  .mspl_se_tb_expect_curvature_pin(fit, "Beta", "logit")
})
