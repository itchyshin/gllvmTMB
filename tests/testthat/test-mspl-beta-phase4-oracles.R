## Phase 4 Beta (logit) LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-beta-prep.md
## Helpers stay in this file. Do not call live MSPL on Beta.
## Do not edit src/. Do not widen .gllvmTMB_mspl_prepare().
## Do not read or grow the MSPL registry.

.beta_mu <- function(eta) {
  stats::plogis(as.numeric(eta))
}

.beta_w <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  if (length(phi) == 1L) {
    phi <- rep(phi, length(mu))
  }
  a <- mu * phi
  b <- (1 - mu) * phi
  (phi^2) * (mu * (1 - mu))^2 * (trigamma(a) + trigamma(b))
}

.beta_I <- function(X, mu, phi) {
  X <- as.matrix(X)
  w <- .beta_w(mu, phi)
  crossprod(X, X * w)
}

.beta_Pj <- function(X, mu, phi) {
  I <- .beta_I(X, mu, phi)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.beta_I_phi <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  if (length(phi) == 1L) {
    phi <- rep(phi, length(mu))
  }
  -trigamma(phi) + (mu^2) * trigamma(mu * phi) +
    ((1 - mu)^2) * trigamma((1 - mu) * phi)
}

.beta_I_eta_phi <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  phi * mu * (1 - mu) * (
    mu * trigamma(mu * phi) - (1 - mu) * trigamma((1 - mu) * phi)
  )
}

.beta_ld <- function(y, mu, phi) {
  y <- as.numeric(y)
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  a <- mu * phi
  b <- (1 - mu) * phi
  lgamma(phi) - lgamma(a) - lgamma(b) +
    (a - 1) * log(y) + (b - 1) * log(1 - y)
}

.beta_bernoulli_Wg <- function(mu) {
  mu * (1 - mu)
}

.beta_bernoulli_Pj <- function(X, mu) {
  I <- crossprod(as.matrix(X), as.matrix(X) * .beta_bernoulli_Wg(mu))
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.beta_bernoulli_ld <- function(y, mu) {
  y * log(mu) + (1 - y) * log(1 - mu)
}

.beta_poisson_W <- function(mu) {
  as.numeric(mu)
}

.beta_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.beta_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.beta_fixture <- function() {
  ## Intercept + one covariate; four stacked rows (toy design).
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  phi <- 5
  list(
    X = X,
    beta = beta,
    eta = eta,
    mu = .beta_mu(eta),
    phi = phi,
    n_rows = nrow(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("E1: Beta information uses w(mu, phi); Bernoulli and Poisson weights differ", {
  fx <- .beta_fixture()
  w <- .beta_w(fx$mu, fx$phi)
  I <- .beta_I(fx$X, fx$mu, fx$phi)
  expect_equal(
    w,
    (fx$phi^2) * (fx$mu * (1 - fx$mu))^2 *
      (trigamma(fx$mu * fx$phi) + trigamma((1 - fx$mu) * fx$phi)),
    tolerance = 1e-12
  )
  expect_equal(I, crossprod(fx$X, fx$X * w), tolerance = 1e-12)
  expect_equal(
    .beta_Pj(fx$X, fx$mu, fx$phi),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )

  expect_false(isTRUE(all.equal(w, .beta_bernoulli_Wg(fx$mu), tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(w, .beta_poisson_W(fx$mu), tolerance = 1e-6)))
  I_bern <- crossprod(fx$X, fx$X * .beta_bernoulli_Wg(fx$mu))
  I_pois <- crossprod(fx$X, fx$X * .beta_poisson_W(fx$mu))
  expect_false(isTRUE(all.equal(I, I_bern, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(I, I_pois, tolerance = 1e-6)))
})

test_that("E2: mu -> 0/1 at fixed phi leaves w -> 1 and P_J finite", {
  fx <- .beta_fixture()
  eta_hi <- 20
  mu_hi <- .beta_mu(eta_hi)
  mu_lo <- .beta_mu(-eta_hi)
  expect_lt(abs(.beta_w(mu_hi, fx$phi) - 1), 0.02)
  expect_lt(abs(.beta_w(mu_lo, fx$phi) - 1), 0.02)

  eta_grid <- seq(0, 20, length.out = 11)
  w_hi <- vapply(eta_grid, function(e) .beta_w(.beta_mu(e), fx$phi), numeric(1L))
  expect_true(all(is.finite(w_hi)))
  expect_true(all(w_hi > 0.5))
  expect_gt(tail(w_hi, 1L), 0.98)

  Pj_beta <- vapply(eta_grid, function(e) {
    mu <- .beta_mu(fx$X[, 1L] * e + fx$X[, 2L] * fx$beta[2L])
    .beta_Pj(fx$X, mu, fx$phi)
  }, numeric(1L))
  expect_true(all(is.finite(Pj_beta)))
  Pj_lim <- 0.5 * log(det(crossprod(fx$X)))
  expect_lt(abs(tail(Pj_beta, 1L) - Pj_lim), 0.05)

  Pj_bern <- vapply(eta_grid, function(e) {
    mu <- .beta_mu(fx$X[, 1L] * e + fx$X[, 2L] * fx$beta[2L])
    .beta_bernoulli_Pj(fx$X, mu)
  }, numeric(1L))
  expect_true(all(diff(Pj_bern) < 0))
  expect_lt(tail(Pj_bern, 1L), -10)
  expect_gt(tail(Pj_beta, 1L), tail(Pj_bern, 1L) + 10)
})

test_that("E3: Beta log-density -> -Inf as |eta| -> Inf; Bernoulli all-zero does not", {
  phi <- 5
  y <- 0.2
  ## Start past the single-observation mode (near logit(y) ~ -1.4) so both
  ## tails are already on the coercive side.
  eta_grid <- seq(4, 16, length.out = 7)
  ld_hi <- vapply(eta_grid, function(e) .beta_ld(y, .beta_mu(e), phi), numeric(1L))
  ld_lo <- vapply(eta_grid, function(e) .beta_ld(y, .beta_mu(-e), phi), numeric(1L))
  expect_true(all(is.finite(ld_hi)))
  expect_true(all(is.finite(ld_lo)))
  expect_true(all(diff(ld_hi) < 0))
  expect_true(all(diff(ld_lo) < 0))
  expect_lt(tail(ld_hi, 1L), -10)
  expect_lt(tail(ld_lo, 1L), -10)

  bern_lo <- vapply(
    seq(0, -16, length.out = 9),
    function(e) .beta_bernoulli_ld(0, .beta_mu(e)),
    numeric(1L)
  )
  expect_true(all(is.finite(bern_lo)))
  expect_true(all(diff(bern_lo) > 0))
  expect_gt(tail(bern_lo, 1L), -1e-6)
  expect_lt(tail(ld_lo, 1L), tail(bern_lo, 1L) - 10)
})

test_that("E4: near-boundary y keeps a finite intercept MLE whose |eta| grows", {
  phi <- 5
  eps_grid <- c(1e-1, 1e-2, 1e-3, 1e-4)
  eta_grid <- seq(-20, 4, length.out = 241)
  eta_hat <- vapply(eps_grid, function(eps) {
    ld <- vapply(eta_grid, function(e) .beta_ld(eps, .beta_mu(e), phi), numeric(1L))
    eta_grid[which.max(ld)]
  }, numeric(1L))
  expect_true(all(is.finite(eta_hat)))
  expect_true(all(eta_hat > -20 + 1e-8))
  expect_true(all(eta_hat < 0))
  expect_true(all(diff(eta_hat) < 0))
  ## Growth is real but slow: phi keeps the intercept MLE finite even as
  ## y -> 0. The claim is monotonicity plus a clear shift, not |eta| -> Inf.
  expect_lt(tail(eta_hat, 1L), eta_hat[1L] - 1.5)
})

test_that("E5: phi -> Inf sends w ~ phi * mu * (1 - mu) and I_phi -> 0", {
  mu <- 0.4
  phi_big <- 80
  w <- .beta_w(mu, phi_big)
  expect_equal(w, phi_big * mu * (1 - mu), tolerance = 0.02)

  phi_grid <- c(10, 20, 40, 80)
  Iphi <- vapply(phi_grid, function(p) .beta_I_phi(mu, p), numeric(1L))
  expect_true(all(Iphi > 0))
  expect_true(all(diff(Iphi) < 0))
  expect_equal(tail(Iphi, 1L), 1 / (2 * phi_big^2), tolerance = 0.05)
  expect_lt(tail(Iphi, 1L), 2e-4)
})

test_that("E6: phi -> 0 sends I_phi ~ 1/phi^2, w -> mu^2 + (1-mu)^2, shapes -> 0", {
  mu <- 0.4
  phi_small <- 1e-2
  Iphi <- .beta_I_phi(mu, phi_small)
  expect_equal(Iphi, 1 / phi_small^2, tolerance = 0.02)
  expect_gt(Iphi, 5e3)

  w_lim <- .beta_w(mu, phi_small)
  expect_equal(w_lim, mu^2 + (1 - mu)^2, tolerance = 0.02)

  a <- mu * phi_small
  b <- (1 - mu) * phi_small
  expect_lt(a, 0.01)
  expect_lt(b, 0.01)
  expect_false(isTRUE(all.equal(a, 0, tolerance = 0)))
})

test_that("E7: Gaussian Hirose Psi atom is refused for Beta mean-precision model", {
  fx <- .beta_fixture()
  refuse_hirose_beta <- function() {
    stop("Beta ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_beta(), "no free Psi")

  ## Fabricating psi = 1/phi or psi = Var(y) is a type error, not a derivation.
  fake_psi_phi <- 1 / fx$phi
  var_y <- fx$mu * (1 - fx$mu) / (1 + fx$phi)
  hirose_phi <- .beta_hirose_atom(rep(1, fx$n_rows), rep(fake_psi_phi, fx$n_rows))
  hirose_var <- .beta_hirose_atom(rep(1, fx$n_rows), var_y)
  expect_false(isTRUE(all.equal(
    hirose_phi,
    .beta_Pj(fx$X, fx$mu, fx$phi),
    tolerance = 1e-3
  )))
  expect_false(isTRUE(all.equal(
    hirose_var,
    .beta_Pj(fx$X, fx$mu, fx$phi),
    tolerance = 1e-3
  )))
  expect_equal(hirose_phi, fx$n_rows * fx$phi, tolerance = 1e-12)
})

test_that("E8: V_loading is (mu, phi)-inert; Poisson W=mu is not Beta w", {
  fx <- .beta_fixture()
  V0 <- .beta_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  mu_up <- fx$mu
  mu_up[1L] <- mu_up[1L] + eps
  expect_equal(.beta_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  expect_equal(
    (.beta_bernoulli_V_loading(fx$Lambda) - V0) / eps,
    0,
    tolerance = 0
  )

  phi_up <- fx$phi + eps
  expect_equal(
    .beta_bernoulli_V_loading(fx$Lambda),
    V0,
    tolerance = 0
  )
  expect_false(isTRUE(all.equal(
    .beta_w(fx$mu, fx$phi),
    .beta_w(fx$mu, phi_up),
    tolerance = 1e-10
  )))
  expect_false(isTRUE(all.equal(
    .beta_Pj(fx$X, fx$mu, fx$phi),
    .beta_Pj(fx$X, mu_up, fx$phi),
    tolerance = 1e-10
  )))

  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  expect_gt(
    abs((.beta_bernoulli_V_loading(Lambda_up) - V0) / eps),
    1e-8
  )

  expect_false(isTRUE(all.equal(
    .beta_w(fx$mu, fx$phi),
    .beta_poisson_W(fx$mu),
    tolerance = 1e-6
  )))
})

test_that("E9: I(eta, phi) is zero at mu = 1/2 and not orthogonal elsewhere", {
  phi <- 5
  expect_equal(.beta_I_eta_phi(0.5, phi), 0, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(.beta_I_eta_phi(0.2, phi), 0, tolerance = 1e-8)))
  expect_false(isTRUE(all.equal(.beta_I_eta_phi(0.8, phi), 0, tolerance = 1e-8)))
  expect_equal(
    .beta_I_eta_phi(0.2, phi),
    -.beta_I_eta_phi(0.8, phi),
    tolerance = 1e-12
  )
  expect_gt(.beta_I_phi(0.2, phi), 0)
  expect_gt(.beta_I_phi(0.5, phi), 0)
})

test_that("Phase-4 Beta oracles never invoke a live MSPL fit or the registry", {
  src_lines <- readLines(test_path("test-mspl-beta-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
  expect_false(grepl("[.]gllvmTMB_mspl_registry[(]", code))
  expect_false(grepl("[.]gllvmTMB_mspl_prepare[(]", code))
  expect_false(grepl("[.]gllvmTMB_mspl_registry_lookup[(]", code))
})
