## confint() interval routes (#1588): b_fix[k] labels, the Wald Sigma advisory
## on a latent() tier, and a Sigma tier the fit does not have.

make_fit_1588 <- function() {
  set.seed(1)
  sim <- gllvmTMB::simulate_unit_trait(
    n_units = 50,
    n_obs_per_unit = 2,
    n_traits = 4,
    Lambda_B = matrix(c(0.9, 0.8, -0.7, 0.5)),
    psi_B = 0.2,
    sigma2_eps = 0.3
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = TRUE),
    data = sim$data,
    trait = "trait",
    unit = "unit"
  )))
}

test_that("confint(parm = 'b_fix[k]') returns one row for profile and Wald (#1588)", {
  skip_on_cran()
  fit <- make_fit_1588()

  ci_prof <- suppressWarnings(confint(fit, parm = "b_fix[1]"))
  expect_equal(nrow(ci_prof), 1L)
  expect_equal(rownames(ci_prof), "b_fix[1]")
  expect_true(all(is.finite(ci_prof)))

  ci_wald <- confint(fit, parm = "b_fix[2]", method = "wald")
  expect_equal(nrow(ci_wald), 1L)
  expect_equal(rownames(ci_wald), "b_fix[2]")
  expect_true(all(is.finite(ci_wald)))

  ## Two labels give two rows.
  ci_two <- suppressWarnings(confint(fit, parm = c("b_fix[3]", "b_fix[1]")))
  expect_setequal(rownames(ci_two), c("b_fix[3]", "b_fix[1]"))
})

test_that("confint() profiles only the requested fixed effects (#1588)", {
  skip_on_cran()
  fit <- make_fit_1588()
  n_calls <- 0L
  testthat::local_mocked_bindings(
    tmbprofile_wrapper = function(fit, name = NULL, which = 1L, ...) {
      n_calls <<- n_calls + 1L
      c(estimate = 0, lower = -1, upper = 1)
    }
  )

  ## a term name used to profile all four fixed effects, then keep one
  ci_term <- confint(fit, parm = "traittrait_1")
  expect_equal(n_calls, 1L)
  expect_equal(nrow(ci_term), 1L)
  expect_equal(rownames(ci_term), "traittrait_1")

  n_calls <- 0L
  ci_lab <- confint(fit, parm = "b_fix[1]")
  expect_equal(n_calls, 1L)
  expect_equal(nrow(ci_lab), 1L)

  ## no parm: every fixed effect is still profiled
  n_calls <- 0L
  ci_all <- confint(fit, parm = 1:4)
  expect_equal(n_calls, 4L)
  expect_equal(nrow(ci_all), 4L)
})

test_that("Wald Sigma on a latent() tier explains the NA intervals (#1588)", {
  skip_on_cran()
  fit <- make_fit_1588()
  expect_message(
    out <- confint(fit, parm = "Sigma_unit", method = "wald"),
    "bootstrap"
  )
  expect_message(
    confint(fit, parm = "Sigma_unit", method = "wald"),
    "profile_ci_total_variance"
  )
  expect_true(all(is.na(out$lower)))
})

test_that("confint() on a tier the fit lacks names the public tier (#1588)", {
  skip_on_cran()
  fit <- make_fit_1588()

  err <- expect_error(
    confint(fit, parm = "Sigma_unit_obs", method = "wald"),
    "unit_obs"
  )
  expect_no_match(conditionMessage(err), "\"W\"")

  err_prof <- expect_error(confint(fit, parm = "Sigma_unit_obs"), "unit_obs")
  expect_no_match(conditionMessage(err_prof), "\"W\"")

  ## the bootstrap route must fail before it warns about n_boot
  warned <- character()
  err_boot <- withCallingHandlers(
    expect_error(
      confint(fit, parm = "Sigma_unit_obs", method = "bootstrap", nsim = 50),
      "unit_obs"
    ),
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warned, 0L)
  expect_no_match(conditionMessage(err_boot), "Available")
})
