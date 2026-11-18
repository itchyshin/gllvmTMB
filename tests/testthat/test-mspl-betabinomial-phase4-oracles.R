## Phase-4-style betabinomial LA-MSPL oracles — pure R, not admission.
##
## Research note:
##   docs/dev-log/research/2026-08-16-mspl-phase4-betabinomial-prep.md
## Helpers stay in this file. Do not call live MSPL on betabinomial.
## Do not edit src/. Do not widen .gllvmTMB_mspl_prepare().
## Registry row is planned, not admitted.

.bb_mu <- function(eta) {
  stats::plogis(as.numeric(eta))
}

.bb_var <- function(N, mu, phi) {
  N <- as.numeric(N)
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  N * mu * (1 - mu) * (phi + N) / (phi + 1)
}

.bb_logpmf <- function(y, N, mu, phi) {
  a <- as.numeric(mu) * as.numeric(phi)
  b <- (1 - as.numeric(mu)) * as.numeric(phi)
  N <- as.numeric(N)
  y <- as.numeric(y)
  lgamma(N + 1) + lgamma(y + a) + lgamma(N - y + b) + lgamma(a + b) -
    lgamma(y + 1) - lgamma(N - y + 1) - lgamma(a) - lgamma(b) -
    lgamma(N + a + b)
}

.bb_score_eta <- function(y, N, mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  N <- as.numeric(N)
  y <- as.numeric(y)
  a <- mu * phi
  b <- (1 - mu) * phi
  phi * mu * (1 - mu) * (
    digamma(y + a) - digamma(a) - digamma(N - y + b) + digamma(b)
  )
}

.bb_dscore_deta <- function(y, N, mu, phi) {
  ## Finite difference of s_eta at the same (y, N, phi). Used only to
  ## check the expected-Hessian form against the outer product.
  eps <- 1e-6
  eta <- stats::qlogis(as.numeric(mu))
  s_up <- .bb_score_eta(y, N, .bb_mu(eta + eps), phi)
  s_dn <- .bb_score_eta(y, N, .bb_mu(eta - eps), phi)
  (s_up - s_dn) / (2 * eps)
}

.bb_score_moments <- function(N, mu, phi) {
  N <- as.integer(N)
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  stopifnot(N >= 1L, is.finite(mu), mu > 0, mu < 1, is.finite(phi), phi > 0)
  y <- 0:N
  log_f <- .bb_logpmf(y, N, mu, phi)
  log_f <- log_f - max(log_f)
  pmf <- exp(log_f)
  pmf <- pmf / sum(pmf)
  score <- .bb_score_eta(y, N, mu, phi)
  observed_info <- -.bb_dscore_deta(y, N, mu, phi)
  c(
    mass = sum(pmf),
    expected_y = sum(pmf * y),
    expected_score = sum(pmf * score),
    fisher_outer = sum(pmf * score^2),
    fisher_hessian = sum(pmf * observed_info)
  )
}

.bb_exact_W <- function(N, mu, phi) {
  vapply(
    seq_along(mu),
    function(i) .bb_score_moments(N[i], mu[i], phi)[["fisher_outer"]],
    numeric(1L)
  )
}

.bb_quasi_W <- function(N, mu, phi) {
  N <- as.numeric(N)
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  N * mu * (1 - mu) * (phi + 1) / (phi + N)
}

.bb_exact_I <- function(X, N, mu, phi) {
  X <- as.matrix(X)
  w <- .bb_exact_W(N, mu, phi)
  crossprod(X, X * w)
}

.bb_quasi_I <- function(X, N, mu, phi) {
  X <- as.matrix(X)
  w <- .bb_quasi_W(N, mu, phi)
  crossprod(X, X * w)
}

.bb_exact_Pj <- function(X, N, mu, phi) {
  I <- .bb_exact_I(X, N, mu, phi)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.bb_bernoulli_W <- function(mu) {
  mu <- as.numeric(mu)
  mu * (1 - mu)
}

.bb_binom_W <- function(N, mu) {
  as.numeric(N) * .bb_bernoulli_W(mu)
}

## Ferrari & Cribari-Neto Beta (continuous) weight — contrast only.
.bb_ferrari_W <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  a <- mu * phi
  b <- (1 - mu) * phi
  I_mu <- phi * (trigamma(a) + trigamma(b))
  dmu <- mu * (1 - mu)
  I_mu * dmu * dmu
}

.bb_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.bb_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.bb_fixture <- function() {
  X <- cbind(1, c(-1.0, -0.5, 0.5, 1.0))
  beta <- c(0.15, -0.35)
  eta <- as.numeric(X %*% beta)
  mu <- .bb_mu(eta)
  N <- rep(8L, 4L)
  phi <- 4
  list(
    X = X,
    beta = beta,
    eta = eta,
    mu = mu,
    N = N,
    phi = phi,
    n_rows = nrow(X),
    p_free = ncol(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L),
    S_diag = c(0.4, 0.5, 0.6, 0.7),
    psi = c(0.2, 0.25, 0.3, 0.35)
  )
}

test_that("B1: BB mean is N*mu; variance carries (phi+N)/(phi+1)", {
  fx <- .bb_fixture()
  moments <- Map(.bb_score_moments, fx$N, fx$mu, MoreArgs = list(phi = fx$phi))
  expect_equal(
    vapply(moments, `[[`, numeric(1L), "expected_y"),
    fx$N * fx$mu,
    tolerance = 1e-10
  )
  expect_equal(
    .bb_var(fx$N, fx$mu, fx$phi),
    fx$N * fx$mu * (1 - fx$mu) * (fx$phi + fx$N) / (fx$phi + 1),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(
    .bb_var(fx$N, fx$mu, fx$phi),
    .bb_binom_W(fx$N, fx$mu),
    tolerance = 1e-4
  )))
})

test_that("B2: exact BB Fisher comes from the full finite pmf", {
  fx <- .bb_fixture()
  moments <- Map(.bb_score_moments, fx$N, fx$mu, MoreArgs = list(phi = fx$phi))
  expect_true(all(abs(vapply(moments, `[[`, numeric(1L), "mass") - 1) < 1e-12))
  expect_true(all(abs(vapply(moments, `[[`, numeric(1L), "expected_score")) < 1e-8))
  outer <- vapply(moments, `[[`, numeric(1L), "fisher_outer")
  hess <- vapply(moments, `[[`, numeric(1L), "fisher_hessian")
  expect_equal(outer, hess, tolerance = 5e-5)
  expect_true(all(outer > 0))
})

test_that("B3: quasi IRLS weight is not the exact Jeffreys atom", {
  fx <- .bb_fixture()
  w_exact <- .bb_exact_W(fx$N, fx$mu, fx$phi)
  w_quasi <- .bb_quasi_W(fx$N, fx$mu, fx$phi)
  expect_false(isTRUE(all.equal(w_exact, w_quasi, tolerance = 1e-3)))
  expect_false(isTRUE(all.equal(
    .bb_exact_Pj(fx$X, fx$N, fx$mu, fx$phi),
    0.5 * as.numeric(determinant(.bb_quasi_I(fx$X, fx$N, fx$mu, fx$phi), logarithm = TRUE)$modulus),
    tolerance = 1e-3
  )))
})

test_that("B4: N=1 is Bernoulli and phi-inert", {
  mu <- c(0.2, 0.5, 0.8)
  N <- rep(1L, 3L)
  w_lo <- .bb_exact_W(N, mu, phi = 0.5)
  w_hi <- .bb_exact_W(N, mu, phi = 20)
  expect_equal(w_lo, .bb_bernoulli_W(mu), tolerance = 1e-8)
  expect_equal(w_hi, .bb_bernoulli_W(mu), tolerance = 1e-8)
  expect_equal(w_lo, w_hi, tolerance = 1e-8)
})

test_that("B5: large phi recovers binomial quasi weight", {
  fx <- .bb_fixture()
  phi_big <- 1e8
  expect_equal(
    .bb_quasi_W(fx$N, fx$mu, phi_big),
    .bb_binom_W(fx$N, fx$mu),
    tolerance = 1e-6
  )
  w_exact <- .bb_exact_W(fx$N, fx$mu, phi_big)
  expect_equal(w_exact, .bb_binom_W(fx$N, fx$mu), tolerance = 1e-3)
})

test_that("B6: Ferrari Beta weight is not a BB atom", {
  fx <- .bb_fixture()
  expect_false(isTRUE(all.equal(
    .bb_ferrari_W(fx$mu, fx$phi),
    .bb_exact_W(fx$N, fx$mu, fx$phi),
    tolerance = 1e-3
  )))
  expect_false(isTRUE(all.equal(
    .bb_ferrari_W(fx$mu, fx$phi),
    .bb_quasi_W(fx$N, fx$mu, fx$phi),
    tolerance = 1e-3
  )))
})

test_that("B7: all-zero / all-N mean paths collapse P*_J", {
  X <- cbind(1, c(-1, 0, 1))
  N <- rep(6L, 3L)
  phi <- 3
  mu_int <- .bb_mu(c(-0.2, 0, 0.2))
  mu_lo <- rep(1e-6, 3L)
  mu_hi <- rep(1 - 1e-6, 3L)
  Pj_int <- .bb_exact_Pj(X, N, mu_int, phi)
  Pj_lo <- .bb_exact_Pj(X, N, mu_lo, phi)
  Pj_hi <- .bb_exact_Pj(X, N, mu_hi, phi)
  expect_gt(Pj_int, Pj_lo)
  expect_gt(Pj_int, Pj_hi)
})

test_that("B8: V_loading and Hirose are (mu, phi, N)-inert", {
  fx <- .bb_fixture()
  V0 <- .bb_bernoulli_V_loading(fx$Lambda)
  H0 <- .bb_hirose_atom(fx$S_diag, fx$psi)
  expect_equal(.bb_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  expect_equal(.bb_hirose_atom(fx$S_diag, fx$psi), H0, tolerance = 0)
  expect_false(isTRUE(all.equal(
    .bb_exact_W(fx$N, fx$mu, fx$phi),
    .bb_exact_W(fx$N, fx$mu, fx$phi + 1),
    tolerance = 1e-8
  )))
  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + 1e-4
  expect_gt(abs(.bb_bernoulli_V_loading(Lambda_up) - V0), 1e-8)
})

test_that("B9: Phase-4 BB oracles never invoke a live MSPL fit or the registry", {
  src_lines <- readLines(test_path("test-mspl-betabinomial-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl("gllvmTMB\\s*\\([^)]*estimator\\s*=", code))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
  expect_false(grepl("[.]gllvmTMB_mspl_registry[(]", code))
  expect_false(grepl("[.]gllvmTMB_mspl_prepare[(]", code))
  expect_false(grepl("[.]gllvmTMB_mspl_registry_lookup[(]", code))
})
