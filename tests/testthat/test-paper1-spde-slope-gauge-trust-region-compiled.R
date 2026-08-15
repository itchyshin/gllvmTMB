spde_slope_gauge_tr_compiled_env <- function() {
  root <- testthat::test_path("..", "..", "dev", "isdm-package-recovery")
  env <- new.env(parent = baseenv())
  for (name in c(
    "spde-slope-gauge-contract.R",
    "spde-slope-gauge-sign-contract.R",
    "spde-slope-gauge-trust-region-contract.R",
    "spde-slope-gauge-trust-region-adapter.R"
  )) {
    source(file.path(root, name), local = env)
  }
  env
}

test_that("compiled 22-coordinate fixture preserves the full sign orbit and callback receipt", {
  skip_if_not_installed("TMB")
  env <- spde_slope_gauge_tr_compiled_env()
  scratch <- tempfile("spde-slope-gauge-tr-compiled-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  cpp <- testthat::test_path("fixtures", "spde_slope_gauge_random.cpp")
  expect_true(file.copy(cpp, scratch))
  compiled <- file.path(scratch, basename(cpp))
  expect_equal(TMB::compile(compiled), 0L)
  dll <- TMB::dynlib(file.path(scratch, "spde_slope_gauge_random"))
  dyn.load(dll)
  on.exit({
    if (exists("object", inherits = FALSE)) rm(object)
    invisible(gc(verbose = FALSE))
    dyn.unload(dll)
  }, add = TRUE)

  raw_order <- env$spde_slope_gauge_raw_order()
  theta <- stats::setNames(c(
    seq(-0.12, 0.12, length.out = 12L), c(-0.18, 0.07, 0.13), 0.09,
    c(-0.21, 0.16, -0.11, 0.42, -0.17, 0.28)
  ), raw_order)
  expect_gt(theta[[20L]], 0)
  object <- TMB::MakeADFun(
    data = list(y = c(0.7, -0.3, 0.4)),
    parameters = list(
      b_fix = theta[1:12], theta_diag_B = theta[13:15], log_kappa = theta[[16L]],
      theta_rr_spde_slope = theta[17:22], s_B = 0,
      g_spde_slope = array(0, dim = c(3L, 1L, 2L))
    ),
    random = c("s_B", "g_spde_slope"), DLL = "spde_slope_gauge_random", silent = TRUE
  )
  object$par <- stats::setNames(as.double(object$par), raw_order)
  expect_length(object$par, 22L)
  expect_true(is.finite(object$fn(unname(theta))))

  full <- object$env$last.par
  expect_length(full, 29L)
  names(full) <- c(
    rep("b_fix", 12L), rep("theta_diag_B", 3L), "log_kappa",
    rep("theta_rr_spde_slope", 6L), "s_B", rep("g_spde_slope", 6L)
  )
  full[seq_len(22L)] <- unname(theta)
  random_indices <- as.integer(object$env$random)
  expect_true(all(random_indices > 0L))
  expect_identical(names(full)[random_indices], c("s_B", rep("g_spde_slope", 6L)))
  sign <- env$spde_slope_gauge_validate_sign_orbit(
    parameters = list(g_spde_slope = array(0, dim = c(3L, 1L, 2L))),
    random = c("s_B", "g_spde_slope"), full = full, random_indices = random_indices,
    theta = theta,
    conditional_hessian_fn = function(x) object$env$spHess(x, random = TRUE),
    report_fn = function(x) object$report(x),
    marginal_objective_fn = function(x) object$fn(x)
  )
  expect_true(sign$valid)
  expect_lte(sign$conditional_hessian_error, 1e-10)
  expect_lte(sign$predictor_error, 1e-10)
  expect_lte(sign$objective_error, 1e-10)

  adapter <- env$spde_slope_gauge_trust_region_callback_adapter(
    list(
      fn = function(x) object$fn(x),
      gr = function(x) unname(object$gr(x)),
      par = theta
    ),
    object_id = 1L,
    dll_path = normalizePath(dll, mustWork = TRUE),
    dll_md5 = unname(tools::md5sum(dll))[[1L]],
    sdreport_fn = function(...) stop("candidate covariance is outside this no-optimizer fixture")
  )
  phi0 <- env$spde_slope_gauge_phi_from_theta(theta)
  replay <- adapter$evaluate(phi0)
  audit <- adapter$audit()
  expect_equal(replay$raw_theta, theta, tolerance = 64 * .Machine$double.eps)
  expect_identical(names(replay$raw_gradient), raw_order)
  expect_length(audit$objective, 1L)
  expect_length(audit$gradient, 1L)
  expect_identical(audit$gradient[[1L]]$supplied_names, NULL)
  expect_identical(audit$gradient[[1L]]$named_gradient, replay$raw_gradient)
})
