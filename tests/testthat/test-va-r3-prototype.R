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
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters)
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
  obj <- .va_r3_make_objective(validated, H = 25L, parameters = parameters)
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
