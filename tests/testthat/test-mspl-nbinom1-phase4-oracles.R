## Phase 4 nbinom1 LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-nbinom1-prep.md
## Helpers stay in this file. Do not call live MSPL on nbinom1.
## Do not edit src/. Do not widen .gllvmTMB_mspl_prepare().
## Do not add an nbinom1 registry row.

.nb1_mu <- function(eta, exposure = 1) {
  as.numeric(exposure) * exp(as.numeric(eta))
}

.nb1_var <- function(mu, phi) {
  as.numeric(mu) * (1 + as.numeric(phi))
}

.nb2_var <- function(mu, theta) {
  mu <- as.numeric(mu)
  theta <- as.numeric(theta)
  mu + (mu * mu) / theta
}

.pois_var <- function(mu) {
  as.numeric(mu)
}

.nb1_W <- function(mu, phi) {
  as.numeric(mu) / (1 + as.numeric(phi))
}

.nb2_W <- function(mu, theta) {
  mu <- as.numeric(mu)
  theta <- as.numeric(theta)
  (mu * theta) / (theta + mu)
}

.pois_W <- function(mu) {
  as.numeric(mu)
}

.nb1_I <- function(X, mu, phi) {
  X <- as.matrix(X)
  w <- .nb1_W(mu, phi)
  crossprod(X, X * w)
}

.pois_I <- function(X, mu) {
  X <- as.matrix(X)
  w <- .pois_W(mu)
  crossprod(X, X * w)
}

.nb2_I <- function(X, mu, theta) {
  X <- as.matrix(X)
  w <- .nb2_W(mu, theta)
  crossprod(X, X * w)
}

.nb1_Pj <- function(X, mu, phi) {
  I <- .nb1_I(X, mu, phi)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.pois_Pj <- function(X, mu) {
  I <- .pois_I(X, mu)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.nb2_Pj <- function(X, mu, theta) {
  I <- .nb2_I(X, mu, theta)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.nb1_size <- function(mu, phi) {
  as.numeric(mu) / as.numeric(phi)
}

.nb1_log_v_minus_mu <- function(mu, phi) {
  log(as.numeric(mu)) + log(as.numeric(phi))
}

.nb2_log_v_minus_mu <- function(mu, theta) {
  2 * log(as.numeric(mu)) - log(as.numeric(theta))
}

.nb1_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.nb1_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.nb1_fixture <- function() {
  ## Intercept + one covariate; four stacked rows (toy design).
  ## Shared phi is interior and not a Poisson limit.
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  phi <- 1.5
  mu <- .nb1_mu(eta)
  list(
    X = X,
    beta = beta,
    eta = eta,
    phi = phi,
    mu = mu,
    n_rows = nrow(X),
    p_free = ncol(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L),
    theta_contrast = 1 / phi
  )
}

test_that("N1: NB1 variance is mu*(1+phi); Poisson and NB2 differ", {
  fx <- .nb1_fixture()
  v_nb1 <- .nb1_var(fx$mu, fx$phi)
  expect_equal(v_nb1, fx$mu + fx$phi * fx$mu, tolerance = 1e-12)
  expect_equal(v_nb1, fx$mu * (1 + fx$phi), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(v_nb1, .pois_var(fx$mu), tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(
    v_nb1,
    .nb2_var(fx$mu, fx$theta_contrast),
    tolerance = 1e-6
  )))
  ## Poisson is the phi -> 0 limit, not the interior value.
  expect_equal(.nb1_var(fx$mu, 0), .pois_var(fx$mu), tolerance = 1e-12)
})

test_that("N2: NB1 weights are mu/(1+phi); not Poisson; not NB2", {
  fx <- .nb1_fixture()
  w_nb1 <- .nb1_W(fx$mu, fx$phi)
  expect_equal(w_nb1, fx$mu / (1 + fx$phi), tolerance = 1e-12)
  expect_equal(
    w_nb1,
    (fx$mu * fx$mu) / .nb1_var(fx$mu, fx$phi),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(w_nb1, .pois_W(fx$mu), tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(
    w_nb1,
    .nb2_W(fx$mu, fx$theta_contrast),
    tolerance = 1e-6
  )))
  expect_equal(.nb1_W(fx$mu, 0), .pois_W(fx$mu), tolerance = 1e-12)
})

test_that("N3: Jeffreys atom uses NB1 W; shared-phi identity holds", {
  fx <- .nb1_fixture()
  I_nb1 <- .nb1_I(fx$X, fx$mu, fx$phi)
  I_pois <- .pois_I(fx$X, fx$mu)
  expect_equal(I_nb1, I_pois / (1 + fx$phi), tolerance = 1e-12)
  expect_equal(
    .nb1_Pj(fx$X, fx$mu, fx$phi),
    .pois_Pj(fx$X, fx$mu) - (fx$p_free / 2) * log(1 + fx$phi),
    tolerance = 1e-12
  )
  expect_equal(
    .nb1_Pj(fx$X, fx$mu, fx$phi),
    0.5 * log(det(I_nb1)),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(
    .nb1_Pj(fx$X, fx$mu, fx$phi),
    .pois_Pj(fx$X, fx$mu),
    tolerance = 1e-6
  )))
  expect_false(isTRUE(all.equal(
    .nb1_Pj(fx$X, fx$mu, fx$phi),
    .nb2_Pj(fx$X, fx$mu, fx$theta_contrast),
    tolerance = 1e-6
  )))
})

test_that("N4: mean-boundary at fixed phi sends NB1 Jeffreys atom to -Inf", {
  fx <- .nb1_fixture()
  beta1_grid <- seq(0, -20, length.out = 11)
  Pj <- vapply(beta1_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    .nb1_Pj(fx$X, .nb1_mu(eta), fx$phi)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), -5)
  expect_lt(tail(Pj, 1L), Pj[1L] - 10)
})

test_that("N5: near-zero mean scaling at fixed phi deteriorates P_J", {
  fx <- .nb1_fixture()
  eps_grid <- 10^seq(0, -6, length.out = 7)
  Pj <- vapply(eps_grid, function(eps) {
    .nb1_Pj(fx$X, eps * fx$mu, fx$phi)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), -10)
})

test_that("N6: phi -> 0 at fixed mu increases P_J toward Poisson; not -Inf", {
  fx <- .nb1_fixture()
  phi_grid <- c(10, 5, 2, 1, 0.1, 0.01)
  Pj <- vapply(phi_grid, function(phi) {
    .nb1_Pj(fx$X, fx$mu, phi)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) > 0))
  phi_lo <- tail(phi_grid, 1L)
  expect_equal(
    tail(Pj, 1L),
    .pois_Pj(fx$X, fx$mu) - (fx$p_free / 2) * log(1 + phi_lo),
    tolerance = 1e-12
  )
  expect_lt(abs(tail(Pj, 1L) - .pois_Pj(fx$X, fx$mu)), 0.02)
  ## Opposite monotonicity from the mean-boundary path (N4).
  expect_gt(tail(Pj, 1L), Pj[1L])
})

test_that("N7: phi -> Inf at fixed mu sends P_J to -Inf", {
  fx <- .nb1_fixture()
  phi_grid <- c(0.5, 1, 2, 5, 20, 100)
  Pj <- vapply(phi_grid, function(phi) {
    .nb1_Pj(fx$X, fx$mu, phi)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_equal(
    tail(Pj, 1L),
    .pois_Pj(fx$X, fx$mu) - (fx$p_free / 2) * log(1 + tail(phi_grid, 1L)),
    tolerance = 1e-12
  )
  expect_lt(tail(Pj, 1L), Pj[1L] - 4)
})

test_that("N8: setting theta = 1/phi does not recover NB1 V or W", {
  fx <- .nb1_fixture()
  expect_false(isTRUE(all.equal(fx$mu, rep(1, fx$n_rows), tolerance = 1e-3)))
  v_nb1 <- .nb1_var(fx$mu, fx$phi)
  v_nb2 <- .nb2_var(fx$mu, fx$theta_contrast)
  expect_false(isTRUE(all.equal(v_nb1, v_nb2, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(
    .nb1_W(fx$mu, fx$phi),
    .nb2_W(fx$mu, fx$theta_contrast),
    tolerance = 1e-6
  )))
  ## They would agree only on rows with mu == 1.
  mu_one <- rep(1, fx$n_rows)
  expect_equal(
    .nb1_var(mu_one, fx$phi),
    .nb2_var(mu_one, fx$theta_contrast),
    tolerance = 1e-12
  )
})

test_that("N9: exposure doubling doubles NB1 information; row count fixed", {
  fx <- .nb1_fixture()
  E <- c(1, 2, 0.5, 4)
  mu1 <- .nb1_mu(fx$eta, exposure = E)
  mu2 <- .nb1_mu(fx$eta, exposure = 2 * E)
  I1 <- .nb1_I(fx$X, mu1, fx$phi)
  I2 <- .nb1_I(fx$X, mu2, fx$phi)
  expect_equal(I2, 2 * I1, tolerance = 1e-12)
  info1 <- sum(.nb1_W(mu1, fx$phi))
  info2 <- sum(.nb1_W(mu2, fx$phi))
  expect_equal(info2, 2 * info1, tolerance = 1e-12)
  expect_equal(info1, sum(mu1) / (1 + fx$phi), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(info1, sum(mu1), tolerance = 1e-6)))
  expect_identical(length(mu1), fx$n_rows)
  expect_identical(length(mu2), fx$n_rows)
  expect_false(isTRUE(all.equal(
    info1,
    as.numeric(fx$n_rows),
    tolerance = 1e-6
  )))
})

test_that("N10: offset spelling vs folded log-exposure leave mu and I identical", {
  fx <- .nb1_fixture()
  E <- c(1.5, 2.0, 0.8, 3.0)
  eta_free <- fx$eta
  mu_offset <- .nb1_mu(eta_free, exposure = E)
  eta_folded <- eta_free + log(E)
  mu_folded <- .nb1_mu(eta_folded, exposure = 1)
  expect_equal(mu_offset, mu_folded, tolerance = 1e-12)
  expect_equal(
    .nb1_I(fx$X, mu_offset, fx$phi),
    .nb1_I(fx$X, mu_folded, fx$phi),
    tolerance = 1e-12
  )
  expect_equal(
    .nb1_Pj(fx$X, mu_offset, fx$phi),
    .nb1_Pj(fx$X, mu_folded, fx$phi),
    tolerance = 1e-12
  )
})

test_that("N11: Hirose Psi and V_loading are refused / inert for NB1", {
  fx <- .nb1_fixture()
  refuse_hirose_nb1 <- function() {
    stop("nbinom1 ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_nb1(), "no free Psi")
  ## Fabricating psi = phi or psi = 1/mu is a type error, not a derivation.
  hirose_phi <- .nb1_hirose_atom(rep(1, fx$n_rows), rep(fx$phi, fx$n_rows))
  hirose_invmu <- .nb1_hirose_atom(fx$mu, 1 / fx$mu)
  expect_false(isTRUE(all.equal(
    hirose_phi,
    .nb1_Pj(fx$X, fx$mu, fx$phi),
    tolerance = 1e-3
  )))
  expect_false(isTRUE(all.equal(
    hirose_invmu,
    .nb1_Pj(fx$X, fx$mu, fx$phi),
    tolerance = 1e-3
  )))
  expect_equal(hirose_invmu, sum(fx$mu^2), tolerance = 1e-12)

  V0 <- .nb1_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  mu_up <- fx$mu
  mu_up[1L] <- mu_up[1L] + eps
  expect_equal(.nb1_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  expect_equal(
    (.nb1_bernoulli_V_loading(fx$Lambda) - V0) / eps,
    0,
    tolerance = 0
  )
  expect_false(isTRUE(all.equal(
    .nb1_Pj(fx$X, fx$mu, fx$phi),
    .nb1_Pj(fx$X, mu_up, fx$phi),
    tolerance = 1e-10
  )))
  expect_false(isTRUE(all.equal(
    .nb1_Pj(fx$X, fx$mu, fx$phi),
    .nb1_Pj(fx$X, fx$mu, fx$phi + eps),
    tolerance = 1e-10
  )))
  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  expect_gt(
    abs((.nb1_bernoulli_V_loading(Lambda_up) - V0) / eps),
    1e-8
  )
})

test_that("N12: NB1 size is mu/phi; log(V-mu) matches the TMB comment", {
  fx <- .nb1_fixture()
  size <- .nb1_size(fx$mu, fx$phi)
  expect_equal(size, fx$mu / fx$phi, tolerance = 1e-12)
  ## NB1 size depends on mu; NB2 size = theta does not.
  expect_false(isTRUE(all.equal(size, rep(fx$theta_contrast, fx$n_rows),
                                tolerance = 1e-6)))
  expect_equal(
    .nb1_var(fx$mu, fx$phi),
    fx$mu + (fx$mu * fx$mu) / size,
    tolerance = 1e-12
  )
  expect_equal(
    .nb1_log_v_minus_mu(fx$mu, fx$phi),
    log(.nb1_var(fx$mu, fx$phi) - fx$mu),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(
    .nb1_log_v_minus_mu(fx$mu, fx$phi),
    .nb2_log_v_minus_mu(fx$mu, fx$theta_contrast),
    tolerance = 1e-6
  )))
  ## Success probability phi/(1+phi) is mu-free (Design 105 NB1 density).
  p_from_mu <- fx$mu / (fx$mu + size)
  expect_equal(p_from_mu, rep(fx$phi / (1 + fx$phi), fx$n_rows),
               tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    p_from_mu,
    fx$mu / (fx$mu + fx$theta_contrast),
    tolerance = 1e-6
  )))
})

test_that("N13: nbinom1 is not admitted and has no planned registry row", {
  tbl <- .gllvmTMB_mspl_registry()
  nb1 <- tbl[tbl$family == "nbinom1", , drop = FALSE]
  expect_false(any(nb1$status == "admitted"))
  expect_false(any(nb1$status == "planned"))
  expect_false(any(nb1$evidence == "phase4_prep"))
  expect_true(is.null(
    .gllvmTMB_mspl_registry_lookup("nbinom1", "log", "ordinary", 1L)
  ))
  expect_true(is.null(
    .gllvmTMB_mspl_registry_lookup("nbinom1", "log", "ordinary", 2L)
  ))
})

test_that("Phase-4 oracles never invoke a live nbinom1 MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-nbinom1-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
})
