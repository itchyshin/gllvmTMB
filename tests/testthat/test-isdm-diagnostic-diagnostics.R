`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

fixture_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "fixture.R"
)
diagnostic_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "diagnostic-rescue",
  "diagnostics.R"
)

if (!file.exists(fixture_path) || !file.exists(diagnostic_path)) {
  test_that("developer-only iSDM diagnostic sources are available", {
    skip("dev/isdm-requalification diagnostic sources are absent")
  })
} else {
source(fixture_path, local = TRUE)
source(diagnostic_path, local = TRUE)

test_that("truth replay reconstructs fixed, shared, and full surfaces exactly", {
  fixture <- isdm_nonspatial_fixture(
    seed = 100L, observation_seed = 101L,
    n_sources = 2L, overlap = "full", n_cells = 30L
  )
  out <- diagnostic_nonspatial_truth_components(fixture)

  expect_equal(out$full, fixture$truth$eta_ecological, tolerance = 0)
  expect_equal(unname(out$shared - out$fixed),
               unname(tcrossprod(out$u, as.numeric(fixture$truth$lambda))),
               tolerance = 1e-15)
  expect_equal(unname(out$full - out$shared), unname(out$e),
               tolerance = 1e-15)

  drift <- fixture
  drift$truth$eta_ecological[1, 1] <- drift$truth$eta_ecological[1, 1] + 1e-4
  expect_error(
    diagnostic_nonspatial_truth_components(drift),
    class = "isdm_diagnostic_truth_replay_mismatch"
  )
})

test_that("rep3 preserves baseline bytes and registers independent streams", {
  fixture <- isdm_nonspatial_fixture(
    seed = 102L, observation_seed = 103L,
    n_sources = 3L, overlap = "weak", n_cells = 30L
  )
  baseline <- fixture$data
  out <- diagnostic_rep3_fixture(fixture, native_task_id = 17L)
  n <- nrow(baseline)

  expect_identical(
    out$data[seq_len(n), names(baseline), drop = FALSE], baseline
  )
  expect_identical(out$data$replicate_id, rep(1:3, each = n))
  expect_identical(out$design$replicate_seeds,
                   as.integer(c(203000034, 203000035)))
  expect_identical(out, diagnostic_rep3_fixture(fixture, 17L))
  expect_false(identical(out$data$value[seq_len(n)],
                         out$data$value[n + seq_len(n)]))

  bernoulli <- out$data$isdm_source == "source3"
  expect_true(all(out$data$value[bernoulli] %in% 0:1))
  expect_error(diagnostic_rep3_fixture(fixture, 0L),
               class = "isdm_diagnostic_task_id_invalid")
})

test_that("surface extraction decomposes a public prediction exactly", {
  scoring <- expand.grid(
    cell_id = factor(c("cell1", "cell2"), levels = c("cell1", "cell2")),
    trait = factor(c("sp1", "sp2"), levels = c("sp1", "sp2")),
    KEEP.OUT.ATTRS = FALSE
  )
  ## expand.grid above varies cell first: (cell1,sp1), (cell2,sp1), ...
  fixed <- c(1, 2, 3, 4)
  lambda <- matrix(c(0.5, -0.25), nrow = 2L)
  z <- c(2, -1)
  s <- matrix(c(0.1, 0.2, 0.3, 0.4), nrow = 2L)
  shared_add <- c(lambda[1, ] * z[1], lambda[1, ] * z[2],
                  lambda[2, ] * z[1], lambda[2, ] * z[2])
  unique_add <- c(s[1, 1], s[1, 2], s[2, 1], s[2, 2])
  public <- fixed + shared_add + unique_add
  env <- new.env(parent = emptyenv())
  env$last.par.best <- c(stats::setNames(z, rep("z_B", 2L)),
                         stats::setNames(as.numeric(s), rep("s_B", 4L)))
  fit <- list(
    use = list(rr_B = TRUE, diag_B = TRUE, lv_B = FALSE), d_B = 1L,
    report = list(Lambda_B = lambda), tmb_obj = list(env = env)
  )
  fixture <- list(scoring = scoring)
  predict_mock <- function(object, newdata, type, re_form = NULL) {
    data.frame(est = if (is.null(re_form)) public else fixed)
  }
  out <- diagnostic_extract_nonspatial(
    fit, fixture, tolerance = 1e-10, .predict = predict_mock
  )

  expect_equal(out$fixed, fixed)
  expect_equal(out$shared, fixed + shared_add)
  expect_equal(out$full, public)
  expect_equal(out$identity_error, 0)
  expect_true(out$sign_invariance$available)
  expect_equal(out$sign_invariance$max_error, 0)

  bad_predict <- function(object, newdata, type, re_form = NULL) {
    data.frame(est = if (is.null(re_form)) public + 1e-4 else fixed)
  }
  expect_error(
    diagnostic_extract_nonspatial(fit, fixture, .predict = bad_predict),
    class = "isdm_diagnostic_public_prediction_mismatch"
  )
})

test_that("surface metrics normalize errors within trait", {
  truth <- c(0, 1, 10, 12)
  estimate <- truth + c(0.1, -0.1, 0.2, -0.2)
  trait <- rep(c("sp1", "sp2"), each = 2L)
  out <- diagnostic_surface_metrics(estimate, truth, trait)
  scales <- rep(c(stats::sd(truth[1:2]), stats::sd(truth[3:4])), each = 2L)

  expect_equal(out$normalized_rmse,
               sqrt(mean(((estimate - truth) / scales)^2)))
  expect_identical(out$per_trait$trait, c("sp1", "sp2"))
  expect_error(
    diagnostic_surface_metrics(c(1, NA), c(1, 2), c("a", "a")),
    class = "isdm_diagnostic_surface_invalid"
  )
})

test_that("curvature follows replay-align-Hessian-replay-align order", {
  calls <- character()
  env <- new.env(parent = emptyenv())
  env$last.par <- c(9, 9, 9, 8)
  env$last.par.best <- env$last.par
  obj <- list(env = env)
  obj$fn <- function(par) {
    calls <<- c(calls, "fn")
    env$last.par <- c(par, random = 8)
    sum(par^2)
  }
  obj$gr <- function(par) 2 * par
  env$spHess <- function(par, random) {
    calls <<- c(calls, "spHess")
    expect_true(random)
    expect_identical(par, env$last.par.best)
    diag(c(4, 5))
  }
  hess_mock <- function(par, fn, gr) {
    calls <<- c(calls, "optimHess")
    diag(c(1, 2, 3))
  }
  sd_mock <- function(obj, par.fixed, hessian.fixed, getJointPrecision,
                      skip.delta.method) {
    calls <<- c(calls, "sdreport")
    expect_identical(par.fixed, fit$opt$par)
    expect_equal(hessian.fixed, diag(c(1, 2, 3)))
    expect_true(getJointPrecision)
    expect_true(skip.delta.method)
    list(jointPrecision = diag(5))
  }
  fit <- list(
    tmb_obj = obj,
    opt = list(par = c(a = 2, a = 0.5, b = -1), objective = 5.25),
    sd_report = list(pdHess = TRUE)
  )
  out <- diagnostic_curvature(
    fit, dimension_cap = 5L, .optim_hess = hess_mock,
    .sdreport = sd_mock
  )

  expect_identical(calls,
                   c("fn", "optimHess", "fn", "spHess", "sdreport"))
  expect_true(out$available)
  expect_true(out$direct_pd_agreement)
  expect_equal(out$objective_difference, 0)
  expect_identical(out$parameter_index_map$a, 1:2)
  expect_equal(sum(out$attribution$native$smallest_algebraic$block_mass$N), 1)
  expect_true(out$conditional_random$pd)
  expect_true(out$joint_precision$eigen_available)
})

test_that("curvature fails primary attribution on PD mismatch and caps eigen work", {
  env <- new.env(parent = emptyenv())
  env$last.par <- env$last.par.best <- c(1, 2, 3, 4)
  obj <- list(
    env = env,
    fn = function(par) {
      env$last.par <- c(par, random = 4)
      sum(par^2)
    },
    gr = function(par) 2 * par
  )
  env$spHess <- function(par, random) diag(6)
  fit <- list(
    tmb_obj = obj,
    opt = list(par = c(a = 1, b = 2, b = 3), objective = 14),
    sd_report = list(pdHess = FALSE)
  )
  out <- diagnostic_curvature(
    fit, dimension_cap = 3L,
    .optim_hess = function(...) diag(3),
    .sdreport = function(...) list(jointPrecision = diag(7))
  )

  expect_false(out$available)
  expect_false(out$direct_pd_agreement)
  expect_match(out$marginal_native$reason, "disagrees")
  expect_false(out$conditional_random$eigen_available)
  expect_false(out$joint_precision$eigen_available)
  expect_null(out$attribution$native)
})
}
