## Bernoulli-logit LA-MSPL SE feasibility pin (availability only).
## Public se=TRUE must still withhold sdreport(). The internal pin
## names Q_P and Q_0 separately. Paper reporting target = Q_0
## (Ranga 2026-08-16); Q_P is availability only. Not exported.
## Not calibrated.
## Logit only (D-135). Do not weaken the public withhold to go green.
##
## Named test-zz-* so it runs after test-va-all-family-light-fits.R.
## CI #979 failed twice on that file's delta_lognormal_log health gate
## (healthy_starts 2 < 3) only when these optimHess pins ran first.
## The VA suite is not this lane; do not edit it.
##
## Internal Q_P / Q_0 pins read R/mspl-curvature-pin.R and must
## skip_if that source is missing (R CMD check install tree).
## Bernoulli Q_0 non-PD is a recorded finding, not a crash
## and not a Hessian to repair.

withr::local_envvar(c(OMP_NUM_THREADS = "1"), .local_envir = teardown_env())

.mspl_se_bern_dat <- function() {
  set.seed(88081L)
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
  eta <- beta[as.integer(trait)] +
    z[as.integer(site)] * Lambda[as.integer(trait)]
  data.frame(
    site = site,
    trait = trait,
    y = stats::rbinom(length(eta), 1L, stats::plogis(eta))
  )
}

.mspl_se_bern_fit <- function() {
  withr::local_envvar(c(OMP_NUM_THREADS = "1"))
  dat <- .mspl_se_bern_dat()
  gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat,
    family = stats::binomial(link = "logit"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L,
      init_jitter = 0,
      se = TRUE,
      warn_runaway = FALSE
    )
  )
}

.mspl_se_pin_source_path <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "R", "mspl-curvature-pin.R"),
    testthat::test_path(
      "..",
      "..",
      "00_pkg_src",
      "gllvmTMB",
      "R",
      "mspl-curvature-pin.R"
    ),
    testthat::test_path(
      "..",
      "..",
      "..",
      "00_pkg_src",
      "gllvmTMB",
      "R",
      "mspl-curvature-pin.R"
    ),
    file.path("R", "mspl-curvature-pin.R"),
    file.path("..", "R", "mspl-curvature-pin.R"),
    file.path("..", "..", "R", "mspl-curvature-pin.R")
  )
  installed <- system.file(
    "..",
    "R",
    "mspl-curvature-pin.R",
    package = "gllvmTMB"
  )
  if (nzchar(installed)) {
    candidates <- c(installed, candidates)
  }
  candidates[file.exists(candidates)][1L]
}

.mspl_se_skip_if_pin_source_missing <- function() {
  path <- .mspl_se_pin_source_path()
  testthat::skip_if(
    is.na(path),
    "R/mspl-curvature-pin.R is not available in this test context (R CMD check)."
  )
  path
}

.mspl_se_skip_if_pin_missing <- function() {
  testthat::skip_if(
    !exists(
      ".gllvmTMB_mspl_curvature_pin",
      envir = asNamespace("gllvmTMB"),
      inherits = FALSE
    ),
    "internal MSPL curvature pin is not in the loaded namespace"
  )
}

test_that("public se=TRUE still withholds sdreport on Bernoulli-logit MSPL", {
  fit <- .mspl_se_bern_fit()
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
})

test_that("Bernoulli Q_P / Q_0 pin source names both tapes and never calls sdreport", {
  src_path <- .mspl_se_skip_if_pin_source_missing()
  src <- paste(readLines(src_path, warn = FALSE), collapse = "\n")
  expect_match(src, "tape = \"Q_P\"")
  expect_match(src, "tape = \"Q_0\"")
  expect_match(src, "unpenalized_tmb_obj")
  expect_match(src, "evaluated_not_optimised = TRUE")
  expect_match(src, "estimator_id = 1")
  expect_match(src, "estimator_id = 2")
  ## Comments may name TMB::sdreport() as the thing this pin is not.
  src_code <- gsub("(?m)^\\s*#.*$", "", src, perl = TRUE)
  expect_false(grepl("TMB::sdreport\\s*\\(", src_code))
  expect_false(grepl("calibrated\\s*=\\s*TRUE", src_code))
})

test_that("internal Bernoulli-logit curvature pin names both tapes and is unexported", {
  .mspl_se_skip_if_pin_source_missing()
  .mspl_se_skip_if_pin_missing()
  expect_false(
    "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
  )
  fit <- .mspl_se_bern_fit()
  skip_if(
    is.null(fit$mspl$unpenalized_tmb_obj),
    "penalty-off Q_0 tape is not available on this fit"
  )
  pin <- expect_no_error(gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit))
  expect_type(pin, "list")
  expect_identical(pin$family, "binomial")
  expect_identical(pin$link, "logit")
  expect_true(isTRUE(pin$public_se_withheld))
  expect_identical(pin$paper_reporting_target, "Q_0")
  expect_identical(pin$penalised$tape, "Q_P")
  expect_identical(pin$penalised$role, "availability_only")
  expect_false(isTRUE(pin$penalised$paper_reporting_target))
  expect_identical(pin$penalised$estimator_id, 1L)
  expect_identical(pin$penalty_off$tape, "Q_0")
  expect_identical(pin$penalty_off$role, "paper_reporting_target")
  expect_true(isTRUE(pin$penalty_off$paper_reporting_target))
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
  ## Availability is not calibration. Public SEs still do not exist.
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$calibrated))
})

test_that("Bernoulli-logit Q_0 non-PD is a recorded finding, not a crash", {
  .mspl_se_skip_if_pin_source_missing()
  .mspl_se_skip_if_pin_missing()
  fit <- .mspl_se_bern_fit()
  skip_if(
    is.null(fit$mspl$unpenalized_tmb_obj),
    "penalty-off Q_0 tape is not available on this fit"
  )
  pin <- expect_no_error(gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit))
  ## Finding (SE-pin cell, 2026-08-15): penalty-off curvature can fail
  ## while Q_P looks usable. Do not repair. Do not skip. Do not treat
  ## this as a missing public SE.
  expect_identical(pin$penalty_off$status, "non_pd")
  expect_true(is.finite(pin$penalty_off$minimum_eigenvalue))
  expect_lt(pin$penalty_off$minimum_eigenvalue, 0)
  expect_false(isTRUE(pin$penalty_off$repaired))
  expect_false(isTRUE(pin$penalty_off$hessian_pd))
  expect_false(isTRUE(pin$penalty_off$se_finite))
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_false(isTRUE(fit$mspl$inference$calibrated))
})
