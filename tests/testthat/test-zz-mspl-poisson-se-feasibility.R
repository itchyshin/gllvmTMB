## Poisson LA-MSPL SE feasibility pin (availability only).
## Public se=TRUE must still withhold sdreport(). Registry is admitted
## (experimental point) after G0 2026-08-16. Internal pin names Q_P and
## Q_0 separately. Paper reporting target = Q_0 (Ranga 2026-08-16);
## Q_P is availability only. Live Poisson W=diag(mu) remains a
## one-sided red flag (softness audit) — pin ≠ atom clearance.
## Not exported. Not covered. No public vcov.
##
## Named test-zz-* so it runs after test-va-all-family-light-fits.R.
## See the Bernoulli twin file for the CI #979 ordering note.
##
## Internal Q_P / Q_0 pins read R/mspl-curvature-pin.R and must
## skip_if that source is missing (R CMD check install tree).
## Q_0 non-PD is a recorded finding, not a crash and not a Hessian
## to repair. Do not flip planned -> admitted.

withr::local_envvar(c(OMP_NUM_THREADS = "1"), .local_envir = teardown_env())

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
  withr::local_envvar(c(OMP_NUM_THREADS = "1"))
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

.mspl_se_pois_pin_source_path <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "R", "mspl-curvature-pin.R"),
    testthat::test_path(
      "..", "..", "00_pkg_src", "gllvmTMB", "R", "mspl-curvature-pin.R"
    ),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "R", "mspl-curvature-pin.R"
    ),
    file.path("R", "mspl-curvature-pin.R"),
    file.path("..", "R", "mspl-curvature-pin.R"),
    file.path("..", "..", "R", "mspl-curvature-pin.R")
  )
  installed <- system.file("..", "R", "mspl-curvature-pin.R", package = "gllvmTMB")
  if (nzchar(installed)) {
    candidates <- c(installed, candidates)
  }
  candidates[file.exists(candidates)][1L]
}

.mspl_se_pois_skip_if_pin_source_missing <- function() {
  path <- .mspl_se_pois_pin_source_path()
  testthat::skip_if(
    is.na(path),
    "R/mspl-curvature-pin.R is not available in this test context (R CMD check)."
  )
  path
}

.mspl_se_pois_skip_if_pin_missing <- function() {
  testthat::skip_if(
    !exists(
      ".gllvmTMB_mspl_curvature_pin",
      envir = asNamespace("gllvmTMB"),
      inherits = FALSE
    ),
    "internal MSPL curvature pin is not in the loaded namespace"
  )
}

test_that("Poisson MSPL registry is admitted while se=TRUE is withheld", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "poisson",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  expect_false(is.null(row))
  expect_identical(row$status, "admitted")
  expect_identical(row$evidence, "admit_packet")
  expect_false(identical(row$evidence, "covered"))
  expect_match(row$notes, "not a covered campaign")
  expect_match(row$notes, "no public SE")

  fit <- .mspl_se_pois_fit()
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$mspl$registry_status, "admitted")
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_false(isTRUE(fit$mspl$inference$calibrated))
  expect_match(fit$sdreport_error, "withheld")
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(standard_errors(fit), class = "gllvmTMB_mspl_inference_unsupported")
})

test_that("Poisson Q_P / Q_0 pin source names both tapes and never calls sdreport", {
  src_path <- .mspl_se_pois_skip_if_pin_source_missing()
  src <- paste(readLines(src_path, warn = FALSE), collapse = "\n")
  expect_match(src, "tape = \"Q_P\"")
  expect_match(src, "tape = \"Q_0\"")
  expect_match(src, "unpenalized_tmb_obj")
  expect_match(src, "evaluated_not_optimised = TRUE")
  expect_match(src, "estimator_id = 1")
  expect_match(src, "estimator_id = 2")
  expect_match(src, "not TMB::sdreport")
  src_code <- paste(
    grep("^\\s*#", strsplit(src, "\n", fixed = TRUE)[[1L]], invert = TRUE, value = TRUE),
    collapse = "\n"
  )
  expect_false(grepl("TMB::sdreport\\s*\\(", src_code))
  expect_false(grepl("calibrated\\s*=\\s*TRUE", src_code))
})

test_that("internal Poisson curvature pin names both tapes and stays unexported", {
  .mspl_se_pois_skip_if_pin_source_missing()
  .mspl_se_pois_skip_if_pin_missing()
  expect_false(
    "gllvmTMB_mspl_curvature_pin" %in% getNamespaceExports("gllvmTMB")
  )
  fit <- .mspl_se_pois_fit()
  skip_if(
    is.null(fit$mspl$unpenalized_tmb_obj),
    "penalty-off Q_0 tape is not available on this fit"
  )
  pin <- expect_no_error(gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit))
  expect_type(pin, "list")
  expect_identical(pin$family, "poisson")
  expect_identical(pin$link, "log")
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
  expect_false(identical(
    pin$penalised$estimator_id,
    pin$penalty_off$estimator_id
  ))
  expect_false(isTRUE(all.equal(pin$penalised$nll, pin$penalty_off$nll)))
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$calibrated))
  expect_identical(fit$mspl$registry_status, "admitted")
})

test_that("Poisson Q_0 non-PD is a recorded finding, not a crash", {
  .mspl_se_pois_skip_if_pin_source_missing()
  .mspl_se_pois_skip_if_pin_missing()
  fit <- .mspl_se_pois_fit()
  skip_if(
    is.null(fit$mspl$unpenalized_tmb_obj),
    "penalty-off Q_0 tape is not available on this fit"
  )
  pin <- expect_no_error(gllvmTMB:::.gllvmTMB_mspl_curvature_pin(fit))
  ## First Poisson cell was available; non-PD must still be typed and
  ## unrepaired if it appears. Do not require PD. Do not admit.
  expect_true(
    pin$penalty_off$status %in% c("available", "non_pd", "nonfinite", "error")
  )
  expect_false(isTRUE(pin$penalty_off$repaired))
  if (identical(pin$penalty_off$status, "non_pd")) {
    expect_true(is.finite(pin$penalty_off$minimum_eigenvalue))
    expect_lte(pin$penalty_off$minimum_eigenvalue, 0)
    expect_false(isTRUE(pin$penalty_off$hessian_pd))
    expect_false(isTRUE(pin$penalty_off$se_finite))
  }
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_false(isTRUE(fit$mspl$inference$calibrated))
  expect_identical(fit$mspl$registry_status, "admitted")
})
