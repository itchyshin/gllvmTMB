test_that("loading ridge curvature adds only its exact free-loading diagonal", {
  A <- matrix(c(3, 0.4, 0.2, 0.4, 2, 0.1, 0.2, 0.1, 4), 3L)
  p <- setNames(c(0.2, -0.3, 0.7), c("b_fix", "theta_rr_B", "theta_rr_spde_lv"))
  obj <- list(par = p, env = list(random = NULL),
    fn = function(p) drop(crossprod(p, A %*% p)) / 2,
    gr = function(p) drop(A %*% p), he = function(p) A)
  H <- gllvmTMB:::.gllvmTMB_loading_ridge_hessian(obj, p, 2)
  expected <- A + diag(c(0, 1 / 4, 0))
  expect_equal(H, expected)
  numeric_reference <- stats::optimHess(p,
    function(p) obj$fn(p) + p[2L]^2 / 8,
    function(p) gllvmTMB:::.gllvmTMB_penalised_gradient(obj, p, 2))
  expect_equal(unname(H), unname(numeric_reference), tolerance = 1e-7)
  expect_null(gllvmTMB:::.gllvmTMB_loading_ridge_hessian(obj, p, Inf))
  expect_null(gllvmTMB:::.gllvmTMB_loading_ridge_hessian(obj, p, NULL))
})

test_that("random-effect curvature uses the marginal AD gradient convention", {
  A <- matrix(c(2, .3, .3, 1), 2L)
  p <- setNames(c(.2, -.4), c("theta_rr_B", "alpha_lv_B"))
  obj <- list(par = p, env = list(random = 3L),
    fn = function(p) drop(crossprod(p, A %*% p)) / 2,
    gr = function(p) drop(A %*% p),
    he = function(p) stop("random-effect Hessian unavailable"))
  H <- gllvmTMB:::.gllvmTMB_loading_ridge_hessian(obj, p, 2)
  expect_equal(unname(H), A + diag(c(.25, 0)), tolerance = 1e-7)
  expect_true(abs(solve(H)[1L, 2L]) > 0)
})

test_that("ridge sdreport propagates full MAP curvature and preserves unpenalised reporting", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(14672)
  n <- 60L
  x <- seq(-1, 1, length.out = n)
  z <- .6 * x + rnorm(n)
  data <- data.frame(unit = factor(rep(seq_len(n), each = 3L)),
    trait = factor(rep(c("a", "b", "c"), n)), x = rep(x, each = 3L))
  data$value <- rep(c(.1, -.1, .2), n) +
    rep(c(.8, -.5, .6), n) * rep(z, each = 3L) + rnorm(3L * n, sd = .2)
  formula <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~ x)
  fit <- suppressWarnings(gllvmTMB(formula, data = data, unit = "unit", trait = "trait",
    control = gllvmTMBcontrol(loading_ridge = 2)))
  meta <- fit$loading_ridge_curvature
  expect_identical(meta$parameter_vector, fit$opt$par)
  expect_identical(meta$loading_indices, which(names(fit$tmb_obj$par) == "theta_rr_B"))
  expect_false(meta$calibrated_sampling_covariance)
  H <- gllvmTMB:::.gllvmTMB_loading_ridge_hessian(fit$tmb_obj, fit$opt$par, 2)
  expect_equal(fit$sd_report$cov.fixed, solve(H), tolerance = 1e-8)
  expect_equal(fit$sd_report$gradient.fixed,
    gllvmTMB:::.gllvmTMB_penalised_gradient(fit$tmb_obj, fit$opt$par, 2))
  expect_equal(as.numeric(fit$sd_report$gradient.fixed.unpenalised),
    as.numeric(fit$tmb_obj$gr(fit$opt$par)))
  joint <- gllvmTMB:::.gllvmTMB_sdreport_loading_ridge(
    fit$tmb_obj, fit$opt$par, 2, getJointPrecision = TRUE)
  Q <- as.matrix(joint$jointPrecision)
  random <- fit$tmb_obj$env$random
  fixed <- setdiff(seq_len(nrow(Q)), random)
  schur <- Q[fixed, fixed, drop = FALSE] -
    Q[fixed, random, drop = FALSE] %*%
    solve(Q[random, random, drop = FALSE], Q[random, fixed, drop = FALSE])
  expect_equal(unname(schur), unname(H), tolerance = 1e-7)
  expect_true(all(is.finite(Q)))
  expect_equal(attr(joint, "loading_ridge_curvature")$parameter_vector, fit$opt$par)
  original <- TMB::sdreport(fit$tmb_obj, par.fixed = fit$opt$par)
  unchanged <- gllvmTMB:::.gllvmTMB_sdreport_loading_ridge(fit$tmb_obj, fit$opt$par, Inf)
  expect_equal(unchanged$cov.fixed, original$cov.fixed, tolerance = 1e-10)
  expect_null(attr(unchanged, "loading_ridge_curvature"))
  skipped <- suppressWarnings(gllvmTMB(formula, data = data, unit = "unit", trait = "trait",
    control = gllvmTMBcontrol(loading_ridge = 2, se = FALSE)))
  expect_null(skipped$sd_report)
  expect_null(skipped$loading_ridge_curvature)
})

test_that("ridge provenance distinguishes fixed-adaptation AGHQ curvature", {
  p <- setNames(c(.2, -.3), c("theta_rr_B", "alpha_lv_B"))
  obj <- list(par = p, env = list(random = NULL, data = list(use_aghq = 1L)),
    he = function(p) diag(2L))
  meta <- gllvmTMB:::.gllvmTMB_loading_ridge_curvature_provenance(obj, p, 2)
  expect_identical(meta$integration, "aghq_fixed_adaptation")
  expect_true(meta$adaptation_nodes_fixed)
  expect_false(meta$calibrated_sampling_covariance)
  expect_identical(meta$method, "ad_hessian_plus_exact_loading_prior_precision")
  obj$env$data$use_aghq <- 0L
  meta <- gllvmTMB:::.gllvmTMB_loading_ridge_curvature_provenance(obj, p, 2)
  expect_identical(meta$integration, "laplace")
  expect_false(meta$adaptation_nodes_fixed)
})

test_that("ordinary ridged score covariance uses the penalised joint precision", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(14674)
  n <- 60L
  z <- rnorm(n)
  data <- data.frame(unit = factor(rep(seq_len(n), each = 3L)),
    trait = factor(rep(c("a", "b", "c"), n)))
  data$value <- rep(c(.1, -.1, .2), n) + rep(c(.8, -.5, .6), n) *
    rep(z, each = 3L) + rnorm(3L * n, sd = .2)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = data, unit = "unit", trait = "trait",
    control = gllvmTMBcontrol(loading_ridge = 2)))
  expect_true(isTRUE(fit$sd_report$pdHess))
  joint <- gllvmTMB:::.gllvmTMB_sdreport_loading_ridge(
    fit$tmb_obj, fit$opt$par, 2, getJointPrecision = TRUE)
  Q <- as.matrix(joint$jointPrecision)
  zpos <- which(rownames(Q) == "z_B")
  expected <- unname(diag(solve(Q))[zpos])
  out <- ordination_uncertainty(fit)
  expect_equal(as.numeric(out$cov), expected, tolerance = 1e-8)
  expect_equal(as.numeric(out$se)^2, expected, tolerance = 1e-8)
})
