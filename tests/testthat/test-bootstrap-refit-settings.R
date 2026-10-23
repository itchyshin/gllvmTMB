bootstrap_settings_fixture <- function() {
  structure(list(
    formula = y ~ 1, covstructs = list(),
    data = data.frame(y = 1:4, trait = rep(c('a', 'b'), 2), unit = rep(1:2, each = 2)),
    trait_col = 'trait', unit_col = 'unit', family = gaussian(), REML = TRUE,
    opt = list(convergence = 0L), use = list(rr_B = TRUE),
    report = list(B_lv_unit = matrix(c(.2, .3), 2, 1,
      dimnames = list(c('a', 'b'), 'x'))),
    aghq = list(used = FALSE, ridge_tau = 2, optimizer = 'optim'),
    control = gllvmTMBcontrol(loading_ridge = 2, optimizer = 'optim',
      optArgs = list(method = 'BFGS'), n_init = 3L)
  ), class = 'gllvmTMB_multi')
}

test_that('covariance and LV bootstrap refits retain fit settings', {
  fit <- bootstrap_settings_fixture()
  seen <- list()
  with_mocked_bindings(
    simulate = function(object, nsim, ...) matrix(seq_len(4 * nsim), 4, nsim),
    .extract_summaries = function(...) list(Sigma_B = diag(2)),
    gllvmTMB = function(...) {
      seen[[length(seen) + 1L]] <<- list(...)
      fit
    },
    .package = 'gllvmTMB',
    {
      suppressWarnings(bootstrap_Sigma(fit, n_boot = 3L, conf = .5,
        level = 'unit', what = 'Sigma', progress = FALSE))
      bootstrap_ci_lv_effects(fit, n_boot = 3L, conf = .5)
    }
  )
  expect_length(seen, 6L)
  for (args in seen) {
    expect_identical(args$control$loading_ridge, 2)
    expect_identical(args$control$optimizer, 'optim')
    expect_identical(args$control$optArgs$method, 'BFGS')
    expect_identical(args$control$n_init, 3L)
    expect_false(args$control$se)
    expect_true(args$REML)
  }
})

test_that('legacy bootstrap refits retain recorded ridge metadata', {
  fit <- bootstrap_settings_fixture()
  fit$control <- NULL
  control <- .bootstrap_refit_control(fit)
  expect_identical(control$loading_ridge, 2)
  expect_identical(control$optimizer, 'optim')
  expect_false(control$se)
  expect_null(fit$control)
})

test_that('bootstrap inputs reject silent count truncation and invalid scalars', {
  withr::local_options(lifecycle_verbosity = 'quiet')
  fit <- bootstrap_settings_fixture()
  for (fn in list(function(...) bootstrap_Sigma(..., level = "unit"), bootstrap_ci_lv_effects)) {
    for (x in list(3.5, NA_real_, Inf, numeric(), c(3, 4), 0, -1)) {
      expect_error(fn(fit, n_boot = x, conf = .5), 'n_boot.*positive integer')
      expect_error(fn(fit, n_boot = 3L, conf = .5, n_cores = x), 'n_cores.*positive integer')
    }
    for (x in list(NA_real_, Inf, numeric(), c(.5,.8), 0, 1)) {
      expect_error(fn(fit, n_boot = 3L, conf = x), 'conf.*single.*0.*1')
    }
  }
})

test_that('native fits retain controls used by bootstrap response refits', {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  set.seed(1473)
  dat <- expand.grid(unit = factor(seq_len(12)), trait = factor(letters[1:3]))
  dat$y <- rnorm(nrow(dat))
  control <- gllvmTMBcontrol(se = FALSE, loading_ridge = 2, n_init = 1L,
    optimizer = 'optim', optArgs = list(method = 'BFGS'))
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1), data = dat,
    family = gaussian(), unit = 'unit', trait = 'trait', control = control)))
  expect_identical(fit$control, control)
})

test_that('LV bootstrap refuses MSPL before simulation or ML refits', {
  fit <- bootstrap_settings_fixture()
  fit$estimator <- 'MSPL'
  fit$REML <- FALSE
  seen <- new.env(parent = emptyenv())
  seen$simulated <- seen$refitted <- FALSE
  with_mocked_bindings(
    simulate = function(object, nsim, ...) {
      seen$simulated <- TRUE
      matrix(seq_len(4 * nsim), 4, nsim)
    },
    gllvmTMB = function(...) { seen$refitted <- TRUE; fit },
    .package = 'gllvmTMB',
    expect_error(bootstrap_ci_lv_effects(fit, n_boot = 3L, conf = .5),
      class = 'gllvmTMB_mspl_inference_unsupported')
  )
  expect_false(seen$simulated)
  expect_false(seen$refitted)
})
