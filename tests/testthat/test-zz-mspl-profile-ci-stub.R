## Fenced LA-MSPL profile-CI scaffold (D-157 new construction).
## Public confint() must still refuse. Helpers are unexported.
## Named test-zz-* so it runs after the VA light-fit suite.
##
## Toy cell: Gaussian identity, se=FALSE, ordinary latent q=1.
## Do not run Totoro. Do not reopen Design 118. Do not admit.

withr::local_envvar(c(OMP_NUM_THREADS = "1"), .local_envir = teardown_env())

.mspl_profile_stub_src_path <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "R", "mspl-profile-ci-stub.R"),
    testthat::test_path(
      "..", "..", "00_pkg_src", "gllvmTMB", "R", "mspl-profile-ci-stub.R"
    ),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "R", "mspl-profile-ci-stub.R"
    ),
    file.path("R", "mspl-profile-ci-stub.R"),
    file.path("..", "R", "mspl-profile-ci-stub.R")
  )
  installed <- system.file("..", "R", "mspl-profile-ci-stub.R", package = "gllvmTMB")
  if (nzchar(installed)) {
    candidates <- c(installed, candidates)
  }
  candidates[file.exists(candidates)][1L]
}

.mspl_profile_stub_skip_if_source_missing <- function() {
  path <- .mspl_profile_stub_src_path()
  testthat::skip_if(
    is.na(path),
    "R/mspl-profile-ci-stub.R is not available in this test context (R CMD check)."
  )
  path
}

.mspl_profile_stub_skip_if_missing <- function() {
  testthat::skip_if(
    !exists(
      ".gllvmTMB_mspl_profile_ci_scaffold",
      envir = asNamespace("gllvmTMB"),
      inherits = FALSE
    ),
    "internal MSPL profile-CI scaffold is not in the loaded namespace"
  )
}

.mspl_profile_stub_gauss_dat <- function() {
  n_site <- 8L
  n_trait <- 3L
  set.seed(170817L)
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = as.numeric(rep(c(-0.4, 0.1, 0.6), n_site) + rnorm(n_site * n_trait, sd = 0.35))
  )
}

.mspl_profile_stub_gauss_fit <- function() {
  withr::local_envvar(c(OMP_NUM_THREADS = "1"))
  dat <- .mspl_profile_stub_gauss_dat()
  gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = TRUE),
    data = dat,
    family = stats::gaussian(link = "identity"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  )
}

test_that("profile-CI stub source is fenced and never calls sdreport or confint", {
  src_path <- .mspl_profile_stub_skip_if_source_missing()
  src <- paste(readLines(src_path, warn = FALSE), collapse = "\n")
  expect_match(src, "role = \"signature\"")
  expect_match(src, "role = \"quickest_baseline\"")
  expect_match(src, "role = \"asymmetry\"")
  expect_match(src, "tape = \"Q_0\"")
  expect_match(src, "public_confint = \"refused\"")
  expect_match(src, "design_118 = \"parked\"")
  expect_match(src, "2026-08-17-mspl-ci-wald-plus-profile.md")
  src_code <- paste(
    grep("^\\s*#", strsplit(src, "\n", fixed = TRUE)[[1L]], invert = TRUE, value = TRUE),
    collapse = "\n"
  )
  expect_false(grepl("TMB::sdreport\\s*\\(", src_code))
  expect_false(grepl("confint\\s*\\(", src_code))
  expect_false(grepl("calibrated\\s*=\\s*TRUE", src_code))
  expect_false(grepl("@export", src))
})

test_that("public confint.R does not call the MSPL profile-CI stub", {
  confint_path <- testthat::test_path("..", "..", "R", "z-confint-gllvmTMB.R")
  skip_if_not(file.exists(confint_path), "z-confint-gllvmTMB.R not in this tree")
  src <- paste(readLines(confint_path, warn = FALSE), collapse = "\n")
  expect_false(grepl("mspl_profile_ci_scaffold", src))
  expect_false(grepl("mspl_ci_triad", src))
  expect_match(src, "gllvmTMB_mspl_assert_inference\\(object, \"confint\"\\)")
})

test_that("MSPL profile-CI triad helpers stay unexported", {
  .mspl_profile_stub_skip_if_source_missing()
  .mspl_profile_stub_skip_if_missing()
  exports <- getNamespaceExports("gllvmTMB")
  expect_false("gllvmTMB_mspl_profile_ci_scaffold" %in% exports)
  expect_false(".gllvmTMB_mspl_profile_ci_scaffold" %in% exports)
  expect_false("gllvmTMB_mspl_ci_triad" %in% exports)
  triad <- gllvmTMB:::.gllvmTMB_mspl_ci_triad()
  expect_identical(triad$profile$role, "signature")
  expect_identical(triad$wald_q0$role, "quickest_baseline")
  expect_identical(triad$wald_q0$tape, "Q_0")
  expect_identical(triad$bootstrap$role, "asymmetry")
  expect_identical(triad$design_118, "parked")
  expect_false(isTRUE(triad$profile$public))
})

test_that("toy Gaussian MSPL se=FALSE point still refuses public confint", {
  skip_on_cran()
  .mspl_profile_stub_skip_if_source_missing()
  .mspl_profile_stub_skip_if_missing()
  fit <- .mspl_profile_stub_gauss_fit()
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_null(fit$sd_report)
  expect_false(isTRUE(fit$mspl$inference$available))
  expect_false(isTRUE(fit$mspl$inference$calibrated))
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit, method = "profile"),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit, method = "wald"),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(standard_errors(fit), class = "gllvmTMB_mspl_inference_unsupported")

  scaf <- expect_no_error(
    gllvmTMB:::.gllvmTMB_mspl_profile_ci_scaffold(fit, run_wald_q0 = FALSE)
  )
  expect_identical(scaf$public_confint, "refused")
  expect_identical(scaf$family, "gaussian")
  expect_identical(scaf$link, "identity")
  expect_true(isTRUE(scaf$se_false_point))
  expect_identical(scaf$profile$role, "signature")
  expect_identical(scaf$profile$status, "not_constructed")
  expect_identical(scaf$wald_q0$role, "quickest_baseline")
  expect_identical(scaf$wald_q0$tape, "Q_0")
  expect_identical(scaf$wald_q0$status, "not_run")
  expect_false(isTRUE(scaf$wald_q0$public_interval))
  expect_identical(scaf$bootstrap$role, "asymmetry")
  expect_identical(scaf$bootstrap$status, "not_constructed")
  expect_identical(scaf$triad$design_118, "parked")
})

test_that("profile-CI scaffold refuses a non-toy family", {
  .mspl_profile_stub_skip_if_source_missing()
  .mspl_profile_stub_skip_if_missing()
  fake <- structure(
    list(
      estimator = "mspl",
      family = stats::binomial(link = "logit"),
      mspl = list(family = "binomial"),
      sd_report = NULL
    ),
    class = c("gllvmTMB_mspl", "gllvmTMB_multi")
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_profile_ci_scaffold(fake),
    class = "gllvmTMB_mspl_profile_ci_family"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_profile_ci_scaffold(list(estimator = "ml")),
    class = "gllvmTMB_mspl_profile_ci_input"
  )
})
