## nbinom1 and nbinom2 LA-MSPL SE feasibility pins (availability only).
## Public se=TRUE must still withhold sdreport(). Not exported. Not
## admitted. Not binomial. Not public vcov.
##
## Registry may still be planned, excluded, or deferred — never admitted.
## Do not require an admitted row to go green. Live fits skip_if the
## public nbinom door is still closed (gllvmTMB_mspl_unsupported).
##
## Named test-zz-* so it runs after test-va-all-family-light-fits.R.
## See the Bernoulli twin file for the CI #979 ordering note.

.mspl_se_nb_dat <- function() {
  n_site <- 8L
  n_trait <- 3L
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = rep(0:3, length.out = n_site * n_trait)
  )
}

.mspl_se_nb_family <- function(which = c("nbinom1", "nbinom2")) {
  which <- match.arg(which)
  if (identical(which, "nbinom1")) nbinom1() else nbinom2()
}

.mspl_se_nb_fit <- function(which = c("nbinom1", "nbinom2")) {
  which <- match.arg(which)
  dat <- .mspl_se_nb_dat()
  gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat,
    family = .mspl_se_nb_family(which),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = TRUE, warn_runaway = FALSE
    )
  )
}

.mspl_se_nb_try_fit <- function(which = c("nbinom1", "nbinom2")) {
  which <- match.arg(which)
  fit <- tryCatch(
    suppressMessages(suppressWarnings(.mspl_se_nb_fit(which))),
    error = function(e) e
  )
  testthat::skip_if(
    inherits(fit, "gllvmTMB_mspl_unsupported"),
    paste(which, "MSPL family door is missing")
  )
  if (inherits(fit, "error")) {
    stop(fit)
  }
  fit
}

## Exact cell_id lookup misses excluded rows that carry a suffix
## (nbinom2:log:ordinary:q1:nbinom2). Scan the table instead.
.mspl_se_nb_registry_rows <- function(which = c("nbinom1", "nbinom2")) {
  which <- match.arg(which)
  tbl <- gllvmTMB:::.gllvmTMB_mspl_registry()
  tbl[tbl$family == which, , drop = FALSE]
}

.mspl_se_nb_assert_not_admitted <- function(which) {
  rows <- .mspl_se_nb_registry_rows(which)
  expect_false(
    any(rows$status == "admitted"),
    info = paste(which, "must not be an admitted MSPL family")
  )
  if (nrow(rows)) {
    expect_true(
      all(rows$status %in% c("planned", "excluded", "deferred")),
      info = paste(
        which, "registry may be planned, excluded, or deferred; got",
        paste(unique(rows$status), collapse = ",")
      )
    )
  }
}

.mspl_se_nb_assert_public_withheld <- function(fit, which) {
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_false(identical(fit$mspl$family, "binomial"))
  expect_identical(fit$mspl$family, which)
  expect_false(identical(fit$mspl$registry_status, "admitted"))
  if (!is.null(fit$mspl$registry_status)) {
    expect_true(
      fit$mspl$registry_status %in% c("planned", "excluded", "deferred")
    )
  }
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_false(isTRUE(fit$mspl$inference$calibrated))
  expect_match(fit$sdreport_error, "withheld")
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(standard_errors(fit), class = "gllvmTMB_mspl_inference_unsupported")
}

.mspl_se_nb_assert_curvature_pin <- function(fit, which) {
  expect_false(
    "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
  )
  pin <- gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit)
  expect_type(pin, "list")
  expect_identical(pin$family, which)
  expect_identical(pin$link, "log")
  expect_false(identical(pin$family, "binomial"))
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

test_that("nbinom1 MSPL registry is not admitted (planned or deferred allowed)", {
  .mspl_se_nb_assert_not_admitted("nbinom1")
})

test_that("nbinom2 MSPL registry is not admitted (planned or deferred allowed)", {
  .mspl_se_nb_assert_not_admitted("nbinom2")
})

test_that("public se=TRUE still withholds sdreport on nbinom1 MSPL", {
  fit <- .mspl_se_nb_try_fit("nbinom1")
  .mspl_se_nb_assert_public_withheld(fit, "nbinom1")
})

test_that("public se=TRUE still withholds sdreport on nbinom2 MSPL", {
  fit <- .mspl_se_nb_try_fit("nbinom2")
  .mspl_se_nb_assert_public_withheld(fit, "nbinom2")
})

test_that("internal nbinom1 curvature pin names both tapes and is unexported", {
  fit <- .mspl_se_nb_try_fit("nbinom1")
  .mspl_se_nb_assert_curvature_pin(fit, "nbinom1")
})

test_that("internal nbinom2 curvature pin names both tapes and is unexported", {
  fit <- .mspl_se_nb_try_fit("nbinom2")
  .mspl_se_nb_assert_curvature_pin(fit, "nbinom2")
})
