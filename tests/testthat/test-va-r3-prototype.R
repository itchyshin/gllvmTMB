test_that("R3 packing and rank-zero guards match the frozen contract", {
  for (q in c(1L, 2L, 4L, 6L)) {
    T <- 6L
    Lambda <- matrix(0, T, q)
    Lambda[row(Lambda) >= col(Lambda)] <- seq_len(.va_r3_theta_length(T, q)) / 10
    packed <- .va_r3_pack_theta_rr(Lambda)
    expect_length(packed, .va_r3_theta_length(T, q))
    expect_equal(.va_r3_unpack_theta_rr(packed, T, q), Lambda, tolerance = 0)
  }

  rank_zero <- .va_r3_fit(
    y = c(1L, 2L), n_trials = c(3L, 3L), X = matrix(1, 2L, 1L),
    unit_id = c(1L, 1L), trait_id = 1:2, q = 0L,
    source = "this-source-must-not-be-opened.cpp"
  )
  expect_identical(rank_zero$status, "not_applicable_rank_zero")
  expect_false(rank_zero$objective_constructed)
})

test_that("R3 objective agreement requires any three of four healthy starts", {
  objectives <- c(10, 10 + 2e-7, 10 + 4e-7, 10 + 3e-6)
  expect_lt(.va_r3_best_three_range(objectives), 1e-6)
  expect_gt(diff(range(objectives)), 1e-6)
  expect_identical(.va_r3_best_three_range(c(1, 2)), Inf)
})

test_that("R3 accepts only the predeclared complete ordinary model cell", {
  args <- list(
    y = c(1L, 2L, 0L, 3L), n_trials = rep(4L, 4L),
    X = cbind(1, c(-1, 1, -1, 1)),
    unit_id = rep(1:2, each = 2L), trait_id = rep(1:2, 2L), q = 1L
  )
  expect_no_error(do.call(.va_r3_validate_data, args))
  expect_error(do.call(.va_r3_validate_data, c(args, list(unique = TRUE))),
               "ordinary latent")
  expect_error(do.call(.va_r3_validate_data, c(args, list(structured = TRUE))),
               "ordinary latent")
  expect_error(do.call(.va_r3_validate_data,
                       within(args, trait_id <- c(1L, 1L, 1L, 2L))),
               "exactly one complete")
  rank_deficient <- args
  rank_deficient$X <- matrix(1, 4L, 2L)
  expect_error(do.call(.va_r3_validate_data, rank_deficient),
               "full column rank")
})

test_that("R3 Gauss-Hermite rules are normalized and stable", {
  for (H in c(15L, 25L, 61L)) {
    rule <- .va_r3_gh_rule(H)
    expect_equal(sum(rule$weights), sqrt(pi), tolerance = 1e-14)
    expect_equal(sum(rule$weights * rule$nodes), 0, tolerance = 1e-14)
    expect_equal(sum(rule$weights * rule$nodes^2) / sqrt(pi), 0.5,
                 tolerance = 1e-13)
  }
  expect_error(.va_r3_gh_rule(9L), "15, H = 25, or H = 61")
})

test_that("R3 H=61 scalar expectation passes the frozen oracle grid", {
  validated <- .va_r3_validate_data(
    y = 1L, n_trials = 3L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = 0, theta_rr = 0, m = matrix(0, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  ## eval_method = "gh" is explicit because this grid checks the QUADRATURE
  ## path against an exact integrate() oracle. Binomial "auto" resolves to the
  ## Jaakkola-Jordan bound, which is deliberately not exact, so leaving the
  ## default here would fail the oracle by construction rather than by defect.
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters,
                               eval_method = "gh")
  beta_index <- which(names(obj$par) == "beta")
  theta_index <- which(names(obj$par) == "theta_rr")
  stable_softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
  for (mu in c(-20, -5, 0, 5, 20)) {
    for (variance in c(0, 1e-8, 1e-4, 0.1, 1, 4)) {
      p <- obj$par
      p[beta_index] <- mu
      p[theta_index] <- sqrt(variance)
      observed <- obj$report(p)$softplus_expectation_by_obs[1L]
      expected <- if (variance == 0) stable_softplus(mu) else {
        stats::integrate(function(z) {
          stable_softplus(mu + sqrt(variance) * z) * stats::dnorm(z)
        }, -Inf, Inf, rel.tol = 1e-13)$value
      }
      expect_lt(abs(observed - expected), 1e-10)
    }
  }
})

test_that("R3 nbinom2 expected log-likelihood passes a direct integrate() oracle", {
  ## Independent check of the template's nbinom2 branch. The oracle density
  ## uses base R's stats::dnbinom(mu = exp(eta), size = phi, log = TRUE) --
  ## algebraically identical to
  ##   log p(y|eta) = lgamma(y+phi) - lgamma(phi) - lgamma(y+1)
  ##                  + phi*log(phi) - (y+phi)*log(phi + exp(eta)) + y*eta
  ## but a genuinely separate implementation (R's own, numerically stable at
  ## large mu), not the shifted-softplus identity the template uses. This is
  ## then integrated against eta ~ N(mu, v) by stats::integrate() and compared
  ## to the template's reported expected_loglik_by_obs.
  validated <- .va_r3_validate_data(
    y = 2L, n_trials = 1L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L,
    family = "nbinom2", link = "log"
  )
  parameters <- list(
    beta = 0, theta_rr = 0, m = matrix(0, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters,
                               eval_method = "gh")
  beta_index <- which(names(obj$par) == "beta")
  theta_index <- which(names(obj$par) == "theta_rr")
  phi_index <- which(names(obj$par) == "log_phi")
  expect_length(phi_index, 1L)

  nbinom2_logdensity <- function(y, eta, phi) {
    stats::dnbinom(y, size = phi, mu = exp(eta), log = TRUE)
  }

  y_val <- 2
  for (mu in c(-3, -1, 0, 1, 3)) {
    for (variance in c(0, 1e-8, 1e-4, 0.1, 1, 4)) {
      for (phi in c(0.5, 2, 10)) {
        p <- obj$par
        p[beta_index] <- mu
        p[theta_index] <- sqrt(variance)
        p[phi_index] <- log(phi)
        observed <- obj$report(p)$expected_loglik_by_obs[1L]
        expected <- if (variance == 0) {
          nbinom2_logdensity(y_val, mu, phi)
        } else {
          ## Finite bounds, not (-Inf, Inf): unlike softplus (linear growth),
          ## the direct oracle exponentiates eta with no stabilisation, so an
          ## unbounded domain lets integrate() probe eta large enough to
          ## overflow exp(). +-40 SD is far beyond where the tail mass matters
          ## at this tolerance and stays well inside exp()'s safe range.
          stats::integrate(function(z) {
            eta <- mu + sqrt(variance) * z
            nbinom2_logdensity(y_val, eta, phi) * stats::dnorm(z)
          }, -40, 40, rel.tol = 1e-13)$value
        }
        expect_lt(abs(observed - expected), 1e-8)
      }
    }
  }
})

test_that("R3 nbinom2 is mapped off (inert) for every other family", {
  ## log_phi must not appear in obj$par -- and must not change the objective
  ## or gradient -- for a family that never uses it. This is the guard against
  ## the parameter-vector-cascade risk: adding log_phi to the template must
  ## cost the pre-existing families nothing.
  validated <- .va_r3_validate_data(
    y = 1L, n_trials = 3L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = 0.4, theta_rr = 0.3, m = matrix(0.1, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  obj <- .va_r3_make_objective(validated, H = 25L, parameters = parameters,
                               eval_method = "gh")
  expect_false("log_phi" %in% names(obj$par))
  ## beta, theta_rr, m, log_L_diag; L_off is empty at q=1 (0 off-diagonal
  ## entries), and log_phi is mapped off for this (binomial) family.
  expect_identical(length(obj$par), 4L)
})

test_that("R3 latent posterior reads variational means and SDs out of the fitted par", {
  ## N = 2, q = 2. TMB matrices are column-major, so the packed vectors below
  ## give unit 1 the Cholesky [[1, 0], [3, 2]] and unit 2 [[0.5, 0], [-1, 1]].
  ##   unit 1: L L' = [[1, 3], [3, 13]]     -> sd = (1, sqrt(13))
  ##   unit 2: L L' = [[0.25, -0.5], [-0.5, 2]] -> sd = (0.5, sqrt(2))
  par <- c(
    m = 0.1, m = 0.2, m = 0.3, m = 0.4,
    log_L_diag = 0, log_L_diag = log(0.5), log_L_diag = log(2), log_L_diag = 0,
    L_off = 3, L_off = -1
  )
  post <- .va_r3_latent_posterior(par, N = 2L, q = 2L)

  expect_equal(post$scores, matrix(c(0.1, 0.2, 0.3, 0.4), 2L, 2L))
  expect_equal(
    post$se,
    matrix(c(1, 0.5, sqrt(13), sqrt(2)), nrow = 2L, ncol = 2L),
    tolerance = 1e-12
  )
  ## These are variational posterior SDs, not Wald SEs, and they are not
  ## calibrated. Both facts must travel with the numbers.
  expect_false(post$calibrated)
  expect_match(post$uncertainty_basis, "variational posterior")

  ## An unnamed par cannot be unpacked and must fail rather than guess.
  expect_error(.va_r3_latent_posterior(unname(par), N = 2L, q = 2L),
               "parameter names")
})

test_that("R3 fit returns a latent posterior of the right shape", {
  set.seed(4242)
  n <- 40L; p <- 4L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.5)
  fit <- .va_r3_fit(
    y = rbinom(n * p, 1L, plogis(eta)), n_trials = rep(1L, n * p),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = as.integer(long$unit), trait_id = as.integer(long$trait),
    q = 2L, family = "binomial", link = "logit", H = 15L
  )
  expect_false(is.null(fit$latent))
  expect_identical(dim(fit$latent$scores), c(n, 2L))
  expect_identical(dim(fit$latent$se), c(n, 2L))
  expect_true(all(is.finite(fit$latent$se)))
  expect_true(all(fit$latent$se > 0))
  expect_false(fit$latent$calibrated)
})

test_that("R3 nbinom2 fit is alive: simulate-then-fit returns a healthy status", {
  ## A recovery SMOKE test, not a recovery accuracy test: the point is to
  ## prove the whole nbinom2 pipeline (beta, loadings, per-trait log_phi, and
  ## the variational block) is alive end to end, not to certify accuracy.
  set.seed(2026L)
  N <- 60L; T <- 4L; q <- 2L
  trait_names <- paste0("sp", seq_len(T))
  long <- data.frame(
    unit = factor(rep(seq_len(N), each = T)),
    trait = factor(rep(trait_names, N), levels = trait_names)
  )
  beta <- c(1.0, 0.8, 0.6, 0.9)
  Lambda <- matrix(0, T, q)
  Lambda[row(Lambda) >= col(Lambda)] <- c(0.5, 0.3, -0.2, 0.4, 0.35, -0.25, 0.2)
  score <- matrix(rnorm(N * q), N, q)
  unit <- as.integer(long$unit)
  trait <- as.integer(long$trait)
  eta <- beta[trait] + rowSums(
    Lambda[trait, , drop = FALSE] * score[unit, , drop = FALSE]
  )
  phi_true <- 2
  y <- rnbinom(N * T, size = phi_true, mu = exp(eta))

  fit <- .va_r3_fit(
    y = y, n_trials = rep(1L, N * T),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = unit, trait_id = trait,
    q = q, family = "nbinom2", link = "log", H = 15L
  )

  expect_identical(fit$status, "healthy")
  expect_true(is.finite(fit$best$objective))
  expect_gte(fit$health$healthy_starts, 3L)
  fitted_log_phi <- unname(fit$best$par[names(fit$best$par) == "log_phi"])
  expect_length(fitted_log_phi, T)
  expect_true(all(is.finite(fitted_log_phi)))
})

test_that("R3 fixed-parameter information marginalises the variational block", {
  set.seed(9191)
  n <- 60L; p <- 5L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.6)
  fit <- .va_r3_fit(
    y = rbinom(n * p, 1L, plogis(eta)), n_trials = rep(1L, n * p),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = as.integer(long$unit), trait_id = as.integer(long$trait),
    q = 2L, family = "binomial", link = "logit", H = 15L
  )
  info <- .va_r3_fixed_information(fit$objective, fit$best$par)

  expect_identical(info$status, "ok")
  expect_true(info$pd_hessian)
  expect_true(all(is.finite(info$se_conditional)))
  expect_true(all(is.finite(info$se_profile)))
  expect_true(all(info$se_profile > 0))

  ## The load-bearing property. Profiling the variational block OUT can only
  ## reduce curvature (the Schur complement subtracts a positive semi-definite
  ## term), so the profile SE must be >= the conditional one. A naive
  ## optimHess over the fixed block alone is therefore anti-conservative --
  ## this test is what stops anyone "simplifying" to that later.
  expect_true(all(info$se_profile >= info$se_conditional * (1 - 1e-8)))

  ## Not calibrated, and that must travel with the numbers.
  expect_false(info$calibrated)

  ## Fails closed rather than returning a number it cannot justify.
  broken <- .va_r3_fixed_information(
    list(he = function(p) stop("no hessian")), fit$best$par
  )
  expect_false(broken$pd_hessian)
  expect_null(broken$se_profile)
  expect_match(broken$status, "hessian_error")
})

test_that("R3 blocked information reproduces the dense Schur complement exactly", {
  ## The blocked route never forms the dense Hessian. It relies on units being
  ## conditionally independent given the fixed parameters, so H_vv is EXACTLY
  ## block diagonal. That is a structural claim about the model, and this test
  ## is what verifies it rather than assuming it: if any cross-unit second
  ## derivative were non-zero, the two routes would disagree here.
  set.seed(31)
  n <- 60L; p <- 5L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.6)
  fit <- .va_r3_fit(
    y = rbinom(n * p, 1L, plogis(eta)), n_trials = rep(1L, n * p),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = as.integer(long$unit), trait_id = as.integer(long$trait),
    q = 2L, family = "binomial", link = "logit", H = 15L
  )

  dense <- .va_r3_fixed_information(fit$objective, fit$best$par)
  blocked <- .va_r3_fixed_information_blocked(fit$objective, fit$best$par,
                                              N = n, q = 2L)

  expect_identical(dense$status, "ok")
  expect_identical(blocked$status, "ok")
  expect_identical(blocked$route, "blocked")
  expect_true(blocked$pd_hessian)

  ## Agreement to numerical precision -- this is the load-bearing assertion.
  expect_equal(blocked$se_profile, dense$se_profile, tolerance = 1e-8)
  expect_equal(blocked$se_conditional, dense$se_conditional, tolerance = 1e-8)

  ## The anti-conservatism invariant must hold on the blocked route too.
  expect_true(all(blocked$se_profile >= blocked$se_conditional * (1 - 1e-8)))
  expect_false(blocked$calibrated)

  ## The index map must place every variational coordinate exactly once.
  map <- .va_r3_variational_index_map(names(fit$best$par), N = n, q = 2L)
  expect_identical(dim(map), c(n, 5L))          # k = 2q + q(q-1)/2 = 5
  expect_identical(anyDuplicated(as.integer(map)), 0L)
  expect_setequal(
    as.integer(map),
    which(names(fit$best$par) %in% c("m", "log_L_diag", "L_off"))
  )
})

test_that("R3 family registry agrees with the validator and drives eval_method", {
  ## The registry is the declared per-family evaluation contract. It must not
  ## drift from .va_r3_validate_data(), which is what actually assigns the
  ## family code the template sees. Adding a family without a registry entry
  ## (or with the wrong code/link) fails here rather than silently.
  y_for <- list(gaussian_anchor = 0.5, binomial = 1L, poisson = 2L, nbinom2 = 2L)
  for (entry in .va_r3_family_registry) {
    validated <- .va_r3_validate_data(
      y = y_for[[entry$family]], n_trials = 3L, X = matrix(1, 1L, 1L),
      unit_id = 1L, trait_id = 1L, q = 1L,
      family = entry$family, link = entry$link
    )
    expect_identical(validated$family, entry$family_code)

    ## "auto" resolves to whatever the registry declares.
    expect_identical(
      .va_r3_resolve_eval_method("auto", entry$family_code),
      entry$default_tier
    )
    ## Every declared tier is accepted; anything else fails closed.
    for (tier in entry$tiers) {
      expect_identical(
        .va_r3_resolve_eval_method(tier, entry$family_code), tier
      )
    }
    for (tier in setdiff(c("gh", "jj"), entry$tiers)) {
      expect_error(
        .va_r3_resolve_eval_method(tier, entry$family_code),
        "not implemented for the"
      )
    }
    ## objective_type reports the resolved bound, never a hardcoded one.
    expect_identical(
      .va_r3_objective_type(.va_r3_resolve_eval_method("auto", entry$family_code)),
      if (identical(entry$default_tier, "jj")) "ELBO_JJ" else "ELBO_GH"
    )
  }

  ## A family code with no registry entry is an error, not a silent default.
  expect_error(.va_r3_family_entry(99L), "no registry entry")
})

test_that("R3 JJ bound over-estimates the softplus expectation and is exact at zero variance", {
  ## The Jaakkola-Jordan/PG bound is not a quadrature rule, so it must not be
  ## held to the oracle grid above. Its contract is an INEQUALITY: it bounds
  ## E[softplus(eta)] from ABOVE, which is what makes the ELBO -- which
  ## subtracts n * softplus_expectation -- a genuine lower bound. It is tight
  ## at v = 0, where xi = |mu| and the bound collapses to softplus(mu).
  validated <- .va_r3_validate_data(
    y = 1L, n_trials = 3L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = 0, theta_rr = 0, m = matrix(0, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters,
                               eval_method = "jj")
  beta_index <- which(names(obj$par) == "beta")
  theta_index <- which(names(obj$par) == "theta_rr")
  stable_softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
  for (mu in c(-20, -5, 0, 5, 20)) {
    for (variance in c(0, 1e-8, 1e-4, 0.1, 1, 4)) {
      p <- obj$par
      p[beta_index] <- mu
      p[theta_index] <- sqrt(variance)
      observed <- obj$report(p)$softplus_expectation_by_obs[1L]
      exact <- if (variance == 0) stable_softplus(mu) else {
        stats::integrate(function(z) {
          stable_softplus(mu + sqrt(variance) * z) * stats::dnorm(z)
        }, -Inf, Inf, rel.tol = 1e-13)$value
      }
      ## Upper bound, up to floating-point slack.
      expect_gt(observed - exact, -1e-10)
      if (variance == 0) {
        ## Tight at v = 0.
        expect_lt(abs(observed - exact), 1e-10)
      }
    }
  }
})

test_that("R3 fails closed outside the certified projected-variance domain", {
  fit <- .va_r3_fit(
    y = c(1, 2), n_trials = c(1L, 1L), X = matrix(1, 2L, 1L),
    unit_id = c(1L, 1L), trait_id = 1:2, q = 1L, H = 61L,
    fixed_global = list(beta = 0, theta_rr = c(3, 3)),
    family = "gaussian_anchor", gaussian_sd = 100,
    rank_source = "fixed_fixture"
  )
  expect_identical(fit$status, "failed_variance_domain")
  expect_false(fit$health$variance_domain_ok)
  expect_gt(fit$health$max_projected_variance, 4)
})

test_that("R3 variational Cholesky unpack matches TMB column-major packing", {
  N <- 2L; q <- 3L
  diag_values <- matrix(c(1, 2, 3, 4, 5, 6), N, q)
  off <- matrix(c(0.1, 0.4, 0.2, 0.5, 0.3, 0.6), N, 3L)
  unpacked <- .va_r3_unpack_variational_chol(log(diag_values), off, N, q)
  expect_equal(unpacked[, , 1L],
               matrix(c(1, 0.1, 0.2, 0, 3, 0.3, 0, 0, 5), 3L, 3L),
               tolerance = 1e-15)
  expect_equal(unpacked[, , 2L],
               matrix(c(2, 0.4, 0.5, 0, 4, 0.6, 0, 0, 6), 3L, 3L),
               tolerance = 1e-15)
})

test_that("R3 q>1 projected variances and KL match direct matrix algebra", {
  N <- 2L; T <- 3L; q <- 2L
  X <- model.matrix(~ 0 + factor(rep(seq_len(T), N), levels = seq_len(T)))
  validated <- .va_r3_validate_data(
    y = c(1L, 2L, 3L, 0L, 2L, 1L), n_trials = rep(4L, N * T), X = X,
    unit_id = rep(seq_len(N), each = T), trait_id = rep(seq_len(T), N), q = q
  )
  Lambda <- matrix(c(0.7, 0, -0.2, 0.5, 0.3, -0.4), T, q, byrow = TRUE)
  parameters <- list(
    beta = c(-0.2, 0.1, 0.3), theta_rr = .va_r3_pack_theta_rr(Lambda),
    m = matrix(c(0.1, -0.2, 0.3, 0.05), N, q),
    log_L_diag = matrix(log(c(0.8, 1.1, 0.9, 0.7)), N, q),
    L_off = matrix(c(0.15, -0.25), N, 1L)
  )
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters)
  report <- obj$report(obj$par)
  L <- .va_r3_unpack_variational_chol(
    parameters$log_L_diag, parameters$L_off, N, q
  )
  expected_v <- vapply(seq_len(N * T), function(r) {
    i <- validated$unit_id[r] + 1L
    lambda <- Lambda[validated$trait_id[r] + 1L, ]
    drop(crossprod(lambda, tcrossprod(L[, , i]) %*% lambda))
  }, numeric(1))
  expected_kl <- vapply(seq_len(N), function(i) {
    S <- tcrossprod(L[, , i])
    0.5 * (sum(diag(S)) + sum(parameters$m[i, ]^2) -
             as.numeric(determinant(S, logarithm = TRUE)$modulus) - q)
  }, numeric(1))
  expect_equal(report$v_by_obs, expected_v, tolerance = 1e-12)
  expect_equal(report$kl_by_unit, expected_kl, tolerance = 1e-12)
})

test_that("R3 scalar ELBO, KL sign, and autodiff match independent calculations", {
  validated <- .va_r3_validate_data(
    y = 3L, n_trials = 8L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = -0.3, theta_rr = 0.7, m = matrix(0.2, 1L, 1L),
    log_L_diag = matrix(log(0.8), 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  ## expected_softplus below is an exact integrate() calculation, so the
  ## objective must use quadrature; binomial "auto" resolves to the JJ bound,
  ## which over-estimates it by construction.
  obj <- .va_r3_make_objective(validated, H = 25L, parameters = parameters,
                               eval_method = "gh")
  report <- obj$report(obj$par)
  mu <- -0.3 + 0.7 * 0.2
  variance <- 0.7^2 * 0.8^2
  expected_softplus <- stats::integrate(
    function(z) {
      eta <- mu + sqrt(variance) * z
      (pmax(eta, 0) + log1p(exp(-abs(eta)))) * stats::dnorm(z)
    },
    -Inf, Inf, rel.tol = 1e-13
  )$value
  expected_loglik <- lchoose(8, 3) + 3 * mu - 8 * expected_softplus
  expected_kl <- 0.5 * (0.2^2 + 0.8^2 - log(0.8^2) - 1)
  expect_equal(report$expected_loglik, expected_loglik, tolerance = 1e-10)
  expect_equal(report$total_kl, expected_kl, tolerance = 1e-12)
  expect_equal(obj$fn(obj$par), -(expected_loglik - expected_kl), tolerance = 1e-10)

  analytic <- obj$gr(obj$par)
  numeric <- vapply(seq_along(obj$par), function(j) {
    h <- 1e-6 * max(1, abs(obj$par[j]))
    plus <- minus <- obj$par
    plus[j] <- plus[j] + h
    minus[j] <- minus[j] - h
    (obj$fn(plus) - obj$fn(minus)) / (2 * h)
  }, numeric(1))
  expect_lt(max(abs(analytic - numeric) / pmax(1, abs(numeric))), 1e-5)
})

test_that("R3 small-variance branch is value- and derivative-continuous", {
  validated <- .va_r3_validate_data(
    y = 1L, n_trials = 3L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = 0.4, theta_rr = 1e-3, m = matrix(0, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  obj <- .va_r3_make_objective(validated, H = 25L, parameters = parameters)
  theta_index <- which(names(obj$par) == "theta_rr")
  evaluate <- function(theta) {
    p <- obj$par
    p[theta_index] <- theta
    c(value = obj$fn(p), gradient = obj$gr(p)[theta_index])
  }
  below <- evaluate(1e-3 * (1 - 1e-7))
  above <- evaluate(1e-3 * (1 + 1e-7))
  expect_lt(abs(below["value"] - above["value"]), 1e-9)
  expect_lt(abs(below["gradient"] - above["gradient"]), 1e-7)
})

test_that("R3 small-variance expansion is insensitive across switch candidates", {
  rule <- .va_r3_gh_rule(61L)
  stable_softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
  expansion <- function(mu, v) {
    p <- plogis(mu); pq <- p * (1 - p)
    f2 <- pq
    f4 <- pq * (1 - 6 * p + 6 * p^2)
    f6 <- pq * (1 - 30 * p + 150 * p^2 - 240 * p^3 + 120 * p^4)
    stable_softplus(mu) + v * f2 / 2 + v^2 * f4 / 8 + v^3 * f6 / 48
  }
  quadrature <- function(mu, v) {
    sum(rule$weights * stable_softplus(mu + sqrt(2 * v) * rule$nodes)) / sqrt(pi)
  }
  for (mu in c(-10, -2, 0, 2, 10)) {
    for (v in c(1e-8, 1e-7, 1e-6, 1e-5, 1e-4)) {
      expect_lt(abs(expansion(mu, v) - quadrature(mu, v)), 1e-10)
    }
  }
})

.va_r3_gaussian_fixture <- function() {
  N <- 4L; T <- 3L; q <- 2L
  beta <- c(0.2, -0.15, 0.35)
  Lambda <- matrix(c(0.8, 0, -0.3, 0.55, 0.25, -0.4), T, q, byrow = TRUE)
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  scores <- matrix(c(-0.5, 0.3, 0.2, -0.4, 0.7, 0.1, -0.2, -0.6), N, q, byrow = TRUE)
  y <- drop(X %*% beta) +
    rowSums(Lambda[trait, , drop = FALSE] * scores[unit, , drop = FALSE])
  list(N = N, T = T, q = q, beta = beta, Lambda = Lambda, unit = unit,
       trait = trait, X = X, y = y, sd = 0.7)
}

test_that("R3 Gaussian variational posterior equals the analytic posterior", {
  z <- .va_r3_gaussian_fixture()
  fit <- .va_r3_fit(
    y = z$y, n_trials = rep(1L, length(z$y)), X = z$X,
    unit_id = z$unit, trait_id = z$trait, q = z$q,
    family = "gaussian_anchor", gaussian_sd = z$sd, H = 15L,
    fixed_global = list(beta = z$beta,
                        theta_rr = .va_r3_pack_theta_rr(z$Lambda))
  )
  expect_identical(fit$status, "healthy")
  V <- solve(diag(z$q) + crossprod(z$Lambda) / z$sd^2)
  residual <- matrix(z$y - drop(z$X %*% z$beta), z$T, z$N)
  analytic_m <- t(vapply(seq_len(z$N), function(i) {
    drop(V %*% crossprod(z$Lambda, residual[, i]) / z$sd^2)
  }, numeric(z$q)))
  expect_equal(fit$report$m, analytic_m, tolerance = 2e-7)
  for (i in seq_len(z$N)) {
    Si <- matrix(fit$report$S_flat[i, ], z$q, z$q, byrow = TRUE)
    expect_equal(Si, V, tolerance = 2e-7)
  }
  expect_lt(max(abs(fit$objective$gr(fit$best$par))), 1e-6)
  C <- tcrossprod(z$Lambda) + diag(z$sd^2, z$T)
  log_det_C <- as.numeric(determinant(C, logarithm = TRUE)$modulus)
  analytic_nll <- sum(vapply(seq_len(z$N), function(i) {
    r <- residual[, i]
    0.5 * (z$T * log(2 * pi) + log_det_C + drop(crossprod(r, solve(C, r))))
  }, numeric(1)))
  expect_equal(fit$report$negative_elbo, analytic_nll, tolerance = 1e-8)
})

test_that("R3 Gaussian variational gradients match analytic matrix derivatives", {
  z <- .va_r3_gaussian_fixture()
  validated <- .va_r3_validate_data(
    z$y, rep(1L, length(z$y)), z$X, z$unit, z$trait, z$q,
    family = "gaussian_anchor", link = "identity", gaussian_sd = z$sd
  )
  parameters <- list(
    beta = z$beta, theta_rr = .va_r3_pack_theta_rr(z$Lambda),
    m = matrix(c(-0.1, 0.2, 0.3, -0.2, 0.05, 0.15, -0.25, 0.1), z$N, z$q),
    log_L_diag = matrix(c(-0.2, 0.1, 0.05, -0.1, 0.15, -0.05, 0.08, -0.12),
                        z$N, z$q),
    L_off = matrix(c(0.1, -0.05, 0.08, -0.12), z$N, 1L)
  )
  fixed <- list(beta = z$beta, theta_rr = .va_r3_pack_theta_rr(z$Lambda))
  obj <- .va_r3_make_objective(
    validated, H = 15L, parameters = parameters, fixed_global = fixed
  )
  observed <- obj$gr(obj$par)
  A <- diag(z$q) + crossprod(z$Lambda) / z$sd^2
  residual <- matrix(z$y - drop(z$X %*% z$beta), z$T, z$N)
  expected_m <- matrix(NA_real_, z$N, z$q)
  expected_rho <- matrix(NA_real_, z$N, z$q)
  expected_off <- matrix(NA_real_, z$N, 1L)
  L <- .va_r3_unpack_variational_chol(
    parameters$log_L_diag, parameters$L_off, z$N, z$q
  )
  for (i in seq_len(z$N)) {
    expected_m[i, ] <- A %*% parameters$m[i, ] -
      crossprod(z$Lambda, residual[, i]) / z$sd^2
    G <- A %*% L[, , i] - solve(t(L[, , i]))
    expected_rho[i, ] <- diag(G) * diag(L[, , i])
    expected_off[i, 1L] <- G[2L, 1L]
  }
  expect_equal(unname(observed[names(obj$par) == "m"]), as.vector(expected_m),
               tolerance = 1e-10)
  expect_equal(unname(observed[names(obj$par) == "log_L_diag"]),
               as.vector(expected_rho), tolerance = 1e-10)
  expect_equal(unname(observed[names(obj$par) == "L_off"]),
               as.vector(expected_off), tolerance = 1e-10)
})

.va_r3_complete_fixture <- function(q, seed) {
  set.seed(seed)
  N <- if (q == 1L) 24L else 30L
  T <- q + 1L
  trials <- 24L
  beta <- seq(-0.35, 0.35, length.out = T)
  Lambda <- matrix(0, T, q)
  Lambda[row(Lambda) >= col(Lambda)] <-
    if (q == 1L) c(0.75, -0.45) else c(0.72, 0.28, -0.35, 0.58, 0.22)
  score <- matrix(rnorm(N * q), N, q)
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  eta <- beta[trait] + rowSums(
    Lambda[trait, , drop = FALSE] * score[unit, , drop = FALSE]
  )
  y <- rbinom(N * T, trials, plogis(eta))
  data.frame(
    succ = y, fail = trials - y,
    trait = factor(sprintf("t%02d", trait)),
    unit = factor(sprintf("u%03d", unit))
  )
}

.va_r3_fit_complete_fixture <- function(q, seed) {
  dat <- .va_r3_complete_fixture(q, seed)
  suppressWarnings(gllvmTMB::gllvmTMB(
    stats::as.formula(paste0(
      "cbind(succ, fail) ~ 0 + trait + ",
      "latent(0 + trait | unit, d = ", q, ", unique = FALSE)"
    )),
    data = dat, family = binomial(), unit = "unit",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 2L, init_jitter = 0.02, se = FALSE)
  ))
}

.va_r3_r2_comparison <- function(q, seed) {
  ml_fit <- .va_r3_fit_complete_fixture(q, seed)
  stopifnot(ml_fit$opt$convergence == 0L)
  d <- ml_fit$tmb_obj$env$data
  par <- ml_fit$tmb_obj$env$last.par.best
  beta <- unname(par[names(par) == "b_fix"])
  Lambda <- ml_fit$report$Lambda_B
  y <- d$y
  trials <- d$n_trials
  unit <- d$site_id + 1L
  trait <- d$trait_id + 1L
  X <- d$X_fix
  validated <- .va_r3_validate_data(y, trials, X, unit, trait, q)
  identity <- list(
    y = identical(validated$y, as.numeric(d$y)),
    trials = identical(validated$n_trials, as.integer(d$n_trials)),
    X = identical(validated$X, unname(d$X_fix)),
    unit = identical(validated$unit_id, as.integer(d$site_id)),
    trait = identical(validated$trait_id, as.integer(d$trait_id))
  )
  aghq_data <- list(
    y = y, n_trials = trials, eta_fixed = drop(X %*% beta),
    loading = Lambda[trait, , drop = FALSE], trait_id = trait - 1L,
    unit = unit, q = q
  )
  nodes <- if (q == 1L) 25L else 9L
  aghq <- .o3_r2_evaluate(aghq_data, nodes)
  fixed_global <- list(beta = beta, theta_rr = .va_r3_pack_theta_rr(Lambda))
  va61 <- .va_r3_fit(
    y, trials, X, unit, trait, q, H = 61L,
    fixed_global = fixed_global, rank_source = "fixed_fixture"
  )
  ladder <- lapply(c(15L, 25L), function(H) {
    obj <- .va_r3_make_objective(
      validated, H = H, parameters = .va_r3_default_parameters(validated, 1L),
      fixed_global = fixed_global
    )
    list(objective = obj$fn(va61$best$par), report = obj$report(va61$best$par))
  })
  aghq_mean <- matrix(NA_real_, nrow = max(unit), ncol = q)
  aghq_cov <- vector("list", max(unit))
  for (i in seq_len(max(unit))) {
    mm <- subset(aghq$moments, unit_id == i & moment == "mean")
    cc <- subset(aghq$moments, unit_id == i & moment == "covariance")
    aghq_mean[i, mm$row] <- mm$value
    aghq_cov[[i]] <- matrix(cc$value, q, q)
  }
  va_cov <- lapply(seq_len(max(unit)), function(i) {
    matrix(va61$report$S_flat[i, ], q, q, byrow = TRUE)
  })
  cov_rel <- vapply(seq_len(max(unit)), function(i) {
    sqrt(sum((va_cov[[i]] - aghq_cov[[i]])^2)) /
      sqrt(sum(aghq_cov[[i]]^2))
  }, numeric(1))
  list(
    va61 = va61, aghq = aghq, identity = identity,
    mean_rmse = sqrt(mean((va61$report$m - aghq_mean)^2)),
    cov_rel = cov_rel,
    bound_gap = aghq$objective + va61$report$elbo,
    quadrature_gap = abs(ladder[[2L]]$objective - va61$report$negative_elbo),
    quadrature_obs_gap = max(abs(ladder[[2L]]$report$expected_loglik_by_obs -
                                     va61$report$expected_loglik_by_obs))
  )
}

test_that("R3 fixed-coordinate q=1/q=2 cells pass the AGHQ admission gate", {
  comparisons <- list(
    q1 = .va_r3_r2_comparison(1L, 20260719L),
    q2 = .va_r3_r2_comparison(2L, 20260720L)
  )
  for (x in comparisons) {
    expect_true(all(unlist(x$identity)))
    expect_identical(x$va61$status, "healthy")
    expect_identical(x$va61$rank_source, "fixed_fixture")
    expect_identical(x$va61$health$attempted_starts, 4L)
    expect_gte(x$va61$health$healthy_starts, 3L)
    expect_true(isTRUE(x$va61$best$healthy))
    expect_lte(x$bound_gap, 1e-6)
    expect_lt(x$mean_rmse, 0.05)
    expect_lt(stats::median(x$cov_rel), 0.10)
    expect_lt(max(x$cov_rel), 0.25)
    expect_lt(x$quadrature_gap, 1e-4)
    expect_lt(x$quadrature_obs_gap, 1e-8)
  }
})

test_that("R3 reasserts the landed one-node O3/Laplace anchors", {
  q1 <- o3_gllvm_unit_hook_self_test()
  q2 <- o3_q2_gllvm_unit_self_test()
  expect_lt(abs(q1$laplace_difference), 1e-6)
  expect_lt(abs(q2$laplace_difference), 1e-6)
})
