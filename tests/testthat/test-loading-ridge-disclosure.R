test_that("loading ridge applies only to the ordinary B loading block", {
  expect_true(.gllvmTMB_loading_ridge_applies(2, c("b_fix", "theta_rr_B")))
  expect_false(.gllvmTMB_loading_ridge_applies(2, c("b_fix", "theta_rr_W")))
  expect_false(.gllvmTMB_loading_ridge_applies(2, c("b_fix", "theta_rr_phy")))
  expect_false(.gllvmTMB_loading_ridge_applies(2, c("b_fix", "theta_diag_B")))
  expect_false(.gllvmTMB_loading_ridge_applies(Inf, "theta_rr_B"))
  expect_false(.gllvmTMB_loading_ridge_applies(NULL, "theta_rr_B"))
})

test_that("penalised likelihood surfaces disclose MAP semantics every time", {
  fit <- structure(list(
    opt = list(objective = 12, par = c(b_fix = 0)),
    objective_components = list(
      likelihood_nll = 11.5,
      ridge_penalty = 0.5,
      optimization_nll = 12,
      optimizer_reported = 12
    ),
    REML = FALSE,
    estimator = "ML",
    aghq = list(used = FALSE, penalised = TRUE, ridge_tau = 2),
    likelihood_weights = list(active = FALSE),
    tmb_data = list(y = 1:3, is_y_observed = rep(1L, 3L)),
    X_fix_names = "b_fix"
  ), class = c("gllvmTMB_multi", "gllvmTMB"))

  expect_warning(ll <- logLik(fit), "MAP point")
  expect_equal(as.numeric(ll), -11.5)
  expect_true(isTRUE(attr(ll, "penalised")))
  expect_warning(logLik(fit), "MAP point")
  expect_warning(.aghq_check_penalised(list(fit), "AIC"), "not AIC")
  expect_warning(.aghq_check_penalised(list(fit), "AIC"), "not AIC")
})

test_that("Laplace ridge stores likelihood and optimisation objectives separately", {
  set.seed(848L)
  dat <- expand.grid(
    trait = factor(paste0("t", 1:3)),
    unit = factor(paste0("u", 1:20))
  )
  latent_score <- rnorm(20)
  loadings <- c(0.5, -0.35, 0.2)
  dat$value <- rep(latent_score, each = 3) * rep(loadings, times = 20) +
    rnorm(nrow(dat), sd = 0.5)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = dat,
    unit = "unit",
    control = gllvmTMBcontrol(aghq_ridge = 2),
    silent = TRUE
  )))

  expect_true(isTRUE(fit$aghq$penalised))
  expect_gt(fit$objective_components$ridge_penalty, 0)
  expect_equal(
    fit$objective_components$optimization_nll,
    fit$objective_components$likelihood_nll +
      fit$objective_components$ridge_penalty,
    tolerance = 1e-12
  )
  expect_equal(
    fit$opt$objective,
    fit$objective_components$optimization_nll,
    tolerance = 1e-8
  )
  expect_warning(ll <- logLik(fit), "MAP point")
  expect_equal(
    as.numeric(ll),
    -fit$objective_components$likelihood_nll,
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(
    as.numeric(ll), -fit$objective_components$optimization_nll,
    tolerance = 1e-12
  )))
})
