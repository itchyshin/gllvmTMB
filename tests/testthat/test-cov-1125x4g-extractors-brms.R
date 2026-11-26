## Coverage (cursor-cloud-1125x4g): extractors, brms sugar, fixed-prior routes.

.cov1125x4g_gauss <- function() {
  set.seed(112546)
  n <- 12L
  df <- data.frame(
    unit = factor(rep(seq_len(n / 2L), each = 2L)),
    trait = factor(rep(c("a", "b"), n / 2L)),
    value = stats::rnorm(n)
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    unit = "unit",
    trait = "trait",
    family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE),
    silent = TRUE
  )))
}

test_that("extract_latent_scores() validates level", {
  fit <- .cov1125x4g_gauss()
  expect_error(extract_latent_scores(fit, level = "cluster"), "should be one of")
  u <- extract_latent_scores(fit, level = "unit")
  expect_equal(nrow(u), nlevels(fit$data[[fit$unit_col]]))
})

test_that("extract_repeatability() refuses without a suitable fit", {
  fit <- structure(list(), class = "lm")
  expect_error(extract_repeatability(fit), "gllvmTMB")
})

test_that("extract_repeatability() needs sd_report on ordinary fits", {
  fit <- .cov1125x4g_gauss()
  expect_error(extract_repeatability(fit), "standard errors")
})

test_that(".repeatability_bootstrap_bound() validates bootstrap columns", {
  expect_error(
    gllvmTMB:::.repeatability_bootstrap_bound(list(R = "x"), c("a", "b"), "R"),
    "numeric"
  )
})

test_that(".gllvmTMB_fixed_prior_route() refuses VA integration", {
  pri <- data.frame(coefficient = "a", mean = 0, sd = 1)
  expect_error(
    gllvmTMB:::.gllvmTMB_fixed_prior_route(
      pri, engine = "tmb", estimator = "ml", REML = FALSE,
      control = gllvmTMBcontrol(integration = "va")
    ),
    class = "gllvmTMB_fixed_prior_unsupported"
  )
})

test_that(".gllvmTMB_fixed_prior_inference() blocks unflagged intervals", {
  obj <- list(
    fixed_effect_priors = data.frame(coefficient = "a", mean = 0, sd = 1)
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_fixed_prior_inference(obj, "confint"),
    class = "gllvmTMB_fixed_prior_inference_unsupported"
  )
  expect_invisible(
    gllvmTMB:::.gllvmTMB_fixed_prior_inference(obj, "confint", prior_curvature = TRUE)
  )
})

test_that(".gllvmTMB_rewrite_scalar_internally() returns input unchanged", {
  f <- quote(value ~ 1 + scalar(1 | unit))
  out <- gllvmTMB:::.gllvmTMB_rewrite_scalar_internally(f)
  expect_identical(out, f)
  expect_true(inherits(out, "call"))
})

test_that(".gllvmTMB_set_spatial_token_consumed() records spatial grouping", {
  state <- getNamespace("gllvmTMB")$.gllvmTMB_spatial_token_consumed
  previous <- state$token
  withr::defer(state$token <- previous)
  spec <- list(source = "spatial", grouping = "site")
  expect_invisible(gllvmTMB:::.gllvmTMB_set_spatial_token_consumed(spec))
  expect_equal(state$token, "site")
})

test_that("desugar_brms_sugar() accepts latent() without altering core call", {
  f <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  )
  expect_s3_class(f, "formula")
  expect_match(deparse(f[[2]]), "value")
})

test_that("gllvmTMB:::.gllvmTMB_mspl_family_link_name() covers student identity", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_family_link_name(9L, 0L),
    "identity"
  )
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_family_link_name(5L, 0L),
    "log"
  )
})

test_that(".gllvmTMB_exact_pair_woodbury_data() rejects non-PSD kernels", {
  bad_k <- matrix(c(1, 0.9, 0.9, 1), 2)
  out <- gllvmTMB:::.gllvmTMB_exact_pair_woodbury_data(
    list(diag(2), bad_k),
    unit_id = c(0L, 1L),
    trait_id = c(0L, 0L),
    n_traits = 1L,
    loading_ranks = c(1L, 1L)
  )
  expect_equal(out$enabled, 0L)
})

test_that(".cv_score() scores gaussian held-out rows", {
  joined <- data.frame(
    trait = rep(c("a", "b"), each = 3L),
    family_id = 0L,
    est = c(0.1, 0.2, 0.3, -0.2, -0.1, 0),
    y_true = c(0, 0.1, 0.2, 0, 0.1, 0.2),
    n_trials = 1L
  )
  sc <- gllvmTMB:::.cv_score(joined)
  expect_type(sc, "list")
  expect_s3_class(sc$by_trait, "data.frame")
  expect_gt(nrow(sc$by_trait), 0L)
  expect_true("C.RMSE" %in% names(sc$by_trait))
})

test_that(".cv_score() aborts on missing columns", {
  expect_error(gllvmTMB:::.cv_score(data.frame(x = 1)), "missing required column")
})