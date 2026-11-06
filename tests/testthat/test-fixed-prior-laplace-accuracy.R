test_that("Laplace accuracy compares likelihoods at a fixed-prior fit", {
  set.seed(6071)
  n <- 36L
  trait <- factor(rep(c("a", "b", "c"), n), levels = c("a", "b", "c"))
  unit <- factor(rep(seq_len(n), each = 3L))
  z <- rnorm(n)
  eta <- rep(c(-.4, -.2, .1), n) + rep(z, each = 3L) * rep(c(.8, -.5, .3), n)
  d <- data.frame(value = rbinom(n * 3L, 1L, plogis(eta)), trait = trait, unit = unit)
  priors <- data.frame(coefficient = paste0("trait", letters[1:3]), mean = 0, sd = 10)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = d, trait = "trait", unit = "unit", family = binomial(),
    control = gllvmTMBcontrol(fixed_effect_priors = priors, loading_ridge = .75,
                              aghq = FALSE, n_init = 1L, svd_start = FALSE,
                              warn_runaway = FALSE, se = FALSE))))
  par <- fit$opt$par
  raw <- fit$tmb_obj$fixed_effect_priors$likelihood_fn(par)
  penalised <- fit$tmb_obj$fn(par)
  expect_gt(abs(penalised - raw), 1)
  check <- .gllvmTMB_laplace_accuracy(fit)
  expect_true(check$evaluated)
  expect_equal(check$loglik_laplace, -as.numeric(raw), tolerance = 1e-7)
  expect_equal(check$optimism, check$loglik_laplace - check$loglik_quadrature,
               tolerance = 1e-10)
  saved_last <- fit$tmb_obj$env$last.par
  saved_best <- fit$tmb_obj$env$last.par.best
  one_node <- .gllvmTMB_laplace_accuracy(fit, k = 1L)
  expect_true(one_node$evaluated)
  expect_equal(one_node$loglik_laplace, one_node$loglik_quadrature, tolerance = 1e-7)
  expect_identical(fit$tmb_obj$env$last.par, saved_last)
  expect_identical(fit$tmb_obj$env$last.par.best, saved_best)
  broken <- fit
  broken$tmb_obj$fixed_effect_priors$likelihood_fn <- NULL
  unavailable <- .gllvmTMB_laplace_accuracy(broken)
  expect_false(unavailable$evaluated)
  expect_match(unavailable$reason, "unpenalised likelihood unavailable")
})
