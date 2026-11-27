## Coverage pins for global ranks 16–18 R files (cursor/1127cov-gllvmTMB-w7).
## Tests only — fast contract paths, no package source edits.

# ---- R/column-coef-foundation.R (rank 16) ----------------------------------

test_that(".find_call_named() collects nested calls by name", {
  expr <- quote(y ~ latent(1 | u) + column_coef(1 + x | trait))
  found <- gllvmTMB:::.find_call_named(expr[[3L]], "column_coef")
  expect_length(found, 1L)
  expect_equal(as.character(found[[1L]][[1L]]), "column_coef")
  expect_length(gllvmTMB:::.find_call_named(expr[[3L]], "missing_fn"), 0L)
})

test_that(".column_coef_parse_basis() enforces intercept and predictor contracts", {
  row_vars <- c("x", "z")
  col_vars <- c("trait")
  resp <- "value"
  parsed <- gllvmTMB:::.column_coef_parse_basis(
    quote(1 + x), row_vars, col_vars, resp
  )
  expect_true(parsed$intercept)
  expect_equal(parsed$predictors, "x")
  expect_equal(parsed$basis, c("(Intercept)", "x"))
  expect_error(
    gllvmTMB:::.column_coef_parse_basis(quote(x), row_vars, col_vars, resp),
    regexp = "intercept explicitly"
  )
  expect_error(
    gllvmTMB:::.column_coef_parse_basis(
      quote(1 + trait), row_vars, col_vars, resp
    ),
    regexp = "metadata cannot be a coefficient basis"
  )
})

test_that(".column_coef_assert_additive_placement() rejects nested helpers", {
  bad <- quote(log(column_coef(1 + x | trait)))
  expect_error(
    gllvmTMB:::.column_coef_assert_additive_placement(bad),
    regexp = "top-level additive"
  )
  good <- quote(1 + column_coef(1 + x | trait))
  expect_invisible(gllvmTMB:::.column_coef_assert_additive_placement(good))
})

test_that(".column_coef_engine_fence() names spatial_coef as not yet admitted", {
  spec <- list(helper = "spatial_coef")
  expect_error(
    gllvmTMB:::.column_coef_engine_fence(spec),
    class = "gllvmTMB_column_coef_engine_not_admitted"
  )
})

# ---- R/mspl.R (rank 17) ----------------------------------------------------

test_that(".gllvmTMB_is_mspl() detects class and estimator label", {
  mspl <- structure(list(estimator = "mspl"), class = "gllvmTMB_mspl")
  expect_true(gllvmTMB:::.gllvmTMB_is_mspl(mspl))
  expect_true(gllvmTMB:::.gllvmTMB_is_mspl(list(estimator = "MSPL")))
  expect_false(gllvmTMB:::.gllvmTMB_is_mspl(list(estimator = "ml")))
})

test_that(".gllvmTMB_mspl_jeffreys_atom_ok() accepts certified atom codes only", {
  expect_true(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(0L))
  expect_true(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(1L))
  expect_false(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(10L))
  expect_false(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(NA_integer_))
})

test_that(".gllvmTMB_mspl_beta_jeffreys_weight() is positive at eta = 0", {
  w <- gllvmTMB:::.gllvmTMB_mspl_beta_jeffreys_weight(0, phi = 2)
  expect_length(w, 1L)
  expect_true(is.finite(w) && w > 0)
  w_vec <- gllvmTMB:::.gllvmTMB_mspl_beta_jeffreys_weight(c(0, 1), phi = 2)
  expect_length(w_vec, 2L)
  expect_true(all(w_vec > 0))
})

test_that(".gllvmTMB_mspl_assert_inference() aborts on MSPL fits", {
  fit <- structure(list(estimator = "mspl"), class = "gllvmTMB_mspl")
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_assert_inference(fit, "vcov"),
    class = "gllvmTMB_mspl_inference_unsupported"
  )
  expect_invisible(
    gllvmTMB:::.gllvmTMB_mspl_assert_inference(list(estimator = "ml"), "vcov")
  )
})

test_that(".gllvmTMB_mspl_tau_representatives() resolves maps and identity", {
  expect_equal(gllvmTMB:::.gllvmTMB_mspl_tau_representatives(log(c(1, 2))), 0:1)
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_tau_representatives(log(1:3), tau_map = c(1L, 1L, 2L)),
    c(0L, 2L)
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_tau_representatives(log(1:2), tau_map = 1L),
    class = "gllvmTMB_mspl_internal_map"
  )
})

test_that(".gllvmTMB_mspl_spde_r0() returns centroid RMS from mesh loc_xy", {
  mesh <- list(loc_xy = matrix(c(0, 0, 1, 0, 0, 1), ncol = 2L, byrow = TRUE))
  r0 <- gllvmTMB:::.gllvmTMB_mspl_spde_r0(mesh)
  expect_type(r0, "double")
  expect_gt(r0, 0)
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_spde_r0(list(loc_xy = matrix(c(0, 0), 1, 2))),
    regexp = "two distinct"
  )
})

test_that(".gllvmTMB_mspl_profile_threshold_diagnostic() projects probe fields", {
  probe <- list(
    objective_source = "fit$tmb_obj (penalised LA-MSPL)",
    target_index = 1L,
    target_name = "b1",
    mle = 0.1,
    threshold = 3.84,
    centre_status = "ok",
    lower_status = "ok",
    upper_status = "ok",
    lower_endpoint = -0.2,
    upper_endpoint = 0.4,
    lower_bracket = c(-0.3, 0),
    upper_bracket = c(0, 0.5),
    objective = "penalised",
    tape = "Q_P",
    nuisance_treatment = "fixed",
    reference_is_maximum = TRUE,
    design_125_fork = "A",
    trace = data.frame(step = integer())
  )
  out <- gllvmTMB:::.gllvmTMB_mspl_profile_threshold_diagnostic(probe)
  expect_false(out$calibrated)
  expect_equal(out$public_confint, "refused")
  expect_equal(out$diagnostic_lower, -0.2)
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_profile_threshold_diagnostic(list(foo = 1)),
    class = "gllvmTMB_mspl_profile_threshold_input"
  )
})

# ---- R/va-intervals.R (rank 18) --------------------------------------------

test_that(".va_r3_infer_T_from_theta_rr() inverts packed length for known T, q", {
  T <- 4L
  q <- 2L
  len <- gllvmTMB:::.va_r3_theta_length(T, q)
  expect_equal(gllvmTMB:::.va_r3_infer_T_from_theta_rr(len, q), T)
  expect_error(
    gllvmTMB:::.va_r3_infer_T_from_theta_rr(len + 1L, q),
    regexp = "integer T"
  )
})

test_that(".va_bootstrap_ceiling() reports arithmetic coverage cap", {
  cap <- gllvmTMB:::.va_bootstrap_ceiling(n_boot = 50L, conf = 0.95)
  expect_equal(cap, (50 - 1) / (51))
  expect_warning(
    gllvmTMB:::.va_bootstrap_ceiling(n_boot = 5L, conf = 0.95),
    regexp = "cannot deliver"
  )
})

test_that(".va_bootstrap_beta_ci() rejects non-probability level values", {
  expect_error(
    gllvmTMB:::.va_bootstrap_beta_ci(list(), level = -0.1),
    regexp = "level"
  )
})