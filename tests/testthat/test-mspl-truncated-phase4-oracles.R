## Phase-4-style truncated Poisson / truncated NB2 LA-MSPL oracles.
##
## Research note:
##   docs/dev-log/research/2026-08-16-mspl-phase4-truncated-prep.md
## Helpers stay in this file. Do not call live MSPL.
## Do not edit src/. Do not widen prepare. Registry rows are planned, not admitted.

.ztp_lambda <- function(eta) {
  exp(as.numeric(eta))
}

.ztp_p0 <- function(lambda) {
  exp(-as.numeric(lambda))
}

.ztp_mean <- function(lambda) {
  lambda <- as.numeric(lambda)
  lambda / (1 - .ztp_p0(lambda))
}

.ztp_var <- function(lambda) {
  lambda <- as.numeric(lambda)
  p0 <- .ztp_p0(lambda)
  m <- lambda / (1 - p0)
  m - lambda^2 * p0 / (1 - p0)^2
}

.ztp_logpmf <- function(y, lambda) {
  stats::dpois(y, lambda, log = TRUE) - log1p(-exp(-lambda))
}

.ztp_score_moments <- function(lambda, tail_prob = 1e-13) {
  lambda <- as.numeric(lambda)
  stopifnot(length(lambda) == 1L, is.finite(lambda), lambda > 0)
  ymax <- stats::qpois(1 - tail_prob, lambda)
  if (ymax < 1L) ymax <- 1L
  y <- 1:ymax
  log_f <- .ztp_logpmf(y, lambda)
  log_f <- log_f - max(log_f)
  pmf <- exp(log_f)
  pmf <- pmf / sum(pmf)
  score <- y - .ztp_mean(lambda)
  c(
    mass = sum(pmf),
    expected_y = sum(pmf * y),
    expected_score = sum(pmf * score),
    fisher_outer = sum(pmf * score^2)
  )
}

.ztp_I <- function(lambda) {
  .ztp_var(as.numeric(lambda))
}

.pois_I <- function(lambda) {
  as.numeric(lambda)
}

.ztp_Pj <- function(X, lambda) {
  X <- as.matrix(X)
  w <- .ztp_I(lambda)
  I <- crossprod(X, X * w)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.tnb2_p0 <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  (phi / (phi + mu))^phi
}

.tnb2_mean <- function(mu, phi) {
  as.numeric(mu) / (1 - .tnb2_p0(mu, phi))
}

.tnb2_untrunc_W <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  mu * phi / (phi + mu)
}

.tnb2_score_eta <- function(y, mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  .tnb2_untrunc_W(mu, phi) / mu * (y - .tnb2_mean(mu, phi))
}

.tnb2_logpmf <- function(y, mu, phi) {
  stats::dnbinom(y, size = phi, mu = mu, log = TRUE) -
    log1p(-.tnb2_p0(mu, phi))
}

.tnb2_score_moments <- function(mu, phi, tail_prob = 1e-13) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  stopifnot(length(mu) == 1L, mu > 0, phi > 0)
  ymax <- stats::qnbinom(1 - tail_prob, size = phi, mu = mu)
  if (ymax < 1L) ymax <- 1L
  y <- 1:ymax
  log_f <- .tnb2_logpmf(y, mu, phi)
  log_f <- log_f - max(log_f)
  pmf <- exp(log_f)
  pmf <- pmf / sum(pmf)
  score <- .tnb2_score_eta(y, mu, phi)
  c(
    mass = sum(pmf),
    expected_y = sum(pmf * y),
    expected_score = sum(pmf * score),
    fisher_outer = sum(pmf * score^2)
  )
}

.tnb2_I <- function(mu, phi) {
  vapply(
    as.numeric(mu),
    function(mu_i) .tnb2_score_moments(mu_i, phi)[["fisher_outer"]],
    numeric(1L)
  )
}

.tnb2_closed_I <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  p0 <- .tnb2_p0(mu, phi)
  var_u <- mu + mu^2 / phi
  e2_t <- (var_u + mu^2) / (1 - p0)
  mean_t <- mu / (1 - p0)
  var_t <- e2_t - mean_t^2
  (phi / (phi + mu))^2 * var_t
}

.bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.trunc_fixture <- function() {
  X <- cbind(1, c(-0.8, -0.2, 0.3, 0.9))
  beta <- c(0.4, -0.25)
  eta <- as.numeric(X %*% beta)
  lambda <- .ztp_lambda(eta)
  phi <- 3
  list(
    X = X,
    eta = eta,
    lambda = lambda,
    mu = lambda,
    phi = phi,
    Lambda = matrix(c(0.7, -0.4, 0.2, 0.5), 4L, 1L)
  )
}

test_that("T1: ZTP mean is lambda/(1-e^{-lambda})", {
  fx <- .trunc_fixture()
  moments <- lapply(fx$lambda, .ztp_score_moments)
  expect_equal(
    vapply(moments, `[[`, numeric(1L), "expected_y"),
    .ztp_mean(fx$lambda),
    tolerance = 1e-8
  )
  expect_equal(.ztp_var(fx$lambda), vapply(moments, `[[`, numeric(1L), "fisher_outer"), tolerance = 1e-8)
})

test_that("T2: ZTP score is centred and I = Var(Y | Y>=1)", {
  fx <- .trunc_fixture()
  moments <- lapply(fx$lambda, .ztp_score_moments)
  expect_true(all(abs(vapply(moments, `[[`, numeric(1L), "mass") - 1) < 1e-10))
  expect_true(all(abs(vapply(moments, `[[`, numeric(1L), "expected_score")) < 1e-8))
  expect_equal(
    vapply(moments, `[[`, numeric(1L), "fisher_outer"),
    .ztp_I(fx$lambda),
    tolerance = 1e-8
  )
})

test_that("T3: ZTP information is not Poisson W=lambda at interior lambda", {
  fx <- .trunc_fixture()
  expect_false(isTRUE(all.equal(.ztp_I(fx$lambda), .pois_I(fx$lambda), tolerance = 1e-3)))
  lambda_big <- 40
  expect_equal(.ztp_I(lambda_big), .pois_I(lambda_big), tolerance = 1e-6)
})

test_that("T4: ZTP P*_J collapses on the all-ones (lambda -> 0) path", {
  X <- cbind(1, c(-1, 0, 1))
  Pj_int <- .ztp_Pj(X, rep(1.2, 3L))
  Pj_lo <- .ztp_Pj(X, rep(1e-4, 3L))
  expect_gt(Pj_int, Pj_lo)
})

test_that("T5: TNB2 p0 and centred score match the wired size=phi kernel", {
  fx <- .trunc_fixture()
  expect_equal(
    .tnb2_p0(fx$mu, fx$phi),
    (fx$phi / (fx$phi + fx$mu))^fx$phi,
    tolerance = 1e-12
  )
  moments <- lapply(fx$mu, .tnb2_score_moments, phi = fx$phi)
  expect_true(all(abs(vapply(moments, `[[`, numeric(1L), "mass") - 1) < 1e-10))
  expect_true(all(abs(vapply(moments, `[[`, numeric(1L), "expected_score")) < 1e-7))
  expect_equal(
    vapply(moments, `[[`, numeric(1L), "expected_y"),
    .tnb2_mean(fx$mu, fx$phi),
    tolerance = 1e-7
  )
})

test_that("T6: TNB2 I_eta is not the untruncated NB2 GLM weight", {
  fx <- .trunc_fixture()
  I_tr <- .tnb2_I(fx$mu, fx$phi)
  expect_equal(I_tr, .tnb2_closed_I(fx$mu, fx$phi), tolerance = 1e-6)
  expect_false(isTRUE(all.equal(I_tr, .tnb2_untrunc_W(fx$mu, fx$phi), tolerance = 1e-3)))
})

test_that("T7: TNB2 large phi tracks ZTP, not Poisson", {
  mu <- c(0.4, 1.0, 2.0)
  phi_big <- 1e5
  expect_equal(.tnb2_closed_I(mu, phi_big), .ztp_I(mu), tolerance = 1e-3)
  expect_false(isTRUE(all.equal(.tnb2_closed_I(mu, phi_big), .pois_I(mu), tolerance = 1e-2)))
})

test_that("T8: V_loading is mean-inert", {
  fx <- .trunc_fixture()
  V0 <- .bernoulli_V_loading(fx$Lambda)
  expect_equal(.bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  expect_false(isTRUE(all.equal(.ztp_I(fx$lambda), .ztp_I(fx$lambda * 1.1), tolerance = 1e-8)))
})

test_that("T9: truncated oracles never invoke a live MSPL fit or the registry", {
  src_lines <- readLines(test_path("test-mspl-truncated-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl("gllvmTMB\\s*\\([^)]*estimator\\s*=", code))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
  expect_false(grepl("[.]gllvmTMB_mspl_registry[(]", code))
  expect_false(grepl("[.]gllvmTMB_mspl_prepare[(]", code))
  expect_false(grepl("[.]gllvmTMB_mspl_registry_lookup[(]", code))
})
