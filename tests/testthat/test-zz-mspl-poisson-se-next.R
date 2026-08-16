## Next Poisson LA-MSPL SE feasibility cells (not the #979 first cell).
## First cell: n=8, p=3, y=rep(0:3), q=1, zero fraction 0.25.
## These cells: sparse intercepts (high zeros) and ordinary q=2.
## Public se=TRUE still withholds sdreport(). Registry stays planned.
## Internal pin names Q_P and Q_0. Not exported. Not admitted.
##
## Named test-zz-* so it runs after test-va-all-family-light-fits.R.

.mspl_se_pois_first_cell_y <- function() {
  rep(0:3, length.out = 8L * 3L)
}

.mspl_se_pois_next_dat <- function(kind = c("sparse", "q2")) {
  kind <- match.arg(kind)
  n_site <- 8L
  n_trait <- 3L
  site <- factor(rep(seq_len(n_site), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site))
  ## Sparse intercepts: high zero fraction, not the first-cell 0:3 cycle.
  ## q=2: milder counts so a second factor can form; still not 0:3.
  y <- if (identical(kind, "sparse")) {
    c(
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1
    )
  } else {
    c(
      1,
      2,
      1,
      2,
      1,
      3,
      1,
      2,
      2,
      3,
      1,
      1,
      2,
      2,
      1,
      1,
      3,
      2,
      2,
      1,
      2,
      1,
      2,
      1
    )
  }
  data.frame(site = site, trait = trait, y = y)
}

.mspl_se_pois_next_fit <- function(kind = c("sparse", "q2")) {
  kind <- match.arg(kind)
  dat <- .mspl_se_pois_next_dat(kind)
  q <- if (identical(kind, "q2")) 2L else 1L
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)",
    q
  ))
  gllvmTMB(
    form,
    data = dat,
    family = stats::poisson(link = "log"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L,
      init_jitter = 0,
      se = TRUE,
      warn_runaway = FALSE
    )
  )
}

.mspl_se_pois_next_expect_withheld <- function(fit) {
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$mspl$registry_status, "planned")
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_match(fit$sdreport_error, "withheld")
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(
    standard_errors(fit),
    class = "gllvmTMB_mspl_inference_unsupported"
  )
}

.mspl_se_pois_next_expect_pin <- function(fit) {
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
  pin
}

test_that("next Poisson SE cells are not the #979 y=rep(0:3) recipe", {
  first_y <- .mspl_se_pois_first_cell_y()
  sparse <- .mspl_se_pois_next_dat("sparse")
  q2 <- .mspl_se_pois_next_dat("q2")
  expect_false(identical(sparse$y, first_y))
  expect_false(identical(q2$y, first_y))
  expect_gt(mean(sparse$y == 0), 0.5)
  expect_lt(mean(first_y == 0), 0.3)
  expect_lt(mean(q2$y == 0), 0.1)
})

test_that("sparse-intercept Poisson MSPL se=TRUE withholds and pins both tapes", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "poisson",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  expect_false(is.null(row))
  expect_identical(row$status, "planned")
  expect_false(identical(row$status, "admitted"))

  fit <- .mspl_se_pois_next_fit("sparse")
  expect_identical(fit$mspl$registry_cell, "poisson:log:ordinary:q1")
  .mspl_se_pois_next_expect_withheld(fit)
  pin <- .mspl_se_pois_next_expect_pin(fit)
  expect_false(isTRUE(all.equal(pin$penalised$nll, pin$penalty_off$nll)))
})

test_that("q=2 Poisson MSPL se=TRUE withholds and pins both tapes", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "poisson",
    link = "log",
    structure = "ordinary",
    q = 2L
  )
  expect_false(is.null(row))
  expect_identical(row$status, "planned")
  expect_false(identical(row$status, "admitted"))
  expect_match(row$notes, "not admitted")
  expect_match(row$notes, "not covered")

  fit <- .mspl_se_pois_next_fit("q2")
  expect_identical(fit$mspl$registry_cell, "poisson:log:ordinary:q2")
  .mspl_se_pois_next_expect_withheld(fit)
  pin <- .mspl_se_pois_next_expect_pin(fit)
  expect_false(isTRUE(all.equal(pin$penalised$nll, pin$penalty_off$nll)))
})

test_that("se=TRUE withhold honesty is not a public vcov on next cells", {
  expect_false(
    "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
  )
  ## One next-cell fit is enough: forming Q_P/Q_0 is not sdreport().
  fit <- .mspl_se_pois_next_fit("sparse")
  pin <- gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit)
  expect_true(isTRUE(pin$public_se_withheld))
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_match(fit$sdreport_error, "withheld")
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(
    standard_errors(fit),
    class = "gllvmTMB_mspl_inference_unsupported"
  )
})
