## loading_profile() refits must be the fitted model with one loading held
## fixed (#1584): same unit_obs grouping, control (loading_ridge) and REML,
## with no spurious warnings or notices, and a clear warning when refits fail.

lp1584_data <- function() {
  set.seed(1)
  sim <- simulate_unit_trait(n_units = 100, n_obs_per_unit = 2, n_traits = 4,
                             Lambda_B = matrix(c(0.9, 0.7, 0.5, 0)),
                             sigma2_eps = 0.3)
  sim$data
}

lp1584_formula <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = TRUE)
lp1584_M <- matrix(c(NA, NA, NA, 0))

lp1584_warnings <- function(expr) {
  w <- character()
  value <- withCallingHandlers(
    expr,
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = w)
}

test_that("a unit_obs-tier profile refits with unit_obs and gives finite objectives (#1584)", {
  skip_on_cran()
  set.seed(1)
  sim2 <- simulate_unit_trait(n_units = 60, n_obs_per_unit = 3, n_traits = 4,
                              Lambda_W = matrix(c(0.9, 0.7, 0.5, 0)),
                              psi_B = 0.3, sigma2_eps = 0.3)
  fitW <- gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | unit) +
      latent(0 + trait | unit_observation, d = 1, unique = FALSE),
    data = sim2$data, trait = "trait", unit = "unit",
    unit_obs = "unit_observation", lambda_constraint = list(unit_obs = lp1584_M)
  )
  res <- lp1584_warnings(
    loading_profile(fitW, level = "unit_obs", entries = cbind(2, 1), n_grid = 3)
  )
  pf <- res$value
  expect_true(all(is.finite(pf$objective)))
  expect_identical(which.min(pf$objective), 2L)
  expect_equal(pf$objective[2], -as.numeric(logLik(fitW)), tolerance = 0.05)
  expect_length(res$warnings, 0L)
})

test_that("a ridged fit is profiled on its own penalised objective (#1584)", {
  skip_on_cran()
  dat <- lp1584_data()
  fitR <- gllvmTMB(lp1584_formula, data = dat, trait = "trait", unit = "unit",
                   lambda_constraint = list(unit = lp1584_M),
                   control = gllvmTMBcontrol(loading_ridge = 0.1))
  pf <- loading_profile(fitR, entries = cbind(2, 1), n_grid = 5)
  expect_true(all(is.finite(pf$objective)))
  ## The curve bottoms out at the fitted (penalised) loading, the grid centre.
  expect_identical(which.min(pf$objective), 3L)
  expect_equal(pf$objective[3], fitR$objective_components$optimization_nll,
               tolerance = 0.05)
})

test_that("a REML fit is profiled as REML, not ML (#1584)", {
  skip_on_cran()
  dat <- lp1584_data()
  fitML <- gllvmTMB(lp1584_formula, data = dat, trait = "trait", unit = "unit",
                    lambda_constraint = list(unit = lp1584_M))
  fitREML <- gllvmTMB(lp1584_formula, data = dat, trait = "trait", unit = "unit",
                      lambda_constraint = list(unit = lp1584_M), REML = TRUE)
  pf <- loading_profile(fitREML, entries = cbind(2, 1), n_grid = 3)
  expect_equal(pf$objective[2], -as.numeric(logLik(fitREML)), tolerance = 0.05)
  expect_gt(abs(-as.numeric(logLik(fitML)) - pf$objective[2]), 1)
})

test_that("a valid profile call gives no warnings or notices, and level = 'B' works (#1584)", {
  skip_on_cran()
  dat <- lp1584_data()
  fit <- gllvmTMB(lp1584_formula, data = dat, trait = "trait", unit = "unit",
                  lambda_constraint = list(unit = lp1584_M))
  ## The refit notices are one-shot per session; make sure they could fire.
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  msgs <- character()
  res <- lp1584_warnings(withCallingHandlers(
    loading_profile(fit, n_grid = 3),
    message = function(cnd) {
      msgs <<- c(msgs, conditionMessage(cnd))
      invokeRestart("muffleMessage")
    }
  ))
  expect_length(res$warnings, 0L)
  expect_length(msgs, 0L)
  expect_equal(nrow(res$value), 9L)

  ## Named entries (a data.frame) must not warn either.
  res2 <- lp1584_warnings(
    loading_profile(fit, entries = data.frame(i = 2, k = 1), n_grid = 3)
  )
  expect_length(res2$warnings, 0L)

  ## Legacy level "B": one deprecation warning, same curve as "unit".
  withr::local_options(gllvmTMB.warned_level_B = NULL)
  res3 <- lp1584_warnings(
    loading_profile(fit, level = "B", entries = cbind(2, 1), n_grid = 3)
  )
  expect_match(res3$warnings, "deprecated", all = FALSE)
  expect_equal(res3$value$objective, res2$value$objective)
})

test_that("failed refits are reported, not hidden behind an all-NA curve (#1584)", {
  skip_on_cran()
  dat <- lp1584_data()
  fit <- gllvmTMB(lp1584_formula, data = dat, trait = "trait", unit = "unit",
                  lambda_constraint = list(unit = lp1584_M))
  testthat::local_mocked_bindings(
    gllvmTMB = function(...) stop("refit blew up")
  )
  res <- lp1584_warnings(
    loading_profile(fit, entries = cbind(2, 1), n_grid = 3)
  )
  expect_true(all(is.na(res$value$objective)))
  expect_true(all(is.na(res$value$delta_deviance)))
  expect_match(res$warnings, "3 of 3 profile refits failed", all = FALSE)
  expect_match(res$warnings, "refit blew up", all = FALSE)
  expect_false(any(grepl("no non-missing arguments", res$warnings)))
})
