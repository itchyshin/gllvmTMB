fit_health_contract_fixture <- function(
  gradient = 0,
  convergence = 0L,
  objective = 1,
  penalised_objective = NULL,
  pd_hessian = TRUE,
  boundary_flags = character()
) {
  par <- c(theta = 0)
  structure(list(
    opt = list(
      convergence = convergence,
      objective = objective,
      par = par,
      iterations = 10L,
      message = ""
    ),
    tmb_obj = list(
      par = par,
      gr = function(p) setNames(rep(gradient, length(p)), names(p))
    ),
    sd_report = list(pdHess = pd_hessian),
    objective_components = if (is.null(penalised_objective)) NULL else
      list(optimization_nll = penalised_objective),
    aghq = list(ridge_tau = Inf),
    report = list(),
    use = list(),
    mock_boundary_flags = boundary_flags,
    X_fix_names = character()
  ), class = c("gllvmTMB_multi", "gllvmTMB"))
}

test_that("fit health uses the selected penalised objective and relative score", {
  testthat::local_mocked_bindings(
    .gllvmTMB_boundary_flags = function(object, ...) object$mock_boundary_flags,
    .package = "gllvmTMB"
  )
  fit <- fit_health_contract_fixture(
    gradient = 5, objective = 1, penalised_objective = 100
  )

  health <- gllvmTMB:::.gllvmTMB_build_fit_health(fit)

  expect_equal(health$objective, 100)
  expect_equal(health$relative_gradient, 5 / 100)
  expect_false(health$stationary_by_relative_gradient)
  expect_identical(health$convergence_status, "not_converged")
})

test_that("fit health distinguishes boundary, degenerate, and converged fits", {
  testthat::local_mocked_bindings(
    .gllvmTMB_boundary_flags = function(object, ...) object$mock_boundary_flags,
    .package = "gllvmTMB"
  )

  boundary <- gllvmTMB:::.gllvmTMB_build_fit_health(
    fit_health_contract_fixture(boundary_flags = "near_zero_sd_B")
  )
  degenerate <- gllvmTMB:::.gllvmTMB_build_fit_health(
    fit_health_contract_fixture(pd_hessian = FALSE)
  )
  not_converged <- gllvmTMB:::.gllvmTMB_build_fit_health(
    fit_health_contract_fixture(convergence = 1L)
  )
  converged <- gllvmTMB:::.gllvmTMB_build_fit_health(
    fit_health_contract_fixture()
  )

  expect_identical(boundary$convergence_status, "boundary")
  expect_identical(degenerate$convergence_status, "degenerate")
  expect_identical(not_converged$convergence_status, "not_converged")
  expect_identical(converged$convergence_status, "converged")
  expect_true(converged$converged)
  expect_false(boundary$converged)
  expect_false(degenerate$converged)
})

test_that("prior curvature records parameters held by a singular likelihood", {
  par <- c(b_fix = 0, theta = 0)
  base_fn <- function(p) 0.5 * p[[2L]]^2
  base_gr <- function(p) c(b_fix = 0, theta = p[[2L]])
  base_he <- function(p) diag(c(0, 1))
  obj <- list(par = par, fn = base_fn, gr = base_gr, he = base_he)
  prior <- gllvmTMB:::.gllvmTMB_resolve_fixed_priors(
    data.frame(coefficient = "b", mean = 0, sd = 1), "b"
  )
  penalised_obj <- gllvmTMB:::.gllvmTMB_attach_fixed_priors(obj, prior)

  curvature <- gllvmTMB:::.gllvmTMB_unpenalised_curvature(
    penalised_obj, par, penalised_pd_hessian = TRUE
  )

  expect_false(curvature$pd_hessian_unpenalised)
  expect_identical(curvature$prior_held_params, "b_fix")
})

test_that("fit records objective provenance and uncertainty type", {
  testthat::local_mocked_bindings(
    .gllvmTMB_boundary_flags = function(object, ...) object$mock_boundary_flags,
    .package = "gllvmTMB"
  )
  fit <- fit_health_contract_fixture(penalised_objective = 4)
  fit$fixed_effect_priors <- list(specification = data.frame())
  fit$objective_components <- list(
    likelihood_nll = 3,
    fixed_effect_prior_nll = 1,
    kernel_psi_sd_prior_nll = 0,
    ridge_penalty = 0,
    optimization_nll = 4
  )
  fit$tmb_obj$fixed_effect_priors <- list(
    likelihood_fn = function(p) 3,
    likelihood_gr = function(p) c(theta = 0),
    likelihood_he = function(p) matrix(0, 1, 1)
  )

  out <- gllvmTMB:::.gllvmTMB_record_fit_convergence(fit)

  expect_true(out$penalised)
  expect_equal(out$objective, -4)
  expect_equal(out$logLik, -3)
  expect_equal(out$log_prior, -1)
  expect_equal(out$objective, out$logLik + out$log_prior)
  expect_identical(out$se_type, "penalised")
  expect_false(out$pd_hessian_unpenalised)
  expect_identical(out$prior_held_params, "theta")
  expect_identical(out$convergence_status, "converged")
  expect_true(isTRUE(out$fit_health$penalised))
})

test_that("no-prior fits retain the legacy output shape", {
  testthat::local_mocked_bindings(
    .gllvmTMB_boundary_flags = function(object, ...) character(),
    .package = "gllvmTMB"
  )
  fit <- fit_health_contract_fixture(objective = 7)
  out <- gllvmTMB:::.gllvmTMB_record_fit_convergence(fit)

  # Keep the exact `objective` name reserved for penalised fits: on ordinary
  # fits it partially matches the historical `objective_components` field.
  # The optimizer's ordinary ML objective remains available unchanged.
  expect_false("objective" %in% names(out))
  expect_identical(out$opt$objective, 7)
  prior_only_fields <- c("penalised", "logLik", "log_prior", "se_type",
    "pd_hessian_unpenalised", "prior_held_params", "unpenalised_curvature_method")
  expect_false(any(prior_only_fields %in% names(out)))
  expect_false("penalised" %in% names(out$fit_health))
  expect_false("pd_hessian_unpenalised" %in% names(out$fit_health))
  expect_false("prior_held_params" %in% names(out$fit_health))
  expect_identical(out$convergence_status, "converged")
})

test_that("anova refuses fixed-effect-prior LRTs", {
  fit <- structure(list(
    estimator = "ML",
    aghq = list(used = FALSE, penalised = FALSE, ridge_tau = Inf),
    fixed_effect_priors = list(specification = data.frame()),
    likelihood_weights = list(active = FALSE)
  ), class = c("gllvmTMB_multi", "gllvmTMB"))

  expect_error(
    gllvmTMB:::.gllvmTMB_anova_global_check(list(fit, fit)),
    class = "gllvmTMB_anova_not_comparable"
  )
  expect_warning(
    gllvmTMB:::.aghq_check_penalised(list(fit), "AIC"),
    "ordinary likelihood-based interpretation is unsupported"
  )
})

test_that("variance_lrt refuses a penalised logLik object before losing its metadata", {
  ll <- structure(-10, class = "logLik", penalised = TRUE)
  expect_error(
    variance_lrt(ll, -12),
    class = "gllvmTMB_variance_lrt_penalised_unsupported"
  )
})

test_that("exact-zero observation SD remains fail-closed for table priors", {
  expect_error(
    gllvmTMB:::.gllvmTMB_guard_exact_zero_priors(
      list(prior_table = data.frame(class = "unique_variance")), 0
    ),
    class = "gllvmTMB_exact_gaussian_prior_unsupported"
  )
  ## The historical AGHQ ridge default is not an explicitly requested penalty.
  expect_invisible(gllvmTMB:::.gllvmTMB_guard_exact_zero_priors(
    list(aghq_ridge = 2, aghq_ridge_explicit = FALSE), 0
  ))
  expect_invisible(gllvmTMB:::.gllvmTMB_guard_exact_zero_priors(
    list(prior_table = NULL, fixed_effect_priors = NULL), 0.1
  ))
})
