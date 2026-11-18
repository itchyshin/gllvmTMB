## Rest-family LA-MSPL SE feasibility pins (availability only).
## Gamma, lognormal, Student-t, ordinal_probit, delta-lognormal, delta-Gamma.
## Registry may be planned or absent (na). Not admitted. Not binomial.
## Public se=TRUE must still withhold sdreport(). Internal pin names
## Q_P and Q_0 separately. Not exported. Not calibrated.
##
## skip_if the public MSPL family door is missing (prepare still rejects).
## skip_if the internal curvature pin is still fenced from these families.
##
## Named test-zz-* so it runs after test-va-all-family-light-fits.R.
## See the Bernoulli twin file for the CI #979 ordering note.

.mspl_rest_form <- y ~ 0 +
  trait +
  latent(0 + trait | site, d = 1, unique = FALSE)

.mspl_rest_grid <- function(y) {
  n_site <- 8L
  n_trait <- 3L
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = y
  )
}

.mspl_rest_cases <- function() {
  n <- 24L
  list(
    Gamma = list(
      family_name = "Gamma",
      link = "log",
      builder = function() stats::Gamma(link = "log"),
      y = rep(c(0.5, 1, 2), length.out = n)
    ),
    lognormal = list(
      family_name = "lognormal",
      link = "log",
      builder = function() lognormal(),
      y = rep(c(0.5, 1, 2), length.out = n)
    ),
    student = list(
      family_name = "student",
      link = "identity",
      builder = function() student(df = 5),
      y = rep(c(-0.5, 0, 0.8), length.out = n)
    ),
    ordinal_probit = list(
      family_name = "ordinal_probit",
      link = "probit",
      builder = function() ordinal_probit(),
      y = factor(rep(1:3, length.out = n), ordered = TRUE)
    ),
    delta_lognormal = list(
      family_name = "delta_lognormal",
      link = "logit",
      builder = function() delta_lognormal(),
      y = rep(c(0, 0.5, 1.5), length.out = n)
    ),
    delta_gamma = list(
      family_name = "delta_gamma",
      link = "logit",
      builder = function() delta_gamma(),
      y = rep(c(0, 0.5, 1.5), length.out = n)
    )
  )
}

.mspl_rest_stub <- function(case) {
  fam <- tryCatch(
    suppressMessages(case$builder()),
    error = function(e) {
      structure(
        list(family = case$family_name, link = case$link),
        class = "family"
      )
    }
  )
  if (isTRUE(fam$delta) || length(fam$family) > 1L) {
    fam <- structure(
      list(family = case$family_name, link = case$link),
      class = "family"
    )
  }
  structure(
    list(
      family = fam,
      estimator = "mspl",
      sd_report = NULL,
      tmb_obj = NULL,
      opt = list(par = 0),
      mspl = list(
        family = case$family_name,
        unpenalized_tmb_obj = NULL
      )
    ),
    class = c("gllvmTMB_mspl", "gllvmTMB")
  )
}

.mspl_rest_try_fit <- function(case) {
  fam <- tryCatch(suppressMessages(case$builder()), error = function(e) e)
  testthat::skip_if(
    inherits(fam, "error"),
    paste(case$family_name, "family constructor is not available")
  )
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      .mspl_rest_form,
      data = .mspl_rest_grid(case$y),
      family = fam,
      estimator = "mspl",
      control = gllvmTMBcontrol(
        n_init = 1L,
        init_jitter = 0,
        se = TRUE,
        warn_runaway = FALSE
      )
    ))),
    error = function(e) e
  )
  testthat::skip_if(
    inherits(fit, "error"),
    paste(case$family_name, "MSPL family door is missing")
  )
  fit
}

.mspl_rest_expect_pin <- function(pin, case) {
  expect_type(pin, "list")
  expect_identical(pin$family, case$family_name)
  expect_identical(pin$link, case$link)
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
}

test_that("rest-family MSPL registry stays planned or na, never admitted", {
  cases <- .mspl_rest_cases()
  for (case in cases) {
    row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
      family = case$family_name,
      link = case$link,
      structure = "ordinary",
      q = 1L
    )
    expect_true(
      is.null(row) || row$status %in% c("planned", "na"),
      info = paste(case$family_name, "registry must be planned or na")
    )
    expect_false(
      isTRUE(row$status == "admitted"),
      info = paste(case$family_name, "must not be admitted")
    )
  }
  reg <- gllvmTMB:::.gllvmTMB_mspl_registry()
  rest_names <- vapply(cases, `[[`, character(1L), "family_name")
  expect_false(any(reg$family %in% rest_names & reg$status == "admitted"))
})

test_that("internal curvature pin is unexported and not fenced from rest families", {
  expect_false(
    "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
  )
  for (case in .mspl_rest_cases()) {
    stub <- .mspl_rest_stub(case)
    pin_err <- tryCatch(
      gllvmTMB:::.gllvmTMB_mspl_curvature_pin(stub),
      error = function(e) e
    )
    testthat::skip_if(
      inherits(pin_err, "gllvmTMB_mspl_curvature_family"),
      paste(
        "internal curvature pin is still fenced from",
        case$family_name
      )
    )
    ## Missing tapes is the expected stub outcome once the family is allowed.
    expect_s3_class(pin_err, "gllvmTMB_mspl_curvature_tape")
  }
})

.mspl_rest_register_door_tests <- function(case) {
  test_that(
    paste(
      "public se=TRUE still withholds on",
      case$family_name,
      "MSPL when the door exists"
    ),
    {
      fit <- .mspl_rest_try_fit(case)
      expect_s3_class(fit, "gllvmTMB_mspl")
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
      expect_false(identical(fit$mspl$registry_status, "admitted"))
    }
  )

  test_that(
    paste(
      "internal",
      case$family_name,
      "curvature pin names both tapes when the door exists"
    ),
    {
      expect_false(
        "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
      )
      fit <- .mspl_rest_try_fit(case)
      pin <- gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit)
      .mspl_rest_expect_pin(pin, case)
      expect_false(isTRUE(all.equal(pin$penalised$nll, pin$penalty_off$nll)))
    }
  )
}

for (case in .mspl_rest_cases()) {
  local({
    .mspl_rest_register_door_tests(case)
  })
}
