test_that("default controls do not acquire prior-table metadata", {
  control <- gllvmTMBcontrol()
  expect_identical(gllvmTMBcontrol(priors = NULL), control)
  expect_false("prior_table" %in% names(control))
  expect_false("prior_table_resolved" %in% names(control))
  expect_identical(.gllvmTMB_adapt_prior_table(control), control)

  empty_table <- data.frame(prior = character(), class = character())
  empty_control <- .gllvmTMB_adapt_prior_table(
    gllvmTMBcontrol(priors = empty_table)
  )
  expect_identical(.gllvmTMB_parse_prior_table(empty_table), list())
  expect_identical(empty_control, control)
  expect_false(.gllvmTMB_has_penalty(list(prior_table_resolved = list())))
  expect_silent(.gllvmTMB_guard_exact_zero_priors(empty_control, 0))

  table <- data.frame(prior = "normal(0,2)", class = "fixef", coef = "beta")
  with_table <- gllvmTMBcontrol(priors = table)
  expect_identical(with_table$prior_table, table)
  expect_null(with_table$prior_table_resolved)
})

test_that("GLLVM prior table resolves coefficient and blanket loading rows", {
  table <- data.frame(
    prior = c("normal(0,2)", "student_t(0.2,1.5,3.5)", "ridge(4)", "ridge(0.25)"),
    class = c("fixef", "fixef", "fixef", "loading"),
    coef = c("traita", "traita:x", "traitb", "all"),
    dpar = rep("mu", 4),
    scale = c("link", "link", "link", "loading_coef"),
    stringsAsFactors = FALSE
  )

  rows <- .gllvmTMB_parse_prior_table(table)
  expect_identical(vapply(rows, `[[`, character(1), "class"),
                   c("fixef", "fixef", "fixef", "loading"))
  expect_identical(rows[[2]]$kind, "student_t")
  expect_identical(rows[[4]]$scale, "loading_coef")

  control <- gllvmTMBcontrol(priors = table)
  adapted <- .gllvmTMB_adapt_prior_table(control)
  expect_equal(adapted$fixed_effect_priors$coefficient,
               c("traita", "traita:x", "traitb"))
  expect_equal(adapted$fixed_effect_priors$distribution,
               c("normal", "student_t", "ridge"))
  expect_equal(adapted$fixed_effect_priors$df[2], 3.5)
  expect_equal(adapted$loading_ridge, 2)
  expect_equal(adapted$aghq_ridge, 2)
  expect_true(adapted$loading_ridge_explicit)
})

test_that("GLLVM prior table rejects unsupported and overlapping requests", {
  base <- data.frame(prior = "normal(0,2)", class = "fixef", coef = "beta")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, prior = "gamma(2,3)")),
               "unsupported")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, dpar = "sigma")),
               "dpar")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, dpar = "sigma")),
               "Check the prior-table documentation")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, group = "unit")),
               "group, block, or resp")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, prior = "normal(0,0)")),
               "scale must be positive")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, prior = "student_t(0,1,0)")),
               "scale and df must be positive")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, prior = "ridge(-1)")),
               "lambda must be nonnegative")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, class = "latent_score")),
               "unsupported prior class")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, class = "unique_variance")),
               "unique_variance rows require a Gamma prior")
  expect_error(.gllvmTMB_parse_prior_table(rbind(base, base)), "duplicate fixed-effect")
  expect_error(.gllvmTMB_resolve_fixed_priors(
    .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors =
      transform(base, coef = "not_a_model_column")))$fixed_effect_priors,
    "beta"
  ), "distinct column")

  loading <- data.frame(prior = "ridge(1)", class = "loading", coef = "all")
  expect_error(.gllvmTMB_parse_prior_table(loading), "loading_coef")
  loading$scale <- "loading_coef"
  expect_error(.gllvmTMB_parse_prior_table(rbind(loading, loading)), "duplicate")

  control_fixed <- gllvmTMBcontrol(
    priors = base,
    fixed_effect_priors = data.frame(coefficient = "beta", mean = 0, sd = 1)
  )
  expect_error(.gllvmTMB_adapt_prior_table(control_fixed), "both.*fixed")

  control_loading <- gllvmTMBcontrol(priors = loading, loading_ridge = 1)
  expect_error(.gllvmTMB_adapt_prior_table(control_loading), "both.*loading")
})

test_that("GLLVM Student-t and ridge penalties have independent density checks", {
  table <- data.frame(
    prior = c("student_t(0.2,1.5,3.5)", "ridge(4)"),
    class = c("fixef", "fixef"),
    coef = c("a", "b"),
    dpar = c("mu", "mu"),
    scale = c("link", "link")
  )
  control <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = table))
  priors <- .gllvmTMB_resolve_fixed_priors(control$fixed_effect_priors, c("a", "b"))
  par <- setNames(c(1.1, -0.7, 0.3), c("b_fix", "b_fix", "theta_rr_B"))
  obj <- list(par = par, fn = function(p) sum(p^2), gr = function(p) 2 * p,
              he = function(p) diag(2, length(p)))
  out <- .gllvmTMB_attach_fixed_priors(obj, priors)
  expected_t <- -stats::dt((par[1] - 0.2) / 1.5, df = 3.5, log = TRUE) + log(1.5)
  expected_ridge <- 0.5 * 4 * par[2]^2
  expect_equal(unname(out$fn(par) - obj$fn(par)), unname(expected_t + expected_ridge),
               tolerance = 1e-12)
  expected_gradient <- c(
    (3.5 + 1) * ((par[1] - 0.2) / 1.5) /
      (3.5 + ((par[1] - 0.2) / 1.5)^2) / 1.5,
    4 * par[2], 0
  )
  expect_equal(as.numeric(out$gr(par) - obj$gr(par)), unname(expected_gradient),
               tolerance = 1e-12)
  delta <- 1e-5
  fd <- vapply(seq_along(par), function(i) {
    step <- numeric(length(par)); step[i] <- delta
    (out$fn(par + step) - out$fn(par - step)) / (2 * delta)
  }, numeric(1))
  expect_equal(as.numeric(out$gr(par)), fd, tolerance = 1e-7)

  points <- rbind(c(-1.3, -0.7), c(-0.3, 0.2), c(0, 0.5),
                  c(0.8, -1.2), c(1.4, 0.9))
  for (k in seq_len(nrow(points))) {
    point <- c(points[k, ], 0.3)
    expected_penalty <-
      -stats::dt((point[[1]] - 0.2) / 1.5, df = 3.5, log = TRUE) + log(1.5) +
      0.5 * 4 * point[[2]]^2
    expect_equal(unname(out$fn(point) - obj$fn(point)), expected_penalty,
                 tolerance = 1e-12)
    step <- 2e-4
    fd_gradient <- numeric(length(point))
    fd_hessian <- matrix(0, length(point), length(point))
    for (i in seq_along(point)) {
      plus <- minus <- point
      plus[[i]] <- plus[[i]] + step
      minus[[i]] <- minus[[i]] - step
      fd_gradient[[i]] <- (out$fn(plus) - out$fn(minus)) / (2 * step)
      fd_hessian[i, i] <- (out$fn(plus) - 2 * out$fn(point) + out$fn(minus)) / step^2
      if (i > 1L) for (j in seq_len(i - 1L)) {
        pp <- pm <- mp <- mm <- point
        pp[c(i, j)] <- pp[c(i, j)] + step
        pm[i] <- pm[i] + step; pm[j] <- pm[j] - step
        mp[i] <- mp[i] - step; mp[j] <- mp[j] + step
        mm[c(i, j)] <- mm[c(i, j)] - step
        fd_hessian[i, j] <- fd_hessian[j, i] <-
          (out$fn(pp) - out$fn(pm) - out$fn(mp) + out$fn(mm)) / (4 * step^2)
      }
    }
    expect_equal(as.numeric(out$gr(point)), fd_gradient, tolerance = 2e-6)
    expect_equal(unname(out$he(point)), fd_hessian, tolerance = 2e-4)
  }
})

test_that("public GLLVM table fits preserve targets and identify penalized estimates", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  set.seed(20261117)
  n <- 36L
  dat <- expand.grid(trait = factor(c("a", "b")), unit = factor(seq_len(n)))
  dat$x <- rep(seq(-1, 1, length.out = n), each = 2)
  eta <- rep(c(-0.2, 0.25), n) + rep(c(0.45, -0.35), n) * dat$x +
    rep(rnorm(n, sd = 0.5), each = 2)
  dat$value <- rbinom(nrow(dat), 1, plogis(eta))
  table <- data.frame(
    prior = c("student_t(0,1.5,4)", "normal(0,2)", "ridge(0.25)"),
    class = c("fixef", "fixef", "loading"),
    coef = c("traita:x", "traitb:x", "all"),
    dpar = c("mu", "mu", "mu"),
    scale = c("link", "link", "loading_coef"),
    stringsAsFactors = FALSE
  )
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = 1, unique = FALSE),
    dat, trait = "trait", unit = "unit", family = binomial("logit"),
    control = gllvmTMBcontrol(priors = table, se = FALSE,
                              svd_start = FALSE, n_init = 1L)
  ))

  expect_identical(fit$prior_table, table)
  expect_equal(vapply(fit$prior_table_resolved, `[[`, character(1), "coef"),
               c("traita:x", "traitb:x", "all"))
  expect_identical(fit$estimator, "MAP")
  expect_identical(fit$estimator_provenance$criterion_id,
                   "laplace_plus_mixed_coefficient_priors_and_loading_ridge")
  expect_true(fit$estimator_provenance$loading_ridge_applied)
  expect_identical(fit$fixed_effect_priors$specification$distribution,
                   c("student_t", "normal"))
  replay <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = fit$prior_table))
  expect_identical(replay$prior_table_resolved, fit$prior_table_resolved)
  expect_identical(replay$fixed_effect_priors$distribution,
                   fit$fixed_effect_priors$specification$distribution)
  expect_equal(fit$aghq$ridge, 2)
  expect_error(confint(fit), "not validated for prior-penalized fits")
  replay_call <- update(fit, data = dat, evaluate = FALSE)
  expect_identical(replay_call$control$prior_table, fit$prior_table)
  replay <- suppressWarnings(update(fit, data = dat))
  expect_identical(replay$prior_table, fit$prior_table)
  expect_identical(replay$prior_table_resolved, fit$prior_table_resolved)

  loading_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = 1, unique = FALSE),
    dat, trait = "trait", unit = "unit", family = binomial("logit"),
    control = gllvmTMBcontrol(priors = table[3, ], se = FALSE,
                              svd_start = FALSE, n_init = 1L)
  ))
  expect_identical(loading_fit$estimator, "MAP")
  expect_identical(loading_fit$estimator_provenance$criterion_id,
                   "laplace_plus_loading_ridge")
  expect_error(gllvmTMB(
    value ~ 0 + trait + trait:x, dat, trait = "trait", unit = "unit",
    family = binomial("logit"),
    control = gllvmTMBcontrol(priors = table[3, ], se = FALSE,
                              svd_start = FALSE, n_init = 1L)
  ), "ordinary between-unit.*theta_rr_B")
})

test_that("natural residual-SD Gamma rows resolve and attach without a log-SD Jacobian", {
  table <- data.frame(
    prior = "gamma(0.8,2)",
    class = "residual_sd",
    dpar = "sigma",
    coef = "(Intercept)",
    scale = "natural_sd",
    stringsAsFactors = FALSE
  )
  rows <- .gllvmTMB_parse_prior_table(table)
  expect_identical(rows[[1L]]$kind, "gamma")
  expect_identical(rows[[1L]]$dpar, "sigma")
  expect_identical(rows[[1L]]$scale, "natural_sd")

  adapted <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = table))
  prior <- adapted$residual_sd_prior
  expect_equal(prior$rate, 2.5)
  expect_identical(prior$measure, "natural_sd")
  expect_identical(prior$jacobian, "none")

  mixed <- rbind(
    data.frame(prior = "normal(0,2)", class = "fixef", dpar = "mu",
               coef = "traita", scale = "link"),
    table
  )
  mixed_control <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = mixed))
  expect_equal(mixed_control$fixed_effect_priors$coefficient, "traita")
  expect_equal(mixed_control$residual_sd_prior$rate, 2.5)

  par <- c(log_sigma_eps = log(0.8), b_fix = 0.3)
  base <- list(
    par = par,
    fn = function(p) sum(p^2) / 2,
    gr = function(p) p,
    he = function(p) diag(length(p))
  )
  out <- .gllvmTMB_attach_residual_sd_prior(base, prior)
  expected <- -stats::dgamma(0.8, shape = 2, rate = 2.5, log = TRUE)
  expect_equal(unname(out$fn(par) - base$fn(par)), expected, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(expected, expected + log(0.8))))
  expect_equal(unname(out$gr(par) - base$gr(par)),
               c(2.5 * 0.8 - 1, 0), tolerance = 1e-12)
  expect_equal(unname(out$he(par) - base$he(par)),
               diag(c(2.5 * 0.8, 0)), tolerance = 1e-12)
  for (eta in log(c(0.2, 0.4, 0.8, 1.1, 2))) {
    point <- c(log_sigma_eps = eta, b_fix = -0.2)
    step <- 1e-4
    plus <- minus <- point
    plus[[1L]] <- plus[[1L]] + step
    minus[[1L]] <- minus[[1L]] - step
    penalty_value <- function(x) out$fn(x) - base$fn(x)
    fd_gradient <- (penalty_value(plus) - penalty_value(minus)) / (2 * step)
    fd_hessian <- (penalty_value(plus) - 2 * penalty_value(point) +
                     penalty_value(minus)) / step^2
    sigma <- exp(eta)
    expect_equal(fd_gradient, 2.5 * sigma - 1, tolerance = 2e-7)
    expect_equal(fd_hessian, 2.5 * sigma, tolerance = 2e-6)
    expect_equal(penalty_value(point),
                 -stats::dgamma(sigma, shape = 2, rate = 2.5, log = TRUE),
                 tolerance = 1e-12)
  }
  expect_identical(.gllvmTMB_attach_residual_sd_prior(base, NULL), base)
  expect_error(.gllvmTMB_attach_residual_sd_prior(out, prior), "already")
  expect_error(.gllvmTMB_attach_residual_sd_prior(
    within(base, par <- c(log_sigma_eps = 0.1, log_sigma_eps = 0.2))
  , prior), "exactly one")
})

test_that("residual-SD Gamma rows reject unsupported targets and parameter values", {
  base <- data.frame(
    prior = "gamma(1,2)",
    class = "residual_sd",
    dpar = "sigma",
    coef = "(Intercept)",
    scale = "natural_sd",
    stringsAsFactors = FALSE
  )
  expect_error(.gllvmTMB_parse_prior_table(transform(base, prior = "gamma(1,1)")),
               "shape must exceed one")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, prior = "gamma(0,2)")),
               "mean must be positive")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, dpar = "mu")),
               "dpar=sigma")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, coef = "traita")),
               "coef=\\(Intercept\\)")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, scale = "link")),
               "scale=natural_sd")
  expect_error(.gllvmTMB_parse_prior_table(rbind(base, base)), "duplicate residual-SD")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, class = "unique_variance")),
               "unique_variance rows do not use dpar or coef selectors")
  expect_error(.gllvmTMB_parse_prior_table(
    transform(base, prior = "normal(0,1)")), "require gamma")
})

test_that("natural residual-SD Gamma prior is applied once and replayed", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  set.seed(20261121)
  n <- 32L
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = 2L)),
    trait = factor(rep(c("a", "b"), times = n)),
    value = rnorm(2L * n, mean = rep(c(0.7, 0.1), times = n), sd = 0.65)
  )
  table <- data.frame(
    prior = c("normal(0,2)", "gamma(0.8,2)"),
    class = c("fixef", "residual_sd"), dpar = c("mu", "sigma"),
    coef = c("traita", "(Intercept)"), scale = c("link", "natural_sd")
  )
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait, data = dat, trait = "trait", unit = "unit",
    family = gaussian(),
    control = gllvmTMBcontrol(priors = table, se = FALSE, n_init = 1L)
  ))

  expect_identical(fit$prior_table, table)
  expect_identical(vapply(fit$prior_table_resolved, `[[`, character(1), "class"),
                   c("fixef", "residual_sd"))
  expect_identical(fit$estimator, "MAP")
  expect_true(fit$penalised)
  expect_identical(fit$se_type, "penalised")
  expect_identical(fit$residual_sd_prior$measure, "natural_sd")
  expect_identical(fit$residual_sd_prior$jacobian, "none")
  expect_true(is.finite(fit$objective_components$residual_sd_prior_nll))
  expect_equal(
    fit$objective_components$residual_sd_prior_nll,
    -stats::dgamma(exp(fit$opt$par[["log_sigma_eps"]]), shape = 2,
                   rate = 2.5, log = TRUE),
    tolerance = 1e-10
  )
  expect_true(is.finite(fit$objective_components$fixed_effect_prior_nll))
  expect_equal(fit$objective_components$optimization_nll,
               fit$objective_components$likelihood_nll +
                 fit$objective_components$fixed_effect_prior_nll +
                 fit$objective_components$residual_sd_prior_nll,
               tolerance = 1e-8)

  ## Independent dense Gaussian oracle for the full adapter objective. The
  ## likelihood is computed from X and y directly; neither the package's
  ## prior penalty helper nor its objective decomposition is used by this
  ## oracle. Central finite differences use h_i = 2e-4 * max(1, |theta_i|)
  ## for Hessian entries and 1e-5 * max(1, |theta_i|) for scores.
  X <- stats::model.matrix(~ 0 + trait, data = dat)
  expect_identical(colnames(X), fit$X_fix_names)
  par0 <- fit$opt$par
  beta_idx <- which(names(par0) == "b_fix")
  eta_idx <- which(names(par0) == "log_sigma_eps")
  expect_length(beta_idx, ncol(X))
  expect_length(eta_idx, 1L)
  expect_length(par0, ncol(X) + 1L)
  oracle <- function(theta) {
    beta <- unname(theta[beta_idx])
    sigma <- exp(unname(theta[eta_idx]))
    residual <- dat$value - drop(X %*% beta)
    sse <- sum(residual^2)
    n_obs <- length(dat$value)
    value <- n_obs * (log(sigma) + 0.5 * log(2 * pi)) +
      sse / (2 * sigma^2) -
      stats::dnorm(beta[[1L]], mean = 0, sd = 2, log = TRUE) -
      stats::dgamma(sigma, shape = 2, rate = 2.5, log = TRUE)
    score <- numeric(length(theta))
    score[beta_idx] <- -drop(crossprod(X, residual)) / sigma^2
    score[beta_idx[[1L]]] <- score[beta_idx[[1L]]] + beta[[1L]] / 2^2
    score[eta_idx] <- n_obs - sse / sigma^2 + 2.5 * sigma - 1
    hessian <- matrix(0, length(theta), length(theta))
    hessian[beta_idx, beta_idx] <- crossprod(X) / sigma^2
    hessian[beta_idx[[1L]], beta_idx[[1L]]] <-
      hessian[beta_idx[[1L]], beta_idx[[1L]]] + 1 / 2^2
    beta_eta <- 2 * drop(crossprod(X, residual)) / sigma^2
    hessian[beta_idx, eta_idx] <- beta_eta
    hessian[eta_idx, beta_idx] <- beta_eta
    hessian[eta_idx, eta_idx] <- 2 * sse / sigma^2 + 2.5 * sigma
    list(value = value, score = score, hessian = hessian)
  }
  offsets <- rbind(
    c(-0.20,  0.10, -0.25),
    c( 0.10, -0.30, -0.10),
    c( 0.25,  0.20,  0.20),
    c(-0.10,  0.25,  0.35),
    c( 0.30, -0.10, -0.30)
  )
  for (k in seq_len(nrow(offsets))) {
    theta <- par0
    theta[beta_idx] <- par0[beta_idx] + offsets[k, 1:2]
    theta[eta_idx] <- par0[eta_idx] + offsets[k, 3L]
    expected <- oracle(theta)
    expect_equal(fit$tmb_obj$fn(theta), expected$value,
                 tolerance = 1e-8 * max(1, abs(expected$value)))
    engine_gradient <- as.numeric(fit$tmb_obj$gr(theta))
    expect_equal(engine_gradient, expected$score, tolerance = 1e-6)
    engine_hessian <- fit$tmb_obj$he(theta)
    expect_equal(unname(engine_hessian), unname(expected$hessian),
                 tolerance = 1e-6)

    fd_score_step <- 1e-5 * pmax(1, abs(theta))
    fd_hessian_step <- 2e-4 * pmax(1, abs(theta))
    fd_score <- numeric(length(theta))
    fd_hessian <- matrix(0, length(theta), length(theta))
    for (i in seq_along(theta)) {
      plus <- minus <- theta
      plus[[i]] <- plus[[i]] + fd_score_step[[i]]
      minus[[i]] <- minus[[i]] - fd_score_step[[i]]
      fd_score[[i]] <- (oracle(plus)$value - oracle(minus)$value) /
        (2 * fd_score_step[[i]])
      plus <- minus <- theta
      plus[[i]] <- plus[[i]] + fd_hessian_step[[i]]
      minus[[i]] <- minus[[i]] - fd_hessian_step[[i]]
      fd_hessian[i, i] <- (oracle(plus)$value - 2 * expected$value +
                             oracle(minus)$value) / fd_hessian_step[[i]]^2
      if (i > 1L) for (j in seq_len(i - 1L)) {
        pp <- pm <- mp <- mm <- theta
        pp[c(i, j)] <- pp[c(i, j)] + fd_hessian_step[c(i, j)]
        pm[i] <- pm[i] + fd_hessian_step[[i]]
        pm[j] <- pm[j] - fd_hessian_step[[j]]
        mp[i] <- mp[i] - fd_hessian_step[[i]]
        mp[j] <- mp[j] + fd_hessian_step[[j]]
        mm[c(i, j)] <- mm[c(i, j)] - fd_hessian_step[c(i, j)]
        mixed <- (oracle(pp)$value - oracle(pm)$value -
                    oracle(mp)$value + oracle(mm)$value) /
          (4 * fd_hessian_step[[i]] * fd_hessian_step[[j]])
        fd_hessian[i, j] <- fd_hessian[j, i] <- mixed
      }
    }
    expect_equal(fd_score, expected$score, tolerance = 1e-6)
    expect_equal(engine_gradient, fd_score, tolerance = 1e-6)
    scaled_hessian_error <- abs(fd_hessian - expected$hessian) /
      pmax(1, abs(expected$hessian))
    expect_lt(max(scaled_hessian_error), 1e-5)
    scaled_engine_hessian_error <- abs(engine_hessian - fd_hessian) /
      pmax(1, abs(fd_hessian))
    expect_lt(max(scaled_engine_hessian_error), 1e-5)
  }
  ## A second optimizer fits the independently written dense oracle from a
  ## fixed data-derived start. This checks fit-level agreement rather than
  ## only evaluating both objectives at the package estimate.
  dense_start <- par0
  dense_start[beta_idx] <- 0
  dense_start[eta_idx] <- log(stats::sd(dat$value))
  dense_fit <- stats::optim(
    par = dense_start,
    fn = function(theta) oracle(theta)$value,
    gr = function(theta) oracle(theta)$score,
    method = "BFGS",
    control = list(reltol = 1e-12, maxit = 1000L)
  )
  dense_hessian <- oracle(dense_fit$par)$hessian
  expect_identical(dense_fit$convergence, 0L)
  expect_true(all(eigen(dense_hessian, symmetric = TRUE, only.values = TRUE)$values > 0))
  expect_equal(fit$objective_components$optimization_nll, dense_fit$value,
               tolerance = 1e-8 * max(1, abs(dense_fit$value)))
  expect_equal(unname(fit$opt$par), unname(dense_fit$par), tolerance = 1e-5)
  expect_true(any(abs(oracle(par0)$hessian[beta_idx, eta_idx, drop = FALSE]) > 1e-8))
  expect_error(confint(fit), "not validated for prior-penalized fits")
  expect_warning(as.numeric(logLik(fit)), "penalised MAP point")
  aic_warnings <- character()
  withCallingHandlers(
    AIC(fit),
    warning = function(w) {
      aic_warnings <<- c(aic_warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("AIC\\(\\) on a penalised fit", aic_warnings)))

  replay_call <- update(fit, data = dat, evaluate = FALSE)
  expect_identical(replay_call$control$prior_table, table)
  replay <- suppressWarnings(update(fit, data = dat))
  expect_identical(replay$prior_table, fit$prior_table)
  expect_identical(replay$prior_table_resolved, fit$prior_table_resolved)

  bad <- dat
  bad$value[1L] <- NA_real_
  expect_error(gllvmTMB(
    value ~ 0 + trait, data = bad, trait = "trait", unit = "unit",
    family = gaussian(), control = gllvmTMBcontrol(priors = table)
  ), "complete responses")
  expect_error(gllvmTMB(
    value ~ 0 + trait, data = dat, trait = "trait", unit = "unit",
    family = gaussian(), weights = seq_len(nrow(dat)),
    control = gllvmTMBcontrol(priors = table)
  ), "unit likelihood weights")
  expect_error(gllvmTMB(
    value ~ 0 + trait, data = dat, trait = "trait", unit = "unit",
    family = binomial(), control = gllvmTMBcontrol(priors = table)
  ), "Gaussian responses")
})
