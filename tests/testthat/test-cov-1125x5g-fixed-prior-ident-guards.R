## Coverage (cursor-cloud-1125x5g): fixed-effect prior internals and check_identifiability guards.

test_that(".gllvmTMB_fixed_prior_route() refuses non-laplace engines", {
  pri <- data.frame(coefficient = "a", mean = 0, sd = 1)
  expect_error(
    gllvmTMB:::.gllvmTMB_fixed_prior_route(
      pri, engine = "julia", estimator = "ml", REML = FALSE,
      control = list(integration = "laplace")
    ),
    class = "gllvmTMB_fixed_prior_unsupported"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_fixed_prior_route(
      pri, engine = "tmb", estimator = "mspl", REML = FALSE,
      control = list(integration = "laplace")
    ),
    class = "gllvmTMB_fixed_prior_unsupported"
  )
  expect_null(
    gllvmTMB:::.gllvmTMB_fixed_prior_route(
      NULL, "tmb", "ml", FALSE, list(integration = "laplace")
    )
  )
})

test_that(".gllvmTMB_resolve_fixed_priors() validates the prior table", {
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_fixed_priors(
      list(coefficient = "a"), c("a")
    ),
    "data.frame"
  )
  tab <- data.frame(coefficient = c("a", "b"), mean = c(0, 0), sd = c(1, 1))
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_fixed_priors(tab, "a"),
    "distinct"
  )
  tab2 <- data.frame(coefficient = "a", mean = 0, sd = -1)
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_fixed_priors(tab2, "a"),
    "positive"
  )
  ok <- gllvmTMB:::.gllvmTMB_resolve_fixed_priors(
    data.frame(coefficient = "a", mean = 0.2, sd = 1.5),
    c("a", "b")
  )
  expect_equal(ok$index, 1L)
  expect_equal(attr(ok, "n_coefficients"), 2L)
})

test_that(".gllvmTMB_fixed_prior_inference() blocks non-prior-curvature callers", {
  obj <- list(fixed_effect_priors = data.frame())
  expect_error(
    gllvmTMB:::.gllvmTMB_fixed_prior_inference(obj, "confint", prior_curvature = FALSE),
    class = "gllvmTMB_fixed_prior_inference_unsupported"
  )
  expect_null(
    gllvmTMB:::.gllvmTMB_fixed_prior_inference(
      list(), "coef", prior_curvature = FALSE
    )
  )
})

test_that("check_identifiability() validates inputs before heavy work", {
  expect_error(check_identifiability(list()), "gllvmTMB")
  fit <- structure(
    list(
      class = "gllvmTMB_multi",
      tmb_data = list(family_id_vec = 1L)
    ),
    class = "gllvmTMB_multi"
  )
  expect_error(
    check_identifiability(fit, sim_reps = 1L),
    "sim_reps"
  )
  expect_error(
    check_identifiability(fit, sim_reps = 5L, alpha = 1.5),
    "alpha"
  )
  expect_error(
    check_identifiability(fit, sim_reps = 5L),
    class = "gllvmTMB_check_identifiability_nongaussian"
  )
})

test_that("fixed_effect_priors() attaches calibration metadata on success", {
  tab <- fixed_effect_priors(
    "logit",
    intercepts = c("traita", "traitb"),
    slopes = "traita:x",
    standardized = TRUE,
    intercept_scale = 1.5,
    slope_scale = 1,
    additional_variance = 0.25
  )
  expect_equal(nrow(tab), 3L)
  cal <- attr(tab, "calibration")
  expect_equal(cal$link, "logit")
  expect_equal(cal$continuous_predictor_sd, 0.5)
  expect_gt(tab$sd[1L], tab$sd[3L])
})

test_that(".valid_family and .valid_link enums align with engine ids", {
  fam <- getFromNamespace(".valid_family", "gllvmTMB")
  lnk <- getFromNamespace(".valid_link", "gllvmTMB")
  expect_equal(fam[["poisson"]], 2L)
  expect_equal(fam[["censored_poisson"]], 21L)
  expect_length(fam, 22L)
  expect_equal(unname(lnk), 0:2)
  expect_named(lnk, c("logit", "probit", "cloglog"))
})