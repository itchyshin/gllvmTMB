## Phase 4-style Tweedie LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-tweedie-prep.md
## Helpers stay in this file. Do not call live MSPL on Tweedie.
## Do not edit src/. Do not add a Tweedie registry row.
## Do not widen .gllvmTMB_mspl_prepare().

.tweedie_mu <- function(eta) {
  exp(as.numeric(eta))
}

.tweedie_W <- function(mu, phi, p) {
  as.numeric(mu)^(2 - as.numeric(p)) / as.numeric(phi)
}

.tweedie_I <- function(X, mu, phi, p) {
  X <- as.matrix(X)
  w <- .tweedie_W(mu, phi, p)
  crossprod(X, X * w)
}

.tweedie_Pj <- function(X, mu, phi, p) {
  I <- .tweedie_I(X, mu, phi, p)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.tweedie_lambda0 <- function(mu, phi, p) {
  ## CPG jump mean; Pr(Y = 0) = exp(-lambda). Textbook, 1 < p < 2.
  as.numeric(mu)^(2 - as.numeric(p)) / (as.numeric(phi) * (2 - as.numeric(p)))
}

.tweedie_p0 <- function(mu, phi, p) {
  exp(-.tweedie_lambda0(mu, phi, p))
}

.tweedie_poisson_W <- function(mu) {
  as.numeric(mu)
}

.tweedie_bernoulli_Wg <- function(mu) {
  mu * (1 - mu)
}

.tweedie_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.tweedie_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.tweedie_fixture <- function() {
  ## Intercept + one covariate; four stacked rows (toy design).
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  mu <- .tweedie_mu(eta)
  list(
    X = X,
    beta = beta,
    eta = eta,
    mu = mu,
    phi = 1.4,
    p = 1.5,
    n_rows = nrow(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("E1: Tweedie information uses W=mu^{2-p}/phi; Poisson and Bernoulli differ", {
  fx <- .tweedie_fixture()
  I <- .tweedie_I(fx$X, fx$mu, fx$phi, fx$p)
  w <- .tweedie_W(fx$mu, fx$phi, fx$p)
  expect_equal(I, crossprod(fx$X, fx$X * w), tolerance = 1e-12)
  expect_equal(
    .tweedie_Pj(fx$X, fx$mu, fx$phi, fx$p),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )
  expect_equal(w, fx$mu^(2 - fx$p) / fx$phi, tolerance = 1e-12)

  expect_false(isTRUE(all.equal(
    w,
    .tweedie_poisson_W(fx$mu),
    tolerance = 1e-6
  )))
  mu_clip <- pmin(pmax(fx$mu / max(fx$mu), 1e-3), 1 - 1e-3)
  I_tw <- .tweedie_I(fx$X, mu_clip, fx$phi, fx$p)
  I_pois <- crossprod(fx$X, fx$X * .tweedie_poisson_W(mu_clip))
  I_bern <- crossprod(fx$X, fx$X * .tweedie_bernoulli_Wg(mu_clip))
  expect_false(isTRUE(all.equal(I_tw, I_pois, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(I_tw, I_bern, tolerance = 1e-6)))
})

test_that("E2: mean-boundary path sends Tweedie Jeffreys atom to -Inf", {
  fx <- .tweedie_fixture()
  beta1_grid <- seq(0, -20, length.out = 11)
  Pj <- vapply(beta1_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    .tweedie_Pj(fx$X, .tweedie_mu(eta), fx$phi, fx$p)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), -5)
  expect_lt(tail(Pj, 1L), Pj[1L] - 8)
})

test_that("E3: phi -> Inf sends P_J to -Inf and P(Y=0) to 1; phi -> 0 raises P_J", {
  fx <- .tweedie_fixture()
  phi_up <- 10^seq(0, 4, length.out = 5)
  Pj_up <- vapply(phi_up, function(phi) {
    .tweedie_Pj(fx$X, fx$mu, phi, fx$p)
  }, numeric(1L))
  p0_up <- vapply(phi_up, function(phi) {
    mean(.tweedie_p0(fx$mu, phi, fx$p))
  }, numeric(1L))
  expect_true(all(is.finite(Pj_up)))
  expect_true(all(diff(Pj_up) < 0))
  expect_true(all(diff(p0_up) > 0))
  expect_gt(tail(p0_up, 1L), 0.99)
  expect_lt(tail(Pj_up, 1L), Pj_up[1L] - 4)

  phi_down <- 10^seq(0, -4, length.out = 5)
  Pj_down <- vapply(phi_down, function(phi) {
    .tweedie_Pj(fx$X, fx$mu, phi, fx$p)
  }, numeric(1L))
  expect_true(all(is.finite(Pj_down)))
  expect_true(all(diff(Pj_down) > 0))
  ## beta-Jeffreys rewards phi -> 0; it is not a collapse repair.
  expect_gt(tail(Pj_down, 1L), Pj_down[1L] + 4)
})

test_that("E4: matched P(Y=0) identifies W, not the (mu, phi) pair", {
  p <- 1.5
  target_p0 <- 0.8
  lam <- -log(target_p0)

  phi_mu_path <- 1.0
  mu_mu_path <- (lam * phi_mu_path * (2 - p))^(1 / (2 - p))
  expect_equal(
    .tweedie_p0(mu_mu_path, phi_mu_path, p),
    target_p0,
    tolerance = 1e-12
  )

  mu_phi_path <- 1.0
  phi_phi_path <- mu_phi_path^(2 - p) / (lam * (2 - p))
  expect_equal(
    .tweedie_p0(mu_phi_path, phi_phi_path, p),
    target_p0,
    tolerance = 1e-12
  )

  ## Textbook: W = (2-p) * lambda, so matched zero-mass matches W.
  w_mu <- .tweedie_W(mu_mu_path, phi_mu_path, p)
  w_phi <- .tweedie_W(mu_phi_path, phi_phi_path, p)
  expect_equal(w_mu, lam * (2 - p), tolerance = 1e-12)
  expect_equal(w_phi, w_mu, tolerance = 1e-12)

  ## The scientific pair is still unidentified: different mu, different phi.
  expect_false(isTRUE(all.equal(mu_mu_path, mu_phi_path, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(phi_mu_path, phi_phi_path, tolerance = 1e-6)))

  ## Poisson all-zero would read mu = -log P(Y=0). That equals neither path.
  mu_poisson <- -log(target_p0)
  expect_equal(mu_poisson, lam, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(mu_poisson, mu_mu_path, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(mu_poisson, mu_phi_path, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(
    .tweedie_poisson_W(mu_poisson),
    w_mu,
    tolerance = 1e-6
  )))
})

test_that("E5: p -> 2- makes W mean-inert and kills the point mass", {
  fx <- .tweedie_fixture()
  p_near2 <- 1.999
  w <- .tweedie_W(fx$mu, fx$phi, p_near2)
  expect_equal(w, rep(1 / fx$phi, fx$n_rows), tolerance = 1e-3)

  p0 <- .tweedie_p0(fx$mu, fx$phi, p_near2)
  expect_lt(max(p0), 1e-6)

  mu_up <- fx$mu * 1.25
  Pj0 <- .tweedie_Pj(fx$X, fx$mu, fx$phi, p_near2)
  Pj1 <- .tweedie_Pj(fx$X, mu_up, fx$phi, p_near2)
  expect_lt(abs(Pj1 - Pj0), 0.05)

  ## At the prep interior p=1.5 the same mu shift *does* move P_J.
  Pj0_int <- .tweedie_Pj(fx$X, fx$mu, fx$phi, fx$p)
  Pj1_int <- .tweedie_Pj(fx$X, mu_up, fx$phi, fx$p)
  expect_false(isTRUE(all.equal(Pj0_int, Pj1_int, tolerance = 1e-6)))
})

test_that("E6: p -> 1+ recovers mu/phi weights; Poisson W=mu only if phi=1", {
  fx <- .tweedie_fixture()
  p_near1 <- 1.001
  w <- .tweedie_W(fx$mu, fx$phi, p_near1)
  expect_equal(w, fx$mu / fx$phi, tolerance = 1e-3)
  expect_equal(
    .tweedie_p0(fx$mu, fx$phi, p_near1),
    exp(-fx$mu / fx$phi),
    tolerance = 1e-3
  )
  expect_false(isTRUE(all.equal(
    w,
    .tweedie_poisson_W(fx$mu),
    tolerance = 1e-6
  )))

  w_phi1 <- .tweedie_W(fx$mu, phi = 1, p = p_near1)
  expect_equal(w_phi1, .tweedie_poisson_W(fx$mu), tolerance = 1e-3)
})

test_that("E7: information size is sum(mu^{2-p}/phi), not sum(mu) or P(Y=0)", {
  fx <- .tweedie_fixture()
  I1 <- .tweedie_I(fx$X, fx$mu, fx$phi, fx$p)
  I2 <- .tweedie_I(fx$X, 2 * fx$mu, fx$phi, fx$p)
  scale <- 2^(2 - fx$p)
  expect_equal(I2, scale * I1, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(I2, 2 * I1, tolerance = 1e-6)))

  info1 <- sum(.tweedie_W(fx$mu, fx$phi, fx$p))
  info2 <- sum(.tweedie_W(2 * fx$mu, fx$phi, fx$p))
  expect_equal(info2, scale * info1, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(info1, sum(fx$mu), tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(info1, as.numeric(fx$n_rows), tolerance = 1e-6)))
  expect_identical(length(fx$mu), fx$n_rows)

  p0_1 <- mean(.tweedie_p0(fx$mu, fx$phi, fx$p))
  p0_2 <- mean(.tweedie_p0(2 * fx$mu, fx$phi, fx$p))
  expect_false(isTRUE(all.equal(p0_1, info1, tolerance = 1e-6)))
  expect_lt(p0_2, p0_1)
})

test_that("E8: Gaussian Hirose Psi atom is refused for Tweedie mean model", {
  fx <- .tweedie_fixture()
  refuse_hirose_tweedie <- function() {
    stop("Tweedie ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_tweedie(), "no free Psi")
  ## Fabricating psi = phi or psi = 1/mu is a type error, not a derivation.
  fake_psi_phi <- rep(fx$phi, fx$n_rows)
  hirose_phi <- .tweedie_hirose_atom(fx$mu, fake_psi_phi)
  expect_false(isTRUE(all.equal(
    hirose_phi,
    .tweedie_Pj(fx$X, fx$mu, fx$phi, fx$p),
    tolerance = 1e-3
  )))
  fake_psi_invmu <- 1 / fx$mu
  hirose_invmu <- .tweedie_hirose_atom(fx$mu, fake_psi_invmu)
  expect_equal(hirose_invmu, sum(fx$mu^2), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    hirose_invmu,
    .tweedie_Pj(fx$X, fx$mu, fx$phi, fx$p),
    tolerance = 1e-3
  )))
})

test_that("E9: V_loading is (mu, phi, p)-inert; Tweedie P_J moves", {
  fx <- .tweedie_fixture()
  V0 <- .tweedie_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6

  expect_equal(.tweedie_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  expect_equal(
    (
      .tweedie_bernoulli_V_loading(fx$Lambda) - V0
    ) / eps,
    0,
    tolerance = 0
  )

  Pj0 <- .tweedie_Pj(fx$X, fx$mu, fx$phi, fx$p)
  mu_up <- fx$mu
  mu_up[1L] <- mu_up[1L] + eps
  expect_false(isTRUE(all.equal(
    Pj0,
    .tweedie_Pj(fx$X, mu_up, fx$phi, fx$p),
    tolerance = 1e-10
  )))
  expect_false(isTRUE(all.equal(
    Pj0,
    .tweedie_Pj(fx$X, fx$mu, fx$phi + eps, fx$p),
    tolerance = 1e-10
  )))
  expect_false(isTRUE(all.equal(
    Pj0,
    .tweedie_Pj(fx$X, fx$mu, fx$phi, fx$p + 1e-4),
    tolerance = 1e-10
  )))

  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  dV_dL <- (
    .tweedie_bernoulli_V_loading(Lambda_up) - V0
  ) / eps
  expect_gt(abs(dV_dL), 1e-8)
})

test_that("E10: Tweedie has no registry row and is not admitted", {
  tbl <- .gllvmTMB_mspl_registry()
  expect_false(any(tbl$family == "tweedie"))
  expect_null(
    .gllvmTMB_mspl_registry_lookup("tweedie", "log", "ordinary", 1L)
  )
  expect_null(
    .gllvmTMB_mspl_registry_lookup("tweedie", "log", "ordinary", 2L)
  )
  expect_false(any(tbl$status == "admitted" & tbl$family == "tweedie"))
  expect_false(any(tbl$status == "planned" & tbl$family == "tweedie"))
})

test_that("Phase-4-style oracles never invoke a live Tweedie MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-tweedie-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
  expect_false(any(grepl("family_id\\s*%in%\\s*c\\(0L,\\s*1L,\\s*6L\\)", code)))
})
