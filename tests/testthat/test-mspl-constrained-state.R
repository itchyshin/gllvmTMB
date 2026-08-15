test_that("internal MSPL constrained state simulates from the penalised constrained fit", {
  set.seed(81401)
  dat <- expand.grid(
    site = factor(seq_len(24L)), trait = factor(paste0("sp", 1:3)),
    KEEP.OUT.ATTRS = FALSE
  )
  z <- stats::rnorm(24L)
  beta <- c(-0.5, 0.1, 0.55)
  lambda <- c(0.8, -0.55, 0.35)
  eta <- beta[as.integer(dat$trait)] +
    z[as.integer(dat$site)] * lambda[as.integer(dat$trait)]
  dat$y <- stats::rbinom(nrow(dat), 1L, stats::plogis(eta))
  fit <- gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1L, unique = FALSE),
    data = dat, family = stats::binomial("logit"), estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  )
  index <- which(names(fit$opt$par) == "b_fix")[[1L]]
  target <- fit$opt$par[[index]] + 0.5
  original_par <- fit$opt$par
  original_eta <- fit$report$eta
  fit$mspl$unpenalized_tmb_obj$fn <- function(...) stop("penalty-off objective called")

  state <- gllvmTMB:::.gllvmTMB_mspl_constrained_simulation_state(
    fit, which = index, target = target
  )
  expect_identical(state$status, "ok")
  expect_identical(state$objective_source, "fit$tmb_obj (penalised LA-MSPL)")
  expect_identical(state$estimator_id, 1L)
  expect_true(state$nuisance_reoptimized)
  expect_identical(state$simulation_fit$opt$par[[index]], target)
  expect_true(all(is.finite(state$simulation_fit$report$eta)))
  expect_identical(fit$opt$par, original_par)
  expect_identical(fit$report$eta, original_eta)

  draw <- stats::simulate(
    state$simulation_fit, nsim = 1L, seed = 81402L, condition_on_RE = FALSE
  )
  expect_identical(dim(draw), c(nrow(dat), 1L))
  expect_true(all(draw[, 1L] %in% c(0, 1)))
})
